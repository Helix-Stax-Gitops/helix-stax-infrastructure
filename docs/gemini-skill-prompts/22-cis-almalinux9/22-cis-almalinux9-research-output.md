# CIS AlmaLinux 9

This document provides a comprehensive reference for hardening AlmaLinux 9 servers according to the CIS Level 1 benchmark, with specific exceptions and configurations tailored for running K3s in the Helix Stax environment.

---

### ## SKILL.md Content
This is the daily-use quick reference for AI agents building and operating Helix Stax infrastructure. It is concise and actionable.

**Core Principle:** Harden first using Ansible, applying K3s-specific exceptions. Then, install K3s. Verify compliance with `hardening-audit.sh` or OpenSCAP.

**K3s Conflict & Exception Map (CRITICAL)**

| CIS Control | CIS Recommended | K3s Requirement | Action for K3s Nodes | Justification |
|---|---|---|---|---|
| 3.2.1 | `net.ipv4.ip_forward = 0` | `1` | **Skip Control.** Set to `1`. | Pod-to-pod and pod-to-external networking. |
| (Implied) | Disable `br_netfilter` module | Load module & set sysctls | **Skip Control.** Allow K3s to manage. | CNI requires bridge packets to traverse iptables. |
| 3.2.2 | `net.bridge.bridge-nf-call-iptables = 0` | `1` | **Skip Control.** Set to `1`. | Required for CNI (Flannel/Cilium). |
| 3.2.2 | `net.bridge.bridge-nf-call-ip6tables = 0`| `1` | **Skip Control.** Set to `1`. | Required for CNI (IPv6). |
| 1.1.3 | `/tmp` mounted `noexec` | Executable scripts may run | **Test.** Apply, but test K3s installer. If fails, remount `rw,exec` for install, then revert. | Security vs. installer convenience. |
| 1.1.x | `/var` mounted `noexec` | `/var/lib/rancher` contains binaries | **Skip Control.** Do NOT set `noexec` on `/var`. | K3s stores executables in its data directory. |
| 1.5.1 | Disable core dumps | Debugging K3s/containerd | **Apply Control.** Re-enable only temporarily for active debugging. | Production systems should not generate core dumps. |
| N/A | `fs.inotify.max_user_watches` default | High value (e.g., 524288) | **Implement K3s Value.** Set to `524288` or higher. | Kubelet needs to watch many files for ConfigMaps, Secrets, etc. |
| N/A | `vm.overcommit_memory` default | `1` | **Implement K3s Value.** Set to `1`. | Kubernetes best practice to avoid OOM-killing critical pods. |
| 1.1.1.x | Disable `sctp` module | May be used by CNIs | **Test.** Disable by default. If a CNI like Cilium needs it, document and enable. | Disable unused protocols. |
| 4.1.x | Audit all container file access | Performance overhead | **Modify.** Audit host files, not all container volume activity. Exclude `/var/lib/containerd`. | Avoid excessive audit log noise and I/O. |
| 5.2.16 | `AllowTcpForwarding no` | `yes` may be needed for `kubectl port-forward` | **Set to `yes` or `local`.** | `kubectl port-forward` works via SSH-like tunneling. `local` is a good compromise. |

**Ansible Hardening Patterns**

| Action | Module | Example Task |
|---|---|---|
| Set Kernel Parameter | `ansible.posix.sysctl` | `ansible.posix.sysctl: name: net.ipv4.ip_forward value: '1' sysctl_file: /etc/sysctl.d/98-k3s.conf state: present` |
| Disable Service | `ansible.builtin.service` | `ansible.builtin.service: name: cups state: stopped enabled: false` |
| Set Mount Option | `ansible.posix.mount` | `ansible.posix.mount: path: /tmp src: tmpfs fstype: tmpfs opts: 'rw,nosuid,nodev,noexec,relatime' state: mounted` |
| Configure SSH | `ansible.builtin.template` | `ansible.builtin.template: src: sshd_config.j2 dest: /etc/ssh/sshd_config notify: restart sshd` |
| Configure Firewall | `ansible.posix.firewalld` | `ansible.posix.firewalld: port: 2222/tcp permanent: true state: enabled zone: public` |
| Disable Kernel Module| `community.general.modprobe` | `community.general.modprobe: name: cramfs state: blacklisted` |
| Set PAM limits | `ansible.builtin.lineinfile` | `ansible.builtin.lineinfile: path: /etc/security/pwquality.conf regexp: '^minlen =' line: 'minlen = 14'` |
| Set SELinux Boolean |`community.general.seboolean`| `community.general.seboolean: name: container_manage_cgroup state: true persistent: true` |

**Troubleshooting Compliance Failure**

1.  **Run `hardening-audit.sh` or `oscap` scan.** Identify failing control number.
2.  **Is it a K3s conflict?** Check the K3s Conflict Map above.
    *   **YES:** The failure is expected. The audit script/scanner profile needs to be updated to accept this exception. Document the deviation.
    *   **NO:** The hardening was not applied correctly.
3.  **Check Ansible logs.** Did the relevant task run and report `changed` or `ok`?
4.  **Manually verify.** Use the `Verification` command from the `reference.md` table for the specific control.
    *   *Example: 5.2.5 fails.* `sudo sshd -T | grep 'permitrootlogin'` -> `permitrootlogin yes`.
5.  **Diagnose the cause.**
    *   Ansible task has incorrect logic?
    *   Another process/config tool overwriting the setting? (e.g., `cloud-init`, manual edits)
    *   `authselect` overwrote a manual PAM change?
6.  **Fix the Ansible role** to be idempotent and correct, then re-run the playbook.

---

### ## reference.md Content
This is the deep-dive reference containing complete configurations, lists, and commands for implementing and verifying the CIS benchmark.

#### CIS-1, 10, 11: Complete Level 1 Control List (Abridged for Key Controls)
*Full list is extensive; this focuses on automatable, impactful server controls.*

| Control | Name | What it Does | Ansible Module | Verification | K3s Conflict |
|---|---|---|---|---|---|
| **Section 1: Initial Setup** |
| 1.1.1.1 | Disable `cramfs` | Disables an old, rarely used filesystem. | `community.general.modprobe` | `modprobe -n -v cramfs` | No |
| 1.1.1.2 | Disable `squashfs` | Disables a read-only compressed filesystem. | `community.general.modprobe` | `modprobe -n -v squashfs` | **Maybe.** Check container images. Usually safe. |
| 1.1.1.3 | Disable `udf` | Disables filesystem for optical media. | `community.general.modprobe` | `modprobe -n -v udf` | No |
| 1.1.3.1 | Set `nodev` on `/tmp` | Prevents character/block devices in `/tmp`. | `ansible.posix.mount` | `findmnt -n /tmp \| grep nodev` | No |
| 1.1.3.2 | Set `nosuid` on `/tmp` | Prevents SUID/SGID bits from taking effect. | `ansible.posix.mount` | `findmnt -n /tmp \| grep nosuid` | No |
| 1.1.3.3 | Set `noexec` on `/tmp` | Prevents running executables from `/tmp`. | `ansible.posix.mount` | `findmnt -n /tmp \| grep noexec` | **Yes (Installer)** |
| 1.1.8.1 | Set `nodev` on `/dev/shm` | Prevents devices in shared memory. | `ansible.posix.mount` | `findmnt -n /dev/shm \| grep nodev` | No |
| 1.3.1 | Install AIDE | Installs Advanced Intrusion Detection Environment. | `ansible.builtin.package` | `rpm -q aide` | No |
| 1.5.1 | Restrict Core Dumps | Prevents processes from creating core dumps. | `ansible.posix.sysctl` | `sysctl fs.suid_dumpable` | **Yes (Debug)** |
| 1.5.3 | Enable ASLR | Randomizes virtual memory layout. | `ansible.posix.sysctl` | `sysctl kernel.randomize_va_space` | No |
| 1.6.1 | Configure SELinux | Ensures SELinux is installed and not disabled. | `ansible.posix.selinux` | `getenforce` & `sestatus` | No |
| **Section 2: Services** |
| 2.1.1 | Disable `chrony` (if not used) | Disables time sync service if another is used. | `ansible.builtin.service` | `systemctl is-enabled chronyd` | No, needed. |
| 2.1.2| Disable `cupsd` | Disables printing service. | `ansible.builtin.service` | `systemctl is-enabled cups` | No |
| 2.1.3 | Disable `avahi-daemon` | Disables mDNS/zeroconf networking. | `ansible.builtin.service` | `systemctl is-enabled avahi-daemon` | No |
| 2.2.2 | Remove `telnet` client | Removes unencrypted remote access client. | `ansible.builtin.package` | `rpm -q telnet` | No |
| **Section 3: Network Config** |
| 3.2.1 | Disable IP Forwarding | Prevents host from acting as a router. | `ansible.posix.sysctl` | `sysctl net.ipv4.ip_forward` | **Yes (Critical)** |
| 3.2.2 | Disable Send Packet Redirects | Prevents host from sending ICMP redirects. | `ansible.posix.sysctl` | `sysctl net.ipv4.conf.all.send_redirects`| No |
| 3.3.1 | Disable Source Routed Packets | Rejects packets with source route option. | `ansible.posix.sysctl` | `sysctl net.ipv4.conf.all.accept_source_route`| No |
| 3.3.2 | Disable ICMP Redirects | Prevents host from accepting ICMP redirects. | `ansible.posix.sysctl` | `sysctl net.ipv4.conf.all.accept_redirects`| **Maybe.** Some CNIs may need it. Test. |
| 3.5.1.1 | Install `firewalld` | Installs the dynamic firewall daemon. | `ansible.builtin.package` | `rpm -q firewalld` | No |
| **Section 4: Logging & Auditing** |
| 4.1.1.1| Enable `auditd` | Ensures the audit daemon runs on boot. | `ansible.builtin.service` | `systemctl is-enabled auditd` | No |
| 4.1.2.x| Configure Audit Rules | Sets up rules to monitor critical system events. | `ansible.builtin.copy` | `auditctl -l` | **Yes (Perf)**|
| 4.2.1.4| Configure `journald` | Sets journald to be persistent. | `ansible.builtin.lineinfile` | `grep '^Storage' /etc/systemd/journald.conf`| No |
| **Section 5: Access & Auth** |
| 5.2.2 | Configure `sshd` Protocol | Ensures only SSH Protocol 2 is used. | `ansible.builtin.lineinfile` | `sshd -T \| grep protocol` | No |
| 5.2.5 | Deny Root Login | Prevents root user from logging in via SSH. | `ansible.builtin.lineinfile` | `sshd -T \| grep permitrootlogin` | No |
| 5.2.6 | Configure Idle Timeout | Sets idle connection timeout to disconnect clients. | `ansible.builtin.lineinfile` | `sshd -T \| grep clientaliveinterval` | No |
| 5.2.8 | Disable Rhosts | Disables insecure Rhosts authentication. | `ansible.builtin.lineinfile` | `sshd -T \| grep ignorerhosts` | No |
| 5.2.11| Disable X11 Forwarding| Disables forwarding of X11 graphical sessions. | `ansible.builtin.lineinfile` | `sshd -T \| grep x11forwarding` | No |
| 5.3.1 | Set Password Creation Req. | Enforces password complexity with `pam_pwquality`.| `ansible.builtin.lineinfile` | `grep minlen /etc/security/pwquality.conf` | No |
| 5.3.2 | Set Lockout for Failed Logins| Locks accounts after failed login attempts. | `authselect` | `authselect current` & `grep pam_faillock.so /etc/pam.d/password-auth` | No |
| 5.4.4 | Set Default `umask` | Sets a restrictive default umask of `027`. | `ansible.builtin.lineinfile`| `grep umask /etc/bashrc` | No |

---
**CIS-10: Kernel Parameter Conflict Table**

| sysctl parameter | CIS required value | K3s required value | Conflict? | Resolution for K3s Nodes |
|---|---|---|---|---|
| `net.ipv4.ip_forward` | `0` | `1` | **Yes** | Set to `1`. Document as a required exception for pod networking. |
| `net.bridge.bridge-nf-call-iptables` | `0` | `1` | **Yes** | Set to `1`. Required for container traffic to be processed by `iptables`. |
| `net.bridge.bridge-nf-call-ip6tables` | `0` | `1` | **Yes** | Set to `1`. Required for container IPv6 traffic. |
| `net.ipv4.conf.all.accept_redirects`| `0` | Default (`1`) | **Maybe** | Set to `0`. Most CNIs do not require redirects. Monitor for issues. |
| `net.ipv4.conf.all.rp_filter` | `1` (strict) | `1` or `2` | **Maybe** | Set to `1`. Flannel can have issues; if so, change to `2` (loose) for interfaces it manages. |
| `fs.suid_dumpable` | `0` | `0` | No Conflict | Set to `0`. Core dumps are a security risk. |
| `kernel.randomize_va_space` | `2` | `2` | No Conflict | Set to `2` (Full ASLR). |
| `kernel.dmesg_restrict` | `1` | Default (`0`) | **Yes** | Set to `1`, but note that non-root users (like `kubectl logs` for some drivers) may lose dmesg access. |
| `fs.inotify.max_user_watches`| Default | `524288`+ | **Yes** | Set to `524288`. This is a hard requirement for kubelet at scale. CIS has no opinion. |
| `vm.overcommit_memory` | Default (`0`) | `1` | **Yes** | Set to `1`. Kubernetes scheduler assumes overcommit is enabled for reliable QoS. |

---
**CIS-6: Hardened `sshd_config` Template for AlmaLinux 9 (Port 2222)**

```jinja
#
# Helix Stax Hardened SSH Configuration
# CIS AlmaLinux 9 Benchmark v1.0.1
#
# Customizations: Port 2222, User 'wakeem'
#

# 5.2.1 Set port
Port 2222

# 5.2.2 Use Protocol 2
Protocol 2

# 5.2.3 Set LogLevel to VERBOSE
LogLevel VERBOSE

# 5.2.4 Configure Idle Timeout Interval
ClientAliveInterval 300
ClientAliveCountMax 3

# 5.2.5 Deny root login
PermitRootLogin no

# 5.2.6 Set max authentication retries
MaxAuthTries 4

# 5.2.7 Enable public key authentication
PubkeyAuthentication yes

# 5.2.8 Disable rhosts
IgnoreRhosts yes
HostbasedAuthentication no

# 5.2.9 Disable environment processing
PermitUserEnvironment no

# 5.2.10 Use Strong Ciphers, MACs, an KEX
# RHEL 9 default crypto policies are strong and sufficient for CIS Level 1
# Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes128-gcm@openssh.com,aes128-ctr
# MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
# KexAlgorithms ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

# 5.2.11 Disable X11 forwarding
X11Forwarding no

# 5.2.12 Set MaxSessions
MaxSessions 10

# 5.2.13 Disable password authentication
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# 5.2.14 Use PAM
UsePAM yes

# 5.2.15 Disable TCP Forwarding and Tunnels
# K3s may need this for `kubectl port-forward`. `local` is a safe compromise.
AllowTcpForwarding local
PermitTunnel no
GatewayPorts no

# 5.2.16 Set login banner
Banner /etc/issue.net

# Helix Stax specific: Restrict access to a specific user
AllowUsers wakeem
```

---
**CIS-3 & CIS-9: SELinux and PAM Configuration (`authselect`)**

**SELinux:**
1.  **Install Base Packages:** `policycoreutils`, `policycoreutils-python-utils`, `libselinux`.
2.  **Install K3s Policy:** Add Rancher repo, then `dnf install k3s-selinux`. This provides necessary types and booleans.
3.  **Ensure Enforcing Mode:** `/etc/selinux/config` should have `SELINUX=enforcing`. Verify with `getenforce`. `sestatus` should show `Enforcing` and `targeted` policy.
4.  **Key Booleans for K3s:** The `k3s-selinux` package handles this. The most important one is `container_manage_cgroup`, which allows container runtimes to manage cgroups.
5.  **Troubleshooting AVC Denials:** Use `ausearch -m avc -ts recent` to find denials. Pipe the output to `audit2allow -a` to see suggested rules. Use `audit2allow -a -M my-k3s-module` to create a local policy module to load.

**PAM on AlmaLinux 9:**
**Warning:** Do NOT edit `/etc/pam.d/*` files directly. Use `authselect`.
1.  **Select Base Profile:** Start with a sane default. `sudo authselect select minimal with-faillock`
2.  **Configure `pwquality`:** Edit `/etc/security/pwquality.conf`.
    *   `minlen = 14`
    *   `dcredit = -1` (at least 1 digit)
    *   `ucredit = -1` (at least 1 uppercase)
    *   `lcredit = -1` (at least 1 lowercase)
    *   `ocredit = -1` (at least 1 special char)
    *   `minclass = 4` (requires all 4 classes if set)
3.  **Configure `pam_pwhistory`:** Add `remember=5` to the `password` stack line in `/etc/pam.d/password-auth` and `system-auth` *after* running `authselect`. This must be done via a post-configuration script or careful `lineinfile`. Better to create a custom `authselect` profile.
4.  **Configure Account Lockout (`pam_faillock`):** The `with-faillock` feature adds this. Configure it in `/etc/security/faillock.conf`.
    *   `deny = 5`
    *   `unlock_time = 900` (15 minutes)
5.  **Restrict `su`:** Add the following line to `/etc/pam.d/su`.
    `auth required pam_wheel.so use_uid`

---
**CIS-4 & CIS-8: Auditd Rule Set for `/etc/audit/rules.d/cis.rules`**

```
## CIS AlmaLinux 9 v1.0.1 - Audit Rules

# Exclude container noise to improve performance
-a never,exit -F path=/var/lib/containerd

# 4.1.2.1 Audit alterations to time
-w /etc/localtime -p wa -k time-change
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change

# 4.1.2.2 Audit user/group modifications
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# 4.1.2.3 Audit network configuration
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale

# 4.1.2.4 Audit MAC modifications
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k mounts

# 4.1.2.5 Audit session initiation
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins

# 4.1.2.6 Audit discretionary access control
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod

# 4.1.2.7 Audit unsuccessful unauthorized access
-a always,exit -F arch=b64 -S open -S openat -S open_by_handle_at -S creat -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b32 -S open -S openat -S open_by_handle_at -S creat -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b64 -S open -S openat -S open_by_handle_at -S creat -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b32 -S open -S openat -S open_by_handle_at -S creat -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access

# 4.1.2.9 Audit sudoers
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# 4.1.2.14 Audit kernel module loading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# 4.1.2.15 Make audit config immutable
-e 2
```

---
**CIS-7: `firewalld` Rule Set for K3s Nodes (`ansible.posix.firewalld`)**

*Default zone is `public`, with default target `DROP`. Only explicitly allowed traffic passes.*

1.  **Set default zone and target:**
    `firewall-cmd --set-default-zone=public`
    `firewall-cmd --permanent --zone=public --set-target=DROP`
2.  **Allow SSH:**
    `firewall-cmd --permanent --zone=public --add-port=2222/tcp`
3.  **Allow K3s API (Control Plane):** Restrict to trusted IPs if possible.
    `firewall-cmd --permanent --zone=public --add-port=6443/tcp`
    *(Optional Rich Rule):* `firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="YOUR_OFFICE_IP/32" port port="6443" protocol="tcp" accept'`
4.  **Allow Kubelet (All Nodes):**
    `firewall-cmd --permanent --zone=public --add-port=10250/tcp`
5.  **Allow Flannel VXLAN (between nodes):** Create a `trusted` zone for inter-node traffic.
    `firewall-cmd --permanent --new-zone=k3s-nodes`
    `firewall-cmd --permanent --zone=k3s-nodes --add-source=NODE1_IP`
    `firewall-cmd --permanent --zone=k3s-nodes --add-source=NODE2_IP`
    `firewall-cmd --permanent --zone=k3s-nodes --add-port=8472/udp`
6.  **Allow etcd (Control Planes, internal only):**
    `firewall-cmd --permanent --zone=k3s-nodes --add-port=2379-2380/tcp`
7.  **Reload firewall:**
    `firewall-cmd --reload`
8.  **Verification:**
    `firewall-cmd --list-all`

---
**CIS-12: OpenSCAP Scanning for AlmaLinux 9**

1.  **Install tools:**
    `dnf install openscap-scanner scap-security-guide`
2.  **Find the CIS profile:**
    `oscap info /usr/share/xml/scap/ssg/almalinux/ssg-almalinux9-ds.xml`
    *Look for a profile like `xccdf_org.ssgproject.content_profile_cis_level1_server`*
3.  **Run scan and generate report:**
    ```bash
    PROFILE="xccdf_org.ssgproject.content_profile_cis_level1_server"
    REPORT_FILE="almalinux9-cis-report.html"
    oscap xccdf eval \
      --profile $PROFILE \
      --results-arf results.xml \
      --report $REPORT_FILE \
      /usr/share/xml/scap/ssg/almalinux/ssg-almalinux9-ds.xml
    ```
4.  **Review `almalinux9-cis-report.html`:** Look for `fail` results. Note that it will fail K3s exception controls (like IP forwarding). These must be manually accepted.
5.  **DO NOT RUN REMEDIATION BLINDLY:** `oscap xccdf remediate` will break K3s by disabling IP forwarding and other required settings. Use the report to inform Ansible role fixes only.

---

### ## examples.md Content
This section contains copy-paste-ready, fully annotated examples for the Helix Stax environment.

#### Ansible `cis-hardening` Role Structure

```
roles/cis-hardening/
├── tasks/
│   ├── main.yml
│   ├── 01_initial_setup.yml
│   ├── 02_services.yml
│   ├── 03_network.yml
│   ├── 04_logging.yml
│   ├── 05_auth.yml
│   └── 06_maintenance.yml
├── templates/
│   ├── sshd_config.j2
│   └── cis_audit.rules.j2
├── files/
│   └── issue.net
└── handlers/
    └── main.yml
```

#### Annotated Playbook: `harden-almalinux9.yml`

```yaml
---
- name: Harden AlmaLinux 9 servers according to CIS Level 1
  hosts: all
  become: true
  vars:
    # -- Helix Stax Specific Vars --
    admin_user: wakeem
    ssh_port: 2222
    # -- K3s Node Configuration --
    is_k3s_node: true # Set to false for non-K3s servers
    k3s_node_ips: # For trusted firewall zone
      - 178.156.233.12
      - 5.78.145.30
      # Add other node IPs here

  roles:
    - role: cis-hardening
```

#### Example Ansible Task File: `roles/cis-hardening/tasks/03_network.yml`

```yaml
---
- name: "3.2.1 | K3S EXCEPTION | Ensure IP forwarding is enabled for K3s"
  when: is_k3s_node
  ansible.posix.sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    sysctl_set: true
    state: present
    reload: true
    sysctl_file: /etc/sysctl.d/98-k3s-hardening.conf
  tags: [cis, cis.3, cis.3.2.1]

- name: "3.2.1 | Ensure IP forwarding is disabled (non-K3s)"
  when: not is_k3s_node
  ansible.posix.sysctl:
    name: net.ipv4.ip_forward
    value: '0'
    sysctl_set: true
    state: present
    reload: true
  tags: [cis, cis.3, cis.3.2.1]

- name: "3.2.2 | K3S EXCEPTION | Ensure bridge-nf-call-iptables is enabled for K3s"
  when: is_k3s_node
  ansible.posix.sysctl:
    name: net.bridge.bridge-nf-call-iptables
    value: '1'
    sysctl_set: true
    state: present
    reload: true
    sysctl_file: /etc/sysctl.d/98-k3s-hardening.conf
  tags: [cis, cis.3, cis.3.2.2]

# --- FIREWALLD RULES ---
- name: "3.5.x | Install and enable firewalld"
  ansible.builtin.package:
    name: firewalld
    state: present
- name: "3.5.x | Start firewalld service"
  ansible.builtin.service:
    name: firewalld
    state: started
    enabled: true

- name: "3.5.x | Set default zone to public and target to DROP"
  ansible.builtin.shell: |
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --zone=public --set-target=DROP
  changed_when: false # Idempotency is complex, run once or build better logic

- name: "3.5.x | Allow SSH on custom port {{ ssh_port }}"
  ansible.posix.firewalld:
    port: "{{ ssh_port }}/tcp"
    permanent: true
    state: enabled
    zone: public
    immediate: true

- name: "3.5.x | K3s | Allow K3s API server"
  when: is_k3s_node
  ansible.posix.firewalld:
    port: 6443/tcp
    permanent: true
    state: enabled
    zone: public
    immediate: true

- name: "3.5.x | K3s | Allow Flannel VXLAN"
  when: is_k3s_node
  ansible.posix.firewalld:
    port: 8472/udp
    permanent: true
    state: enabled
    zone: public # Or a 'trusted' zone with source IPs
    immediate: true
```

#### Runbook: "Apply CIS Level 1 to a new Hetzner server before K3s installation"

1.  **Provision Server:** Create a new CX/CPX series server on Hetzner Cloud with AlmaLinux 9.
2.  **Initial Access:** SSH into the server as `root` using the key provided at creation.
3.  **Create Admin User:**
    ```bash
    # Create user
    useradd -m -s /bin/bash wakeem
    # Add to wheel group for sudo
    usermod -aG wheel wakeem
    # Set up SSH key
    mkdir -p /home/wakeem/.ssh
    cp /root/.ssh/authorized_keys /home/wakeem/.ssh/
    chown -R wakeem:wakeem /home/wakeem/.ssh
    chmod 700 /home/wakeem/.ssh
    chmod 600 /home/wakeem/.ssh/authorized_keys
    # Test sudo
    su - wakeem
    sudo whoami # Should return root
    exit
    ```
4.  **Add to Ansible Inventory:** Add the new server's IP (e.g., `5.78.145.30`) to your Ansible inventory file under a `[k3s_nodes]` group.
5.  **Run Hardening Playbook:** From your Ansible control node:
    `ansible-playbook -i inventory/hosts harden-almalinux9.yml --limit=5.78.145.30`
6.  **Verify Hardening:**
    *   SSH to the server with `ssh -p 2222 wakeem@5.78.145.30`. Root login should be denied.
    *   Run the OpenSCAP scan as described in `reference.md`.
    ```bash
    # On the hardened server
    sudo dnf install -y openscap-scanner scap-security-guide
    PROFILE="xccdf_org.ssgproject.content_profile_cis_level1_server"
    sudo oscap xccdf eval --profile $PROFILE --report /tmp/initial-scan.html /usr/share/xml/scap/ssg/almalinux/ssg-almalinux9-ds.xml
    ```
    *   Review `/tmp/initial-scan.html`. Score should be >80-85%. Failures should be expected K3s exceptions (IP forwarding, etc.) or manual items.
7.  **Install K3s:** Now that the server is hardened with K3s exceptions, proceed with the K3s installation using your standard Ansible role or script.
8.  **Final Verification:** After K3s is running, run the OpenSCAP scan again to ensure K3s installation didn't revert any security settings.

#### CI Integration: GitHub Actions to Run Audit Script

**`.github/workflows/security-audit.yml`**

```yaml
name: 'Security Compliance Audit'

on:
  schedule:
    - cron: '0 2 * * 1' # Run every Monday at 2 AM UTC
  workflow_dispatch:

jobs:
  audit-prod-nodes:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [ "helix-stax-cp", "helix-stax-vps" ]
        ip: [ "178.156.233.12", "5.78.145.30" ]

    steps:
    - name: 'Checkout audit script repository'
      uses: actions/checkout@v3

    - name: 'Run hardening-audit.sh on ${{ matrix.node }}'
      uses: appleboy/ssh-action@master
      with:
        host: ${{ matrix.ip }}
        username: wakeem
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        port: 2222
        script: |
          # Copy a remote script or have it pre-exist on the node
          # For this example, we assume it's at /usr/local/bin/hardening-audit.sh
          # The script should exit with a non-zero status code on failure.
          sudo /usr/local/bin/hardening-audit.sh
```

**`hardening-audit.sh` (Outline)**

This script should be placed on each server.

```bash
#!/bin/bash
# hardening-audit.sh - Quick compliance check for Helix Stax
set -e

FAIL=0
PASS=0
log_check() {
    local name="$1"
    local status="$2"
    if [ "$status" -eq 0 ]; then
        echo "[PASS] $name"
        ((PASS++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

# --- K3s Specific Checks (Expected to be 'non-compliant' with CIS) ---
check_ip_forwarding() { [[ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]]; }
log_check "K3S EXCEPTION: IP Forwarding is 1" $?

check_bridge_nf() { [[ $(sysctl -n net.bridge.bridge-nf-call-iptables) -eq 1 ]]; }
log_check "K3S EXCEPTION: bridge-nf-call-iptables is 1" $?

# --- Standard CIS Checks ---
check_selinux() { [[ $(getenforce) == "Enforcing" ]]; }
log_check "SELinux is Enforcing" $?

check_ssh_port() { sudo sshd -T | grep -q "port 2222"; }
log_check "SSH Port is 2222" $?

check_root_login() { sudo sshd -T | grep -q "permitrootlogin no"; }
log_check "SSH PermitRootLogin is no" $?

check_firewalld_ssh() { sudo firewall-cmd --list-ports --zone=public | grep -q "2222/tcp"; }
log_check "Firewalld allows port 2222/tcp" $?

check_firewalld_k3s_api() { sudo firewall-cmd --list-ports --zone=public | grep -q "6443/tcp"; }
log_check "Firewalld allows port 6443/tcp" $?

check_tmp_noexec() { findmnt -n /tmp | grep -q "noexec"; }
log_check "/tmp is mounted noexec" $?

# --- Summary ---
TOTAL=$((PASS + FAIL))
SCORE=$((PASS * 100 / TOTAL))
echo "-------------------------------------"
echo "Compliance Score: $SCORE% ($PASS / $TOTAL passed)"
echo "-------------------------------------"

if [ $SCORE -lt 95 ]; then
    echo "Audit FAILED: Score is below 95%."
    exit 1
fi

echo "Audit PASSED."
exit 0
```
