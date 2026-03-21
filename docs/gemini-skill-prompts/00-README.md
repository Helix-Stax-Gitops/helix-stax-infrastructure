# Gemini Deep Research Prompts — Tool Skills

Fire each prompt into Gemini Deep Research one at a time.
For grouped prompts, Gemini outputs `# Tool Name` headers — split into separate `~/.claude/skills/{tool-name}/SKILL.md` files.

## Prompts (21 total)

| # | Prompt | Tools | Skills Out |
|---|--------|-------|------------|
| 01 | Edge & Ingress | Cloudflare, Traefik, Helm | 3 |
| 02 | GitOps CI/CD | ArgoCD, Devtron | 2 |
| 03 | IaC Pipeline | OpenTofu, Ansible | 2 |
| 04 | PostgreSQL Stack | CloudNativePG, DBA, pgvector, RuVector | 3-4 |
| 05 | Cache & Queue | Valkey | 1 |
| 06 | Storage Chain | MinIO, Harbor, Backblaze B2 | 3 |
| 07 | Identity | Zitadel, Google Workspace | 2 |
| 08 | Security Stack | CrowdSec, Kyverno, NeuVector, Gitleaks | 4 |
| 09 | Secrets Pipeline | OpenBao, SOPS, ESO | 3 |
| 10 | Observability Metrics | Prometheus, Grafana, Alertmanager | 3 |
| 11 | Logging Pipeline | Loki, Promtail/Alloy | 2 |
| 12 | Tracing Pipeline | OpenTelemetry, Tempo | 2 |
| 13 | Internal Portals | Backstage, Outline | 2 |
| 14 | Communication | Rocket.Chat, Postal | 2 |
| 15 | Backup & DR | Velero | 1 |
| 16 | K8s Fundamentals | K3s, kubectl, YAML | 3 |
| 17 | Infrastructure Base | AlmaLinux, Networking, Hetzner | 3 |
| 18 | Container Supply Chain | Docker/OCI, Harbor builds | 2 |
| 19 | AI & ML Stack | Ollama, Open WebUI, SearXNG (+future) | 3+ |
| 20 | Automation + Website | n8n, cert-manager, Flannel, Astro, Git | 5 |
| 21 | Integration Capstone | All tools together | 1 |

---

## Prompt Directories

| # | Directory |
|---|-----------|
| 01 | `01-edge-ingress/` |
| 02 | `02-gitops-cicd/` |
| 03 | `03-iac-pipeline/` |
| 04 | `04-postgresql-stack/` |
| 05 | `05-cache-queue/` |
| 06 | `06-storage-chain/` |
| 07 | `07-identity/` |
| 08 | `08-security-stack/` |
| 09 | `09-secrets-pipeline/` |
| 10 | `10-observability-metrics/` |
| 11 | `11-logging-pipeline/` |
| 12 | `12-tracing-pipeline/` |
| 13 | `13-internal-portals/` |
| 14 | `14-communication/` |
| 15 | `15-backup-dr/` |
| 16 | `16-k8s-fundamentals/` |
| 17 | `17-infrastructure-base/` |
| 18 | `18-container-supply-chain/` |
| 19 | `19-ai-ml-stack/` |
| 20 | `20-automation-website/` |
| 21 | `21-integration-capstone/` |
