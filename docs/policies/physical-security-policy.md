---
title: "Physical Security Policy"
policy_id: POL-020
category: policy
classification: INTERNAL
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: ISO 27001
    controls: ["A.7.1", "A.7.6"]
  - framework: SOC 2
    controls: ["CC6.4"]
  - framework: HIPAA
    controls: ["164.310(a)(1)"]
---

# Physical Security Policy

## TLDR

Establishes physical security requirements for Helix Stax as a fully remote, cloud-native firm. Covers data center security (delegated to Hetzner), remote work/home office requirements, device security, media disposal, and visitor policy. Required by ISO 27001 A.7, SOC 2 CC6.4, and HIPAA. Approved by CEO.

---

## Purpose

This policy establishes security requirements for the physical environments where Helix Stax information is processed or stored, acknowledging our model as a fully remote, cloud-native firm.

## Scope

- Third-party data centers (Hetzner Cloud)
- Remote work environments (home offices)
- Portable devices and media

---

## Policy Statements

### 1. Data Center Security (Hetzner Cloud)

Helix Stax does not maintain physical servers. Physical security is delegated to Hetzner Cloud:

- **Compliance:** Helix Stax shall review Hetzner's ISO 27001 and SOC 2 Type II reports annually
- **Controls:** Physical access to Hetzner facilities is restricted to authorized personnel via biometric and electronic access control systems
- **Geography:** All production infrastructure hosted in Hetzner data centers to ensure GDPR and security alignment

### 2. Remote Work and Home Office Security

Every employee's home office is considered a "Secure Area" for compliance purposes:

- **Visual Privacy:** Screens must not be visible to unauthorized persons (family, visitors) when handling Restricted/Confidential data
- **Physical Protection:** Laptops must be stored in a locked drawer or room when not in use for extended periods
- **Network Security:** WPA3 (or WPA2-AES) mandatory for home Wi-Fi. Default router passwords must be changed

### 3. Device Security and Workstation Use

- **Encryption:** Full Disk Encryption (FDE) mandatory for all endpoints
- **Auto-Lock:** Screens must automatically lock after 5 minutes of inactivity
- **Clear Desk/Clear Screen:** No sensitive information (passwords, PII) may be left on physical desks or sticky notes
- **Public Spaces:** Working from public Wi-Fi (cafes, airports) requires the Helix Stax Zero Trust tunnel (Cloudflare WARP)

### 4. Visitor Policy

As there is no corporate office, physical "visitors" to home offices are prohibited from accessing Helix Stax devices. Consultants visiting client sites must adhere to the client's physical security policies while maintaining Helix Stax device security protocols.

### 5. Media Disposal and Transfer

- **Cloud Media:** Storage volumes decommissioned via OpenTofu/Hetzner API. Helix Stax relies on Hetzner's secure multi-pass wipe of underlying physical disks
- **Physical Media:** USB drives or external SSDs containing Helix Stax data are discouraged. If used, they must be encrypted. Disposal must be performed by a certified secure destruction service
- **HIPAA Requirement:** A log of all media movement (e.g., shipping a laptop for repair) must be maintained, including date, sender, and recipient

### 6. Compliance Evidence

- Annual review of Hetzner SOC 2 / ISO certificates
- MDM report showing 100% encryption compliance across the fleet
- Signed "Remote Work Security Agreement" from all employees

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve physical security requirements, review vendor certificates |
| **DevOps Lead** | Manage cloud media disposal, maintain MDM compliance |
| **HR Lead** | Collect signed Remote Work Security Agreements |
| **All Personnel** | Follow home office security requirements, protect devices |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| ISO 27001 | A.7.1 | Physical Security Perimeters |
| ISO 27001 | A.7.6 | Working in Secure Areas |
| SOC 2 | CC6.4 | Physical Access Controls |
| HIPAA | 164.310(a)(1) | Facility Access Controls |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
