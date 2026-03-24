# K3s on AlmaLinux 9

This document provides a comprehensive guide for installing, configuring, and operating K3s on CIS-hardened AlmaLinux 9 systems for Helix Stax. It is designed to be a definitive reference for AI agents and human operators.

### ## SKILL.md Content

This is the core daily reference for managing K3s.

#### **K3s CLI Quick Reference**

| Command | Description |
| :--- | :--- |
| `k3s server ...` | Start the K3s server (control plane). |
| `k3s agent ...` | Start the K3s agent (worker node). |
| `k3s kubectl <cmd>` | Run kubectl commands against the local K3s cluster. |
| `k3s crictl <cmd>` | Run crictl commands to interact with containerd. |
| `k3s etcd-snapshot save` | Manually trigger an etcd snapshot. |
| `k3s etcd-snapshot ls` | List existing etcd snapshots. |
| `k3s etcd-snapshot delete` | Delete an etcd snapshot. |
| `k3s check-config` | Verifies kernel and system configuration for K3s. |
| `systemctl start k3s` | Start the K3s server service. |
| `systemctl stop k3s` | Stop the K3s server service. |
| `journalctl -u k3s -f` | Follow logs for the K3s server. |
| `systemctl status k3s` | Check the status of the K3s server service. |
| `systemctl start k3s-agent` | Start the K3s agent service. |
| `journalctl -u k3s-agent -f` | Follow logs for the K3s agent. |

#### **Setup Checklist: Hardened AlmaLinux 9**

1.  **Load Kernel Modules**: Ensure `/etc/modules-load.d/k3s.conf` exists and loads `br_netfilter` and `overlay`.
2.  **Apply Kernel Parameters**: Ensure `/etc/sysctl.d/99-k3s.conf` is applied with all required settings (`ip_forward`, `bridge-nf-call-iptables`, etc.).
3.  **Install SELinux Policies**:
    *   Add the Rancher RPM repository.
    *   `dnf install -y container-selinux k3s-selinux`. This **must** be done *before* installing K3s.
4.  **Set SELinux Booleans**:
    *   `setsebool -P container_manage_cgroup 1`
5.  **Configure Firewall (`firewalld`)**:
    *   Open all required ports for the node's role (Control Plane vs. Agent). See table below.
    *   `firewall-cmd --reload`
6.  **Install K3s**:
    *   Run the install script with environment variables to set the version and configuration.
    *   Place a `config.yaml` at `/etc/rancher/k3s/config.yaml` before the first start.
7.  **Verify Installation**:
    *   `systemctl status k3s` (or `k3s-agent`).
    *   `k3s kubectl get nodes -o wide`
    *   `k3s kubectl get pods -A` (check CoreDNS, Flannel, etc.)
    *   `ausearch -m AVC -ts recent` (check for SELinux denials).

#### **Firewalld Port Reference**

| Port | Protocol | Role | Description |
| :--- | :--- | :--- | :--- |
| 2222 | TCP | All | SSH (Helix Stax custom port) |
| **6443** | **TCP** | **Control Plane** | **Kubernetes API Server** |
| 2379-2380 | TCP | Control Plane | etcd client & peer (for HA) |
| 10250 | TCP | All | Kubelet API |
| 10257 | TCP | Control Plane | kube-controller-manager metrics |
| 10259 | TCP | Control Plane | kube-scheduler metrics |
| **8472** | **UDP** | **All** | **Flannel VXLAN overlay network** |
| 30000-32767 | TCP/UDP | All | NodePort Services |
| 9100 | TCP | All | Node Exporter (Prometheus) |

#### **Kernel Parameter Reference (CIS Conflict Resolution)**

| Parameter | K3s Required Value | CIS Hardening Value | Resolution |
| :--- | :--- | :--- | :--- |
| `net.ipv4.ip_forward` | `1` | `0` | **Set to `1`**. Required for routing. Document as a compliance exception. |
| `net.bridge.bridge-nf-call-iptables` | `1` | `0` | **Set to `1`**. Required for pod networking. Document as a compliance exception. |
| `net.bridge.bridge-nf-call-ip6tables` | `1` | `0` | **Set to `1`**. Required for pod networking (IPv6). Document. |
| `net.ipv4.conf.all.rp_filter` | `1` or `2` | `2` | Set to `1` (strict) or `2` (loose). Flannel VXLAN may benefit from `2`. `1` is often sufficient. |

#### **Troubleshooting Decision Tree**

1.  **K3s service fails to start:**
    *   `journalctl -u k3s` or `journalctl -u k3s-agent`. Look for fatal errors.
    *   **Permission denied?** Check SELinux denials: `ausearch -m AVC -ts recent`. You may have missed installing `k3s-selinux` or setting a boolean.
    *   **Port conflict?** `ss -tlpn | grep 6443`. Ensure no other service is using the K3s API port.
    *   **Bad config?** Check `/etc/rancher/k3s/config.yaml` for YAML syntax errors.

2.  **Nodes are `NotReady`:**
    *   On the worker, `journalctl -u k3s-agent`. Look for connection errors to `https://<server_ip>:6443`.
    *   **Firewall issue?** `nc -zv <server_ip> 6443` from the worker. Check firewalld on the CP node.
    *   **Token mismatch?** Ensure the `K3S_TOKEN` used by the agent matches `/var/lib/rancher/k3s/server/node-token` on the CP.

3.  **Pods are `ContainerCreating` or `CrashLoopBackOff`:**
    *   `k3s kubectl describe pod <pod_name> -n <namespace>`. Check Events.
    *   **SELinux denial?** `ausearch -m AVC -ts recent`. Common when mounting volumes.
    *   **Network issue?** Pods cannot reach DNS or other pods. Go to step 4.

4.  **Pods cannot communicate across nodes:**
    *   `k3s kubectl get pods -n kube-system -l app=flannel -o wide`. Ensure Flannel pods are running on all nodes.
    *   **Firewall issue?** Check if port `8472/UDP` is open between all nodes.
    *   **Kernel module missing?** `lsmod | grep br_netfilter`. If missing, `modprobe br_netfilter` and ensure it loads on boot.
    *   **Wrong interface?** `ip a`. Check if `--flannel-iface` is set to the correct inter-node communication interface if multiple exist.

---
### ## reference.md Content

This section contains deep specifications and complete configurations.

#### **K3s Server: `config.yaml`**

Complete configuration for a control plane node. Place at `/etc/rancher/k3s/config.yaml`.

```yaml
# /etc/rancher/k3s/config.yaml
#
# K3s server configuration for Helix Stax control plane nodes.
# Precedence: CLI flags > Environment variables > YAML file.

# --- Cluster Networking ---
# Use the server's public IP for both API advertisement and Flannel traffic.
# This is crucial for nodes in different locations (Hetzner regions).
advertise-address: "178.156.233.12" # Set to the node's primary public/reachable IP.
node-ip: "178.156.233.12"           # IP for intra-cluster communication (Flannel).

# If using a multi-NIC setup where internal traffic goes over a private network,
# set node-ip to the private IP and advertise-address to the public one.
# For Hetzner, specify the correct public interface for Flannel if needed.
# flannel-iface: "eth0"

# Standard Kubernetes CIDRs. Do not change unless necessary.
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"

# --- Flannel CNI Configuration ---
# Explicitly set the backend to VXLAN for a simple, encapsulated L3 overlay.
flannel-backend: "vxlan"

# --- Component Disabling ---
# We manage our own ingress (Traefik v3) and load balancing (Cloudflare Tunnel).
disable:
  - traefik     # Disable bundled Traefik v2. We deploy v3 via Helm.
  - servicelb   # Disable K3s's simple ServiceLB.

# --- TLS and Authentication ---
# Add the server's IP to the API Server's certificate SAN.
# This allows `kubectl` to connect securely from outside the cluster using the IP.
tls-san:
  - "178.156.233.12"

# --- Kubeconfig Permissions ---
# Set the generated kubeconfig to be readable by all users (e.g., 'wakeem').
write-kubeconfig-mode: "0644"

# --- Datastore Configuration ---
# Instructs K3s to initialize with an embedded etcd datastore for multi-node HA.
# A single-node server would use SQLite by default. This flag is key for clustering.
cluster-init: true

# Automated etcd snapshots every 12 hours, retaining the last 5.
etcd-snapshot-schedule-cron: "0 */12 * * *"
etcd-snapshot-retention: 5
etcd-snapshot-dir: /var/lib/rancher/k3s/server/db/snapshots

# Expose etcd metrics for Prometheus scraping.
etcd-expose-metrics: true

# --- Kubernetes API Server Arguments ---
# Enable audit logging for security and compliance.
kube-apiserver-arg:
  - "audit-log-path=/var/log/k3s/k3s-audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"
  - "audit-policy-file=/etc/rancher/k3s/audit-policy.yaml"
```

#### **K3s Agent: `config.yaml`**

Place at `/etc/rancher/k3s/config.yaml` on agent nodes. Note that `server-url` and `token` are usually passed as environment variables (`K3S_URL`, `K3S_TOKEN`) during installation.

```yaml
# /etc/rancher/k3s/config.yaml (Agent Node)
#
# K3s agent configuration for Helix Stax worker nodes.

# --- Node Networking ---
# The IP this agent should register with.
node-ip: "5.78.145.30" # The public/reachable IP of this worker node.

# If multiple NICs, ensure Flannel uses the correct one.
# flannel-iface: "eth0"

# --- Node Labels and Taints (Optional) ---
# Example: Label this node as a worker.
# node-label:
#   - "role=worker"
#   - "region=us-west"
```

#### **Kernel Modules: `/etc/modules-load.d/k3s.conf`**

Ensures required kernel modules are loaded on boot.

```ini
# /etc/modules-load.d/k3s.conf
#
# Load kernel modules required by K3s and its CNI (Flannel/Cilium).
br_netfilter
overlay
```

#### **Kernel Parameters: `/etc/sysctl.d/99-k3s.conf`**

Sets kernel parameters required for K3s functionality and performance.

```ini
# /etc/sysctl.d/99-k3s.conf
#
# Kernel parameters for K3s on AlmaLinux 9.

# --- Networking (Required) ---
# Enable IP forwarding (CIS STIG conflict: document exception).
net.ipv4.ip_forward = 1
# Allow bridged traffic to pass through iptables (CIS STIG conflict: document exception).
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
# Set reverse path filter. '1' is strict and secure. '2' can help in complex routing scenarios.
net.ipv4.conf.all.rp_filter = 1

# --- Performance & Stability ---
# Increase max inotify instances and watches for the kubelet and other controllers.
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
# Increase max open file descriptors.
fs.file-max = 2097152
# Increase max PID count for high pod density.
kernel.pid_max = 4194304
# Increase max memory map areas, required by tools like Elasticsearch/OpenSearch.
vm.max_map_count = 524288
# Increase socket backlog for busy API server.
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
```

#### **Containerd Registry Configuration: `/etc/rancher/k3s/registries.yaml`**

Configures K3s's containerd to use a private registry (`harbor.helixstax.net`) with a custom CA (Cloudflare Origin CA).

```yaml
# /etc/rancher/k3s/registries.yaml
#
# This configures containerd to trust and use private registries.
# K3s will automatically reload containerd when this file changes.

mirrors:
  # Define a mirror for Docker Hub to a local proxy cache if you have one.
  "docker.io":
    endpoint:
      - "https://registry-1.docker.io"

  # Define our primary private registry.
  "harbor.helixstax.net":
    endpoint:
      - "https://harbor.helixstax.net"

configs:
  "harbor.helixstax.net":
    auth:
      # Auth can be configured here if not using `kubectl create secret docker-registry`.
      # username: "k3s-pull-user"
      # password: "password"
    tls:
      # Provide the CA certificate for our private registry.
      # This is the Cloudflare Origin CA certificate.
      ca_file: "/etc/ssl/certs/cloudflare_origin_ca.pem"
      # If using a client certificate for auth:
      # cert_file: "/etc/rancher/k3s/certs/harbor-client.crt"
      # key_file: "/etc/rancher/k3s/certs/harbor-client.key"
```

#### **Flannel vs. Cilium Decision Matrix**

| Criterion | Flannel | Cilium | Recommendation for Helix Stax |
| :--- | :--- | :--- | :--- |
| **Complexity** | Low. Native to K3s. "It just works." | High. Requires manual setup, eBPF knowledge. | **Flannel**. For a small 2-3 node cluster, Flannel's simplicity is a major advantage. |
| **NetworkPolicy** | No. Requires a separate policy engine (e.g., Calico). | Yes. Rich L3/L4 and L7 policies built-in. | **Cilium**. If NetworkPolicy is a day-1 requirement, Cilium is the clear winner. |
| **eBPF** | No. Standard kernel networking (VXLAN). | Yes. Core of its functionality. | **Cilium**. Offers superior performance and observability via eBPF. |
| **K3s Integration** | Native, default CNI. | Requires manual disabling of Flannel and Helm install. | **Flannel**. Zero-config integration. |
| **AlmaLinux 9 Support** | Confirmed. Works out-of-the-box. | **Confirmed**. AlmaLinux 9 ships with kernel 5.14+, which has excellent eBPF support for Cilium. | No blocker for either. |
| **Resource Overhead** | Minimal. One small daemonset. | More significant. The `cilium-agent` daemonset is larger and consumes more CPU/RAM. | **Flannel**. Lower overhead on resource-constrained cpx31 nodes. |
| **Observability** | Basic (Prometheus metrics). | **Hubble** (excellent L3-L7 flow visualization). | **Cilium**. Hubble is a game-changer for network troubleshooting. |
| **kube-proxy Replacement** | No. Relies on kube-proxy. | Yes. Can replace kube-proxy entirely for better performance. | **Cilium**. This is a significant architectural benefit. |

**Final Recommendation:** Start with **Flannel** for its native integration and simplicity. This aligns with the K3s philosophy of reducing operational complexity. Evaluate a migration to **Cilium** in the future if/when NetworkPolicy enforcement, advanced observability (Hubble), or kube-proxy replacement become critical requirements. The migration path is well-defined.

---
### ## examples.md Content

This section provides copy-paste-ready Ansible roles, runbooks, and configurations for the Helix Stax environment.

#### **Runbook: Fresh Install on `helix-stax-cp`**

This runbook details the manual steps to set up the first control-plane node. An Ansible role should automate this.

```bash
# SSH into the new server
ssh wakeem@178.156.233.12 -p 2222

# --- 1. System Prep ---
# Load kernel modules now
sudo modprobe overlay
sudo modprobe br_netfilter

# Create modules-load file for persistence
cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

# Create sysctl config file
cat <<EOF | sudo tee /etc/sysctl.d/99-k3s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter = 1
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
fs.file-max = 2097152
kernel.pid_max = 4194304
vm.max_map_count = 524288
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
EOF

# Apply sysctl settings immediately
sudo sysctl --system

# --- 2. SELinux Prep ---
# Create the Rancher RPM repo file
cat <<EOF | sudo tee /etc/yum.repos.d/rancher.repo
[rancher]
name=Rancher
baseurl=https://rpm.rancher.io/k3s/stable/el/9/x86_64
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

# Install SELinux policies (MUST be done before k3s)
sudo dnf install -y container-selinux k3s-selinux

# Set the required SELinux boolean
sudo setsebool -P container_manage_cgroup 1

# --- 3. Firewall Configuration ---
# Add K3s Control Plane rules
sudo firewall-cmd --permanent --add-port=2222/tcp # SSH
sudo firewall-cmd --permanent --add-port=6443/tcp # K8s API
sudo firewall-cmd --permanent --add-port=10250/tcp # Kubelet
sudo firewall-cmd --permanent --add-port=8472/udp # Flannel
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp # NodePorts
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/udp # NodePorts
# Open etcd ports for future HA nodes
sudo firewall-cmd --permanent --add-port=2379-2380/tcp

# Reload firewall to apply rules
sudo firewall-cmd --reload

# --- 4. K3s Configuration and Installation ---
# Create the K3s config directory
sudo mkdir -p /etc/rancher/k3s

# Create the main K3s config.yaml file
cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml
advertise-address: "178.156.233.12"
node-ip: "178.156.233.12"
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
flannel-backend: "vxlan"
disable:
  - traefik
  - servicelb
tls-san:
  - "178.156.233.12"
write-kubeconfig-mode: "0644"
cluster-init: true
etcd-snapshot-schedule-cron: "0 */12 * * *"
etcd-snapshot-retention: 5
etcd-expose-metrics: true
kube-apiserver-arg:
    - "audit-log-path=/var/log/k3s/k3s-audit.log"
    - "audit-log-maxage=30"
EOF

# Install K3s using the curl script
export INSTALL_K3S_VERSION="v1.30.2+k3s1" # Pin to a specific version
curl -sfL https://get.k3s.io | sh -

# --- 5. Post-Install Verification ---
# Wait a minute for the cluster to come up
sleep 60

# Check service status
sudo systemctl status k3s

# Check nodes (should show the CP node as Ready)
sudo k3s kubectl get nodes

# Check system pods (CoreDNS, Flannel, Metrics Server should be running or creating)
sudo k3s kubectl get pods -A

# Copy kubeconfig for local use
mkdir -p ~/.kube
sudo k3s kubectl config view --raw > ~/.kube/config
chmod 600 ~/.kube/config

# You can now use `kubectl` directly
kubectl get nodes
```

#### **Ansible Role: `k3s-server`**

```yaml
# roles/k3s-server/tasks/main.yml
- name: K3s Server | Pre-flight checks and setup
  ansible.builtin.include_tasks: preflight.yml
  tags: [k3s, k3s-server]

- name: K3s Server | Install K3s control plane
  ansible.builtin.include_tasks: install.yml
  tags: [k3s, k3s-server]

- name: K3s Server | Post-install verification
  ansible.builtin.include_tasks: verify.yml
  tags: [k3s, k3s-server]

# roles/k3s-server/tasks/preflight.yml
- name: K3s Pre-flight | Ensure required kernel modules are loaded on boot
  ansible.builtin.copy:
    dest: /etc/modules-load.d/k3s.conf
    content: |
      overlay
      br_netfilter
    mode: '0644'
  notify: Reboot server

- name: K3s Pre-flight | Ensure sysctl params are set
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/99-k3s.conf
    reload: yes
  loop:
    - { key: 'net.ipv4.ip_forward', value: '1' }
    - { key: 'net.bridge.bridge-nf-call-iptables', value: '1' }
    - { key: 'net.bridge.bridge-nf-call-ip6tables', value: '1' }

- name: K3s Pre-flight | Add Rancher RPM repository
  ansible.builtin.yum_repository:
    name: rancher-k3s
    description: Rancher K3s Stable
    baseurl: https://rpm.rancher.io/k3s/stable/el/9/x86_64
    gpgcheck: yes
    gpgkey: https://rpm.rancher.io/public.key
    enabled: yes

- name: K3s Pre-flight | Install k3s-selinux and dependencies
  ansible.builtin.dnf:
    name:
      - container-selinux
      - k3s-selinux
    state: present

- name: K3s Pre-flight | Set container_manage_cgroup SELinux boolean
  ansible.posix.seboolean:
    name: container_manage_cgroup
    state: yes
    persistent: yes

- name: K3s Pre-flight | Configure firewalld for control plane
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: true
    state: enabled
    immediate: true # Use immediate instead of a handler for simplicity
  loop:
    - "2222/tcp"  # SSH
    - "6443/tcp"  # K8s API
    - "8472/udp"  # Flannel
    - "10250/tcp" # Kubelet
    - "2379-2380/tcp" # etcd for HA

# roles/k3s-server/tasks/install.yml
- name: K3s Install | Check if k3s is already installed
  ansible.builtin.stat:
    path: /usr/local/bin/k3s
  register: k3s_binary

- name: K3s Install | Create k3s config directory
  ansible.builtin.file:
    path: /etc/rancher/k3s
    state: directory
    mode: '0755'

- name: K3s Install | Copy k3s server config.yaml
  ansible.builtin.template:
    src: config.yaml.j2
    dest: /etc/rancher/k3s/config.yaml
    mode: '0644'
  notify: Restart k3s

- name: K3s Install | Run k3s installation script
  ansible.builtin.shell:
    cmd: "curl -sfL https://get.k3s.io | sh -"
  environment:
    INSTALL_K3S_VERSION: "v1.30.2+k3s1"
    # The config.yaml file is used, so fewer env vars are needed here
  when: not k3s_binary.stat.exists

# roles/k3s-server/templates/config.yaml.j2
advertise-address: "{{ ansible_host }}"
node-ip: "{{ ansible_host }}"
cluster-init: true
tls-san:
  - "{{ ansible_host }}"
disable: ["traefik", "servicelb"]
flannel-backend: "vxlan"
write-kubeconfig-mode: "0644"
etcd-snapshot-schedule-cron: "0 */12 * * *"
etcd-snapshot-retention: 5
```

#### **Ansible Role: `k3s-agent`**

```yaml
# roles/k3s-agent/tasks/main.yml
- name: K3s Agent | Fetch join token from control plane
  ansible.builtin.set_fact:
    k3s_join_token: "{{ hostvars[groups['k3s_servers'][0]]['k3s_token_content'] }}"
  delegate_to: localhost
  run_once: true

- name: K3s Agent | Pre-flight (kernel, selinux, firewall)
  ansible.builtin.include_tasks: preflight.yml

- name: K3s Agent | Install k3s agent
  ansible.builtin.shell:
    cmd: "curl -sfL https://get.k3s.io | sh -"
  environment:
    K3S_URL: "https://{{ hostvars[groups['k3s_servers'][0]]['ansible_host'] }}:6443"
    K3S_TOKEN: "{{ k3s_join_token }}"
    INSTALL_K3S_VERSION: "v1.30.2+k3s1"
  args:
    creates: /usr/local/bin/k3s

# To get the token (run on the server node first):
# - name: K3s Server | Read node join token
#   ansible.builtin.slurp:
#     src: /var/lib/rancher/k3s/server/node-token
#   register: k3s_token_file
#
# - name: K3s Server | Set token as fact
#   ansible.builtin.set_fact:
#     k3s_token_content: "{{ k3s_token_file.content | b64decode | trim }}"
#     cacheable: yes
```

#### **Runbook: Replace Flannel with Cilium**

**WARNING:** This is a disruptive operation and will cause cluster downtime. Do not perform on a production cluster without a maintenance window and backups.

1.  **Backup Existing Cluster State**:
    *   `sudo k3s etcd-snapshot save --name pre-cilium-migration`
    *   Copy the snapshot from `/var/lib/rancher/k3s/server/db/snapshots/` to a safe location.
    *   Use Velero to back up all manifests and PVs.

2.  **Drain All Nodes**:
    *   `kubectl drain helix-stax-cp --ignore-daemonsets --delete-emptydir-data`
    *   `kubectl drain helix-stax-vps --ignore-daemonsets --delete-emptydir-data`

3.  **Uninstall K3s on ALL Nodes**:
    *   On each control plane node: `sudo /usr/local/bin/k3s-uninstall.sh`
    *   On each agent node: `sudo /usr/local/bin/k3s-agent-uninstall.sh`
    *   Clean up remaining files: `sudo rm -rf /etc/rancher/ /var/lib/rancher/`

4.  **Update K3s `config.yaml` on Control Plane**:
    *   Modify `/etc/rancher/k3s/config.yaml` on `helix-stax-cp` to disable Flannel and prepare for Cilium.

    ```yaml
    # In /etc/rancher/k3s/config.yaml
    # ... (keep other settings like advertise-address)
    
    # --- CNI Configuration for Cilium ---
    flannel-backend: "none"          # CRITICAL: Disable Flannel completely
    disable-network-policy: true     # CRITICAL: Disable K3s's built-in network policy controller
    
    # To enable Cilium's kube-proxy replacement (recommended):
    disable:
      - kube-proxy
      - traefik
      - servicelb
    ```

5.  **Re-install K3s Server**:
    *   Run the K3s install script again on `helix-stax-cp`. `curl -sfL https://get.k3s.io | sh -`. It will use the new `config.yaml`.

6.  **Mount BPF Filesystem**:
    *   Cilium requires the BPF filesystem.
    *   `sudo mount bpffs /sys/fs/bpf -t bpf`
    *   Add to `/etc/fstab` to make it permanent: `bpffs /sys/fs/bpf bpf defaults 0 0`

7.  **Install Cilium using Helm**:
    *   Add Cilium Helm repo: `helm repo add cilium https://helm.cilium.io/`
    *   Install Cilium with K3s-specific values:

    ```bash
    # Get the K3s API server endpoint
    K3S_API_EP=$(grep 'server:' /etc/rancher/k3s/k3s.yaml | sed 's/.*server: //')

    helm install cilium cilium/cilium --version 1.15.5 \
      --namespace kube-system \
      --set k8sServiceHost={{ hostvars[groups['k3s_servers'][0]]['ansible_host'] }} \
      --set k8sServicePort=6443 \
      --set kubeProxyReplacement=strict \
      --set securityContext.capabilities.ciliumAgent='{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}' \
      --set securityContext.capabilities.cleanCiliumState='{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}' \
      --set cgroup.autoMount.enabled=false \
      --set cgroup.hostRoot=/sys/fs/cgroup
    ```

8.  **Verify Cilium Status**:
    *   `kubectl -n kube-system get pods -l k8s-app=cilium`
    *   Wait for all Cilium pods to be `Running`.
    *   Run the connectivity test: `cilium connectivity test`

9.  **Re-join Agent Nodes**:
    *   On worker nodes, prepare the BPF filesystem (`mount` and `fstab`).
    *   Re-install the K3s agent using the token from the newly re-installed server.

10. **Uncordon Nodes and Restore Workloads**:
    *   `kubectl uncordon helix-stax-cp`
    *   `kubectl uncordon helix-stax-vps`
    *   Restore your workloads using Velero or re-deploying your manifests.

#### **etcd Snapshot Cron Job to MinIO**

This script can be placed in `/etc/cron.daily/` on `helix-stax-cp`.

```bash
#!/bin/bash
# /etc/cron.daily/k3s-snapshot-to-minio

# --- Configuration ---
S3_BUCKET="s3://k3s-backups"
S3_ENDPOINT="https://minio.helixstax.net"
MC_CONFIG="/home/wakeem/.mc" # Path to mc config dir
SNAPSHOT_DIR="/var/lib/rancher/k3s/server/db/snapshots"
LOG_FILE="/var/log/k3s-snapshot-upload.log"

# --- Script ---
echo "--- Starting K3s snapshot upload: $(date) ---" >> "$LOG_FILE"

# Ensure mc is configured for your MinIO instance
# Example: mc alias set minio https://minio.helixstax.net <access_key> <secret_key>

/usr/local/bin/mc --config-dir "$MC_CONFIG" cp --recursive "$SNAPSHOT_DIR/" "$S3_BUCKET/$(hostname)/" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
  echo "Successfully uploaded snapshots." >> "$LOG_FILE"
  # Optional: Prune local snapshots since they are now in S3
  # k3s etcd-snapshot delete ...
else
  echo "ERROR: Snapshot upload failed." >> "$LOG_FILE"
fi

echo "--- Finished K3s snapshot upload ---" >> "$LOG_FILE"
```
