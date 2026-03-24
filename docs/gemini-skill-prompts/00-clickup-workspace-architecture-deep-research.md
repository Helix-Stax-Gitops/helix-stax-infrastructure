# Gemini Deep Research: ClickUp Workspace Architecture for IT Consulting + Autonomous AI Agents

## Your Role
You are a **Senior IT Project Management Consultant** specializing in ClickUp workspace design for technology companies. You have 15+ years of experience designing project management systems for IT consulting firms, MSPs, and DevOps teams. You understand ITIL, Agile/Scrum, compliance frameworks (SOC 2, NIST, ISO 27001), and how AI agents interact with project management tools.

Your job is to design the DEFINITIVE ClickUp workspace architecture for Helix Stax — not generic best practices, but a specific, opinionated, ready-to-implement blueprint. You are the authority. Tell me exactly how to structure everything. No "it depends" — make the decisions.

Think like a PM who has set up ClickUp for 50 consulting firms and knows exactly what works and what fails. Design for:
- A 1-person team scaling to 5-10 people
- 23 AI agents that create/update tasks programmatically via API and MCP
- Multi-client delivery with guest access
- SOC 2 / HIPAA compliance requirements
- Integration with n8n, Rocket.Chat, GitHub, Grafana, and a full K3s infrastructure stack

## Who I Am
I run Helix Stax, a small IT consulting company with 2 active clients. I have 23 AI agents (Claude Code + Gemini CLI) that create, update, and manage ClickUp tasks automatically. I need a COMPLETE ClickUp workspace architecture — spaces, folders, lists, statuses, tags, custom fields, automations, views, dashboards, documents, and governance. This is a full overhaul.

## What ClickUp Is
ClickUp is our central nervous system — every task, every client engagement, every compliance control, every sprint, every infrastructure build, and every agent action is tracked here. It replaces Jira, Asana, Notion, and Monday in a single tool.

ClickUp hierarchy: Workspace → Spaces → Folders → Lists → Tasks → Subtasks

## What This Document Becomes
This is NOT a research report. This is the **OFFICIAL Helix Stax ClickUp Standard Operating Guide**. Every team member, every agent, every client interaction follows this document. No exceptions. No improvisation. If it's not in this guide, it doesn't happen in ClickUp.

When someone joins the team, they read this. When an agent is spawned, it follows this. When a client asks "how do you track work?" — this is the answer.

The output must be clear enough that someone with ZERO ClickUp experience can follow it and set up the workspace correctly. Screenshots aren't possible, so use exact ClickUp menu paths (e.g., "Space Settings → Statuses → + Add Status").

## Current Workspace (ACTUAL hierarchy — design from this, not theory)

```
Workspace: Helix Stax (ID: 9017890239)
├── 01 Platform (Space ID: 90174819900) — Internal operations
│   ├── 01 Business Operations (Folder)
│   │   ├── Sales Pipeline
│   │   ├── Marketing & Content
│   │   ├── Finance & Billing
│   │   ├── HR & Onboarding
│   │   └── Legal & Contracts
│   ├── 02 Platform Engineering (Folder)
│   │   ├── Infrastructure Backlog (280+ tasks, 7-phase build plan)
│   │   ├── K3s Cluster Operations
│   │   ├── Service Deployments
│   │   ├── CI/CD Pipeline
│   │   ├── Database Operations
│   │   ├── Service Evaluation Queue
│   │   ├── Backup & DR
│   │   └── Monitoring & Alerting
│   ├── 03 Security Operations (Folder)
│   │   ├── Security Incidents
│   │   ├── Vulnerability Management
│   │   ├── Access Reviews
│   │   ├── Threat Intelligence
│   │   ├── WAF & Firewall Rules
│   │   ├── Certificate Management
│   │   ├── Identity & Auth (Zitadel)
│   │   └── Problems (Root Cause)
│   ├── 04 Service Management (Folder)
│   │   ├── Change Requests
│   │   ├── Service Requests
│   │   ├── Incidents & Problems
│   │   ├── Service Catalog
│   │   ├── Asset Management
│   │   └── Capacity Planning
│   ├── 05 Compliance Program (Folder)
│   │   ├── Unified Control Matrix (80 controls, 12 custom fields)
│   │   ├── Evidence Collection
│   │   ├── Policy Management
│   │   ├── Risk Register
│   │   ├── Audit Tracker
│   │   ├── Vendor Assessments
│   │   ├── Gap Analysis & POA&M
│   │   ├── Compliance Reports
│   │   ├── Data Governance
│   │   ├── IT Governance
│   │   ├── AI Agent Governance
│   │   └── Training & Certifications
│   ├── 06 Process Library (Folder)
│   │   ├── Runbooks
│   │   ├── Templates
│   │   ├── Automation Recipes
│   │   └── SOPs
│   └── 07 Product & Strategy (Folder)
│       ├── Product Roadmap
│       ├── Research & Spikes
│       ├── Architecture Decisions (ADRs)
│       ├── Website (helixstax.com)
│       ├── Brand Kit
│       └── Client-Facing Products
└── 02 Delivery (Space ID: 90174819904) — Client work
    ├── 00 Delivery Operations (internal)
    └── {Per-client folders with guest access}
```

Tags: 68 total (51 Platform, 17 Delivery) — INCONSISTENT formats (mix of `domain:k3s` and plain `security`)
Custom Fields: 20 across 5 lists — mostly on UCM
Status Workflows: DEFAULT ONLY — never configured custom statuses
Automations: ZERO configured
Views: ZERO configured beyond default
Dashboards: ZERO
Forms: ZERO
Sprints: NOT configured
Goals: NOT configured

## What Has Gone Wrong (design AGAINST these failures)

1. **PM agent (Sable) creates bare tasks** — no tags, no dates, no assignees, no dependencies. Just a name and description. This happened 80+ times in one session.
2. **208 tasks sat in default "to do" status** for days with no one updating them.
3. **Tags are inconsistent** — some use `domain:k3s` format, others use plain `security`. No standard enforced.
4. **No one tracks reviews** — code reviews, security reviews, architecture reviews happen but aren't recorded as tasks or subtasks.
5. **No sprint structure** — work just piles up in backlogs with no cadence.
6. **No project lifecycle tracking** — can't answer "where is this project in the pipeline?" without manually checking.
7. **No dependency chains** — tasks that block each other aren't linked.
8. **ClickUp Docs unused** — all documentation lives outside ClickUp.
9. **No client visibility** — clients can't see their engagement status.
10. **No dashboards** — no way to get a quick health check without reading every task.

## Day in the Life (design the workspace to support THIS workflow)

**Morning (Wakeem checks in):**
- Open ClickUp → see what's blocked, what's overdue, sprint burndown
- Pull up client dashboard → any SLA breaches? Deliverables due today?
- Check agent activity → what did agents do overnight? Any failed tasks?
- Sprint standup view → what's in progress, what needs attention

**During work (agents running):**
- Agents create tasks with FULL metadata (tags, dates, assignees, dependencies)
- PR merged → ClickUp task auto-updates to "In Review"
- Deployment succeeds → ClickUp task auto-closes + Rocket.Chat notification
- Security scan finds vuln → ClickUp incident auto-created with severity
- Agent gets blocked → ClickUp task marked "Blocked" + alert

**Client meeting (30-second prep):**
- Pull up client's delivery folder → see all active tasks, timeline, SLA status
- Show client what was delivered this sprint
- Show upcoming work for next sprint
- Client submits new request via ClickUp form → auto-triaged

**End of day:**
- Sprint burndown → are we on track?
- What shipped today? (completed tasks view)
- What's carrying over? (overdue tasks view)
- Agent performance → tasks created vs completed, average time

**Weekly:**
- Sprint review → auto-generated report from ClickUp data
- Backlog grooming → prioritize next sprint
- Compliance check → any evidence collection due?
- Stale task detection → anything untouched for 7+ days?

## Competitor Research
Research how these types of companies structure ClickUp and what templates exist:
- IT consulting firms / MSPs (managed service providers)
- DevOps / SRE teams
- Compliance-focused organizations (SOC 2, HIPAA)
- Companies using AI agents with ClickUp
- ClickUp's own official templates for IT and consulting
- Any ClickUp community templates for ITIL service management

## Project Lifecycle Tracking (CRITICAL)
Design the COMPLETE lifecycle of how work moves through ClickUp from intake to completion. Cover EVERY type of work:

### Internal Project Lifecycle
```
Idea → Research → Architecture → Approved → Sprint Backlog → In Progress → In Review → Testing → Deployed → Verified → Done
```

### Client Engagement Lifecycle
```
Lead → Qualified → Proposal Sent → SOW Signed → Onboarding → Discovery → Assessment → Remediation → Verification → Ongoing Support → Renewal/Closure
```

### Infrastructure Build Lifecycle
```
Planned → Researching → Designed → Approved → Building → Testing → Deployed → Monitoring → Operational
```

### Incident Lifecycle (ITIL)
```
Detected → Triaged → Investigating → Identified → Mitigating → Resolved → Post-Mortem → Closed
```

### Compliance Control Lifecycle
```
Not Started → Evidence Gathering → Implementing → Operational → Audit Ready → Audited → Compliant / Non-Compliant → Remediation
```

### Bug Lifecycle
```
Reported → Confirmed → Assigned → In Progress → Fix In Review → Resolved → Verified → Closed
```

For EACH lifecycle, define:
- Which ClickUp list it lives in
- Which statuses map to each stage
- What triggers the transition (manual? automation? agent?)
- What metadata is required at each stage (tags, fields, assignees)
- What notifications fire at each transition
- What blocks progression (missing fields? approval needed?)
- How to track WHERE a project is at any moment

## ClickUp Deep Features to Evaluate and Design For

Research and recommend whether to use EACH of these ClickUp features:

| Feature | Use? | How? |
|---------|------|------|
| **Relationships** (task links) | ? | Link related tasks across lists/spaces |
| **Roll-ups** | ? | Aggregate subtask data to parent tasks |
| **Portfolios** | ? | Group projects for executive view |
| **Gantt Charts** | ? | Visualize project timelines and dependencies |
| **Mind Maps** | ? | Brainstorming and planning |
| **Sprints** (native) | ? | Sprint planning with velocity tracking |
| **Goals** (native) | ? | OKR tracking linked to tasks |
| **Milestones** | ? | Key delivery dates |
| **Time Estimates** | ? | Per-task time budgeting |
| **Custom Task Types** | ? | Different task types for bugs, features, incidents, controls |
| **Conditional Logic in Forms** | ? | Smart intake forms |
| **Doc relationships** | ? | Link docs to tasks |
| **Pulse** | ? | Who's online, who's working on what |
| **Workload view** | ? | Capacity management |
| **Box view** | ? | Sprint summary per person |
| **Activity view** | ? | Audit trail of all changes |
| **Everything view** | ? | Cross-space search |
| **Custom Automations with Webhooks** | ? | Deep integration with n8n |
| **ClickApps** | ? | Which ClickApps to enable (time tracking, sprints, custom fields, etc.) |

For each feature, say: YES (use it, here's how), NO (skip it, here's why), or LATER (not now, add when X happens).

## Task Types & Work Item Taxonomy (CRITICAL — standardize everything)

Define EVERY type of work item that can exist in ClickUp. A brand new team member should look at a task and INSTANTLY know what it is, what stage it's in, and what to do next.

### Work Item Types (use ClickUp Custom Task Types)
| Type | Icon | When to Use | Example | Default List |
|------|------|------------|---------|-------------|
| **Epic** | ? | Large multi-sprint initiative | "Deploy monitoring stack" | ? |
| **Feature** | ? | New capability to build | "Add OAuth to MCP Worker" | ? |
| **Bug** | ? | Something broken | "[BUG] Traefik 502 on websocket" | ? |
| **Incident** | ? | Production issue | "[INC-001] K3s API unreachable" | ? |
| **Change Request** | ? | Modify production system | "Upgrade PostgreSQL 16 → 17" | ? |
| **Service Request** | ? | Internal request | "Create new Harbor project" | ? |
| **Security Finding** | ? | Vulnerability or risk | "[SEC] Trivy CVE-2026-XXXX critical" | ? |
| **Compliance Control** | ? | UCM control | "UCM-AC-001 Enforce least-privilege" | ? |
| **Research/Spike** | ? | Investigation task | "Evaluate RuVector vs pgvector" | ? |
| **Documentation** | ? | Write/update docs | "Write Velero runbook" | ? |
| **Client Deliverable** | ? | Client-facing output | "CTGA Assessment Report for Acme" | ? |
| **Agent Task** | ? | Created by AI agent | Auto-generated by agent work | ? |

For each type, define:
- Which list it goes in
- Required fields (what MUST be filled in at creation)
- Default status workflow
- Default tags auto-applied
- Who gets notified
- SLA (if applicable — e.g., incidents must be triaged within 1 hour)

### Epic → Feature → Task → Subtask Hierarchy
Design the hierarchy for large initiatives:
```
Epic: "Deploy Full Monitoring Stack"
├── Feature: "Deploy Prometheus"
│   ├── Task: "Configure ServiceMonitors for all services"
│   │   ├── Subtask: "ServiceMonitor for Traefik"
│   │   ├── Subtask: "ServiceMonitor for CloudNativePG"
│   │   └── Subtask: "ServiceMonitor for Valkey"
│   ├── Task: "Configure alerting rules"
│   └── Task: "Create Grafana dashboards"
├── Feature: "Deploy Loki"
│   ├── Task: "Configure Promtail/Alloy"
│   └── Task: "Set up MinIO storage backend"
└── Feature: "Deploy Alertmanager"
    ├── Task: "Configure Rocket.Chat receiver"
    └── Task: "Configure Postal email receiver"
```

Define:
- When to create an Epic vs a Feature vs a Task
- How Epics track progress (% complete from child tasks?)
- Can agents create Epics? Or only Wakeem/PM?
- How to close an Epic (all children done? manual review?)
- Epic reporting — how to see all Epics and their health

### New Team Member Onboarding Flow
When someone brand new joins Helix Stax:
1. What do they see first in ClickUp?
2. How do they know what to work on?
3. How do they create their first task correctly?
4. How do they find existing work?
5. How do they understand the status workflow?
6. How do they know what tags to use?
7. What views should they have pinned?
8. What dashboards should they check daily?

Design a **"Getting Started"** ClickUp Doc that auto-shares with new members. Include:
- Workspace map (where everything lives)
- Status definitions (what each status means, when to transition)
- Tag glossary (every tag and when to use it)
- Task creation checklist (required fields)
- "My First Sprint" guide
- Who to ask for help

### Request & Intake Standardization
Define how EVERY type of request enters ClickUp:
| Request Type | Entry Point | Auto-actions |
|-------------|-------------|-------------|
| Client request | ClickUp Form → Delivery space | Auto-assign PM, auto-tag, set SLA timer |
| Bug report | ClickUp Form → Platform Engineering | Auto-tag `type:bug`, auto-assign triage |
| Incident | n8n webhook from Alertmanager | Auto-create with severity, auto-notify Rocket.Chat |
| Feature request | Manual task or ClickUp Form | Auto-tag `type:feature`, add to backlog |
| Change request | ClickUp Form → Service Management | Auto-create approval workflow |
| Security finding | n8n webhook from Trivy/CrowdSec | Auto-tag `type:security`, auto-escalate if critical |
| Agent-created task | MCP API call | MUST include: tags, assignee, priority, due date, parent task |
| Research task | Manual or agent | Auto-tag `type:research` |

## Naming Conventions (EXACT rules, no ambiguity)

Define the EXACT naming pattern for every element. A new team member should be able to name anything correctly without asking.

| Element | Pattern | Example | Anti-pattern (DON'T do this) |
|---------|---------|---------|------------------------------|
| Spaces | `NN Name` | `01 Platform` | `platform`, `Platform Space` |
| Folders | `NN Name` | `02 Platform Engineering` | `engineering`, `Eng` |
| Lists | Title Case | `Infrastructure Backlog` | `infra backlog`, `INFRA` |
| Epics | `[EPIC] Description` | `[EPIC] Deploy monitoring stack` | `monitoring`, `set up monitoring` |
| Features | `[FEAT] Service: Description` | `[FEAT] Grafana: Add client dashboard` | `add dashboard` |
| Bugs | `[BUG] Service: Description` | `[BUG] Traefik: 502 on WebSocket` | `traefik broken` |
| Incidents | `[INC-NNNN] Description` | `[INC-0001] K3s API unreachable` | `k3s down` |
| Change Requests | `[CR] Description` | `[CR] Upgrade PostgreSQL 16→17` | `upgrade pg` |
| Security | `[SEC] CVE/Description` | `[SEC] CVE-2026-XXXX Harbor critical` | `security issue` |
| UCM Controls | `UCM-XX-NNN Description` | `UCM-AC-001 Enforce least-privilege` | Keep as-is |
| Research | `[RESEARCH] Topic` | `[RESEARCH] Evaluate RuVector` | `look into ruvector` |
| Docs | `[DOC] Type: Subject` | `[DOC] Runbook: Velero backup restore` | `velero doc` |
| Client tasks | `[CLIENT] Client: Description` | `[CLIENT] Acme: CTGA assessment` | `acme stuff` |
| Agent tasks | `[AGENT] Agent: Description` | `[AGENT] Kit: Deploy Prometheus` | `deploy prometheus` |
| Tags | `category:value` kebab-case | `svc:traefik`, `type:bug` | `Traefik`, `BUG` |
| ClickUp Docs | `Title — Category` | `Velero Backup Restore — Runbook` | `velero` |

Define rules for:
- Maximum task name length
- When to use brackets `[TYPE]` vs not
- Subtask naming (inherits parent service? or standalone?)
- How agents should auto-generate names (what template?)

## Priority Definitions (SLA per priority level)

| Priority | Meaning | Response Time | Resolution Time | Example | Who Gets Notified |
|----------|---------|---------------|-----------------|---------|-------------------|
| **Urgent** | Production down, data at risk, security breach | 15 minutes | 4 hours | K3s cluster unreachable, credentials exposed | Wakeem immediately (Rocket.Chat + email + phone) |
| **High** | Major feature blocked, client SLA at risk, critical bug | 1 hour | 24 hours | Deployment pipeline broken, client deliverable overdue | Wakeem + relevant agent (Rocket.Chat) |
| **Normal** | Standard work, planned tasks, features, improvements | 4 hours | 1 sprint (1-2 weeks) | New feature, documentation update, research task | Task assignee only |
| **Low** | Nice-to-have, tech debt, future improvement, evaluation | Next sprint | No SLA | Evaluate a tool, refactor old code, cosmetic fix | No notification |

Define:
- What happens when SLA is about to breach? (automation: change color? notify?)
- Can agents set Urgent priority? Or only Wakeem?
- Auto-escalation: Normal → High after 7 days overdue?

## Definition of Done (per task type)

When is a task ACTUALLY complete? Not "I think it's done" — a concrete checklist.

### Feature / Task
- [ ] Code written and committed
- [ ] Tests pass (unit + integration)
- [ ] Security scan clean (no CRITICAL/HIGH)
- [ ] Code reviewed (PR approved)
- [ ] Deployed to target environment
- [ ] Verified working in target environment
- [ ] Documentation updated (if applicable)
- [ ] ClickUp task status → Done

### Bug
- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Regression test added
- [ ] Fix deployed
- [ ] Original reporter confirmed fix
- [ ] ClickUp task → Resolved

### Incident
- [ ] Service restored
- [ ] Root cause identified
- [ ] Post-mortem written
- [ ] Preventive action identified
- [ ] Preventive action task created
- [ ] ClickUp task → Post-Mortem Complete

### Compliance Control
- [ ] Control implemented
- [ ] Evidence collected
- [ ] Evidence stored in MinIO WORM
- [ ] Control tested/validated
- [ ] Auditor can verify
- [ ] ClickUp task → Compliant

### Client Deliverable
- [ ] Work completed
- [ ] Internal review passed
- [ ] Client-ready format (PDF/doc/dashboard)
- [ ] Delivered to client
- [ ] Client acknowledged receipt
- [ ] ClickUp task → Delivered

Design a ClickUp checklist template for each Definition of Done so it auto-attaches when a task of that type is created.

## Handoff Standards

When work moves between people or agents, the task MUST contain:

```
HANDOFF:
1. What was produced (files, configs, deployments)
2. Key decisions made (and why)
3. What's uncertain (ranked HIGH/MEDIUM/LOW)
4. What the next person needs to do
5. Blockers or dependencies
```

Define:
- Where does the handoff go? (task comment? task description update? subtask?)
- Is handoff required to change status? (e.g., can't move to "In Review" without handoff)
- Agent handoff format vs human handoff format — same or different?
- Automation: if task moves to "In Review" without handoff comment → auto-block and notify

## Reporting Cadence

| Report | Frequency | Data Source | Audience | Auto-generated? |
|--------|-----------|-------------|----------|-----------------|
| **Sprint Review** | Every sprint end | ClickUp sprint data | Internal team | Yes (n8n pulls data, generates markdown) |
| **Client Status Report** | Weekly (per client) | Delivery space tasks | Client | Yes (template filled from task data) |
| **Compliance Posture** | Monthly | UCM controls, evidence status | Internal + auditor | Yes (custom fields aggregated) |
| **Infrastructure Health** | Weekly | Platform Engineering tasks + Grafana | Internal | Semi (dashboard + manual notes) |
| **Agent Performance** | Per session | Agent task metadata | Internal | Yes (from Sable tracking) |
| **Security Summary** | Weekly | Security Ops tasks | Internal | Yes (open vulns, incidents, access reviews) |
| **Financial** | Monthly | Finance list + time tracking | Internal | Manual |
| **Board Deck** | Quarterly | All of the above | Stakeholders | Manual with data pulls |

For each report, define:
- What ClickUp data feeds into it
- What dashboard or view generates the data
- Export format (PDF? Markdown? ClickUp Doc?)
- Who reviews before distribution
- Where it's stored (ClickUp Doc? Google Drive? Outline?)

## Integration Map

Design the complete data flow between ClickUp and every connected system:

```
GitHub PR merged ──webhook──→ n8n ──API──→ ClickUp: update task status to "In Review"
Grafana alert fires ──webhook──→ n8n ──API──→ ClickUp: create incident task
ArgoCD deploy succeeds ──webhook──→ n8n ──API──→ ClickUp: close deployment task
CrowdSec threat ──webhook──→ n8n ──API──→ ClickUp: create security finding
Agent completes work ──MCP──→ ClickUp: update task + add handoff comment
Devtron build fails ──webhook──→ n8n ──API──→ ClickUp: create bug task
Client submits form ──ClickUp form──→ ClickUp: auto-create + assign + tag
Sprint ends ──n8n cron──→ ClickUp API: pull data → generate report → Rocket.Chat
Certificate expiring ──n8n cron──→ ClickUp: create task in Certificate Management
Compliance evidence due ──n8n cron──→ ClickUp: create reminder in Evidence Collection
```

For EACH integration:
- Trigger event
- Which n8n workflow handles it
- What ClickUp API endpoint is called
- What task metadata is set
- What notifications fire
- Error handling (what if ClickUp API fails?)

## Capacity Planning & Estimation

- **Sprint capacity**: How many tasks per sprint for a 1-person team + 23 agents?
- **Estimation method**: Story points or time-based? (recommend one)
- **Point scale**: If story points — 1, 2, 3, 5, 8, 13? Or T-shirt sizes (S, M, L, XL)?
- **Agent capacity**: How to account for agent work in sprint planning?
- **Buffer**: How much sprint capacity to reserve for unplanned work (bugs, incidents)?
- **Velocity tracking**: How to calculate and display velocity in ClickUp
- **Over-commitment detection**: Automation to warn when sprint is overloaded

## Escalation Paths

| Condition | Time Elapsed | Action | Who |
|-----------|-------------|--------|-----|
| Task blocked | 0h | Status → Blocked, blocker documented | Agent/assignee |
| Task still blocked | 24h | Auto-notify PM (Rocket.Chat) | Sable/n8n |
| Task still blocked | 48h | Escalate to Wakeem (Rocket.Chat + email) | n8n |
| Task still blocked | 72h | Auto-raise priority by one level | Automation |
| Urgent task not started | 15 min | Notify Wakeem immediately | Automation |
| SLA breach imminent | 1h before SLA | Warning notification | Automation |
| SLA breached | 0h past SLA | Escalate to Wakeem + log compliance event | Automation |

Define:
- Can agents escalate? How?
- De-escalation (blocker resolved → auto-notify PM, resume SLA timer)
- Escalation for client tasks vs internal tasks — different paths?

## Client Communication Log

Where do client interactions get recorded?

| Communication | Where in ClickUp | Format |
|--------------|-----------------|--------|
| Meeting notes | Task comment on engagement task OR ClickUp Doc linked to client folder | Markdown with date, attendees, decisions, action items |
| Email decisions | Task comment with email content pasted | Prefix: `[EMAIL] From: client@...` |
| Phone call notes | Task comment | Prefix: `[CALL] Date, duration, summary` |
| Client feedback | Task comment on the deliverable task | Prefix: `[FEEDBACK]` |
| SOW/contract changes | ClickUp Doc in client folder | Versioned doc with change log |
| Approval received | Task comment + status change | `[APPROVED BY] Client Name, Date` |

Define:
- Is there a dedicated "Communications" list per client? Or comments on tasks?
- How to search for past client decisions
- How to link a communication to multiple tasks
- Privacy: which communications are visible to client guests?

## Template Library
NOTE: We already have a 27-template Gemini library (AUTHORITATIVE standard) + 6 templates in the infra repo. Do NOT redesign templates — instead, tell me how to INTEGRATE existing templates into the ClickUp workspace:
- How to create ClickUp task templates from our existing markdown templates
- Where templates live (Space-level? Folder-level?)
- Can agents use templates via API? How?
- How to auto-attach the right template when a task type is selected
- How to update templates without breaking existing tasks
- Which of our 27 templates should become ClickUp task templates vs ClickUp Doc templates?

## Existing Research (USE THIS AS INPUT)
I already have a comprehensive ClickUp Automation Playbook from a previous Gemini Deep Research session. It covers 145+ automations, 50+ native triggers, 45+ n8n workflows, 30+ API endpoints, and 20+ AI agent MCP patterns. Reference this research — don't duplicate it, BUILD ON IT. The playbook covers the HOW of automation. This prompt covers the WHERE (workspace structure) and the WHAT (governance, standards, views, dashboards). Together they form the complete ClickUp architecture.

Key findings from the automation playbook:
- Native automations inherit through the workspace hierarchy (Space → Folder → List)
- n8n is the external orchestration hub connecting ClickUp to all other services
- AI agents interact via MCP tools (create_task, update_task, search_tasks, etc.)
- Status changes, due dates, tags, and custom fields all serve as automation triggers
- Compliance evidence collection can be fully automated via n8n + ClickUp webhooks

## What We Currently Have (needs overhaul)

### Current Structure
- **01 Platform** (Space ID: 90174819900) — Internal operations
  - 7 folders: Business Ops, Platform Engineering, Security Ops, Service Management, Compliance Program, Process Library, Product & Strategy
  - 55 lists across these folders
  - 280+ tasks (208 from last session + 80+ added today)
  - 80 UCM compliance controls
  - 20 custom fields across 5 lists
  - 68 tags (51 Platform, 17 Delivery)
- **02 Delivery** (Space ID: 90174819904) — Client work with guest access
  - Per-client folders
  - 00 Delivery Operations (internal)

### Problems With Current Structure
1. **Tags are inconsistent** — some use `domain:k3s` format, others use plain `security`, `ai-agents`, `cloudflare`
2. **Status workflows not configured** — everything uses default "to do / complete"
3. **No blocking/dependency tracking** — tasks don't link to each other properly
4. **Subtasks underused** — big tasks should be broken into subtasks with their own statuses
5. **Documents scattered** — no organized doc structure in ClickUp
6. **No dashboards** — no visibility into project health, sprint progress, agent activity
7. **No automations** — everything manual
8. **Custom fields inconsistent** — UCM list has 12 fields, other lists have none
9. **Agent-created tasks missing metadata** — AI agents create bare tasks without tags, dates, assignees
10. **No sprint/agile structure** — no sprints, no velocity tracking, no burndown
11. **No views configured** — no board views, no Gantt, no calendar view
12. **No forms** — no intake forms for bugs, client requests, incidents

## Our Full Stack (ClickUp needs to track ALL of this)

### Infrastructure (23 agents manage this)
K3s, Traefik, cert-manager, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, NeuVector, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Velero, Cloudflare

### Apps
helixstax.com (Astro), Rocket.Chat, Backstage, Outline, Open WebUI, SearXNG, Ollama

### Client Delivery
CTGA assessments, compliance audits, infrastructure builds, managed services, consulting engagements

### Business
Sales pipeline, marketing content, proposals/SOW, invoicing, HR, legal

### Compliance Frameworks
NIST CSF 2.0, SOC 2 Type II, ISO 27001, CIS Controls v8, HIPAA (per client), PCI DSS (per client)

## What I Need Researched

### 1. Space Architecture
- Should we keep 2 spaces (Platform + Delivery) or restructure?
- Should compliance be its own space or stay as a folder?
- Should agents have their own space for tracking agent work?
- How do other IT consulting firms structure ClickUp?
- Best practices for multi-client workspace organization

### 2. Folder & List Structure
- What folders should exist in each space?
- What lists should exist in each folder?
- How granular should lists be? (one list per service? per domain? per phase?)
- Should infrastructure tasks be organized by service (PostgreSQL list, Traefik list) or by phase (Phase 1 list, Phase 2 list)?
- How to handle cross-cutting tasks that span multiple services

### 3. Status Workflows (per list type)
Design COMPLETE status workflows for each type of work:
- Infrastructure build tasks
- Bug/issue lifecycle
- Incident management (ITIL-aligned)
- Change management
- Client delivery engagement
- Compliance controls
- Sprint/agile tasks
- Agent-generated tasks
- Research/evaluation tasks
- Content/marketing tasks
- What statuses should auto-transition? What needs manual approval?

### 4. Tag System
Design a COMPLETE tag taxonomy:
- What tag categories? (domain, service, type, phase, environment, framework, priority-modifier?)
- Naming convention — `category:value` or plain names?
- Which tags should be created at space level vs workspace level?
- How many tags is too many? When do tags become noise?
- Should agents apply tags automatically? Which ones?
- Color coding strategy

### 5. Custom Fields Strategy
- Which lists need custom fields? What fields?
- UCM controls: current 12 fields — are they right? Missing any?
- Infrastructure tasks: what fields? (service, environment, dependency chain position?)
- Client delivery: what fields? (SLA, client name, engagement type, billing?)
- Agent tracking: what fields? (agent name, model used, tokens consumed, duration?)
- Should custom fields be at folder level (inherited by all lists) or per-list?

### 6. Subtask Strategy
- When should a task be a subtask vs its own task?
- Should subtasks have their own statuses separate from parent?
- How deep should nesting go? (task → subtask → sub-subtask?)
- How do agents create subtasks properly?
- Checklist vs subtask — when to use which?

### 7. Dependency & Relationship System
- How to model the infrastructure dependency chain in ClickUp
  (PostgreSQL must deploy before Zitadel, Traefik before all apps, etc.)
- Blocking vs waiting-on vs related — when to use each
- How do dependencies affect sprint planning?
- Should agents create dependencies automatically?
- How to visualize the dependency graph (Gantt? Board?)

### 8. Views
Design views for each audience:
- **Orchestrator/PM view**: What's in progress, what's blocked, what's next
- **Developer view**: My tasks, current sprint, PRs linked to tasks
- **Security view**: Open vulnerabilities, compliance gaps, access reviews due
- **Client view**: Engagement status, deliverable timeline, SLA compliance
- **Agent view**: Tasks assigned to agents, agent performance, completion rate
- **Executive view**: Project health, burn rate, sprint velocity, client satisfaction
- Board vs List vs Calendar vs Gantt vs Timeline — which for what

### 9. Dashboard Design
Design dashboards for:
- **Project Health**: task completion rate, blocker count, sprint burndown
- **Infrastructure Status**: service deployment status, dependency chain progress
- **Compliance Posture**: controls implemented vs planned, evidence collection status, next audit date
- **Client Delivery**: per-client engagement health, SLA tracking, deliverable pipeline
- **Agent Performance**: tasks created/completed by agents, tags applied, average completion time
- **Sprint Dashboard**: velocity, burndown, scope changes, carryover

### 10. Automation Rules
Design automations for:
- When status changes → notify Rocket.Chat
- When task is blocked → alert assignee + PM
- When due date approaches (3 days) → reminder
- When subtask completes → check if parent can auto-complete
- When task tagged `compliance:required` → add to compliance evidence list
- When client task created → add to client's Shared Drive folder
- When priority set to urgent → notify immediately
- When task unmodified for 7 days → flag as stale
- Agent-triggered automations (webhook from n8n)

### 11. Documents Structure
Where should ClickUp Docs live?
- Runbooks (per service)
- SOPs (operational procedures)
- ADRs (architecture decisions)
- Policies (security, compliance)
- Client documentation
- Templates (post-mortem, change request, sprint review, proposal)
- Meeting notes
- Should docs be in ClickUp or in Outline (separate wiki)? Or both?

### 12. Forms & Intake
Design forms for:
- Bug report → auto-creates task with tags + priority + assignee
- Client request → auto-creates in delivery space with SLA tracking
- Incident report → auto-creates with incident lifecycle status
- Change request → auto-creates with approval workflow
- Service request → auto-routes to correct list
- Security finding → auto-escalates based on severity
- New client intake → auto-creates folder structure + templates

### 13. Sprint/Agile Structure
- Sprint duration (1 week? 2 weeks?)
- How to create sprints in ClickUp
- Sprint planning workflow
- Sprint review automation
- Velocity tracking
- Backlog grooming process
- How agents interact with sprints (can they add tasks to active sprint?)

### 14. Agent Integration Patterns
How should 23 AI agents interact with ClickUp?
- Task creation standards (what fields are REQUIRED)
- Status update patterns
- Comment formatting
- Subtask creation rules
- When to create vs update tasks
- Agent identification (which agent did what — custom field or comment?)
- Preventing duplicate task creation
- Rate limiting (don't spam ClickUp API)

### 15. Governance & Maintenance
- Who owns the workspace structure? (PM? Orchestrator?)
- How often to audit tag hygiene, stale tasks, orphan lists?
- Archive policy — when to archive completed work?
- Naming convention enforcement
- Template enforcement for task creation
- Permission model — who can create/edit/delete what?

### 16. Time Tracking & Billing
- Should agents log time on tasks? How?
- How does time tracking feed into client billing?
- ClickUp native time tracking vs external (Toggl, Harvest)
- Time estimates vs actual — variance tracking
- Billable vs non-billable time categorization

### 17. Goals, OKRs & Milestones
- Quarterly business goals (revenue, clients, compliance certifications)
- How do tasks ladder up to goals?
- Key milestones: K3s operational, first CTGA assessment, SOC 2 audit, etc.
- ClickUp Goals feature — how to configure for consulting
- Sprint goals vs business goals — separate or linked?

### 18. Guest Access & Client Visibility
- What can clients see in 02 Delivery space?
- Permission model for guest users
- What's hidden from clients (internal notes, agent activity, cost data)
- Client-specific views vs internal views
- How to onboard a client to ClickUp (invite flow, training)

### 19. Notification Strategy
- What triggers ClickUp notifications vs Rocket.Chat vs email vs nothing
- Per-person notification preferences
- Agent notifications (should agents get notified? how?)
- Client notifications (task updates, deliverables ready)
- Preventing notification fatigue

### 20. Email Integration
- ClickUp email-to-task — enable or skip?
- Which email addresses create tasks in which lists?
- Client emails → task creation in delivery space?
- Integration with Postal (transactional) and Google Workspace (business)

### 21. Archive & Retention Strategy
- When to archive completed sprints, engagements, old tasks
- What happens to archived data (searchable? reportable?)
- Compliance retention requirements (7 years for SOC 2/HIPAA evidence)
- How to export data for long-term storage (MinIO WORM)
- Cleanup automation (auto-archive after 90 days of completion?)

### 22. Whiteboards & Visual Planning
- ClickUp Whiteboards for architecture diagrams — use or skip?
- Mind maps for brainstorming
- Roadmap visualization
- When to use Whiteboard vs Mermaid diagrams in docs

### 23. Multiple Assignees & Workload
- Tasks assigned to both Wakeem AND an agent — how to handle
- Workload view — capacity planning
- Over-allocation detection
- Agent workload tracking (how many tasks per agent per sprint)

## Required Output Format

```markdown
# ClickUp Workspace Architecture — Helix Stax

## Executive Summary
[2-3 sentences on the recommended architecture]

## Space Architecture
[Diagram showing spaces, folders, lists]

## Status Workflows
### [Workflow Name]
| Status | Color | Transitions To | Auto/Manual | Trigger |

## Tag Taxonomy
| Category | Tags | Color | Applied By |

## Custom Fields
### [List/Folder Name]
| Field | Type | Options | Required? | Who Sets It |

## Subtask & Dependency Rules
[Decision tree: when to subtask, when to depend, when to relate]

## Views (per audience)
| View Name | Type | Filters | Grouping | Audience |

## Dashboards
### [Dashboard Name]
| Widget | Data Source | Refresh |

## Automations
| # | Trigger | Condition | Action | List |

## Documents Structure
[Tree showing doc organization]

## Forms
### [Form Name]
| Field | Type | Required | Maps To |

## Sprint Configuration
[Sprint settings, cadence, ceremony schedule]

## Agent Integration Standards
| Rule | Description | Enforcement |

## Governance
| Policy | Frequency | Owner |

## Migration Plan
[How to get from current state to target state without losing data]
```

Be exhaustive and opinionated. This is the definitive workspace architecture for an IT consulting firm running 23 AI agents. Tell me exactly how to structure everything — not options, THE answer. Include specific ClickUp feature names, settings paths, and API endpoints where relevant.
