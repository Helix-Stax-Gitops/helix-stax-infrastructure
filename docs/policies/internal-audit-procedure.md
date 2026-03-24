---
title: "Internal Audit Procedure"
policy_id: POL-015
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
  - framework: ISO 27001
    controls: ["9.2"]
  - framework: SOC 2
    controls: ["CC4.1"]
  - framework: HIPAA
    controls: ["164.308(a)(8)"]
---

# Internal Audit Procedure

## TLDR

Defines the process for conducting internal audits of the Helix Stax ISMS to ensure compliance with ISO 27001:2022, SOC 2, and HIPAA. Covers audit planning, methodology, evidence collection, and corrective action tracking. Approved by CEO.

---

## Purpose

This procedure defines the process for conducting internal audits of the Helix Stax Information Security Management System (ISMS) to ensure compliance with ISO 27001:2022, SOC 2 (Trust Services Criteria), and HIPAA Security Rule requirements.

## Scope

- All infrastructure (K3s, AlmaLinux 9.7, Hetzner Cloud)
- All applications and services
- All administrative processes and controls

---

## Procedure Steps

### 1. Audit Program Planning

**Frequency:** Internal audits shall be performed at least annually, or more frequently if significant changes occur (e.g., K3s cluster migration, major Zitadel configuration changes).

**Quarterly Audit Schedule:**

| Quarter | Audit Focus Area | Reference Controls |
|---------|-----------------|-------------------|
| Q1 | Access Control and Identity (Zitadel, OIDC) | ISO A.5.15-18, SOC 2 AC |
| Q2 | Technical Infrastructure and Encryption (K3s, OpenBao, S3) | ISO A.8.1, A.8.24, HIPAA |
| Q3 | Risk Management and Incident Response | ISO 6.1.2, A.5.24 |
| Q4 | HR Security and Policy Review | ISO A.5.1, A.6 |

### 2. Audit Methodology

The auditor shall employ three primary methods:

1. **Interview:** Questioning process owners (in a solo environment, this involves reviewing documented decisions)
2. **Observation:** Real-time viewing of system configurations (e.g., verifying Traefik IngressRoute TLS settings)
3. **Technical Testing:** Verification of security settings through automated tools

### 3. Solo Auditor Independence Requirements

In a 1-person team, Helix Stax maintains objectivity through:

- **Self-Assessment:** The founder performs the primary audit using a standardized checklist
- **External Peer Review:** Engaging an external qualified consultant or reciprocal "audit buddy" to review the internal audit report every 2 years
- **Automated Evidence:** Relying on system-generated logs and reports that cannot be easily manipulated

### 4. Technical Audit Evidence (Automation)

- **OpenSCAP:** Weekly automated scans of AlmaLinux 9.7 nodes against CIS Benchmark or STIG. Reports stored in the audit evidence repository.
- **Zitadel Logs:** Audit logs exported to Loki/Grafana to verify only authorized OIDC users accessed management interfaces.
- **OpenBao Audit Trail:** Verification that secret access is logged and encryption keys are rotated per policy.
- **Kube-bench:** Running CIS Kubernetes Benchmark against the K3s cluster.

### 5. Audit Report Template (FORM-AUD-01)

Each audit report must include:

1. **Audit ID and Date**
2. **Scope of Audit** (e.g., "K3s Node Security")
3. **Summary of Findings:** Categorized as "Conformity," "Opportunity for Improvement (OFI)," or "Non-conformity (NC)"
4. **Evidence Links:** (e.g., "Link to OpenSCAP HTML report")

### 6. Corrective Action Tracking

Any Non-conformity identified must be logged in the **Corrective Action Tracking Log**. Each entry requires:

- Root Cause Analysis (RCA)
- Corrective Action Plan
- Verification of closure date

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve audit schedule, review findings, allocate resources |
| **Internal Auditor** | Plan and execute audits, document findings |
| **System Owners** | Provide access to evidence, implement corrective actions |
| **External Reviewer** | Validate audit independence (biennial peer review) |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| ISO 27001 | 9.2 | Internal Audit |
| SOC 2 | CC4.1 | Monitoring Activities |
| HIPAA | 164.308(a)(8) | Evaluation |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
