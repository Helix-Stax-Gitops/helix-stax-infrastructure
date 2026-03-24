---
template: incident-report
category: operational
task_type: incident
clickup_list: "04 Service Management"
auto_tags: ["incident", "operations", "post-mortem"]
required_fields: ["TLDR", "Detection", "Severity", "Affected Services", "Timeline", "Root Cause", "Action Items"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF", "ISO 27001"]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Incident Report

Complete this report within 24 hours of incident resolution.
Store in `docs/runbooks/incidents/YYYY-MM-DD-{slug}.md`.

## TLDR

<!-- One sentence. What broke, when, and what fixed it. -->

Example: Traefik ingress lost TLS cert renewal on 2026-03-15 at 02:14 UTC; cert-manager pod had crashed 72 hours earlier. Restored by restarting cert-manager and manually triggering renewal.

---

## Detection

**Detected at**: YYYY-MM-DD HH:MM UTC

**Detected by**: <!-- Monitoring alert / User report / Manual observation -->

**Detection method**:
- [ ] Grafana / Loki alert
- [ ] Rocket.Chat notification
- [ ] User complaint
- [ ] Manual check
- [ ] Other: _______________

**Time to detection**: <!-- How long after the fault began before it was caught -->

---

## Severity

- [ ] **SEV-1**: Full outage. All users affected. Production down.
- [ ] **SEV-2**: Partial outage. Core feature broken for all or most users.
- [ ] **SEV-3**: Degraded performance. Feature impaired; workaround exists.
- [ ] **SEV-4**: Minor. Edge case or cosmetic issue.

---

## Affected Services

<!-- List every service that was impacted. Include namespace and cluster. -->

| Service | Namespace | Cluster | Impact |
|---------|-----------|---------|--------|
| | | | |
| | | | |

---

## Impact

| Metric | Value |
|--------|-------|
| **Users affected** | |
| **Duration** | ___ minutes / hours |
| **Data loss?** | Yes / No |
| **Revenue impact** | Yes / No / Unknown |
| **Client-facing?** | Yes / No |

---

## Timeline

<!-- UTC timestamps. Be exact. Include what you did, not just what happened. -->

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Fault begins (estimated) |
| HH:MM | First alert fires |
| HH:MM | On-call notified |
| HH:MM | Investigation starts |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | Service restored |
| HH:MM | Incident closed |

**Total duration**: ___ minutes

---

## Immediate Actions Taken

<!-- What did you do to restore service? Commands run, configs changed, rollbacks executed. -->

1.
2.
3.

**Commands run**:

```bash
# Paste commands here
```

---

## Root Cause

<!-- One paragraph. Be specific. "The pod crashed" is not a root cause.
     "The cert-manager pod OOM-killed due to a memory leak introduced in v1.13.0" is. -->

---

## Contributing Factors

<!-- What made this worse or harder to detect? -->

- [ ] No alerting configured
- [ ] Alert fired but was ignored
- [ ] Monitoring gap
- [ ] Missing runbook
- [ ] Dependency failure
- [ ] Configuration drift
- [ ] Other: _______________

---

## Resolution

<!-- Exactly what fixed it. -->

---

## Action Items

<!-- What changes prevent recurrence? Assign owners and due dates. -->

| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| | | | |
| | | | |

---

## Lessons Learned [REQUIRED]

What did this incident teach you? Write things future-you needs to know.

- [Lesson learned]
- [Lesson learned]

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC7.4 | Security incident management — documented incident response and lessons learned | Timeline captures detection to resolution; action items drive improvements |
| SOC 2 | CC7.5 | Monitoring and maintenance of protection systems | Incidents feed improvement roadmap and control enhancements |
| NIST CSF | RC.IM-1 | Incident handling coordination and execution | Structured incident report with root cause, actions, and timeline |
| ISO 27001 | A.16.1.5 | Response to information security incidents — documented root cause and improvement | Action items drive preventive controls |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Timeline is in UTC with exact timestamps
- [ ] Root cause is specific (not vague — "pod crashed" vs "pod OOM-killed due to memory leak in X version")
- [ ] Action items are assigned with owners and due dates
- [ ] Lessons learned documented
- [ ] Report reviewed by incident lead and technical stakeholders
- [ ] Action items tracked in ClickUp with dependencies

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.1 |
