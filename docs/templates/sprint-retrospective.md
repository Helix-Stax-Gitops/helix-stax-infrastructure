---
template: sprint-retrospective
category: agile
task_type: sprint
clickup_list: "02 Platform Engineering"
auto_tags: ["sprint", "retrospective", "agile"]
required_fields: ["Sprint Overview", "What Went Well", "What Didn't Go Well", "Action Items"]
classification: internal
compliance_frameworks: ["NIST CSF"]
review_cycle: per-sprint
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Sprint Retrospective

Complete this retrospective at the end of each sprint.
Store in `docs/retrospectives/sprint-{number}-{start-date}.md`.
Use this to capture lessons learned and drive continuous improvement.

---

## TLDR [REQUIRED]

One sentence. Overall sprint health — did you hit goals, and what's the key lesson?

**Example**: Sprint 42 delivered 7/8 planned features; blocked by auth service outage mid-sprint. Next sprint: add chaos testing to prevent repeat incidents.

---

## Sprint Overview [REQUIRED]

| Field | Value |
|-------|-------|
| **Sprint Number** | [e.g., 42] |
| **Sprint Dates** | YYYY-MM-DD to YYYY-MM-DD |
| **Team Members** | [Names, comma-separated] |
| **Sprint Goal** | [Original goal statement] |
| **Goal Met?** | Yes / No / Partial |

---

## Planned vs Actual [REQUIRED]

| Metric | Planned | Actual | Variance |
|--------|---------|--------|----------|
| **Stories committed** | [Count] | [Count] | [+/- Count] |
| **Story points committed** | [Points] | [Points] | [+/- Points] |
| **Stories completed** | [Count] | [Count] | [+/- Count] |
| **Bugs fixed** | [Count] | [Count] | [+/- Count] |
| **Unplanned work** | 0 | [Count] | [+/- Count] |

**Burndown**:
```
Ideal:  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
Actual: ▄▄▄▄▄▄▄▄▄▄▄▄░░░░░░░░░

Day-by-day: [Paste burndown chart or link]
```

---

## What Went Well [REQUIRED]

What are you proud of this sprint? What should you keep doing?

- [Achievement or positive pattern]
- [Achievement or positive pattern]
- [Achievement or positive pattern]

**Why these were wins**:
[Explain the impact of these wins — speed, quality, morale, customer satisfaction, etc.]

---

## What Didn't Go Well [REQUIRED]

What slowed you down or frustrated the team? What should change?

| Issue | Impact | Category |
|-------|--------|----------|
| [Issue description] | [How it hurt: delay, rework, frustration] | [Process / Technical / External] |
| [Issue description] | [How it hurt] | [Process / Technical / External] |
| [Issue description] | [How it hurt] | [Process / Technical / External] |

**Root causes**:
- [Root cause analysis for each issue]

---

## Action Items [REQUIRED]

What specific changes will you make next sprint to improve?

| Action Item | Owner | Due Date | Category | Expected Outcome |
|-------------|-------|----------|----------|-----------------|
| [Specific action] | [Name] | [Sprint start +1 week or specific date] | [Process/Technical/Team] | [What improves] |
| [Specific action] | [Name] | [Sprint start +1 week or specific date] | [Process/Technical/Team] | [What improves] |
| [Specific action] | [Name] | [Sprint start +1 week or specific date] | [Process/Technical/Team] | [What improves] |

**Success criteria**: How will you know if these actions worked?
- [Measurable indicator]
- [Measurable indicator]

---

## Blockers / External Factors [OPTIONAL]

What external events or dependencies affected this sprint?

- [Blocker or external factor]
- [Blocker or external factor]

**Mitigation for next sprint**:
[How will you prevent or work around this next time?]

---

## Team Health [OPTIONAL]

How is the team doing?

| Dimension | Status | Notes |
|-----------|--------|-------|
| **Morale** | Good / Neutral / Low | [Brief comment] |
| **Velocity trend** | Up / Stable / Down | [If down, context] |
| **On-call burden** | Light / Normal / Heavy | [Any on-call incidents] |
| **Knowledge sharing** | Strong / Adequate / Weak | [Are team members learning from each other?] |
| **Process friction** | Low / Normal / High | [Tools, meetings, tooling issues] |

---

## Metrics [OPTIONAL]

| Metric | This Sprint | Last Sprint | Trend |
|--------|-------------|-------------|-------|
| **Velocity (story points)** | [Points] | [Points] | ↑ / → / ↓ |
| **Cycle time (avg days)** | [Days] | [Days] | ↑ / → / ↓ |
| **Defect escape rate** | [%] | [%] | ↑ / → / ↓ |
| **On-call incidents** | [Count] | [Count] | ↑ / → / ↓ |
| **Deployment frequency** | [Count] | [Count] | ↑ / → / ↓ |

---

## Lessons Learned [OPTIONAL]

What did this sprint teach you? Write things for future-you and the team to remember.

- [Lesson]
- [Lesson]
- [Lesson]

---

## Shout-Outs [OPTIONAL]

Celebrate wins and recognize teammates.

- **[Name]**: [Specific contribution — fixed blocker, mentored new team member, shipped feature, etc.]
- **[Name]**: [Specific contribution]

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| NIST CSF | PL.O-1 | Continuous improvement — systematic review and enhancement | Sprint retrospective drives process improvements and risk mitigation |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Planned vs Actual metrics completed
- [ ] At least 3 "What went well" and 2 "What didn't go well" documented
- [ ] Action items have specific owners and due dates
- [ ] Retrospective reviewed with team and approved
- [ ] Action items created in ClickUp with sprint tag and due date

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.0 |
