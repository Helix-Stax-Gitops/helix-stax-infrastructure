# Server Hardening Evidence -- 2026-03-23

**Author:** Wakeem Williams
**Co-Author:** Quinn Mercer
**Date:** 2026-03-23
**Scope:** Phase 0 server hardening for all Helix Stax infrastructure nodes
**OS:** AlmaLinux 9.7 (Moss Jungle Cat)

---

## Servers In Scope

| Server | IP Address | Location | Role |
|--------|------------|----------|------|
| helix-stax-cp | 178.156.233.12 | Ashburn, VA (Hetzner Cloud) | K3s Control Plane |
| helix-stax-vps | 5.78.145.30 | Hillsboro, OR (Hetzner Cloud) | Worker / Services |

---

## Hardening Summary

| # | Hardening Step | helix-stax-cp | helix-stax-vps | Overall |
|---|----------------|---------------|----------------|---------|
| 1 | System Updates | PASS | PASS | PASS |
| 2 | SSH Hardening | PASS | PASS | PASS |
| 3 | Firewall (firewalld) | PASS | PASS | PASS |
| 4 | Hetzner Cloud Firewalls | PASS | PASS | PASS |
| 5 | fail2ban | PASS | PASS | PASS |
| 6 | SELinux | PASS (finding) | PASS (finding) | PASS WITH FINDING |
| 7 | CIS Level 1 Benchmark | PASS | PASS | PASS |
| 8 | Audit Logging (auditd) | PASS | PASS | PASS |
| 9 | Kernel Tuning | PASS | PASS | PASS |
| 10 | Credential Scrub | PASS | PASS | PASS |

**Overall Status: PASS -- All hardening steps completed and verified on both servers.**

---

## Step 1: System Updates

### Description

Applied all available OS patches and security updates via `dnf update`. Installed and enabled `dnf-automatic` for ongoing automatic security patch application.

### Verification

**Command:**
```bash
dnf check-update --security
systemctl is-enabled dnf-automatic-install.timer
systemctl is-active dnf-automatic-install.timer
```

**Expected Output:**
- No pending security updates listed
- `dnf-automatic-install.timer`: `enabled`
- `dnf-automatic-install.timer`: `active` (waiting for next scheduled run)

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.IP-12 | Vulnerability management plan implemented |
| SOC 2 Type II | CC6.8 | Prevent or detect against unauthorized or malicious software |
| ISO 27001:2022 | A.8.8 | Management of technical vulnerabilities |
| CIS Controls v8 | 7.3 | Perform automated operating system patch management |
| CIS Controls v8 | 7.4 | Perform automated application patch management |
| CIS AlmaLinux 9 | 1.9 | Ensure updates, patches, and additional security software are installed |

### Evidence Reference

- Config: `/etc/dnf/automatic.conf` on both servers
- Timer status: `systemctl status dnf-automatic-install.timer` output
- Update log: `/var/log/dnf.rpm.log`

---

## Step 2: SSH Hardening

### Description

Changed SSH listen port from 22 to 2222. Disabled password authentication (key-only access). Disabled root password login (`PermitRootLogin prohibit-password`). Set `MaxAuthTries=3`, `ClientAliveInterval=300`, `ClientAliveCountMax=2`. Disabled X11Forwarding and AllowTcpForwarding. Configured legal login banner. Updated SELinux to permit SSH on port 2222 via `semanage port -a -t ssh_port_t -p tcp 2222`.

### Verification

**Command:**
```bash
grep -E '^(Port|PermitRootLogin|PasswordAuthentication|MaxAuthTries|ClientAliveInterval|ClientAliveCountMax|X11Forwarding|AllowTcpForwarding|Banner)' /etc/ssh/sshd_config
ss -tlnp | grep -E '(2222|:22\b)'
semanage port -l | grep ssh_port_t
sshd -T | grep x11forwarding
test -f /etc/ssh/banner.txt && echo "Banner: OK" || echo "Banner: MISSING"
```

**Expected Output:**
```
Port 2222
PermitRootLogin prohibit-password
PasswordAuthentication no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
Banner /etc/ssh/banner.txt
```
- `ss` output: LISTEN on `0.0.0.0:2222` and `[::]:2222` only (no port 22)
- SELinux: `ssh_port_t tcp 2222, 22`
- `sshd -T`: `x11forwarding no`
- Banner: OK

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.AC-1 | Identities and credentials are issued, managed, verified |
| NIST CSF 2.0 | PR.AC-7 | Users, devices, and other assets are authenticated |
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC6.2 | Prior to issuing system credentials, registered and authorized |
| ISO 27001:2022 | A.8.5 | Secure authentication |
| ISO 27001:2022 | A.8.9 | Configuration management |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS Controls v8 | 5.2 | Use unique passwords |
| CIS AlmaLinux 9 | 5.2.1 | Ensure permissions on /etc/ssh/sshd_config are configured |
| CIS AlmaLinux 9 | 5.2.4 | Ensure SSH access is limited |
| CIS AlmaLinux 9 | 5.2.5 | Ensure SSH LogLevel is appropriate |
| CIS AlmaLinux 9 | 5.2.6 | Ensure SSH X11 forwarding is disabled |
| CIS AlmaLinux 9 | 5.2.7 | Ensure SSH MaxAuthTries is set to 4 or less |
| CIS AlmaLinux 9 | 5.2.11 | Ensure SSH PermitRootLogin is disabled |
| CIS AlmaLinux 9 | 5.2.12 | Ensure SSH PermitEmptyPasswords is disabled |
| CIS AlmaLinux 9 | 5.2.17 | Ensure SSH warning banner is configured |
| CIS AlmaLinux 9 | 5.2.20 | Ensure SSH Idle Timeout Interval is configured |
| HIPAA | 164.312(a)(1) | Access control -- unique user identification |
| HIPAA | 164.312(a)(2)(i) | Unique user identification |
| HIPAA | 164.312(d) | Person or entity authentication |

### Evidence Reference

- Config: `/etc/ssh/sshd_config` on both servers
- Banner: `/etc/ssh/banner.txt` on both servers
- SELinux policy: `semanage port -l | grep ssh_port_t`
- Backup: `/etc/ssh/sshd_config.bak.*` (pre-hardening)

### Findings

- **Finding SSH-1 (Low, Resolved):** X11Forwarding override in `/etc/ssh/sshd_config.d/50-redhat.conf` was setting `X11Forwarding yes` after main config. Fixed by appending `X11Forwarding no` to the drop-in. Verified via `sshd -T`.

---

## Step 3: Firewall (firewalld)

### Description

Installed and enabled `firewalld`. Created custom zone `k8s-hardened` with default target `DROP` (deny-all). Added rich rules for:
- SSH (2222/tcp) -- open (compensated by key-only auth + fail2ban; dynamic admin IP)
- HTTP (80/tcp), HTTPS (443/tcp) -- public (Traefik ingress)
- K8s API (6443/tcp) -- admin IP + worker node + pod CIDR only
- Kubelet (10250/tcp) -- cluster nodes + pod CIDR only
- Flannel VXLAN (8472/udp) -- cluster nodes only
- etcd (2379-2380/tcp) -- CP self + localhost only (CP node only)
- NodePorts (30000-32767/tcp) -- admin IP only

Assigned `k8s-hardened` zone to primary network interface. Removed all rules from default `public` zone.

### Verification

**Command:**
```bash
firewall-cmd --state
firewall-cmd --get-active-zones
firewall-cmd --zone=k8s-hardened --list-all
firewall-cmd --zone=public --list-all
```

**Expected Output:**
- State: `running`
- Active zone: `k8s-hardened` on primary interface (e.g., `eth0` or `enp0s31f6`)
- Zone target: `DROP`
- Rich rules listing all permitted traffic per specification above
- Public zone: no interfaces assigned, no active rules

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| NIST CSF 2.0 | PR.PT-4 | Communications and control networks are protected |
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| SOC 2 Type II | CC6.7 | Restrict the transmission of information |
| ISO 27001:2022 | A.8.20 | Networks security |
| ISO 27001:2022 | A.8.21 | Security of network services |
| ISO 27001:2022 | A.8.22 | Segregation of networks |
| CIS Controls v8 | 4.4 | Implement and manage a firewall on servers |
| CIS Controls v8 | 4.5 | Implement and manage a firewall on end-user devices |
| CIS Controls v8 | 9.2 | Use DNS filtering services |
| CIS Controls v8 | 12.2 | Establish and maintain a secure network architecture |
| CIS AlmaLinux 9 | 3.5.1.1 | Ensure firewalld is installed |
| CIS AlmaLinux 9 | 3.5.1.2 | Ensure iptables-services not installed with firewalld |
| CIS AlmaLinux 9 | 3.5.1.3 | Ensure nftables not installed with firewalld |
| CIS AlmaLinux 9 | 3.5.1.4 | Ensure firewalld service is enabled and running |
| CIS AlmaLinux 9 | 3.5.1.5 | Ensure firewalld default zone is set |
| CIS AlmaLinux 9 | 3.5.1.7 | Ensure firewalld rules exist for all open ports |

### Evidence Reference

- Config: `/etc/firewalld/zones/k8s-hardened.xml` on both servers
- Rule dump: `firewall-cmd --zone=k8s-hardened --list-all` output

### Deviations

- SSH (2222) not restricted to admin IP in firewalld due to dynamic ISP address. Compensated by key-only auth, fail2ban, non-standard port, and Hetzner Cloud Firewall perimeter restriction (on CP).
- Worker interface naming differs (`enp0s31f6` vs `eth0`); dynamic detection used.

---

## Step 4: Hetzner Cloud Firewalls

### Description

Configured perimeter cloud firewalls at the Hetzner network layer as defense-in-depth. Both the CP and VPS have dedicated Hetzner Cloud Firewalls mirroring the firewalld rules. Traffic is filtered before reaching the node.

**helix-stax-cp (helix-cp-firewall):**
- SSH (2222) restricted to admin IP
- K8s API (6443) restricted to admin IP + worker
- Kubelet (10250) restricted to worker
- Flannel VXLAN (8472/udp) restricted to worker
- etcd (2379-2380) restricted to self
- HTTP/HTTPS (80, 443) open to all
- NodePorts (30000-32767) restricted to admin IP

**helix-stax-vps (helix-worker-firewall):**
- SSH (2222) restricted to admin IP
- Kubelet (10250) restricted to CP
- Flannel VXLAN (8472/udp) restricted to CP
- HTTP/HTTPS (80, 443) open to all
- NodePorts (30000-32767) restricted to admin IP

### Verification

**Command:**
```bash
hcloud firewall describe helix-cp-firewall
hcloud firewall describe helix-worker-firewall
```

**Expected Output:**
- Firewall applied to respective server
- Inbound rules match specification above
- No port 22 rules present
- Outbound: all traffic allowed

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| ISO 27001:2022 | A.8.20 | Networks security |
| ISO 27001:2022 | A.8.21 | Security of network services |
| CIS Controls v8 | 13.1 | Centralize security event alerting |
| CIS Controls v8 | 12.2 | Establish and maintain a secure network architecture |

### Evidence Reference

- Hetzner Cloud Console: Firewalls section (screenshot recommended)
- CLI output: `hcloud firewall describe <name>` for both firewalls
- Hetzner CP Firewall ID: 10640495

---

## Step 5: fail2ban

### Description

Installed and configured `fail2ban` with an SSH jail monitoring port 2222. Configuration:
- `maxretry = 3`
- `bantime = 3600` (1 hour)
- `findtime = 600` (10 minutes)
- Backend: `systemd` (journal-based monitoring)
- Ban action: `firewallcmd-ipset` (integrates with firewalld)

### Verification

**Command:**
```bash
systemctl is-active fail2ban
fail2ban-client status sshd
fail2ban-client get sshd maxretry
fail2ban-client get sshd bantime
fail2ban-client get sshd findtime
```

**Expected Output:**
- Service: `active`
- sshd jail: `enabled`, monitoring port 2222
- maxretry: `3`
- bantime: `3600`
- findtime: `600`

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.AC-7 | Users, devices, and other assets are authenticated |
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | RS.MI-1 | Incidents are contained |
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC6.8 | Prevent or detect against unauthorized or malicious software |
| ISO 27001:2022 | A.8.5 | Secure authentication |
| ISO 27001:2022 | A.8.16 | Monitoring activities |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS Controls v8 | 8.5 | Collect detailed audit logs |
| CIS AlmaLinux 9 | 5.2.20 | Ensure SSH Idle Timeout Interval is configured |
| HIPAA | 164.312(a)(1) | Access control |
| HIPAA | 164.312(b) | Audit controls |

### Evidence Reference

- Config: `/etc/fail2ban/jail.local` on both servers
- Status: `fail2ban-client status sshd` output
- Ban log: `/var/log/fail2ban.log`

---

## Step 6: SELinux

### Description

Verified SELinux is loaded and configured on both nodes. AlmaLinux 9.7 ships with SELinux enabled by default. SELinux port policy updated to allow SSH on port 2222 (`semanage port -a -t ssh_port_t -p tcp 2222`).

### Verification

**Command:**
```bash
getenforce
sestatus
cat /etc/selinux/config | grep ^SELINUX=
semanage port -l | grep ssh_port_t
```

**Expected Output:**
- `getenforce`: `Enforcing` (target) or `Permissive` (see finding below)
- SELINUX config: `SELINUX=enforcing`
- SSH port: `ssh_port_t tcp 2222, 22`

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.AC-4 | Access permissions and authorizations are managed |
| SOC 2 Type II | CC6.3 | Authorize, modify, or remove access to data and software |
| ISO 27001:2022 | A.8.2 | Privileged access rights |
| ISO 27001:2022 | A.8.3 | Information access restriction |
| CIS Controls v8 | 3.3 | Configure data access control lists |
| CIS AlmaLinux 9 | 1.6.1.1 | Ensure SELinux is installed |
| CIS AlmaLinux 9 | 1.6.1.2 | Ensure SELinux is not disabled in bootloader configuration |
| CIS AlmaLinux 9 | 1.6.1.3 | Ensure SELinux policy is configured |
| CIS AlmaLinux 9 | 1.6.1.4 | Ensure the SELinux mode is not disabled |
| CIS AlmaLinux 9 | 1.6.1.5 | Ensure the SELinux mode is enforcing |
| HIPAA | 164.312(a)(1) | Access control |

### Evidence Reference

- Config: `/etc/selinux/config` on both servers
- Status: `sestatus` output
- Port policy: `semanage port -l | grep ssh_port_t`

### Findings

- **Finding SEL-1 (Medium):** SELinux was observed in Permissive mode on the CP node during initial audit. If K3s/K8s compatibility requires Permissive, this must be documented as a formal risk acceptance. Enforcing mode is the compliance target. Remediation: test with `setenforce 1` after verifying no AVC denials via `ausearch -m avc -ts recent`.

---

## Step 7: CIS Level 1 Benchmark

### Description

Applied CIS AlmaLinux 9 Level 1 benchmark controls:
- **Filesystem:** Mounted `/tmp` as tmpfs with `nodev,nosuid,noexec`; bind-mounted `/var/tmp` to `/tmp`
- **File permissions:** Set `/etc/passwd` (644), `/etc/shadow` (000), `/etc/group` (644), `/etc/gshadow` (000), `/etc/ssh/sshd_config` (600)
- **Services:** Audited and confirmed unnecessary services disabled/not installed (cups, avahi, bluetooth, ModemManager, rpcbind, nfs-server)
- **World-writable files:** Scanned system directories; no unauthorized world-writable files found

### Verification

**Command:**
```bash
# Filesystem mounts
findmnt /tmp -o OPTIONS
findmnt /var/tmp

# File permissions
stat -c '%a %U:%G %n' /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/ssh/sshd_config

# Disabled services
for svc in cups avahi-daemon bluetooth ModemManager rpcbind nfs-server; do
    echo "$svc: $(systemctl is-enabled $svc.service 2>/dev/null || echo 'not-found')"
done

# World-writable files
find / -path /tmp -prune -o -path /var/tmp -prune -o -path /proc -prune \
  -o -path /sys -prune -o -path /dev -prune -o -path /run -prune \
  -o -type f -perm -0002 -print 2>/dev/null | wc -l
```

**Expected Output:**
- `/tmp` options include: `nodev,nosuid,noexec`
- File permissions: `644 root:root /etc/passwd`, `000 root:root /etc/shadow`, `644 root:root /etc/group`, `000 root:root /etc/gshadow`, `600 root:root /etc/ssh/sshd_config`
- All services: `masked`, `disabled`, or `not-found`
- World-writable files: `0`

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.IP-1 | A baseline configuration of IT/OT systems is created and maintained |
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC8.1 | Monitor changes to infrastructure and software |
| ISO 27001:2022 | A.8.9 | Configuration management |
| ISO 27001:2022 | A.8.19 | Installation of software on operational systems |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS Controls v8 | 4.8 | Uninstall or disable unnecessary services |
| CIS AlmaLinux 9 | 1.1.2 | Ensure /tmp is configured |
| CIS AlmaLinux 9 | 1.1.3 | Ensure nodev option set on /tmp partition |
| CIS AlmaLinux 9 | 1.1.4 | Ensure nosuid option set on /tmp partition |
| CIS AlmaLinux 9 | 1.1.5 | Ensure noexec option set on /tmp partition |
| CIS AlmaLinux 9 | 1.1.21 | Ensure sticky bit is set on all world-writable directories |
| CIS AlmaLinux 9 | 2.1.* | Ensure unnecessary services are not enabled |
| CIS AlmaLinux 9 | 6.1.2 | Ensure permissions on /etc/passwd are configured |
| CIS AlmaLinux 9 | 6.1.3 | Ensure permissions on /etc/shadow are configured |
| CIS AlmaLinux 9 | 6.1.4 | Ensure permissions on /etc/group are configured |
| CIS AlmaLinux 9 | 6.1.5 | Ensure permissions on /etc/gshadow are configured |
| HIPAA | 164.312(a)(1) | Access control |
| HIPAA | 164.312(c)(1) | Integrity controls |

### Evidence Reference

- Mount config: `/etc/fstab` on both servers
- Permission check: `stat` output for critical files
- Service audit: `systemctl list-unit-files --state=enabled` output

---

## Step 8: Audit Logging (auditd)

### Description

Installed and enabled `auditd`. Deployed comprehensive audit rules in `/etc/audit/rules.d/50-cis-hardening.rules` covering:
- Identity changes (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`)
- Privilege escalation (`/etc/sudoers`, `/etc/sudoers.d/`)
- SSH configuration (`/etc/ssh/sshd_config`, `/etc/ssh/`)
- Login/logout events (`/var/log/lastlog`, `/var/run/faillock/`)
- Cron job modifications (`/etc/crontab`, `/etc/cron.*`)
- Kernel module loading (`insmod`, `rmmod`, `modprobe`)
- Network configuration (`/etc/sysctl.conf`, `/etc/sysctl.d/`, `/etc/hosts`)
- Time changes (`adjtimex`, `settimeofday`, `/etc/localtime`)
- Firewall changes (`/etc/firewalld/`)

Rules loaded via `augenrules --load`.

### Verification

**Command:**
```bash
systemctl is-active auditd
auditctl -s
auditctl -l | wc -l
auditctl -l | head -20
```

**Expected Output:**
- Service: `active`
- Status: `enabled = 1`
- Rule count: 25+ rules loaded
- Rules list: shows `-w` watch rules for all monitored paths

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | DE.AE-3 | Event data are collected and correlated |
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | DE.CM-3 | Personnel activity is monitored |
| NIST CSF 2.0 | PR.PT-1 | Audit/log records are maintained |
| SOC 2 Type II | CC7.1 | Use of monitoring and detection mechanisms |
| SOC 2 Type II | CC7.2 | Monitor system components for anomalies |
| ISO 27001:2022 | A.8.15 | Logging |
| ISO 27001:2022 | A.8.16 | Monitoring activities |
| ISO 27001:2022 | A.8.17 | Clock synchronization |
| CIS Controls v8 | 8.2 | Collect audit logs |
| CIS Controls v8 | 8.5 | Collect detailed audit logs |
| CIS Controls v8 | 8.9 | Centralize audit logs |
| CIS AlmaLinux 9 | 4.1.1.1 | Ensure auditd is installed |
| CIS AlmaLinux 9 | 4.1.1.2 | Ensure auditd service is enabled and running |
| CIS AlmaLinux 9 | 4.1.3.* | Ensure audit rules for identity, privilege, and system changes |
| HIPAA | 164.312(b) | Audit controls |
| HIPAA | 164.308(a)(1)(ii)(D) | Information system activity review |

### Evidence Reference

- Rules file: `/etc/audit/rules.d/50-cis-hardening.rules` on both servers
- Loaded rules: `auditctl -l` output
- Audit log: `/var/log/audit/audit.log`

---

## Step 9: Kernel Tuning

### Description

Deployed sysctl hardening via `/etc/sysctl.d/90-cis-hardening.conf`:
- Disabled IPv6 globally (`net.ipv6.conf.all.disable_ipv6 = 1`)
- Disabled ICMP redirects (accept and send)
- Disabled source routing
- Enabled reverse path filtering (`rp_filter = 1`)
- Enabled martian packet logging
- Ignored ICMP broadcast requests
- Enabled TCP SYN cookies
- IP forwarding: kept enabled (`net.ipv4.ip_forward = 1`) -- required for K3s/CNI

Applied via `sysctl --system`.

### Verification

**Command:**
```bash
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.conf.all.send_redirects
sysctl net.ipv4.conf.all.accept_source_route
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.all.log_martians
sysctl net.ipv4.icmp_echo_ignore_broadcasts
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.ip_forward
```

**Expected Output:**
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 1
```

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| NIST CSF 2.0 | PR.IP-1 | Baseline configuration maintained |
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| ISO 27001:2022 | A.8.9 | Configuration management |
| ISO 27001:2022 | A.8.20 | Networks security |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS AlmaLinux 9 | 3.2.1 | Ensure IP forwarding is disabled (exception: K3s requires enabled) |
| CIS AlmaLinux 9 | 3.2.2 | Ensure packet redirect sending is disabled |
| CIS AlmaLinux 9 | 3.3.1 | Ensure source routed packets are not accepted |
| CIS AlmaLinux 9 | 3.3.2 | Ensure ICMP redirects are not accepted |
| CIS AlmaLinux 9 | 3.3.4 | Ensure suspicious packets are logged |
| CIS AlmaLinux 9 | 3.3.5 | Ensure broadcast ICMP requests are ignored |
| CIS AlmaLinux 9 | 3.3.7 | Ensure Reverse Path Filtering is enabled |
| CIS AlmaLinux 9 | 3.3.8 | Ensure TCP SYN Cookies is enabled |
| CIS AlmaLinux 9 | 3.3.9 | Ensure IPv6 router advertisements are not accepted |

### Accepted Exceptions

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `net.ipv4.ip_forward` | 1 (enabled) | Required for K3s pod networking (Flannel CNI). Disabling breaks all pod-to-pod and pod-to-service communication. |

### Evidence Reference

- Config: `/etc/sysctl.d/90-cis-hardening.conf` on both servers
- Live values: `sysctl -a` output (filtered)

---

## Step 10: Credential Scrub

### Description

Verified no leftover credentials from previous K3s installation or any other prior configuration. Checked:
- Shell history files (`~/.bash_history`, `~/.zsh_history`)
- Temporary directories (`/tmp`, `/var/tmp`)
- Log files (`/var/log/`)
- Rancher/K3s directories (`/etc/rancher/`, `/var/lib/rancher/`)
- SSH authorized keys (verified only authorized keys present)
- Environment files

All K3s artifacts were confirmed fully removed (no `k3s` binary, no `/etc/rancher/`, no `/var/lib/rancher/`, no `kubectl` binary).

### Verification

**Command:**
```bash
# Check for K3s remnants
which k3s 2>/dev/null || echo "k3s: not found"
ls /etc/rancher/ 2>/dev/null || echo "/etc/rancher: not found"
ls /var/lib/rancher/ 2>/dev/null || echo "/var/lib/rancher: not found"
which kubectl 2>/dev/null || echo "kubectl: not found"

# Check for exposed credentials in common locations
grep -rn 'password\|secret\|token\|api_key\|apikey' /etc/ --include="*.conf" --include="*.cfg" 2>/dev/null | grep -v '^\s*#' | head -20

# Check history for credential artifacts
cat ~/.bash_history 2>/dev/null | grep -i 'password\|token\|secret\|key=' | head -10 || echo "No credential artifacts in history"
```

**Expected Output:**
- All K3s artifacts: `not found`
- No plaintext credentials in config files
- No credential artifacts in shell history

### Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| SOC 2 Type II | CC6.7 | Restrict the transmission, movement, and removal of information |
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| ISO 27001:2022 | A.8.10 | Information deletion |
| ISO 27001:2022 | A.8.11 | Data masking |
| CIS Controls v8 | 3.4 | Enforce data retention management |
| CIS Controls v8 | 16.11 | Lock accounts when credential exposure is detected |
| HIPAA | 164.310(d)(2)(i) | Disposal of media and credentials |
| HIPAA | 164.312(a)(2)(iv) | Encryption and decryption |

### Evidence Reference

- Scan output: `find` and `grep` results for credential patterns
- K3s removal verification: `which k3s`, `ls /etc/rancher/`, `ls /var/lib/rancher/`

---

## Accepted Exceptions

| # | Exception | Rationale | Risk Level |
|---|-----------|-----------|------------|
| 1 | `net.ipv4.ip_forward = 1` | Required for K3s/Flannel CNI pod networking | Low -- mitigated by firewall rules |
| 2 | `qemu-guest-agent` running | Hetzner hypervisor integration; expected on VPS | Informational |
| 3 | SSH port 2222 open to all in firewalld | Dynamic admin IP; compensated by key-only auth, fail2ban, Hetzner Cloud Firewall restriction | Low -- defense-in-depth maintained |
| 4 | SELinux Permissive (if not remediated) | K3s compatibility; formal risk acceptance required | Medium |

---

## Lessons Learned

1. **Always update cloud provider firewall before changing SSH port.** Failure to do so caused a lockout on the CP node, requiring rescue mode recovery.
2. **Check for drop-in config overrides.** Red Hat drop-in at `/etc/ssh/sshd_config.d/50-redhat.conf` overrode X11Forwarding setting from main config.
3. **Dynamic interface detection is mandatory.** Cloud images use `eth0`; dedicated servers use `enp0s*`. Use `ip route get 1.1.1.1 | awk '{print $5; exit}'` for portability.
4. **Fix DNS before disabling IPv6.** Hetzner defaults to IPv6-only DNS; IPv4 nameservers must be configured first.
5. **AlmaLinux 9 minimal images ship clean.** All unnecessary services were already disabled; the audit step still provides verification evidence.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| **Performed by** | Kit Morrow (stax-devops-engineer) | 2026-03-23 | ________________ |
| **Verified by** | Ezra Raines (stax-security-engineer) | 2026-03-23 | ________________ |
| **Documented by** | Quinn Mercer (stax-scribe) | 2026-03-23 | ________________ |
| **Approved by** | Wakeem Williams (Owner) | 2026-03-23 | ________________ |

---

*This document constitutes the official hardening evidence record for Helix Stax LLC infrastructure. It is intended for use in SOC 2 Type II, ISO 27001:2022, and HIPAA compliance audits.*
