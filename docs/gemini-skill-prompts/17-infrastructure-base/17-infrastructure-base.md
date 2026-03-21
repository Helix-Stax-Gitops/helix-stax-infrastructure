# Gemini Deep Research: Infrastructure Base (AlmaLinux 9.7 + Networking + Hetzner Cloud)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
This group covers the physical and OS layer that everything else sits on. AlmaLinux 9.7 is our hardened server OS (CIS Benchmark Level 2, SELinux enforcing). Hetzner Cloud is our VPS provider (CX32 nodes in the EU, private networking). Networking fundamentals cover everything from kernel-level packet routing to Flannel VXLAN overlays in K3s. You cannot debug K3s, Traefik, or Zitadel issues without understanding all three layers simultaneously.

## Our Specific Setup
- **Nodes**: heart (control plane, 178.156.233.12), helix-worker-1 (worker, 138.201.131.157) — both CX32 on Hetzner Cloud
- **OS**: AlmaLinux 9.7, SELinux enforcing, firewalld active, CIS Benchmark Level 1/2 hardened
- **K3s**: Flannel CNI (VXLAN mode), CoreDNS, Traefik ingress
- **Private network**: Hetzner private network 10.0.0.0/16, nodes communicate over private IPs
- **IaC**: Hetzner provisioned via OpenTofu, hardened via Ansible
- **DNS**: Internal resolution via CoreDNS in K3s, external via Cloudflare
- **Domains**: helixstax.com (public/Cloudflare), helixstax.net (internal apps)
- **TLS**: cert-manager issues certs inside cluster, Cloudflare handles edge TLS
- **Secrets**: OpenBao (Vault-compatible), External Secrets Operator

## What I Need Researched

### AlmaLinux 9.7 — systemd

- Complete systemd unit file anatomy: `[Unit]`, `[Service]`, `[Install]` sections with all relevant directives
- Service management: `systemctl start/stop/restart/reload/enable/disable/mask/unmask/daemon-reload`
- Status and introspection: `systemctl status`, `systemctl show`, `systemctl list-units`, `systemctl list-timers`
- journalctl: `-u <unit>`, `-f` (follow), `-n <lines>`, `--since`/`--until`, `-p err`, `--no-pager`, `-x` (catalog), `--disk-usage`, `--vacuum-size`
- systemd timers: writing `.timer` units as cron replacements, `OnCalendar=` syntax, `Persistent=true` for missed runs
- Dependencies and ordering: `Wants=`, `Requires=`, `After=`, `Before=`, `PartOf=`, `BindsTo=`
- Drop-in overrides: `/etc/systemd/system/<unit>.d/override.conf` — when to use vs editing the unit directly
- Resource control in units: `CPUQuota=`, `MemoryLimit=`, `IOWeight=`, cgroup v2 integration
- Security hardening directives: `NoNewPrivileges=`, `PrivateTmp=`, `ProtectSystem=`, `ReadOnlyPaths=`, `User=`, `Group=`
- Troubleshooting: units stuck in `activating`, `failed` state debugging, dependency hell, circular dependency detection

### AlmaLinux 9.7 — SELinux

- Core concepts: enforcing vs permissive vs disabled, types, domains, contexts, booleans, policies
- `getenforce` / `setenforce` / `sestatus` — checking and toggling mode
- Context inspection: `ls -Z`, `ps -Z`, `id -Z`, `stat --printf=%C`
- `chcon` vs `semanage fcontext` vs `restorecon` — which to use when and why
- `audit2allow`: reading `/var/log/audit/audit.log`, generating `.te` policy modules, compiling and installing with `semodule`
- `audit2why`: translating AVC denials to human-readable explanations
- `semanage`: managing ports (`semanage port -a -t http_port_t -p tcp 8080`), file contexts, booleans
- Common booleans for our stack: `httpd_can_network_connect`, `container_manage_cgroup`, `virt_use_fusefs`
- Troubleshooting K3s on SELinux: common AVC denials for Flannel, Traefik, container runtimes (containerd)
- SELinux + Hetzner volumes: context issues when mounting block devices
- Policy modules for custom services: `.te`, `.fc`, `.if` file structure, `make -f /usr/share/selinux/devel/Makefile`
- When SELinux should be set to permissive temporarily vs permanently for a domain

### AlmaLinux 9.7 — firewalld

- Zone model: `public`, `trusted`, `internal`, `dmz` — which zone for which interface
- `firewall-cmd` reference: `--list-all`, `--add-service`, `--add-port`, `--add-rich-rule`, `--remove-*`, `--permanent`, `--reload`
- Services vs ports: defining custom services in `/etc/firewalld/services/`
- Rich rules syntax: source IP filtering, destination, port, action (`accept`, `reject`, `drop`), logging
- Port forwarding: `--add-forward-port=port=80:proto=tcp:toport=8080:toaddr=`
- K3s-specific rules: ports required for API server (6443), flannel VXLAN (8472/udp), NodePort range (30000-32767), Kubelet (10250), etcd (2379-2380)
- Hetzner firewall vs firewalld: layered defense — Hetzner blocks at cloud level, firewalld at OS level
- Masquerading: `--add-masquerade` for pod-to-external traffic through Flannel
- Direct rules (nftables backend): when firewalld is insufficient and you need raw nftables
- Troubleshooting: `firewall-cmd --list-all-zones`, `nft list ruleset`, connectivity lost after `--reload`

### AlmaLinux 9.7 — dnf and Package Management

- dnf basics: `install`, `remove`, `update`, `upgrade`, `downgrade`, `search`, `info`, `list installed`
- Repo management: `/etc/yum.repos.d/`, `dnf repolist`, `dnf config-manager --enable/--disable`
- EPEL, PowerTools/CRB for AlmaLinux 9: enabling correctly
- Security updates only: `dnf upgrade --security`, `dnf updateinfo list security`
- dnf-automatic: unattended security updates config (`/etc/dnf/automatic.conf`)
- Package groups: `dnf groupinstall`, `dnf grouplist`
- Version locking: `dnf versionlock add/remove/list`
- Rollback: `dnf history`, `dnf history undo <id>`
- Offline/air-gapped: `dnf download --resolve`, `createrepo`, local repo setup
- Verifying package integrity: `rpm -V <package>`, `rpm --import` GPG keys

### AlmaLinux 9.7 — System Tuning and Security

- cgroups v2: verifying it's enabled, systemd slice hierarchy, resource limits per service
- /proc and /sys tuning: `sysctl` parameters for K3s (`net.bridge.bridge-nf-call-iptables=1`, `net.ipv4.ip_forward=1`, `vm.max_map_count`), `/etc/sysctl.d/` drop-ins
- SSH hardening: `/etc/ssh/sshd_config` — disable root login, PasswordAuthentication no, AllowUsers, ClientAliveInterval, MaxAuthTries, Protocol 2, key algorithms
- User management: `useradd`, `usermod`, `groupadd`, sudoers (`/etc/sudoers.d/`), `visudo`, principle of least privilege
- CIS Benchmark Level 1/2 on AlmaLinux 9: what's actually enforced, what breaks K3s, required exemptions for container workloads
- Log rotation: `/etc/logrotate.d/`, `logrotate -d` (dry run), forcing rotation, journal size limits
- Time sync: chronyd config (`/etc/chrony.conf`), `chronyc sources`, `chronyc tracking`, NTP pool selection
- Auditd: `/etc/audit/auditd.conf`, `auditctl -l`, writing rules for file access monitoring

### Networking — iptables/nftables and Traffic Analysis

- nftables basics: tables, chains, rules — `nft list ruleset`, `nft add rule`, priority values
- iptables compatibility shim on AlmaLinux 9: `iptables-legacy` vs `iptables-nft`
- K3s and iptables: how K3s/kube-proxy writes iptables rules, `iptables -L -n -v --line-numbers`, KUBE-SERVICES chain
- tcpdump: capturing on specific interface (`-i eth0`), port filter (`port 6443`), writing to pcap, reading back, `-n` no DNS, host filter
- ss: `ss -tlnp` (TCP listening with process), `ss -s` (summary), replacing netstat
- dig: `dig @8.8.8.8 helixstax.com A`, `+short`, `+trace`, `+dnssec`, reverse lookup (`-x`), SOA, MX, TXT queries
- systemd-resolved: `/etc/systemd/resolved.conf`, `resolvectl status`, `resolvectl query`, DNS-over-TLS config
- DNS resolution order on AlmaLinux 9: `/etc/nsswitch.conf`, `/etc/resolv.conf` (symlink to stub), split DNS with `[Resolve]` per-link
- TLS/certificate debugging: `openssl s_client -connect host:443 -servername host`, `openssl x509 -text -noout -in cert.pem`, chain verification, `openssl verify`
- MTU and jumbo frames: detecting MTU issues (`ping -M do -s 1472`), Flannel VXLAN MTU (1450), setting MTU on Hetzner private network interfaces
- Network namespaces: `ip netns list`, entering a pod network namespace via `nsenter`

### Networking — Flannel VXLAN and CoreDNS

- Flannel VXLAN mode: how VTEP devices work, VXLAN packet encapsulation overhead (50 bytes), debugging with `bridge fdb show`
- Flannel troubleshooting: pod-to-pod connectivity failures, checking `flannel.1` interface, `ip route` for pod CIDR routes
- CoreDNS in K3s: ConfigMap location (`kube-system/coredns`), Corefile syntax, adding custom upstream resolvers, `ndots` setting impact, debugging with `kubectl exec -- nslookup`
- DNS debugging in pods: `kubectl run -it --rm debug --image=busybox --restart=Never -- sh`, `nslookup`, `dig` inside pod
- Hetzner private network routing: adding static routes, `ip route add`, ensuring inter-node pod traffic stays on private network

### Hetzner Cloud — hcloud CLI

- Authentication: `hcloud context create`, `HCLOUD_TOKEN` env var, `~/.config/hcloud/cli.toml`
- Server management: `hcloud server list`, `create`, `delete`, `reboot`, `reset`, `shutdown`, `rebuild`, `describe`
- Server create reference: `--type cx32`, `--image alma-linux-9`, `--location ash` (Ashburn), `--network`, `--ssh-key`, `--user-data-from-file`
- Network management: `hcloud network list`, `create`, `add-subnet`, `add-route`, attach server
- Firewall management: `hcloud firewall list`, `create`, `add-rule`, `apply-to-server`, rule syntax (inbound/outbound, protocol, port, source IPs)
- Volume management: `hcloud volume list`, `create --size 40 --server heart`, `attach`, `detach`, `resize`, formatting and mounting
- SSH key management: `hcloud ssh-key list`, `create --name key --public-key-from-file ~/.ssh/id_ed25519.pub`
- Snapshots and images: `hcloud server create-image --type snapshot`, `hcloud image list --type snapshot`, restoring from snapshot
- Load balancer: `hcloud load-balancer create`, `add-target`, `add-service`, health check config
- Server metrics: `hcloud server metrics --type cpu,disk,network heart`
- Rescue mode: enabling, booting into rescue, accessing filesystem from rescue environment
- cloud-init user data: `/etc/cloud/cloud.cfg`, running scripts on first boot, debugging via `/var/log/cloud-init.log`

### Hetzner Cloud — Architecture and Cost

- CX32 specs: 4 vCPU, 8GB RAM, 80GB NVMe — right-sizing for K3s control plane vs worker
- Private networks: 10.0.0.0/16 CIDR, subnets per zone, inter-node latency on private vs public
- Hetzner firewall rules that must be open for K3s: 6443 (API), 8472/udp (Flannel), 10250 (Kubelet metrics), 2379-2380 (etcd), 30000-32767 (NodePort)
- Volume performance: IOPS limits on Hetzner volumes, when to use local NVMe vs volumes, fstype choice (xfs vs ext4)
- Cost model: CX32 hourly/monthly, volume pricing, snapshot pricing, private network (free), load balancer pricing, bandwidth (free within datacenter)
- Snapshot strategy: pre-change snapshots before K3s upgrades, automated snapshots via API/cron
- Hetzner API: REST API v1, authentication header, rate limits, useful endpoints for automation
- OpenTofu provider: `hcloud` provider reference, resource types (`hcloud_server`, `hcloud_network`, `hcloud_firewall`, `hcloud_volume`, `hcloud_ssh_key`)

## Required Output Format

Structure your response EXACTLY like this — it will be split into separate skill files for AI agents. Use `# Tool Name` as top-level headers so the output can be mechanically split:

```markdown
# AlmaLinux 9.7

## Overview
[2-3 sentence description]

## systemd
### Unit File Anatomy
[directives, examples]
### Service Management
[commands with examples]
### Timers
[.timer unit examples]
### Troubleshooting
[failed units, dependency issues]

## SELinux
### Core Concepts
[types, domains, contexts]
### Context Management
[chcon vs semanage vs restorecon]
### audit2allow Workflow
[full AVC denial -> policy module workflow]
### K3s-Specific Denials
[common denials and fixes]
### Troubleshooting
[commands and patterns]

## firewalld
### Zone Model
[zone assignments]
### firewall-cmd Reference
[commands with examples]
### K3s Required Rules
[exact commands for K3s ports]
### Rich Rules
[syntax examples]
### Troubleshooting
[common issues]

## Package Management (dnf)
### Common Commands
[install, remove, update patterns]
### Security Updates
[dnf-automatic, security-only updates]
### Repo Management
[EPEL, CRB, custom repos]
### Troubleshooting
[history, rollback]

## System Tuning
### sysctl for K3s
[exact parameters and values]
### SSH Hardening
[sshd_config directives]
### CIS Benchmark Exemptions
[what breaks K3s and how to exempt]
### chronyd
[time sync commands]

# Networking

## Overview
[2-3 sentence description]

## nftables / iptables
### nftables Basics
[tables, chains, rules]
### K3s iptables Rules
[kube-proxy chains, debugging]

## Traffic Analysis
### tcpdump
[capture commands for K3s debugging]
### ss
[socket inspection commands]

## DNS Debugging
### dig Reference
[query patterns]
### systemd-resolved
[config and debugging]
### CoreDNS in K3s
[ConfigMap, Corefile, debugging]
### Pod DNS Debugging
[kubectl exec patterns]

## TLS Debugging
### openssl Commands
[s_client, x509, verify]
### Certificate Chain Debugging
[common failures and fixes]

## Flannel VXLAN
### Architecture
[VTEP, encapsulation, MTU]
### Troubleshooting
[connectivity failures, route debugging]

## Network Namespaces
### Pod Namespace Access
[nsenter patterns]

# Hetzner Cloud

## Overview
[2-3 sentence description]

## hcloud CLI Reference
### Authentication
[context, token]
### Server Management
[create, list, reboot, delete with examples]
### Network Management
[private network commands]
### Firewall Management
[rule creation, K3s required rules]
### Volume Management
[create, attach, format, mount]
### Snapshots
[create, restore workflow]

## cloud-init
### User Data Structure
[script examples for AlmaLinux bootstrap]
### Debugging
[log locations]

## OpenTofu Provider
### Resource Reference
[hcloud_server, hcloud_network, hcloud_firewall, hcloud_volume examples]

## Architecture Decisions
### Node Sizing
[CX32 right-sizing rationale]
### Private Network Design
[CIDR, routing, inter-node]
### Firewall Layering
[Hetzner cloud firewall + firewalld strategy]

## Cost Model
[pricing breakdown, optimization tips]

## Troubleshooting
[rescue mode, console access, common failures]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual config snippets, and actual error messages where relevant. Do NOT give theory — give copy-paste-ready commands and configs for AlmaLinux 9.7 nodes running K3s on Hetzner Cloud. Assume SELinux is enforcing and firewalld is active at all times.
