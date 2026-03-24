---
template: people-onboarding-checklist
category: people
task_type: onboarding
clickup_list: 01 Business Operations > People Management
auto_tags: [onboarding, people, new-hire, client-onboarding]
required_fields: [Onboardee Name, Start Date, Checklist Items, Signoffs]
classification: internal
compliance_frameworks: [SOC2, ISO27001]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Onboarding Checklist (Team Member or Client)

Use this template when onboarding a new Helix Stax team member, contractor, or client team member. File in ClickUp under 01 Platform > Business Operations > People Management or Delivery > [Client Name].

## TLDR

A comprehensive onboarding checklist ensuring new team members or client team members have everything they need to be productive and secure on Day 1. Includes access provisioning, security training, documentation review, and accountability sign-offs. Critical for SOC 2 compliance (CC6.1 access control).

---

## Onboarding Details

| Field | Value |
|-------|-------|
| **Onboardee Name** | [REQUIRED] |
| **Role & Title** | [REQUIRED] |
| **Start Date** | [REQUIRED] |
| **Report To** | [Manager/Contact] |
| **Onboarding Lead** | [Who is responsible for this checklist] |
| **Type** | [ ] Internal Team Member  [ ] Contractor  [ ] Client Team Member  [ ] Vendor/Partner |

---

## Pre-Onboarding (Before Day 1)

**[REQUIRED]** Prepare before the person starts. Owner: [Hiring manager or ops lead]

### IT & Access Provisioning

- [ ] Create email account and add to Google Workspace groups
- [ ] Create ClickUp account and assign to relevant workspaces/lists
- [ ] Create Rocket.Chat account and add to relevant channels
- [ ] Grant Kubernetes API access (if applicable) via [RBAC role or tool]
- [ ] Grant Grafana dashboard access (monitoring, dashboards only for non-ops staff)
- [ ] Grant git repository access (GitHub, read-only for most roles)
- [ ] Create [other tool] account (list all tools used)
- [ ] Schedule IT onboarding meeting for Day 1 (1 hour) to walk through tools and passwords

### Documentation & Training

- [ ] Send Onboarding Guide (see Section 2 below) — onboardee should skim before Day 1
- [ ] Schedule Day 1 welcome meeting with manager (30 min)
- [ ] Prepare workspace: desk, laptop, monitors, etc. (for in-person staff)
- [ ] Book [first week] meeting calendar:
  - [ ] Day 1: Welcome + IT setup (1 hour)
  - [ ] Day 1: Role-specific orientation (2 hours)
  - [ ] Day 2–3: Team introductions (30 min each with key people)
  - [ ] Day 4–5: Deeper dives on projects/clients

### Background & Screening

- [ ] Complete background check (if applicable per role)
- [ ] Verify references
- [ ] Collect signed NDA/confidentiality agreement
- [ ] File in Helix Stax HR system

---

## Day 1

**[REQUIRED]** First day checklist. Owner: Onboarding lead (usually manager or ops person)

### Morning: IT Setup & Welcome

- [ ] Onboardee arrives and receives workspace tour
- [ ] IT onboarding meeting (1 hour):
  - [ ] Walk through email, Google Workspace, ClickUp, Rocket.Chat
  - [ ] Share password manager / secure secrets access (OpenBao if applicable)
  - [ ] Confirm all accounts are working
  - [ ] Collect emergency contact info
- [ ] Welcome meeting with manager (30 min):
  - [ ] Role expectations and first-week priorities
  - [ ] Organizational structure overview
  - [ ] ClickUp workspace walkthrough (where they'll spend time)
- [ ] Team introduction: Welcome message posted in Rocket.Chat #introductions
  - Format: "Welcome [Name]! [Role] starting today. Background: [Brief bio]. Excited to work with you all!"

### Afternoon: Role-Specific Orientation

- [ ] **If Engineering**: System architecture walkthrough (K3s, Kubernetes, Zitadel, etc.)
- [ ] **If Operations**: SLA/runbook overview, incident response procedures, on-call rotation
- [ ] **If Client-Facing (Sales/Consulting)**: Client list, proposal templates, CRM/ClickUp structure
- [ ] **If People/HR**: Policies, benefits, payroll, compliance
- [ ] Schedule role-specific deep dives for Days 2–5

### End of Day

- [ ] Checkin: Does the onboardee have what they need? Any blockers?
- [ ] Tomorrow's agenda reviewed
- [ ] Encourage starting slow — this is information overload; they don't need to understand everything today

---

## Days 2–5: Deep Onboarding

**[REQUIRED]** Role-specific onboarding during the first week. Owner: Onboarding lead + role leads

### All Roles: Mandatory Training & Sign-Offs

#### Security & Compliance Training
- [ ] Complete Helix Stax Security Policy briefing (30 min)
  - Topics: Password hygiene, phishing, incident reporting, secrets handling
  - Location: [Link to training doc]
  - Sign-off: Onboardee confirms they read and understood
  - **Date Completed**: __________
- [ ] Complete SOC 2 compliance overview (30 min — all staff must know basics)
  - Topics: Access controls, incident reporting, audit evidence
  - Location: [Link to SOC 2 doc]
  - Sign-off: Onboardee confirms attendance
  - **Date Completed**: __________
- [ ] Review Confidentiality Agreement and NDA
  - Sign-off: Both parties sign
  - **Date Signed**: __________

#### Operational Policies
- [ ] Review Time Off, Expense Reimbursement, Code of Conduct policies
- [ ] Review ClickUp task standards (how we format tasks, what goes in descriptions)
- [ ] Review Rocket.Chat norms (channels, response times, escalation paths)
- [ ] Review incident response procedures (how to report security/critical issues)
  - **Date Completed**: __________

#### Product & Company Knowledge
- [ ] Tour of helixstax.com website (Company positioning, CTGA framework overview)
- [ ] Read [Company Mission/Values doc] (10 min)
- [ ] Watch or read intro to CTGA Framework (20 min)
- [ ] If Client-Facing: Read 2 recent proposals/SOWs to understand engagement model
- [ ] If Engineering: Read [Infrastructure Overview] (15 min)
  - **Date Completed**: __________

### Role-Specific Deep Dives

**[Pick the relevant section(s) below based on onboardee's role]**

#### Engineering/DevOps Roles

- [ ] Architecture walkthrough (K3s cluster, Zitadel, ArgoCD, etc.) — 2 hours
- [ ] Tour of infrastructure code (GitHub repo structure)
  - Git workflow (branches, PR process, commit standards)
  - Helm chart structure and values overrides
  - OpenTofu modules (if applicable)
- [ ] Deploy an application to the cluster (hands-on lab)
  - First deploy should be a simple, non-production workload
  - Pair with a senior engineer for this
- [ ] Access the monitoring stack (Prometheus, Grafana, Loki)
  - Tour of key dashboards
  - How to create custom dashboards
  - How to set up alerts
- [ ] Review the runbooks (copy in `docs/runbooks/`)
  - At least 3 critical runbooks
- [ ] Schedule: "Shadow" shift on-call engineer for 1 day (observe incident response without being on-call yet)
- [ ] **Clearance**: Senior engineer confirms new team member can deploy to non-production clusters safely
  - **Date Cleared**: __________
  - **Cleared By**: __________

#### Operations/SRE Roles

- [ ] Incident response procedures walk-through
  - On-call rotation and escalation paths
  - How to triage severity (SEV-1/2/3/4)
  - Post-incident review process
- [ ] SLA review (what are our service commitments?)
  - Run through example incident scenario
- [ ] Monitoring tour (Prometheus, Grafana, Loki, Alertmanager)
- [ ] Access a staging environment and trigger a test alert
  - Practice responding to alerts
  - Pair with another ops person
- [ ] Review service runbooks (top 10 common incidents)
- [ ] **Clearance**: Operations lead confirms new team member understands escalation procedures
  - **Date Cleared**: __________
  - **Cleared By**: __________

#### Sales/Client-Facing Roles

- [ ] Client management system (ClickUp workspace + Delivery folder structure)
  - How to create a new client engagement
  - Proposal templates and workflow
- [ ] Meet the existing clients (1 brief intro per major client)
  - Client background, engagement type, key contacts
- [ ] Shadow a proposal review meeting (listen, don't lead)
- [ ] Draft a sample proposal outline (non-client, internal exercise)
  - Review with manager
- [ ] Review post-engagement feedback from 2 recent clients
- [ ] **Clearance**: Sales/consulting lead reviews one practice proposal and provides feedback
  - **Date Cleared**: __________
  - **Cleared By**: __________

#### People/Operations/Support Roles

- [ ] ClickUp workspace and task management system
  - 01 Platform structure (all the "meta" tasks about the company)
  - Filtering, reporting, custom fields
- [ ] HR & benefits systems (payroll, benefits portal, time tracking)
- [ ] Email templates and communication norms
- [ ] Compliance program overview (Unified Control Matrix, evidence, audit process)
- [ ] **Clearance**: HR/Operations lead confirms new team member can manage day-to-day tasks
  - **Date Cleared**: __________
  - **Cleared By**: __________

---

## End of Week Checkin

**[REQUIRED]** By Friday EOD of Week 1

- [ ] Schedule 1-on-1 with manager (30 min)
  - How's the first week?
  - Any concerns or questions?
  - Clarify role expectations and first-month priorities
  - **Date of Checkin**: __________
- [ ] Solicit informal feedback from 2–3 colleagues who worked with onboardee this week
- [ ] Update the onboarding lead on progress
- [ ] If all checkpoints passed: Onboardee is "officially onboarded" and ready for independent work (with oversight appropriate to their role)

---

## Client Team Member Onboarding (Variant)

**[Use this section if onboarding a client's team member to use the Helix Stax infrastructure you've built for them]**

### Pre-Onboarding

- [ ] Client provides list of team members to be added + roles (admin, developer, viewer, etc.)
- [ ] Create Kubernetes RBAC roles matching client's org structure
- [ ] Create monitoring dashboard access (read-only for most roles)
- [ ] Create git repository access (if client team will contribute code)
- [ ] Prepare access credentials securely (via OpenBao or secure link, never email)

### Day 1: Client Team Onboarding Session

- [ ] Live walkthrough (2 hours, led by Helix Stax engineer):
  - [ ] Kubernetes dashboard + kubectl basics
  - [ ] How to deploy an application
  - [ ] How to check logs (kubectl logs, Loki)
  - [ ] How to view metrics (Grafana)
  - [ ] Runbooks: where they are and how to use them
- [ ] Each client team member attempts a simple, guided deployment
  - Deploying a test app to a dev namespace
  - Checking that it's running
  - Viewing its logs
  - Scaling it up/down

### Handoff

- [ ] Client team lead confirms:
  - [ ] All team members have access
  - [ ] All team members understand basic operations
  - [ ] Runbooks are clear
  - [ ] Support channel (email/Slack/Rocket.Chat) is clear
- [ ] Helix Stax provides 1 week of post-onboarding support (available for questions)
  - **Support End Date**: __________

---

## Post-Onboarding (30 Days)

**[REQUIRED]** Follow-up at 30-day mark to ensure long-term success.

- [ ] Schedule 1-on-1 with manager (30 min) — ask:
  - How's the role going?
  - Are there knowledge gaps or tools that need improvement?
  - What would help you succeed?
  - Any feedback on the onboarding process?
  - **Date of Checkin**: __________
- [ ] Review onboarding checklist for any gaps
  - Did the onboardee complete all required training?
  - Are there any compliance sign-offs missing?
- [ ] Update Helix Stax documentation if onboarding process revealed gaps
  - e.g., If onboardee struggled with runbook X, improve it
- [ ] Formally close out this onboarding checklist in ClickUp

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| SOC 2 | CC6.1 (Access Control) | Control user access; document provisioning | Prescriptive access provisioning checklist + sign-offs |
| SOC 2 | CC7.2 (System Monitoring) | Ensure staff can detect and respond to issues | Training on monitoring tools (Grafana, Loki, Prometheus) |
| ISO 27001 | A.6.2 (User Access Management) | Control access based on role | Role-based access provision (RBAC, read-only, admin) |
| ISO 27001 | A.7.3 (Confidentiality) | Train staff on confidentiality obligations | Mandatory confidentiality agreement sign-off |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Pre-onboarding checklist completed before Day 1
- [ ] All Day 1 activities completed
- [ ] All mandatory training completed and signed off
- [ ] Role-specific deep dives completed with clearance from role lead
- [ ] 30-day checkin completed
- [ ] Checklist filed in ClickUp and marked complete
- [ ] Any process improvements from feedback documented

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
