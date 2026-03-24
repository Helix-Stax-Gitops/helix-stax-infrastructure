---
title: "Data Classification Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-005"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC6.1", "CC6.5", "CC6.7"]
  - framework: "ISO 27001"
    controls: ["A.5.12", "A.5.13", "A.8.10", "A.8.11", "A.8.12"]
  - framework: "HIPAA"
    controls: ["164.312(a)(2)(iv)", "164.312(e)(1)", "164.312(e)(2)(ii)"]
  - framework: "NIST CSF"
    controls: ["PR.DS-1", "PR.DS-2", "PR.DS-5"]
---

# Data Classification Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Data Classification Policy defines four classification levels (Public, Internal, Confidential, Restricted) and specifies handling, storage, transmission, and destruction requirements for each. No PHI shall be stored in ClickUp or any non-encrypted SaaS tool. Required by SOC 2 CC6.7, ISO 27001 A.5.12, HIPAA 164.312(a)(2)(iv). Approved by CEO.

---

## 1. Purpose

This policy establishes a data classification framework to ensure that information assets receive protection appropriate to their sensitivity. It enables personnel to identify data sensitivity, apply the correct handling procedures, and meet regulatory obligations for data protection.

## 2. Scope

This policy applies to all data created, received, processed, stored, or transmitted by Helix Stax systems, including data belonging to clients managed under the Delivery workspace.

## 3. Definitions

| Term | Definition |
|------|-----------|
| **PHI** | Protected Health Information as defined by HIPAA; individually identifiable health information |
| **PII** | Personally Identifiable Information; data that can identify a specific individual |
| **Data Owner** | The individual accountable for the classification and protection of a specific data set |
| **Data Custodian** | The individual or system responsible for implementing the technical controls that protect data |
| **Encryption at Rest** | Protecting stored data using cryptographic algorithms so it cannot be read without the decryption key |
| **Encryption in Transit** | Protecting data during transmission using TLS or equivalent cryptographic protocols |

## 4. Policy Statements

### 4.1 Classification Levels

**PS-005.1**: All data shall be classified into one of the following four levels:

| Level | Description | Examples |
|-------|------------|---------|
| **Public** | Information intended for unrestricted distribution | Marketing materials, published blog posts, helixstax.com website content, brand kit assets |
| **Internal** | Information for internal use that poses minimal risk if disclosed | Internal procedures, meeting notes, project plans, architecture diagrams, ClickUp task descriptions |
| **Confidential** | Sensitive business information whose disclosure could cause harm | Client contracts, financial records, proprietary CTGA scoring algorithms, vendor agreements, employee records |
| **Restricted** | Highly sensitive data subject to regulatory requirements or whose disclosure would cause severe harm | PHI, PII, credentials, encryption keys, audit evidence, client vulnerability assessments |

### 4.2 Handling Requirements

**PS-005.2**: Data shall be handled according to the following requirements per classification level:

| Requirement | Public | Internal | Confidential | Restricted |
|-------------|--------|----------|-------------|------------|
| **Encryption at Rest** | Not required | Not required | Required (AES-256) | Required (AES-256 via LUKS or OpenBao) |
| **Encryption in Transit** | TLS 1.2+ | TLS 1.2+ | TLS 1.3 required | TLS 1.3 required; mTLS where supported |
| **Access Control** | None | Authenticated users | Role-based; need-to-know | Named individuals; explicit authorization |
| **Storage Location** | Any | Company-managed systems | Encrypted volumes on Helix Stax infrastructure | Encrypted volumes with OpenBao-managed keys |
| **Sharing** | Unrestricted | Internal channels only | Encrypted channels; NDA required for external | Prohibited unless encrypted and CEO-approved |
| **Retention** | Per business need | 1 year minimum | 3 years minimum | 7 years (HIPAA); per regulation otherwise |
| **Destruction** | No special requirements | Standard deletion | Secure deletion; documented | Cryptographic erasure; documented; witnessed |

### 4.3 Specific Data Handling Rules

**PS-005.3**: Protected Health Information (PHI) shall NOT be stored in ClickUp, Rocket.Chat, Google Workspace, or any SaaS platform that is not covered by a Business Associate Agreement (BAA) and does not provide encryption at rest with customer-managed keys.

**PS-005.4**: PHI shall be stored exclusively in CloudNativePG databases with TDE enabled on LUKS-backed PersistentVolumes, with encryption keys managed by OpenBao.

**PS-005.5**: Credentials, API keys, private keys, and certificates shall be classified as Restricted and stored exclusively in OpenBao. Hardcoding secrets in source code, configuration files, environment variables baked into container images, or ClickUp task fields is prohibited.

**PS-005.6**: Backup archives containing Confidential or Restricted data shall be encrypted using AES-256 before transfer to offsite storage (Backblaze B2). Encryption keys for backups shall be managed in OpenBao and shall not be stored alongside the backup media.

**PS-005.7**: Audit evidence and compliance scan results (OpenSCAP ARF reports, Lynis outputs) shall be classified as Confidential, SHA-256 hashed for integrity verification, and archived to MinIO with S3 Object Lock (Compliance Mode).

### 4.4 Data Labeling

**PS-005.8**: All policy documents, architecture documents, and formal deliverables shall include a classification label in the document header. The absence of a label implies Internal classification by default.

**PS-005.9**: Kubernetes Secrets shall be labeled with `data-classification: restricted` and managed exclusively through External Secrets Operator syncing from OpenBao.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Assigns data ownership; approves Restricted data sharing; reviews classification disputes |
| **Data Owner** | Classifies data; approves access requests for their data; reviews classification annually |
| **Data Custodian / System Administrator** | Implements technical controls per classification; configures encryption; manages access controls |
| **Compliance Lead** | Verifies handling requirements are met during audits; maintains data inventory |
| **All Personnel** | Classify data they create; handle data according to its classification; report misclassification |

## 6. Compliance & Enforcement

Mishandling of Confidential or Restricted data constitutes a serious policy violation. Storing PHI in unauthorized locations or transmitting Restricted data over unencrypted channels constitutes a critical policy violation and may trigger HIPAA breach notification obligations.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. Data classification exceptions additionally require:

- A risk assessment specific to the data in question
- Compensating controls documented and verified
- CEO approval for any exception involving Restricted data
- No exceptions are permitted for PHI handling requirements

## 8. Related Documents

- Information Security Policy (POL-001)
- Access Control Policy (POL-002)
- Backup & Recovery Policy (POL-006)
- Vendor Management Policy (POL-008)
- HIPAA Security Rule (45 CFR Part 164, Subpart C)

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
| **Policy ID** | POL-005 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
