---
template: n8n-workflow-readme
category: infrastructure
task_type: workflow
clickup_list: "02 Platform Engineering"
auto_tags: ["n8n", "automation", "workflow"]
required_fields: ["TLDR", "Trigger", "Flow Description", "Credentials Required", "Debugging"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF"]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: n8n Workflow README

One README per workflow. Store alongside the workflow JSON in the repo.
Path convention: `workflows/{slug}/README.md` and `workflows/{slug}/{workflow-name}.json`

## TLDR [REQUIRED]

One sentence. What this workflow does and when it runs.

**Example**: Sends a Rocket.Chat notification to Wakeem whenever a new GitHub issue is labeled `bug` and assigned to `helix-infra`.

---

## Trigger [REQUIRED]

| Field | Value |
|-------|-------|
| **Trigger type** | [Webhook / Cron / Manual / Event] |
| **Trigger detail** | [URL path, cron expression, or event name] |
| **Cron schedule** | [e.g., `0 9 * * 1-5` for weekdays at 09:00 UTC, or N/A] |
| **Webhook URL** | [e.g., `https://n8n.helixstax.net/webhook/{path}`, or N/A] |
| **Expected frequency** | [How often this fires in normal operation] |

---

## Flow Description [REQUIRED]

Describe what the workflow does step by step.
Write it like a sentence, not a node list.
"When X happens, Y is fetched from Z, transformed into W, and sent to V."

---

## What It Creates / Modifies [REQUIRED]

List every external side effect. Be specific.

| System | Action | Detail |
|--------|--------|--------|
| [System name] | [Action] | [Specific detail - table, channel, etc] |
| [System name] | [Action] | [Specific detail] |

If the workflow is read-only, state: "Read-only. No external modifications."

---

## Credentials Required [REQUIRED]

List every credential by name as it appears in n8n.
Do not paste the actual secret values here.

| Credential Name (in n8n) | Service | Notes |
|--------------------------|---------|-------|
| [Credential name] | [Service] | [Scope, permissions, or usage notes] |
| [Credential name] | [Service] | [Scope, permissions, or usage notes] |

**Where credentials are stored**: OpenBao / n8n credential store

**How to rotate**: [Link to SOP or describe steps]

---

## Error Handling

<!-- Describe how errors are handled within the workflow. -->

**On node failure**:
- [ ] Workflow stops and logs error
- [ ] Retry configured: ___ attempts, ___ second delay
- [ ] Error branch sends alert to: _______________
- [ ] Other: _______________

**On partial failure** (some items succeed, some fail):
<!-- Describe behavior -->

**On external service unavailable**:
<!-- Describe behavior -->

---

## Debugging

**How to test manually**:

```
1. Open n8n UI at https://n8n.helixstax.net
2. Find workflow: [workflow name]
3. Click "Execute Workflow" or send test payload to webhook
4. Inspect node outputs in the execution log
```

**Common failure modes**:

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| | | |
| | | |

**Where to find logs**:
- n8n execution log: `https://n8n.helixstax.net/executions`
- Loki query: `{app="n8n"} |= "workflow-id"`

---

## Dependencies

<!-- Other workflows, services, or external APIs this depends on. -->

| Dependency | Type | Notes |
|------------|------|-------|
| | Workflow / Service / API | |

**Must run before this workflow**: <!-- Names or "None" -->

**Must run after this workflow**: <!-- Names or "None" -->

---

## Known Limitations [OPTIONAL]

Things this workflow does not handle. Edge cases it ignores.

- [Limitation]
- [Limitation]

---

## Version History [OPTIONAL]

| Version | Date | Change |
|---------|------|--------|
| 1.0 | YYYY-MM-DD | Initial version |
| 1.1 | YYYY-MM-DD | [Brief change description] |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC7.3 | Logging and monitoring of system events | Workflow trigger logging and error handling documented |
| SOC 2 | CC6.2 | Change management — documented workflow automation | Credentials, flow, and external modifications documented |
| NIST CSF | PR.IP-4 | Secure software development processes — documented automation | Flow description and credentials for audit trail |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Trigger type and frequency documented
- [ ] All external modifications (creates, updates, deletes) listed
- [ ] All credentials identified (no hardcoded secrets)
- [ ] Error handling clearly defined
- [ ] Debugging steps tested (manual execution works)
- [ ] Dependencies on other workflows listed
- [ ] Known limitations explicitly stated
- [ ] Workflow JSON file stored in repo alongside README
- [ ] Workflow tested in n8n UI before deployment

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
