# MCP Audit — 03: Databases & Storage

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Relational DBs, NoSQL, object storage, container registries, cache layers

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for databases and storage tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

Tools to audit:
- PostgreSQL / CloudNativePG (I already have postgres-db)
- MySQL / MariaDB
- Valkey / Redis (I already have valkey-cache)
- MinIO / S3-compatible storage
- MongoDB
- SQLite
- Elasticsearch / OpenSearch
- ClickHouse
- CockroachDB
- Neo4j (graph database)
- Supabase
- Neon (serverless Postgres)
- Harbor (container registry — I already have harbor-registry)
- Docker Hub
- GitHub Container Registry (GHCR)
- Backblaze B2
- Cloudflare R2
- AWS S3 (for MinIO compatibility)

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |

Note which ones I already have and whether there are BETTER alternatives to my current MCP servers.
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server found; flag rows where I already have an MCP with "(HAVE)"
2. **Coverage Gaps** — storage/DB tools with NO MCP and recommended workarounds
3. **Upgrade Candidates** — better alternatives to postgres-db, valkey-cache, or harbor-registry if they exist
4. **MinIO Note** — does any MCP support the MinIO/S3-compatible API specifically, or only AWS S3?
</output_format>
