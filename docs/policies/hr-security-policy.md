---
title: "HR Security Policy"
policy_id: POL-013
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
    controls: ["A.6.1", "A.6.2", "A.6.5"]
  - framework: SOC 2
    controls: ["CC1.4"]
  - framework: HIPAA
    controls: ["164.308(a)(3)", "164.308(a)(5)"]
---

# HR Security Policy

## TLDR

Defines security requirements for the entire employment lifecycle -- from recruitment through termination -- to minimize insider threat, unauthorized access, and data breach risk. Required by ISO 27001 A.6, SOC 2 CC1.4, and HIPAA. Approved by CEO.

---

## Purpose

This policy defines the security requirements for human resources throughout the employment lifecycle to ensure that employees and contractors understand their responsibilities and that the risk of insider threat, unauthorized access, or data breach is minimized.

## Scope

- All Helix Stax personnel: full-time employees, part-time employees, contractors, and interns
- All personnel with access to client infrastructure and Sensitive Personal Information (SPI/PHI)
- All stages: pre-employment, onboarding, active employment, and termination

---

## Policy Statements

### 1. Pre-Employment Screening (ISO 27001 A.6.1 / SOC 2 CC1.4)

**Background Checks:** Before any offer is finalized, Helix Stax shall perform background verification proportional to the role and risk level:

- Identity verification (government-issued ID)
- Criminal background check (state and federal)
- Verification of educational and professional credentials

**HIPAA Specifics:** For roles accessing PHI, additional screening for debarment or exclusion from federal healthcare programs (OIG/SAM) shall be performed.

### 2. Terms and Conditions of Employment (ISO 27001 A.6.2)

- **Contractual Obligations:** All employment and contractor agreements must explicitly state security responsibilities.
- **Confidentiality:** All personnel must sign the Helix Stax Confidentiality and Non-Disclosure Agreement (NDA) before gaining access to any internal or client systems.
- **Acceptable Use:** Personnel must sign the Acceptable Use Policy (AUP) acknowledging their commitment to protect Helix Stax and client assets.

### 3. Security Awareness and Training (SOC 2 CC1.4 / HIPAA 164.308(a)(5))

- **Initial Training:** Within 5 business days of hire, all personnel must complete initial security awareness training covering social engineering, secure password management, HIPAA Privacy and Security Rules, and incident reporting procedures.
- **Ongoing Training:** Security training shall be repeated at least annually. Failure to complete training is a disciplinary offense.

### 4. Disciplinary Process (HIPAA 164.308(a)(1)(ii)(C))

- **Zero Tolerance:** Helix Stax maintains zero tolerance for intentional security breaches or unauthorized access to PHI/Client Data.
- **Levels of Action:** Sanctions range from verbal warnings and retraining to immediate termination and legal action, depending on severity and intent.

### 5. Termination and Change of Employment (ISO 27001 A.6.5)

- **Revocation of Access:** Upon termination (voluntary or involuntary), all logical access to Helix Stax and client systems must be revoked immediately.
- **Asset Return:** Personnel must return all physical assets (laptops, keys, badges) on or before their last day.
- **Exit Interview:** A formal exit interview will remind the individual of ongoing non-disclosure obligations.
- **Documentation:** A termination checklist must be completed and filed for every departure to ensure SOC 2/ISO audit compliance.

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve hiring decisions, oversee security vetting, enforce policy |
| **HR Lead** | Conduct background checks, manage onboarding/offboarding checklists |
| **DevOps Lead** | Provision and revoke system access, maintain access logs |
| **All Personnel** | Comply with security obligations, complete required training |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| ISO 27001 | A.6.1 | Screening |
| ISO 27001 | A.6.2 | Terms and Conditions of Employment |
| ISO 27001 | A.6.5 | Responsibilities After Termination or Change |
| SOC 2 | CC1.4 | Board of Directors and Management Personnel |
| HIPAA | 164.308(a)(3) | Workforce Security |
| HIPAA | 164.308(a)(5) | Security Awareness and Training |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
