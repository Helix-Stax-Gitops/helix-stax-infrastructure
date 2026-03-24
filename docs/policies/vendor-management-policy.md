---
title: "Vendor Management Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-008"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC9.2", "CC2.3", "CC3.4"]
  - framework: "ISO 27001"
    controls: ["A.5.19", "A.5.20", "A.5.21", "A.5.22", "A.5.23"]
  - framework: "HIPAA"
    controls: ["164.308(b)(1)", "164.308(b)(3)", "164.314(a)"]
  - framework: "NIST CSF"
    controls: ["GV.SC-3", "GV.SC-4", "GV.SC-5"]
---

# Vendor Management Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Vendor Management Policy governs third-party risk assessment, ongoing monitoring, and Business Associate Agreement (BAA) requirements for HIPAA-covered vendors. Covers all cloud providers (Hetzner, Cloudflare, Backblaze) and SaaS tools. Required by SOC 2 CC9.2, ISO 27001 A.5.19, HIPAA 164.308(b). Approved by CEO.

---

## 1. Purpose

This policy establishes the requirements for assessing, onboarding, monitoring, and offboarding third-party vendors that process, store, transmit, or have access to Helix Stax data or systems. It ensures that vendor relationships do not introduce unacceptable risk to the organization or its clients.

## 2. Scope

This policy applies to all third-party vendors, service providers, and subprocessors that:

- Provide infrastructure, platform, or software services to Helix Stax
- Have access to Helix Stax systems or data
- Process, store, or transmit data on behalf of Helix Stax or its clients
- Provide services that, if disrupted, would impact Helix Stax operations

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Vendor** | Any third-party organization providing goods or services to Helix Stax |
| **BAA** | Business Associate Agreement; a HIPAA-required contract between a covered entity and a business associate that handles PHI |
| **Vendor Risk Tier** | A classification of vendor criticality based on data access, service dependency, and regulatory implications |
| **Shared Responsibility Model** | The division of security responsibilities between a cloud provider and the customer |

## 4. Policy Statements

### 4.1 Vendor Risk Tiering

**PS-008.1**: All vendors shall be classified into risk tiers upon onboarding:

| Tier | Criteria | Examples | Assessment Requirements |
|------|----------|----------|------------------------|
| **Critical** | Hosts or processes Confidential/Restricted data; service outage causes production downtime | Hetzner (IaaS), Cloudflare (edge/security), GitHub (source code) | Full security assessment; SOC 2/ISO cert review; annual reassessment |
| **High** | Accesses Internal data; provides important but non-critical services | Backblaze (offsite backups), Google Workspace (business email), ClickUp (project management) | Security questionnaire; certification review; annual reassessment |
| **Medium** | Limited data access; provides supplementary services | Domain registrars, analytics tools, design tools | Security questionnaire; biennial reassessment |
| **Low** | No data access; provides commodity services | Office supplies, general consulting | Basic due diligence; no recurring assessment |

### 4.2 Pre-Engagement Assessment

**PS-008.2**: Before onboarding a Critical or High tier vendor, the following assessments shall be completed:

1. **Security certification review**: Verify current SOC 2 Type II report, ISO 27001 certificate, or equivalent independent audit
2. **Security questionnaire**: Vendor completes the Helix Stax Vendor Security Questionnaire covering: data handling practices, encryption capabilities, access controls, incident response procedures, and subprocessor management
3. **Data flow mapping**: Document what data the vendor will access, where it will be stored, and how it will be transmitted
4. **Contractual review**: Verify the contract includes: data protection obligations, breach notification requirements (within 72 hours), right to audit, data return/destruction upon termination

**PS-008.3**: Vendors that cannot provide a current SOC 2 Type II report or equivalent shall not be used for Critical tier services without CEO-approved exception with documented compensating controls.

### 4.3 Business Associate Agreements (HIPAA)

**PS-008.4**: A signed Business Associate Agreement (BAA) is required before any vendor processes, stores, or transmits Protected Health Information (PHI) on behalf of Helix Stax or its clients.

**PS-008.5**: BAAs shall include, at minimum: (1) permissible uses and disclosures of PHI, (2) vendor obligation to safeguard PHI, (3) breach notification within 24 hours, (4) return or destruction of PHI upon termination, (5) right to audit, (6) vendor obligation to ensure subcontractor compliance.

**PS-008.6**: The following vendors require a BAA if Helix Stax processes PHI:

| Vendor | Service | BAA Status |
|--------|---------|------------|
| Hetzner | IaaS hosting | Required |
| Backblaze | Offsite backup storage | Required |
| Cloudflare | Edge proxy and WAF | Required if PHI traverses |

### 4.4 Current Vendor Inventory and Shared Responsibility

**PS-008.7**: The following delineates security responsibilities for core infrastructure providers:

| Vendor | Helix Stax Responsibility | Vendor Responsibility |
|--------|---------------------------|----------------------|
| **Hetzner** | OS hardening, K3s security, data encryption, access control, patching | Physical security, network infrastructure, hardware maintenance, power/cooling |
| **Cloudflare** | WAF rule configuration, Zero Trust policy, DNS record management | DDoS mitigation, CDN infrastructure, TLS termination, edge security |
| **Backblaze** | Encryption of data before upload, access key management, retention configuration | Storage infrastructure, durability, availability |
| **GitHub** | Repository access controls, branch protection, secret scanning configuration | Platform availability, infrastructure security, code scanning tools |

### 4.5 Ongoing Monitoring

**PS-008.8**: Critical tier vendors shall be reassessed annually. Reassessment includes: reviewing updated SOC 2 reports, verifying continued certification, reviewing any disclosed breaches or incidents, and validating that the shared responsibility model is correctly implemented.

**PS-008.9**: Vendor security advisories and breach disclosures shall be monitored. Upon notification of a vendor security incident, the Security Lead shall assess impact to Helix Stax within 24 hours and initiate the Incident Response Policy (POL-004) if Helix Stax data is affected.

**PS-008.10**: Vendor contracts shall include a right-to-terminate clause exercisable within 30 days if the vendor fails to meet security obligations or suffers a material breach affecting Helix Stax data.

### 4.6 Vendor Offboarding

**PS-008.11**: Upon termination of a vendor relationship, the following shall be completed within 30 days: (1) revoke all vendor access to Helix Stax systems, (2) confirm return or certified destruction of Helix Stax data, (3) rotate any credentials the vendor had access to, (4) update the vendor inventory.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Approves Critical tier vendor engagements; signs BAAs; authorizes vendor exceptions |
| **Security Lead** | Conducts vendor security assessments; reviews SOC 2 reports; monitors vendor advisories |
| **Compliance Lead** | Maintains vendor inventory in ClickUp (Folder 05); tracks BAA status; manages assessment schedule |
| **System Administrator** | Implements vendor access controls; manages API keys and integrations; executes vendor offboarding |

## 6. Compliance & Enforcement

Engaging a vendor without completing the required risk assessment constitutes a serious policy violation. Processing PHI through a vendor without a signed BAA constitutes a critical policy violation and a HIPAA violation.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. No exceptions are permitted for BAA requirements when PHI is involved.

## 8. Related Documents

- Information Security Policy (POL-001)
- Data Classification Policy (POL-005)
- Risk Assessment Policy (POL-009)
- Incident Response Policy (POL-004)
- Vendor Security Questionnaire template (Process Library, ClickUp Folder 06)

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
| **Policy ID** | POL-008 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
