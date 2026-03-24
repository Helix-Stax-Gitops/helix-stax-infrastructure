---
template: monthly-compliance-status
category: compliance
task_type: report
clickup_list: "05 Compliance Program"
auto_tags: ["compliance", "monthly", "report", "status"]
required_fields: ["TLDR", "Report Header", "Controls by Status", "Open Items", "New Findings", "Resolved Findings", "Evidence Summary", "Top 3 Risks", "Key Actions"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: monthly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Monthly Compliance Status Report

Monthly posture report summarizing compliance health across all active frameworks.
Generate on the first business day of each month. File in `docs/compliance/reports/YYYY-MM-compliance-status.md`.
Link from ClickUp: 05 Compliance Program > Reports.

---

## TLDR

<!-- [REQUIRED] Two sentences. Overall posture and the single most important finding this month. -->

Example: Helix Stax compliance posture improved from 78% to 82% across Tier 1 frameworks in March 2026. Two new NIST CSF gaps were identified in the Identity domain, offset by closing four SOC 2 POA&M items.

---

## Report Header

<!-- [REQUIRED] Key facts at a glance. -->

| Field | Value |
|-------|-------|
| **Reporting Period** | <!-- YYYY-MM (e.g., 2026-03) --> |
| **Report Date** | YYYY-MM-DD |
| **Prepared By** | <!-- Name --> |
| **Frameworks Covered** | <!-- NIST CSF 2.0, SOC 2, ISO 27001, CIS Controls v8, HIPAA (if applicable) --> |
| **Overall Posture Score** | <!-- Percentage or fraction --> |
| **Previous Period Score** | <!-- Percentage or fraction --> |
| **Trend** | <!-- Improving / Stable / Declining --> |

---

## Controls by Status

<!-- [REQUIRED] Per-framework breakdown. -->

| Framework | Total Controls | Compliant | Partially Compliant | Non-Compliant | Not Assessed |
|-----------|:-------------:|:---------:|:-------------------:|:-------------:|:------------:|
| NIST CSF 2.0 | | | | | |
| SOC 2 | | | | | |
| ISO 27001 | | | | | |
| CIS Controls v8 | | | | | |
| HIPAA (if applicable) | | | | | |

---

## Open POA&M Items

<!-- [REQUIRED] Plan of Action & Milestones aging report. -->

| Aging Bucket | Count | Change from Last Month |
|:------------:|:-----:|:---------------------:|
| < 30 days | | |
| 30 - 60 days | | |
| 60 - 90 days | | |
| > 90 days (overdue) | | |
| **Total Open** | | |

**Highest-priority open POA&M items**:

| POA&M ID | Control | Description | Owner | Due Date | Status |
|----------|---------|-------------|-------|----------|--------|
| | | | | | |
| | | | | | |

---

## New Findings This Period

<!-- [REQUIRED] Gaps, deficiencies, or observations identified this month. -->

| Finding ID | Framework | Control | Description | Severity | Remediation Target |
|------------|-----------|---------|-------------|----------|-------------------|
| | | | | P1/P2/P3/P4 | YYYY-MM-DD |

---

## Resolved Findings This Period

<!-- [REQUIRED] What was closed out this month. -->

| Finding ID | Framework | Control | Resolution Summary | Closed Date |
|------------|-----------|---------|-------------------|-------------|
| | | | | |

---

## Evidence Collection Summary

<!-- [REQUIRED] Track evidence completeness. -->

| Framework | Evidence Required | Evidence Collected | Collection Rate |
|-----------|:-----------------:|:------------------:|:---------------:|
| NIST CSF 2.0 | | | % |
| SOC 2 | | | % |
| ISO 27001 | | | % |
| CIS Controls v8 | | | % |

**Evidence gaps** (required but not yet collected):

| Control ID | Evidence Type | Due Date | Assigned To |
|------------|--------------|----------|-------------|
| | | | |

---

## Top 3 Risks

<!-- [REQUIRED] The three most significant compliance risks right now. -->

| # | Risk | Affected Framework(s) | Likelihood | Impact | Mitigation Plan |
|---|------|-----------------------|:----------:|:------:|----------------|
| 1 | | | Low/Med/High | Low/Med/High | |
| 2 | | | | | |
| 3 | | | | | |

---

## Key Actions for Next Period

<!-- [REQUIRED] What must happen next month to maintain or improve posture. -->

| # | Action | Owner | Target Date | Priority |
|---|--------|-------|-------------|----------|
| 1 | | | | P1/P2/P3/P4 |
| 2 | | | | |
| 3 | | | | |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Report Satisfies It |
|-----------|-----------|-------------|------------------------------|
| SOC 2 | CC4.1 | COSO monitoring activities | Provides periodic compliance monitoring and reporting |
| SOC 2 | CC4.2 | Evaluate and communicate deficiencies | Surfaces findings and tracks remediation |
| ISO 27001 | Clause 9.1 | Monitoring, measurement, analysis | Monthly measurement of ISMS effectiveness |
| NIST CSF | GV.OC | Organizational context | Tracks compliance posture across frameworks over time |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] All framework control counts reconcile with UCM
- [ ] POA&M aging is accurate against ClickUp task dates
- [ ] Evidence collection rates verified against Evidence Vault
- [ ] Reviewed by compliance lead
- [ ] Distributed to stakeholders

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Internal |
| **Version** | 1.0 |
