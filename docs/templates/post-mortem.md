---
template: post-mortem
category: operational
task_type: post-mortem
clickup_list: "04 Service Management"
auto_tags: ["post-mortem", "incident", "blameless"]
required_fields: ["TLDR", "Incident Metadata", "Timeline", "Impact", "Root Cause", "Five Whys", "Action Items", "Lessons Learned"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF", "ISO 27001"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Post-Mortem

Blameless analysis of a resolved incident. Focus on systems, not individuals.
Complete within 48 hours of incident resolution. File in `docs/runbooks/incidents/YYYY-MM-DD-{slug}-postmortem.md`.
Link from ClickUp: 04 Service Management > Incidents.

**Note**: Post-mortems are blameless. The goal is to understand what happened, why, and how to prevent recurrence. Never assign individual blame.

---

## TLDR

<!-- [REQUIRED] One sentence. What happened, when, and how it was resolved. -->

Example: CloudNativePG primary pod OOM-killed on 2026-03-15 at 14:22 UTC due to a memory leak in pg_stat_statements; failover to replica succeeded but caused 8 minutes of write unavailability. Fixed by upgrading CloudNativePG operator to v1.23.1.

---

## Incident Metadata

<!-- [REQUIRED] Key facts at a glance. -->

| Field | Value |
|-------|-------|
| **Incident ID** | <!-- INC-YYYY-NNN --> |
| **Severity** | <!-- SEV-1 / SEV-2 / SEV-3 / SEV-4 --> |
| **Duration** | <!-- Total minutes/hours from fault to resolution --> |
| **Detection Method** | <!-- Grafana alert / Loki alert / User report / Manual observation --> |
| **Time to Detection** | <!-- Minutes from fault start to first alert --> |
| **Incident Commander** | <!-- Name --> |
| **Date** | <!-- YYYY-MM-DD --> |
| **Related Incident Report** | <!-- Link to incident report if one exists --> |

---

## Timeline

<!-- [REQUIRED] UTC timestamps. Be exact. Include actions taken, not just events. -->

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Fault begins (estimated) |
| HH:MM | First alert fires (specify which alert) |
| HH:MM | Incident commander notified |
| HH:MM | Investigation begins |
| HH:MM | <!-- Key investigation milestone --> |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | Service restored and verified |
| HH:MM | Incident closed |

**Total incident duration**: ___ minutes

---

## Impact

<!-- [REQUIRED] Quantify the impact. -->

| Metric | Value |
|--------|-------|
| **Services affected** | <!-- List services and namespaces --> |
| **Users affected** | <!-- Number or percentage --> |
| **Duration of user impact** | <!-- Minutes/hours --> |
| **Data loss** | Yes / No |
| **SLA breach** | Yes / No (specify which SLA) |
| **PHI/PII exposed** | Yes / No |
| **Revenue impact** | Yes / No / Unknown |
| **Client-facing** | Yes / No |

---

## Root Cause

<!-- [REQUIRED] One specific paragraph. "The pod crashed" is NOT a root cause.
     "The CloudNativePG primary OOM-killed because pg_stat_statements accumulated
     unbounded memory in v1.22.0 when tracking >10k unique queries" IS a root cause. -->

---

## Five Whys

<!-- [REQUIRED] Trace from symptom to systemic root cause. -->

1. **Why** did [symptom]?
   Because <!-- answer -->

2. **Why** did [answer from #1]?
   Because <!-- answer -->

3. **Why** did [answer from #2]?
   Because <!-- answer -->

4. **Why** did [answer from #3]?
   Because <!-- answer -->

5. **Why** did [answer from #4]?
   Because <!-- answer --> (root cause)

---

## Contributing Factors

<!-- [OPTIONAL] What made this incident worse or harder to detect/resolve. -->

- [ ] No alerting configured for this failure mode
- [ ] Alert fired but was ignored or missed
- [ ] Monitoring gap (metric not collected)
- [ ] Missing or outdated runbook
- [ ] Dependency failure (cascading)
- [ ] Configuration drift from documented state
- [ ] Insufficient capacity / resource limits
- [ ] Other: _______________

---

## What Went Well

<!-- [REQUIRED] Acknowledge what worked. This reinforces good practices. -->

- <!-- Example: Automated failover worked as designed -->
- <!-- Example: Alert fired within 30 seconds of fault -->

---

## What Went Wrong

<!-- [REQUIRED] Identify systemic failures (not individual blame). -->

- <!-- Example: No runbook existed for this failure mode -->
- <!-- Example: Alert was too noisy, causing desensitization -->

---

## Runbook Evaluation

<!-- [REQUIRED] Forces evaluation of operational preparedness. -->

| Question | Answer |
|----------|--------|
| Was there a runbook for this scenario? | Yes / No |
| If yes, was it followed? | Yes / Partially / No |
| If yes, did it help resolve the issue? | Yes / Partially / No |
| If no, should one be created? | Yes / No |
| Runbook link (if exists) | <!-- Link --> |

---

## Action Items

<!-- [REQUIRED] Concrete actions to prevent recurrence. Every action must have an owner and due date. -->

| # | Action | Owner | Due Date | Priority | Status | ClickUp Task |
|---|--------|-------|----------|----------|--------|-------------|
| 1 | | | | P1/P2/P3/P4 | Open | |
| 2 | | | | | Open | |
| 3 | | | | | Open | |

---

## Lessons Learned

<!-- [REQUIRED] What this incident taught us. Write for future operators. -->

-
-

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Post-Mortem Satisfies It |
|-----------|-----------|-------------|-----------------------------------|
| SOC 2 | CC7.3 | Evaluate security events | Analyzes incident root cause and impact |
| SOC 2 | CC7.4 | Respond to security incidents | Documents response actions and timeline |
| SOC 2 | CC7.5 | Remediate identified vulnerabilities | Tracks corrective action items to completion |
| NIST CSF | RS.AN-1 | Notifications from detection systems investigated | Documents investigation from alert to resolution |
| NIST CSF | RS.AN-2 | Impact of incident understood | Quantifies impact across services and users |
| ISO 27001 | A.16.1.6 | Learning from information security incidents | Captures lessons learned and systemic improvements |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Timeline has UTC timestamps with at least 5 entries
- [ ] Root cause is specific and actionable (not vague)
- [ ] Five Whys reaches a systemic cause
- [ ] Every action item has an owner and due date
- [ ] Action items are ticketed in ClickUp
- [ ] Reviewed by incident commander and infrastructure engineer

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Kit Morrow (Infrastructure Engineer) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Internal |
| **Version** | 1.0 |
