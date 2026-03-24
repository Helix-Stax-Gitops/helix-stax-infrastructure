---
template: compliance-gap-analysis
category: compliance
task_type: gap-analysis
clickup_list: "05 Compliance Program"
auto_tags: ["compliance", "gap-analysis", "poam"]
required_fields: ["TLDR", "Assessment Metadata", "Gap Summary", "Detailed Gap Analysis", "Remediation Plan", "Master Timeline"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Compliance Gap Analysis and POA&M

Use for documenting gaps between current state and compliance requirements, plus the Plan of Action & Milestones (POA&M) to remediate. File as `docs/compliance/gap-analysis/{framework-name}-gap-analysis-{YYYY-MM-DD}.md`.

---

## TLDR

<!-- One sentence: framework, assessment date, number of gaps, overall remediation timeline. -->

Example: SOC 2 Type II gap analysis as of 2026-03-22. 12 gaps identified across 5 controls. Estimated remediation: 16 weeks. High-priority items due by Q2 2026.

---

## Assessment Metadata

### [REQUIRED] Assessment Information

| Field | Value |
|-------|-------|
| **Framework** | SOC 2 / ISO 27001 / NIST CSF / NIST 800-171 / PCI DSS / HIPAA / GDPR |
| **Assessment Date** | YYYY-MM-DD |
| **Assessment Scope** | All systems / Specific scope: __________ |
| **Assessed By** | |
| **Reviewed By** | |
| **Target Compliance Date** | YYYY-MM-DD |

### [REQUIRED] Assessment Context

**Why this assessment?**
- [ ] Preparation for audit/certification
- [ ] Post-incident remediation
- [ ] New framework adoption
- [ ] Annual compliance review
- [ ] Client requirement

**Previous assessment date**: __________ (if applicable)
**Previous gap count**: ____ (if applicable)

---

## Gap Summary

### [REQUIRED] Gap Overview

| Control/Domain | Total Controls | Gaps Identified | High Priority | Remediation Timeline |
|----------------|--------|-----------------|----------------|----------------------|
| [Control domain 1] | | | | |
| [Control domain 2] | | | | |
| **TOTAL** | | | | |

**Critical gaps (must remediate before audit/go-live)**:
1. _________
2. _________
3. _________

---

## Detailed Gap Analysis

### [REQUIRED] Gap Template (repeat for each gap)

#### Gap #1

**Control ID**: [SOC 2 / ISO / NIST / etc. control identifier]

**Control Title**: [Full name of control]

**Requirement**: [What the control requires]

**Current State**: [What you have now — detailed description]

**Desired State**: [What you need to have]

**Gap Description**: [Difference between current and desired. Be specific.]

**Root Cause**: Why does this gap exist?
- [ ] Lack of tooling
- [ ] Lack of process/procedure
- [ ] Lack of trained personnel
- [ ] Architectural limitation
- [ ] Resource constraint
- [ ] Other: __________

**Compliance Impact**:
- **Severity**: P1 (Critical audit finding) / P2 (Major finding) / P3 (Minor finding) / P4 (Observation)
- **Frameworks affected**: [Which frameworks require this control]
- **Audit show-stopper**: Yes / No

**Evidence of Gap**: [How was this gap discovered? Audit findings, testing results, documentation review, etc.]

---

## Remediation Plan (POA&M)

### [REQUIRED] Remediation for Each Gap

For each identified gap, document the Plan of Action & Milestones (POA&M):

#### Remediation Plan for Gap #1

**Gap**: [Restate gap briefly]

**Remediation Approach**: [How will this gap be closed? Technical implementation, process change, documentation, training, etc.]

**Remediation Steps**:

1. **Phase 1** (Target: YYYY-MM-DD)
   - [ ] Step 1.1
   - [ ] Step 1.2
   - [ ] Step 1.3
   - **Responsible**: _________
   - **Resources needed**: _________

2. **Phase 2** (Target: YYYY-MM-DD)
   - [ ] Step 2.1
   - [ ] Step 2.2
   - **Responsible**: _________
   - **Resources needed**: _________

3. **Phase 3** (Target: YYYY-MM-DD)
   - [ ] Step 3.1 (Verification & testing)
   - [ ] Step 3.2 (Evidence collection)
   - **Responsible**: _________

**Total Estimated Effort**: ___ weeks / ___ person-weeks

**Dependencies**: [Other gaps that must be closed first / Other projects that must complete]

**Risk if not remediated**: [Impact on audit, timeline, security posture]

**Verification Method**: How will you verify the gap is closed?
- [ ] Manual audit / review
- [ ] Automated testing
- [ ] Tool configuration review
- [ ] Penetration test
- [ ] SOC 2 / ISO auditor confirmation

**Evidence to be collected**:
- [ ] Configuration screenshot
- [ ] Policy document
- [ ] Audit logs
- [ ] Test results
- [ ] Certification/report

---

## Master Remediation Timeline

### [REQUIRED] POA&M Summary Table

| Gap ID | Control | Priority | Owner | Target Date | Status | Evidence |
|--------|---------|----------|-------|-------------|--------|----------|
| | | P1/P2/P3 | | YYYY-MM-DD | Planned / In Progress / Complete | |
| | | | | | | |

**Color coding**:
- 🔴 Red: Overdue
- 🟠 Orange: Due within 2 weeks
- 🟡 Yellow: Due within 4 weeks
- 🟢 Green: On track

### [OPTIONAL] Critical Path

**Sequence of remediation** (showing dependencies):

```
Week 1-2: [Gap #1 - foundational requirement]
    ↓
Week 3-4: [Gap #2, Gap #3 - build on Gap #1]
    ↓
Week 5-6: [Gap #4 - Integration]
    ↓
Week 7-8: [Testing & verification for all]
```

---

## Resource & Budget Planning

### [REQUIRED] Resource Allocation

| Resource | Allocation | Cost | Funding Source |
|----------|-----------|------|-----------------|
| **Personnel** | ___ person-weeks | $_____ | |
| **Tools/Software** | [tool list] | $_____ | |
| **Consulting/services** | [if needed] | $_____ | |
| **Training** | [if needed] | $_____ | |
| **TOTAL** | | $_____ | |

**Budget approved**: [ ] Yes [ ] No (awaiting approval)
**Approval date**: ___________

---

## Risk Assessment

### [REQUIRED] Remediation Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Remediation takes longer than planned | Medium | Audit delay | Add buffer to timeline, assign additional resources |
| New finding discovered during remediation | Low | Scope creep | Regular risk reviews, communication with auditor |
| Remediation tool fails / unavailable | Low | Alternative approach needed | Identify backup tools, alternative processes |
| Resource/personnel turnover | Medium | Delay | Document procedures, cross-train |

---

## Compliance Mapping

### [REQUIRED] Framework-Specific View

**For SOC 2 Type II** (if applicable):

| Trust Service Criterion | Gap Count | Remediation Owner | Target Date |
|------------------------|-----------|-------------------|-------------|
| C1 | | | |
| C3.1 | | | |
| CC5.1-5.2 | | | |
| CC6.1-6.2 | | | |
| CC7.1-7.2 | | | |

**For ISO 27001** (if applicable):

| Annex A Section | Gap Count | Remediation Owner | Target Date |
|-----------------|-----------|-------------------|-------------|
| A.5 (Organizational controls) | | | |
| A.6 (People controls) | | | |
| A.8 (Access control) | | | |
| A.12 (Operations) | | | |

---

## Monitoring & Verification

### [REQUIRED] Progress Tracking

**POA&M will be monitored via:**

- [ ] **Weekly status meetings** (Security/Compliance team)
- [ ] **ClickUp task tracking** (each remediation action is a task with owner + due date)
- [ ] **Monthly executive summary** (to leadership)
- [ ] **Quarterly auditor sync** (if preparation for external audit)

### [REQUIRED] Completion Criteria

**A gap is considered "closed" only when:**

1. [ ] Remediation action is 100% complete
2. [ ] Evidence has been collected and stored in `docs/compliance/evidence/`
3. [ ] Evidence has been independently verified (auditor, peer review, or tool validation)
4. [ ] Gap remediation task marked "Done" in ClickUp
5. [ ] Results communicated to audit/compliance lead

---

## Post-Remediation Validation

### [OPTIONAL] Audit Preparation

**Once remediation is complete:**

- [ ] Prepare evidence packet for auditor review
- [ ] Schedule pre-audit walkthrough with auditor
- [ ] Conduct internal mock audit using same scope/procedures
- [ ] Address any issues found before formal audit

---

## Escalation & Communication

### [REQUIRED] Stakeholder Communication

| Stakeholder | Communication Frequency | Responsible |
|-----------|--------------------------|-------------|
| **Security Lead** | Weekly | |
| **Executive Sponsor** | Monthly | |
| **Audit Committee** | Quarterly | |
| **External Auditor** | Per audit schedule | |

**Current POA&M status** (as of today):

- **On Track**: ____ gaps (remediation progressing as planned)
- **At Risk**: ____ gaps (timeline or scope concerns)
- **Overdue**: ____ gaps (requires immediate attention)

**Escalation triggers**:
- If any gap becomes 4+ weeks overdue → Escalate to executive sponsor
- If 3+ gaps at risk → Schedule remediation review meeting

---

## Lessons Learned & Prevention

### [OPTIONAL] Root Cause Prevention

**To prevent these gaps from recurring:**

- [ ] Process improvement: [describe]
- [ ] Architecture change: [describe]
- [ ] Tooling enhancement: [describe]
- [ ] Training/awareness: [describe]

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Status** | Draft / In Review / Approved |
| **Classification** | Confidential |
