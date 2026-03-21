# ClickUp Workspace Overhaul — Agent Reference

## Spaces

| Space | ID | Status |
|-------|----|--------|
| 01 Infrastructure | TBD (user creates manually) | NEW |
| 02 Helix Stax | 90174390517 (existing, restructure) | ACTIVE |
| Vacancy Ecosystem | 90174131081 | ARCHIVE |
| Wakeem Home Server | 90174615853 | ARCHIVE |

## Space 01: Infrastructure — Folder + List Structure

```
01 Infrastructure (Space — user creates manually)
  01 Server Provisioning (Folder)
    - Hetzner VPS
    - AlmaLinux Base Hardening
    - DNS & Cloudflare
    - Firewall Rules
  02 K3s Cluster (Folder)
    - Cluster Setup
    - Traefik Ingress
    - CNI (Flannel/Cilium)
    - Storage
  03 Core Services (Folder)
    - PostgreSQL (CloudNativePG)
    - Valkey
    - Harbor Registry
    - MinIO Object Storage
    - OpenBao Secrets
  04 Auth & Identity (Folder)
    - Zitadel Deployment
    - OIDC Client Configs
    - Cloudflare Access
  05 CI/CD Pipeline (Folder)
    - Devtron
    - ArgoCD GitOps
    - Harbor Trivy Scanning
  06 Monitoring & Observability (Folder)
    - OpenTelemetry Collector (placeholder)
    - Grafana Tempo (placeholder)
    - Prometheus + Alertmanager
    - Grafana Dashboards
    - Loki Logging
    - Grafana OnCall
    - CrowdSec IDS
  07 Backups & DR (Folder)
    - Velero Configuration
    - MinIO Backup Tier
    - Backblaze B2 Offsite
    - Recovery Testing
  08 Infrastructure as Code (Folder)
    - OpenTofu Modules
    - Ansible Roles
    - Ansible Inventories
  09 Client Productization (Folder)
    - Onboarding Templates
    - Client Environment Provisioning
    - CTGA Assessment Tooling
  10 Bugs & Issues (Folder)
    - Infrastructure Bugs
  11 Apps (Folder)
    - Website (helixstax.com)
    - Rocket.Chat
    - Backstage (internal portal)
    - Outline (knowledge base)
    - n8n
```

## Space 02: Helix Stax — Folder + List Structure

Existing space ID: 90174390517. Create NEW folders alongside existing ones. Old folders archived later.

```
02 Helix Stax (Space — existing)
  01 Engineering (Folder — NEW)
    - Website (helixstax.com)
    - Client Portal
    - n8n Workflows
    - AI & Automation
    - Email Stack
  02 Operations (Folder — NEW)
    - Active Incidents
    - Post-Mortems
    - Change Requests
    - Change Log
    - Scheduled Maintenance
  03 Compliance (Folder — NEW) [EZRA BUILDS THIS]
    - NIST CSF 2.0 — Govern
    - NIST CSF 2.0 — Identify
    - NIST CSF 2.0 — Protect
    - NIST CSF 2.0 — Detect
    - NIST CSF 2.0 — Respond
    - NIST CSF 2.0 — Recover
    - SOC 2 — CC1 (Control Environment)
    - SOC 2 — CC2 (Communication & Info)
    - SOC 2 — CC3 (Risk Assessment)
    - SOC 2 — CC4 (Monitoring Activities)
    - SOC 2 — CC5 (Control Activities)
    - SOC 2 — CC6 (Logical & Physical Access)
    - SOC 2 — CC7 (System Operations)
    - SOC 2 — CC8 (Change Management)
    - SOC 2 — CC9 (Risk Mitigation)
    - SOC 2 — A1 (Availability)
    - SOC 2 — C1 (Confidentiality)
    - SOC 2 — P1 (Privacy)
    - ISO 27001 (lists per Annex A domain)
    - CIS Controls v8
    - Evidence Collection
    - Access Reviews
    - Audit Findings
    - Framework Mappings
  04 Client Delivery (Folder — NEW)
    - Intake / Triage Queue
    - Client Templates
  05 Business (Folder — NEW)
    - Marketing & Content
    - SEO & GEO
    - Sales Pipeline
    - Finance & Vendors
  06 PACT & Internal (Folder — NEW)
    - Agent Activity Log
    - Sprint Backlog
    - Knowledge Base (ADRs, SOPs)
    - Admin (Licenses, Access)
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Spaces | NN Name | 01 Infrastructure |
| Folders | NN Name | 03 Core Services |
| Lists | Title Case | PostgreSQL (CloudNativePG) |
| Tasks | Imperative verb | Configure Traefik TLS termination |
| Bugs | [BUG] Description | [BUG] CoreDNS fails on IPv6 |
| Incidents | [INC-NNNN] Description | [INC-0001] K3s API unreachable |
| Milestones | [MILESTONE] Description | [MILESTONE] K3s cluster operational |

## Status Workflows

### Infrastructure / Engineering
Backlog (Gray) -> To Do (Blue) -> In Research (Purple) -> In Design (Orange) -> In Progress (Yellow) -> In Review (Light Blue) -> Blocked (Red) -> Done (Green) -> Won't Do (Light Gray)

### Bug Lifecycle
Reported -> Confirmed -> In Progress -> Fix In Review -> Resolved / Cannot Reproduce / Duplicate

### Incident Lifecycle
Detected -> Investigating -> Identified -> Mitigating -> Resolved -> Post-Mortem Complete

### Change Management
Requested -> Under Review -> Approved -> Scheduled -> Implementing -> Verifying -> Complete / Rejected / Rolled Back

### Client Delivery
New Request -> Triaged -> Scheduled -> In Progress -> Awaiting Client -> In Review -> Delivered -> Closed

### Compliance
Not Started -> Evidence Gathering -> In Implementation -> Awaiting Audit -> Compliant / Non-Compliant / Exception Granted

## Tags Taxonomy (category:value format, lowercase-kebab)

### Domain (Blue)
domain:k3s, domain:networking, domain:auth, domain:database, domain:storage, domain:monitoring, domain:cicd, domain:security, domain:iac

### Phase (Green)
phase:01-provisioning through phase:08-productize

### Type (Orange)
type:feature, type:bug, type:tech-debt, type:security, type:documentation, type:incident, type:change-request, type:research

### Environment (Purple)
env:production, env:staging, env:lab

### Service
svc:traefik, svc:zitadel, svc:harbor, svc:minio, svc:postgres, svc:valkey, svc:prometheus, svc:grafana, svc:loki, svc:crowdsec, svc:argocd, svc:devtron, svc:velero, svc:openbao, svc:cloudflare, svc:k3s, svc:ansible, svc:opentofu, svc:rocketchat, svc:backstage, svc:outline, svc:n8n

### Modifiers
sla:breach-risk, compliance:required, compliance-evidence, compliance-gap, audit-trail, client-visible, blocking, quick-win

## ClickUp Docs Structure

```
Docs/
  01 Runbooks/ (per-service deployment & operations)
  02 SOPs/ (Change Mgmt, Incident Response, Access Review, Backup, Client Onboarding, Security, Certs)
  03 ADRs/ (Architecture Decision Records)
  04 Policies/ (InfoSec, Acceptable Use, Data Classification, IR, Change Mgmt, Access Control)
  05 Client Documentation/ (Portal Guide, SLA Definitions, Service Catalog)
  06 Templates/ (Post-Mortem, Change Request, ADR, Sprint Review)
```

## Wakeem User ID: 192289304
## Workspace ID: 9017890239

## Tool Swaps (from original plan)
- Redis -> Valkey (BSD, Linux Foundation)
- Terraform -> OpenTofu (MPL 2.0, Linux Foundation)
- Telegram -> Rocket.Chat (MIT, self-hosted)
- Homepage -> Backstage (Apache 2.0, Phase 3+)
- Gatus -> Grafana public dashboards
- Metabase -> Grafana
- Added: Outline (knowledge base)
- Added: OpenTelemetry + Tempo (placeholder, Phase 6+)

## MCP Tool Limitations

These CANNOT be done via ClickUp MCP — require manual UI:
- Create/archive spaces
- Configure status workflows
- Create custom fields
- Create automations
- Create forms
- Create views/dashboards
- Configure goals/milestones/sprints

These CAN be done via MCP:
- Create folders (clickup_create_folder)
- Create lists in folders (clickup_create_list_in_folder)
- Create tasks (clickup_create_task)
- Create documents (clickup_create_document)
- Create document pages with content (clickup_create_document_page)
- Add tags to tasks (clickup_add_tag_to_task)
- Add task dependencies (clickup_add_task_dependency)
- Update tasks (clickup_update_task)
- Move tasks (clickup_move_task)
