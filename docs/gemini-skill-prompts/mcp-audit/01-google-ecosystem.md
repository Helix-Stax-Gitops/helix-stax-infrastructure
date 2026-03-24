# MCP Audit — 01: Google Ecosystem

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Google APIs, Google Cloud services, Google Workspace, marketing tools, Firebase

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server that exists for Google services. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

Tools to audit:
- Gmail API (send, read, search, labels, filters)
- Google Drive (files, folders, permissions, Shared Drives)
- Google Calendar (events, scheduling, resources)
- Google Sheets (read, write, formulas)
- Google Docs (read, create, edit)
- Google Slides
- Google Forms
- Google Workspace Admin SDK (Directory API, Reports API, Org Units)
- Google Cloud KMS (key management, encryption)
- Google Cloud IAM (roles, policies, service accounts)
- Google Cloud Storage (buckets, objects)
- Google Cloud Pub/Sub
- Google Cloud Logging
- Google Cloud Monitoring
- Google Cloud DNS
- Google Cloud Armor
- Google Cloud Run / Functions
- Gemini API / Vertex AI
- Google Search Console
- Google Analytics (GA4)
- Google Tag Manager
- Google Maps / Places API
- Google Ads API
- Firebase

For each MCP found, provide a table row with:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |

Also list which Google services have NO MCP and what the alternative is (CLI, API, custom build).
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server found
2. **Coverage Gaps** — table of tools with NO MCP, with recommended alternatives
3. **Priority Picks** — your top 3-5 MCPs to install for a Google Workspace + GCP user
4. **Custom Build Candidates** — tools worth building a custom MCP for (rank by effort vs value)
</output_format>
