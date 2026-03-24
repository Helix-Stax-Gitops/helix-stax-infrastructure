---
template: ops-meeting-notes
category: operational
task_type: meeting
clickup_list: 06 Process Library > Meeting Templates
auto_tags: [meeting-notes, communication, archive]
required_fields: [Attendees, Agenda, Decisions, Action Items, Next Steps]
classification: internal
compliance_frameworks: [SOC2, ISO27001]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Meeting Notes

Use this template to document any meeting — client calls, internal team sync, standup, project kickoff, or retrospective. File in ClickUp under the relevant project/client folder. Reference in related tasks/decisions.

## TLDR

Structured meeting notes that capture decisions, action items, and follow-up tasks. This template creates an auditable record of what was discussed, what was decided, and who is responsible for next steps. Notes are filed in ClickUp for compliance tracking and institutional memory.

---

## Meeting Info

| Field | Value |
|-------|-------|
| **Meeting Title** | [REQUIRED] |
| **Date & Time** | [REQUIRED] |
| **Duration** | [Minutes] |
| **Location/Zoom Link** | [REQUIRED] |
| **Facilitator** | [Who led the meeting] |
| **Scribe** | [Who took notes — usually not the facilitator] |

---

## Attendees

**[REQUIRED]** List all participants.

| Name | Organization | Role | Status |
|------|--------------|------|--------|
| [Name] | [Org] | [Title] | Present / Absent / Late arrival |
| [Name] | [Org] | [Title] | Present / Absent / Late arrival |

**Note**: Include organization if this is a multi-party meeting (Client + Helix Stax + vendors).

---

## Agenda

**[REQUIRED]** What was supposed to be discussed? List in order.

1. **[Topic 1]** — [Brief description] (15 min estimated)
2. **[Topic 2]** — [Brief description] (20 min estimated)
3. **[Topic 3]** — [Brief description] (10 min estimated)
4. **Open Discussion** — [Parking lot items if applicable]

**Planned vs Actual Time**: [Did you run over? Did you skip items? Note any deviations]

---

## Decisions Made

**[REQUIRED]** Every explicit decision goes here with rationale. This is the source of truth for "we decided to..."

| # | Decision | Rationale | Owner for Implementation |
|---|----------|-----------|-------------------------|
| **D-1** | [What was decided] | [Why — business context, constraints, options considered] | [Who is responsible for executing] |
| **D-2** | [e.g., "Proceed with Zitadel OIDC integration in Phase 3"] | [e.g., "Aligns with compliance roadmap; Client approved budget"] | [Name] |
| **D-3** | | | |

**Note**: If a decision was deferred, say so explicitly: "D-X: Deferred pending [dependency]"

---

## Action Items

**[REQUIRED]** Explicit next steps. Every action item needs an owner and due date.

| # | Action Item | Owner | Due Date | Priority | Status |
|---|-------------|-------|----------|----------|--------|
| **A-1** | [What needs to happen] | [Name] | [DATE] | P1 / P2 / P3 / P4 | Open |
| **A-2** | [e.g., "Schedule Phase 2 design review with Client stakeholders"] | [Name] | [DATE] | P1 | Open |
| **A-3** | [e.g., "Send Helix Stax resource list to Client HR by Friday"] | [Name] | [DATE] | P2 | Open |

**Follow-Up**:
- Owner confirms completion in ClickUp task comment
- If not completed by due date, escalate in next meeting

---

## Discussion Notes

**[OPTIONAL but RECOMMENDED]** Key points discussed under each agenda item. Use bullet points. Include:
- Problems identified
- Questions asked and answered
- Options discussed (even if not chosen)
- Concerns or blockers raised
- Commitments made

### [Agenda Item 1: Topic Name]

- **Background**: [Context for why this was discussed]
- **Problem**: [What issue was raised]
- **Options Discussed**:
  - Option A: [Description] — Pros: [X], Cons: [Y]
  - Option B: [Description] — Pros: [X], Cons: [Y]
- **Outcome**: [Which option was chosen and why]
- **Questions for Follow-Up**: [Anything left unanswered]

### [Agenda Item 2: Topic Name]

[Same structure as above]

---

## Risks & Blockers Identified

**[OPTIONAL]** Anything that could prevent forward progress? Escalate immediately if discovered in meeting.

| Risk/Blocker | Severity | Mitigation Plan | Owner | Target Resolution |
|--------------|----------|-----------------|-------|------------------|
| [e.g., "Client hasn't approved budget yet"] | P1 | [e.g., "Schedule finance decision call with CFO by Wed"] | [Name] | [DATE] |
| | | | | |

---

## Decisions Deferred

**[OPTIONAL]** If a decision was tabled, explain why and when it will be revisited.

| Decision | Why Deferred | When Revisited | Owner for Follow-Up |
|----------|-------------|-----------------|-------------------|
| [e.g., "Choose monitoring tool for Phase 2"] | [e.g., "Waiting for competitor pricing"] | [e.g., "Next standup on 3/29"] | [Name] |

---

## Parking Lot

**[OPTIONAL]** Ideas or concerns brought up but out of scope for this meeting. File as separate ClickUp tasks if they warrant follow-up.

- [e.g., "Discuss Prometheus vs Grafana licensing for multi-tenant setup"]
- [e.g., "Cost optimization for MinIO storage tier"]

---

## Next Meeting

**[REQUIRED]** When is the next touchpoint?

| Field | Value |
|-------|-------|
| **Next Meeting Title** | [e.g., "Phase 2 Design Review"] |
| **Suggested Date** | [DATE] |
| **Suggested Attendees** | [List] |
| **Pre-Work for Attendees** | [e.g., "Review architecture design doc"] |

---

## Summary for Stakeholders

**[OPTIONAL]** 1–2 paragraph executive summary to share with people who didn't attend. Post this in Rocket.Chat or email to relevant stakeholders.

Example:

"In today's Phase 1 kickoff call, we aligned on assessment scope and timeline. Key decisions: (1) Assessment will focus on NIST CSF compliance gaps, (2) We'll use CTGA framework for maturity scoring, (3) Client will provide infrastructure access by 3/26. Next step: Schedule design review workshop for 4/10. No blockers at this time."

---

## Attendee Feedback

**[OPTIONAL]** Did the meeting accomplish its goals? Use for continuous improvement.

| Attendee | Prepared? | Time Well Used? | Action Items Clear? | Any Feedback? |
|----------|-----------|-----------------|---------------------|---------------|
| [Name] | Yes / No | Yes / No | Yes / No | [Notes] |

---

## Reference Documents

**[OPTIONAL]** Link to any docs discussed or presented in the meeting.

- [Architecture Design Doc](link)
- [Current SOW](link)
- [CTGA Assessment Results](link)
- [Proposal Presentation](link)

---

## Follow-Up Communications

**[OPTIONAL]** After the meeting, what needs to be communicated to whom?

- [ ] Send meeting notes to [Attendee List] within 24 hours
- [ ] Post summary in Rocket.Chat #[channel]
- [ ] Update ClickUp tasks related to [Project/Client]
- [ ] Schedule follow-up calls: [Calls needed]

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| SOC 2 | CC3.2 (Communication) | Document decisions and escalations | Decisions + Blockers sections create audit trail |
| ISO 27001 | A.5.1 (Management responsibility) | Document management direction | Decisions section records leadership direction |
| NIST CSF | GV.RO-1 (Governance) | Document organizational decisions | Decisions + Action Items provide governance record |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Attendees list is complete (including remote/absent)
- [ ] Every decision has a rationale and owner
- [ ] Every action item has a due date and priority
- [ ] Notes are filed in ClickUp within 24 hours
- [ ] Decisions are communicated to relevant stakeholders
- [ ] Action item owners confirm receipt and understand responsibility

---

## Example: Filled Meeting Notes

### Meeting Info

| Field | Value |
|-------|-------|
| **Meeting Title** | TechStartup Inc. — Phase 1 Kickoff |
| **Date & Time** | 2026-03-22, 2:00 PM US Eastern |
| **Duration** | 60 minutes |
| **Location** | Zoom: [link] |
| **Facilitator** | Wakeem Williams (Helix Stax) |
| **Scribe** | Quinn Mercer (Helix Stax) |

### Attendees

| Name | Organization | Role | Status |
|------|--------------|------|--------|
| Wakeem Williams | Helix Stax | Engagement Lead | Present |
| Quinn Mercer | Helix Stax | Documentation | Present |
| Jane Smith | TechStartup Inc. | VP Infrastructure | Present |
| Bob Johnson | TechStartup Inc. | CTO | Present |
| Alice Chen | TechStartup Inc. | Security Lead | Late arrival (2:15 PM) |

### Decisions Made

| # | Decision | Rationale | Owner for Implementation |
|---|----------|-----------|-------------------------|
| **D-1** | Proceed with CTGA framework for current-state assessment | Aligns with TechStartup's SOC 2 audit timeline; gives quantifiable score | Wakeem Williams |
| **D-2** | Assessment scope: NIST CSF, SOC 2, ISO 27001 only (defer PCI DSS to Phase 2) | TechStartup's compliance roadmap prioritizes these; PCI scope not yet confirmed | Wakeem Williams |
| **D-3** | Infrastructure access via VPC peering + IAM role (not via VPN) | More secure; Helix Stax tools run in containers, no VPN client needed | Jane Smith (client) |

### Action Items

| # | Action Item | Owner | Due Date | Priority | Status |
|---|-------------|-------|----------|----------|--------|
| **A-1** | Provision Hetzner Cloud account + grant Helix Stax read-only access | Jane Smith | 2026-03-26 | P1 | Open |
| **A-2** | Schedule assessment kickoff call for 2026-03-29 | Quinn Mercer | 2026-03-23 | P1 | Open |
| **A-3** | Send Helix Stax resource requirements to TechStartup procurement | Wakeem Williams | 2026-03-24 | P2 | Open |

### Discussion Notes

#### Agenda Item 1: Engagement Scope & Timeline

- **Background**: TechStartup is preparing for SOC 2 Type II audit; current infrastructure is not audit-ready
- **Problem**: Manual compliance evidence collection is taking 40% of ops team's time
- **Options Discussed**:
  - Option A: Full infrastructure rewrite (greenfield K3s) — Best compliance posture but 13 weeks, $85K
  - Option B: Compliance wrapper on existing AWS — Faster, less disruptive, doesn't fix underlying architectural issues
- **Outcome**: Proceed with Option A (greenfield K3s). TechStartup's growth roadmap requires new infrastructure anyway; this is the right time.
- **Questions**: Will Helix Stax help with application migration? (Deferred — possible Phase 5 engagement)

#### Agenda Item 2: Infrastructure Access & Security

- **Background**: Helix Stax needs read/write access to infrastructure for build-out
- **Problem**: TechStartup's security policy is strict; need to balance access with least-privilege
- **Options Discussed**:
  - Option A: VPN access + local admin — Simpler, higher risk
  - Option B: VPC peering + Kubernetes API only — More secure, requires setup
  - Option C: AWS IAM role with read-only audit access — Auditable but limited for build-out
- **Outcome**: VPC peering + Kubernetes API (Option B). Alice Chen (Security) will review IAM policy by 3/26.

#### Agenda Item 3: Compliance Frameworks & Evidence

- TechStartup's audit timeline: Q3 2026 (5 months away)
- Helix Stax will implement evidence collection automation in Phase 3
- Quarterly control audits will be included in monthly managed service report

### Risks & Blockers Identified

| Risk/Blocker | Severity | Mitigation Plan | Owner | Target Resolution |
|--------------|----------|-----------------|-------|------------------|
| Hetzner Cloud account provisioning may take 2 business days | P2 | Request expedited setup; have backup account ready | Jane Smith | 2026-03-26 |
| TechStartup's legacy AWS infrastructure still running in production | P1 | Schedule separate engagement for migration planning (Phase 5) | Wakeem Williams | 2026-03-29 call |

### Next Meeting

| Field | Value |
|-------|-------|
| **Next Meeting Title** | Phase 1 Assessment Kickoff Call |
| **Suggested Date** | 2026-03-29, 10:00 AM US Eastern |
| **Suggested Attendees** | Wakeem, Quinn, Jane, Bob, Alice |
| **Pre-Work for Attendees** | TechStartup: Complete Hetzner Cloud setup; Helix Stax: Prepare assessment toolkit |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.0 |
