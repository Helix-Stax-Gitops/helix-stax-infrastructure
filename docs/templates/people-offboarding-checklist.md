---
template: people-offboarding-checklist
category: people
task_type: offboarding
clickup_list: 01 Business Operations > People Management
auto_tags: [offboarding, people, exit, client-close]
required_fields: [Departing Person Name, Departure Date, Access Revocation, Knowledge Transfer, Signoffs]
classification: internal
compliance_frameworks: [SOC2, ISO27001]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Offboarding Checklist (Team Member or Client)

Use this template when a team member leaves Helix Stax or when wrapping up a client engagement. File in ClickUp under 01 Platform > Business Operations > People Management or Delivery > [Client Name].

## TLDR

A comprehensive offboarding checklist ensuring departing team members or concluding client engagements are handled securely and professionally. Includes access revocation (critical for SOC 2 CC6.1), knowledge transfer, file cleanup, and account closure. Prevents security gaps and ensures institutional knowledge is preserved.

---

## Offboarding Details

| Field | Value |
|-------|-------|
| **Departing Person / Client Name** | [REQUIRED] |
| **Role & Title** | [REQUIRED] |
| **Departure Date** | [REQUIRED] |
| **Last Day of Work** | [REQUIRED] |
| **Reason for Departure** | [ ] Resignation  [ ] Termination  [ ] Retirement  [ ] Contract End  [ ] Client Engagement Complete |
| **Offboarding Lead** | [Who is responsible for this checklist] |
| **Type** | [ ] Internal Team Member  [ ] Contractor  [ ] Client Team Member  [ ] Vendor/Partner |

---

## Week Before Departure

**[REQUIRED]** Prepare for transition. Owner: Manager or engagement lead.

### Knowledge Transfer Planning

- [ ] Schedule knowledge transfer sessions (4–8 hours total depending on role)
  - [ ] List all critical systems/projects departing person owns
  - [ ] Identify internal person(s) who will take over responsibilities
  - [ ] Schedule: [Date 1], [Date 2], [Date 3] (spread over multiple days)
- [ ] Identify critical passwords/secrets that need to be handed off (never via email)
  - [ ] Use OpenBao or secure handoff process only
  - [ ] Who will inherit access?
- [ ] Create a knowledge transfer document (see Section 3 below)
  - Departing person fills in: "Here's what I do, here's the tribal knowledge"

### Project Handoff

- [ ] Document all ongoing projects, task lists, and in-progress work
  - [ ] File in ClickUp or wiki for continuity
  - [ ] Tag the new owner(s)
- [ ] Review upcoming deadlines and commitments
  - [ ] Ensure nothing falls through the cracks
  - [ ] Brief replacement on current state

### Communication Plan

- [ ] Schedule announcement in Rocket.Chat (if internal departure)
  - [ ] Thank-you message from departing person (optional)
  - [ ] Transition plan communicated to team
- [ ] If client engagement: Schedule final handoff call with client
  - [ ] Confirm deliverables are complete
  - [ ] Introduce new point of contact (if applicable)
  - [ ] Timeline for access/knowledge transfer with client team

---

## Two Business Days Before Departure

**[REQUIRED]** Begin access revocation and transition. Owner: IT/Ops lead.

### Data Backup & Export

- [ ] Export any personal files departing person may want
  - [ ] Google Drive files (personal projects, notes, etc.)
  - [ ] Email archives (if employee wants a copy)
  - [ ] ClickUp task history they created (if applicable)
  - [ ] Provide via secure link; never email
- [ ] Backup departing person's ClickUp tasks to institutional knowledge base
  - [ ] Archive or reassign incomplete tasks
  - [ ] Update task descriptions with context for next owner
- [ ] Any GitHub commits/PRs associated with departing person
  - [ ] Ensure all merged work is documented
  - [ ] Mark any open PRs as abandoned or transfer ownership

### Email & Communications Transition

- [ ] Create email forward: departing person's email → manager or successor
  - [ ] Configure auto-reply: "I have left Helix Stax. Contact [Manager Name] at [email] for assistance."
  - [ ] Keep forwarding active for [30–90 days] to catch late emails
- [ ] Add departing person's email to archival/backup (if using Google Workspace)
  - [ ] Ensure emails are not deleted

### Access Revocation (Most Critical)

**[REQUIRED]** Start revoking access gradually 2 days before departure. Don't cut all at once (departing person may need access for final handoff).

- [ ] **Keep for now** (revoke on last day):
  - ClickUp (to wrap up final tasks)
  - Git repository (if they have commits to finalize)
  - VPN or infrastructure access (may be needed for knowledge transfer)

- [ ] **Revoke now**:
  - [ ] Rocket.Chat (remove from all channels, deactivate account)
  - [ ] Grafana dashboards (remove access)
  - [ ] Any client-specific tools or credentials (Figma, Asana, AWS, etc.)
  - [ ] Credit cards or company payment methods
  - [ ] Physical access (badge, keycard) — if in-person office

---

## Last Day of Work

**[REQUIRED]** Complete all access revocation and final handoff. Owner: IT/Ops + manager.

### Morning: Final Knowledge Transfer

- [ ] Last sync-up meeting (30 min) with manager + successor
  - [ ] Any last-minute questions?
  - [ ] Confirm all critical handoffs are complete
  - [ ] Thank you and well-wishes
- [ ] Confirm successor has access to all necessary systems
  - [ ] Test access: Can they log in to critical systems?
  - [ ] Can they deploy, query, or perform their new duties?

### Afternoon: Full Access Revocation

**[CRITICAL]** Do all of this on last day to prevent unauthorized access after departure.

- [ ] **Immediate Revocation**:
  - [ ] Disable or delete email account (after final export + forwarding set up)
  - [ ] Remove from all Google Workspace groups
  - [ ] Remove from all ClickUp workspaces (export first!)
  - [ ] Revoke Kubernetes API access (remove RBAC role)
  - [ ] Revoke all cloud platform access (AWS, Hetzner, etc.)
  - [ ] Remove SSH keys from all servers
  - [ ] Remove from Rocket.Chat (deactivate account)
  - [ ] Remove from any third-party tools (GitHub, Figma, Notion, etc.)
  - [ ] Revoke VPN access and authentication credentials

- [ ] **Password & Secret Cleanup**:
  - [ ] Rotate any passwords known to departing person
    - [ ] OpenBao secrets
    - [ ] Database passwords
    - [ ] API keys
    - [ ] SSH keys
  - [ ] Audit for shared passwords (update any passwords departing person had access to)
  - [ ] Change Rocket.Chat bot tokens if departing person had access

- [ ] **Physical Access** (if applicable):
  - [ ] Collect badge/keycard
  - [ ] Collect laptop (wipe if personal device, preserve if company device)
  - [ ] Collect any company property (phone, hardware, etc.)

- [ ] **Confirm Revocation**: IT/Ops lead test that departing person no longer has access
  - [ ] Try to log in to ClickUp — should fail
  - [ ] Try to access VPN — should fail
  - [ ] Try to SSH to servers — should fail
  - [ ] **Verification Date & Time**: __________
  - [ ] **Verified By**: __________

### Exit Interview (if departing team member)

- [ ] HR/Manager conducts brief exit interview
  - [ ] What worked well?
  - [ ] What could improve?
  - [ ] Any feedback on company culture, tools, policies?
  - [ ] Stay in touch? (forward personal contact info if they're willing)

---

## Post-Departure (Ongoing)

**[REQUIRED]** Monitor and cleanup after departure.

### First Week After Departure

- [ ] Audit git commits — are there any uncommitted changes or stashed work?
  - [ ] If yes, commit or discard on behalf of departing person (with note: "Committed by [Manager] after [Name] departure")
- [ ] Audit ClickUp tasks — are all high-priority items assigned to successors?
  - [ ] Archive any personal/private tasks (1-on-1s with departed person, etc.)
- [ ] Audit Rocket.Chat message archives
  - [ ] Any customer-facing conversations that need to be escalated or documented?

### Monthly Audit (Months 1–3)

- [ ] Verify departing person still has no access to any systems
  - [ ] Spot-check ClickUp, GitHub, Rocket.Chat
- [ ] Monitor email forwarding — are emails still being received?
  - [ ] If forwarding is working, keep it on for full 90 days
- [ ] Ensure backups of their work (ClickUp, GitHub, wiki) are retained
  - [ ] Don't delete from archives yet

### At 90-Day Mark

- [ ] Stop email forwarding from departing person's account
- [ ] Archive (don't delete) email account and ClickUp task history
  - [ ] Retain for compliance/audit purposes for [7 years per SOC 2]
- [ ] Consider permanent deletion of:
  - [ ] VPN credentials
  - [ ] Temporary SSH keys
  - [ ] Temporary API tokens created during employment

---

## Client Engagement Completion (Variant)

**[Use this section if a client engagement is ending]**

### Final Delivery

- [ ] All deliverables complete and signed off by client
  - [ ] Architecture documentation
  - [ ] Runbooks and operational procedures
  - [ ] Training completed
  - [ ] Go-live completed (if applicable)
- [ ] Client team has been trained and is independent
  - [ ] Can operate the infrastructure without Helix Stax support
  - [ ] Has access to all necessary tools and documentation

### Knowledge Transfer to Client

- [ ] Schedule final handoff meeting with client technical team (2 hours)
  - [ ] Overview of what was built
  - [ ] How to operate it (runbooks, dashboards, escalation)
  - [ ] Support options for ongoing issues
- [ ] Provide client with:
  - [ ] All infrastructure code (Git repo access or export)
  - [ ] Complete runbooks and operations documentation
  - [ ] Contact info for ongoing support (if applicable)
  - [ ] List of accounts/credentials they now own
    - [ ] Kubernetes cluster
    - [ ] Database credentials
    - [ ] Identity provider (Zitadel) admin access
    - [ ] Monitoring (Grafana) admin access
    - [ ] Any other tools

### Access Revocation with Client

- [ ] Client confirms they have:
  - [ ] All infrastructure code and backups
  - [ ] All admin credentials rotated to client-only ownership
  - [ ] Runbooks and documentation downloaded/copied
  - [ ] Training completed for their team
- [ ] Helix Stax revokes access to client infrastructure:
  - [ ] Remove Kubernetes API access for Helix Stax engineers
  - [ ] Remove SSH keys from all servers
  - [ ] Remove database credentials from Helix Stax systems
  - [ ] Remove monitoring/dashboard access
  - [ ] Rotate any Helix Stax-owned secrets (e.g., CI/CD tokens)
- [ ] **Transition Confirmation**:
  - [ ] Client confirms they can access their own infrastructure without Helix Stax
  - [ ] Test: Client logs in and performs basic operation (e.g., deploy an app)
  - [ ] **Confirmation Date**: __________
  - [ ] **Confirmed By**: __________

### Final Billing & Contract Closure

- [ ] Final invoice sent to client
- [ ] All payment received and processed
- [ ] SOW marked as "complete" in ClickUp
- [ ] Client satisfaction survey (optional, 2-minute survey)
  - [ ] What did we do well?
  - [ ] What could improve?
  - [ ] Would you recommend Helix Stax?

---

## Documentation & Records

**[REQUIRED]** Preserve institutional knowledge.

- [ ] Create "Transition Summary" document (1 page) capturing:
  - [ ] Departing person's role and responsibilities
  - [ ] Who took over each responsibility
  - [ ] Key projects they owned (status at departure)
  - [ ] Lessons learned from their tenure
- [ ] File in team wiki or ClickUp for future reference
- [ ] Archive ClickUp tasks they created (don't delete; may be referenced later)
- [ ] If applicable: Store in Obsidian vault under `01_Internal/03_Team_Records/[Name]_offboarding`

---

## Compliance & Audit

**[REQUIRED]** Ensure offboarding is compliant and auditable.

### Access Revocation Audit

- [ ] Document all access revocations with timestamps
  - [ ] Who performed the revocation
  - [ ] What access was revoked
  - [ ] When (date/time)
  - [ ] Verified by whom
- [ ] File audit trail in [Compliance folder] for SOC 2 audit
  - Location: `C:\Wakeem\workspace\helix_stax\05_Compliance\access-revocation-log`

### Retention & Deletion

- [ ] Confirm email archives are backed up (retained for [7 years] per SOC 2 requirements)
- [ ] Confirm ClickUp task archives are exported (retain for compliance)
- [ ] Confirm git commit history is preserved (no force-pushes to delete work)
- [ ] Document any data deleted and justify deletions per data retention policy

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| SOC 2 | CC6.1 (Access Control) | Timely removal of access | Explicit revocation checklist on last day with verification |
| SOC 2 | CC6.2 (Privileged Access) | Revoke privileged access immediately | Separate "Immediate Revocation" section for critical systems |
| ISO 27001 | A.6.2.5 (Removal/Change) | Promptly remove access of departing users | Last-day revocation with audit trail |
| ISO 27001 | A.13.2.4 (Return of Assets) | Collect company property | Physical asset collection section |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Knowledge transfer completed and documented
- [ ] All access revoked (verified on last day)
- [ ] Email forwarding set up for 90 days
- [ ] Equipment/property collected
- [ ] Audit trail of access revocation documented
- [ ] Transition summary filed
- [ ] Exit interview completed (if applicable)
- [ ] Offboarding checklist marked complete in ClickUp
- [ ] Departing person's record archived for compliance

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
