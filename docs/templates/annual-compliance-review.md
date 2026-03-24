---
template: annual-compliance-review
category: compliance
task_type: review
clickup_list: "05 Compliance Program"
auto_tags: ["compliance", "annual-review", "audit"]
required_fields: ["TLDR", "Executive Summary", "Year-over-Year Posture", "Audit Results", "Control Maturity", "Gaps Remaining", "Strategic Roadmap"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: annually
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Annual Compliance Review

Year-end review of the compliance program: posture trends, audit outcomes, maturity progression, and strategic roadmap.
Generate before annual audit or at fiscal year end. File in `docs/compliance/reviews/YYYY-annual-review.md`.
Link from ClickUp: 05 Compliance Program > Audits.

---

## TLDR

<!-- [REQUIRED] Two sentences. Year-over-year posture change and the single most impactful accomplishment. -->

Example: Helix Stax compliance posture improved from 64% to 87% across Tier 1 frameworks in FY2026, driven by the Unified Control Matrix (UCM) rollout and Zitadel OIDC migration. SOC 2 Type II readiness moved from Developing to Proactive maturity.

---

## Executive Summary

<!-- [REQUIRED] 3-5 paragraphs for leadership consumption. Cover:
     - Overall compliance health and trend
     - Major achievements
     - Key gaps remaining
     - Budget and resource implications
     - Strategic outlook -->

---

## Report Header

| Field | Value |
|-------|-------|
| **Review Period** | <!-- FY YYYY or YYYY-01-01 to YYYY-12-31 --> |
| **Report Date** | YYYY-MM-DD |
| **Prepared By** | <!-- Name --> |
| **Frameworks Covered** | <!-- List all active frameworks --> |
| **Previous Review Date** | <!-- Link to last year's review --> |

---

## Year-over-Year Posture by Framework

<!-- [REQUIRED] Show progress across all active frameworks. -->

| Framework | Start of Year | End of Year | Delta | Trend |
|-----------|:------------:|:-----------:|:-----:|:-----:|
| NIST CSF 2.0 | <!-- % --> | <!-- % --> | <!-- +/- --> | <!-- Improving/Stable/Declining --> |
| SOC 2 | | | | |
| ISO 27001 | | | | |
| CIS Controls v8 | | | | |
| HIPAA (if applicable) | | | | |

---

## Audit Results Summary

<!-- [REQUIRED] Results from any formal audits conducted this year. -->

| Audit | Date | Auditor | Result | Findings | Observations |
|-------|------|---------|--------|:--------:|:------------:|
| <!-- SOC 2 Type II --> | | | Pass / Qualified / Fail | | |
| <!-- ISO 27001 Surveillance --> | | | | | |
| <!-- Internal Audit --> | | | | | |

### Findings Detail

<!-- List significant audit findings. -->

| Finding # | Framework | Control | Description | Severity | Status | Remediation Date |
|-----------|-----------|---------|-------------|----------|--------|-----------------|
| | | | | Critical/Major/Minor/Observation | Open/Closed | |

---

## Control Maturity by Domain

<!-- [REQUIRED] Score each domain on a 1-5 maturity scale. -->

| Maturity Level | Description |
|:--------------:|-------------|
| 1 - Initial | Ad hoc, undocumented |
| 2 - Developing | Partially documented, inconsistent execution |
| 3 - Defined | Documented, consistently executed |
| 4 - Managed | Measured, monitored, feedback loops |
| 5 - Optimized | Continuous improvement, automated |

| Domain | Start of Year | End of Year | Target Next Year |
|--------|:------------:|:-----------:|:----------------:|
| Access Control | | | |
| Change Management | | | |
| Incident Response | | | |
| Risk Management | | | |
| Vulnerability Management | | | |
| Data Protection | | | |
| Business Continuity | | | |
| Vendor Management | | | |
| Security Awareness | | | |
| Asset Management | | | |

---

## Key Accomplishments

<!-- [REQUIRED] Major compliance milestones achieved this year. -->

| # | Accomplishment | Framework(s) Impacted | Controls Addressed |
|---|---------------|----------------------|-------------------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Gaps Remaining

<!-- [REQUIRED] Known compliance gaps that carry into next year. -->

| # | Gap | Framework | Control(s) | Risk Level | Remediation Plan |
|---|-----|-----------|-----------|:----------:|-----------------|
| 1 | | | | High/Med/Low | |
| 2 | | | | | |
| 3 | | | | | |

---

## Risk Posture Summary

<!-- [REQUIRED] Annual risk snapshot. -->

| Metric | Q1 | Q2 | Q3 | Q4 | Year Trend |
|--------|:--:|:--:|:--:|:--:|:----------:|
| Total open risks | | | | | |
| Critical/High risks | | | | | |
| Risks closed | | | | | |
| Mean time to remediate (days) | | | | | |

---

## POA&M Annual Summary

| Metric | Count |
|--------|:-----:|
| POA&M items opened this year | |
| POA&M items closed this year | |
| POA&M items carried over | |
| Average age at closure (days) | |
| Items overdue at year-end | |

---

## Strategic Roadmap for Next Year

<!-- [REQUIRED] Phased plan for compliance improvement. -->

### H1 Goals (January - June)

| # | Goal | Framework(s) | Key Actions | Success Criteria |
|---|------|-------------|-------------|-----------------|
| 1 | | | | |
| 2 | | | | |

### H2 Goals (July - December)

| # | Goal | Framework(s) | Key Actions | Success Criteria |
|---|------|-------------|-------------|-----------------|
| 1 | | | | |
| 2 | | | | |

---

## Budget Recommendations

<!-- [OPTIONAL] Resource needs for the compliance program next year. -->

| Category | Current Spend | Proposed Spend | Justification |
|----------|:------------:|:--------------:|---------------|
| Tooling | | | |
| Audits (external) | | | |
| Training | | | |
| Staffing / Contractors | | | |
| **Total** | | | |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Review Satisfies It |
|-----------|-----------|-------------|------------------------------|
| SOC 2 | CC4.1 | Monitoring activities | Annual evaluation of control effectiveness |
| ISO 27001 | Clause 9.3 | Management review | Formal review of ISMS performance and improvement |
| NIST CSF | GV.OC | Organizational context | Annual assessment of compliance program maturity |
| NIST CSF | ID.GV | Governance | Documents governance posture and strategic direction |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Year-over-year posture data is verified against monthly reports
- [ ] Audit findings reconciled with auditor reports
- [ ] Maturity scores justified with evidence
- [ ] Strategic roadmap has measurable success criteria
- [ ] Reviewed by compliance lead and approved by leadership
- [ ] Distributed to relevant stakeholders

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Confidential |
| **Version** | 1.0 |
