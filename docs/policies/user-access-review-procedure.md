---
title: "User Access Review Procedure"
policy_id: POL-021
category: procedure
classification: INTERNAL
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: SOC 2
    controls: ["CC6.2", "CC6.3"]
  - framework: ISO 27001
    controls: ["A.5.18", "A.9.2.5"]
  - framework: HIPAA
    controls: ["164.312(a)(1)"]
---

# User Access Review Procedure

## TLDR

Defines the requirements and process for conducting periodic reviews of user access rights to Helix Stax systems. Covers automated evidence collection (Airflow), review workflow, remediation timelines, and sample templates. Required by SOC 2, ISO 27001, and HIPAA. Approved by CEO.

---

## Purpose

This procedure defines the requirements and process for conducting periodic reviews of user access rights to Helix Stax information systems and data. The goal is to ensure that access remains limited to authorized individuals based on the principle of least privilege and "need-to-know."

## Scope

**Systems in Scope:**

- **Identity Provider:** Zitadel (OIDC)
- **Infrastructure:** K3s RBAC, Hetzner Cloud Console, SSH Keys
- **Secrets/Security:** OpenBao (Transit/KV), Cloudflare Access (Zero Trust)
- **Development:** GitHub (Organizations/Repos)
- **Operations:** ClickUp (Workspaces), n8n

---

## Procedure Steps

### 1. Frequency

Reviews shall be conducted on a **quarterly** basis (Jan, Apr, Jul, Oct). High-privilege accounts (Cluster Admin, Global Admin) may be subject to more frequent monthly spot checks.

### 2. Evidence Collection (Automated)

Helix Stax utilizes automation to collect user access data:

1. Fetch user lists and roles via API from Zitadel, GitHub, ClickUp, and Cloudflare
2. Query K3s `RoleBinding` and `ClusterRoleBinding` objects
3. Consolidate data into a timestamped JSON/CSV report
4. Upload report to the `compliance-evidence` bucket in MinIO
5. Trigger n8n webhook to create a "Quarterly Access Review" task in ClickUp assigned to the Compliance Officer

### 3. Review and Validation

The Reviewer examines the consolidated report. For each user/access entry, the Reviewer marks:

- **KEEP:** Access is correct and necessary
- **MODIFY:** Access level needs adjustment (e.g., downgrade from Admin to Member)
- **REMOVE:** Access is no longer required

The Reviewer must sign off on the completed review template.

### 4. Remediation and Escalation

- **Remediation:** Any "REMOVE" or "MODIFY" actions must be completed by DevOps within **5 business days**
- **Escalation:** If a system owner or manager fails to complete the review within 10 business days, the issue is escalated to the CTO

### 5. Access Review Template

| System | User ID | Current Role | Business Purpose | Status | Reviewer | Review Date |
|--------|---------|-------------|-----------------|--------|----------|-------------|
| Zitadel | wakeem@helixstax.com | Org Owner | Primary Admin | KEEP | W. Williams | YYYY-MM-DD |
| K3s | service-acc | cluster-admin | CI/CD Runner | REMOVE | W. Williams | YYYY-MM-DD |
| GitHub | contractor-01 | read-only | Project X | MODIFY | W. Williams | YYYY-MM-DD |
| OpenBao | dev-team-group | kv-read | Application Secrets | KEEP | W. Williams | YYYY-MM-DD |

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **Compliance Officer** | Initiate review cycles, track completion |
| **System Owners** | Provide current user/access lists |
| **Managers/Team Leads** | Review access for direct reports, confirm business necessity |
| **DevOps Lead** | Remediate access changes (removal or modification) within 5 business days |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| SOC 2 | CC6.2 | User Access Authorization |
| SOC 2 | CC6.3 | User Access Modification/Removal |
| ISO 27001 | A.5.18 | Access Rights |
| ISO 27001 | A.9.2.5 | Review of User Access Rights |
| HIPAA | 164.312(a)(1) | Access Control |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
