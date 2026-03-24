---
title: "Change Management Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-003"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC8.1", "CC6.8", "CC7.1"]
  - framework: "ISO 27001"
    controls: ["A.8.9", "A.8.32"]
  - framework: "NIST CSF"
    controls: ["PR.IP-3", "DE.CM-4"]
---

# Change Management Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Change Management Policy governs how changes to Helix Stax production systems are requested, reviewed, approved, tested, and deployed. All changes flow through GitOps (ArgoCD) with CI/CD via Devtron. Required by SOC 2 CC8.1, ISO 27001 A.8.9. Approved by CEO.

---

## 1. Purpose

This policy ensures that all changes to production infrastructure and applications are controlled, documented, and traceable. It prevents unauthorized modifications, reduces the risk of service disruption, and provides an auditable change history for compliance evidence.

## 2. Scope

This policy covers all changes to:

- Kubernetes manifests, Helm charts, and ArgoCD application definitions
- Infrastructure-as-Code (OpenTofu modules, Ansible playbooks)
- Application source code deployed to the K3s cluster
- DNS records (Cloudflare), firewall rules, and network configurations
- Database schemas (CloudNativePG)
- Secrets and credential rotations (OpenBao)
- Operating system patches and kernel parameters (AlmaLinux 9)
- CI/CD pipeline configurations (Devtron)

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Standard Change** | A pre-approved, low-risk, routine change that follows a documented procedure (e.g., dependency update, certificate renewal) |
| **Normal Change** | A change requiring review and approval before implementation |
| **Emergency Change** | A change required to restore service or mitigate an active security threat, implemented before full review |
| **Change Record** | A documented record of a change including its justification, approval, implementation details, and outcome |
| **GitOps** | A deployment methodology where Git is the single source of truth; changes are applied by reconciling desired state from Git to the cluster |

## 4. Policy Statements

### 4.1 Change Request Process

**PS-003.1**: All changes to production systems shall be initiated through a pull request (PR) in the appropriate GitHub repository. Direct modification of production systems without a corresponding PR is prohibited.

**PS-003.2**: Each PR shall include: (1) description of the change and business justification, (2) risk assessment (impact if the change fails), (3) rollback procedure, (4) testing evidence.

**PS-003.3**: Standard changes shall be documented in the Process Library (ClickUp Folder 06) with pre-approved procedures. Standard changes require a PR but do not require additional approval beyond automated CI checks.

### 4.2 Review and Approval

**PS-003.4**: Normal changes shall be reviewed and approved by at least one reviewer before merging. The change author shall not self-approve their own changes.

**PS-003.5**: Changes affecting security controls, authentication systems (Zitadel), secrets management (OpenBao), or network configurations shall require CEO approval regardless of change category.

**PS-003.6**: All PRs shall pass automated CI checks (linting, security scanning, unit tests) before approval. PRs with failing checks shall not be merged.

### 4.3 Deployment

**PS-003.7**: Production deployments shall be executed exclusively through the GitOps pipeline: code merged to the designated branch triggers ArgoCD synchronization. Manual kubectl apply, helm install, or direct SSH modifications to production are prohibited except during emergency changes.

**PS-003.8**: Database schema changes shall be applied through versioned migration scripts committed to version control. Ad-hoc SQL execution against production databases is prohibited under normal operations.

**PS-003.9**: OS-level changes (patches, kernel parameters, service configurations) shall be applied through Ansible playbooks committed to the infrastructure repository. Manual SSH-based changes are prohibited except during emergency changes.

### 4.4 Emergency Changes

**PS-003.10**: Emergency changes are permitted only when: (1) a production service is currently unavailable, OR (2) an active security threat requires immediate mitigation.

**PS-003.11**: Emergency changes shall be documented retroactively within 24 hours of implementation, including: the incident that triggered the change, actions taken, who authorized the change, and a post-implementation review.

**PS-003.12**: All emergency changes that bypassed the standard GitOps pipeline shall be codified into the appropriate repository within 48 hours to prevent configuration drift.

### 4.5 Rollback

**PS-003.13**: Every change shall have a documented rollback procedure. For GitOps-deployed changes, rollback is performed by reverting the Git commit. For OS-level changes, Ansible playbooks shall include rollback tasks.

**PS-003.14**: ArgoCD drift detection shall alert on any divergence between the Git-defined desired state and the actual cluster state. Detected drift shall be investigated and resolved within 4 hours.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Approves security-sensitive changes; authorizes emergency changes; reviews change metrics quarterly |
| **System Administrator** | Implements changes through GitOps pipeline; monitors deployment health; executes rollbacks when needed |
| **Security Lead** | Reviews changes affecting security controls; validates that security scanning passes before approval |
| **All Personnel** | Submit changes through the PR process; do not modify production systems directly |

## 6. Compliance & Enforcement

Unauthorized changes to production systems (bypassing the PR/GitOps pipeline) constitute a serious policy violation. All changes are logged in Git history, ArgoCD sync logs, and Kubernetes audit logs, providing an immutable audit trail.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. Change management exceptions require:

- Documentation of why the standard process cannot be followed
- Identification of compensating controls (e.g., additional monitoring)
- Maximum exception duration of 30 days

## 8. Related Documents

- Information Security Policy (POL-001)
- Incident Response Policy (POL-004)
- `docs/runbooks/` -- Operational runbooks for standard changes
- `docs/adr/` -- Architecture Decision Records for significant design changes
- Devtron CI/CD pipeline documentation

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
| **Policy ID** | POL-003 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
