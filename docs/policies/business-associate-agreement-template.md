---
title: "Business Associate Agreement (BAA) Template"
policy_id: POL-011
category: policy
classification: CONFIDENTIAL
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: HIPAA
    controls: ["164.308(b)(1)", "164.314(a)", "164.502(e)"]
  - framework: SOC 2
    controls: ["CC2.3", "CC9.2"]
  - framework: ISO 27001
    controls: ["A.5.19", "A.5.20", "A.5.21"]
---

# Business Associate Agreement (BAA) Template

## TLDR

BAA template governing HIPAA-compliant relationships between Helix Stax (Business Associate) and Covered Entity clients. Required by HIPAA Privacy and Security Rules. Includes vendor-specific addenda for Hetzner, Cloudflare, and Backblaze B2. Approved by CEO.

---

## Purpose

This template defines the contractual obligations between Helix Stax and healthcare Covered Entities to ensure HIPAA-compliant handling of Protected Health Information (PHI). As an IT consulting firm providing infrastructure management and DevOps services, Helix Stax may access, maintain, or transmit PHI on behalf of clients.

## Scope

- All client engagements involving PHI or ePHI
- All Helix Stax personnel and subcontractors with PHI access
- All infrastructure components processing PHI (K3s, databases, backups)

---

## Agreement Terms

### 1. Background and Purpose

Business Associate provides IT consulting, infrastructure management, and DevOps services to Covered Entity. In the course of providing these services, Business Associate may have access to, or maintain, Protected Health Information ("PHI") as defined by HIPAA (45 CFR Parts 160 and 164). This Agreement ensures both parties comply with the HIPAA Security and Privacy Rules.

### 2. Definitions

- **Protected Health Information (PHI):** As defined in 45 CFR 160.103, limited to information created, received, maintained, or transmitted by Business Associate from or on behalf of Covered Entity.
- **Security Incident:** The attempted or successful unauthorized access, use, disclosure, modification, or destruction of information or interference with system operations.
- **Breach:** The acquisition, access, use, or disclosure of PHI in a manner not permitted under Subpart E of 45 CFR Part 164 which compromises the security or privacy of the PHI.

### 3. Obligations of Business Associate

- **Permitted Uses:** Business Associate shall not use or disclose PHI other than as permitted or required by this Agreement or as required by law.
- **Safeguards:** Business Associate shall implement administrative, physical, and technical safeguards that reasonably and appropriately protect the confidentiality, integrity, and availability of ePHI. These safeguards align with SOC 2 Type II and ISO 27001:2022 internal controls.
- **Mitigation:** Business Associate agrees to mitigate, to the extent practicable, any harmful effect of a use or disclosure of PHI in violation of this Agreement.
- **Breach Reporting:** Business Associate shall report to Covered Entity any Breach of Unsecured PHI or any Security Incident within **72 hours** of discovery.
- **Subcontractors:** Business Associate shall ensure that any subcontractors that create, receive, maintain, or transmit PHI agree to the same restrictions and conditions.
- **Access and Amendment:** Business Associate shall provide access to PHI in a Designated Record Set per 45 CFR 164.524.

### 4. Obligations of Covered Entity

- Covered Entity shall notify Business Associate of any limitations in its notice of privacy practices.
- Covered Entity shall not request Business Associate to use or disclose PHI in any manner that would not be permissible under the Privacy Rule.

### 5. Term and Termination

- **Term:** This Agreement terminates when all PHI provided by Covered Entity to Business Associate is destroyed or returned.
- **Termination for Cause:** Upon knowledge of a material breach, Covered Entity shall provide 30 days to cure. If not cured, Covered Entity may terminate.
- **Return or Destruction of PHI:** Upon termination, Business Associate shall return or destroy all PHI. If infeasible, protections extend indefinitely.

### 6. Vendor-Specific Infrastructure Addendum

- **Backblaze B2 (Backup Storage):** BAA in place between Helix Stax and Backblaze. PHI is encrypted client-side using AES-256 (FIPS 140-3 compliant) before transmission.
- **Cloudflare (CDN/WAF):** BAA in place between Helix Stax and Cloudflare Enterprise. Configured with "Full (Strict)" SSL/TLS and Data Localization for US processing.
- **Hetzner Cloud (Compute/Hosting):** **[IMPORTANT DISCLOSURE]** Hetzner does not sign HIPAA BAAs. Helix Stax implements strict technical safeguards (LUKS disk encryption, encrypted overlay networking, zero-trust access). Covered Entity acknowledges the physical infrastructure provider is not a Business Associate under HIPAA and accepts the risk, provided SOC 2 compliant logical separation and encryption of all PHI is maintained.

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Execute BAAs, oversee compliance, manage vendor BAA status |
| **DevOps Lead** | Implement technical safeguards, maintain encryption controls |
| **Compliance Lead** | Track BAA inventory, coordinate audit evidence |
| **All Personnel** | Handle PHI per BAA terms, report incidents within 1 hour |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| HIPAA | 164.308(b)(1) | Business Associate Contracts |
| HIPAA | 164.314(a) | Business Associate Requirements |
| HIPAA | 164.502(e) | Disclosures to Business Associates |
| SOC 2 | CC2.3 | Communication with External Parties |
| SOC 2 | CC9.2 | Risk Mitigation (Vendors) |
| ISO 27001 | A.5.19 | Information Security in Supplier Relationships |
| ISO 27001 | A.5.20 | Addressing Security Within Supplier Agreements |
| ISO 27001 | A.5.21 | Managing Security in the ICT Supply Chain |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
