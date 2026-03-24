---
template: compliance-risk-register-entry
category: compliance
task_type: risk
clickup_list: "05 Compliance Program"
auto_tags: ["risk", "compliance", "risk-register"]
required_fields: ["TLDR", "Risk Identification", "Risk Assessment", "Compliance Impact", "Current Mitigation", "Mitigation Plan", "KRIs"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "NIST SP 800-53"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Risk Register Entry

Use for documenting individual security, operational, or compliance risks in the enterprise risk register. File as `docs/compliance/risk-register/RISK-{ID}.md`.

---

## TLDR

<!-- One sentence: risk ID, title, likelihood + impact, current status. -->

Example: RISK-045: Kubernetes RBAC misconfiguration. HIGH likelihood, CRITICAL impact. Currently unmitigated; remediation planned for Q2 2026.

---

## Risk Identification

### [REQUIRED] Basic Information

| Field | Value |
|-------|-------|
| **Risk ID** | RISK-___ |
| **Risk Title** | |
| **Category** | Security / Operational / Compliance / Financial / Reputational |
| **Identified Date** | YYYY-MM-DD |
| **Identified By** | |
| **Last Updated** | YYYY-MM-DD |

### [REQUIRED] Risk Owner

| Role | Name | Email | Phone |
|------|------|-------|-------|
| **Risk Owner** | | | |
| **Business Owner** | | | |
| **Technical Owner** | | | |

---

## Risk Description

### [REQUIRED] Narrative

<!-- Detailed description of the risk. What could go wrong? Why? Impact on business/security/compliance. 2-3 paragraphs. -->

---

## Risk Assessment

### [REQUIRED] Likelihood & Impact Matrix

**Likelihood**: How often might this occur?

- [ ] **L1 - Rare**: <1% chance per year
- [ ] **L2 - Unlikely**: 1-5% chance per year
- [ ] **L3 - Possible**: 5-25% chance per year
- [ ] **L4 - Likely**: 25-75% chance per year
- [ ] **L5 - Almost Certain**: >75% chance per year

**Justification**:

**Impact**: Damage if this risk materializes?

- [ ] **I1 - Negligible**: <$10K, no client impact, no regulatory impact
- [ ] **I2 - Minor**: $10K-$100K, limited client impact, low regulatory impact
- [ ] **I3 - Moderate**: $100K-$1M, affects some clients, moderate regulatory impact
- [ ] **I4 - Major**: $1M-$5M, affects many clients, significant regulatory impact
- [ ] **I5 - Catastrophic**: >$5M, widespread client impact, critical regulatory/reputational impact

**Justification**:

### [REQUIRED] Risk Score

**Current Risk Level** (before mitigations):

| | Negligible | Minor | Moderate | Major | Catastrophic |
|---|-----------|-------|----------|-------|--------------|
| **Rare** | Green | Green | Yellow | Yellow | Yellow |
| **Unlikely** | Green | Yellow | Yellow | Orange | Orange |
| **Possible** | Yellow | Yellow | Orange | Orange | Red |
| **Likely** | Yellow | Orange | Orange | Red | Red |
| **Almost Certain** | Yellow | Orange | Red | Red | Red |

**Risk Score**: [ ] **GREEN** (Low) [ ] **YELLOW** (Medium) [ ] **ORANGE** (High) [ ] **RED** (Critical)

---

## Affected Frameworks & Controls

### [REQUIRED] Compliance Impact

| Framework | Control ID | Control Name | Gap? | Evidence |
|-----------|-----------|--------------|------|----------|
| SOC 2 | | | Yes / No | |
| ISO 27001 | | | Yes / No | |
| NIST CSF | | | Yes / No | |
| PCI DSS | | | Yes / No | |

---

## Current Mitigation

### [REQUIRED] Existing Controls

| Control | Status | Effectiveness | Notes |
|---------|--------|----------------|-------|
| | Implemented / Partial / Planned | Low / Medium / High | |
| | | | |

**Risk Level AFTER Current Controls**: [ ] Green [ ] Yellow [ ] Orange [ ] Red

### [OPTIONAL] Residual Risk Tolerance

Is the current residual risk acceptable to the organization?

- [ ] **Acceptable**: Risk is tolerable at current level, monitor only
- [ ] **Acceptable with Conditions**: Risk acceptable if mitigations stay in place, review quarterly
- [ ] **Unacceptable**: Risk is intolerable, must reduce via additional mitigations

---

## Risk Mitigation Plan

### [REQUIRED] Planned Mitigations

| Mitigation | Target Date | Owner | Status | Expected Risk Reduction |
|-----------|------------|-------|--------|--------------------------|
| | | | Planned / In Progress / Complete | From ___ to ___ |
| | | | | |

### [REQUIRED] Mitigation Timeline

**Mitigation Phase 1** (by [date]):
- [ ] Action item 1
- [ ] Action item 2

**Mitigation Phase 2** (by [date]):
- [ ] Action item 1

**Mitigation Phase 3** (by [date]):
- [ ] Action item 1

### [OPTIONAL] Mitigation Dependencies

- Depends on: [other risks or projects]
- Blocks: [other risks or projects]
- Budget required: $___________

---

## Monitoring & Controls

### [REQUIRED] Key Risk Indicators (KRIs)

| Indicator | Baseline | Threshold | Current | Frequency |
|-----------|----------|-----------|---------|-----------|
| | | | | Weekly / Monthly / Quarterly |
| | | | | |

**Where KRIs are monitored**:
- [ ] Prometheus / Grafana
- [ ] ClickUp task tracking
- [ ] Manual review
- [ ] Other: _______

### [REQUIRED] Testing & Validation

How will the organization verify that mitigations are effective?

| Test | Frequency | Owner | Last Run | Result |
|------|-----------|-------|----------|--------|
| | Quarterly / Annually | | | Pass / Fail |
| | | | | |

---

## Financial Impact Analysis

### [OPTIONAL] Cost-Benefit of Mitigations

| Mitigation Cost | Annual Cost | Expected Benefit (avoided loss) | ROI |
|-----------------|------------|--------------------------------|----|
| Implementation | $_____ | | |
| Ongoing maintenance | $_____/year | $_____ avoided per year | __% |

**Cost-benefit acceptable**: Yes / No

---

## Risk Register Entry

### [REQUIRED] Status Tracking

| Date | Status | Likelihood | Impact | Owner | Notes |
|------|--------|-----------|--------|-------|-------|
| YYYY-MM-DD | Identified | L_ | I_ | | |
| | | | | | |
| | | | | | |

**Status Options**: Identified → Assessed → Planned → In Progress → Mitigated → Closed

### [OPTIONAL] Risk Acceptance

If risk is accepted without mitigation:

- [ ] Risk accepted by: _____________ (Name, Title)
- [ ] Acceptance date: YYYY-MM-DD
- [ ] Business justification: ______________
- [ ] Review date: YYYY-MM-DD

**Risk acceptance must be approved by Security Lead and Business Owner.**

---

## Compliance Evidence

### [REQUIRED] Compliance Mapping

This risk entry satisfies:
- **SOC 2 CC3.3**: Risk assessment and mitigation planning
- **ISO 27001 A.12.6.1**: Management of technical vulnerabilities
- **NIST CSF ID.RA**: Asset management and risk assessment
- **NIST SP 800-53 RA-3**: Risk assessment documentation

### [OPTIONAL] Audit Trail

- [ ] Reviewed by risk committee (date: _______)
- [ ] Escalated to executive sponsor (date: _______)
- [ ] Included in audit evidence package
- [ ] Demonstrable in SOC 2 Type II audit

---

## Review Schedule

- [ ] **Quarterly**: Status update and KRI review
- [ ] **Annually**: Full risk reassessment and mitigation effectiveness validation
- [ ] **Immediately**: If risk materializes (incident opened)

**Last reviewed**: ___________
**Next review date**: ___________
**Responsible reviewer**: ___________

---

## Related Risks

**Related risks** (interdependencies):

- RISK-___: [Title]
- RISK-___: [Title]

**Related incidents/vulnerabilities**:

- INC-___: [Title]
- VUL-___: [Title]

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Internal / Confidential |
