# Gemini Deep Research: CIS AlmaLinux 9 Benchmark — Level 1 Hardening Reference

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

The CIS (Center for Internet Security) Benchmark for AlmaLinux 9 is the authoritative hardening standard for RHEL-compatible Linux systems. It defines prescriptive configuration guidance organized into numbered controls across security domains (filesystem, services, network, auditing, access control, etc.). Level 1 is the baseline — controls that can be applied to any production server without significant operational impact. Level 2 adds more aggressive hardening suited for high-security environments.

This benchmark is the hardening bible for Helix Stax servers. Every Ansible role we write for OS-level hardening is derived directly from CIS controls. The benchmark covers:

- **What to disable**: Unused filesystems, services, protocols
- **What to configure**: SSH, PAM, sysctl, auditd, firewalld, SELinux
- **What to verify**: Post-hardening compliance scanning with CIS-CAT

K3s introduces complications because it requires certain kernel parameters and behaviors that conflict with strict CIS controls (IP forwarding, bridge-nf-call-iptables, container cgroup management). Knowing exactly which controls to apply, which to skip, and how to document exceptions is critical before Ansible roles are written.

## Our Specific Setup

- **OS**: AlmaLinux 9.7 (RHEL 9-compatible — controls that differ from CentOS 7/8 must be flagged)
- **K3s**: Runs on hardened nodes — some CIS controls MUST be skipped or modified for K3s compatibility
- **SELinux**: Must remain `enforcing` with `targeted` policy — never permissive or disabled
- **Firewall**: `firewalld` (NOT iptables directly) — CIS firewalld controls apply
- **SSH port**: 2222 (NOT 22 — SSH port control must reflect this)
- **Admin user**: `wakeem` (NOT root — PermitRootLogin must be `no`)
- **Ansible**: Hardening implemented as Ansible roles — every control must map to a specific Ansible module and task
- **Compliance target**: NIST CSF v2.0 + CIS Controls v8 (Level 1 is minimum viable compliance baseline)
- **Servers**: helix-stax-cp (178.156.233.12, cpx31), helix-stax-vps (5.78.145.30, cpx31), helix-stax-test (cx22, temporary)
- **Scanning**: CIS-CAT Lite (free) or OpenSCAP for post-hardening validation

---

## What I Need Researched

---

### CIS-1. Complete Level 1 Control List

Provide the complete CIS AlmaLinux 9 Level 1 control list organized by section. For each control:

- Control number (e.g., 1.1.1.1)
- Control name/title
- What it does (one sentence)
- Ansible module to implement it
- Verification command to confirm it is applied
- Whether it conflicts with K3s (yes/no — flag conflicts prominently)

Sections to cover:

**Section 1: Initial Setup**
- 1.1.x Filesystem Configuration (cramfs, squashfs, udf — disabled kernel modules; /tmp, /var/tmp, /dev/shm mount options)
- 1.2.x Configure Software Updates (dnf-automatic, GPG verification)
- 1.3.x Filesystem Integrity Checking (AIDE or equivalent)
- 1.4.x Secure Boot Settings (GRUB password, UEFI)
- 1.5.x Additional Process Hardening (core dumps, ASLR, ptrace)
- 1.6.x Mandatory Access Control (SELinux type, mode, packages)
- 1.7.x Warning Banners (motd, login banners)

**Section 2: Services**
- 2.1.x Special Purpose Services (disabling time services, cupsd, avahi, dhcpd, DNS, FTP, LDAP, NFS, RPC, etc.)
- 2.2.x Service Clients (disabling telnet-client, rsh, ldap-utils, etc.)
- 2.3.x Nonessential Services (ensuring only required services run)

**Section 3: Network Configuration**
- 3.1.x Disable unused protocols (IPv6 if not needed, DCCP, SCTP, RDS, TIPC)
- 3.2.x Network Parameters (host only — IP forwarding, send redirects)
- 3.3.x Network Parameters (host and router — accept redirects, source route, ICMP)
- 3.4.x Uncommon Network Protocols
- 3.5.x Firewall Configuration (firewalld rules, default deny)

**Section 4: Logging and Auditing**
- 4.1.x Auditd configuration (enable, configure, rules)
- 4.1.x Audit rules (specific syscalls, file watches)
- 4.2.x Logging (rsyslog, journald configuration)

**Section 5: Access, Authentication, and Authorization**
- 5.1.x Cron/at restrictions
- 5.2.x SSH Server Configuration (every sshd_config directive)
- 5.3.x Configure PAM (pam_pwquality, pam_pwhistory, account lockout, su restriction)
- 5.4.x User Accounts and Environments (root account, password settings, PATH, umask)
- 5.5.x User Accounts (inactive accounts, password expiry, system accounts)

**Section 6: System Maintenance**
- 6.1.x System File Permissions (passwd, shadow, group, gshadow permissions and ownership)
- 6.2.x User and Group Settings (no legacy + entries, no duplicate UIDs/GIDs, home directories)

---

### CIS-2. K3s Conflicts and Workarounds

K3s requires kernel parameters and OS behaviors that directly conflict with CIS hardening. Document EVERY conflict with the exact workaround:

**Known conflicts to research and document:**

- `net.ipv4.ip_forward = 1` — Required by K3s (pods need routing); CIS says disable. How to document exception.
- `net.bridge.bridge-nf-call-iptables = 1` — Required for CNI; CIS says disable. K3s loads the `br_netfilter` module automatically — how does this interact with CIS module disabling controls?
- `net.bridge.bridge-nf-call-ip6tables = 1` — Same as above for IPv6.
- `kernel.pid_max` — K3s may require higher PID limits for container workloads.
- `/tmp` noexec mount option — K3s scripts may write executables to /tmp during install. Does this break the installer?
- Core dump disabling — Does K3s need core dumps for debugging?
- `fs.inotify.max_user_instances` and `fs.inotify.max_user_watches` — Required by K3s for high pod counts.
- `vm.overcommit_memory` — Kubernetes recommends `1`; CIS default differs.
- SCTP/DCCP kernel module disabling — Are any K3s CNIs (Flannel, Cilium) dependent on these?
- `/proc/sys/kernel/dmesg_restrict` — K3s may need dmesg access.
- Auditd and container volume mounts — Will auditd rules interfere with container file access?

For each conflict: state the CIS control number, the K3s requirement, the recommended approach (apply CIS control AND add K3s exception, OR skip CIS control, OR apply partial control), and the Ansible implementation.

---

### CIS-3. SELinux Configuration Controls

SELinux in `enforcing` mode with `targeted` policy is mandatory for our setup. Document:

- CIS controls 1.6.x: SELinux installation (`libselinux`, `policycoreutils`), mode (`enforcing`), type (`targeted`)
- Ansible modules: `ansible.posix.selinux`, `community.general.seboolean`, `ansible.posix.sefcontext`
- Required SELinux booleans for K3s: `container_manage_cgroup`, `virt_use_nfs`, `container_use_cifs` — which are needed and why
- K3s SELinux policy package: `k3s-selinux` RPM — how to install via Ansible, where to get it (rancher repo)
- Verifying SELinux mode: `getenforce`, `sestatus` — what the output should look like
- SELinux and containerd: known AVC denials that appear during K3s startup, how to handle them
- SELinux audit log monitoring: how auditd captures AVC denials, `ausearch -m AVC` command
- Permissive domains: how to put a single domain in permissive mode without disabling SELinux system-wide (for K3s troubleshooting)
- `audit2allow` workflow: when an AVC denial blocks K3s functionality, how to generate and apply a policy module
- OpenSCAP + SELinux: using `oscap` to verify SELinux compliance posture

---

### CIS-4. Filesystem Controls

The CIS benchmark specifies mount options and kernel module restrictions for filesystems. Document:

**Kernel module disabling (Section 1.1.1):**
- How to disable `cramfs`, `squashfs`, `udf`, `vfat` (if not needed) via `/etc/modprobe.d/`
- Ansible task: `ansible.builtin.copy` to write modprobe deny config
- Does K3s use any of these filesystem types internally?
- Verification: `modprobe -n -v <module>` should return `install /bin/true`

**Mount options (Section 1.1.2 - 1.1.9):**
- `/tmp`: `nodev`, `nosuid`, `noexec` — exact `/etc/fstab` entry, Ansible `mount` module task
- `/var/tmp`: same options — bind mount to /tmp or separate partition?
- `/dev/shm`: `nodev`, `nosuid`, `noexec` — exact entry
- `/home`: `nodev`
- `/var`: `nodev`
- `/var/log`: `nodev`, `nosuid`, `noexec`
- `/var/log/audit`: `nodev`, `nosuid`, `noexec`
- Does K3s write to any of these mount points during operation? Will `noexec` on `/var` break K3s?
- K3s data directory is `/var/lib/rancher/` — does `noexec` on `/var` break this? How to handle with a bind mount or separate partition.
- Ansible `mount` module: complete task syntax for adding options to existing mounts without reformatting

---

### CIS-5. Service Disabling Controls

Section 2 of the CIS benchmark covers disabling services not needed on a K3s node. For each service:
- Service name
- Why CIS requires disabling it
- Whether K3s or any of our deployed apps require it
- Ansible task to disable it (`ansible.builtin.service` with `state: stopped, enabled: false`)
- Verification command

Services to cover:
- `cups` (printing — definitely disable)
- `avahi-daemon` (mDNS — disable unless needed)
- `dhcpd` (DHCP server — disable)
- `named` / `bind` (DNS server — disable, we use Cloudflare)
- `vsftpd`, `ftpd` (FTP — disable)
- `httpd`, `nginx` (web server — disable, we use K3s pods for this)
- `dovecot`, `cyrus-imapd` (email — disable)
- `samba`, `smb` (file sharing — disable)
- `squid` (proxy — disable)
- `snmpd` (SNMP — disable)
- `ypserv`, `rpcbind` (NIS/NFS server — disable)
- `nfs-server`, `rpcbind` (NFS — disable unless used)
- `rsync` (disable if not used)
- `telnet` client package (remove)
- `rsh` client package (remove)
- `postfix` — K3s nodes may need a local MTA for cron emails; decision: disable or configure null client?
- `bluetooth`, `wpa_supplicant` (disable on cloud servers)

---

### CIS-6. SSH Hardening Controls

Section 5.2 covers every `sshd_config` directive. For our setup (port 2222, key-only auth, no root login):

Provide the complete CIS-compliant `sshd_config` template with:
- Every CIS 5.2.x control mapped to the exact `sshd_config` directive and recommended value
- Which controls we deviate from and why (e.g., `Port 2222` instead of 22)
- The complete Ansible task to deploy the hardened sshd_config using `ansible.builtin.template`
- Handler to restart sshd after config change
- Verification: `sshd -T` output — what a passing config looks like

Specific directives to cover:
- `Port 2222` (our non-standard port)
- `Protocol 2`
- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PermitEmptyPasswords no`
- `MaxAuthTries 4`
- `MaxSessions 10`
- `LoginGraceTime 60`
- `PubkeyAuthentication yes`
- `AuthorizedKeysFile .ssh/authorized_keys`
- `IgnoreRhosts yes`
- `HostbasedAuthentication no`
- `PermitUserEnvironment no`
- `ClientAliveInterval 300`
- `ClientAliveCountMax 3`
- `LogLevel VERBOSE`
- `X11Forwarding no`
- `AllowTcpForwarding no` (or `local` — does K3s need SSH tunneling?)
- `GatewayPorts no`
- `PermitTunnel no`
- `AllowUsers wakeem` (restrict to named user)
- Ciphers, MACs, KexAlgorithms — CIS-approved list for RHEL 9
- `UsePAM yes`
- `Banner /etc/issue.net`

---

### CIS-7. Firewalld Controls

Section 3.5 covers firewall configuration. Document:

- CIS requirements for default-deny posture with `firewalld`
- `firewall-cmd` commands to set default zone to `drop` or `public` with minimal open ports
- Required open ports for our K3s cluster:
  - Port 2222/TCP: SSH (our non-standard port)
  - Port 6443/TCP: K3s API server (from internal network only, or all if Cloudflare tunneled)
  - Port 10250/TCP: kubelet metrics
  - Port 8472/UDP: Flannel VXLAN (between cluster nodes only)
  - Port 51820/UDP: WireGuard (if used by K3s/Cilium)
  - Port 2379-2380/TCP: etcd (CP only, internal only)
  - Port 30000-32767/TCP: NodePort range (if needed)
- Ansible tasks using `ansible.posix.firewalld` module for each rule
- Zone configuration: which zone is the default, which zone K3s traffic uses
- Rich rules: restricting K3s API port to specific source IPs
- Firewalld and CrowdSec: how CrowdSec firewall-bouncer adds dynamic block rules
- Firewalld persistence: `permanent: true` and `immediate: true` in Ansible tasks
- Verification: `firewall-cmd --list-all` expected output

---

### CIS-8. Logging and Audit Controls

Sections 4.1 and 4.2 cover auditd and logging. Document:

**Auditd (Section 4.1):**
- Installing `audit` package on AlmaLinux 9
- `/etc/audit/auditd.conf` — CIS-required settings (max_log_file_action, space_left_action, disk_full_action)
- Audit rules file location: `/etc/audit/rules.d/` — CIS-required rules for:
  - Monitoring privileged commands (`chmod`, `chown`, `setuid`, `setgid` binaries)
  - Monitoring `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` changes
  - Monitoring login/logout events
  - Monitoring network configuration changes
  - Monitoring kernel module loading/unloading
  - Monitoring successful/failed su, sudo attempts
  - Capturing all admin (UID 0) actions
- `augenrules --load` vs `auditctl -R` — which does AlmaLinux 9 use?
- K3s and auditd: will K3s container operations generate excessive audit events? How to tune.
- Ansible tasks for auditd configuration

**Rsyslog/Journald (Section 4.2):**
- CIS controls for rsyslog — ensuring it's installed and running
- Key `rsyslog.conf` settings required by CIS
- Log file permissions: CIS requires restrictive permissions on `/var/log/` contents
- Journald configuration: `Storage=persistent`, `Compress=yes`
- Log forwarding to Loki (our stack): how this interacts with CIS logging controls

---

### CIS-9. Authentication and PAM Controls

Section 5.3 covers PAM configuration. For AlmaLinux 9 (which uses `authselect`, not direct PAM file editing):

- `authselect` profile selection: `sssd`, `minimal`, `winbind` — which profile is CIS-compliant baseline?
- `pam_pwquality`: minimum length, complexity, retry count — exact `/etc/security/pwquality.conf` values required by CIS
- `pam_pwhistory`: remember N old passwords — CIS required value
- Account lockout: `pam_faillock` on AlmaLinux 9 — exact configuration for N failed attempts, lockout duration
- `pam_faillock` vs `pam_tally2` — AlmaLinux 9 uses `pam_faillock` exclusively (tally2 removed in RHEL 9)
- `su` restriction: only members of `wheel` group can use `su` — exact PAM configuration
- Password aging in `/etc/login.defs`: `PASS_MAX_DAYS`, `PASS_MIN_DAYS`, `PASS_WARN_AGE`
- Setting `TMOUT` for shell sessions (auto-logout)
- `useradd` defaults: `/etc/default/useradd` settings
- Ansible tasks using `ansible.builtin.lineinfile` or `community.general.pamd` module
- Warning: `authselect` on RHEL 9 — do NOT edit PAM files directly; use `authselect` commands

---

### CIS-10. Kernel Parameter Controls

CIS Section 3.2 and 3.3 cover sysctl parameters. Provide a complete table:

| sysctl parameter | CIS required value | K3s required value | Conflict? | Resolution |
|---|---|---|---|---|

Specifically cover:
- `net.ipv4.ip_forward` — CIS says 0, K3s requires 1
- `net.ipv4.conf.all.send_redirects` — CIS says 0
- `net.ipv4.conf.default.send_redirects` — CIS says 0
- `net.ipv4.conf.all.accept_source_route` — CIS says 0
- `net.ipv4.conf.all.accept_redirects` — CIS says 0
- `net.ipv4.conf.all.secure_redirects` — CIS says 0
- `net.ipv4.conf.all.log_martians` — CIS says 1
- `net.ipv4.icmp_echo_ignore_broadcasts` — CIS says 1
- `net.ipv4.icmp_ignore_bogus_error_responses` — CIS says 1
- `net.ipv4.conf.all.rp_filter` — CIS says 1 (may conflict with Flannel/Cilium)
- `net.ipv4.tcp_syncookies` — CIS says 1
- `net.ipv6.conf.all.accept_ra` — CIS says 0 (if IPv6 not needed)
- `net.bridge.bridge-nf-call-iptables` — K3s requires 1, CIS may say 0
- `kernel.randomize_va_space` — CIS says 2 (ASLR)
- `kernel.dmesg_restrict` — CIS says 1
- `fs.suid_dumpable` — CIS says 0 (disable core dumps for SUID)
- `kernel.core_uses_pid` — CIS says 1
- `fs.inotify.max_user_watches` — K3s requires high value (e.g., 524288)
- `vm.overcommit_memory` — Kubernetes recommends 1

Ansible implementation using `ansible.posix.sysctl` module — complete task format.

---

### CIS-11. Automated vs Manual Controls

Categorize all CIS Level 1 controls by automation feasibility:

**Fully Automated (Ansible)**: Controls that can be applied reliably via Ansible with no manual steps.

**Partially Automated**: Controls where Ansible does most of the work but a manual verification step is required.

**Manual Only**: Controls that require human judgment or interactive UI steps (e.g., BIOS settings, physical media, GRUB password entry).

**Not Applicable to Hetzner Cloud VMs**: Controls that apply to physical hardware or bare metal but not cloud VMs (e.g., physical boot media, USB port disabling).

---

### CIS-12. CIS-CAT and OpenSCAP Scanning

How to validate CIS compliance after Ansible hardening:

**CIS-CAT Lite (free):**
- What CIS-CAT Lite covers vs Pro
- Download and setup on AlmaLinux 9
- Running a CIS Level 1 scan: exact command
- Interpreting the HTML report: pass/fail counts, what a 90%+ score looks like
- Which controls CIS-CAT cannot autocheck (manual-only controls)

**OpenSCAP (open source alternative):**
- Installing `scap-security-guide` and `openscap-scanner` on AlmaLinux 9.7 (`dnf install`)
- AlmaLinux 9 SCAP profile for CIS Level 1: profile ID to use
- Running a baseline scan: `oscap xccdf eval` command with AlmaLinux 9 data stream
- Generating HTML report: `--report` flag
- Remediation mode: `oscap xccdf remediate` — what it does, risks of running it
- Using OpenSCAP results to drive Ansible remediation

**hardening-audit.sh script:**
What should our `hardening-audit.sh` script contain? Provide a complete outline of:
- Which checks should be scripted (SELinux mode, SSH config, firewalld rules, sysctl values)
- Expected output format (PASS/FAIL per control)
- Checks that verify K3s-specific exceptions are documented (not false-failed)
- Integration with CI: how to fail a pipeline if compliance drops below threshold

---

### Best Practices & Anti-Patterns

- What are the top 10 CIS hardening best practices for K3s nodes running AlmaLinux 9 in production?
- What are the most common mistakes when applying CIS hardening to Kubernetes nodes? Rank by severity (critical → low).
- What configurations look correct but silently break K3s? (e.g., applying all kernel hardening without K3s exceptions)
- What CIS controls should NEVER be applied to a K3s control plane node without modification?
- What are the performance anti-patterns in audit logging that cause excessive disk I/O on busy K3s nodes?
- What is the correct order of operations: CIS harden first, then install K3s? Or K3s-aware hardening from the start?

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| Apply `net.ipv4.ip_forward=0` | Pure bastion/jump host | Yes — apply CIS control | No routing needed |
| Apply `net.ipv4.ip_forward=0` | K3s control plane or worker | No — K3s exception | K3s requires IP forwarding for pod networking |
| Disable `postfix` | Server has no local cron email needs | Disable | Reduces attack surface |
| Keep `postfix` | Server uses cron + needs email notification | Configure as null client | CIS allows this with proper config |
| Use OpenSCAP | No CIS-CAT Pro license | Use OpenSCAP | Free, built into AlmaLinux |
| Use CIS-CAT Pro | Enterprise compliance reporting needed | CIS-CAT Pro | Official reports for auditors |
| Use `authselect` | AlmaLinux 9 PAM changes | Always | Direct PAM file edits break on authselect systems |
| Set `/tmp noexec` | No K3s on the node | Apply CIS control | Clean isolation |
| Set `/tmp noexec` | K3s being installed on node | Test carefully | K3s installer may write to /tmp |

- When to use `ansible.posix.sysctl` vs writing directly to `/etc/sysctl.d/`
- When to use `community.general.seboolean` vs shell `setsebool`
- When to apply CIS Level 2 controls vs staying at Level 1

### Common Pitfalls

- Running OpenSCAP remediation blindly — it may break K3s networking
- Disabling IP forwarding on a K3s node (breaks pod-to-pod routing immediately)
- Setting `/var` to `noexec` without carving out `/var/lib/rancher/` (breaks K3s data path)
- Locking `root` password before confirming `wakeem` user has full sudo access (risk of lockout)
- Applying `MaxSessions 1` in sshd_config while Ansible uses multiplexed connections (breaks Ansible)
- Using `authselect` profile changes after manual PAM edits — `authselect` will overwrite manual changes
- Wrong `auditd.conf` disk_full_action — setting `HALT` on a busy K3s node will panic it on disk fill
- `firewalld` zone confusion — applying rules to the wrong zone (public vs drop vs trusted)
- CIS control for disabling USB storage: not applicable on Hetzner Cloud VMs — do not waste time on it
- Version confusion: CIS Benchmark for AlmaLinux 9 vs RHEL 9 vs CentOS 9 Stream — verify which is authoritative

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CIS control number quick-reference table (number, name, ansible module, verify command)
- K3s conflict map: which controls to skip/modify and exact workarounds
- Ansible task patterns for each CIS section
- Troubleshooting decision tree (compliance failure → diagnosis → fix)
- Integration points with our stack (K3s, CrowdSec, auditd, Loki)
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete CIS Level 1 control list with all metadata
- Full sysctl parameter table with CIS vs K3s values and conflict resolution
- Complete hardened `sshd_config` template for AlmaLinux 9 on port 2222
- Complete PAM configuration using `authselect` for AlmaLinux 9
- Complete auditd rule set (CIS-required rules)
- Complete firewalld rule set for K3s nodes
- OpenSCAP command reference for AlmaLinux 9
- `hardening-audit.sh` complete script outline

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Complete Ansible `cis-hardening` role structure with all task files
- Real configurations using our servers (178.156.233.12, 5.78.145.30), SSH port 2222, user `wakeem`
- Annotated playbook: `harden-almalinux9.yml` that applies all CIS Level 1 controls with K3s exceptions noted inline
- Before/after: sysctl values before and after hardening, with K3s-required exceptions documented
- OpenSCAP scan command and expected output for a well-hardened AlmaLinux 9 K3s node
- CI integration: GitHub Actions job that runs `hardening-audit.sh` against a test node and fails on score < 85%
- Step-by-step runbook: "Apply CIS Level 1 to a new Hetzner server before K3s installation"

Use `# CIS AlmaLinux 9` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual sysctl values, actual PAM configs, actual auditd rules, actual firewalld commands, and actual Ansible tasks. Do NOT give theory — give copy-paste-ready Ansible roles and verification commands for hardening AlmaLinux 9.7 K3s nodes on Hetzner Cloud.
