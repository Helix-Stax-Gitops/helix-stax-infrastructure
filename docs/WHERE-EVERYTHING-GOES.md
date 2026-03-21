# Where Everything Goes — Helix Stax Master Reference

**Author**: Wakeem Williams
**Date**: 2026-03-20
**Purpose**: Single source of truth for where every type of content lives. Read this before creating anything.

---

## The 6 Platforms

| Platform | URL/Path | Purpose | Who Has Access |
|----------|----------|---------|---------------|
| **ClickUp** | app.clickup.com | Task management, compliance tracking, client delivery | Team + clients (scoped) |
| **Google Drive** | Shared Drive: "Helix Stax" | Document backup, compliance evidence archive, client files | Team + clients (separate drives) |
| **GitHub** | github.com/KeemWilliams + helix-stax org | Code, IaC, Git history | Team (private repos) |
| **Outline** | wiki.helixstax.com (future) | Wiki, knowledge base, client docs | Team + clients (scoped) |
| **Obsidian** | ~/HelixStax/vault/ | Drafting workspace, personal notes | Wakeem (synced to Drive for team read) |
| **Local** | ~/.claude/, agent configs | AI tooling, prompts, PACT configs | Wakeem only. NEVER shared. |

---

## Content Type to Platform Mapping

### Documents

| Content Type | Create In | Backup To | Sync To |
|-------------|----------|-----------|---------|
| Runbooks | ClickUp Docs | Google Drive (auto via n8n) | Outline |
| SOPs | ClickUp Docs | Google Drive | Outline |
| ADRs | ClickUp Docs + Git (docs/adr/) | Google Drive | Outline |
| Policies | ClickUp Docs | Google Drive (7yr retention) | Outline |
| Post-Mortems | ClickUp Docs | Google Drive | -- |
| Meeting Notes | ClickUp Docs | Google Drive | -- |
| Client Proposals | Google Drive (source) | -- | ClickUp (link) |
| SOWs / Contracts | Google Drive (source) | -- | ClickUp (link) |
| Compliance Reports | ClickUp (task) + Google Drive (PDF) | MinIO (WORM) | -- |

### Code and Infrastructure

| Content Type | Lives In | NEVER In |
|-------------|---------|----------|
| Application code | GitHub repos | Google Drive, ClickUp |
| OpenTofu modules | GitHub (helix-stax-infrastructure) | Google Drive |
| Ansible roles | GitHub (helix-stax-infrastructure) | Google Drive |
| Helm values | GitHub (helix-stax-infrastructure) | Google Drive |
| CI/CD pipeline config | GitHub + Devtron/ArgoCD | Google Drive, ClickUp |
| Kubernetes manifests | GitHub (GitOps via ArgoCD) | Anywhere else |
| Docker Compose (legacy) | GitHub (transitional, will be removed) | -- |

### Secrets and Credentials

| Content Type | Lives In | NEVER In |
|-------------|---------|----------|
| API keys | OpenBao (runtime) | Git, Google Drive, ClickUp, .env files |
| Database passwords | OpenBao | Anywhere else |
| TLS certificates | cert-manager (auto) | Git |
| Encrypted secrets in Git | SOPS + age encrypted files | Plaintext anywhere |
| SSH keys | ~/.ssh/ (local) + OpenBao | Git, Google Drive |
| Agent/service tokens | OpenBao + ESO | Hardcoded in code |

### Compliance Evidence

| Content Type | Lives In | Backup To | Retention |
|-------------|---------|-----------|-----------|
| Control evidence | ClickUp (UCM tasks) + MinIO | Google Drive | 7 years |
| Audit reports | Google Drive | MinIO (WORM) | 7 years |
| Pen test results | Google Drive (confidential) | MinIO | 7 years |
| Access review logs | ClickUp + Google Drive | MinIO | 7 years |
| Incident reports | ClickUp | Google Drive | 7 years |
| Policy documents | ClickUp Docs + Google Drive | MinIO | 7 years |

### Brand and Marketing

| Content Type | Lives In | Published To |
|-------------|---------|-------------|
| Logos (SVG, PNG, EPS) | Google Drive > Brand/ | GitHub (brand kit repo) |
| Style guide | Google Drive > Brand/ | Outline wiki |
| Social media assets | Google Drive > Marketing/ | Social platforms |
| Website content | GitHub (website repo) | helixstax.com |
| SEO research | ClickUp (Product & Strategy) | -- |

### AI Tooling (LOCAL ONLY)

| Content Type | Lives In | NEVER In |
|-------------|---------|----------|
| CLAUDE.md files | ~/.claude/ + project roots | Google Drive, ClickUp |
| Agent definitions | ~/.claude/agents/ | Google Drive |
| PACT memory DB | ~/.claude/pact-memory/ | Google Drive |
| Agent registry | ~/.claude/pact-registry/ | Google Drive |
| Gemini/Google prompts | Local repo (docs/) | Google Drive |
| Skills and hooks | ~/.claude/skills/, hooks/ | Google Drive |

---

## Google Shared Drive Structure

### HELIX STAX (Main Shared Drive)

```
Helix Stax/
  01 Infrastructure/
    Architecture Diagrams/
    Runbooks/ (auto-sync from ClickUp)
    Network Diagrams/
    K3s Cluster Docs/
    Backup Verification Reports/
  02 Compliance/
    Policies/ (versioned, master copies)
    SOPs/ (auto-sync from ClickUp)
    Evidence/
      2026/
        Q1/
        Q2/
    Audit Reports/
    Framework Mappings/
    Risk Assessments/
    Access Reviews/
    Pen Test Reports/
  03 Brand/
    Logos/
    Color Palette/
    Typography/
    Style Guide/
    Document Templates (LaTeX + Google Docs)/
    Social Media Assets/
    Email Signatures/
  04 Website/
    Content/
    SEO Research/
    Analytics Reports/
    Design Assets/
  05 Business/
    Business Plan/
    Proposals & Quotes/
    Contracts & Agreements/
    NDAs/
    Partnership Docs/
    Meeting Notes/
  06 Finance/
    Invoices/
    Tax Documents/
    Receipts/
    Vendor Contracts/
    Tool Subscriptions/
  07 HR & Operations/
    Onboarding Materials/
    Training Materials/
    Employee Handbook/
  08 Engineering/
    ADRs/ (auto-sync from Git)
    API Documentation/
    Technical Specs/
    Post-Mortems/
  09 Obsidian Vault/ (read-only sync)
    [Mirror of local vault for team access]
    [Exclude: .obsidian/, personal notes]
  10 Backups/ (auto via n8n)
    ClickUp Docs/ (daily PDF export)
    Git Repo Archives/ (weekly snapshots)
```

### Per-Client Shared Drive (separate drive per client)

```
Client: {Name}/
  00 Onboarding/
    Contract & SOW/
    NDA/
    BAA or DPA (if applicable)/
    Welcome Pack/
  01 Deliverables/
    Reports/
    Documentation/
    Configurations/
  02 Compliance/
    CTGA Assessment Results/
    Evidence Collection/
    Risk Assessment/
    POA&M/
  03 Infrastructure/
    Environment Documentation/
    Network Diagrams/
    Access Matrix/
  04 Support/
    Incident Reports/
    Change Requests/
    Meeting Notes/
  05 Billing/
    Invoices/
    Quotes/
```

---

## Cross-Platform Naming Consistency

Same numbered structure everywhere:

| ClickUp Folder | Google Drive Folder | Outline Collection | Git Repo Directory |
|----------------|--------------------|--------------------|-------------------|
| 01 Business Operations | 05 Business/ | Business | -- |
| 02 Platform Engineering | 01 Infrastructure/ | Infrastructure | docs/ |
| 03 Security Operations | 02 Compliance/ (subset) | Security | docs/runbooks/ |
| 04 Service Management | -- | Operations | -- |
| 05 Compliance Program | 02 Compliance/ | Compliance | docs/compliance-templates/ |
| 06 Process Library | 01 Infrastructure/Runbooks/ | Runbooks & SOPs | docs/templates/ |
| 07 Product & Strategy | 04 Website/ + 05 Business/ | Product | -- |

---

## Decision Tree: Where Do I Put This?

```
Is it code or infrastructure config?
  YES → GitHub repo
  NO ↓

Is it a secret, API key, or credential?
  YES → OpenBao (runtime) or SOPS (Git-encrypted)
  NO ↓

Is it AI tooling (CLAUDE.md, agents, prompts, PACT)?
  YES → LOCAL ONLY (~/.claude/ or local docs/)
  NO ↓

Is it a task, ticket, or trackable work item?
  YES → ClickUp
  NO ↓

Is it a client deliverable or contract?
  YES → Google Drive (client's Shared Drive)
  NO ↓

Is it a policy, SOP, or runbook?
  YES → ClickUp Docs (source) → Google Drive (backup) → Outline (wiki)
  NO ↓

Is it compliance evidence?
  YES → ClickUp (task link) + MinIO (WORM archive) + Google Drive (backup)
  NO ↓

Is it a brand asset or marketing material?
  YES → Google Drive > Brand/
  NO ↓

Is it a draft or personal note?
  YES → Obsidian vault
  NO → Ask Wakeem
```

---

## Sync Automations (n8n, after n8n is deployed)

| Trigger | From | To |
|---------|------|-----|
| ClickUp Doc updated | ClickUp | Google Drive (PDF export) |
| Git push | GitHub | Google Drive (repo archive) |
| Compliance task completed | ClickUp | MinIO (evidence archive) + Google Drive |
| Obsidian vault committed | Git | Google Drive > Obsidian Vault/ |
| Client report generated | ClickUp/LaTeX | Client Google Drive + ClickUp attachment |

---

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation Lead)
**Date**: 2026-03-20
**Version**: 1.0
