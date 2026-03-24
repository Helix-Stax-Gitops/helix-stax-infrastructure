---
title: "Terminated User Access Removal Procedure"
policy_id: POL-022
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
    controls: ["CC6.3"]
  - framework: ISO 27001
    controls: ["A.6.5"]
  - framework: HIPAA
    controls: ["164.308(a)(3)(ii)(C)"]
---

# Terminated User Access Removal Procedure

## TLDR

Outlines the procedure and evidence requirements for timely removal of access for terminated employees or contractors. Covers the offboarding checklist, Zitadel "Kill Switch" automation, evidence collection for auditors, and retention requirements. Required by SOC 2, ISO 27001, and HIPAA. Approved by CEO.

---

## Purpose

This procedure ensures the timely removal of access for terminated employees or contractors, preventing unauthorized access to systems following a change in employment status.

## Scope

- All terminated employees and contractors
- All Helix Stax production systems, infrastructure, and sensitive data
- All identity providers and third-party services

---

## Procedure Steps

### 1. Revocation Timeline

Access to all Helix Stax production systems must be revoked **immediately** (no later than 24 hours) upon notification of termination.

### 2. Offboarding Checklist (Systems to Revoke)

| Step | System | Action |
|------|--------|--------|
| 1 | **Zitadel (Primary)** | Deactivate/Delete user account (automatically kills OIDC sessions) |
| 2 | **K3s** | Delete Kubeconfig entries and User/Group RBAC bindings |
| 3 | **OpenBao** | Revoke user tokens and entity aliases |
| 4 | **GitHub** | Remove user from the HelixStax organization |
| 5 | **ClickUp** | Remove user from all workspaces and teams |
| 6 | **Cloudflare** | Revoke Cloudflare Access (Zero Trust) seats and assignments |
| 7 | **Hetzner** | Delete user from the Cloud Console project |
| 8 | **SSH Keys** | Remove the user's public key from authorized_keys across all nodes (automated via Ansible) |

### 3. Automation and Evidence Capture

**Zitadel "Kill Switch" Automation:**

- Disabling a user in Zitadel triggers an outbound webhook to n8n
- n8n scripts iterate through the APIs of GitHub, ClickUp, and Cloudflare to disable the user
- All API responses (Success/Fail) are logged to the `termination-logs` index in Loki

**Evidence Collection for Auditors:**

For each terminated user, capture and store the following in MinIO (`/evidence/terminations/[User_ID]/`):

- Zitadel screenshot/log showing "State: Deactivated" with timestamp
- GitHub Audit Log showing "removed [user] from organization"
- API response payloads from the n8n offboarding workflow
- Offboarding ticket: ClickUp task with completed checklist and final sign-off from IT/HR

### 4. Retention

Evidence of access removal must be retained for a minimum of **7 years** to support SOC 2 Type II audit windows and HIPAA compliance requirements.

### 5. Sample Evidence Log (Audit Ready)

**Termination Event ID:** TERM-YYYY-XXXX
**User:** former.staff@helixstax.com
**Termination Date/Time:** YYYY-MM-DD HH:MM EST

| System | Action Taken | Timestamp (UTC) | Result | Evidence Ref |
|--------|-------------|-----------------|--------|-------------|
| Zitadel | Account Deactivated | YYYY-MM-DD HH:MM | SUCCESS | zitadel-deactivate-log-XX.json |
| GitHub | Org Member Removed | YYYY-MM-DD HH:MM | SUCCESS | github-audit-XX.png |
| Cloudflare | Access Seat Revoked | YYYY-MM-DD HH:MM | SUCCESS | cf-api-resp-XX.json |
| K3s | RBAC Cleaned | YYYY-MM-DD HH:MM | SUCCESS | k3s-cleanup-log-XX.txt |

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Authorize termination, verify completion of offboarding |
| **HR Lead** | Initiate offboarding process, conduct exit interview |
| **DevOps Lead** | Execute technical access revocation, verify automation success |
| **Compliance Lead** | Collect and archive evidence, verify retention compliance |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| SOC 2 | CC6.3 | User Access Modification/Removal |
| ISO 27001 | A.6.5 | Responsibilities After Termination or Change |
| HIPAA | 164.308(a)(3)(ii)(C) | Termination Procedures |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
