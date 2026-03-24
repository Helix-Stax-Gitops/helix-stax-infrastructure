# MCP Audit — 04: Identity & Security

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: IAM, secrets management, vulnerability scanning, SIEM, policy enforcement

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for identity and security tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

Tools to audit:
- Zitadel (I already have zitadel-iam)
- Keycloak
- Auth0
- OAuth2 / OIDC generic
- LDAP / Active Directory
- OpenBao / HashiCorp Vault (I already have openbao-vault)
- Trivy (I already have trivy-sec)
- CrowdSec
- Kyverno
- NeuVector
- Falco
- Cosign / Sigstore
- Gitleaks
- SOPS
- Snyk
- SonarQube
- Wazuh (SIEM)
- OWASP ZAP
- Grype
- OpenSCAP

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |

For tools without MCP, is it worth building a custom one? Rate priority (high/medium/low).
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server; flag my existing MCPs with "(HAVE)"
2. **Coverage Gaps** — security tools with NO MCP; include custom build priority rating (high/medium/low) and rationale
3. **CrowdSec Focus** — specific section: does any MCP exist for CrowdSec bouncer/hub/LAPI interaction?
4. **Upgrade Candidates** — are there better alternatives to zitadel-iam, openbao-vault, or trivy-sec?
</output_format>
