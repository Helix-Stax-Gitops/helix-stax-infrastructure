---
title: "Access Control Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-002"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC6.1", "CC6.2", "CC6.3"]
  - framework: "ISO 27001"
    controls: ["A.5.15", "A.5.16", "A.5.17", "A.5.18", "A.8.2", "A.8.3"]
  - framework: "HIPAA"
    controls: ["164.312(a)(1)", "164.312(a)(2)(i)", "164.312(d)"]
  - framework: "NIST CSF"
    controls: ["PR.AC-1", "PR.AC-3", "PR.AC-4", "PR.AC-6"]
---

# Access Control Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Access Control Policy governs logical access to all Helix Stax systems including K3s, databases, cloud infrastructure, and SaaS tools. Enforces least privilege, MFA via Zitadel, SSH key-only authentication, and formal provisioning/deprovisioning processes. Required by SOC 2 CC6.1, ISO 27001 A.5.15, HIPAA 164.312(a). Approved by CEO.

---

## 1. Purpose

This policy establishes the requirements for controlling logical access to Helix Stax information systems. It ensures that access is granted based on the principle of least privilege, authenticated through strong mechanisms, and revoked promptly when no longer required.

## 2. Scope

This policy applies to all access to:

- K3s cluster nodes and the Kubernetes API
- Hetzner Cloud console and API
- Cloudflare dashboard and API
- All applications deployed on the platform (Zitadel, Devtron, ArgoCD, Grafana, Harbor, MinIO, n8n, Rocket.Chat, Outline)
- PostgreSQL databases (CloudNativePG)
- OpenBao secrets management
- GitHub repositories
- ClickUp workspace
- Any third-party SaaS tool used for business operations

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Least Privilege** | Granting only the minimum access rights necessary to perform assigned duties |
| **RBAC** | Role-Based Access Control; access permissions assigned to roles, not individual users |
| **MFA** | Multi-Factor Authentication; requiring two or more independent authentication factors |
| **Privileged Access** | Administrative or elevated access that can modify system configuration, security controls, or access other users' data |
| **Service Account** | A non-human identity used by applications or automated processes to authenticate to systems |
| **Break-Glass** | Emergency access procedure that bypasses normal controls under documented, auditable conditions |

## 4. Policy Statements

### 4.1 Authentication

**PS-002.1**: All human access to production systems shall require multi-factor authentication (MFA) enforced via Zitadel OIDC. Username/password-only authentication is prohibited.

**PS-002.2**: SSH access to cluster nodes shall use Ed25519 key-based authentication exclusively. Password-based SSH authentication shall be disabled in sshd_config (`PasswordAuthentication no`, `ChallengeResponseAuthentication no`).

**PS-002.3**: SSH root login shall be disabled (`PermitRootLogin no`). Administrative tasks shall be performed via named user accounts with sudo privileges.

**PS-002.4**: Passwords for web applications shall meet the following minimum requirements: 14 characters minimum length, containing uppercase, lowercase, numeric, and special characters. Passwords shall not be reused within 12 generations.

**PS-002.5**: Service accounts shall authenticate using short-lived tokens (maximum 1-hour TTL) issued by OpenBao or Zitadel machine-to-machine grants. Long-lived API keys are prohibited for production services.

### 4.2 Authorization

**PS-002.6**: All access shall follow the principle of least privilege. Users shall be granted only the permissions necessary to perform their assigned duties.

**PS-002.7**: Access to Kubernetes resources shall be governed by RBAC with namespace-scoped roles. Cluster-admin privileges shall be restricted to the CEO and shall not be used for routine operations.

**PS-002.8**: Database access shall be restricted to application service accounts with query-specific permissions. Direct human access to production databases requires documented justification and Security Lead approval.

**PS-002.9**: Privileged access to infrastructure (Hetzner Cloud, Cloudflare, OpenBao root tokens) shall be restricted to the CEO and logged in an immutable audit trail.

### 4.3 Provisioning and Deprovisioning

**PS-002.10**: Access shall be provisioned through a documented request process: (1) request submitted in ClickUp, (2) approved by CEO, (3) implemented by System Administrator, (4) verified by requester.

**PS-002.11**: Access shall be revoked within 24 hours of an individual's termination, role change, or contract completion. For involuntary terminations, access shall be revoked immediately upon notification.

**PS-002.12**: Access reviews shall be conducted monthly. All active accounts, their roles, and permissions shall be reviewed against current business requirements. Accounts with no login activity for 90 days shall be disabled.

### 4.4 Break-Glass Access

**PS-002.13**: Emergency break-glass access shall follow the documented procedure: (1) split-knowledge SSH bypass keys stored in separate physical locations, (2) usage triggers an automated alert to the Security Lead, (3) all actions performed under break-glass access are logged and reviewed within 24 hours, (4) break-glass credentials are rotated after every use.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Approves access requests; conducts monthly access reviews; holds cluster-admin and break-glass authority |
| **Security Lead** | Monitors access logs; investigates anomalies; manages Zitadel OIDC configuration; enforces MFA enrollment |
| **System Administrator** | Provisions/deprovisions access; manages SSH keys; configures RBAC policies; rotates service account credentials |
| **All Personnel** | Protect credentials; report suspected unauthorized access; do not share or reuse credentials |

## 6. Compliance & Enforcement

Unauthorized access attempts, credential sharing, or failure to comply with MFA requirements constitute policy violations handled per the Information Security Policy (POL-001) enforcement framework.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. Access control exceptions additionally require:

- A compensating control documented in the exception request
- A maximum exception duration of 90 days (shorter than the standard 12-month maximum)
- Monthly review of active access control exceptions

## 8. Related Documents

- Information Security Policy (POL-001)
- Data Classification Policy (POL-005)
- Incident Response Policy (POL-004)
- Operational Runbook: Access Review and Privilege Audit (monthly)
- Operational Runbook: Emergency Access (Break-Glass) Procedure

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
| **Policy ID** | POL-002 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
