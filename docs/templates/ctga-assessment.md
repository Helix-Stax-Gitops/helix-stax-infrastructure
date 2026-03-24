---
template: ctga-assessment
category: delivery
task_type: assessment
clickup_list: "02 Delivery"
auto_tags: ["ctga", "assessment", "client-facing", "maturity"]
required_fields: ["TLDR", "Assessment Header", "Score Overview", "Controls Strand", "Technology Strand", "Growth Strand", "Adoption Strand", "Findings", "Remediation Roadmap"]
classification: client-facing
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: CTGA Maturity Assessment

Helix Stax proprietary CTGA (Controls, Technology, Growth, Adoption) maturity assessment.
Used for client engagements -- initial baseline or recurring assessment. Classification: Client-Facing.
File in `docs/delivery/{client-slug}/YYYY-MM-DD-ctga-assessment.md`.
Link from ClickUp: 02 Delivery > {Client} > Assessments.

---

## TLDR

<!-- [REQUIRED] Two sentences. Client name, overall score, maturity band, and the single most critical finding. -->

Example: ACME Corp scored 485/900 (Developing) in their initial CTGA assessment, with Controls (145/225) and Adoption (80/225) as the weakest strands. The most critical finding is the absence of any documented change management process, impacting both compliance readiness and operational stability.

---

## Assessment Header

<!-- [REQUIRED] Key facts at a glance. -->

| Field | Value |
|-------|-------|
| **Client** | <!-- [REQUIRED] Client name --> |
| **Assessment Date** | <!-- [REQUIRED] YYYY-MM-DD --> |
| **Assessment Type** | <!-- Initial Baseline / Recurring (Qn YYYY) --> |
| **Assessor** | <!-- Name(s) --> |
| **Overall Score** | <!-- [REQUIRED] NNN / 900 --> |
| **Maturity Band** | <!-- [REQUIRED] Reactive / Developing / Proactive / Optimized --> |
| **Previous Score** | <!-- N/A for initial, or NNN / 900 --> |
| **Score Delta** | <!-- +/- or N/A --> |

---

## Maturity Bands

| Score Range | Band | Description |
|:-----------:|------|-------------|
| 100 - 300 | Reactive | Ad hoc processes, minimal documentation, firefighting mode |
| 301 - 500 | Developing | Some documented processes, inconsistent execution, gaps in coverage |
| 501 - 700 | Proactive | Defined processes, regular monitoring, continuous improvement emerging |
| 701 - 900 | Optimized | Automated controls, metrics-driven decisions, predictive capabilities |

---

## Score Overview

<!-- [REQUIRED] Summary across all four strands. Each strand scores 100-225. -->

| Strand | Score | Max | Percentage | Band |
|--------|:-----:|:---:|:----------:|------|
| **Controls** | <!-- /225 --> | 225 | <!-- % --> | <!-- Reactive/Developing/Proactive/Optimized --> |
| **Technology** | <!-- /225 --> | 225 | <!-- % --> | |
| **Growth** | <!-- /225 --> | 225 | <!-- % --> | |
| **Adoption** | <!-- /225 --> | 225 | <!-- % --> | |
| **Overall** | <!-- /900 --> | 900 | <!-- % --> | |

---

## Controls Strand (C)

<!-- [REQUIRED] Security controls, compliance posture, risk management, policies. -->

### Domain Scores

| Domain | Score | Max | Notes |
|--------|:-----:|:---:|-------|
| Security Policies & Procedures | | <!-- /45 --> | |
| Access Control & Identity | | <!-- /45 --> | |
| Change Management | | <!-- /45 --> | |
| Incident Response | | <!-- /45 --> | |
| Risk Management & Compliance | | <!-- /45 --> | |
| **Controls Total** | | **/225** | |

### Observations

<!-- What was found during assessment of Controls. Be specific. -->

-
-

### Strand Recommendations

<!-- Actions specific to improving the Controls score. -->

| # | Recommendation | Current Impact | Expected Score Impact | Priority |
|---|---------------|:--------------:|:--------------------:|----------|
| 1 | | | +___ points | P1/P2/P3/P4 |
| 2 | | | | |

---

## Technology Strand (T)

<!-- [REQUIRED] Infrastructure maturity, tooling, automation, monitoring, architecture. -->

### Domain Scores

| Domain | Score | Max | Notes |
|--------|:-----:|:---:|-------|
| Infrastructure & Architecture | | <!-- /45 --> | |
| Monitoring & Observability | | <!-- /45 --> | |
| CI/CD & Automation | | <!-- /45 --> | |
| Data Management & Backup | | <!-- /45 --> | |
| Security Tooling | | <!-- /45 --> | |
| **Technology Total** | | **/225** | |

### Observations

-
-

### Strand Recommendations

| # | Recommendation | Current Impact | Expected Score Impact | Priority |
|---|---------------|:--------------:|:--------------------:|----------|
| 1 | | | +___ points | P1/P2/P3/P4 |
| 2 | | | | |

---

## Growth Strand (G)

<!-- [REQUIRED] Scalability, business alignment, strategic planning, capacity management. -->

### Domain Scores

| Domain | Score | Max | Notes |
|--------|:-----:|:---:|-------|
| Strategic Planning & Roadmap | | <!-- /45 --> | |
| Scalability & Capacity | | <!-- /45 --> | |
| Documentation & Knowledge | | <!-- /45 --> | |
| Process Maturity | | <!-- /45 --> | |
| Business Continuity & DR | | <!-- /45 --> | |
| **Growth Total** | | **/225** | |

### Observations

-
-

### Strand Recommendations

| # | Recommendation | Current Impact | Expected Score Impact | Priority |
|---|---------------|:--------------:|:--------------------:|----------|
| 1 | | | +___ points | P1/P2/P3/P4 |
| 2 | | | | |

---

## Adoption Strand (A)

<!-- [REQUIRED] User enablement, training, organizational buy-in, change management culture. -->

### Domain Scores

| Domain | Score | Max | Notes |
|--------|:-----:|:---:|-------|
| Training & Awareness | | <!-- /45 --> | |
| Tool Adoption & Utilization | | <!-- /45 --> | |
| Process Adherence | | <!-- /45 --> | |
| Organizational Alignment | | <!-- /45 --> | |
| Continuous Improvement Culture | | <!-- /45 --> | |
| **Adoption Total** | | **/225** | |

### Observations

-
-

### Strand Recommendations

| # | Recommendation | Current Impact | Expected Score Impact | Priority |
|---|---------------|:--------------:|:--------------------:|----------|
| 1 | | | +___ points | P1/P2/P3/P4 |
| 2 | | | | |

---

## Findings by Priority

<!-- [REQUIRED] All findings consolidated and ranked. -->

| # | Finding | Strand | Domain | Priority | Affected Frameworks |
|---|---------|--------|--------|----------|-------------------|
| 1 | | C/T/G/A | | P1 (Critical) | <!-- SOC 2, NIST, etc. --> |
| 2 | | | | P2 (High) | |
| 3 | | | | P3 (Normal) | |
| 4 | | | | P4 (Low) | |

---

## Remediation Roadmap

<!-- [REQUIRED] Phased plan with projected score impact per phase. -->

### Phase 1: Quick Wins (0 - 30 days)

| # | Action | Strand | Projected Score Impact | Effort |
|---|--------|--------|:---------------------:|--------|
| 1 | | | +___ points | <!-- Hours/days --> |
| 2 | | | | |

**Projected score after Phase 1**: ___ / 900

### Phase 2: Foundation (30 - 90 days)

| # | Action | Strand | Projected Score Impact | Effort |
|---|--------|--------|:---------------------:|--------|
| 1 | | | +___ points | |
| 2 | | | | |

**Projected score after Phase 2**: ___ / 900

### Phase 3: Maturation (90 - 180 days)

| # | Action | Strand | Projected Score Impact | Effort |
|---|--------|--------|:---------------------:|--------|
| 1 | | | +___ points | |
| 2 | | | | |

**Projected score after Phase 3**: ___ / 900

---

## Recommended Services

<!-- [OPTIONAL] Helix Stax services that address the client's gaps. -->

| Service | Addresses | Strands Impacted | Engagement Type |
|---------|-----------|:----------------:|----------------|
| <!-- Service name --> | <!-- Which findings --> | C / T / G / A | <!-- Retainer / Project / Assessment --> |

---

## Next Assessment

| Field | Value |
|-------|-------|
| **Recommended cadence** | <!-- Quarterly / Semi-annual / Annual --> |
| **Next assessment date** | <!-- YYYY-MM-DD --> |
| **Focus areas** | <!-- Which strands/domains to prioritize --> |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Assessment Maps |
|-----------|-----------|-------------|--------------------------|
| SOC 2 | CC3.1 | Risk identification | Controls strand assesses security control posture |
| SOC 2 | CC4.1 | Monitoring activities | CTGA recurring assessments track control effectiveness |
| ISO 27001 | Clause 9.1 | Monitoring and measurement | Quantified maturity scoring across 4 domains |
| NIST CSF | ID.RA | Risk assessment | Controls and Technology strands map to risk assessment |
| NIST CSF | PR.AT | Awareness and training | Adoption strand directly measures training and awareness |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] All four strand scores sum to overall score
- [ ] Domain scores within each strand sum to strand total
- [ ] Findings prioritized and linked to strands
- [ ] Remediation roadmap has projected score impact per phase
- [ ] Reviewed by engagement lead
- [ ] Client-ready formatting (no internal notes or jargon)

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Sable Navarro (Product Manager) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Client-Facing |
| **Version** | 1.0 |
