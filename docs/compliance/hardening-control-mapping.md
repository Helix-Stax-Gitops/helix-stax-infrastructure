# Server Hardening Control Mapping Matrix

**Author:** Wakeem Williams
**Co-Author:** Quinn Mercer
**Date:** 2026-03-23
**Purpose:** Map each hardening step to all applicable compliance framework controls
**Companion Document:** [Server Hardening Evidence -- 2026-03-23](server-hardening-evidence-2026-03-23.md)

---

## Control Mapping Matrix

### Step 1: System Updates

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.8 | Prevent or detect against unauthorized or malicious software |
| ISO 27001:2022 | A.8.8 | Management of technical vulnerabilities |
| NIST CSF 2.0 | PR.IP-12 | Vulnerability management plan implemented |
| CIS Controls v8 | 7.3 | Perform automated operating system patch management |
| CIS Controls v8 | 7.4 | Perform automated application patch management |
| CIS AlmaLinux 9 | 1.9 | Ensure updates, patches, and additional security software are installed |
| HIPAA | 164.308(a)(5)(ii)(B) | Protection from malicious software |

---

### Step 2: SSH Hardening

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC6.2 | Prior to issuing system credentials, registered and authorized |
| ISO 27001:2022 | A.8.5 | Secure authentication |
| ISO 27001:2022 | A.8.9 | Configuration management |
| NIST CSF 2.0 | PR.AC-1 | Identities and credentials are issued, managed, verified |
| NIST CSF 2.0 | PR.AC-7 | Users, devices, and other assets are authenticated |
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

---

### Step 3: Firewall (firewalld)

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| SOC 2 Type II | CC6.7 | Restrict the transmission of information |
| ISO 27001:2022 | A.8.20 | Networks security |
| ISO 27001:2022 | A.8.21 | Security of network services |
| ISO 27001:2022 | A.8.22 | Segregation of networks |
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| NIST CSF 2.0 | PR.PT-4 | Communications and control networks are protected |
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
| HIPAA | 164.312(e)(1) | Transmission security |

---

### Step 4: Hetzner Cloud Firewalls

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| ISO 27001:2022 | A.8.20 | Networks security |
| ISO 27001:2022 | A.8.21 | Security of network services |
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| CIS Controls v8 | 12.2 | Establish and maintain a secure network architecture |
| CIS Controls v8 | 13.1 | Centralize security event alerting |

---

### Step 5: fail2ban

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC6.8 | Prevent or detect against unauthorized or malicious software |
| ISO 27001:2022 | A.8.5 | Secure authentication |
| ISO 27001:2022 | A.8.16 | Monitoring activities |
| NIST CSF 2.0 | PR.AC-7 | Users, devices, and other assets are authenticated |
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | RS.MI-1 | Incidents are contained |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS Controls v8 | 8.5 | Collect detailed audit logs |
| CIS AlmaLinux 9 | 5.2.20 | Ensure SSH Idle Timeout Interval is configured |
| HIPAA | 164.312(a)(1) | Access control |
| HIPAA | 164.312(b) | Audit controls |

---

### Step 6: SELinux

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.3 | Authorize, modify, or remove access to data and software |
| ISO 27001:2022 | A.8.2 | Privileged access rights |
| ISO 27001:2022 | A.8.3 | Information access restriction |
| NIST CSF 2.0 | PR.AC-4 | Access permissions and authorizations are managed |
| CIS Controls v8 | 3.3 | Configure data access control lists |
| CIS AlmaLinux 9 | 1.6.1.1 | Ensure SELinux is installed |
| CIS AlmaLinux 9 | 1.6.1.2 | Ensure SELinux is not disabled in bootloader configuration |
| CIS AlmaLinux 9 | 1.6.1.3 | Ensure SELinux policy is configured |
| CIS AlmaLinux 9 | 1.6.1.4 | Ensure the SELinux mode is not disabled |
| CIS AlmaLinux 9 | 1.6.1.5 | Ensure the SELinux mode is enforcing |
| HIPAA | 164.312(a)(1) | Access control |

---

### Step 7: CIS Level 1 Benchmark

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC8.1 | Monitor changes to infrastructure and software |
| ISO 27001:2022 | A.8.9 | Configuration management |
| ISO 27001:2022 | A.8.19 | Installation of software on operational systems |
| NIST CSF 2.0 | PR.IP-1 | A baseline configuration of IT/OT systems is created and maintained |
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

---

### Step 8: Audit Logging (auditd)

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC7.1 | Use of monitoring and detection mechanisms |
| SOC 2 Type II | CC7.2 | Monitor system components for anomalies |
| ISO 27001:2022 | A.8.15 | Logging |
| ISO 27001:2022 | A.8.16 | Monitoring activities |
| ISO 27001:2022 | A.8.17 | Clock synchronization |
| NIST CSF 2.0 | DE.AE-3 | Event data are collected and correlated |
| NIST CSF 2.0 | DE.CM-1 | The network is monitored to detect potential cybersecurity events |
| NIST CSF 2.0 | DE.CM-3 | Personnel activity is monitored |
| NIST CSF 2.0 | PR.PT-1 | Audit/log records are maintained |
| CIS Controls v8 | 8.2 | Collect audit logs |
| CIS Controls v8 | 8.5 | Collect detailed audit logs |
| CIS Controls v8 | 8.9 | Centralize audit logs |
| CIS AlmaLinux 9 | 4.1.1.1 | Ensure auditd is installed |
| CIS AlmaLinux 9 | 4.1.1.2 | Ensure auditd service is enabled and running |
| CIS AlmaLinux 9 | 4.1.3.1 | Ensure events that modify date and time information are collected |
| CIS AlmaLinux 9 | 4.1.3.2 | Ensure events that modify user/group information are collected |
| CIS AlmaLinux 9 | 4.1.3.3 | Ensure events that modify the system's network environment are collected |
| CIS AlmaLinux 9 | 4.1.3.5 | Ensure login and logout events are collected |
| CIS AlmaLinux 9 | 4.1.3.7 | Ensure kernel module loading and unloading is collected |
| HIPAA | 164.312(b) | Audit controls |
| HIPAA | 164.308(a)(1)(ii)(D) | Information system activity review |

---

### Step 9: Kernel Tuning

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.6 | Restrict access through boundary protection devices |
| ISO 27001:2022 | A.8.9 | Configuration management |
| ISO 27001:2022 | A.8.20 | Networks security |
| NIST CSF 2.0 | PR.IP-1 | Baseline configuration maintained |
| NIST CSF 2.0 | PR.AC-5 | Network integrity is protected |
| CIS Controls v8 | 4.1 | Establish and maintain a secure configuration process |
| CIS AlmaLinux 9 | 3.2.1 | Ensure IP forwarding is disabled (exception documented) |
| CIS AlmaLinux 9 | 3.2.2 | Ensure packet redirect sending is disabled |
| CIS AlmaLinux 9 | 3.3.1 | Ensure source routed packets are not accepted |
| CIS AlmaLinux 9 | 3.3.2 | Ensure ICMP redirects are not accepted |
| CIS AlmaLinux 9 | 3.3.4 | Ensure suspicious packets are logged |
| CIS AlmaLinux 9 | 3.3.5 | Ensure broadcast ICMP requests are ignored |
| CIS AlmaLinux 9 | 3.3.7 | Ensure Reverse Path Filtering is enabled |
| CIS AlmaLinux 9 | 3.3.8 | Ensure TCP SYN Cookies is enabled |
| CIS AlmaLinux 9 | 3.3.9 | Ensure IPv6 router advertisements are not accepted |

---

### Step 10: Credential Scrub

| Framework | Control ID | Control Name |
|-----------|-----------|--------------|
| SOC 2 Type II | CC6.1 | Logical and physical access controls |
| SOC 2 Type II | CC6.7 | Restrict the transmission, movement, and removal of information |
| ISO 27001:2022 | A.8.10 | Information deletion |
| ISO 27001:2022 | A.8.11 | Data masking |
| NIST CSF 2.0 | PR.DS-3 | Assets are formally managed throughout removal and disposal |
| CIS Controls v8 | 3.4 | Enforce data retention management |
| CIS Controls v8 | 16.11 | Lock accounts when credential exposure is detected |
| HIPAA | 164.310(d)(2)(i) | Disposal of media and credentials |
| HIPAA | 164.312(a)(2)(iv) | Encryption and decryption |

---

## Framework Coverage Summary

### Controls Addressed per Framework

| Framework | Total Controls Addressed | Hardening Steps Covering |
|-----------|-------------------------|--------------------------|
| **SOC 2 Type II** | 10 distinct controls | CC6.1, CC6.2, CC6.3, CC6.6, CC6.7, CC6.8, CC7.1, CC7.2, CC8.1 + RS.MI-1 via fail2ban |
| **ISO 27001:2022** | 14 distinct controls | A.8.2, A.8.3, A.8.5, A.8.8, A.8.9, A.8.10, A.8.11, A.8.15, A.8.16, A.8.17, A.8.19, A.8.20, A.8.21, A.8.22 |
| **NIST CSF 2.0** | 14 distinct controls | PR.AC-1, PR.AC-4, PR.AC-5, PR.AC-7, PR.DS-3, PR.IP-1, PR.IP-12, PR.PT-1, PR.PT-4, DE.AE-3, DE.CM-1, DE.CM-3, RS.MI-1 |
| **CIS Controls v8** | 13 distinct safeguards | 3.3, 3.4, 4.1, 4.4, 4.5, 4.8, 5.2, 7.3, 7.4, 8.2, 8.5, 8.9, 9.2, 12.2, 13.1, 16.11 |
| **CIS AlmaLinux 9** | 35+ benchmark sections | 1.1.*, 1.6.*, 1.9, 2.1.*, 3.2.*, 3.3.*, 3.5.*, 4.1.*, 5.2.*, 6.1.* |
| **HIPAA** | 9 distinct sections | 164.308(a)(1)(ii)(D), 164.308(a)(5)(ii)(B), 164.310(d)(2)(i), 164.312(a)(1), 164.312(a)(2)(i), 164.312(a)(2)(iv), 164.312(b), 164.312(c)(1), 164.312(d), 164.312(e)(1) |

### Coverage by NIST CSF 2.0 Function

| Function | Controls Addressed | Steps Contributing |
|----------|--------------------|--------------------|
| **PROTECT (PR)** | PR.AC-1, PR.AC-4, PR.AC-5, PR.AC-7, PR.DS-3, PR.IP-1, PR.IP-12, PR.PT-1, PR.PT-4 | 1, 2, 3, 4, 5, 6, 7, 9, 10 |
| **DETECT (DE)** | DE.AE-3, DE.CM-1, DE.CM-3 | 4, 5, 8 |
| **RESPOND (RS)** | RS.MI-1 | 5 |
| **IDENTIFY (ID)** | -- | (Covered by asset inventory, not server hardening) |
| **RECOVER (RC)** | -- | (Covered by backup/DR, not server hardening) |

### Coverage by SOC 2 Trust Service Criteria

| Category | Controls Addressed | Steps Contributing |
|----------|--------------------|--------------------|
| **CC6 -- Logical & Physical Access** | CC6.1, CC6.2, CC6.3, CC6.6, CC6.7, CC6.8 | 1, 2, 3, 4, 5, 6, 7, 9, 10 |
| **CC7 -- System Operations** | CC7.1, CC7.2 | 8 |
| **CC8 -- Change Management** | CC8.1 | 7 |

---

## Gap Analysis

### Not Addressed by Server Hardening (requires separate controls)

| Framework | Control | Why Not Covered | Where Covered |
|-----------|---------|-----------------|---------------|
| SOC 2 | CC1-CC5 | Organizational controls, not technical | Policies, HR, governance |
| SOC 2 | CC9 | Risk mitigation | Risk assessment process |
| ISO 27001 | A.5.* | Information security policies | Policy documents |
| ISO 27001 | A.6.* | Organization of information security | Organizational structure |
| ISO 27001 | A.7.* | Human resource security | HR processes |
| NIST CSF | ID.* | Asset management, risk assessment | Asset inventory, risk register |
| NIST CSF | RC.* | Recovery planning | Backup/DR procedures |
| HIPAA | 164.308 (most) | Administrative safeguards | Policies, training, procedures |
| HIPAA | 164.310 (most) | Physical safeguards | Facility controls |
| CIS v8 | 1-2 | Hardware/software inventory | Asset management system |
| CIS v8 | 14-18 | Application security, incident response, training | Separate programs |

---

*This mapping is maintained alongside the hardening evidence document and should be updated whenever hardening procedures change or new compliance frameworks are added.*
