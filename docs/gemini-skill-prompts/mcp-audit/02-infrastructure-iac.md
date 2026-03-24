# MCP Audit — 02: Infrastructure & IaC

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Kubernetes, container runtimes, IaC tools, Hetzner, cluster management

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for infrastructure and IaC tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

Tools to audit:
- Kubernetes / K3s (cluster management, kubectl operations)
- Helm (chart management, releases)
- ArgoCD (application sync, health, rollback)
- Devtron (pipeline management, builds)
- vCluster (virtual cluster management)
- Hetzner Cloud (servers, networks, firewalls, volumes)
- Docker (containers, images, builds)
- Podman
- containerd
- Rancher
- Portainer
- OpenTofu / Terraform (plan, apply, state — I already have opentofu-iac)
- Ansible (playbooks, inventory — I already have ansible-ops)
- Pulumi
- Crossplane
- cert-manager (certificate management)
- CoreDNS
- Flannel / Cilium / Calico (CNI)

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |

For tools without MCP, recommend: CLI name, install command, whether output is JSON-structured, and whether a custom MCP is worth building.
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server found
2. **Coverage Gaps** — table of tools with NO MCP; include CLI alternative and JSON-output flag
3. **Upgrade Candidates** — are there better alternatives to my existing opentofu-iac or ansible-ops MCPs?
4. **Custom Build Candidates** — top tools to build a custom MCP for (rank by effort vs operational value on K3s)
</output_format>
