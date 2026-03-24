---
title: "Management Review Procedure"
policy_id: POL-016
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
    controls: ["9.3"]
  - framework: SOC 2
    controls: ["CC1.2", "CC4.2"]
  - framework: HIPAA
    controls: ["164.308(a)(8)"]
---

# Management Review Procedure

## TLDR

Describes how Helix Stax management reviews the ISMS to ensure continuing suitability, adequacy, and effectiveness. Covers review inputs, outputs, meeting templates, and record-keeping for solo founders. Required by ISO 27001 Clause 9.3 and SOC 2. Approved by CEO.

---

## Purpose

This procedure describes how Helix Stax management reviews the ISMS to ensure its continuing suitability, adequacy, and effectiveness, as required by ISO 27001:2022 Clause 9.3.

## Scope

- All ISMS components and controls
- All infrastructure and operational metrics
- All risk register entries and audit findings

---

## Procedure Steps

### 1. Review Frequency and Attendees

- **Frequency:** Quarterly (recommended for high-velocity startups) or at minimum semi-annually
- **Attendees:** For a solo founder, conducted as a "Formal Review Session." External contractors providing DevOps or Security services should be invited to provide input.

### 2. Review Inputs

The following items must be reviewed during each session:

1. **Status of Previous Actions:** Progress on items from the last management review
2. **Internal/External Issues:** Changes in Hetzner Cloud availability, new AlmaLinux vulnerabilities, or regulatory changes (e.g., new HIPAA guidance)
3. **Feedback:** Client security questionnaires or feedback
4. **Performance Metrics:**
   - Uptime of Zitadel and K3s services
   - Number of blocked attacks (CrowdSec/Traefik)
   - Vulnerability remediation timelines
5. **Audit Results:** Summary of internal audit findings
6. **Risk Assessment:** Review of the Risk Register and whether current controls (OpenBao, OIDC) are sufficient

### 3. Review Outputs

The review must conclude with decisions and actions related to:

- Continual improvement opportunities
- Any need for changes to the ISMS
- Resource needs (e.g., upgrading Hetzner nodes or purchasing additional backup storage)

### 4. Meeting Template (FORM-MGMT-01)

**MEETING MINUTES: ISMS MANAGEMENT REVIEW**

| Field | Value |
|-------|-------|
| Date | YYYY-MM-DD |
| Location | Remote / Office |
| Facilitator | Name / Founder |

**Input Review Checklist:**

| Input Item | Summary of Status / Discussion | Action Required? |
|------------|-------------------------------|-----------------|
| Audit Results | Review of Q[X] Internal Audit Findings | Y/N |
| Incidents | Review of security incidents (e.g., failed Zitadel logins) | Y/N |
| Risk Status | Are current risks in the Risk Register still accurate? | Y/N |
| Tech Health | OpenSCAP scan results and K3s patch status | Y/N |

**Decisions and Action Items:**

| ID | Decision / Action Item | Owner | Target Date |
|----|----------------------|-------|-------------|
| 001 | e.g., Update OpenBao rotation policy to 60 days | Founder | YYYY-MM-DD |
| 002 | e.g., Schedule external pen-test for Traefik ingress | Founder | YYYY-MM-DD |

**Statement of Effectiveness:**
*Based on the inputs provided, the ISMS is deemed [Effective / Effective with minor improvements / Ineffective].*

**Signed:** __________________________ (Founder/CEO)

### 5. Record Keeping for Solo Founders

To prove to auditors that management reviews actually occurred:

1. **Digitally Sign** the minutes using a timestamped GPG signature or store them in a Git repository with immutable commit history
2. **Attach Evidence Artifacts:** Directly link Grafana dashboards or OpenSCAP reports reviewed during the session to the meeting minutes

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Facilitate review, make decisions, sign off on effectiveness |
| **External Consultants** | Provide security/DevOps input when invited |
| **Compliance Lead** | Prepare review inputs, track action items to closure |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| ISO 27001 | 9.3 | Management Review |
| SOC 2 | CC1.2 | Board Oversight |
| SOC 2 | CC4.2 | Communication of Deficiencies |
| HIPAA | 164.308(a)(8) | Evaluation |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
