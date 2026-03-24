---
title: "Claude-Gemini Bridge Architecture"
type: architecture
status: active
author: Wakeem Williams
co_author: Quinn Mercer
created: 2026-03-23
last_updated: 2026-03-23
tags: [ai, architecture, claude-code, gemini-cli, mcp, agents, bridge]
references:
  - docs/architecture/dual-workflow-architecture.md
  - docs/architecture/defense-in-depth-architecture.md
  - docs/architecture/secrets-lifecycle-architecture.md
---

# Claude-Gemini Bridge Architecture

## 1. Overview

Helix Stax operates a dual-engine AI architecture. Claude Code and Gemini CLI
serve fundamentally different roles, chosen for the strengths of their
underlying models rather than arbitrary preference.

**Claude Code** is the orchestrator and sole code mutator. It manages the PACT
framework's 20-agent swarm, performs iterative file edits, drives task
management through ClickUp, triggers n8n automations, and controls all
write operations across the infrastructure stack.

**Gemini CLI** is the read-only analytical engine. Its 1M+ token context
window handles workloads that would exhaust Claude's 200K window: bulk log
analysis, deep research with citations, compliance matrix construction,
full-repository architectural review, and SBOM/CVE processing across
hundreds of files simultaneously.

Neither engine replaces the other. They are complementary:

```
+-------------------------------+       +-------------------------------+
|        CLAUDE CODE            |       |         GEMINI CLI            |
|  (Orchestrator + Mutator)     |       |    (Analyst + Researcher)     |
+-------------------------------+       +-------------------------------+
| - 20 PACT agents (Agent Teams)|       | - 10 analytical subagents     |
| - File editing (Read/Write)   |       | - 1M+ token context window    |
| - Task management (ClickUp)   |       | - Deep research with citations|
| - Infrastructure deployment   |       | - Bulk data processing        |
| - Secret management (OpenBao) |       | - Compliance evidence review  |
| - CI/CD orchestration         |       | - Log/metric pattern analysis |
| - Code review + PR workflow   |       | - SBOM + vulnerability triage |
| - n8n workflow deployment     |       | - Full-repo architecture scan |
+-------------------------------+       +-------------------------------+
        |                                        ^
        |  gemini -p "..." > output.md           |
        +----------------------------------------+
        Claude invokes Gemini headless via Bash
```

### Design Principles

1. **Gemini never writes.** All file mutations flow through Claude agents.
2. **Claude reviews all Gemini output.** No Gemini analysis is acted upon
   without Claude agent validation.
3. **No secrets in prompts.** Gemini receives analysis tasks, never credentials.
4. **Context routing by size.** Tasks exceeding ~150K tokens route to Gemini.
5. **MCP sharing is read-only.** Gemini accesses shared MCPs for queries only.

---

## 2. MCP Sharing Model

MCPs are partitioned by write sensitivity. Gemini receives a read-only
subset. Claude retains exclusive access to all state-mutating MCPs.

```
+-------------------------------------------------------------------+
|                        MCP TOPOLOGY                               |
+-------------------------------------------------------------------+
|                                                                   |
|  SHARED (Read-Only to Gemini)          CLAUDE-ONLY (Write Ops)    |
|  +-----------------------------+       +------------------------+ |
|  | github-core                 |       | clickup-pm             | |
|  | postgres-db                 |       | n8n-automation         | |
|  | grafana-obs                 |       | zitadel-iam            | |
|  | loki-logs                   |       | openbao-vault          | |
|  | obsidian-docs               |       | ansible-ops            | |
|  | trivy-sec                   |       | opentofu-iac           | |
|  | google-workspace            |       | harbor-registry        | |
|  | cloudflare-edge             |       | valkey-cache           | |
|  +-----------------------------+       | gdrive-docs            | |
|                                        | clickup (Anthropic)    | |
|                                        +------------------------+ |
|                                                                   |
|  CLOUDFLARE REMOTE MCPs (via mcp-remote SSE)                     |
|  +-----------------------------+                                  |
|  | observability  (connected)  |  Both engines can connect.      |
|  | workers-ai                  |  Claude: full access.           |
|  | kv                          |  Gemini: read-only queries.    |
|  | d1                          |                                  |
|  | r2                          |                                  |
|  | browser-rendering           |                                  |
|  | vectorize                   |                                  |
|  | durable-objects             |                                  |
|  | queues                      |                                  |
|  | casb                        |                                  |
|  +-----------------------------+                                  |
|                                                                   |
|  GOOGLE MCPs                                                      |
|  +-----------------------------+                                  |
|  | google-workspace (Worker)   |  Deployed as Cloudflare Worker. |
|  | gcloud CLI (npm)            |  KMS, IAM, DNS, Storage.       |
|  +-----------------------------+                                  |
+-------------------------------------------------------------------+
```

### Shared MCP Details

| MCP Server        | Transport | Package / Endpoint                                  | Gemini Access Level  |
|-------------------|-----------|------------------------------------------------------|----------------------|
| github-core       | stdio     | `npx -y @modelcontextprotocol/server-github`         | Read repos, PRs, issues |
| postgres-db       | stdio     | `npx -y @henkey/postgres-mcp-server`                 | SELECT queries only  |
| grafana-obs       | stdio     | `npx -y @grafana/mcp-grafana`                        | Read dashboards, PromQL |
| loki-logs         | docker    | `public.ecr.aws/cardinalhq.io/loki-mcp`              | Query log lines      |
| obsidian-docs     | stdio     | `uvx mcp-obsidian-advanced`                           | Read vault, graph    |
| trivy-sec         | stdio     | `npx -y @aquasecurity/trivy-mcp`                     | Read scan results    |
| google-workspace  | SSE       | Cloudflare Worker (custom)                            | Read Docs, Sheets    |
| cloudflare-edge   | SSE       | `https://observability.mcp.cloudflare.com/sse`       | Read analytics       |

### Claude-Only MCP Details

| MCP Server        | Transport | Package / Endpoint                                  | Why Claude-Only          |
|-------------------|-----------|------------------------------------------------------|--------------------------|
| clickup-pm        | stdio     | `npx -y @taazkareem/clickup-mcp-server`             | Task CRUD, state mutation |
| n8n-automation    | stdio     | `npx -y n8n-mcp-server`                             | Workflow deployment       |
| zitadel-iam       | stdio     | `npx -y zitadel-mcp`                                | Identity lifecycle        |
| openbao-vault     | stdio     | `npx -y @hashicorp/vault-mcp-server`                | Secret management         |
| ansible-ops       | stdio     | `npx -y @ansible/mcp-server`                        | Playbook execution        |
| opentofu-iac      | stdio     | `npx -y @opentofu/mcp-server`                       | State-altering IaC        |
| harbor-registry   | stdio     | `npx -y mcp-harbor`                                 | Registry mutations        |

---

## 3. Agent Tool Permission Matrix

### 3.1 Claude Code Agents (20)

| #  | Agent                  | Persona           | Phase    | Permitted MCPs                              | Authorized CLIs                                |
|----|------------------------|--------------------|----------|---------------------------------------------|------------------------------------------------|
| 1  | stax-product-manager   | Sable Navarro      | Prepare  | clickup-pm, github-core                     | gh                                             |
| 2  | stax-preparer          | Remy Alcazar       | Prepare  | obsidian-docs, github-core, google-workspace | --                                             |
| 3  | stax-scout-integrations| Scout Calloway     | Prepare  | github-core, obsidian-docs                  | --                                             |
| 4  | stax-architect         | Cass Whitfield     | Architect| obsidian-docs, grafana-obs, github-core     | --                                             |
| 5  | stax-ui-designer       | Lena Takeda        | Architect| obsidian-docs                               | --                                             |
| 6  | stax-backend-coder     | Dax Okafor         | Code     | postgres-db, valkey-cache                   | docker                                         |
| 7  | stax-frontend-coder    | Wren Ashby         | Code     | github-core                                 | --                                             |
| 8  | stax-database-engineer | Soren Lindqvist    | Code     | postgres-db                                 | psql                                           |
| 9  | stax-devops-engineer   | Kit Morrow         | Code     | opentofu-iac, ansible-ops, cloudflare-edge  | kubectl, helm, vcluster, hcloud, argocd        |
| 10 | stax-n8n               | Nix Patel          | Code     | n8n-automation                              | n8n                                            |
| 11 | stax-test-engineer     | Petra Vanek        | Test     | github-core                                 | gh, docker                                     |
| 12 | stax-security-engineer | Ezra Raines        | Review   | openbao-vault, trivy-sec, zitadel-iam       | sops, cosign, gitleaks, cscli, kyverno         |
| 13 | stax-qa-engineer       | Bex Cordero        | Review   | github-core                                 | gh, docker                                     |
| 14 | stax-vigil-monitor     | Vigil Frost        | Review   | loki-logs, grafana-obs, cloudflare-edge     | otelcol                                        |
| 15 | stax-memory-agent      | Clio Amari         | Memory   | obsidian-docs                               | python                                         |
| 16 | stax-scribe            | Quinn Mercer       | Support  | obsidian-docs, google-workspace             | --                                             |
| 17 | stax-scribe-l1         | Quinn L1           | Support  | obsidian-docs                               | --                                             |
| 18 | stax-scribe-l3         | Quinn L3           | Support  | obsidian-docs, google-workspace             | --                                             |
| 19 | stax-sage-seo          | Sage Holloway      | Support  | google-workspace                            | --                                             |
| 20 | stax-pixel             | Pixel Zheng        | Code     | --                                          | --                                             |

### 3.2 Gemini CLI Agents (10)

All Gemini agents are **read-only**. They cannot write files, execute
destructive commands, or access write-capable MCPs.

| #  | Agent                | Focus                     | Permitted MCPs                                | Authorized CLIs        |
|----|----------------------|---------------------------|-----------------------------------------------|------------------------|
| 1  | research-analyst     | Deep research, citations  | github-core, obsidian-docs, google-workspace  | --                     |
| 2  | bulk-analyzer        | Large dataset processing  | postgres-db, loki-logs                        | --                     |
| 3  | trivy-scanner        | CVE triage, SBOM review   | trivy-sec                                     | trivy (read-only)      |
| 4  | compliance-auditor   | SOC2/ISO/HIPAA matrices   | github-core, obsidian-docs, google-workspace  | --                     |
| 5  | log-analyzer         | Log pattern detection     | loki-logs, grafana-obs                        | --                     |
| 6  | config-validator     | K8s manifest validation   | github-core                                   | kubectl (get/describe) |
| 7  | schema-mapper        | DB schema documentation   | postgres-db                                   | --                     |
| 8  | sbom-analyzer        | Supply chain analysis     | trivy-sec, github-core                        | syft (read-only)       |
| 9  | skill-researcher     | Tool/framework research   | github-core, obsidian-docs                    | --                     |
| 10 | n8n-workflow-analyzer| Workflow audit, validation | --                                            | --                     |

---

## 4. Headless Execution Pattern

Claude invokes Gemini via the Bash tool. Gemini runs headless, processes
the prompt, and writes structured output to a file that Claude agents
subsequently read and act upon.

### Invocation Patterns

**Basic prompt:**
```bash
gemini -p "Analyze the K3s cluster RBAC bindings for SOC 2 compliance gaps" \
  > shared/scripts/gemini-outputs/rbac-audit-$(date +%Y%m%d).md
```

**Agent-specific (uses a subagent persona):**
```bash
gemini -p "@compliance-auditor Review these 200 Trivy scan results and \
  produce a consolidated CVE risk matrix with CVSS scores" \
  > shared/scripts/gemini-outputs/cve-matrix-$(date +%Y%m%d).md
```

**All-files mode (ingests entire repo into context):**
```bash
gemini --all_files -p "Map all service dependencies in this repository. \
  Identify circular dependencies and undocumented API contracts." \
  > shared/scripts/gemini-outputs/dependency-map-$(date +%Y%m%d).md
```

### Output Conventions

| Convention              | Value                                          |
|-------------------------|------------------------------------------------|
| Output directory        | `shared/scripts/gemini-outputs/`               |
| File naming             | `{task-slug}-{YYYYMMDD}.md`                    |
| Format                  | Markdown with YAML frontmatter                 |
| Top-level headers       | `# Tool Name` for grouped topics (splittable)  |
| Required sections       | Summary, Findings, Recommendations             |
| Structured data         | JSON code blocks for machine-parseable results |

### Integration Flow

```
Claude Agent                    Gemini CLI                     Output File
    |                               |                              |
    |-- Bash: gemini -p "..." ----->|                              |
    |                               |-- Process (1M ctx) -------->|
    |                               |-- Write output ------------>|
    |<-- Bash exit code ------------|                              |
    |                                                              |
    |-- Read: gemini-outputs/file.md ----------------------------->|
    |                                                              |
    |-- Validate findings                                          |
    |-- Act on recommendations                                     |
    |-- Update ClickUp tasks                                       |
```

---

## 5. When to Use Which

### Decision Framework

| Signal                                  | Route To     | Rationale                                    |
|-----------------------------------------|-------------|----------------------------------------------|
| Context > 200K tokens                   | **Gemini**  | Claude's window caps at 200K                 |
| Needs file editing / code mutation      | **Claude**  | Gemini is read-only by policy                |
| Deep research with citations            | **Gemini**  | Grounding + 1M context + web search          |
| Task management / ClickUp ops           | **Claude**  | Write-capable MCP, PACT integration          |
| Log analysis (thousands of lines)       | **Gemini**  | Bulk ingestion without context exhaustion     |
| Code review (iterative, per-file)       | **Claude**  | Agent Teams peer review workflow              |
| Compliance matrix construction          | **Gemini**  | Cross-reference hundreds of controls + docs   |
| Infrastructure deployment               | **Claude**  | OpenTofu/Ansible/Helm write operations        |
| SBOM / CVE bulk processing              | **Gemini**  | Hundreds of JSON reports in single pass       |
| Git operations (commit, PR, branch)     | **Claude**  | Native git tooling + hooks                    |
| Full-repo architectural analysis        | **Gemini**  | `--all_files` ingests entire codebase         |
| Secret management                       | **Claude**  | OpenBao MCP, never expose to Gemini           |
| n8n workflow validation (500+ nodes)    | **Gemini**  | Workflow JSON exceeds Claude context          |
| Identity lifecycle (Zitadel OIDC)       | **Claude**  | Write-capable MCP, auth state mutation        |

### Decision Flowchart

```
                    START: New Task
                         |
                   Does it require
                   writing files?
                   /            \
                 YES             NO
                  |               |
               CLAUDE        Is context
                             > 150K tokens?
                             /          \
                           YES           NO
                            |             |
                         GEMINI       Does it need
                                     live MCP writes?
                                     /          \
                                   YES           NO
                                    |             |
                                 CLAUDE       Either works.
                                              Prefer Claude
                                              for speed,
                                              Gemini for depth.
```

---

## 6. Cloudflare MCP Integration

Cloudflare provides 13 remote MCP servers accessible via SSE transport.
Both Claude and Gemini connect through the `mcp-remote` adapter, which
proxies the SSE connection and handles OAuth with Cloudflare Access.

### Available Cloudflare MCPs

| MCP Server         | Endpoint                                        | Use Case                        | Status       |
|--------------------|-------------------------------------------------|---------------------------------|--------------|
| Observability      | `observability.mcp.cloudflare.com/sse`          | Analytics, request logs         | Connected    |
| Workers AI         | `workers-ai.mcp.cloudflare.com/sse`             | AI inference at edge            | Available    |
| KV                 | `kv.mcp.cloudflare.com/sse`                     | Key-value store operations      | Available    |
| D1                 | `d1.mcp.cloudflare.com/sse`                     | SQLite database at edge         | Available    |
| R2                 | `r2.mcp.cloudflare.com/sse`                     | Object storage (S3-compatible)  | Available    |
| Browser Rendering  | `browser-rendering.mcp.cloudflare.com/sse`      | Headless browser, screenshots   | Available    |
| Vectorize          | `vectorize.mcp.cloudflare.com/sse`              | Vector embeddings at edge       | Available    |
| Durable Objects    | `durable-objects.mcp.cloudflare.com/sse`        | Stateful edge compute           | Available    |
| Queues             | `queues.mcp.cloudflare.com/sse`                 | Message queue operations        | Available    |
| CASB               | `casb.mcp.cloudflare.com/sse`                   | Cloud access security broker    | Available    |

### Connection Pattern

Both engines use the same `mcp-remote` npm package to establish SSE
connections. The adapter handles OAuth token refresh transparently.

```
settings.json (Claude or Gemini):

{
  "mcpServers": {
    "cloudflare-observability": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://observability.mcp.cloudflare.com/sse"]
    },
    "cloudflare-kv": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://kv.mcp.cloudflare.com/sse"]
    }
  }
}
```

### Access Control

- Claude agents with `cloudflare-edge` permission: full read/write
- Gemini agents with `cloudflare-edge` permission: read-only queries
- OAuth is per-account (Cloudflare dashboard), not per-engine
- Restrict Gemini's tool access via `excludeTools` in Gemini agent
  frontmatter to prevent write operations

---

## 7. Google MCP Integration

### Google Workspace Worker

A custom Cloudflare Worker deployed at the edge serves as the Google
Workspace MCP. It wraps the Google Workspace APIs (Docs, Sheets,
Calendar, Gmail) behind an SSE-compatible MCP interface.

```
+-----------+       +-------------------+       +------------------+
| Claude /  | SSE   | Cloudflare Worker | REST  | Google Workspace |
| Gemini    |------>| (Workspace MCP)   |------>| APIs             |
+-----------+       +-------------------+       +------------------+
                    | - OAuth2 token    |       | - Docs API       |
                    | - Rate limiting   |       | - Sheets API     |
                    | - Response format |       | - Calendar API   |
                    +-------------------+       | - Gmail API      |
                                                +------------------+
```

**Authentication flow:**
1. Worker holds a GCP Service Account key in Cloudflare Secrets
2. Service Account has Domain-Wide Delegation scoped to specific APIs
3. Worker impersonates admin@helixstax.com for API calls
4. No credentials pass through Claude or Gemini prompts

### gcloud CLI MCP

The `@anthropic/gcloud-mcp` npm package wraps the entire gcloud CLI,
providing structured MCP access to:

- **Cloud KMS**: SOPS key rotation, encryption boundary management
- **IAM**: Service account and permission auditing
- **Cloud DNS**: DNS record management
- **Cloud Storage**: Bucket operations for compliance evidence

Configuration:
```json
{
  "mcpServers": {
    "gcloud": {
      "command": "npx",
      "args": ["-y", "@anthropic/gcloud-mcp"]
    }
  }
}
```

---

## 8. Security Model

### Core Security Invariants

1. **Gemini is read-only, always.**
   - GEMINI.md explicitly prohibits writes (see `~/.gemini/GEMINI.md`)
   - Gemini subagent `tools` arrays restrict to `read_file`, `grep_search`
   - No write-capable MCPs are shared with Gemini
   - Gemini cannot execute `git commit`, `git push`, or file mutations

2. **Claude reviews all Gemini output.**
   - Gemini writes to `shared/scripts/gemini-outputs/`
   - Claude agents read those files, validate findings, then act
   - No automated pipeline directly applies Gemini recommendations

3. **No secrets in Gemini prompts.**
   - Credentials live in OpenBao, accessed only via Claude's `openbao-vault` MCP
   - Gemini prompt strings never contain API keys, tokens, or passwords
   - Environment variables are sourced by Claude before Gemini invocation;
     Gemini receives only the analytical task, never the env vars

4. **MCP access is least-privilege.**
   - Each agent (Claude or Gemini) receives only the MCPs required
     for its specific role (see Section 3)
   - Gemini's shared MCPs enforce read-only access at the server level
   - Claude-only MCPs handle all state mutations

### Threat Model

| Threat                              | Mitigation                                           |
|-------------------------------------|------------------------------------------------------|
| Gemini prompt injection writes file | `tools` array restricts to read ops; GEMINI.md rules |
| Secret leakage via Gemini prompt    | No secrets passed; OpenBao accessed only by Claude   |
| Gemini output contains malicious code | Claude agent validates before acting on any output  |
| MCP server exposes write ops to Gemini | Server-side read-only; `excludeTools` in config    |
| Gemini context poisoning            | Output isolated to `gemini-outputs/`; never auto-applied |
| Cross-engine credential leak        | Separate config files; no shared credential stores   |

### Audit Trail

```
Claude action on Gemini output:
1. Gemini invoked via Bash (logged in Claude transcript .jsonl)
2. Gemini output written to gemini-outputs/ (git-trackable)
3. Claude agent reads output (logged in transcript)
4. Claude agent acts on validated findings (logged + committed)
5. ClickUp task updated with outcome (audit trail in ClickUp)
```

All Gemini invocations produce artifacts in `shared/scripts/gemini-outputs/`.
These files are version-controlled, providing a complete audit trail of
what Gemini analyzed and what Claude acted upon.

---

## Appendix A: Configuration File Locations

| File                              | Purpose                                    |
|-----------------------------------|--------------------------------------------|
| `~/.claude/settings.json`        | Claude global MCP servers + permissions    |
| `~/.gemini/settings.json`        | Gemini global MCP servers (read-only subset)|
| `~/.gemini/GEMINI.md`            | Gemini global context (read-only mandate)  |
| `~/.gemini/agents/*.md`          | 10 Gemini analytical subagents             |
| `HelixStax/.claude/agents/*.md`  | 20 Claude PACT agents (project-local)      |
| `shared/scripts/gemini-outputs/` | All Gemini output artifacts                |

## Appendix B: Quick Reference Commands

```bash
# Basic Gemini research
gemini -p "Research best practices for K3s RBAC hardening" \
  > shared/scripts/gemini-outputs/rbac-research-$(date +%Y%m%d).md

# Compliance audit with specific agent
gemini -p "@compliance-auditor Generate SOC 2 CC6.1 evidence matrix \
  from current Zitadel OIDC configuration" \
  > shared/scripts/gemini-outputs/soc2-cc61-$(date +%Y%m%d).md

# Full-repo dependency analysis
gemini --all_files -p "Identify all service-to-service dependencies, \
  map them, and flag any undocumented contracts" \
  > shared/scripts/gemini-outputs/dep-analysis-$(date +%Y%m%d).md

# Log analysis (bulk)
gemini -p "@log-analyzer Analyze the last 24h of Traefik access logs \
  for anomalous traffic patterns. Output top 10 suspicious IPs." \
  > shared/scripts/gemini-outputs/traffic-anomalies-$(date +%Y%m%d).md

# CVE triage across all images
gemini -p "@trivy-scanner Process all Trivy JSON reports in \
  infrastructure/security/scans/ and produce a prioritized CVE matrix" \
  > shared/scripts/gemini-outputs/cve-triage-$(date +%Y%m%d).md
```
