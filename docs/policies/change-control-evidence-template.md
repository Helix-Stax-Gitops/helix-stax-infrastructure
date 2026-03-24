---
title: "Change Control Evidence Template"
policy_id: POL-024
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
    controls: ["CC8.1"]
  - framework: ISO 27001
    controls: ["A.8.9", "A.8.32"]
---

# Change Control Evidence Template

## TLDR

Ensures all changes to the Helix Stax environment are authorized, tested, and documented. Covers change request forms, evidence sources (ADRs, ClickUp, Devtron/ArgoCD, Git), evidence collection checklists, and mapping to POL-003 Change Management Policy. Required by SOC 2 and ISO 27001. Approved by CEO.

---

## Purpose

This document ensures all changes to the Helix Stax environment are authorized, tested, and documented to maintain system integrity and audit readiness.

## Scope

- All production infrastructure changes
- All application deployments
- All configuration changes to K3s, Traefik, Zitadel, and other core services

---

## Procedure Steps

### 1. Change Request (CR) Form Template

To be linked in ClickUp tasks or GitHub PR descriptions.

| Field | Value |
|-------|-------|
| **Request ID** | CHG-YYYY-#### |
| **Requester** | [Name] |
| **Date** | YYYY-MM-DD |
| **Change Type** | Standard / Normal / Emergency |
| **Description** | [What is being changed and why?] |
| **Risk Assessment** | High / Med / Low -- Impact on availability, security, or data integrity |
| **Rollback Plan** | [Specific steps, e.g., `git revert <hash>` or `velero restore`] |
| **Test Results** | [Link to CI/CD pipeline, Vitest results, or manual QA logs] |
| **Approver** | [Peer/Architect Name -- must not be the Requester] |

### 2. Evidence Sources for Change Control

| Evidence Type | Source | Details |
|---------------|--------|---------|
| **Architectural Changes** | ADRs stored in Git | Each ADR includes Status (Proposed/Accepted/Superseded) |
| **Operational Changes** | ClickUp Tasks | Every infrastructure ticket links to a Git Commit or PR |
| **Deployment Evidence** | Devtron | Deployment history logs showing who triggered the sync |
| **GitOps Diffs** | ArgoCD | "Current State" vs "Desired State" diffs |
| **Code Changes** | Git | All changes via Pull Request with at least one required approval |

### 3. Evidence Collection Checklist (Per Audit Period)

For a sampled change, the following evidence must be provided:

- [ ] **Authorization:** ClickUp task or ADR approval
- [ ] **Testing:** Pipeline logs showing successful build/test (GitHub Actions/Devtron)
- [ ] **Implementation:** Git commit hash showing the diff in the YAML manifest
- [ ] **Validation:** Link to monitoring (Grafana) showing stable metrics post-deploy
- [ ] **Segregation of Duties (SoD):** Proof that the person who merged was not the sole author (Peer Review)

### 4. Mapping to POL-003 (Change Management Policy)

| Policy Rule | Enforcement |
|-------------|-------------|
| 3.1: All production changes require a ticket | Mapped to ClickUp Task |
| 3.2: No direct changes to K3s via `kubectl` in Production | Mapped to ArgoCD/Devtron Sync Logs |
| 3.5: Emergency changes require retrospective approval within 24 hours | Mapped to "Emergency" flag in CR Form |

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve high-risk changes, oversee change management compliance |
| **DevOps Lead** | Execute changes, maintain deployment evidence in Devtron/ArgoCD |
| **Architect** | Review architectural changes, approve ADRs |
| **Compliance Lead** | Collect evidence per audit period, verify SoD compliance |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| SOC 2 | CC8.1 | Change Management |
| ISO 27001 | A.8.9 | Configuration Management |
| ISO 27001 | A.8.32 | Change Management |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
