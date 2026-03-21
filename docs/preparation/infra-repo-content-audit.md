# Infra Repo Content Audit

**Author**: Remy Alcazar (Research Analyst)
**Date**: 2026-03-20
**Scope**: Full content audit of `helix-stax-infrastructure/` — classify every file, identify misplaced content, recommend destinations.

---

## Summary

- **Total files scanned**: 184 (excluding `.git/`, `.worktrees/`, and `terraform/.terraform/` cache)
- **Belongs**: 130
- **Misplaced**: 54

The repo has significant contamination from two prior work sessions that used it as a general-purpose scratch space. The `docs/` tree is the primary problem area. Infrastructure code (terraform, docker-compose, scripts, helm) is clean. The docs subdirectories `content/`, `review/`, `compliance-templates/`, and portions of `preparation/`, `plans/`, `templates/`, and `architecture/` contain business, marketing, and operations content that does not belong here.

---

## Misplaced Items

### Marketing & Brand (Social Media / LinkedIn)

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/content/linkedin-carousel-draft.md` | LinkedIn carousel draft (10 slides, platform launch content pack) | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\` | Move |
| `docs/review/linkedin-content-final-verdict.md` | PM verdict on the LinkedIn 6-slide rewrite | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` | Move |
| `docs/review/linkedin-content-marketing-review.md` | Marketing/SEO researcher review of the carousel draft | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` | Move |
| `docs/review/linkedin-content-pm-review.md` | PM review of the carousel draft | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` | Move |
| `docs/review/linkedin-content-seo-review.md` | SEO review of the carousel draft | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` | Move |
| `docs/preparation/linkedin-facebook-strategy-research.md` | LinkedIn & Facebook content strategy research (formats, cadence, hashtags) | `C:\Wakeem\workspace\helix_stax\01_Social_Media\research\` | Move |
| `docs/preparation/seo-social-media-strategy.md` | LinkedIn SEO, hashtag strategy, posting cadence, buyer persona keywords | `C:\Wakeem\workspace\helix_stax\01_Social_Media\research\` | Move |

### Marketing & Brand (Positioning / Strategy)

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/review/compliant-automation-marketing.md` | Research analysis on "compliant automation" market positioning gap | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` | Move |
| `docs/review/compliant-automation-positioning.md` | PM strategic analysis — "Every automation we build is audit-ready" decision doc | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` | Move |
| `docs/review/whats-missing-marketing-deep-dive.md` | Brand strategy deep dive — the missing human story layer | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` | Move |

### Business Operations & Compliance Program

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/compliance-templates/annual-compliance-review.md` | Template: Annual Compliance Review (ClickUp Space 01 Platform) | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` | Move |
| `docs/compliance-templates/ctga-assessment-report.md` | Template: CTGA Assessment Report (client-facing deliverable) | `C:\Users\MSI LAPTOP\HelixStax\business\ctga\templates\` | Move |
| `docs/compliance-templates/dashboard-guide.md` | Template: Compliance Dashboard Guide (operations + compliance leads audience) | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` | Move |
| `docs/compliance-templates/monthly-compliance-status-report.md` | Template: Monthly Compliance Status Report | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` | Move |
| `docs/compliance-templates/quarterly-risk-assessment.md` | Template: Quarterly Risk Assessment | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` | Move |
| `docs/preparation/compliance-structure-research.md` | Research: ClickUp-based compliance management structure, UCM design, multi-framework tracking | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\research\` | Move |
| `docs/preparation/workspace-structure-research.md` | Research: ClickUp workspace architecture, folder structure, one vs two spaces debate | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` | Move |
| `docs/preparation/business-event-workflows-deep-research.md` | Research: Business event automations — sales, client lifecycle, internal ops, compliance | `C:\Wakeem\workspace\helix_stax\07_Technology\n8n\research\` | Move |
| `docs/preparation/clickup-automations-deep-research.md` | Research: ClickUp automations + Postal integration ruleset | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` | Move |
| `docs/preparation/rebranding-and-tools-research.md` | Research: White-label/rebranding analysis of OSS stack licenses + new tool evaluation | `C:\Wakeem\workspace\helix_stax\07_Technology\research\` | Move |
| `docs/plans/clickup-workspace-overhaul.md` | ClickUp workspace overhaul agent reference — space IDs, folder/list structure | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` | Move |

### PM Reports & Session Records

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/review/session-status-report.md` | Post-session ClickUp audit — task status counts, backlog health check | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` | Move |
| `docs/review/workspace-verification-report.md` | Test engineer verification report of ClickUp workspace structure vs approved plan | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` | Move |

### Business Templates (Non-Infra)

These are Gemini-generated operational templates that belong with business operations, not infra.

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/templates/GEMINI-COMPLETE-TEMPLATE-LIBRARY.md` | Complete Gemini-generated template library (27 templates, status: needs ClickUp integration) | `C:\Wakeem\workspace\helix_stax\00_Corporate\templates\` | Move |
| `docs/templates/client-proposal.md` | Client proposal template (cover page, pricing, scope) | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` | Move |
| `docs/templates/statement-of-work.md` | Statement of Work template | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` | Move |
| `docs/templates/offboarding-checklist.md` | Team member offboarding checklist | `C:\Wakeem\workspace\helix_stax\00_Corporate\hr\templates\` | Move |
| `docs/templates/onboarding-checklist-team-member.md` | Team member onboarding checklist | `C:\Wakeem\workspace\helix_stax\00_Corporate\hr\templates\` | Move |
| `docs/templates/meeting-notes.md` | Meeting notes template | `C:\Wakeem\workspace\helix_stax\00_Corporate\templates\` | Move |
| `docs/templates/sprint-review-retro.md` | Sprint review / retrospective template | `C:\Wakeem\workspace\helix_stax\07_Technology\templates\` | Move |
| `docs/templates/sla-definition.md` | SLA definition template | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` | Move |

### AI Tooling Prompts (Not Infra — Belong in `.claude/` or vault)

These are Gemini/Claude prompts for AI workflow optimization, ClickUp management, and template generation. They have no relationship to infrastructure code.

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/gemini-agent-ecosystem-optimization-prompt.md` | Prompt: Redesign PACT agent ecosystem for efficiency (Claude Code + Gemini CLI) | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |
| `docs/gemini-clickup-task-sweep-prompt.md` | Prompt: Gemini CLI ClickUp task board sweep and status reconciliation | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |
| `docs/gemini-claude-code-infrastructure-research-prompt.md` | Prompt: Deep research on Claude Code agent architecture + MCP tool integration | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |
| `docs/gemini-cli-google-cloud-setup-prompt.md` | Prompt: Gemini CLI setup + Google Cloud enterprise configuration | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |
| `docs/gemini-template-generation-prompt.md` | Prompt: Generate all Helix Stax document templates via Gemini | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |
| `docs/google-deep-research-templates-prompt.md` | Prompt: Google AI Studio deep research for IT consulting documentation templates | `~/.claude/prompts/` or `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | Move |

### ClickUp UI Assets (Not Infra)

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `assets/icons/clickup/business-operations.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/compliance-program.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/delivery.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/platform.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/platform-engineering.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/process-library.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/product-strategy.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/security-operations.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |
| `assets/icons/clickup/service-management.svg` | SVG icon used in ClickUp workspace UI | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` | Move |

### Architecture Docs — Borderline / AI Tooling (Not Infra Architecture)

These are Gemini research outputs about Claude Code and Gemini CLI configuration. They are AI tooling references, not infrastructure architecture decisions.

| Current Path | Description | Recommended Destination | Action |
|---|---|---|---|
| `docs/architecture/claude-code-agent-tool-integration.md` | Gemini research output: Claude Code project structure, MCP topologies, agent architecture | `~/.claude/` reference docs or `C:\Users\MSI LAPTOP\HelixStax\vault\ai-tooling\` | Move |
| `docs/architecture/gemini-cli-google-cloud-enterprise.md` | Gemini research output: Gemini CLI setup + Google Cloud enterprise config (full report) | `~/.claude/` reference docs or `C:\Users\MSI LAPTOP\HelixStax\vault\ai-tooling\` | Move |
| `docs/architecture/gemini-cli-google-cloud-enterprise-summary.md` | Summary of the above Gemini research output | `~/.claude/` reference docs or `C:\Users\MSI LAPTOP\HelixStax\vault\ai-tooling\` | Move |

---

## Items That Stay (with rationale)

### Root Level
| File | Rationale |
|------|-----------|
| `.gitignore` | Repo config — stays |
| `CHANGELOG.md` | Standard repo artifact — stays |
| `CLAUDE.md` | AI tooling for this repo — stays (per S5 policy: AI tooling is not application code) |
| `README.md` | Repo documentation — stays |
| `docs/WHERE-EVERYTHING-GOES.md` | Cross-workspace reference guide authored by Wakeem — BORDERLINE. It references all 6 platforms including this repo. Best placed in vault or business workspace, but harmless here as a navigational aid. Recommend moving to `C:\Users\MSI LAPTOP\HelixStax\vault\` when vault is active. |

### Infrastructure Code
All files in these directories are clean and belong:
- `terraform/` (all `.tf`, `.tfvars`, `.tfstate`, `cloud-init/`, `k3s/`, `modules/`)
- `docker-compose/` (all compose files, nginx configs, postgres init, openbao config, netbird config, etc.)
- `scripts/` (`cloudflare-finalize-github-idp.sh`, `cloudflare-zero-trust-setup.sh`, `firewall-setup.sh`)
- `helm/` (directory exists, currently empty — keep as placeholder)

### Infra Docs — All Clean
| Path | Rationale |
|------|-----------|
| `docs/adr/ADR-001-zero-trust-network-architecture.md` | ADR for infra decision — stays |
| `docs/runbooks/authelia-break-glass.md` | Infra runbook — stays |
| `docs/runbooks/authentik-backup-restore.md` | Infra runbook — stays |
| `docs/runbooks/cloudflare-setup.md` | Infra runbook — stays |
| `docs/runbooks/cloudflare-zero-trust.md` | Infra runbook — stays |
| `docs/runbooks/postal-setup.md` | Infra runbook — stays |
| `docs/runbooks/zero-trust-deployment.md` | Infra runbook — stays |
| `docs/tutorials/_index.md` | Tutorial index — stays |
| `docs/tutorials/phase-00-hardening/01-wipe-cluster.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/02-ssh-hardening.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/03-kernel-tuning.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/04-dns-fix.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/05-load-balancer-delete.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/06-firewall-hardening.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/07-fail2ban-setup.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/08-auto-updates.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/09-cis-benchmark.md` | Server hardening tutorial — stays |
| `docs/tutorials/phase-00-hardening/10-credential-scrub.md` | Server hardening tutorial — stays |
| `docs/dns-records.md` | Infrastructure DNS configuration reference — stays |
| `docs/netbird-acls.md` | Netbird ACL configuration — stays |
| `docs/tech-stack.md` | Tech stack reference doc — stays (infra-relevant, tagged as infrastructure) |
| `docs/tools-inventory.md` | Complete CLI/Helm/Docker tool inventory for the buildout — stays |
| `docs/plans/sprint-plan.md` | Infrastructure buildout sprint plan (10-phase K8s rebuild) — stays |
| `docs/plans/addendum-notes.md` | Sprint plan addendum (wipe + clean install directive) — stays |
| `docs/plans/authelia-warp-plan.md` | Infra implementation plan: Authelia RBAC + WARP enrollment — stays |
| `docs/preparation/zero-trust-context.md` | Infra PREPARE doc: Docker Compose inventory, port bindings, OIDC state for coding agents — stays |
| `docs/preparation/cicd-automations-deep-research.md` | Research: CI/CD event automations (Devtron/Harbor/ArgoCD/K3s stack) — infra-adjacent, stays |
| `docs/preparation/service-events-deep-research.md` | Research: Service event catalog for all infra services (K8s, Prometheus, Grafana, Loki, etc.) — stays |
| `docs/preparation/sops-research.md` | Research: SOPS evaluation for GitOps secret encryption with ArgoCD/OpenBao — stays |

### Gemini Skill Prompts (`docs/gemini-skill-prompts/`)
All 40+ skill prompt files stay. They are structured infra knowledge prompts for every stack component (Cloudflare, Traefik, Helm, ArgoCD, Devtron, OpenTofu, Ansible, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Gitleaks, SOPS, Grafana, Prometheus, Loki, Alertmanager, Backstage, Outline, Rocket.Chat, Postal, Velero, integration, K8s fundamentals, security stack, secrets pipeline, storage chain, container registry, infrastructure base, database deep, logging pipeline, tracing pipeline, AI stack, automation platform, website-git). These are explicitly in scope per the mission brief.

### Infra Templates — Stays
| File | Rationale |
|------|-----------|
| `docs/templates/bug-report.md` | Used for GitHub issues on this repo — stays |
| `docs/templates/feature-request.md` | Used for GitHub issues on this repo — stays |
| `docs/templates/incident-report.md` | Infra incident reporting template — stays |
| `docs/templates/security-advisory.md` | Security advisory template — infra-relevant, stays |
| `docs/templates/n8n-workflow-readme.md` | README template for n8n workflows stored in this repo — stays |
| `docs/templates/release-notes.md` | Release notes template for infra releases (`CHANGELOG.md` / `docs/releases/`) — stays |

### Architecture Docs — Stays
| File | Rationale |
|------|-----------|
| `docs/architecture/system-design-cicd-devops.md` | ByteByteGo system design patterns mapped to Helix Stax CI/CD — infra architecture reference, stays |
| `docs/architecture/system-design-databases-caching.md` | ByteByteGo patterns mapped to CloudNativePG/Valkey/MinIO decisions — infra architecture reference, stays |

---

## Empty Directory to Remove

| Path | Action |
|------|--------|
| `assets/icons/clickup/` | Once SVGs are moved, the entire `assets/` directory will be empty — delete it |

---

## Recommended Migration Order

Priority is highest-contamination first, safest-to-move first (no cross-references to other infra files).

1. **LinkedIn content cluster** (7 files) — `docs/content/` + LinkedIn-related `docs/review/` files. Zero infra cross-references. Safe to batch-move immediately.
2. **Positioning & marketing docs** (3 files) — `docs/review/compliant-automation-*.md` + `whats-missing-marketing-deep-dive.md`. Pure business strategy content.
3. **ClickUp UI assets** (9 SVGs) — `assets/icons/clickup/`. Zero infra use. Move then delete `assets/`.
4. **AI tooling prompts** (6 files) — `docs/gemini-*-prompt.md` + `docs/google-deep-research-templates-prompt.md`. Move to `~/.claude/prompts/` or vault.
5. **AI tooling architecture outputs** (3 files) — `docs/architecture/claude-code-*.md` + `docs/architecture/gemini-cli-*.md`. These are research outputs, not infra ADRs.
6. **Compliance templates** (5 files) — entire `docs/compliance-templates/` directory. Move to business workspace.
7. **Business templates** (8 files) — client-proposal, SOW, onboarding, offboarding, meeting-notes, sprint-retro, SLA definition, GEMINI template library. Move to business workspace.
8. **ClickUp/ops research** (5 files) — workspace-structure-research, clickup-automations-deep-research, compliance-structure-research, session-status-report, workspace-verification-report. Move to business workspace.
9. **Marketing research** (2 files) — linkedin-facebook-strategy-research, seo-social-media-strategy. Move to `01_Social_Media/research/`.
10. **Business event research + rebranding** (2 files) — business-event-workflows-deep-research, rebranding-and-tools-research. Move to `07_Technology/`.
11. **plans/clickup-workspace-overhaul.md** — After ClickUp work is complete, move to `07_Technology/clickup/` for archival.

---

## Post-Migration: Directory Cleanup

After migration, the following directories in `docs/` should be deleted (they will be empty or near-empty):

| Directory | Status After Migration |
|-----------|----------------------|
| `docs/content/` | Empty — delete |
| `docs/compliance-templates/` | Empty — delete |
| `assets/` | Empty — delete |

`docs/review/` will be reduced to zero misplaced files. The directory itself should stay as the PACT peer-review output location for infra PRs.

`docs/templates/` will retain 6 infra-relevant templates (bug-report, feature-request, incident-report, security-advisory, n8n-workflow-readme, release-notes). Directory stays.

`docs/architecture/` will retain 2 infra-relevant files (system-design-cicd-devops, system-design-databases-caching). Directory stays.

`docs/preparation/` will retain 4 infra-relevant files (zero-trust-context, cicd-automations-deep-research, service-events-deep-research, sops-research). Directory stays.
