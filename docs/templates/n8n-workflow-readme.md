# TEMPLATE: n8n Workflow README

One README per workflow. Store alongside the workflow JSON in the repo.
Path convention: `workflows/{slug}/README.md` and `workflows/{slug}/{workflow-name}.json`

---

## TLDR

<!-- One sentence. What this workflow does and when it runs. -->

Example: Sends a Telegram notification to Wakeem whenever a new GitHub issue is labeled `bug` and assigned to `helix-infra`.

---

## Trigger

| Field | Value |
|-------|-------|
| **Trigger type** | Webhook / Cron / Manual / Event |
| **Trigger detail** | <!-- URL path, cron expression, or event name --> |
| **Cron schedule** | `0 9 * * 1-5` (weekdays at 09:00 UTC) or N/A |
| **Webhook URL** | `https://n8n.helixstax.com/webhook/{path}` or N/A |
| **Expected frequency** | <!-- How often this fires in normal operation --> |

---

## Flow Description

<!-- Describe what the workflow does step by step.
     Write it like a sentence, not a node list.
     "When X happens, Y is fetched from Z, transformed into W, and sent to V." -->

---

## What It Creates / Modifies

<!-- List every external side effect. Be specific. -->

| System | Action | Detail |
|--------|--------|--------|
| <!-- Telegram --> | <!-- Sends message --> | <!-- To Wakeem's bot, #infra-alerts channel --> |
| <!-- GitHub --> | <!-- Creates comment --> | <!-- On the triggering issue --> |
| <!-- PostgreSQL --> | <!-- Inserts row --> | <!-- `audit_log` table, `helix` schema --> |

<!-- If the workflow is read-only, state: "Read-only. No external modifications." -->

---

## Credentials Required

<!-- List every credential by name as it appears in n8n.
     Do not paste the actual secret values here. -->

| Credential Name (in n8n) | Service | Notes |
|--------------------------|---------|-------|
| | | |
| | | |

**Where credentials are stored**: OpenBao / n8n credential store

**How to rotate**: <!-- Link to SOP or describe steps -->

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
1. Open n8n UI at https://n8n.helixstax.com
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
- n8n execution log: `https://n8n.helixstax.com/executions`
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

## Known Limitations

<!-- Things this workflow does not handle. Edge cases it ignores. -->

-
-

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | YYYY-MM-DD | Initial version |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
