---
template: change-request
category: operational
task_type: change
clickup_list: "04 Service Management"
auto_tags: ["change-request", "itil", "operations"]
required_fields: ["TLDR", "Change Classification", "Description", "Risk Assessment", "Implementation Plan", "Rollback Plan"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "ITIL 4"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Change Request

ITIL 4-aligned change request for any planned modification to production systems, configurations, or infrastructure.
File in `docs/changes/CR-YYYY-NNN-{slug}.md`. Link from ClickUp: 04 Service Management > Changes.

---

## TLDR

<!-- [REQUIRED] One sentence. What is changing, and why. -->

Example: Upgrade Traefik from v2.10 to v3.0 to enable HTTP/3 support and resolve CVE-2026-12345 on the `heart` control plane ingress.

---

## Change Classification

<!-- [REQUIRED] Select the change type per ITIL 4 Change Enablement. -->

| Field | Value |
|-------|-------|
| **Change ID** | CR-YYYY-NNN |
| **Change Type** | <!-- Standard (pre-approved, low risk) / Normal (requires CAB review) / Emergency (bypasses normal approval, documented retroactively) --> |
| **Priority** | <!-- P1 (Critical) / P2 (High) / P3 (Normal) / P4 (Low) --> |
| **Requested By** | <!-- Name --> |
| **Request Date** | YYYY-MM-DD |
| **Target Implementation Date** | YYYY-MM-DD |
| **Maintenance Window** | <!-- Day, time range in UTC --> |

---

## Description

<!-- [REQUIRED] Clearly describe what is changing. -->

### Before State

<!-- What the system looks like today. Include versions, configs, topology. -->

### After State

<!-- What the system will look like after the change. Be specific. -->

### What Changes

<!-- Summarize the delta between before and after. -->

| Component | Current | Proposed |
|-----------|---------|----------|
| <!-- Component --> | <!-- Current version/config --> | <!-- New version/config --> |

---

## Justification

<!-- [REQUIRED] Why is this change needed? Link to business need, security advisory, or compliance requirement. -->

---

## Risk Assessment

<!-- [REQUIRED] Identify risks and mitigations. -->

| Risk | Likelihood | Impact | Mitigation |
|------|:----------:|:------:|------------|
| <!-- Risk 1 --> | Low / Medium / High | Low / Medium / High | <!-- How to reduce this risk --> |
| <!-- Risk 2 --> | | | |
| <!-- Risk 3 --> | | | |

**Overall risk level**: <!-- Low / Medium / High / Critical -->

---

## Affected Services

<!-- [REQUIRED] Every service impacted by this change, including downstream dependencies. -->

| Service | Namespace | Cluster | Impact | Downtime Expected |
|---------|-----------|---------|--------|:-----------------:|
| <!-- Service --> | <!-- Namespace --> | `heart` / `helix-worker-1` | <!-- Description --> | Yes / No |

---

## Testing Results

<!-- [REQUIRED] What was tested and how before requesting this production change. -->

| Test | Environment | Result | Evidence |
|------|-------------|--------|----------|
| <!-- Test description --> | <!-- vCluster / Dev / Local --> | Pass / Fail | <!-- Link to logs, screenshots --> |

---

## Implementation Plan

<!-- [REQUIRED] Step-by-step plan with time estimates. -->

| Step | Action | Estimated Duration | Responsible |
|------|--------|--------------------|-------------|
| 1 | <!-- Pre-change backup --> | | |
| 2 | <!-- Execute change --> | | |
| 3 | <!-- Verify change --> | | |
| 4 | <!-- Monitor for issues --> | | |
| 5 | <!-- Close change --> | | |

**Total estimated duration**: ___ minutes/hours

**Pre-implementation checklist**:
- [ ] Backup taken and verified
- [ ] Rollback procedure reviewed
- [ ] Stakeholders notified
- [ ] Monitoring dashboards open

---

## Rollback Plan

<!-- [REQUIRED] Exact steps to undo the change. Include commands. -->

**Rollback trigger**: <!-- Under what conditions should rollback be initiated? -->

**Rollback deadline**: <!-- After what point is rollback no longer possible? -->

1. <!-- Rollback step 1 -->

```bash
# Command here
```

2. <!-- Rollback step 2 -->

```bash
# Command here
```

**Rollback verification**:

```bash
# How to confirm rollback succeeded
```

---

## Communication Plan

<!-- [OPTIONAL] Who needs to be informed before, during, and after. -->

| When | Who | Channel | Message |
|------|-----|---------|---------|
| Before | <!-- Stakeholders --> | Rocket.Chat #ops | Change window starting |
| During | <!-- Ops team --> | Rocket.Chat #incidents | Status updates |
| After | <!-- Stakeholders --> | Rocket.Chat #ops | Change complete / rolled back |

---

## CAB Approval

<!-- [REQUIRED for Normal and Emergency changes] -->

| Field | Value |
|-------|-------|
| **Approver** | <!-- Name and role --> |
| **Decision** | <!-- Approved / Rejected / Deferred --> |
| **Date** | YYYY-MM-DD |
| **Conditions** | <!-- Any conditions attached to approval --> |

**Emergency change justification** (if applicable):
<!-- Why this change cannot wait for normal CAB review. Emergency changes require retroactive documentation within 24 hours. -->

---

## Post-Implementation Review

<!-- [OPTIONAL] Complete after the change is deployed. -->

| Field | Value |
|-------|-------|
| **Actual implementation date** | YYYY-MM-DD |
| **Actual duration** | ___ minutes/hours |
| **Outcome** | Success / Partial / Rolled back |
| **Issues encountered** | <!-- Any unexpected problems --> |
| **Lessons learned** | <!-- What to do differently next time --> |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC8.1 | Change management | Records change details, risk assessment, rollback, and approvals |
| ISO 27001 | A.12.1.2 | Change management | Provides structured change request with CAB approval |
| NIST CSF | PR.IP-3 | Configuration change control | Documents before/after state and rollback procedures |
| ITIL 4 | Change Enablement | Manage change lifecycle | Follows standard/normal/emergency classification with CAB review |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Risk assessment completed with mitigations
- [ ] Testing completed in non-production environment
- [ ] Rollback plan includes specific commands
- [ ] CAB approval obtained (Normal/Emergency) or pre-approved (Standard)
- [ ] Post-implementation review completed within 24 hours

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
