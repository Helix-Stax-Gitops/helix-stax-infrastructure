---
template: sop
category: operational
task_type: sop
clickup_list: "06 Process Library"
auto_tags: ["sop", "procedure", "operations"]
required_fields: ["TLDR", "Purpose", "Scope", "Roles and Responsibilities", "Procedure", "Exception Process", "Verification"]
classification: internal
compliance_frameworks: ["ISO 27001", "SOC 2", "NIST CSF"]
review_cycle: annually
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Standard Operating Procedure (SOP)

Documenting a repeatable business or technical process with defined roles and verification checkpoints.
File in `docs/sops/{slug}.md`. Link from ClickUp: 06 Process Library > SOPs.

---

## TLDR

<!-- [REQUIRED] One sentence. What process does this SOP govern? -->

Example: This SOP governs the quarterly access review process for all Helix Stax production systems, ensuring compliance with SOC 2 CC6.2 and ISO 27001 A.9.2.5.

---

## Purpose

<!-- [REQUIRED] Why does this SOP exist? What business or compliance need does it address? -->

---

## Scope

<!-- [REQUIRED] Define boundaries explicitly. -->

**In scope**:
- <!-- What this SOP covers -->

**Out of scope**:
- <!-- What this SOP explicitly does NOT cover -->

---

## Roles and Responsibilities

<!-- [REQUIRED] RACI matrix for this process. -->

| Role | Responsible | Accountable | Consulted | Informed |
|------|:-----------:|:-----------:|:---------:|:--------:|
| <!-- Role 1 --> | | | | |
| <!-- Role 2 --> | | | | |
| <!-- Role 3 --> | | | | |

**Role definitions**:

| Role | Name / Position | Authority |
|------|----------------|-----------|
| Process Owner | <!-- Who owns this process --> | Approves exceptions, authorizes changes |
| Executor | <!-- Who performs the steps --> | Executes procedure, reports issues |
| Reviewer | <!-- Who verifies quality --> | Validates output, signs off |

---

## Prerequisites

<!-- [OPTIONAL] What must be in place before starting this procedure. -->

- [ ] <!-- Access, tools, approvals needed -->
- [ ] <!-- Dependencies that must be met -->

---

## Procedure

<!-- [REQUIRED] Phased steps with verification checkpoints after each phase.
     Each step should be actionable and specific. -->

### Phase 1: Preparation

1. <!-- First preparation step -->
2. <!-- Second preparation step -->

**Checkpoint**: <!-- How to verify Phase 1 is complete before proceeding -->

### Phase 2: Execution

3. <!-- First execution step -->
4. <!-- Second execution step -->
5. <!-- Continue as needed -->

**Checkpoint**: <!-- How to verify Phase 2 is complete before proceeding -->

### Phase 3: Review and Close

6. <!-- Review step -->
7. <!-- Documentation step -->
8. <!-- Close-out step -->

**Checkpoint**: <!-- How to verify the process is complete -->

---

## Exception Process

<!-- [REQUIRED] What happens when this SOP cannot be followed as written. -->

| Situation | Action | Approval Required From |
|-----------|--------|----------------------|
| Minor deviation (no compliance impact) | Document deviation, proceed | Process Owner |
| Major deviation (compliance impact) | Stop, document, request exception | Wakeem Williams |
| Emergency (cannot wait for approval) | Proceed, document within 24 hours | Wakeem Williams (retroactive) |

**Exception documentation**: Record all exceptions in ClickUp with tag `sop-exception` and link to the originating SOP.

---

## Verification Checklist

<!-- [REQUIRED] What must be true when this process completes successfully. -->

- [ ] All procedure steps completed in order
- [ ] All checkpoints passed
- [ ] Output artifacts produced and stored in correct location
- [ ] Records updated (see Records section below)
- [ ] <!-- Domain-specific verification -->

---

## Records

<!-- [REQUIRED] What evidence this process produces and where it is stored. -->

| Record | Format | Storage Location | Retention Period |
|--------|--------|-----------------|-----------------|
| <!-- Record 1 --> | <!-- Format --> | <!-- Location --> | <!-- Period --> |
| <!-- Record 2 --> | <!-- Format --> | <!-- Location --> | <!-- Period --> |

---

## Related Documents

<!-- [OPTIONAL] Links to related SOPs, runbooks, policies, or standards. -->

| Document | Relationship |
|----------|-------------|
| <!-- Document name --> | <!-- How it relates --> |

---

## Revision History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 | YYYY-MM-DD | | Initial version |

---

## Approval

<!-- [REQUIRED] Sign-off before this SOP becomes effective. -->

| Name | Role | Date | Signature |
|------|------|------|-----------|
| Wakeem Williams | Process Owner | | |
| <!-- Reviewer --> | Reviewer | | |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This SOP Satisfies It |
|-----------|-----------|-------------|---------------------------|
| ISO 27001 | Clause 7.5 | Documented information | Formalizes process into controlled, versioned document |
| SOC 2 | CC1.1 | Control environment | Defines roles, responsibilities, and accountability |
| NIST CSF | GV.PO | Policy and procedures | Documents operational procedures for governance |
| NIST CSF | PR.IP-1 | Baseline configuration management | Establishes repeatable, auditable process |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Procedure has been tested end-to-end at least once
- [ ] RACI matrix is complete with named individuals
- [ ] Approval signatures obtained
- [ ] Linked in ClickUp and accessible to all relevant roles

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Last Reviewed** | YYYY-MM-DD |
| **Classification** | Internal |
| **Version** | 1.0 |
