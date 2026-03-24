---
template: compliance-dashboard-guide
category: compliance
task_type: guide
clickup_list: "05 Compliance Program"
auto_tags: ["compliance", "dashboard", "grafana", "guide"]
required_fields: ["TLDR", "Dashboard Inventory", "Key Metrics", "Threshold Actions", "Dashboard-to-Evidence Mapping"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Compliance Dashboard Interpretation Guide

Reference guide for reading and interpreting compliance dashboards in Grafana.
Keep alongside dashboard JSON exports. File in `docs/compliance/guides/compliance-dashboard-guide.md`.
Link from ClickUp: 05 Compliance Program > Reports.

---

## TLDR

This guide explains how to read compliance dashboards, what each metric means, when to take action based on thresholds, and how dashboard data maps to audit evidence. Use this when onboarding new team members, preparing for audits, or investigating compliance posture changes.

---

## Dashboard Inventory

<!-- [REQUIRED] List all compliance-related dashboards. -->

| Dashboard Name | Grafana URL | Purpose | Update Frequency | Primary Audience |
|---------------|-------------|---------|:----------------:|-----------------|
| Compliance Posture Overview | <!-- URL --> | Overall compliance health across frameworks | Real-time | Leadership, Compliance Lead |
| Control Status by Framework | <!-- URL --> | Per-framework control implementation status | Real-time | Compliance Lead, Auditors |
| POA&M Tracker | <!-- URL --> | Open remediation items and aging | Daily | Compliance Lead, Control Owners |
| Evidence Collection Status | <!-- URL --> | Evidence completeness by control | Weekly | Compliance Lead |
| Risk Heat Map | <!-- URL --> | Active risks by likelihood and impact | Quarterly refresh | Leadership, Security Engineer |
| <!-- Add more as needed --> | | | | |

---

## Key Metrics and What They Mean

<!-- [REQUIRED] Define every metric that appears on compliance dashboards. -->

### Posture Metrics

| Metric | Definition | Good | Warning | Critical | Data Source |
|--------|-----------|:----:|:-------:|:--------:|-------------|
| **Overall Compliance Score** | Percentage of controls in Compliant status across all Tier 1 frameworks | > 85% | 70-85% | < 70% | UCM in ClickUp |
| **Framework Compliance Rate** | Per-framework percentage of controls meeting requirements | > 80% | 60-80% | < 60% | UCM in ClickUp |
| **Controls Assessed** | Percentage of total controls that have been evaluated (not "Not Assessed") | > 95% | 80-95% | < 80% | UCM in ClickUp |

### POA&M Metrics

| Metric | Definition | Good | Warning | Critical | Data Source |
|--------|-----------|:----:|:-------:|:--------:|-------------|
| **Open POA&M Count** | Total remediation items not yet resolved | < 10 | 10-25 | > 25 | ClickUp tasks |
| **Overdue POA&M Count** | Items past their due date | 0 | 1-3 | > 3 | ClickUp tasks |
| **Average POA&M Age** | Mean age of open items in days | < 30 | 30-60 | > 60 | ClickUp tasks |
| **POA&M Closure Rate** | Items closed per month vs. items opened | > 1.0 | 0.7-1.0 | < 0.7 | ClickUp tasks |

### Evidence Metrics

| Metric | Definition | Good | Warning | Critical | Data Source |
|--------|-----------|:----:|:-------:|:--------:|-------------|
| **Evidence Coverage** | Percentage of controls with current evidence | > 90% | 75-90% | < 75% | Evidence Vault |
| **Evidence Freshness** | Percentage of evidence collected within its review cycle | > 85% | 70-85% | < 70% | Evidence Vault |
| **Stale Evidence Count** | Evidence items past their review cycle | 0 | 1-5 | > 5 | Evidence Vault |

### Risk Metrics

| Metric | Definition | Good | Warning | Critical | Data Source |
|--------|-----------|:----:|:-------:|:--------:|-------------|
| **Open High/Critical Risks** | Count of risks scored 13+ | 0 | 1-3 | > 3 | Risk Register |
| **Risk Trend** | Quarter-over-quarter change in total risk score | Declining | Stable | Increasing | Risk Register |
| **Unmitigated Risks** | Risks without an active treatment plan | 0 | 1-2 | > 2 | Risk Register |

---

## Reading the Dashboards

<!-- [REQUIRED] How to interpret each dashboard panel type. -->

### Status Distribution (Pie/Donut Charts)

| Segment | Color | Meaning | Action |
|---------|:-----:|---------|--------|
| Compliant | Green | Control fully implemented, evidence current | None -- maintain |
| Partially Compliant | Yellow | Control partially implemented or evidence gap | Review and complete within 30 days |
| Non-Compliant | Red | Control not implemented or failed assessment | Create POA&M item, remediate per priority |
| Not Assessed | Gray | Control not yet evaluated | Schedule assessment |

### Trend Lines (Time Series)

- **Upward trend in compliance score**: Program is maturing. Verify with evidence, not just status changes.
- **Downward trend in compliance score**: Investigate cause. Common reasons: new controls added, evidence expired, POA&M items overdue.
- **Flat trend**: May indicate stagnation. Review whether improvement actions are being executed.

### Heat Maps (Risk)

- **Top-right quadrant** (High Likelihood + High Impact): Requires immediate action. These risks should have active POA&M items.
- **Bottom-left quadrant** (Low Likelihood + Low Impact): Monitor only. Review quarterly.
- **Movement between quadrants**: Track quarter-over-quarter. Movement toward top-right triggers ALERT.

---

## Threshold Actions

<!-- [REQUIRED] What to do when thresholds are crossed. -->

| Threshold Crossed | Immediate Action | Escalation | Timeline |
|-------------------|-----------------|------------|----------|
| Overall compliance < 70% | Review all non-compliant controls, create POA&M items | Escalate to Wakeem Williams | 24 hours |
| Any framework < 60% | Focus remediation on that framework | Compliance Lead reviews | 48 hours |
| Overdue POA&M > 3 | Contact owners, update timelines or escalate | Compliance Lead reviews | 24 hours |
| Evidence coverage < 75% | Prioritize evidence collection for gaps | Schedule collection sprint | 1 week |
| Open Critical/High risks > 3 | Review treatment plans, accelerate mitigation | Escalate to leadership | 48 hours |

---

## Audit Preparation Checklist

<!-- [OPTIONAL] How to use dashboards to prepare for audits. -->

Before any audit (internal or external):

- [ ] Overall compliance score is > 85%
- [ ] No non-compliant controls without active POA&M items
- [ ] All POA&M items have owners and due dates
- [ ] No overdue POA&M items (or documented justification)
- [ ] Evidence coverage > 90%
- [ ] No stale evidence (all within review cycle)
- [ ] Risk register is current (reviewed within last quarter)
- [ ] Dashboard screenshots exported as evidence: `{CONTROL-ID}_DASHBOARD_{DATE}_{VERSION}`

---

## Dashboard-to-Evidence Mapping

<!-- [REQUIRED] How dashboard data satisfies audit evidence requirements. -->

| Dashboard | Evidence Type | Framework | Control | How to Export |
|-----------|-------------|-----------|---------|---------------|
| Compliance Posture Overview | Compliance monitoring evidence | SOC 2 CC4.1 | Monitoring activities | Screenshot + PDF export |
| Control Status by Framework | Control implementation evidence | ISO 27001 Clause 9.1 | ISMS monitoring | Grafana panel share + CSV |
| POA&M Tracker | Remediation tracking evidence | NIST CSF RS.MI | Mitigation activities | CSV export from Grafana |
| Evidence Collection Status | Evidence management evidence | ISO 27001 Clause 7.5 | Documented information | Screenshot + timestamp |
| Risk Heat Map | Risk assessment evidence | SOC 2 CC3.2 | Risk assessment | Quarterly snapshot + PDF |

**Evidence naming convention**: `{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}`

Example: `CC4.1_DASHBOARD_2026-03-22_v1`

---

## Troubleshooting

<!-- [OPTIONAL] Common dashboard issues and how to resolve them. -->

| Issue | Likely Cause | Resolution |
|-------|-------------|------------|
| Dashboard shows stale data | Data source query timeout or sync lag | Check Grafana data source health; verify ClickUp sync |
| Control count mismatch with UCM | New controls added but not synced | Re-sync UCM data source; verify control inventory |
| POA&M count differs from ClickUp | Dashboard filter excludes some statuses | Review dashboard query filters; align with ClickUp views |
| Risk heat map empty | Quarterly data not refreshed | Run quarterly risk assessment; update risk register |

---

## Access and Permissions

<!-- [OPTIONAL] Who can view and modify compliance dashboards. -->

| Role | View | Edit | Export | Share |
|------|:----:|:----:|:------:|:-----:|
| Leadership | Yes | No | Yes | Yes |
| Compliance Lead | Yes | Yes | Yes | Yes |
| Security Engineer | Yes | Yes | Yes | No |
| Control Owners | Yes (own controls) | No | Yes | No |
| Auditors (guest) | Yes (read-only) | No | Yes | No |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Guide Satisfies It |
|-----------|-----------|-------------|------------------------------|
| SOC 2 | CC4.1 | Monitoring activities | Defines how compliance monitoring dashboards are interpreted |
| SOC 2 | CC4.2 | Communicate deficiencies | Specifies threshold actions for compliance gaps |
| ISO 27001 | Clause 9.1 | Monitoring, measurement, analysis | Documents metrics, thresholds, and interpretation procedures |
| NIST CSF | GV.OC | Organizational context | Enables consistent interpretation of compliance posture |
| NIST CSF | ID.GV | Governance | Provides governance framework for dashboard-driven decisions |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Every dashboard in inventory has a valid Grafana URL
- [ ] All metrics have defined thresholds (Good/Warning/Critical)
- [ ] Dashboard-to-evidence mapping covers all Tier 1 frameworks
- [ ] Reviewed by compliance lead and infrastructure engineer
- [ ] Accessible to all roles listed in Access and Permissions

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
