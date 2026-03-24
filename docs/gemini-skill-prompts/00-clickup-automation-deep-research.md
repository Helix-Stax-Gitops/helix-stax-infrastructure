# Gemini Deep Research: ClickUp Automation — Complete Integration & Workflow Guide

## Who I Am
I run Helix Stax, a small IT consulting company. I manage everything through ClickUp — project management, client delivery, compliance tracking, sprint planning, and internal operations. I have 23 AI agents (Claude Code + Gemini CLI) that interact with ClickUp via MCP and API. I need to automate EVERYTHING possible in ClickUp — native automations, API integrations, webhooks, n8n workflows, and AI agent interactions.

## What ClickUp Is
ClickUp is an all-in-one project management platform that serves as the **central nervous system** for Helix Stax. It's where every task, every client engagement, every compliance control, and every sprint is tracked. It replaces Jira, Asana, Trello, Monday, and Notion in a single tool.

**Key ClickUp Concepts:**
- **Workspace** → contains Spaces (top-level organizational unit)
- **Spaces** → contain Folders and Lists (e.g., "01 Platform" for internal, "02 Delivery" for clients)
- **Folders** → group related Lists (e.g., "Platform Engineering" contains Infrastructure Backlog, Service Deployments, CI/CD Pipeline)
- **Lists** → contain Tasks (the actual work items)
- **Tasks** → have statuses, assignees, due dates, custom fields, tags, subtasks, dependencies, comments, attachments, time tracking
- **Custom Fields** → typed metadata on tasks (dropdowns, numbers, dates, labels, relationships)
- **Views** → Board, List, Calendar, Gantt, Table, Timeline, Map, Workload
- **Automations** → native if/then rules that trigger on task events
- **Webhooks** → HTTP callbacks fired on workspace events (for external integrations)
- **API v2** → REST API for full programmatic control
- **ClickUp AI** — built-in AI features (we use our own agents instead)
- **Forms** → public/private forms that create tasks on submission
- **Docs** → rich text documents inside ClickUp (wiki-style)
- **Goals** → OKR-style goal tracking with measurable targets
- **Dashboards** → customizable reporting with widgets
- **Time Tracking** → native time tracking per task

**Why ClickUp matters for automation:**
ClickUp is the single source of truth for all work. Every other system (GitHub, Grafana, n8n, Rocket.Chat, ArgoCD) needs to read from or write to ClickUp to keep the project state synchronized. Without automation, tasks go stale, statuses drift, and the PM (Sable) can't maintain an accurate picture of the operation.

## How ClickUp Connects to Our Stack
```
GitHub PR merged → n8n webhook → ClickUp task status updated
Grafana alert fires → n8n webhook → ClickUp incident task created
ArgoCD deploy succeeds → n8n webhook → ClickUp deployment task closed
Agent completes work → Claude Code MCP → ClickUp task updated
Client submits form → ClickUp Form → Task auto-created + assigned
Sprint ends → n8n cron → ClickUp sprint report generated → Rocket.Chat
```

n8n is the **integration hub** — it receives events from all systems and translates them into ClickUp API calls. The ClickUp MCP server allows AI agents to interact with ClickUp directly without going through n8n.

## My ClickUp Setup
- **Workspace**: 2 Spaces — 01 Platform (internal ops), 02 Delivery (client work)
- **01 Platform**: 7 folders — Business Ops, Platform Engineering, Security Ops, Service Management, Compliance Program, Process Library, Product & Strategy
- **02 Delivery**: Per-client folders with guest access
- **Lists**: 55 total, 208+ tasks, 80 UCM compliance controls
- **Tags**: 68 (51 Platform, 17 Delivery)
- **Custom Fields**: 20 across 5 lists
- **14 ClickUp Docs** with content

## My Full Tool Stack (integrate ALL of these with ClickUp)
- **CI/CD**: GitHub, Devtron, ArgoCD, Harbor
- **Infrastructure**: K3s, OpenTofu, Ansible, Hetzner Cloud
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Security**: CrowdSec, Kyverno, NeuVector, Trivy, Gitleaks, OpenBao
- **Communication**: Rocket.Chat, Postal (email)
- **Identity**: Zitadel
- **Automation**: n8n (central hub)
- **AI Agents**: Claude Code (23 agents), Gemini CLI (10 workers)
- **Compliance**: OCS Inventory, Openlane, PentAGI, Fleet
- **Google Workspace**: Gmail, Drive, Calendar, Sheets
- **Website**: Astro (helixstax.com)
- **Backup**: Velero, MinIO, Backblaze B2

## What I Need Researched

### 1. ClickUp Native Automations (exhaustive)
- Every trigger type available (status changes, assignee changes, due dates, custom fields, tags, comments, attachments, time tracking, subtasks, dependencies, priorities)
- Every action type (create task, move task, change status, assign, add comment, send email, apply template, set custom field, add tag, create subtask, call webhook)
- Every condition type (if status is, if priority is, if custom field equals, if assignee is, if tag contains)
- Automation recipes — pre-built automations ClickUp offers
- Automation limits per plan tier
- Chaining automations (one automation triggers another)
- Automation for Docs, Whiteboards, Forms
- Time-based automations (due date approaches, overdue, recurring)

### 2. ClickUp API v2 — Complete Automation Reference
- Every endpoint that supports automation (webhooks, tasks, lists, folders, spaces, custom fields, comments, time tracking, goals, docs)
- Rate limits and how to handle them
- Webhook events — every event type (taskCreated, taskUpdated, taskStatusUpdated, taskAssigneeUpdated, taskCommentPosted, taskMoved, etc.)
- Webhook payload schemas for each event
- Bulk operations (batch create, batch update)
- Custom field API (create, read, update field values programmatically)
- OAuth vs Personal API token — which for what
- Pagination patterns for large workspaces

### 3. n8n + ClickUp Integration Patterns
- ClickUp trigger node — every trigger event available
- ClickUp node — every operation available
- Webhook vs polling — which is more reliable
- Multi-step workflows:
  - GitHub PR merged → update ClickUp task status
  - Devtron build fails → create ClickUp bug task + tag + assign
  - ArgoCD sync fails → create ClickUp incident
  - Grafana alert fires → create ClickUp task in Service Management
  - CrowdSec threat detected → create ClickUp security incident
  - New client in CRM → create ClickUp folder + lists + templates
  - Sprint review → auto-generate sprint report from ClickUp data
  - Daily standup → pull tasks in progress, post to Rocket.Chat
  - Compliance evidence due → create ClickUp reminder + assign
  - Invoice due → create ClickUp task in Finance
  - Velero backup fails → create ClickUp incident
  - Certificate expiring → create ClickUp task in Security
  - New team member → create ClickUp onboarding checklist
  - Client offboarding → archive ClickUp folder + export data

### 4. GitHub + ClickUp Integration
- Native GitHub integration — what it does and doesn't do
- Branch creation from ClickUp tasks
- PR linking to tasks (auto status updates)
- Commit message task ID parsing
- GitHub Actions → ClickUp status updates
- GitHub Issues ↔ ClickUp task sync
- Release notes → ClickUp changelog

### 5. ClickUp + Rocket.Chat Integration
- Webhook notifications from ClickUp to Rocket.Chat channels
- Per-channel routing (engineering tasks → #engineering, client tasks → #client-name)
- Interactive messages (approve/reject from Rocket.Chat)
- Daily digest bot (morning summary of tasks)
- Blocker alerts (task marked blocked → immediate notification)

### 6. ClickUp + Google Workspace Integration
- Google Calendar sync (task due dates ↔ calendar events)
- Google Drive attachments in tasks
- Google Sheets ↔ ClickUp dashboards (export/import data)
- Gmail → ClickUp task creation
- Google Forms → ClickUp task creation

### 7. ClickUp for Client Delivery Automation
- Client onboarding workflow (template folder + lists + tasks + permissions)
- Client guest access management
- Per-client dashboards and reporting
- SLA tracking (custom fields + automations)
- Client status reports (auto-generated from task data)
- Time tracking → invoice generation
- Client satisfaction surveys (after task completion)
- Project health scoring (automated based on task metrics)

### 8. ClickUp for Compliance Automation
- UCM (Unified Control Matrix) management via custom fields
- Evidence collection reminders (automated based on due dates)
- Compliance report generation from task data
- Audit trail (who changed what, when)
- Risk register automation (score calculation, escalation)
- Policy review reminders (annual, quarterly)
- Vendor assessment tracking

### 9. ClickUp for Sprint/Agile Automation
- Sprint creation and management
- Velocity tracking
- Burndown chart automation
- Sprint retrospective template automation
- Story point estimation workflows
- Backlog grooming automation
- Sprint rollover (incomplete tasks → next sprint)

### 10. ClickUp AI Agent Integration
- How AI agents (Claude Code) should interact with ClickUp
- Task creation patterns for agents
- Status update patterns
- Comment threading for agent collaboration
- Custom field updates from agent work
- Agent-to-task assignment tracking
- Automated code review task creation from PR
- Agent performance tracking via custom fields

### 11. ClickUp Dashboard & Reporting Automation
- Auto-updating dashboards
- Custom widgets for IT consulting
- Time tracking reports
- Client billing reports
- Team utilization reports
- SLA compliance reports
- Export automation (PDF, CSV, scheduled reports)

### 12. ClickUp Forms & Intake Automation
- Client intake forms → auto-create project structure
- Bug report forms → auto-assign, auto-tag, auto-prioritize
- Service request forms → auto-route to correct list
- Change request forms → auto-create approval workflow
- Security incident forms → auto-escalate

## Required Output Format

Structure your response as a comprehensive automation playbook:

```markdown
# ClickUp Automation Playbook — Helix Stax

## Executive Summary
- Total automations documented: X
- Native automations: X
- n8n workflows: X
- API integrations: X
- AI agent patterns: X

## 1. Native Automations
### Trigger Reference
| Trigger | When It Fires | Example Use Case |

### Action Reference
| Action | What It Does | Example |

### Recommended Automation Rules (top 30)
| # | Trigger | Condition | Action | List | Why |

## 2. API Reference for Automation
### Webhook Events
| Event | Payload Fields | Use Case |

### Key Endpoints
| Endpoint | Method | Use Case | Rate Limit |

## 3. n8n Workflow Templates
### Workflow: [Name]
- Trigger: [what starts it]
- Steps: [what happens]
- ClickUp actions: [what changes in ClickUp]
- Error handling: [what if it fails]

[...for each workflow]

## 4-12. [Continue for each section with tables and specific configurations]

## Implementation Priority
| # | Automation | Impact | Effort | Implement When |
```

Be exhaustive. I want every possible automation for an IT consulting firm running ClickUp as its central nervous system. Include actual ClickUp API endpoints, actual webhook payload examples, and actual n8n node configurations.
