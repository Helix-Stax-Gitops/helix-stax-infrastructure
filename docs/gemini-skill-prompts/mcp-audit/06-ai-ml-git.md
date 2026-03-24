# MCP Audit — 06: AI/ML & Git

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: Local inference, LLM APIs, vector databases, embedding stores, Git platforms

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
Find EVERY MCP server for AI/ML and Git tools. Search glama.ai, smithery.ai, mcpservers.org, npm, PyPI, and GitHub.

**AI/ML — Local Inference:**
- Ollama (local inference)
- Open WebUI
- vLLM / LocalAI / LMStudio

**AI/ML — Cloud APIs:**
- Hugging Face (models, datasets, spaces)
- OpenAI API
- Anthropic API (Claude)
- Google Gemini API
- Cohere
- Replicate
- Together AI
- Groq

**AI/ML — Orchestration:**
- LangChain / LangSmith / LangGraph
- LlamaIndex
- MLflow
- Weights & Biases

**AI/ML — Vector & Embeddings:**
- pgvector
- Pinecone
- Weaviate
- Qdrant
- ChromaDB

**Git & Code:**
- GitHub (I already have github-core — are there better/additional ones?)
- GitLab
- Bitbucket
- Sourcegraph (code search)
- Generic Git operations

For each MCP found:
| Tool | MCP Server | Repo URL | Package | Stars/Updated | Install Command | Transport | Auth | Maturity | Workers? | Recommendation |
</task>

<output_format>
Return your findings as:

1. **Master Table** — one row per confirmed MCP server; flag github-core with "(HAVE)"
2. **Ollama Focus** — dedicated section: does the Ollama MCP support model management (pull/list/delete) or only inference? Any Open WebUI MCP?
3. **pgvector Note** — does any MCP expose pgvector specifically, or is it handled via the generic postgres MCP?
4. **GitHub Upgrade Check** — are there better GitHub MCPs than the standard one? Compare feature coverage.
5. **Coverage Gaps** — tools with NO MCP and recommended workarounds
</output_format>
