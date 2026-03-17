# Changelog

All notable changes to the Helix Stax infrastructure are documented here.

## [0.2.0] - 2026-03-17

### Phase 1: Foundation — Services VPS

#### Added
- VPS: helix-stax-vps (cpx31, 8GB, Hillsboro/hil, 5.78.145.30, ID: 124045581)
- VPS Firewall: helix-vps-firewall (ID: 10712312) — SSH 2222 (admin IP only), HTTP, HTTPS
- Docker CE 29.3.0 on VPS (upgraded from Debian repo 20.10)
- docker-compose-plugin v5.1.0 on VPS
- fail2ban on VPS (systemd backend, sshd jail on port 2222)
- UFW on VPS: default-deny, allow 2222/80/443
- /data directories on VPS: postgres, harbor, minio, authentik
- Terraform split-location variables: cp_location (ash) + vps_location (hil)

#### Changed
- VPS replaced: cpx11 Ashburn (failed cloud-init) → cpx31 Hillsboro (manual provisioning)
  - Old: ID 124041456, cpx11, ash, 5.161.225.106
  - New: ID 124045581, cpx31, hil, 5.78.145.30
- SSH port on VPS: 22 → 2222 (dual-port approach: verified 2222 first, then removed 22)
- Local SSH config for helix-vps: Port 22 → Port 2222
- Terraform variables.tf: single `location` split into `cp_location` + `vps_location`
- VPS firewall SSH rule: 0.0.0.0/0 → admin IP only (173.40.165.150/32)
- VPS server label added: role=services

#### Fixed
- Terraform state stale entry: removed old VPS (124041456), imported real VPS (124045581)
- Terraform plan: zero drift after import + apply

### Infrastructure Cost
- VPS added: cpx31 Hillsboro ~$18/mo
- Current spend: ~$64/mo (CP + worker + VPS)

## [0.1.0] - 2026-03-17

### Phase 0: Server Hardening

#### Added
- SSH hardening on both nodes (port 2222, key-only auth, fail2ban)
- Firewall hardening via firewalld (default-deny, custom k8s-hardened zone)
- Hetzner Cloud Firewall on CP node (port 2222, 6443, 80, 443)
- Kernel tuning on worker node (sysctl, file descriptors, kubelet reservation)
- DNS fix for IPv4 nameservers on both nodes
- CIS Level 1 benchmarks passed on both nodes
- Automatic security updates (dnf-automatic) on both nodes
- Audit logging (auditd) with 25+ watch rules on both nodes
- SSH legal warning banner on both nodes

#### Changed
- Renamed heart → helix-stax-cp
- Renamed helix-worker-1 → helix-stax-worker-1
- SSH port 22 → 2222 on both nodes

#### Removed
- K3s cluster (full wipe for clean rebuild)
- Load balancer: helix-k8s-api-lb (ID: 5886481) — $6/mo saved
- Load balancer: helix-ingress-lb (ID: 5889680) — $6/mo saved
- Plaintext credentials from memory files (3 passwords scrubbed)
- All K3s residual directories (/var/lib/rancher/, /etc/rancher/, /var/lib/cni/)

#### Fixed
- SSH lockout during initial hardening attempt (Hetzner Cloud Firewall missing port 2222)
- Resolved via rescue mode — documented in 02-ssh-hardening.md execution log

#### Discovered
- Worker node has SATA SSDs (not NVMe) — I/O scheduler left as mq-deadline
- Worker already had 8GB swap partition — skipped swap file creation
- SELinux in Permissive mode on CP — semanage still required for port labeling
- firewalld not installed by default on Hetzner AlmaLinux — installed manually

### Infrastructure Cost
- Monthly savings: $12/mo (deleted 2 load balancers)
- Current spend: ~$46/mo (2 nodes, no VPS yet)
