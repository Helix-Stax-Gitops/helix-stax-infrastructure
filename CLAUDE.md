# Helix Stax Infrastructure

## Project Overview
Greenfield infrastructure rebuild for Helix Stax — tearing down everything and rebuilding from scratch on K3s. This repo contains all IaC (OpenTofu, Ansible, Helm), docs, runbooks, and configuration for the complete stack.

## Stack (Updated 2026-03-20)

| Layer | Tools |
|-------|-------|
| **Provisioning** | Hetzner Cloud (US region), AlmaLinux 9.7 |
| **IaC** | OpenTofu (NOT Terraform), Ansible |
| **Orchestration** | K3s |
| **Ingress** | Traefik + Cloudflare |
| **CNI** | Flannel (evaluating Cilium) |
| **Database** | CloudNativePG (PostgreSQL) |
| **Cache** | Valkey (NOT Redis) |
| **Registry** | Harbor |
| **Object Storage** | MinIO |
| **Secrets** | OpenBao + External Secrets Operator |
| **Identity** | Zitadel (NOT Authentik) |
| **CI/CD** | Devtron + ArgoCD |
| **Monitoring** | Prometheus + Grafana + Loki + Alertmanager |
| **Tracing** | OpenTelemetry + Grafana Tempo (Phase 6+, placeholder) |
| **IDS** | CrowdSec |
| **Backup** | Velero -> MinIO -> Backblaze B2 |
| **Automation** | n8n |
| **Chat** | Rocket.Chat (NOT Telegram) |
| **Internal Portal** | Backstage (Phase 3+) |
| **Knowledge Base** | Outline |
| **Status Page** | Grafana public dashboards (NOT Gatus) |
| **BI Dashboards** | Grafana (NOT Metabase) |

## Key Decisions

- **OpenTofu over Terraform**: BSL license concerns. Drop-in replacement, same HCL.
- **Valkey over Redis**: SSPL license. Valkey is Linux Foundation fork, BSD license.
- **Rocket.Chat over Telegram**: Self-hosted, OIDC with Zitadel, client channels, audit logging.
- **Backstage over Homepage**: Service catalog + docs + software templates. Deploy Phase 3+.
- **Outline**: Wiki/knowledge base + client landing page.
- **Grafana absorbs**: Status page (public dashboards), BI dashboards, Gatus replacement.
- **OpenTelemetry**: Placeholder only — deploy when client environments exist.

## Architecture

```
Internet
    |
Cloudflare (CDN + DDoS + WAF + Zero Trust)
    |
Hetzner Cloud (US — Ashburn, VA)
    |
K3s Cluster
  +-- Traefik (ingress)
  +-- cert-manager (TLS)
  +-- CloudNativePG (PostgreSQL)
  +-- Valkey
  +-- MinIO
  +-- Harbor
  +-- Zitadel (needs PostgreSQL)
  +-- Devtron + ArgoCD
  +-- Prometheus + Grafana + Loki
  +-- CrowdSec
  +-- n8n (needs PostgreSQL)
  +-- Velero (backups)
  +-- Rocket.Chat
  +-- Backstage (Phase 3+)
  +-- Outline
    |
Backblaze B2 (offsite backups)
```

## Nodes

| Node | Role | IP |
|------|------|----|
| heart | Control Plane | 178.156.233.12 |
| helix-worker-1 | Worker | 138.201.131.157 |

## Task Dependency Chain

```
OpenTofu: Provision Hetzner VPS (US region)
  -> Ansible: Harden AlmaLinux (SELinux, SSH, firewall, CIS Benchmark)
    -> Ansible: Install K3s on hardened nodes
      -> Helm: Deploy Traefik (ingress)
      -> Helm: Deploy cert-manager (TLS)
        -> Helm: Deploy PostgreSQL (CloudNativePG)
        -> Helm: Deploy Valkey
        -> Helm: Deploy MinIO
        -> Helm: Deploy Harbor
          -> Helm: Deploy Zitadel (needs PostgreSQL)
            -> Manual: Configure OIDC clients
              -> Helm: Deploy Devtron (needs Harbor)
              -> Helm: Deploy ArgoCD
                -> Helm: Deploy Prometheus + Grafana + Loki
                -> Helm: Deploy CrowdSec
                -> Helm: Deploy n8n (needs PostgreSQL)
                  -> n8n: Build integration workflows
                    -> Helm: Deploy Velero (backups)
                      -> Ansible: Codify into reusable roles
                        -> OpenTofu: Codify into reusable modules
```

## IaC Tool Selection

| Tool | When | Example |
|------|------|---------|
| **OpenTofu** | Provisioning infrastructure | Hetzner VPS, Cloudflare DNS, firewall rules |
| **Helm** | Deploying apps on K3s | Prometheus, Grafana, Zitadel, Harbor, ArgoCD |
| **Ansible** | OS-level config + hardening | AlmaLinux hardening, SELinux, SSH, CrowdSec |
| **ArgoCD** | GitOps continuous deployment | Ongoing app deploys, config drift correction |
| **Manual** | One-time UI config | Devtron pipelines, Zitadel OIDC clients |

## ClickUp Workspace

Central nervous system for all operations. Two spaces, research-backed structure.

### Spaces
- **01 Platform** (ID: 90174819900) — Internal ops. Team only, no client access.
- **02 Delivery** (ID: 90174819904) — Client work. Per-client folders with guest access.

### 01 Platform Structure
| # | Folder | Purpose |
|---|--------|---------|
| 01 | Business Operations | Sales, marketing, finance, HR, legal |
| 02 | Platform Engineering | Infra backlog, K3s, services, CI/CD, DB, backups, monitoring |
| 03 | Security Operations | Incidents, vulns, access reviews, WAF, certs, identity/auth |
| 04 | Service Management | ITIL: changes, requests, incidents, catalog, assets, capacity |
| 05 | Compliance Program | UCM (80 controls), evidence, policies, risk, audits, vendors, gaps, reports |
| 06 | Process Library | Runbooks, SOPs, templates, automation recipes |
| 07 | Product & Strategy | Roadmap, research, ADRs, website, brand kit, client-facing products |

### 02 Delivery Structure
- **00 Delivery Operations** — Internal (engagement pipeline, resource allocation, health scores)
- **{Client Name}** — One folder per client engagement

### Apps (deployed on K3s)
- Website (helixstax.com)
- Rocket.Chat
- Backstage (internal portal)
- Outline (knowledge base)
- n8n
- Grafana (monitoring + BI + status page)

### Integration Flow
```
All services -> n8n (hub) -> ClickUp (tasks/comments)
                           -> Rocket.Chat (notifications)
                           -> Grafana (dashboards)
```

### Compliance Architecture
- Unified Control Matrix (UCM): ~80 controls mapped across NIST CSF, SOC 2, ISO 27001, CIS v8
- Per-framework views are filtered views on the same UCM list (no duplication)
- Evidence naming: {CONTROL-ID}_{TYPE}_{DATE}_{VERSION}
- HIPAA/PCI/GDPR added as custom fields per client, not separate lists

## Compliance Frameworks

### Tier 1 (Now)
NIST CSF 2.0, CIS Controls v8, CIS Benchmarks (AlmaLinux 9), SOC 2, ISO 27001

### Tier 2 (Per Client)
HIPAA, PCI DSS 4.0, NIST 800-171, CMMC 2.0, GDPR, CCPA

### Tier 3 (Future)
FedRAMP, StateRAMP, CJIS, ITAR

## Conventions

- Domain: helixstax.com (public), internal services on subdomains
- OS: AlmaLinux 9.7
- No secrets in git — OpenBao only
- All Helm values in `helm/` directory
- All OpenTofu modules in `terraform/` (migrating to `opentofu/`)
- Runbooks in `docs/runbooks/`
- ADRs in `docs/adr/`
- Phase tutorials in `docs/tutorials/`

## PACT Agent Notes

- Wakeem is sole assignee on all ClickUp tasks
- 19 PACT agents tracked in "Worked By" field (internal, never client-visible)
- Agents use ClickUp MCP tools directly for task management
- All agent work targets worktree paths, not main branch
- Commit messages: Wakeem as author, NO Co-Authored-By lines
