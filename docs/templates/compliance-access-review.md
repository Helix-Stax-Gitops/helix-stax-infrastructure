---
template: compliance-access-review
category: compliance
task_type: access-review
clickup_list: "05 Compliance Program"
auto_tags: ["access-review", "compliance", "security"]
required_fields: ["TLDR", "Review Metadata", "User Access Review", "Access Changes Summary", "Compliance Mapping", "Attestation"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "PCI DSS"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Periodic Access Review

Use for documented periodic reviews of user access rights to systems and data. Store in `docs/compliance/access-reviews/access-review-{YYYY-MM-DD}.md`.

---

## TLDR

<!-- One sentence: review date, systems covered, access changes made, approval. -->

Example: Quarterly access review as of 2026-03-22. Reviewed K3s RBAC, PostgreSQL roles, Zitadel users. Removed 3 inactive accounts, revoked 5 excessive permissions. Approved by Security Lead.

---

## Review Metadata

### [REQUIRED] Review Information

| Field | Value |
|-------|-------|
| **Review Type** | Quarterly / Biannual / Annual |
| **Review Date** | YYYY-MM-DD |
| **Reviewed Systems** | K3s / PostgreSQL / Zitadel / Rocket.Chat / Harbor / MinIO / All |
| **Review Period** | From YYYY-MM-DD to YYYY-MM-DD (since last review) |
| **Reviewed By** | |
| **Approved By** | |

### [REQUIRED] Review Scope

**Systems included in this review**:

- [ ] Kubernetes cluster (K3s) - RBAC and service accounts
- [ ] PostgreSQL databases - user roles and permissions
- [ ] Zitadel identity provider - organizational structure and app clients
- [ ] Rocket.Chat - channels, groups, and member roles
- [ ] Harbor container registry - repository access
- [ ] MinIO object storage - access keys and bucket policies
- [ ] Hetzner Cloud console - project access and role assignments
- [ ] GitHub repository access - collaborator permissions
- [ ] AWS/Cloud console access (if applicable): ___________

---

## User Access Review

### [REQUIRED] Active Users Summary

| System | Total Users | Active Users | Inactive Users (>60 days) | Access Reviewed? |
|--------|-------------|--------------|--------------------------|------------------|
| | | | | ✓ / ✗ |
| | | | | ✓ / ✗ |

### [REQUIRED] User Access Matrix

**For each active user, document their access:**

#### User 1: [Name]

| Access Right | System | Assigned Date | Business Justification | Still Required? | Approver |
|--------------|--------|---------------|------------------------|----------------|---------|
| [Role/Permission] | [System] | | | ✓ / ✗ | |
| | | | | | |

**Action**: [ ] Approved as-is [ ] Access reduced [ ] Access revoked [ ] Training needed

---

#### User 2: [Name]

| Access Right | System | Assigned Date | Business Justification | Still Required? | Approver |
|--------------|--------|---------------|------------------------|----------------|---------|
| | | | | | |

**Action**: [ ] Approved as-is [ ] Access reduced [ ] Access revoked [ ] Training needed

---

### [REQUIRED] Privileged Access Review

**Users with elevated/admin access (require explicit approval):**

| User | System | Privilege Level | Assigned By | Assigned Date | Business Justification | Approval |
|------|--------|-----------------|------------|--------------|------------------------|----------|
| | | Admin / Superuser | | | | ✓ / ✗ |
| | | | | | | |

**NOTE**: Privileged access requires documented business justification and explicit quarterly re-approval.

---

## Service Accounts & Automation

### [REQUIRED] Service Account Review

**Non-human accounts (service accounts, bots, automation):**

| Account Name | Purpose | System | Permissions | Last Used | Status |
|--------------|---------|--------|-------------|-----------|--------|
| | | | | | Active / Inactive / To Remove |
| | | | | | |

**Inactive service accounts (>90 days unused)**:
- [ ] Account 1 — Marked for removal
- [ ] Account 2 — Marked for removal

**Action**: Remove or keep?

---

## Access Changes Summary

### [REQUIRED] Changes Made During This Review

**Additions** (new access granted):

| User | Access Granted | System | Date Granted | Approver | Business Justification |
|------|----------------|--------|--------------|----------|------------------------|
| | | | | | |

**Modifications** (access scope changed):

| User | Previous Access | New Access | System | Date Changed | Reason |
|------|-----------------|-----------|--------|--------------|--------|
| | | | | | |

**Revocations** (access removed):

| User | Access Revoked | System | Date Revoked | Reason |
|------|----------------|--------|--------------|--------|
| | | | | Terminated / Role change / Risk mitigation / Unused for >60 days |
| | | | | |

**Summary**:
- Total additions: ___
- Total modifications: ___
- Total revocations: ___

---

## Compliance & Controls

### [REQUIRED] Access Control Verification

For each system, verify controls are functioning:

- [ ] **Least privilege enforced**: Users have minimum permissions needed for job function
- [ ] **Separation of duties**: No one person has conflicting roles (e.g., dev + approver)
- [ ] **Access logging enabled**: All access attempts logged and auditable
- [ ] **MFA required for sensitive systems**: Admin/privileged access requires MFA
- [ ] **Idle account cleanup**: Inactive accounts disabled/removed after 60 days
- [ ] **Regular reviews conducted**: Quarterly or more frequently for sensitive systems

### [REQUIRED] Exceptions & Deviations

**Any exceptions to access control policy** (e.g., user with excessive permissions):

| Exception | Duration | Justification | Approver | Review Date |
|-----------|----------|---------------|----------|------------|
| | | | | |

**All exceptions must be explicitly approved and reviewed at least quarterly.**

---

## Audit Trail & Evidence

### [REQUIRED] How Access Was Verified

**Evidence collected for this review:**

- [ ] Exported user lists from each system (date: _______)
- [ ] Active session logs for last 30 days
- [ ] Last login timestamps for each user
- [ ] Role/permission configuration exports
- [ ] Comparison to previous review (identify changes)
- [ ] Interviews with department heads (verify business justification)
- [ ] System audit logs reviewed for unauthorized access attempts

**Evidence storage**: `docs/compliance/evidence/access-review-{YYYY-MM-DD}/`

---

## Non-Compliance Findings

### [OPTIONAL] Findings & Remediation

**Any access control violations or non-compliance discovered:**

| Finding | Severity | System | User(s) Affected | Remediation | Owner | Target Date |
|---------|----------|--------|-----------------|-------------|-------|------------|
| | P1/P2/P3 | | | | | |

**Violations to address immediately**:
1. _________
2. _________

---

## Compliance Mapping

### [REQUIRED] Compliance Requirements Satisfied

This access review documents compliance with:

| Framework | Control ID | Requirement | Evidence |
|-----------|-----------|-------------|----------|
| SOC 2 | CC6.1 | Logical and physical access controls | User access matrix, changes log |
| SOC 2 | CC6.2 | Access management policies | Access review completion |
| ISO 27001 | A.9.2.1 | User access provision and revocation | Access log, changes made |
| ISO 27001 | A.9.4.3 | Password management | MFA verification |
| NIST CSF | PR.AC-1 | Access management policies | Access control verification |
| PCI DSS | 7.1 | Limit access to systems | Access matrix review |
| PCI DSS | 7.2 | Ensure users have appropriate access | User role verification |

---

## Attestation & Approval

### [REQUIRED] Management Sign-Off

**By signing below, I attest that:**

1. I reviewed all access within my area of responsibility
2. Access is appropriate and justified
3. All non-compliant access has been identified and remediation scheduled
4. Access control procedures are understood and being followed

| Role | Name | Date | Signature |
|------|------|------|-----------|
| **Department Manager 1** | | | |
| **Department Manager 2** | | | |
| **Security Lead** | | | |
| **Compliance Lead** | | | |

### [REQUIRED] Executive Summary for Auditor

**For SOC 2/ISO 27001 auditor reference:**

This review confirms:
- [ ] Access is provisioned in accordance with least privilege principle
- [ ] Access is reviewed periodically and non-compliant access corrected
- [ ] All users have documented business justification for their access
- [ ] Inactive users are identified and access promptly revoked
- [ ] Privileged accounts are specially controlled and reviewed quarterly

**No access violations that would prevent compliance certification**: [ ] True [ ] False

If False, explain: _______________

---

## Monitoring Until Next Review

### [REQUIRED] Continuous Monitoring

Between this review and the next scheduled review:

- [ ] Monthly access report generated (last Friday of month)
- [ ] Inactive accounts reviewed monthly and disabled/removed at 60 days
- [ ] Access change log maintained (all additions/revocations tracked)
- [ ] Any violation immediately escalated to Security Lead
- [ ] Next full review scheduled for: YYYY-MM-DD

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Review Type** | Quarterly / Annual |
| **Next Review** | YYYY-MM-DD |
| **Classification** | Confidential |
