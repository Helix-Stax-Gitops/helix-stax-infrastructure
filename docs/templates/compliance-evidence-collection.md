---
template: compliance-evidence-collection
category: compliance
task_type: evidence
clickup_list: "05 Compliance Program"
auto_tags: ["compliance", "evidence", "audit"]
required_fields: ["TLDR", "Control Being Evidenced", "Evidence Documentation", "Gap Analysis", "Evidence Lifecycle", "Attestation"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "PCI DSS", "HIPAA", "GDPR"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Compliance Evidence Collection Worksheet

Use for gathering documentation evidence to satisfy compliance control requirements. Store in `docs/compliance/evidence/{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}.md`.

---

## TLDR

<!-- One sentence: control ID, framework, type of evidence being collected, date. -->

Example: SOC 2 CC6.2 (Logical access control) — Collecting evidence of role-based access control implementation for Zitadel and Kubernetes RBAC as of 2026-03-22.

---

## Evidence Requisition

### [REQUIRED] Control Being Evidenced

| Field | Value |
|-------|-------|
| **Framework** | SOC 2 / ISO 27001 / NIST CSF / PCI DSS / HIPAA / GDPR / CIS |
| **Control ID** | |
| **Control Name** | |
| **Control Description** | |
| **Requirement** | |

### [REQUIRED] Evidence Collection Metadata

| Field | Value |
|-------|-------|
| **Evidence Type** | Policy / Procedure / Configuration / Log / Report / Screenshot / Certification / Audit Trail |
| **Collection Date** | YYYY-MM-DD |
| **Evidence Period** | From YYYY-MM-DD to YYYY-MM-DD |
| **Collected By** | |
| **Reviewed By** | |

### [REQUIRED] Control Scope

**What systems/data does this control apply to?**

- [ ] Kubernetes cluster (K3s on Hetzner)
- [ ] PostgreSQL databases
- [ ] MinIO object storage
- [ ] Zitadel identity provider
- [ ] Rocket.Chat communication platform
- [ ] Network perimeter (Cloudflare)
- [ ] Application layer (_________)
- [ ] All systems

---

## Evidence Documentation

### [REQUIRED] Evidence Item 1

**Description**: What specific piece of evidence demonstrates this control?

**Location/Source**: Where is this evidence stored or maintained?

**Format**: Document / Configuration file / Screenshot / Log entry / Code / Report / Other

**Evidence Content**:

```
Paste the actual evidence here (config file, policy text, log excerpt, etc.)
```

**How this evidences the control**:

### [OPTIONAL] Evidence Item 2

**Description**:

**Location/Source**:

**Format**:

**Evidence Content**:

```

```

**How this evidences the control**:

### [OPTIONAL] Evidence Item 3

**Description**:

**Location/Source**:

**Format**:

**Evidence Content**:

```

```

**How this evidences the control**:

---

## Control Satisfaction Assessment

### [REQUIRED] Gap Analysis

| Requirement | Is This Requirement Met? | Evidence Supporting | Gap? |
|-------------|--------------------------|-------------------|------|
| | Yes / Partial / No | | |
| | | | |

### [REQUIRED] Overall Control Assessment

- [ ] **SATISFIED**: All requirements met, strong evidence
- [ ] **PARTIALLY SATISFIED**: Most requirements met, some evidence gaps
- [ ] **NOT SATISFIED**: Key requirements missing, significant evidence gaps

**Explanation**:

---

## Remediation for Gaps (if applicable)

### [REQUIRED] Gap Remediation Plan

For each gap identified above:

| Gap | Root Cause | Remediation Action | Owner | Target Date |
|-----|-----------|-------------------|-------|-------------|
| | | | | |
| | | | | |

**Remediation priority**:
- [ ] P1 (Critical - audit show-stopper)
- [ ] P2 (High - must remediate before next audit)
- [ ] P3 (Medium - should remediate within 6 months)
- [ ] P4 (Low - nice to have)

---

## Compliance Framework Context

### [REQUIRED] Control Origin

| Framework | Origin | Links |
|-----------|--------|-------|
| SOC 2 | Trust Services Criteria (if applicable) | |
| ISO 27001 | Annex A clause (if applicable) | |
| NIST CSF | Function / Category / Subcategory | |
| PCI DSS | Requirement (if applicable) | |
| HIPAA | 45 CFR § section (if applicable) | |
| GDPR | Article (if applicable) | |

### [OPTIONAL] Cross-Framework Mapping

This control may satisfy:

| Framework | Control ID | Alignment | Evidence Reusable? |
|-----------|-----------|-----------|-------------------|
| | | Same / Similar / Superset / Subset | Yes / No |
| | | | |

---

## Evidence Lifecycle

### [REQUIRED] Evidence Retention

- [ ] How long must this evidence be retained? ___ years (usually 3-7 years minimum)
- [ ] Where is evidence stored? (Obsidian vault / GitHub / S3 / Archive)
- [ ] Is evidence encrypted? Yes / No
- [ ] Access control: Who can view this evidence? (Compliance team / Auditors / Internal only)

### [REQUIRED] Evidence Freshness

- [ ] When does this evidence expire? YYYY-MM-DD
- [ ] How often must this control be re-evidenced? Monthly / Quarterly / Annually
- [ ] Who is responsible for evidence refresh? ___________

---

## Audit Trail & Attestation

### [REQUIRED] Evidence Completeness Checklist

- [ ] All required documents collected
- [ ] No sensitive data exposed in evidence (PII, secrets, keys)
- [ ] Evidence is legible and clear
- [ ] Evidence is dated and timestamped
- [ ] Evidence includes source/system name
- [ ] Chain of custody documented (who collected, when, verified by)

### [REQUIRED] Internal Attestation

| Role | Name | Date | Sign-Off |
|------|------|------|----------|
| **Compliance Lead** | | | ✓ / ✗ |
| **Security Lead** | | | ✓ / ✗ |
| **Evidence Reviewer** | | | ✓ / ✗ |

**Attestation Statement**: I certify that this evidence is complete, accurate, and demonstrates satisfaction of the control requirement as of the collection date.

---

## Audit-Ready Packaging

### [REQUIRED] Audit Presentation Format

**How will auditors access this evidence?**

- [ ] In person demonstration (system walkthrough)
- [ ] Screenshots/photos
- [ ] Exported configuration files (sanitized)
- [ ] Policy documents
- [ ] Audit trail logs
- [ ] Interview with control owner

**Presentation narrative** (2-3 sentences explaining control to auditor):

### [OPTIONAL] Sensitive Data Handling

**Does this evidence contain sensitive data?**

- [ ] Yes — PII / Secrets / Financial data / Other: __________
- [ ] No — Safe to share with external auditors

**If sensitive**: How will this be redacted for external auditors?

---

## Related Evidence

**Other evidence supporting this same control**:
- [Link to evidence document]
- [Link to evidence document]

**Other controls this evidence also supports**:
- CONTROL-ID: [Name]
- CONTROL-ID: [Name]

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Internal / Confidential |
