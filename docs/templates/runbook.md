---
template: runbook
category: operational
task_type: runbook
clickup_list: "06 Process Library"
auto_tags: ["runbook", "operations", "procedure"]
required_fields: ["TLDR", "When to Use", "Prerequisites", "Step-by-Step Procedure", "Rollback Procedure", "Verification Checklist"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF", "ISO 27001"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Runbook

Step-by-step guide for diagnosing and resolving a specific operational scenario.
File in `docs/runbooks/{slug}.md`. Link from ClickUp: 06 Process Library > Runbooks.

---

## TLDR

<!-- [REQUIRED] One sentence. What operational task does this runbook cover? -->

Example: Restore a CloudNativePG cluster from a Velero backup after a full database failure on the `heart` control plane node.

---

## When to Use This Runbook

<!-- [REQUIRED] Describe the trigger conditions. When should an operator reach for this runbook? -->

- [ ] Triggered by monitoring alert (specify which alert)
- [ ] Triggered by user-reported issue
- [ ] Scheduled maintenance task
- [ ] Disaster recovery scenario
- [ ] Other: _______________

---

## Prerequisites

<!-- [REQUIRED] Everything the operator needs before starting. -->

| Requirement | Detail |
|-------------|--------|
| **Access** | <!-- SSH keys, kubectl contexts, cloud console access --> |
| **Tools** | <!-- CLI tools that must be installed: kubectl, helm, opentofu, etc. --> |
| **Permissions** | <!-- RBAC roles, namespace access, Zitadel service accounts --> |
| **Knowledge** | <!-- Concepts the operator should understand before starting --> |
| **Dependencies** | <!-- Services that must be running, configs that must exist --> |

**Environment**:

| Field | Value |
|-------|-------|
| Cluster | `heart` (CP) / `helix-worker-1` |
| Namespace | <!-- Target namespace --> |
| Service(s) | <!-- Services this runbook operates on --> |

---

## Step-by-Step Procedure

<!-- [REQUIRED] Numbered steps with exact commands. One action per step.
     Include expected output or verification after critical steps.
     Use code blocks for all commands. -->

### Phase 1: Assessment

1. <!-- Describe what to check first -->

```bash
# Command here
```

**Expected output**: <!-- What the operator should see -->

2. <!-- Next assessment step -->

```bash
# Command here
```

### Phase 2: Execution

3. <!-- First action step -->

```bash
# Command here
```

**Expected output**: <!-- What the operator should see -->

4. <!-- Continue numbering sequentially -->

```bash
# Command here
```

### Phase 3: Verification

5. <!-- How to confirm the procedure worked -->

```bash
# Command here
```

**Expected output**: <!-- What success looks like -->

---

## Rollback Procedure

<!-- [REQUIRED] Exact steps to undo everything if the procedure fails or causes harm. -->

1. <!-- First rollback step -->

```bash
# Command here
```

2. <!-- Continue rollback steps -->

```bash
# Command here
```

**Rollback verification**:

```bash
# How to confirm rollback succeeded
```

---

## Verification Checklist

<!-- [REQUIRED] How to confirm the entire operation succeeded end-to-end. -->

- [ ] Service is healthy (pod status, readiness probes passing)
- [ ] Endpoints are reachable (ingress responding, TLS valid)
- [ ] Monitoring confirms normal metrics (Grafana dashboard, Loki logs)
- [ ] No error logs in the last 5 minutes
- [ ] Dependent services are unaffected
- [ ] <!-- Domain-specific verification -->

---

## Escalation Path

<!-- [OPTIONAL] Who to contact if this runbook does not resolve the issue. -->

| Severity | Escalation Target | Contact Method | SLA |
|----------|-------------------|----------------|-----|
| SEV-1 | <!-- Name/role --> | Rocket.Chat #incidents | Immediate |
| SEV-2 | <!-- Name/role --> | Rocket.Chat #incidents | 1 hour |
| SEV-3 | <!-- Name/role --> | Rocket.Chat #ops | 4 hours |

---

## Known Issues and Edge Cases

<!-- [OPTIONAL] Gotchas, known failure modes, and workarounds. -->

| Issue | Symptom | Workaround |
|-------|---------|------------|
| | | |

---

## Revision History

<!-- [OPTIONAL] Track changes to this runbook over time. -->

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 | YYYY-MM-DD | | Initial version |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Runbook Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC7.4 | Response to identified security incidents | Documents step-by-step incident response procedures |
| NIST CSF | PR.IP-9 | Response and recovery plans | Provides tested, repeatable operational procedures |
| ISO 27001 | A.12.1.1 | Documented operating procedures | Formalizes operational knowledge into auditable procedures |
| NIST CSF | RS.RP-1 | Response plan execution | Enables consistent execution of response procedures |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Procedure has been tested in a non-production environment
- [ ] Rollback procedure has been verified
- [ ] Reviewed by infrastructure engineer
- [ ] Linked from relevant service documentation

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
