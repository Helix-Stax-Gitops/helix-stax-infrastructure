# Gemini Deep Research: K3s on AlmaLinux 9 — Installation, SELinux, and CNI

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

K3s is a lightweight, CNCF-certified Kubernetes distribution maintained by Rancher/SUSE. It packages Kubernetes, containerd, Flannel, CoreDNS, Traefik (we disable the bundled one), local-path-provisioner, and a SQLite/etcd backend into a single binary under 100MB. K3s is designed for edge, IoT, and resource-constrained environments — but it is fully production-capable and is our chosen Kubernetes distribution for Helix Stax because it reduces operational complexity without sacrificing compatibility.

Running K3s on a CIS-hardened AlmaLinux 9.7 system introduces specific challenges:
- **SELinux enforcing**: K3s and containerd must be allowed by SELinux policy (via the `k3s-selinux` package)
- **Kernel parameters**: K3s requires parameters that CIS hardening disables (ip_forward, bridge-nf-call)
- **Firewalld**: K3s needs specific ports open across nodes
- **Flannel vs Cilium**: CNI choice has implications for networking policy, eBPF, and kernel version requirements

Understanding the exact installation steps, required kernel parameters, SELinux policy requirements, and CNI trade-offs is essential before writing any Ansible role.

## Our Specific Setup

- **OS**: AlmaLinux 9.7 (RHEL 9.7-compatible)
- **K3s version**: Latest stable (track v1.29+ or v1.30+ depending on current release)
- **Nodes**:
  - helix-stax-cp (178.156.233.12, cpx31, Hetzner Ashburn) — Control Plane
  - helix-stax-vps (5.78.145.30, cpx31, Hetzner Hillsboro) — Worker or secondary role TBD
  - helix-stax-test (cx22, temporary) — Validation target
- **SSH port**: 2222 (affects firewalld and Ansible connection)
- **Admin user**: `wakeem`
- **SELinux**: Enforcing, targeted policy — mandatory, never disable
- **Firewall**: `firewalld` — NOT iptables directly
- **CNI**: Flannel VXLAN (current), evaluating Cilium
- **Bundled Traefik**: Disabled (`--disable=traefik`) — we deploy our own via Helm
- **Bundled ServiceLB**: Disable if using MetalLB or Cloudflare Tunnel instead
- **TLS**: Cloudflare Origin CA (15-year certs) — NO cert-manager, NO Let's Encrypt
- **IaC**: Ansible installs K3s after OpenTofu provisions the Hetzner servers
- **Backup**: etcd snapshots to MinIO, Velero for workload backup

---

## What I Need Researched

---

### K3S-1. Installation Methods

K3s can be installed via the curl install script or offline. Document both fully:

**Online Install (curl script):**
- Exact command: `curl -sfL https://get.k3s.io | sh -` — environment variables that control behavior
- All `INSTALL_K3S_*` environment variables: `INSTALL_K3S_VERSION`, `INSTALL_K3S_CHANNEL`, `INSTALL_K3S_EXEC`, `INSTALL_K3S_NAME`, `INSTALL_K3S_TYPE` (server vs agent), `INSTALL_K3S_SKIP_ENABLE`, `INSTALL_K3S_SKIP_START`
- `K3S_*` environment variables: `K3S_TOKEN`, `K3S_URL`, `K3S_KUBECONFIG_MODE`, `K3S_NODE_NAME`, `K3S_RESOLV_CONF`, `K3S_DATASTORE_ENDPOINT`
- How the install script detects AlmaLinux 9 vs Ubuntu — does it use different package managers or just binary install?
- Where K3s binary is placed (`/usr/local/bin/k3s`), where config lives (`/etc/rancher/k3s/config.yaml`)
- Where the systemd service unit file is placed and its contents
- Install script idempotency: can you run it twice safely? What happens if already installed?

**Offline Install:**
- Downloading the K3s binary and images for offline install
- Required files: `k3s` binary, `k3s-airgap-images-amd64.tar.gz` (or `.tar`)
- Where to place airgap images: `/var/lib/rancher/k3s/agent/images/`
- Ansible task to copy binary and images, set permissions, create systemd unit
- Why offline install matters for Hetzner servers: if you provision a server with firewalld blocking outbound, you need offline install or pre-open outbound temporarily

**Ansible Implementation:**
- Using `ansible.builtin.get_url` vs `ansible.builtin.shell` with curl
- Recommended pattern: use `ansible.builtin.shell` with the install script piped to `sh`, or use a dedicated `xanmanning.k3s` Ansible role?
- Environment variable passing in Ansible shell tasks
- Idempotency: how to check if K3s is already installed before running installer (`stat /usr/local/bin/k3s`)

---

### K3S-2. SELinux and K3s

This is the most likely source of subtle failures on a hardened AlmaLinux 9 system. Document exhaustively:

**k3s-selinux package:**
- What is `k3s-selinux` and what does it provide?
- How to install it: the Rancher RPM repository URL for AlmaLinux 9 (BaseOS architecture, exact `.repo` file)
- Must `k3s-selinux` be installed BEFORE or AFTER K3s itself?
- Package contents: what SELinux policy modules are included
- Version compatibility: which `k3s-selinux` version matches which K3s version?
- Ansible tasks: add Rancher repo, install `container-selinux` (dependency), install `k3s-selinux`

**Required SELinux booleans:**
- `container_manage_cgroup`: what it allows, why K3s needs it, `setsebool -P container_manage_cgroup 1`
- `virt_use_samba`, `virt_use_nfs`: needed if pods mount NFS/SMB volumes (likely not initially)
- Any other booleans K3s or containerd require on RHEL 9
- How to discover needed booleans: using `audit2allow` on AVC denials from K3s startup

**Known AVC denials:**
- Common AVC denials seen during K3s startup on RHEL 9 systems (research GitHub issues and bug trackers)
- AVC denials related to containerd creating container namespaces
- AVC denials related to Flannel creating VXLAN interfaces
- AVC denials related to K3s writing to `/var/lib/rancher/`
- How to use `ausearch -m AVC -ts recent` to find denials after K3s starts
- `audit2allow -a -M k3s-local` workflow: generating a local policy module for any remaining denials
- Loading the policy module: `semodule -i k3s-local.pp`

**Containerd and SELinux:**
- How containerd handles SELinux labeling of container mounts
- `containerd` configuration for SELinux: where this is configured in K3s's bundled containerd
- `container_selinux` vs `k3s-selinux` package relationship

---

### K3S-3. Kernel Parameters for K3s

Document every kernel parameter K3s requires, the CIS conflict status, and the exact `sysctl` configuration:

**Required by K3s (may conflict with CIS hardening):**
- `net.ipv4.ip_forward = 1` — K3s requirement, CIS says 0 — resolution: apply exception, document in compliance record
- `net.bridge.bridge-nf-call-iptables = 1` — required for Flannel/iptables rules
- `net.bridge.bridge-nf-call-ip6tables = 1` — required for IPv6 CNI operations
- These require the `br_netfilter` kernel module to be loaded — how to ensure this on AlmaLinux 9 (`/etc/modules-load.d/`)
- `net.ipv4.conf.all.rp_filter = 0` or `= 1` — does Flannel VXLAN require loose RP filter?

**Required by K3s for performance/stability at scale:**
- `fs.inotify.max_user_instances = 8192` (or higher)
- `fs.inotify.max_user_watches = 524288`
- `fs.file-max` — maximum open file descriptors
- `kernel.pid_max = 4194304` — high pod count nodes need more PIDs
- `vm.max_map_count = 524288` — required by Elasticsearch/OpenSearch-based tools; worth setting proactively
- `net.core.somaxconn = 32768` — better socket backlog for busy API server
- `net.ipv4.tcp_max_syn_backlog` — related

**AlmaLinux 9 defaults that need verification:**
- Are any of these parameters already set to the correct values in AlmaLinux 9 default kernel config?
- Does the AlmaLinux 9 kernel ship with `br_netfilter` enabled by default or does it need to be loaded?

**Ansible implementation:**
- Using `ansible.posix.sysctl` module for runtime + persistent settings
- Using `/etc/sysctl.d/99-k3s.conf` for K3s-specific parameters
- Using `/etc/modules-load.d/k3s.conf` to auto-load `br_netfilter` and `overlay` modules
- Task ordering: load modules first, then apply sysctl

---

### K3S-4. K3s Server Configuration Flags

K3s server (control plane) has extensive configuration options. Document all flags relevant to our setup:

**Configuration file format:**
- `/etc/rancher/k3s/config.yaml` — YAML format, preferred over command-line flags
- How environment variables map to config file keys
- Precedence: config file vs environment variable vs command-line flag

**Control plane flags we use:**
- `--disable=traefik` — disable bundled Traefik, we deploy our own
- `--disable=servicelb` — disable bundled ServiceLB (we use Cloudflare Tunnel)
- `--flannel-backend=vxlan` — explicit VXLAN backend for Flannel
- `--write-kubeconfig-mode=644` — allow non-root to read kubeconfig
- `--tls-san=<IP>` — add Hetzner server IP to TLS SAN so external kubectl works
- `--advertise-address=<IP>` — set the IP that the API server advertises to agents
- `--node-ip=<IP>` — node's internal IP for Flannel
- `--cluster-cidr=10.42.0.0/16` — pod CIDR (default, confirm or change)
- `--service-cidr=10.43.0.0/16` — service CIDR (default, confirm or change)
- `--cluster-dns=10.43.0.10` — CoreDNS cluster IP (default)
- `--datastore-endpoint` — for external PostgreSQL datastore (future HA setup)
- `--etcd-expose-metrics` — expose etcd metrics to Prometheus
- `--kube-apiserver-arg=audit-log-path=/var/log/k3s-audit.log` — K8s audit log
- `--kube-apiserver-arg=audit-policy-file=/etc/rancher/k3s/audit-policy.yaml` — K8s audit policy

**Token and authentication:**
- `K3S_TOKEN`: how it's generated, where it's stored on the server (`/var/lib/rancher/k3s/server/node-token`)
- How to read it in Ansible: `ansible.builtin.slurp` module on the token file
- Token rotation: is it possible, what breaks if you change it

---

### K3S-5. K3s Agent (Worker Node) Setup

- K3s agent installation command with environment variables: `K3S_URL`, `K3S_TOKEN`, `K3S_NODE_NAME`
- Agent-specific flags: `--node-label`, `--node-taint`, `--flannel-iface` (to specify correct network interface)
- How the agent registers with the server: TLS bootstrap, node approval
- Verifying agent joined: `kubectl get nodes` from CP — what the output should look like
- Agent-specific SELinux requirements: same as server or different?
- Firewalld on agent node: ports needed for agent (kubelet 10250, Flannel 8472/UDP)
- Multi-NIC gotcha: Hetzner servers have public and sometimes private NICs — how to tell K3s which interface to use for Flannel (`--flannel-iface`)

---

### K3S-6. Firewalld Ports for K3s

Provide the complete firewalld rule set for each node type:

**Control Plane node (helix-stax-cp):**
- 2222/TCP: SSH (our port)
- 6443/TCP: K3s API server (Kubernetes API)
- 2379-2380/TCP: etcd peer communication (if running etcd, CP only)
- 10250/TCP: kubelet API (metrics, logs)
- 10257/TCP: kube-controller-manager (if exposing metrics)
- 10259/TCP: kube-scheduler (if exposing metrics)
- 8472/UDP: Flannel VXLAN (between all cluster nodes)
- 51820/UDP: WireGuard (if K3s uses WireGuard backend instead of VXLAN)
- 5001/TCP: Embedded registry (if enabled)
- 30000-32767/TCP+UDP: NodePort services
- 9100/TCP: Node Exporter (Prometheus scrape)

**Worker/Agent node (helix-stax-vps):**
- 2222/TCP: SSH
- 10250/TCP: kubelet API
- 8472/UDP: Flannel VXLAN
- 51820/UDP: WireGuard (if applicable)
- 30000-32767/TCP+UDP: NodePort services
- 9100/TCP: Node Exporter

**Ansible tasks using `ansible.posix.firewalld`:**
- Complete task list for each port with `permanent: true` and `immediate: true`
- Zone handling: which zone to add rules to (`public` vs custom zone)
- Source IP restriction: limiting 6443/TCP to specific management IPs
- Firewall reload handler

---

### K3S-7. Flannel vs Cilium CNI Evaluation

Provide an objective comparison for our specific use case (K3s on AlmaLinux 9, 2-3 nodes, Hetzner Cloud):

**Flannel (current):**
- What Flannel provides: L3 networking over VXLAN, no NetworkPolicy support natively
- Backend options available in K3s: `vxlan` (default), `wireguard-native`, `host-gw`, `ipsec`, `none`
- VXLAN backend: how it works, UDP port 8472, encapsulation overhead
- WireGuard backend (`wireguard-native`): encrypted overlay, requires WireGuard kernel module on AlmaLinux 9 — is it available?
- Flannel limitations: no NetworkPolicy enforcement (requires separate policy engine), no eBPF, no bandwidth management
- Performance: overhead vs direct routing
- AlmaLinux 9 compatibility: any known issues?

**Cilium:**
- What Cilium provides: eBPF-based networking, NetworkPolicy, L7 policy, Hubble observability, kube-proxy replacement
- K3s + Cilium setup: how to replace Flannel with Cilium on K3s (must use `--flannel-backend=none --disable-network-policy`)
- Cilium installation on K3s: Helm chart, required K3s flags, mounting eBPF filesystem
- Kernel requirements: minimum kernel version for Cilium eBPF features — does AlmaLinux 9.7's kernel meet them?
- AlmaLinux 9.7 kernel version: what kernel ships with AlmaLinux 9.7? Does it support Cilium's required eBPF features?
- kube-proxy replacement with Cilium: `--disable=kube-proxy` in K3s, Cilium replaces it
- Hubble: network observability built into Cilium — integration with our Prometheus/Grafana stack
- Cilium eBPF and SELinux: does SELinux interfere with Cilium's eBPF programs? Required booleans or policy exceptions?
- Resource overhead: Cilium vs Flannel on a cpx31 (4 vCPU, 8GB RAM) node

**Decision matrix:**

| Criterion | Flannel | Cilium | Recommendation |
|---|---|---|---|
| Complexity | Low | High | |
| NetworkPolicy | No (needs Calico/Cilium) | Yes (built-in) | |
| eBPF | No | Yes | |
| K3s integration | Native, default | Requires manual setup | |
| AlmaLinux 9 support | Confirmed | Needs kernel version check | |
| 2-node cluster overhead | Minimal | More (DaemonSet per node) | |
| Observability | Basic | Hubble (excellent) | |
| kube-proxy replacement | No | Yes (optional) | |

---

### K3S-8. Replacing Flannel with Cilium on K3s

If we decide to use Cilium, document the exact steps:

- Required K3s server flags: `--flannel-backend=none`, `--disable-network-policy`, `--disable=kube-proxy` (optional for full kube-proxy replacement)
- Mounting BPF filesystem: does K3s handle this automatically or must we add it to `/etc/fstab`?
- Cilium Helm chart installation: exact values needed for K3s compatibility (`kubeProxyReplacement`, `k8sServiceHost`, `k8sServicePort`)
- Cilium CLI (`cilium` CLI tool): connectivity test command, status check
- Hubble relay and UI: how to deploy, how to access via Traefik IngressRoute
- CNI migration: can you migrate from Flannel to Cilium on a running cluster without downtime? Procedure if not.
- Cilium + Hetzner Cloud: any Hetzner-specific networking considerations (private networks, HCCM)?

---

### K3S-9. K3s Upgrades

How to safely upgrade K3s across a multi-node cluster:

**system-upgrade-controller:**
- What it is: a K3s-native upgrade controller that applies K3s upgrades via Plans
- How to deploy: Helm chart or manifest
- `Plan` CRD: defining an upgrade plan for server and agent nodes
- Upgrade sequence: server first, then agents — how the controller manages this
- Rollback: what happens if upgrade fails mid-way

**Ansible re-run approach:**
- Running the K3s install script again with a new version pinned
- Draining nodes before upgrade: `kubectl drain` in Ansible using `kubernetes.core.k8s_drain`
- Testing the new version on helix-stax-test before rolling to helix-stax-cp
- Rollback: downgrading K3s by re-running install script with older version pin

**Upgrade decision matrix:**
When to use system-upgrade-controller vs Ansible: criteria and recommendation.

---

### K3S-10. K3s Backup and Restore (etcd)

K3s uses an embedded etcd by default (or SQLite for single-node). Document:

**Embedded etcd (recommended for HA):**
- When K3s uses embedded etcd vs SQLite: cluster init flag `--cluster-init`
- Automatic snapshots: `--etcd-snapshot-schedule-cron`, `--etcd-snapshot-retention`, `--etcd-snapshot-dir`
- Manual snapshot: `k3s etcd-snapshot save`
- Where snapshots are stored by default: `/var/lib/rancher/k3s/server/db/snapshots/`
- Ansible task to copy snapshots to MinIO: using `aws s3 cp` or `mc cp` in a cron job

**Restore procedure:**
- Stopping K3s on all nodes
- `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`
- Restarting K3s
- Re-joining agents after restore
- Full step-by-step runbook

**SQLite (single-node setup):**
- Where SQLite database lives: `/var/lib/rancher/k3s/server/db/state.db`
- Backup: copying the SQLite file (K3s must be stopped or using WAL mode backup)
- Restore: replacing the file

---

### K3S-11. Containerd Configuration on AlmaLinux 9

K3s bundles containerd. Document:

- Containerd config file location in K3s: `/var/lib/rancher/k3s/agent/etc/containerd/config.toml`
- The `config.toml.tmpl` pattern: how K3s generates containerd config from a template
- Configuring containerd to use Harbor as private registry mirror
- Registries configuration: `/etc/rancher/k3s/registries.yaml` — format for mirrors and TLS
- Our Harbor registry (`harbor.helixstax.net`): how to configure K3s to pull from it with Cloudflare Origin CA cert
- Containerd cgroup driver: `systemd` vs `cgroupfs` — which does AlmaLinux 9 require?
- cgroup v2: AlmaLinux 9 uses cgroup v2 by default — does K3s handle this correctly?
- Containerd snapshotter: `overlayfs` vs `native` — which works with SELinux enforcing on AlmaLinux 9?

---

### K3S-12. Traefik Deployment After K3s

We disable the bundled Traefik and deploy our own via Helm. Document the handoff:

- `--disable=traefik` flag: what exactly this disables (the Helm chart auto-deployment, not the binary)
- When to deploy our Traefik: after K3s is running and core services (CoreDNS) are healthy
- Traefik v3 Helm chart: repository URL, chart name, required values for our setup
- IngressRoute CRD installation: does the Helm chart install them, or do we need a separate CRDs manifest?
- Traefik and Cloudflare Origin CA: how to configure Traefik to serve Cloudflare Origin certs
- Traefik and Zitadel ForwardAuth: middleware configuration for SSO
- Post-K3s-install verification: `kubectl get pods -n kube-system` — expected healthy pods (CoreDNS, Flannel, metrics-server, local-path-provisioner)
- What is NOT present after `--disable=traefik`: confirming Traefik is absent before deploying ours

---

### K3S-13. CrowdSec Alongside K3s

CrowdSec Security Engine runs as a host-level daemon alongside K3s. Document:

- CrowdSec on AlmaLinux 9.7: dnf repo, package name (`crowdsec`), service name
- CrowdSec and K3s log sources: configuring CrowdSec to read K3s logs (`/var/log/k3s.log` or journald)
- K3s log location: how K3s logs by default on systemd — `journalctl -u k3s`
- Configuring CrowdSec to read journald: `acquis.yaml` `journalctl_filter` configuration
- CrowdSec collections for K3s: is there a `crowdsecurity/k3s` collection? What about Kubernetes API audit logs?
- Firewall bouncer: `crowdsec-firewall-bouncer` integration with `firewalld` — does it create `firewalld` rich rules?
- SELinux and CrowdSec: known AVC denials when CrowdSec runs under SELinux enforcing mode
- CrowdSec and Traefik (in-cluster): the CrowdSec Traefik bouncer Helm chart — for blocking at the ingress level
- LAPI setup: running CrowdSec LAPI on helix-stax-cp, other nodes register as Security Engine agents

---

### Best Practices & Anti-Patterns

- What are the top 10 best practices for K3s on hardened AlmaLinux 9 in production?
- What are the most common mistakes when installing K3s on a CIS-hardened system? Rank by severity.
- What K3s configurations look correct but silently cause problems on SELinux enforcing systems?
- What are the performance anti-patterns for K3s on a 2-3 node cluster (over-provisioning, under-provisioning etcd, etc.)?
- When does K3s's embedded etcd become a problem vs using an external PostgreSQL datastore?
- What is the correct boot order: harden OS, then install K3s? Or install K3s, then verify it works, then apply remaining hardening?

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| Flannel vs Cilium | Small cluster (<5 nodes), no L7 policy needed | Flannel | Lower complexity, native K3s support |
| Flannel vs Cilium | NetworkPolicy enforcement needed | Cilium | Flannel has no NetworkPolicy |
| Flannel vs Cilium | AlmaLinux 9 kernel too old for Cilium eBPF | Flannel | Cilium eBPF requires kernel 4.19.57+ (minimum), 5.10+ preferred |
| etcd vs SQLite | Multi-node HA cluster | etcd (`--cluster-init`) | SQLite is single-writer only |
| etcd vs SQLite | Single-node dev setup | SQLite | Lower overhead |
| system-upgrade-controller vs Ansible | Regular cadence upgrades | system-upgrade-controller | Automated, K3s-native |
| system-upgrade-controller vs Ansible | Major version upgrade or testing first | Ansible | More control, test on helix-stax-test first |
| Online install vs offline | Normal network-accessible server | Online (curl) | Simpler, always gets correct version |
| Online install vs offline | Air-gapped or security-restricted | Offline | Required when outbound blocked |
| `--disable=traefik` | Always on our nodes | Always | We deploy Traefik v3 ourselves |
| `--disable=servicelb` | Using Cloudflare Tunnel | Disable | ServiceLB not needed |

### Common Pitfalls

- Forgetting `k3s-selinux` package: K3s starts but containers fail to run under SELinux enforcing
- Missing `br_netfilter` module: Flannel VXLAN fails silently; pods can't communicate across nodes
- Wrong `--flannel-iface`: K3s picks the wrong network interface on multi-NIC Hetzner nodes, causing broken pod networking
- Applying `/var` `noexec` mount option before K3s installs: K3s writes executables under `/var/lib/rancher/`
- Token confusion: K3s agent uses `K3S_TOKEN` (join token at `/var/lib/rancher/k3s/server/node-token`), NOT the kubeconfig credential
- Kubeconfig `127.0.0.1` issue: K3s writes `server: https://127.0.0.1:6443` in kubeconfig — must replace with actual CP IP for external kubectl access
- `--disable=traefik` timing: flag must be set at first K3s server start — cannot be toggled after initial install without manual Helm uninstall
- cgroup v2 on AlmaLinux 9: some older containerd configs expect cgroup v1 — verify cgroup version and containerd cgroup driver match
- Firewalld not reloaded after adding rules: `firewall-cmd --reload` required for rules to take effect even with `permanent: true`
- SELinux AVC denials during K3s startup that go unnoticed: check `ausearch -m AVC` after first start

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- K3s CLI quick reference (`k3s server`, `k3s agent`, `k3s kubectl`, `k3s etcd-snapshot`, `k3s crictl`)
- SELinux setup checklist: required packages, booleans, AVC denial resolution
- Firewalld port reference table (CP node vs agent node)
- Kernel parameter reference (CIS vs K3s, conflict resolution)
- Troubleshooting decision tree (K3s won't start → diagnosis → fix)
- Integration points: Ansible, OpenTofu, Traefik, CrowdSec, Harbor
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete K3s server config.yaml with all relevant flags documented
- Complete K3s agent config.yaml
- Complete firewalld rule set for CP and agent nodes
- Complete kernel parameter set (`/etc/sysctl.d/99-k3s.conf`) with CIS conflict notes
- Complete `/etc/modules-load.d/k3s.conf` for required kernel modules
- Complete Flannel vs Cilium comparison matrix
- K3s etcd backup and restore procedure
- Containerd registries.yaml for Harbor integration
- Cilium installation values.yaml for K3s (if using Cilium)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (178.156.233.12, 5.78.145.30), port 2222, user `wakeem`
- Complete Ansible `k3s-server` role: pre-flight checks, SELinux setup, kernel params, K3s install, post-install verification
- Complete Ansible `k3s-agent` role: token retrieval, agent install, verification
- Annotated `config.yaml` for helix-stax-cp with all our flags explained
- `registries.yaml` configured for Harbor at `harbor.helixstax.net` with Cloudflare Origin CA
- Step-by-step runbook: "Fresh K3s install on CIS-hardened AlmaLinux 9"
- Step-by-step runbook: "Replacing Flannel with Cilium on running K3s cluster"
- etcd snapshot cron job and MinIO upload script

Use `# K3s on AlmaLinux 9` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual K3s config files, actual firewalld commands, actual SELinux commands, and actual Ansible tasks. Do NOT give theory — give copy-paste-ready configurations and Ansible roles for K3s on hardened AlmaLinux 9.7 on Hetzner Cloud.
