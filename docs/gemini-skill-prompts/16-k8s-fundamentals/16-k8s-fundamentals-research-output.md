Of course. Here is the comprehensive research document for K3s, kubectl, and Kubernetes Manifests, tailored to the Helix Stax environment and formatted for your AI agents. The content is structured to be split into the three requested file types (`SKILL.md`, `reference.md`, `examples.md`) for each tool.

***

# K3s

### ## SKILL.md Content

```markdown
# K3s: AI Agent Skill File

## Core Concepts
- **K3s is lightweight Kubernetes.** Single binary, runs as a service (`k3s` or `k3s-agent`).
- **Our Setup:**
  - `helix-stax-cp` (178.156.233.12): Server (control plane)
  - `helix-stax-vps` (5.78.145.30): Agent (worker)
- **Datastore:** Embedded etcd for HA readiness.
- **CNI:** Flannel (VXLAN).
- **Ingress:** Traefik (managed by ArgoCD via Helm, K3s default is disabled).
- **Storage:** `local-path-provisioner` for ephemeral/single-node storage. Longhorn for replicated.
- **Registry Mirror:** Harbor (`harbor.helixstax.net`) configured in `/etc/rancher/k3s/registries.yaml`.


## Common Operations

### Service Management
- **Check server status:** `sudo systemctl status k3s`
- **Check agent status:** `sudo systemctl status k3s-agent`
- **Restart server:** `sudo systemctl restart k3s`
- **Restart agent:** `sudo systemctl restart k3s-agent`
- **View server logs:** `sudo journalctl -u k3s -f`
- **View agent logs:** `sudo journalctl -u k3s-agent -f`


### Node Management (via kubectl)
- **List nodes:** `kubectl get nodes -o wide`
- **Cordon a node (stop scheduling):** `kubectl cordon <node-name>`
- **Uncordon a node:** `kubectl uncordon <node-name>`
- **Drain a node for maintenance:** `kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data`
- **Check node resource usage:** `kubectl top nodes`

### Configuration
- **kubeconfig location:** `/etc/rancher/k3s/k3s.yaml`. Copy to `~/.kube/config` on your local machine.
- **Merge kubeconfigs:** `KUBECONFIG=~/.kube/config:/path/to/new/k3s.yaml kubectl config view --flatten > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config`
- **Join token location:** `/var/lib/rancher/k3s/server/node-token` on the `helix-stax-cp` node.

### Backup
- **Create an etcd snapshot:** `sudo k3s etcd-snapshot save`
- **List snapshots:** `sudo k3s etcd-snapshot ls`
- **Default snapshot location:** `/var/lib/rancher/k3s/server/db/snapshots/`

## Troubleshooting Decision Tree

| Symptom                                   | Check                                                                      | Fix / Next Step                                                                                                 |
| ----------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Worker node `NotReady`**                | `journalctl -u k3s-agent -f` on the worker. Look for connection errors.      | Verify firewall on `helix-stax-cp` allows port 6443 from `helix-stax-vps`. Check for token mismatches.                    |
| **Pods stuck `ContainerCreating`**        | `kubectl describe pod <pod-name>` to see events. `journalctl -u k3s` on node. | Often a CNI issue. Check Flannel logs. Ensure port 8472 (VXLAN) is open between nodes.                           |
| **Image pull fails (`ImagePullBackOff`)** | `kubectl describe pod <pod-name>`. Check events for registry errors.         | Verify `/etc/rancher/k3s/registries.yaml` is correct. Restart K3s (`systemctl restart k3s`) after any changes. |
| **Cluster unresponsive**                  | `sudo systemctl status k3s` on `helix-stax-cp`.                                      | Check `journalctl -u k3s -f`. If etcd issues, consider a restore.                                                 |
| **`type: LoadBalancer` pending**          | `kubectl get pods -n kube-system -l app=svclb-traefik`                       | Ensure the ServiceLB (klipper-lb) pods are running. ServiceLB is built-in; if it's not working, check K3s logs. |

## Key K3s-Specific Tools
- **Containerd CLI:** `sudo k3s crictl ps`, `sudo k3s crictl logs <id>`, `sudo k3s crictl inspect <id>`
- **Etcd Control:** `sudo k3s etcd-snapshot <save|ls|delete|prune>`
- **Kubeconfig:** The single source of truth is `/etc/rancher/k3s/k3s.yaml` on the server node.
```

### ## reference.md Content

```markdown
# K3s: Deep Reference

## A1. K3s Architecture

K3s is a highly available, certified Kubernetes distribution designed for production workloads in resource-constrained, remote locations or on IoT devices. It is packaged as a single binary of less than 100MB that includes everything needed to run a Kubernetes cluster.

### Differences from Standard K8s (kubeadm, RKE)
- **Single Binary:** `k3s` binary contains all control plane components (API server, scheduler, controller-manager) and agent components (kubelet, CNI, etc.), whereas kubeadm installs them as separate static pods/binaries.
- **Embedded Components:** K3s replaces some standard components with lightweight alternatives to reduce footprint and complexity.
- **Lightweight Footprint:** Requires significantly less RAM and CPU than a standard K8s distribution.

### K3s Embedded Components & Equivalents
| Standard K8s Component | K3s Embedded Component                          | Role                                                      | Our Status      |
| ---------------------- | ----------------------------------------------- | --------------------------------------------------------- | --------------- |
| `etcd`                 | `etcd` (default for HA) or `SQLite` (single)    | Key-value store for cluster state                         | Using `etcd`    |
| `kube-proxy`           | `kube-router` (net-pol) or `iptables/ipvs` mode | Manages Service IPs and network rules                     | Using default   |
| `CoreDNS`              | `CoreDNS`                                       | Cluster DNS and service discovery                         | Using default   |
| Ingress Controller     | `Traefik v2`                                    | Exposes HTTP/HTTPS routes from outside the cluster        | **Disabled**    |
| CNI Plugin             | `Flannel`                                       | Provides pod-to-pod networking                            | Using default   |
| Storage Provisioner    | `local-path-provisioner`                        | Dynamically provisions `hostPath`-based PVs               | Using default   |
| LoadBalancer           | `ServiceLB` (Klipper)                           | Implements `type: LoadBalancer` Services on bare metal    | Using default   |

### Server vs. Agent Roles
- **Server:** Runs the Kubernetes control plane (API Server, Controller Manager, Scheduler) and the datastore (etcd). It can also run workloads like a worker. Our `helix-stax-cp` node is a server.
- **Agent:** Runs the Kubelet, CNI, and CRI (containerd). Connects to a server to join the cluster. Our `helix-stax-vps` is an agent.

### Datastore Options
- **Embedded SQLite:** Default for single-server setups. Simple, but not HA.
- **Embedded etcd:** Used for multi-server HA clusters. K3s automates etcd clustering. **We use this (`--cluster-init`) for HA readiness.**
- **External Datastore:** `PostgreSQL`, `MySQL`. Offloads state management to an external database.

### API Server Port & Token
- **API Server Port:** `6443/tcp`. Kubelets and `kubectl` connect to this port on the server node.
- **K3s Token:** A shared secret stored at `/var/lib/rancher/k3s/server/node-token` on servers. Agents present this token to a server to securely join the cluster.

---

## A2. Installation & Initial Configuration

### Server Installation Flags (for `helix-stax-cp`)
- `--cluster-init`: Initializes a new HA cluster with embedded etcd.
- `--tls-san <IP_OR_HOSTNAME>`: Adds subject alternative names to the K3s server's TLS certificate. Critical for allowing kubectl/agents to connect via IP or DNS name. We use this for `178.156.233.12` and `helix-stax-cp.helixstax.net`.
- `--disable traefik`: Disables the built-in Traefik to allow us to manage it via Helm and ArgoCD.
- `--flannel-backend=vxlan`: Explicitly sets the Flannel backend. VXLAN is default and recommended.
- `--write-kubeconfig-mode 644`: Sets permissions on the generated kubeconfig file (`/etc/rancher/k3s/k3s.yaml`) to be readable by the user.

### Agent Installation
The agent is installed by running the K3s install script with environment variables `K3S_URL` and `K3S_TOKEN`.

### Kubeconfig
The admin kubeconfig is generated at `/etc/rancher/k3s/k3s.yaml` on the server node. To use it, copy its contents to `~/.kube/config` on your local machine or merge it with existing configurations.

### Systemd Services
- `k3s.service`: Manages the K3s server process on `helix-stax-cp`.
- `k3s-agent.service`: Manages the K3s agent process on `helix-stax-vps`.
- Use `sudo systemctl {start, stop, restart, status}` and `sudo journalctl -u {k3s, k3s-agent}` to manage them.

### Uninstall
- **Server:** `sudo /usr/local/bin/k3s-uninstall.sh`
- **Agent:** `sudo /usr/local/bin/k3s-agent-uninstall.sh`

---

## A3. K3s-Specific Features

### `registries.yaml` (Harbor Mirror)
- **Location:** `/etc/rancher/k3s/registries.yaml` on ALL nodes (server and agents).
- **Purpose:** Configures containerd to use private registries or registry mirrors. This is how we configure our Harbor instance as a pull-through cache for Docker Hub, gcr.io, etc.
- **Activation:** **Requires a restart of the K3s service on each node to take effect.**
- **Verification:** After restarting, exec into a new pod and run `crictl pull <image>`. Then check `crictl images` to see if it was pulled from your mirror.

### Traefik in K3s
- **Why we disable it:** K3s bundles a specific version of Traefik. Managing it ourselves via Helm allows for:
    1.  **Version Control:** Pinning to a specific version that works with our configurations.
    2.  **Customization:** Overriding Helm `values.yaml` for custom ports, resource limits, and enabling CRD-based configuration.
    3.  **CI/CD:** Managing its configuration declaratively via ArgoCD.

### `local-path-provisioner`
- **Function:** A built-in provisioner that dynamically creates `PersistentVolume`s using a directory on the host node (`hostPath`).
- **Default StorageClass:** `local-path`
- **Limitations:**
    - **Single Node:** Data is tied to the node where the pod is running. If the pod is rescheduled to another node, it loses access to its data.
    - **No Replication:** If the node fails, the data is lost.
- **Use Cases:**
    - **local-path:** Caching, ephemeral data, single-replica applications where data loss is acceptable.
    - **Longhorn/CloudNativePG:** Databases, stateful applications, any workload where data persistence and replication are critical.

### `ServiceLB` (Klipper)
- **Function:** Detects Services of `type: LoadBalancer` and creates a DaemonSet that exposes the service's NodePorts on the host network of each node.
- **IP Assignment:** It assigns the nodes' own IP addresses as the "external" IPs for the LoadBalancer Service.
- **Traffic Flow (Cloudflare -> Traefik):**
    1.  DNS record (`*.helixstax.net`) in Cloudflare points to `178.156.233.12`.
    2.  Cloudflare routes incoming traffic to one of those node IPs on port 443.
    3.  ServiceLB, running on that node, forwards traffic from the host's port 443 to the Traefik service's NodePort.
    4.  Traefik pod receives the traffic and routes it to the correct backend pod based on the IngressRoute.
- **Conflicts:** If you install MetalLB, you MUST disable ServiceLB by starting K3s with the `--disable-servicelb` flag to avoid conflicts over who controls LoadBalancer services.

---

## A4. Node Management

- **Labels:** Key-value pairs for organizing nodes. Used in `nodeSelector` and `affinity` rules to place pods. E.g., `topology.kubernetes.io/region=eu-central`.
- **Taints:** A property on a node that repels pods. A pod must have a matching `toleration` to be scheduled on a tainted node. Control plane nodes are typically tainted to prevent workloads.
- **Cordon:** Marks a node as unschedulable. Existing pods continue to run.
- **Drain:** Safely evicts all pods from a node, respecting PDBs. `--ignore-daemonsets` is required because DaemonSet pods are not evicted. `--delete-emptydir-data` is necessary for pods with `emptyDir` volumes.
- **Node Conditions:**
    - `Ready`: Node is healthy and ready to accept pods.
    - `MemoryPressure`: Node memory is running low. Kubernetes may start evicting pods.
    - `DiskPressure`: Node disk space is running low. Kubernetes may start evicting pods.
    - `PIDPressure`: Too many processes on the node.

---

## A5. K3s Upgrades

### `system-upgrade-controller`
- **What it is:** A Kubernetes operator that automates K3s upgrades based on a CRD called `Plan`.
- **Deployment:** Deployed via a standard YAML manifest.
- **Plan CRD:** Defines the target K3s version, which nodes to upgrade (via `nodeSelector`), and concurrency.
- **Process:** It cordons and drains each node, runs the K3s installer with the new version, uncordons the node, and moves to the next one.
- **Safety:** **Always upgrade the server (control plane) first.** The Plan for the server should have `concurrency: 1`. After the server is successfully upgraded, a separate Plan can upgrade the agents.

### Manual Upgrade
1.  **On Server (`helix-stax-cp`):** Run the installer script with the target version: `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.Y.Z sh -s - server ...`
2.  **Verify Server:** Wait for the server to come back up and be healthy. `kubectl get nodes`.
3.  **On Agents (`helix-stax-vps`):** Run the installer script on each agent: `curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... INSTALL_K3S_VERSION=vX.Y.Z sh -s -`

### Rollback
K3s does not have an official rollback mechanism. The safest way to "roll back" is to perform a manual "upgrade" to the previous version pin. **Always take an etcd snapshot before any upgrade.**

---

## A6. K3s Backup and Restore

### Embedded etcd Snapshot
- **Command:** `sudo k3s etcd-snapshot save`
- **Flags:** `--name` to specify a custom name, `--dir` to change location.
- **Scheduling:** Use a `cron` job or a `systemd` timer to take regular snapshots.
- **Storage:** Snapshots are stored locally at `/var/lib/rancher/k3s/server/db/snapshots`. These **MUST** be copied off-site (e.g., to MinIO or Backblaze B2) for disaster recovery.

### Restore from Snapshot
- **Command:** Stop K3s, then run `sudo k3s server --cluster-reset --cluster-reset-restore-path=<path_to_snapshot>`
- **What it recovers:** All Kubernetes resources (Deployments, Services, ConfigMaps, Secrets, CRDs, etc.) stored in etcd.
- **What it does NOT recover:** **Persistent Volume data.** The state of PVCs/PVs is restored, but the actual data on disk (e.g., in `/var/lib/rancher/k3s/storage/` or Longhorn volumes) is not part of the etcd snapshot.

### Velero vs. etcd Snapshot
| Tool           | What It Backs Up                                  | What It Restores                                  | Use Case                       |
| -------------- | ------------------------------------------------- | ------------------------------------------------- | ------------------------------ |
| **K3s etcd**   | The entire etcd database (K8s API objects).       | The entire cluster state to a point in time.      | **Disaster Recovery** (full cluster loss). |
| **Velero**     | K8s API objects (by querying API server) AND PV data. | Specific namespaces, resources, or full cluster.  | **Application-level backup/restore/migration.** |

---

## A7. K3s Networking

### Flannel
- **How it works:** Creates a virtual overlay network, typically using VXLAN, that spans all nodes in the cluster. Each node is assigned a subnet (`/24`) from the cluster CIDR.
- **Encapsulation:** When a pod on `helix-stax-vps` sends a packet to a pod on `helix-stax-cp`, Flannel encapsulates the packet in a UDP datagram and sends it through the VXLAN tunnel between the two nodes.
- **Firewall:** Port **`8472/udp`** must be open between all K3s nodes for Flannel VXLAN to work.

### CoreDNS
Provides service discovery. A request to `<service-name>.<namespace>.svc.cluster.local` resolves to the service's ClusterIP.

### Firewall Requirements (AlmaLinux 9.7)
Essential ports to open on `firewalld`:
- **Server (`helix-stax-cp`):**
  - `6443/tcp` (K8s API): from workers and admin locations.
  - `2379-2380/tcp` (etcd): from other servers (if HA).
  - `8472/udp` (Flannel VXLAN): from all other nodes.
  - `51820-51821/udp` (WireGuard, if used): from all other nodes.
  - Traefik ports: `80/tcp`, `443/tcp` from anywhere (Cloudflare).
- **Agent (`helix-stax-vps`):**
  - `8472/udp` (Flannel VXLAN): from all other nodes.
  - `51820-51821/udp` (WireGuard, if used): from all other nodes.
  - NodePorts `30000-32767/tcp`: from all other nodes.

### SELinux
K3s has automatic SELinux support. If you encounter permission errors, check `audit.log` for AVC denials (`ausearch -m avc -ts recent`). Proper SELinux policies are generally handled by the K3s RPMs or install script. Issues can arise with custom volume mounts.

---

## A8. K3s Troubleshooting

- **Logs are primary:** `journalctl` is the first place to look.
- **`crictl` for container runtime:** Since K3s uses containerd, `k3s crictl` is the equivalent of `docker` for inspecting containers on the node level.
- **etcd Health:** `sudo k3s etcd-snapshot ls` is a good proxy for health, as it queries etcd. For deeper checks, you need to use `etcdctl` with the correct certs from `/var/lib/rancher/k3s/server/tls/etcd/`.
- **Common Issues:**
  - **Node `NotReady` after reboot:** The K3s agent service started before networking was fully up. `sudo systemctl restart k3s-agent` usually fixes it.
  - **Flannel port blocked:** A firewall is blocking `8472/udp` between nodes.
  - **`containerd` socket not found:** The K3s service is not running or has crashed. Check `journalctl -u k3s`.
- **Recovering a crashed single control plane:** Use the `--cluster-reset` with a snapshot restore procedure described in A6.

---

## Best Practices & Decision Matrix

### Best Practices
1.  **Use embedded etcd (`--cluster-init`)** even for 2 nodes for future HA expansion.
2.  **Disable built-in components you manage yourself** (`--disable traefik`).
3.  **Automate etcd snapshots** and store them off-site.
4.  **Use the `system-upgrade-controller`** for controlled, automated upgrades.
5.  **Configure `registries.yaml` on all nodes** for a consistent container runtime environment.
6.  **Taint the control-plane node** (`kubectl taint node helix-stax-cp CriticalAddonsOnly=true:NoSchedule`) to reserve it for cluster components.
7.  **Ensure firewalls are correctly configured** for all required K3s and CNI ports.
8.  **Tag K3s versions** and upgrade on a regular schedule (e.g., quarterly).
9.  **Do not run critical stateful workloads on `local-path` storage.** Use it for caches or dev.
10. **Monitor node resources** (`MemoryPressure`, `DiskPressure`) proactively.

### Decision Matrix
| Decision                      | If...                                                              | Use...                                | Because...                                                                 |
| ----------------------------- | ------------------------------------------------------------------ | ------------------------------------- | -------------------------------------------------------------------------- |
| **Datastore**                 | You need High Availability                                         | `Embedded etcd`                       | It's built-in, simple to manage, and supports multi-server clustering.     |
| **Ingress Controller**        | You need granular control, specific versions, or custom middleware | `Helm-managed Traefik`                | The built-in Traefik is opaque and hard to customize declaratively.        |
| **Load Balancer**             | You're on bare metal and just need to expose Traefik               | `ServiceLB` (default)                 | It's zero-config and sufficient for exposing a single ingress entrypoint.  |
| **Storage for a Database**    | Data must be replicated and survive node failure                   | `Longhorn` or `CloudNativePG`         | `local-path` storage is tied to a single node and will result in data loss.|
| **Upgrading the Cluster**     | You want an automated, repeatable process                        | `system-upgrade-controller`             | It codifies the upgrade process (cordon, drain, upgrade) into a CRD.       |
| **Backing up the Cluster**    | You need to recover from a total cluster failure                 | `k3s etcd-snapshot` + off-site copy   | It's a complete, point-in-time backup of the K8s API state.                |
```

### ## examples.md Content

```markdown
# K3s: Helix Stax Examples

## A2. Installation Commands

### Install K3s Server on `helix-stax-cp` (178.156.233.12)
```bash
# This command initializes a new HA-ready cluster, sets the public IP in the TLS cert,
# disables the built-in Traefik, and makes the kubeconfig readable.
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --tls-san 178.156.233.12 \
  --tls-san helix-stax-cp.helixstax.net \
  --disable traefik \
  --write-kubeconfig-mode 644
```

### Get Join Token from `helix-stax-cp`
```bash
# Run this on 'helix-stax-cp'
sudo cat /var/lib/rancher/k3s/server/node-token
# Example output: K10abcdef1234567890::server:a1b2c3d4e5f6
```

### Install K3s Agent on `helix-stax-vps` (5.78.145.30)
```bash
# Replace <TOKEN_FROM_HELIX_STAX_CP> with the output from the previous command.
# The URL must point to the server's API port.
curl -sfL https://get.k3s.io | K3S_URL=https://178.156.233.12:6443 K3S_TOKEN="<TOKEN_FROM_HEART>" sh -
```

### Copy and Merge Kubeconfig
```bash
# 1. On your local machine, securely copy the kubeconfig from the server
# Post-hardening: use wakeem@ instead of root. Root SSH login is disabled after CIS hardening.
scp wakeem@178.156.233.12:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-helix-stax.yaml

# 2. Merge it with your existing config
export KUBECONFIG=~/.kube/config:~/.kube/k3s-helix-stax.yaml
kubectl config view --flatten > ~/.kube/config.tmp && mv ~/.kube/config.tmp ~/.kube/config

# 3. Switch to the new context
kubectl config use-context default
```

## A3. K3s-Specific Configurations

### `registries.yaml` for Harbor Mirror
This file must be created at `/etc/rancher/k3s/registries.yaml` on **all nodes** (`helix-stax-cp` and `helix-stax-vps`).

```yaml
# /etc/rancher/k3s/registries.yaml
#
# Configures containerd to use our Harbor instance as a mirror for Docker Hub
# and other public registries. Also configures authentication.

mirrors:
  # Mirror for Docker Hub
  "docker.io":
    endpoint:
      - "https://harbor.helixstax.net"

  # Mirror for Google Container Registry
  "gcr.io":
    endpoint:
      - "https://harbor.helixstax.net"

  # Mirror for Quay.io
  "quay.io":
    endpoint:
      - "https://harbor.helixstax.net"

configs:
  "harbor.helixstax.net":
    auth:
      # Username and password for the Harbor robot account used by K3s nodes
      # These credentials MUST be created in Harbor first.
      username: "k3s-pull-user"
      password: "<REPLACE_WITH_HARBOR_ROBOT_ACCOUNT_SECRET>"  # Production: inject via Ansible from OpenBao. Never commit plaintext.
    tls:
      # If Harbor uses a cert signed by a private CA, provide the CA cert here.
      # For Let's Encrypt, this is usually not needed.
      # ca_file: "/etc/rancher/k3s/certs/harbor-ca.crt"
      insecure_skip_verify: false
```
**Activation Runbook:**
1. Create the file above on `helix-stax-cp` and `helix-stax-vps`.
2. On `helix-stax-cp`: `sudo systemctl restart k3s`
3. On `helix-stax-vps`: `sudo systemctl restart k3s-agent`
4. Verify by deploying a pod with `image: busybox` and checking `k3s crictl images` on the node to see if the image source is Harbor.

## A5. Upgrade Runbook (Manual Example)

**Goal:** Upgrade the cluster from K3s `v1.27.x` to `v1.28.y`.

**Pre-flight Check:**
- `sudo k3s etcd-snapshot save --name pre-upgrade-v1.28.y`
- Copy snapshot off-site: `scp /var/lib/rancher/k3s/server/db/snapshots/pre-upgrade-v1.28.y user@backup-server:/backups/`

**Step 1: Cordon the Worker Node**
```bash
kubectl cordon helix-stax-vps
```

**Step 2: Upgrade the Server Node (`helix-stax-cp`)**
```bash
# Run on helix-stax-cp
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.y+k3s1 sh -s - server --cluster-init
```

**Step 3: Verify Server Upgrade**
```bash
# Wait a few minutes for the server to restart
watch kubectl get nodes # Wait until 'helix-stax-cp' reports the new version and is Ready
kubectl version # Check client/server versions
```

**Step 4: Upgrade the Worker Node (`helix-stax-vps`)**
```bash
# Run on helix-stax-vps
# Token and URL are remembered by the systemd service, but it's safe to include them.
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.y+k3s1 sh -
```

**Step 5: Verify Worker Upgrade & Uncordon**
```bash
watch kubectl get nodes # Wait until 'helix-stax-vps' reports the new version and is Ready
kubectl uncordon helix-stax-vps
```

## A6. Backup & Restore Runbook

### Daily Backup Cron Job
Add this to the crontab (`sudo crontab -e`) on `helix-stax-cp`.

```cron
# K3s daily etcd snapshot at 3:00 AM
0 3 * * * /usr/local/bin/k3s etcd-snapshot save
# Prune snapshots older than 7 days
0 4 * * * /usr/local/bin/k3s etcd-snapshot prune --snapshot-retention 7
# Sync snapshots to MinIO bucket
0 5 * * * /usr/local/bin/mc mirror /var/lib/rancher/k3s/server/db/snapshots/ minio/k3s-snapshots/
```

### Disaster Recovery from Snapshot (Full Cluster Restore)
**Assumptions:** `helix-stax-cp` node is destroyed and rebuilt. Snapshot `snapshot-name.zip` has been recovered from off-site backup.

1. **Install K3s with restore flags on the new `helix-stax-cp` node.**
   ```bash
   # Place the snapshot file in a known location, e.g., /root/snapshot-name.zip
   # Stop k3s if it's running
   sudo systemctl stop k3s

   # Run the server with the restore command
   sudo k3s server \
     --cluster-reset \
     --cluster-reset-restore-path=/root/snapshot-name.zip
   ```

2. **Start the K3s service.**
   ```bash
   sudo systemctl start k3s
   ```

3. **Verify the cluster state.**
   ```bash
   kubectl get nodes # The old worker will be NotReady
   kubectl get all -A # All the etcd-backed resources should be present
   ```

4. **Re-join the worker node.**
   - You may need to delete the old worker node object: `kubectl delete node helix-stax-vps`
   - Uninstall and reinstall k3s-agent on `helix-stax-vps` (5.78.145.30) using the new token from the restored server.

## A7. Firewall Configuration (AlmaLinux 9.7 `firewalld`)

### On `helix-stax-cp` (Server)
```bash
# Allow K8s API from worker and admin networks
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="5.78.145.30" port protocol="tcp" port="6443" accept'
# Allow Flannel VXLAN from worker
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="5.78.145.30" port protocol="udp" port="8472" accept'
# Allow Traefik ingress from anywhere
sudo firewall-cmd --permanent --add-port={80/tcp,443/tcp}
# Reload firewall
sudo firewall-cmd --reload
```

### On `helix-stax-vps` (Agent)
```bash
# Allow Flannel VXLAN from server
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="178.156.233.12" port protocol="udp" port="8472" accept'
# Reload firewall
sudo firewall-cmd --reload
```
```

***

# kubectl

### ## SKILL.md Content

```markdown
# kubectl: AI Agent Skill File

## Configuration & Context
- **View current context:** `kubectl config current-context`
- **List all contexts:** `kubectl config get-contexts`
- **Switch context:** `kubectl config use-context <context-name>`
- **Set default namespace for current context:** `kubectl config set-context --current --namespace=<ns>`
- **Merge kubeconfig:** `KUBECONFIG=~/.kube/config:new-config.yaml kubectl config view --flatten > ~/.kube/config.new`

## Resource Inspection (Read-Only)
- **Get resources (all namespaces):** `kubectl get <resource> -A` (e.g., `kubectl get pods -A`)
- **Get with more details:** `kubectl get <resource> <name> -o wide`
- **Get as YAML/JSON:** `kubectl get <resource> <name> -o yaml`
- **List all resources in a namespace:** `kubectl get all -n <ns>`
- **Describe resource (shows events):** `kubectl describe <resource> <name> -n <ns>` **(CRITICAL FOR DEBUGGING)**
- **Explain a manifest field:** `kubectl explain deployment.spec.strategy`

**Common Short Names:** `po`, `svc`, `deploy`, `rs`, `ds`, `sts`, `cm`, `ns`, `pvc`, `pv`, `ing`, `netpol`

## Debugging Pods & Workloads
- **View pod logs:** `kubectl logs <pod-name> -n <ns>`
- **Follow pod logs:** `kubectl logs -f <pod-name> -n <ns>`
- **Logs for a specific container:** `kubectl logs <pod-name> -c <container-name>`
- **Logs for previous crashed container:** `kubectl logs --previous <pod-name>`
- **Exec into a container:** `kubectl exec -it <pod-name> -n <ns> -- /bin/sh`
- **Run a single command in a container:** `kubectl exec <pod-name> -- ls /app`
- **Forward a local port to a pod/service:** `kubectl port-forward svc/<service-name> 8080:80`
- **Check resource usage:** `kubectl top pods -A` or `kubectl top nodes`
- **Get all events in namespace (sorted):** `kubectl get events -n <ns> --sort-by=.lastTimestamp`

## Creating & Modifying Resources
- **Declarative Apply (BEST PRACTICE):** `kubectl apply -f <filename.yaml>`
- **Apply all files in a directory:** `kubectl apply -k <directory>` or `kubectl apply -f <dir> -R`
- **Dry run (client-side validation):** `kubectl apply -f <file> --dry-run=client`
- **Dry run (server-side, runs webhooks):** `kubectl apply -f <file> --dry-run=server`
- **See what `apply` will change:** `kubectl diff -f <file>`
- **Delete resource:** `kubectl delete <resource> <name>`
- **Force delete a stuck pod:** `kubectl delete pod <name> --grace-period=0 --force`

## Rollout Management
- **Check rollout status:** `kubectl rollout status deployment/<name>`
- **View rollout history:** `kubectl rollout history deployment/<name>`
- **Rollback to previous version:** `kubectl rollout undo deployment/<name>`
- **Rollback to a specific revision:** `kubectl rollout undo deployment/<name> --to-revision=2`
- **Trigger a rolling restart:** `kubectl rollout restart deployment/<name>` (Picks up updated a ConfigMap/Secret that is not auto-reloaded).

## RBAC & Permissions
- **Check your permissions:** `kubectl auth can-i <verb> <resource> -n <ns>` (e.g., `kubectl auth can-i create deployments -n default`)
- **List all your permissions in a namespace:** `kubectl auth can-i --list -n <ns>`
```

### ## reference.md Content

```markdown
# kubectl: Deep Reference

`kubectl` is the command-line tool for interacting with the Kubernetes API server. It allows introspection, management, and troubleshooting of all cluster resources.

## B1. Configuration and Context Management

The `kubectl` configuration is stored in a file known as the `kubeconfig` file.
- **Default Location:** `~/.kube/config`
- **Structure:** A YAML file containing:
    - `clusters`: Defines cluster endpoints and an alias (e.g., `k3s-helix-stax`, `cluster-url`, `certificate-authority-data`).
    - `users`: Defines authenticated users (e.g., `admin-user`, `client-certificate-data`, `token`).
    - `contexts`: Binds a `cluster` with a `user` and an optional default `namespace`. This is what you switch between.
- **Merging:** The `KUBECONFIG` environment variable can take a colon-separated list of paths. `kubectl` merges them in order. The command `kubectl config view --flatten` is used to consolidate these into a single file.
- **CI/CD Kubeconfig:** For ArgoCD/Devtron, never use a full-privilege admin kubeconfig. Instead, create a `ServiceAccount`, bind it to a `Role` or `ClusterRole` with the minimum necessary permissions (`RoleBinding`/`ClusterRoleBinding`), and generate a token for that ServiceAccount to use as the `user` token in the kubeconfig.

## B2. Resource Inspection Commands

### `kubectl get`
The cornerstone for reading state.
- **Flags:**
    - `-o <format>`: Output format.
        - `wide`: Adds extra columns (Node, IP, etc.).
        - `yaml`, `json`: Full resource definition.
        - `jsonpath='<template>'`: Extracts specific fields from JSON output.
        - `custom-columns=<spec>`: Defines custom table columns from resource fields.
    - `-A` or `--all-namespaces`: Gets resources from all namespaces.
    - `-n, --namespace <ns>`: Specifies a namespace.
    - `-l, --selector <label-query>`: Filters resources by label (e.g., `-l app=nginx,env=prod`).
    - `--field-selector <field-query>`: Filters resources by field (e.g., `--field-selector status.phase=Running`).
    - `-w, --watch`: Watches for changes to the resource(s).

### `kubectl describe`
Provides a detailed, human-readable summary of a resource. Its most valuable section is `Events`, which shows a log of actions and errors related to the resource (e.g., scheduling failures, image pull errors, probe failures). **Always run `describe` on a failing pod.**

### `kubectl explain`
Acts as built-in API documentation. It can describe the fields of any resource kind.
- `kubectl explain pods`: High-level fields of a Pod.
- `kubectl explain pod.spec.containers`: Details about the containers array within a pod spec.

### `kubectl api-resources` & `api-versions`
- `api-resources`: Lists all resource types known to the API server, including their short names, `APIGroup`, and whether they are namespaced.
- `api-versions`: Lists all the available API groups (e.g., `apps/v1`, `traefik.io/v1alpha1`).

## B3. Log and Debugging Commands

- **`kubectl logs <pod> [-c <container>]`**:
    - `-f`: Stream logs live (follow).
    - `--previous`: Show logs from the previous, terminated instance of the container (essential for debugging crash loops).
    - `--tail=N`: Show the last `N` lines.
    - `--since=T`: Show logs since a duration (e.g., `10s`, `5m`, `2h`).
- **`kubectl exec -it <pod> -- <shell>`**: Provides an interactive TTY session inside the container.
- **`kubectl port-forward <resource>/<name> <local>:<remote>`**: Creates a tunnel from your local machine to a port inside the cluster. Useful for accessing a database or web UI that isn't exposed publicly.
- **`kubectl cp <pod>:<path> <local-path>`**: Copies files/directories between a pod and your local filesystem.
- **`kubectl debug` (K8s 1.23+):** A powerful command to attach an ephemeral "debug" container to a running pod. This is useful when the original container image doesn't have debugging tools (like `curl`, `netcat`, etc.). `kubectl debug mypod -it --image=busybox --target=main-app-container`.

## B4. Apply, Create, Delete, Patch

- **`apply` vs `create`:** `apply` is declarative. It merges the supplied manifest with the live object. If the object doesn't exist, it creates it. If it exists, it updates it. `create` is imperative. It will fail if the object already exists. **In GitOps, always use `apply`.**
- **`diff`:** Shows a `diff` of what `apply` *would* do without changing anything. Invaluable for preventing mistakes.
- **Dry Runs:**
    - `client`: Only validates the YAML syntax and basic structure on your machine.
    - `server`: Sends the object to the API server, which runs full validation and admission webhooks (like Kyverno) but does not persist the object. **This is a true pre-flight check.**
- **`delete`:**
    - `--grace-period=0 --force`: Forcefully deletes a Pod that is stuck in a `Terminating` state. This can be dangerous and should be a last resort, as it doesn't wait for the application to shut down gracefully.
- **`patch`:** Used for making small, targeted changes to a live object.
    - **Strategic Merge Patch:** The default for `kubectl patch`. It's a "smart" merge that understands Kubernetes list types (e.g., it can update a container in a pod spec by name).
    - **JSON Merge Patch (`--type=merge`):** A simple merge where the patch overwrites fields. Arrays in the patch will completely replace arrays in the target object.
    - **JSON Patch (`--type=json`):** A surgical patch format (RFC 6902) using operations like `add`, `replace`, `remove` with a specific path.
- **`replace`:** Replaces the entire live object with the one specified in the file. It will fail if fields that cannot be changed are different. It's more destructive than `apply` and rarely used.
- **`edit`:** Opens the live resource's YAML in your default editor. When you save, it applies the changes. **AVOID in a GitOps workflow.** Useful for quick-and-dirty debugging in a dev cluster.

## B5. Rollout Management

These commands primarily target `Deployment`, `StatefulSet`, and `DaemonSet` resources.
- `rollout status`: Blocks until the rollout is complete (all new pods are `Ready`) or fails.
- `rollout history`: Shows a list of revisions (changes to the pod template). `kubectl rollout history deploy/myapp --revision=3` shows the details of that specific revision.
- `rollout undo`: Reverts the pod template to the previous revision and triggers a new rollout.
- `rollout restart`: Performs a rolling update by creating a new `ReplicaSet` with the exact same pod template. This is the correct way to force pods to restart and pick up changes from modified `ConfigMaps` or `Secrets` that are not automatically reloaded.

## B6. RBAC and Access Control

- **`auth can-i`**: The ultimate tool for debugging permission issues. The `--as` flag is powerful for impersonating another user or a ServiceAccount to check *their* permissions.
- **Imperative vs. Declarative RBAC:** You can create roles/bindings with commands like `kubectl create rolebinding ...`, but for production, these should always be defined as YAML manifests and applied via GitOps for auditability and consistency.

## B7. Output Formatting and Scripting

- **JSONPath**: A query language for extracting data from JSON. Essential for scripting. The syntax `{.items[*].metadata.name}` iterates through the `items` array and pulls the `name` from each `metadata` object.
- **Custom Columns**: `kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName`. A simpler way to create custom tables without complex JSONPath.
- **Piping to `jq`**: For complex JSON manipulation, `kubectl get ... -o json | jq '<query>'` is more powerful and readable than complex JSONPath.
- **`--label-columns`**: Adds columns to the output for any specified labels.
- **`--sort-by`**: Sorts the output list based on a JSONPath field. E.g., `kubectl get pods --sort-by=.metadata.creationTimestamp`.

## B8. Useful `krew` Plugins

`krew` is the official plugin manager for `kubectl`.
- `kubectl krew install <plugin>`
- **ctx:** Fast context switching.
- **ns:** Fast namespace switching.
- **neat:** Cleans up cluttered YAML output from `kubectl get -o yaml` by removing system-generated fields.
- **stern / tail:** Tail logs from multiple pods at once based on a selector. `stern -l app=my-app`.
- **tree:** Shows the ownership hierarchy of resources (e.g., Deployment -> ReplicaSet -> Pod).
- **who-can:** A reverse `auth can-i`. Shows which users/groups can perform an action.
- **images:** Lists all container images running in the cluster.

### Common Pitfalls
- **Using `kubectl edit` in production:** Breaks the GitOps loop and leads to configuration drift.
- **Forgetting `-n <namespace>`:** Accidentally creating/deleting resources in the `default` namespace.
- **Using `--grace-period=0 --force` carelessly:** Can lead to data corruption in stateful applications.
- **Confusing `apply` with `replace`:** `replace` can be destructive. Stick to `apply`.
- **Ignoring the `Events` section in `kubectl describe`:** It's the #1 place to find the root cause of pod failures.
```

### ## examples.md Content

```markdown
# kubectl: Helix Stax Examples

## B1. Context Management

```bash
# Assume k3s-helix-stax.yaml was copied from the 'helix-stax-cp' node.
# Rename the context for clarity
kubectl config rename-context default helix-stax-prod

# Switch to our production context
kubectl config use-context helix-stax-prod

# Set the default namespace for this context to 'argocd' for easy management
kubectl config set-context --current --namespace=argocd
```

## B2. Resource Inspection Examples

```bash
# Get all pods across the cluster, showing which node they are on
kubectl get pods -A -o wide

# Check the status of our Traefik deployment in its namespace
kubectl get deployment traefik -n traefik -o wide

# Describe the Zitadel statefulset to see recent events
kubectl describe statefulset zitadel -n identity

# Get the full YAML for our public gateway IngressRoute, cleaning it up for readability
kubectl get ingressroute -n traefik public-gateway -o yaml | kubectl neat

# List all CRDs related to Traefik
kubectl get crd -l app.kubernetes.io/name=traefik

# Find out the short name for 'ingressroutetcp'
kubectl api-resources | grep ingressroutetcp
# Output: ingressroutetcps, irt   traefik.io/v1alpha1   true         IngressRouteTCP
```

## B3. Debugging Examples

```bash
# A pod in the 'rocketchat' namespace is CrashLooping. Find out why.
# 1. Get the exact pod name
kubectl get pods -n rocketchat

# 2. Describe the pod to see events
kubectl describe pod rocketchat-xxxxxxxx-yyyyy -n rocketchat
# Look at Events section for clues like 'Back-off restarting failed container'

# 3. Check logs of the *previous*, crashed container
kubectl logs --previous rocketchat-xxxxxxxx-yyyyy -n rocketchat
# This will show the application's panic/error message right before it exited.

# 4. If the container is running but misbehaving, get a shell inside it
kubectl exec -it -n identity statefulset/zitadel-0 -- /bin/bash

# Port-forward the ArgoCD UI to your local machine for access over a secure tunnel
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Now you can access https://localhost:8080

# The NeuVector enforcer DaemonSet pod on 'helix-stax-vps' is failing. Check its logs.
# First, find the pod name on that node.
POD_NAME=$(kubectl get pods -n neuvector --field-selector spec.nodeName=helix-stax-vps -l app=neuvector-enforcer-pod -o jsonpath='{.items[0].metadata.name}')

# Then get its logs
kubectl logs $POD_NAME -n neuvector

# Check CPU and Memory usage for pods in the monitoring namespace
kubectl top pods -n monitoring
```

## B4 & B5. Apply and Rollout Examples

```bash
# We have a change for Outline in our Git repo. Let's see what will change.
# (Assuming manifest is at ./apps/outline/deployment.yaml)
kubectl diff -f ./apps/outline/deployment.yaml

# The diff looks good. Apply it.
kubectl apply -f ./apps/outline/deployment.yaml

# Now watch the rollout to make sure it completes successfully.
kubectl rollout status deployment/outline -n outline

# Oh no! The new version has a bug. Let's roll back immediately.
kubectl rollout undo deployment/outline -n outline

# We just updated a ConfigMap for n8n, but the pods don't auto-reload.
# Trigger a rolling restart to force them to pick up the new config.
kubectl rollout restart deployment/n8n -n n8n
```

## B6. RBAC Examples

```bash
# Can the ArgoCD ServiceAccount in the 'argocd' namespace deploy apps into the 'n8n' namespace?
kubectl auth can-i create deployments -n n8n --as=system:serviceaccount:argocd:argocd-application-controller

# What all can the default service account in the 'dev' namespace do?
kubectl auth can-i --list -n dev --as=system:serviceaccount:dev:default
# This should be a very short list, hopefully empty.
```

## B7. Output Formatting & Scripting Examples

```bash
# Get a list of all pod names in the cluster
kubectl get pods -A -o jsonpath='{.items[*].metadata.name}'

# Create a custom table of pods, their node, and their IP address
kubectl get pods -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP"

# Get all PVCs sorted by the amount of storage they requested
kubectl get pvc -A --sort-by=.spec.resources.requests.storage

# List all running container images and their versions using the 'images' krew plugin
kubectl images

# Tail logs for all Zitadel pods at once using 'stern'
stern -n identity zitadel
```
```

***

# YAML / Kubernetes Manifests

### ## SKILL.md Content

```markdown
# YAML / K8s Manifests: AI Agent Skill File

## Core Structure
Every K8s manifest has four top-level fields:
- `apiVersion`: Which K8s API to use (e.g., `apps/v1`, `v1`, `traefik.io/v1alpha1`).
- `kind`: The type of resource (e.g., `Deployment`, `Service`, `IngressRoute`).
- `metadata`: Data about the resource (name, namespace, labels, annotations).
- `spec`: The desired state of the resource.

---

## Core Workload Resources

### Deployment
- **Use for:** Stateless applications (frontends, APIs, etc).
- **Key Spec Fields:**
    - `replicas`: Number of pods.
    - `selector`: `matchLabels` must match labels in the pod `template`.
    - `template`: The pod specification.
        - `metadata.labels`: Labels for the pod.
        - `spec.containers`: List of containers to run.
            - `name`, `image`, `ports`.
            - `env`/`envFrom`: Environment variables.
            - `volumeMounts`: Where to mount volumes.
            - `resources`: `requests` (for scheduling) and `limits` (for throttling/killing).
            - `livenessProbe`/`readinessProbe`: Health checks.

### StatefulSet
- **Use for:** Stateful applications needing stable identity (databases, message queues).
- **Key Spec Fields:**
    - `serviceName`: Must match the name of a **Headless Service**.
    - `replicas`, `selector`, `template`: Same as Deployment.
    - `volumeClaimTemplates`: A template for a PVC. Each pod replica gets its own PVC based on this template (e.g., `data-zitadel-0`, `data-zitadel-1`).

### DaemonSet
- **Use for:** Running one pod on every (or selected) node. (e.g., NeuVector Enforcer, logging agents).
- **Key Spec Fields:**
    - No `replicas` field.
    - `template` and `selector` are the same as Deployment.
    - Use `spec.template.spec.tolerations` to run on control-plane nodes.

---

## Networking Resources

### Service
- **Use for:** Stable internal endpoint for a set of pods.
- **Key Spec `type`:**
    - `ClusterIP`: (Default) Internal IP only.
    - `LoadBalancer`: Exposes the service externally. In K3s, ServiceLB provides a node IP.
    - `ExternalName`: CNAME alias to an external domain.
- **Key Spec Fields:**
    - `selector`: Must match the labels of the pods to send traffic to.
    - `ports`: Maps a service port to a pod `targetPort`.

### Traefik IngressRoute (CRD) - `traefik.io/v1alpha1`
- **Use for:** Exposing HTTP/S services to the outside world. **We use this, not standard Ingress.**
- **Key Spec Fields:**
    - `entryPoints`: Which Traefik ports to listen on (e.g., `websecure`).
    - `routes`: List of routing rules.
        - `match`: The rule (e.g., `Host(\`app.helixstax.com\`) && PathPrefix(\`/api\`)`).
        - `services`: The backend K8s Service to send traffic to.
        - `middlewares`: Apply middleware like auth, redirects, etc.
    - `tls`: TLS configuration.
        - `certResolver`: Tells Traefik to use `letsencrypt` (for public) or our internal resolver.

---

## Configuration & Storage

### ConfigMap / Secret
- **Use for:** Decoupling configuration/secrets from pods.
- **Consumption:**
    - `envFrom`: Mount all keys as environment variables.
    - `valueFrom`: Mount a single key as an environment variable.
    - `volumes`: Mount as files in the container.
- **BEST PRACTICE:** Never store raw `Secret` YAML in Git. `ExternalSecretsOperator` creates them from OpenBao.

### PersistentVolumeClaim (PVC)
- **Use for:** Requesting persistent storage for a pod.
- **Key Spec Fields:**
    - `accessModes`: [`ReadWriteOnce`]. RWO is the only mode supported by `local-path` and most block storage.
    - `storageClassName`: Which provisioner to use (`local-path` for node-local, `longhorn` for replicated).
    - `resources.requests.storage`: Amount of storage needed (e.g., `10Gi`).

---

## Debugging Workflow
1.  **YAML Linting:** Check indentation (2 spaces, no tabs).
2.  **Dry Run:** `kubectl apply -f my-app.yaml --dry-run=server`. This will catch typos, invalid fields, and admission controller rejections (Kyverno policies).
3.  **Check Events:** If a pod is `Pending` or `ImagePullBackOff`, run `kubectl describe pod <name>` and look at the `Events` section at the bottom.
4.  **Check Logs:** If a pod is `CrashLoopBackOff`, run `kubectl logs --previous <name>` to see why it died.
```

### ## reference.md Content

```markdown
# YAML / K8s Manifests: Deep Reference

## C1. Core Workload Resources

### `Deployment` (`apps/v1`)
The standard for managing stateless applications.
- **`spec.strategy`**: Defines how updates are rolled out.
    - `type: RollingUpdate` (default).
    - `rollingUpdate.maxUnavailable`: Max number of pods that can be unavailable during an update. Can be a number or percentage. E.g., `25%`.
    - `rollingUpdate.maxSurge`: Max number of extra pods that can be created above the desired replica count. Can be a number or percentage. E.g., `25%`.
- **`spec.template.spec`
