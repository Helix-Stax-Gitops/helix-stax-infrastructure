---
template: quarterly-risk-assessment
category: compliance
task_type: risk-assessment
clickup_list: "05 Compliance Program"
auto_tags: ["risk", "assessment", "quarterly", "compliance"]
required_fields: ["TLDR", "Assessment Header", "Risk Heat Map", "Top 10 Risks", "New Risks", "Vulnerability Trends", "Progress", "Recommendations"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Quarterly Risk Assessment

Comprehensive risk assessment with heat map, trend analysis, and POA&M progress tracking.
Generate quarterly (January, April, July, October). File in `docs/compliance/risk/YYYY-QN-risk-assessment.md`.
Link from ClickUp: 05 Compliance Program > Risk Register.

---

## TLDR

<!-- [REQUIRED] Two sentences. Overall risk posture and the most significant change since last quarter. -->

Example: Helix Stax risk posture remains Medium with 3 High-rated risks, down from 5 last quarter. The most significant change is the closure of the Zitadel misconfiguration risk (R-2026-008) following the OIDC hardening project.

---

## Assessment Header

<!-- [REQUIRED] Key facts at a glance. -->

| Field | Value |
|-------|-------|
| **Quarter** | <!-- Q1/Q2/Q3/Q4 YYYY --> |
| **Assessment Date** | YYYY-MM-DD |
| **Assessor** | <!-- Name and role --> |
| **Methodology** | <!-- NIST SP 800-30 / ISO 27005 / Custom --> |
| **Scope** | <!-- All production systems / Specific domain --> |
| **Overall Risk Rating** | <!-- Low / Medium / High / Critical --> |
| **Previous Quarter Rating** | <!-- Low / Medium / High / Critical --> |
| **Trend** | <!-- Improving / Stable / Worsening --> |

---

## Risk Landscape Summary

<!-- [REQUIRED] Narrative overview of the current threat environment.
     Cover external threats, internal risks, and changes since last quarter. -->

---

## Risk Heat Map

<!-- [REQUIRED] Visual risk distribution. Mark each cell with the count of risks in that zone. -->

|  | **Low Impact** | **Medium Impact** | **High Impact** | **Critical Impact** |
|---|:---:|:---:|:---:|:---:|
| **High Likelihood** | <!-- count --> | <!-- count --> | <!-- count --> | <!-- count --> |
| **Medium Likelihood** | <!-- count --> | <!-- count --> | <!-- count --> | <!-- count --> |
| **Low Likelihood** | <!-- count --> | <!-- count --> | <!-- count --> | <!-- count --> |

**Risk scoring formula**: Risk Score = Likelihood (1-5) x Impact (1-5)

| Score Range | Rating | Response |
|:-----------:|--------|----------|
| 1 - 5 | Low | Accept or monitor |
| 6 - 12 | Medium | Mitigate within 90 days |
| 13 - 19 | High | Mitigate within 30 days |
| 20 - 25 | Critical | Immediate action required |

---

## Top 10 Risks

<!-- [REQUIRED] Ranked by risk score. -->

| Rank | Risk ID | Description | Likelihood (1-5) | Impact (1-5) | Risk Score | Trend | Owner | Treatment |
|:----:|---------|-------------|:-----------------:|:------------:|:----------:|:-----:|-------|-----------|
| 1 | R-YYYY-NNN | | | | | <!-- Up/Down/Stable --> | | <!-- Accept / Mitigate / Transfer / Avoid --> |
| 2 | | | | | | | | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |
| 6 | | | | | | | | |
| 7 | | | | | | | | |
| 8 | | | | | | | | |
| 9 | | | | | | | | |
| 10 | | | | | | | | |

---

## New Risks Identified

<!-- [REQUIRED] Risks discovered since last quarter. -->

| Risk ID | Description | Source | Likelihood | Impact | Score | Treatment Plan |
|---------|-------------|--------|:----------:|:------:|:-----:|---------------|
| | | <!-- Audit / Scan / Incident / Review --> | | | | |

---

## Risks Closed or Downgraded

<!-- [REQUIRED] Risks resolved or reduced since last quarter. -->

| Risk ID | Description | Previous Score | Action Taken | New Status |
|---------|-------------|:--------------:|-------------|------------|
| | | | | Closed / Downgraded to ___ |

---

## Vulnerability Trends

<!-- [REQUIRED] 4-quarter rolling comparison. -->

| Metric | Q-3 | Q-2 | Q-1 | Current | Trend |
|--------|:---:|:---:|:---:|:-------:|:-----:|
| Total open risks | | | | | |
| Critical/High risks | | | | | |
| Mean time to remediate (days) | | | | | |
| New risks identified | | | | | |
| Risks closed | | | | | |
| Overdue POA&M items | | | | | |

---

## POA&M Progress

<!-- [REQUIRED] Plan of Action & Milestones status. -->

| POA&M ID | Risk ID | Control | Description | Owner | Due Date | Status | % Complete |
|----------|---------|---------|-------------|-------|----------|--------|:----------:|
| | | | | | | On Track / At Risk / Overdue | |

**POA&M summary**:

| Status | Count |
|--------|:-----:|
| Completed this quarter | |
| On track | |
| At risk | |
| Overdue | |
| **Total active** | |

---

## Risk by Domain

<!-- [OPTIONAL] Risk distribution across operational domains. -->

| Domain | Total Risks | Critical | High | Medium | Low |
|--------|:-----------:|:--------:|:----:|:------:|:---:|
| Infrastructure | | | | | |
| Identity & Access | | | | | |
| Data Protection | | | | | |
| Application Security | | | | | |
| Business Continuity | | | | | |
| Third-Party / Vendor | | | | | |
| Compliance | | | | | |

---

## Recommendations

<!-- [REQUIRED] Prioritized actions for the next quarter. -->

| # | Recommendation | Risk(s) Addressed | Priority | Estimated Effort |
|---|---------------|-------------------|----------|-----------------|
| 1 | | | P1/P2/P3/P4 | <!-- Hours/days --> |
| 2 | | | | |
| 3 | | | | |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Assessment Satisfies It |
|-----------|-----------|-------------|----------------------------------|
| SOC 2 | CC3.1 | Risk identification | Identifies and ranks risks across all domains |
| SOC 2 | CC3.2 | Risk assessment | Scores risks by likelihood and impact |
| SOC 2 | CC3.3 | Risk responses | Documents treatment decisions for each risk |
| ISO 27001 | Clause 6.1 | Risk assessment process | Provides structured, repeatable risk assessment |
| NIST CSF | ID.RA-1 | Asset vulnerabilities identified | Catalogs vulnerabilities and their risk scores |
| NIST CSF | ID.RA-4 | Business impacts identified | Assesses impact of risk realization |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Top 10 risks are ranked with scores and owners
- [ ] Heat map reflects current risk distribution
- [ ] 4-quarter trend data is accurate
- [ ] POA&M items reconciled with ClickUp
- [ ] Reviewed by security engineer and compliance lead
- [ ] Presented to leadership

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Ezra Raines (Security Engineer) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Confidential |
| **Version** | 1.0 |
