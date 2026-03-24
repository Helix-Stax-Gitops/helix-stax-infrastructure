# MCP Audit — 07: Automation, Communications, PM & Docs

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Workflow automation, chat platforms, project management, documentation, file processing, CRM, finance

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for automation, communication, project management, and documentation tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

**Automation:**
- n8n (I already have n8n-automation)
- Temporal
- Windmill
- Make / Zapier
- Pipedream
- IFTTT

**Communication:**
- Rocket.Chat
- Slack
- Discord
- Microsoft Teams
- Matrix / Element
- Telegram (bot API)
- Email (SMTP/IMAP generic)
- Twilio (SMS)
- SendGrid / Mailgun / Resend

**Project Management:**
- ClickUp (I already have clickup-pm)
- Linear
- Jira / Atlassian
- Notion
- Todoist
- Asana
- Monday.com
- Shortcut

**Documentation & Knowledge:**
- Obsidian (I already have obsidian-docs)
- Outline
- Confluence
- Backstage
- GitBook
- Mintlify

**Other Utilities:**
- File processing (PDF, Image, Video, OCR, Pandoc)
- Browser automation (Playwright, Puppeteer)
- Backup tools (Velero, Restic, Kopia, Borg)
- CRM (HubSpot, Salesforce, Freshdesk, Zendesk)
- Finance (Stripe, Invoice Ninja, QuickBooks)

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server; flag n8n-automation, clickup-pm, obsidian-docs with "(HAVE)"
2. **Rocket.Chat Focus** — dedicated section: does ANY MCP exist for Rocket.Chat? If not, what is the best alternative for agent-to-channel messaging?
3. **Outline & Backstage** — do MCPs exist for either? These are self-hosted tools with REST APIs.
4. **Coverage Gaps** — tools with NO MCP; note which have well-documented REST APIs suitable for custom MCP builds
5. **Upgrade Candidates** — better alternatives to my existing n8n-automation, clickup-pm, or obsidian-docs MCPs?
</output_format>
