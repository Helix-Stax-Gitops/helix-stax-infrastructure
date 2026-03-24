# MCP Audit — 05: Monitoring, Observability & Networking

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Prometheus stack, distributed tracing, ingress controllers, VPN/mesh networking

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for monitoring, observability, and networking tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

**Monitoring & Observability:**
- Prometheus (I access via grafana-obs)
- Grafana (I already have grafana-obs)
- Loki (I already have loki-logs)
- Alertmanager (I access via grafana-obs)
- OpenTelemetry
- Grafana Tempo
- Jaeger
- Grafana Mimir
- Thanos
- Datadog (for reference)
- PagerDuty (for reference)
- New Relic (for reference)

**Networking & Ingress:**
- Cloudflare — ALL services (I already have cloudflare-edge, but are there MORE Cloudflare MCPs?)
- Traefik
- Nginx / Nginx Proxy Manager
- Caddy
- Tailscale
- WireGuard
- NetBird
- Cloudflare WARP

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |

Are there better/additional Cloudflare MCPs beyond what I have?
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server; flag my existing MCPs with "(HAVE)"
2. **Cloudflare Deep-Dive** — dedicated section listing ALL Cloudflare MCPs found (not just one), with which Cloudflare services each covers
3. **Grafana Stack Gap Analysis** — which parts of the Grafana LGTM stack (Loki, Grafana, Tempo, Mimir) have dedicated MCPs vs are bundled vs are missing
4. **Coverage Gaps** — tools with NO MCP and recommended alternatives
</output_format>
