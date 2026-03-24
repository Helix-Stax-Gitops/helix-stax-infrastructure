---
title: OpenSCAP Tailoring Specification for K3s Nodes
author: Wakeem Williams
co_author: Ezra Raines
date: 2026-03-23
version: "1.0"
status: draft
scope: OpenSCAP CIS L1 tailoring for K3s-compatible AlmaLinux 9 scanning
target_os: AlmaLinux 9.7
base_profile: xccdf_org.ssgproject.content_profile_cis_server_l1
tailoring_file: /etc/security/scap/helix-stax-k3s-tailoring.xml
compliance_mapping:
  soc2:
    - CC4.1  # Monitoring of Internal Controls
    - CC7.2  # System Monitoring
  iso27001:
    - A.8.8   # Management of technical vulnerabilities
    - A.8.15  # Logging
  nist_csf:
    - DE.CM-3  # Security continuous monitoring
    - PR.IP-1  # Baseline configuration
---

# OpenSCAP Tailoring Specification

## 1. Overview

K3s requires specific kernel parameters and modules that conflict with CIS Benchmark Level 1 controls. This document defines a tailoring profile that excepts conflicting controls while selectively including high-value Level 2 controls, producing a scan profile purpose-built for Helix Stax K3s nodes.

## 2. Base Profile

| Attribute | Value |
|-----------|-------|
| Profile ID | `xccdf_org.ssgproject.content_profile_cis_server_l1` |
| Content file | `/usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml` |
| SSG version | `scap-security-guide >= 0.1.72` |
| Platform | AlmaLinux 9.7 (x86_64) |

Install prerequisites:

```bash
sudo dnf install -y openscap-scanner scap-security-guide openscap-utils
```

Verify content availability:

```bash
oscap info /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml | grep -i "cis_server_l1"
```

## 3. Controls to EXCEPT (K3s Conflicts)

The following CIS L1 rules must be excepted because K3s networking (Flannel CNI, pod-to-pod routing) requires these kernel parameters and modules to be in a non-compliant state.

### 3.1 IP Forwarding

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_ip_forward` |
| CIS Control | 3.1.1 - Ensure IP forwarding is not enabled |
| Required K3s value | `net.ipv4.ip_forward = 1` |
| Reason | K3s pods communicate across nodes via IP forwarding. Disabling breaks all pod networking. |

### 3.2 Bridge Netfilter (iptables)

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_sysctl_net_bridge_bridge-nf-call-iptables` |
| CIS Control | 3.1.2 - Ensure packet redirect sending is not allowed |
| Required K3s value | `net.bridge.bridge-nf-call-iptables = 1` |
| Reason | Flannel CNI requires bridged traffic to pass through iptables for NetworkPolicy enforcement. |

### 3.3 br_netfilter Kernel Module

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_kernel_module_br_netfilter_disabled` |
| CIS Control | 3.1 - Network Parameters (related) |
| Required K3s state | Module `br_netfilter` must be **loaded** |
| Reason | Required for bridge netfilter functionality. K3s loads this at startup. |

### 3.4 Overlay Kernel Module

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_kernel_module_overlay_disabled` |
| CIS Control | 1.1.1 - Disable unused filesystems |
| Required K3s state | Module `overlay` must be **loaded** |
| Reason | containerd uses the overlayfs storage driver. Disabling prevents container image layers from functioning. |

### 3.5 Summary of Excepted Rules

```
xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_ip_forward
xccdf_org.ssgproject.content_rule_sysctl_net_bridge_bridge-nf-call-iptables
xccdf_org.ssgproject.content_rule_kernel_module_br_netfilter_disabled
xccdf_org.ssgproject.content_rule_kernel_module_overlay_disabled
```

## 4. Selective Level 2 Controls to INCLUDE

The following CIS Level 2 controls provide significant security value with no K3s conflict and are selectively included in the tailored profile.

### 4.1 IPv6 Kernel Disable

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_all_disable_ipv6` |
| CIS Control | 3.1 (L2) - Disable IPv6 |
| Configuration | `net.ipv6.conf.all.disable_ipv6 = 1` |
| Rationale | Hetzner nodes do not use IPv6 for cluster communication. Disabling reduces attack surface. |

Additional sysctl entries:

```bash
# /etc/sysctl.d/91-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

### 4.2 Auditd Immutability

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_audit_rules_immutable` |
| CIS Control | 4.1.17 (L2) - Make the audit configuration immutable |
| Configuration | `-e 2` as the final line in `/etc/audit/rules.d/99-finalize.rules` |
| Rationale | Prevents any process (including root) from modifying audit rules at runtime. Changes require reboot. |

```bash
# /etc/audit/rules.d/99-finalize.rules
-e 2
```

### 4.3 DCCP Protocol Blacklist

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled` |
| CIS Control | 3.4.1 (L2) - Ensure DCCP is disabled |
| Configuration | `install dccp /bin/true` in `/etc/modprobe.d/k3s-blacklist.conf` |
| Rationale | DCCP is unused; historical vulnerability target. |

### 4.4 SCTP Protocol Blacklist

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled` |
| CIS Control | 3.4.2 (L2) - Ensure SCTP is disabled |
| Configuration | `install sctp /bin/true` in `/etc/modprobe.d/k3s-blacklist.conf` |
| Rationale | SCTP is unused; reduces kernel attack surface. |

### 4.5 RDS Protocol Blacklist

| Attribute | Value |
|-----------|-------|
| Rule ID | `xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled` |
| CIS Control | 3.4.3 (L2) - Ensure RDS is disabled |
| Configuration | `install rds /bin/true` in `/etc/modprobe.d/k3s-blacklist.conf` |
| Rationale | RDS is unused; reduces kernel attack surface. |

### 4.6 Protocol Blacklist File

```bash
# /etc/modprobe.d/k3s-blacklist.conf
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
```

### 4.7 Summary of Included L2 Rules

```
xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_all_disable_ipv6
xccdf_org.ssgproject.content_rule_audit_rules_immutable
xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled
xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled
xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled
```

## 5. Tailoring File Structure

### 5.1 XML Structure

The tailoring file extends the base CIS L1 profile by deselecting conflicting rules and selecting additional L2 rules:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xccdf-1.2:Tailoring xmlns:xccdf-1.2="http://checklists.nist.gov/xccdf/1.2"
  id="xccdf_helixstax.com_tailoring_k3s-almalinux9">
  <xccdf-1.2:benchmark href="/usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml"/>
  <xccdf-1.2:version time="2026-03-23T00:00:00">1.0</xccdf-1.2:version>
  <xccdf-1.2:Profile id="xccdf_helixstax.com_profile_cis_server_l1_k3s"
    extends="xccdf_org.ssgproject.content_profile_cis_server_l1">
    <xccdf-1.2:title>CIS Server L1 - K3s Tailored (Helix Stax)</xccdf-1.2:title>
    <xccdf-1.2:description>
      CIS AlmaLinux 9 Level 1 Server profile tailored for K3s nodes.
      Excepts IP forwarding, bridge netfilter, and kernel module rules
      that conflict with Kubernetes networking. Includes select L2 controls
      for defense-in-depth (IPv6 disable, auditd immutability, protocol blacklists).
    </xccdf-1.2:description>

    <!-- EXCEPTED: K3s requires ip_forward=1 -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_ip_forward" selected="false"/>

    <!-- EXCEPTED: K3s requires bridge-nf-call-iptables=1 -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_sysctl_net_bridge_bridge-nf-call-iptables" selected="false"/>

    <!-- EXCEPTED: K3s requires br_netfilter loaded -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_kernel_module_br_netfilter_disabled" selected="false"/>

    <!-- EXCEPTED: containerd requires overlay module -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_kernel_module_overlay_disabled" selected="false"/>

    <!-- INCLUDED L2: Disable IPv6 -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_all_disable_ipv6" selected="true"/>

    <!-- INCLUDED L2: Auditd immutability (-e 2) -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_audit_rules_immutable" selected="true"/>

    <!-- INCLUDED L2: Disable DCCP protocol -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled" selected="true"/>

    <!-- INCLUDED L2: Disable SCTP protocol -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled" selected="true"/>

    <!-- INCLUDED L2: Disable RDS protocol -->
    <xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled" selected="true"/>
  </xccdf-1.2:Profile>
</xccdf-1.2:Tailoring>
```

### 5.2 File Location

```
/etc/security/scap/helix-stax-k3s-tailoring.xml
```

Ensure directory exists:

```bash
sudo mkdir -p /etc/security/scap
```

## 6. Generating the Tailoring File with autotailor

As an alternative to manually writing XML, use the `autotailor` utility from the `openscap-utils` package:

```bash
# Install openscap-utils if not already present
sudo dnf install -y openscap-utils

# Generate tailoring file using autotailor
autotailor \
  --output /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --id-namespace helixstax.com \
  --new-profile-id xccdf_helixstax.com_profile_cis_server_l1_k3s \
  --extend xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --deselect xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_ip_forward \
  --deselect xccdf_org.ssgproject.content_rule_sysctl_net_bridge_bridge-nf-call-iptables \
  --deselect xccdf_org.ssgproject.content_rule_kernel_module_br_netfilter_disabled \
  --deselect xccdf_org.ssgproject.content_rule_kernel_module_overlay_disabled \
  --select xccdf_org.ssgproject.content_rule_sysctl_net_ipv6_conf_all_disable_ipv6 \
  --select xccdf_org.ssgproject.content_rule_audit_rules_immutable \
  --select xccdf_org.ssgproject.content_rule_kernel_module_dccp_disabled \
  --select xccdf_org.ssgproject.content_rule_kernel_module_sctp_disabled \
  --select xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

Verify the generated file:

```bash
oscap xccdf validate /etc/security/scap/helix-stax-k3s-tailoring.xml
# Expected: no errors
```

## 7. Running the Tailored Scan

### 7.1 Full Evaluation Command

```bash
# Create results directory
sudo mkdir -p /var/log/compliance

# Run tailored scan
sudo oscap xccdf eval \
  --profile xccdf_helixstax.com_profile_cis_server_l1_k3s \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-$(date +%F).xml \
  --report /var/log/compliance/report-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

### 7.2 Command Breakdown

| Flag | Purpose |
|------|---------|
| `--profile` | Use the tailored K3s profile (not the stock CIS L1 profile) |
| `--tailoring-file` | Path to the tailoring XML that defines exceptions and additions |
| `--results-arf` | Output machine-readable ARF XML for auditor consumption |
| `--report` | Output human-readable HTML report |

### 7.3 Interpreting Results

```bash
# Count pass/fail from ARF results
oscap xccdf generate report \
  /var/log/compliance/arf-results-$(date +%F).xml \
  > /var/log/compliance/summary-$(date +%F).html

# Quick pass/fail count
grep -c 'result="pass"' /var/log/compliance/arf-results-$(date +%F).xml
grep -c 'result="fail"' /var/log/compliance/arf-results-$(date +%F).xml
```

### 7.4 Evidence Archival

Hash and archive results for compliance evidence (SOC 2 CC7.2):

```bash
# SHA-256 hash for tamper evidence
sha256sum /var/log/compliance/arf-results-$(date +%F).xml \
  > /var/log/compliance/arf-results-$(date +%F).xml.sha256

# Upload to MinIO (immutable compliance bucket)
mc cp /var/log/compliance/arf-results-$(date +%F).xml \
  minio/compliance-evidence/openscap/$(date +%Y)/$(date +%m)/
mc cp /var/log/compliance/arf-results-$(date +%F).xml.sha256 \
  minio/compliance-evidence/openscap/$(date +%Y)/$(date +%m)/
```

## 8. Scanning Cadence

| Frequency | Scan Type | Output |
|-----------|-----------|--------|
| Weekly | Full OpenSCAP CIS L1 (tailored) | ARF XML + HTML report |
| Daily | Lynis hardening index | Score pushed to Prometheus |
| On-change | Ansible `--check --diff` | Drift alerts to Rocket.Chat |

## 9. Validation After System Updates

After `dnf update` or kernel updates, re-verify K3s-required parameters are still active:

```bash
# Verify K3s kernel params survived update
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

sysctl net.bridge.bridge-nf-call-iptables
# Expected: net.bridge.bridge-nf-call-iptables = 1

lsmod | grep -E "br_netfilter|overlay"
# Expected: both modules listed

# Re-run tailored scan to confirm compliance
sudo oscap xccdf eval \
  --profile xccdf_helixstax.com_profile_cis_server_l1_k3s \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-post-update-$(date +%F).xml \
  --report /var/log/compliance/report-post-update-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```
