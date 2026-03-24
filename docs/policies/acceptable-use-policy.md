---
title: "Acceptable Use Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-007"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC1.4", "CC1.5", "CC6.2"]
  - framework: "ISO 27001"
    controls: ["A.5.10", "A.8.1", "A.8.2"]
  - framework: "NIST CSF"
    controls: ["PR.AT-1", "PR.IP-11"]
---

# Acceptable Use Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Acceptable Use Policy defines rules for acceptable and prohibited use of Helix Stax systems, monitoring notice, personal use limitations, and consequences of violations. Required by SOC 2 CC1.4, ISO 27001 A.5.10. Approved by CEO.

---

## 1. Purpose

This policy defines the acceptable and prohibited uses of Helix Stax information systems, networks, and data. It protects the organization and its clients from harm caused by misuse, establishes monitoring expectations, and ensures all personnel understand their responsibilities when using company resources.

## 2. Scope

This policy applies to:

- All Helix Stax employees, contractors, and vendors
- All company-managed systems, including K3s cluster infrastructure, cloud accounts (Hetzner, Cloudflare, Backblaze), SaaS tools (GitHub, ClickUp, Google Workspace), and self-hosted applications
- All devices used to access Helix Stax systems, including personal devices used for work purposes
- All network access through Cloudflare Zero Trust tunnels

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Company Systems** | All hardware, software, networks, cloud services, and data owned or managed by Helix Stax |
| **Authorized User** | Any individual granted access to Helix Stax systems through the provisioning process defined in the Access Control Policy (POL-002) |
| **Monitoring** | The observation and recording of system activity including network traffic, authentication events, command execution, and application usage |

## 4. Policy Statements

### 4.1 Acceptable Use

**PS-007.1**: Company systems shall be used primarily for authorized business purposes related to the user's assigned duties and responsibilities.

**PS-007.2**: Limited personal use of company internet access is permitted provided it: (1) does not interfere with job performance, (2) does not consume excessive bandwidth, (3) does not violate any other provision of this policy, and (4) does not expose company systems to risk.

**PS-007.3**: All users shall lock or log out of their workstations when leaving them unattended. SSH sessions to production nodes shall use a maximum idle timeout of 15 minutes (`ClientAliveInterval 300`, `ClientAliveCountMax 3` in sshd_config).

**PS-007.4**: Users shall not attempt to access systems, data, or network segments for which they have not been explicitly authorized, even if technical controls fail to prevent such access.

### 4.2 Prohibited Activities

**PS-007.5**: The following activities are strictly prohibited on all Helix Stax systems:

1. **Unauthorized access**: Attempting to access accounts, files, or systems without explicit authorization
2. **Credential abuse**: Sharing credentials, using another person's credentials, or storing credentials outside of OpenBao
3. **Malicious software**: Introducing viruses, malware, ransomware, or any unauthorized software onto company systems
4. **Circumventing controls**: Disabling, bypassing, or tampering with security controls, monitoring tools, or audit logging
5. **Data exfiltration**: Copying, transmitting, or removing Confidential or Restricted data without authorization
6. **Unauthorized scanning**: Running port scans, vulnerability scanners, or penetration testing tools against company or client systems without written CEO approval
7. **Crypto mining**: Using company compute resources for cryptocurrency mining or any non-business computational task
8. **Illegal activity**: Using company systems for any activity that violates applicable law
9. **Harassment**: Using company communication tools (Rocket.Chat, email) for harassment, discrimination, or threats
10. **Unauthorized modifications**: Modifying production systems outside the Change Management Policy (POL-003)

### 4.3 Monitoring Notice

**PS-007.6**: All activity on Helix Stax systems is subject to monitoring and logging. By accessing company systems, users consent to monitoring. Monitored activities include but are not limited to:

- Authentication events (success and failure) via Zitadel audit logs
- SSH session commands via auditd
- Kubernetes API calls via K3s audit logging
- Network traffic via CrowdSec and Cloudflare
- File system changes via AIDE
- Application access logs aggregated in Loki

**PS-007.7**: Monitoring data shall be used solely for security operations, incident investigation, compliance verification, and performance management. Access to monitoring data is restricted to the Security Lead and CEO.

**PS-007.8**: Users shall have no expectation of privacy when using company systems. This includes Rocket.Chat messages, email sent through company domains, and files stored on company infrastructure.

### 4.4 Bring Your Own Device (BYOD)

**PS-007.9**: Personal devices used to access Helix Stax systems shall: (1) be enrolled in Cloudflare Zero Trust with WARP client installed, (2) have full-disk encryption enabled, (3) have a screen lock with maximum 5-minute timeout, (4) run a supported and patched operating system.

**PS-007.10**: Upon termination or end of contract, Helix Stax reserves the right to remotely wipe company data from personal devices that accessed company systems.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Approves policy; grants exceptions for prohibited activities (e.g., authorized penetration testing); reviews monitoring reports |
| **Security Lead** | Monitors system usage; investigates suspicious activity; manages monitoring tools; reports violations |
| **System Administrator** | Implements technical controls for monitoring; configures session timeouts and access restrictions |
| **All Personnel** | Comply with acceptable use requirements; report violations by others; acknowledge this policy upon onboarding |

## 6. Compliance & Enforcement

| Violation Type | First Occurrence | Second Occurrence | Third Occurrence |
|---------------|-----------------|------------------|------------------|
| Minor (e.g., unlocked workstation, excessive personal use) | Verbal warning | Written warning | Access suspension |
| Serious (e.g., unauthorized scanning, credential sharing) | Written warning; access suspended pending investigation | Termination | -- |
| Critical (e.g., data exfiltration, malware introduction, circumventing controls) | Immediate access revocation; investigation; potential termination and legal action | -- | -- |

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. Specific exceptions for prohibited activities (such as authorized penetration testing) require written CEO approval documenting: scope, timeframe, authorized personnel, and tools permitted.

## 8. Related Documents

- Information Security Policy (POL-001)
- Access Control Policy (POL-002)
- Data Classification Policy (POL-005)
- Incident Response Policy (POL-004)

## 9. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial policy creation |

## 10. Approval

| Role | Name | Date |
|------|------|------|
| **Policy Owner** | Wakeem Williams, CEO | 2026-03-23 |
| **Approved By** | Wakeem Williams, CEO | 2026-03-23 |

---

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation) |
| **Policy ID** | POL-007 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
