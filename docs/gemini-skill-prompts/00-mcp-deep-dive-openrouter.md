# MCP Server Ecosystem Audit — Tongyi DeepResearch Format

## System Prompt (set in OpenRouter)

```
You are Tongyi DeepResearch, an expert AI infrastructure analyst specializing in Model Context Protocol (MCP) servers, AI agent tooling, and cloud-native infrastructure.

Your task is to produce exhaustive, structured research reports. Use <think> blocks for your reasoning process. Be thorough — enumerate every option, not just popular ones.

Formatting Rules:
- Use Markdown for lists, tables, and styling
- Use ```code fences``` for all code blocks
- Format file names, paths, and function names with `inline code` backticks
- For responses with many sections, use collapsible sections (HTML details/summary tags) to organize information
- Every recommendation must include: repository URL, install command, maturity rating, and rationale
```

## Prompt (send as user message)

<context>
I run Helix Stax, a small IT consulting company operating a 23-agent autonomous AI ecosystem using Claude Code (Anthropic) and Gemini CLI (Google). My agents need structured, programmatic access to 50+ infrastructure tools via Model Context Protocol (MCP).

MCP is an open standard (by Anthropic) that wraps tools as JSON-RPC servers. Agents connect via stdio (local) or SSE (remote). MCP servers expose Tools (callable functions), Resources (readable data), and Prompts (templates).

My current stack:
- K3s on AlmaLinux 9.7, Hetzner Cloud (2 nodes)
- Cloudflare CDN/WAF/Zero Trust, Traefik ingress
- CloudNativePG (PostgreSQL), Valkey (cache), MinIO (S3), Harbor (registry)
- Zitadel (identity), OpenBao (secrets), CrowdSec/Kyverno/NeuVector (security)
- Devtron + ArgoCD (CI/CD), OpenTofu + Ansible (IaC)
- Prometheus + Grafana + Loki + Alertmanager (monitoring)
- n8n (automation), Rocket.Chat (comms), Backstage + Outline (portals)
- Ollama + Open WebUI + SearXNG + pgvector (AI)
- Google Workspace Enterprise Standard, ClickUp (PM)

I currently have 15 MCP servers configured:
github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry
</context>

<task>
Produce a comprehensive MCP server ecosystem audit covering these areas:

## PART 1: MCP Servers for My Stack

For EACH tool in my stack, find every available MCP server. Search these registries:
- glama.ai (primary — catalog EVERYTHING listed there)
- modelcontextprotocol.io, mcp.so, smithery.ai, mcpservers.org, pulsemcp.com
- npm (@modelcontextprotocol/*, mcp-server-*, mcp-*)
- PyPI (mcp-*, fastmcp-*)
- GitHub (search "mcp-server-{tool}", "{tool}-mcp")
- Docker Hub (*-mcp*)

For each MCP found, provide:
| Field | Required |
|-------|----------|
| Repository URL | Yes |
| Package name | Yes |
| Stars / last update | Yes |
| Install command | Yes |
| Transport (stdio/SSE) | Yes |
| Key tools exposed | Yes |
| Auth method | Yes |
| Maturity (production/beta/experimental) | Yes |
| Cloudflare Workers compatible? | Yes |
| Recommendation (add/skip/watch) | Yes |

Cover ALL of these categories:

**Google Ecosystem** (find EVERY Google MCP):
Gmail, Drive, Calendar, Sheets, Docs, Slides, Forms, Admin SDK, Cloud KMS, Cloud IAM, Cloud Storage, Cloud Pub/Sub, Cloud Logging, Cloud Monitoring, Gemini API, Vertex AI, Search Console, Analytics, Maps, Ads, Firebase, Cloud DNS, Cloud Armor, Cloud Run

**Infrastructure**: Kubernetes, Helm, ArgoCD, Devtron, vCluster, Hetzner Cloud, Docker, Rancher, Portainer

**IaC**: OpenTofu/Terraform, Ansible, Pulumi, Crossplane

**Databases**: PostgreSQL, MySQL, Valkey/Redis, MinIO, MongoDB, SQLite, Elasticsearch, ClickHouse, Neo4j, Supabase

**Identity**: Zitadel, Keycloak, Auth0, LDAP, SAML

**Security**: OpenBao/Vault, Trivy, CrowdSec, Kyverno, NeuVector, Falco, Cosign, Gitleaks, SOPS, Snyk, SonarQube, Wazuh, OWASP ZAP, Grype

**Monitoring**: Prometheus, Grafana, Loki, Alertmanager, OpenTelemetry, Tempo, Jaeger, Mimir, Thanos, Datadog, PagerDuty

**Networking**: Cloudflare (all services), Traefik, Nginx, Caddy, cert-manager, CoreDNS, Cilium, Tailscale, WireGuard, NetBird

**Automation**: n8n, Temporal, Windmill, Zapier, Pipedream

**Communication**: Rocket.Chat, Slack, Discord, Teams, Matrix, Telegram, Twilio, SendGrid, Resend

**Storage**: Harbor, Docker Hub, GHCR, Backblaze B2, Cloudflare R2, S3

**Project Management**: ClickUp, Linear, Jira, Notion, Todoist, Asana

**Documentation**: Obsidian, Outline, Confluence, Backstage, GitBook, Mintlify

**AI/ML**: Ollama, Open WebUI, Hugging Face, LangChain, OpenAI, Anthropic, Gemini, Cohere, Replicate, pgvector, Pinecone, Weaviate, Qdrant, ChromaDB, MLflow

**Git**: GitHub, GitLab, Bitbucket, Sourcegraph

**Compliance**: OCS Inventory, Fleet, OpenSCAP, Drata, Wazuh

**Website**: Astro, Next.js, Vercel, Playwright, Puppeteer

**File Processing**: PDF, Image (Sharp/ImageMagick), Video (FFmpeg), OCR, Pandoc

**Backup**: Velero, Restic, Kopia, Borg

**CRM/Business**: HubSpot, Salesforce, Freshdesk, Zendesk, Stripe, Invoice Ninja

## PART 2: MCP Development Frameworks

Find every SDK and framework for BUILDING custom MCP servers:
- Official SDKs (Python, TypeScript, Go, Rust, Java, C#)
- Community frameworks (FastMCP, etc.)
- MCP tooling (Inspector, CLI tools, schema generators, proxy tools, aggregators)
- Hosting patterns (local, Cloudflare Workers, K8s, Docker)
- Custom server templates (REST wrapper, CLI wrapper, DB wrapper)

## PART 3: MCP Ecosystem Health

- Current MCP spec version and roadmap
- Security best practices
- Performance patterns
- Testing patterns
- Anti-patterns to avoid

## PART 4: Recommendations

- Top 30 MCP servers to add (ranked by impact)
- Which can run on Cloudflare Workers
- Custom MCPs worth building
- CLI cheat sheets for tools without MCP
</task>

<output_format>
Structure as a massive reference document with:
1. Executive Summary (totals: found, recommended, skip, build custom)
2. Category-by-category tables (one table per category)
3. CLI-only tools table
4. Top 30 recommendations (ranked)
5. Development frameworks table
6. Custom MCPs to build table
7. Ecosystem health summary

Use collapsible sections for large categories. Every recommendation must have an install command.
</output_format>
