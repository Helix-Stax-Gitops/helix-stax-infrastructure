# Gemini Deep Research: AI & ML Stack

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
Ollama, Open WebUI, and SearXNG form our self-hosted AI inference and search stack. Ollama runs LLMs locally via a REST API. Open WebUI is the chat interface and RAG pipeline that sits on top of Ollama. SearXNG is a privacy-respecting meta-search engine that provides live web search for RAG pipelines and n8n workflows. Together they give us a fully self-contained AI assistant with real-time web context — no OpenAI dependency.

> **Note**: This group will expand as new AI tools are evaluated — Hugging Face, LangChain, vLLM, LocalAI, etc.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 control plane, helix-worker-1: 138.201.131.157 worker)
- **Ollama**: Deployed on K3s, CPU-only (no GPU on Hetzner Cloud — standard CX-series VMs)
- **Open WebUI**: Deployed on K3s via Helm, connects to Ollama backend, uses pgvector (CloudNativePG) for embeddings
- **SearXNG**: Deployed on K3s, used as search provider in Open WebUI and as HTTP endpoint for n8n workflows
- **Ingress**: Traefik IngressRoutes, TLS via cert-manager + Let's Encrypt DNS-01 via Cloudflare
- **Identity**: Zitadel OIDC — Open WebUI users authenticate via Zitadel; Ollama and SearXNG are internal-only
- **Automation**: n8n calls Ollama REST API directly for document summarization, classification, and embedding tasks
- **Database**: pgvector extension in CloudNativePG PostgreSQL for Open WebUI RAG embeddings
- **Internal domain**: services on helixstax.net subdomains

## What I Need Researched

### Ollama

#### 1. K3s Deployment
- Helm chart options (official or community) for deploying Ollama on K3s
- CPU-only deployment on Hetzner Cloud — resource requests/limits (memory is the constraint, not GPU)
- PersistentVolumeClaim for model storage (models are large — 4-8GB each, need durable storage)
- Pulling models at startup via init containers vs post-deploy job
- Ollama health check endpoints for K3s liveness/readiness probes
- Updating Ollama (rolling update strategy for stateful model server)

#### 2. Model Management
- `ollama pull`, `ollama list`, `ollama rm`, `ollama show` CLI reference
- Model selection for CPU-only small infrastructure:
  - **phi3:mini / phi3.5** — Microsoft, best quality/size ratio for general tasks
  - **llama3.2:3b** — Meta, fast on CPU, good for classification
  - **mistral:7b** — good general-purpose, heavier
  - **gemma2:2b** — Google, very fast on CPU
  - **nomic-embed-text** — embedding model for RAG (768-dim)
  - **mxbai-embed-large** — higher quality embeddings (1024-dim)
  - When to use which model: classification vs summarization vs embedding vs chat
- Memory requirements per model (how much RAM needed for each)
- Quantization levels (Q4_K_M vs Q5_K_M vs Q8_0 — tradeoffs on CPU)
- Running multiple models: only one model loads at a time by default, how to configure keep_alive

#### 3. Modelfile Creation
- Modelfile syntax: FROM, SYSTEM, PARAMETER, TEMPLATE, ADAPTER, LICENSE
- Creating custom system prompts for Helix Stax context (IT consulting assistant persona)
- Setting parameters: temperature, top_p, top_k, num_ctx (context window), num_predict
- How to `ollama create` a custom model from a Modelfile
- Sharing Modelfiles across the team via Git

#### 4. REST API Reference (for n8n integration)
- `/api/generate` — single-turn completion (parameters, streaming vs non-streaming)
- `/api/chat` — multi-turn chat (messages array, roles)
- `/api/embeddings` — generate embeddings for a text (critical for pgvector pipeline)
- `/api/tags` — list available models
- `/api/pull` — pull a model programmatically
- `/api/show` — show model metadata
- Authentication: Ollama has no built-in auth — how to secure behind Traefik (BasicAuth middleware or restrict to cluster-internal only)
- How to call Ollama from n8n HTTP Request node (URL, headers, body structure, streaming disabled)
- Error handling: model not loaded, out of memory, context length exceeded

#### 5. Resource Management
- Memory limits for CPU inference (rule of thumb: model size * 1.2 for quantized)
- Concurrent request handling (Ollama queues requests — only one inference at a time by default)
- `OLLAMA_NUM_PARALLEL` environment variable — when and how to use
- `OLLAMA_MAX_LOADED_MODELS` — keeping multiple models warm
- CPU thread configuration (`OLLAMA_NUM_THREADS`)
- Prometheus metrics exposure (does Ollama export metrics? How to scrape?)
- Logging levels and log format for Loki ingestion

---

### Open WebUI

#### 6. K3s Deployment
- Official Helm chart (`open-webui/open-webui`) — values reference
- Connecting to Ollama backend (env: `OLLAMA_BASE_URL`)
- PostgreSQL backend configuration (replace default SQLite with CloudNativePG — env vars needed)
- pgvector configuration for RAG embeddings (env: `VECTOR_DB`, connection string)
- PersistentVolumeClaim for uploads and user data
- Environment variables: complete reference for self-hosted deployment
- Zitadel OIDC integration: `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`, `OPENID_PROVIDER_URL`, scopes needed, redirect URI configuration

#### 7. User Management
- Local users vs OIDC (Zitadel) — how they coexist
- Admin user bootstrap (first user, or env var `WEBUI_SECRET_KEY`)
- Role-based access: admin vs user — what each can do
- API key generation for programmatic access (used by n8n)
- User signup settings (allow open registration vs invite-only vs SSO-only)

#### 8. RAG Pipeline
- Document upload flow: upload → chunking → embedding → pgvector storage → retrieval
- Supported document types (PDF, DOCX, TXT, Markdown, etc.)
- Chunk size and overlap configuration
- Embedding model selection in Open WebUI (pointing to Ollama's nomic-embed-text or mxbai-embed-large)
- RAG query flow: user message → embed query → cosine similarity search in pgvector → inject top-k chunks → LLM generates response
- Collection management (organizing documents by topic/client)
- Hybrid search (vector + keyword BM25) — does Open WebUI support it?
- Relevance score thresholds — filtering low-quality retrievals

#### 9. SearXNG Web Search Integration
- Configuring SearXNG as the web search provider in Open WebUI
- When web search is triggered (user toggles, or always-on)
- How search results are injected into context
- Controlling which queries trigger web search

#### 10. API Keys and Programmatic Access
- Open WebUI API: base URL, authentication (Bearer token = API key)
- Chat completion endpoint (OpenAI-compatible — `/api/chat/completions`)
- How n8n calls Open WebUI API vs calling Ollama directly — when to use each
- File upload API for RAG document ingestion via n8n

#### 11. Admin Configuration
- Model presets: default model, per-user model restrictions
- System prompt injection at the admin level
- Custom tools and functions (Open WebUI 0.4+ feature — Python functions as tools)
- Pipeline plugins (external processing steps)
- Banners and announcements
- Usage analytics and audit logging

---

### SearXNG

#### 12. K3s Deployment
- Helm chart or raw manifests for SearXNG on K3s
- ConfigMap for `settings.yml` — how to manage configuration in K3s
- Secret for `secret_key` (required for SearXNG — must be random, consistent across restarts)
- Traefik IngressRoute configuration (path-based or host-based)
- Resource requirements (lightweight — 128Mi memory is fine)
- Stateless deployment (no PVC needed — all config via ConfigMap)

#### 13. Configuration (settings.yml)
- `general` section: instance name, contact, description
- `search` section: safe_search, autocomplete, default_lang, ban_time_on_fail, max_ban_time_on_fail
- `server` section: secret_key, port, bind_address, image_proxy, method (GET vs POST)
- `ui` section: static_use_hash, default_locale, query_in_title, infinite_scroll
- `outgoing` section: request_timeout, useragent_suffix, pool_connections, enable_http2, proxies (if needed)
- `enabled_plugins` list: what to enable/disable

#### 14. Engine Selection
- Which engines to enable for an IT consulting firm:
  - **Web**: Google, Bing, DuckDuckGo, Brave — tradeoffs on reliability and rate limiting
  - **Code**: GitHub, GitLab, Stack Overflow, npm
  - **Docs**: Wikipedia, ArXiv (for AI research)
  - **IT-specific**: CVE search, Shodan (for security research)
- Engines to disable (to avoid noise or rate limiting): shopping, news aggregators, adult content
- Per-engine configuration: `timeout`, `shortcut`, `weight`, `disabled`
- Rate limiting per engine — SearXNG handles this automatically but per-engine timeouts matter

#### 15. API Access
- SearXNG JSON API: `/search?q={query}&format=json`
- Parameters: `q`, `categories`, `engines`, `lang`, `time_range`, `safesearch`, `pageno`
- Response structure: `results` array (url, title, content, engine, score), `suggestions`, `infoboxes`
- How Open WebUI calls SearXNG (internal cluster URL, no auth needed if cluster-internal)
- How n8n calls SearXNG (HTTP Request node — URL structure, response parsing)
- Rate limiting: SearXNG has no built-in API rate limiting — rely on Traefik middleware if exposed externally

#### 16. Privacy and Security
- Not exposing SearXNG publicly (cluster-internal only via Traefik with Access restrictions)
- Disabling the HTML UI (API-only mode) — is this supported?
- Logging: what SearXNG logs, how to minimize PII in logs
- `image_proxy` — proxying images through SearXNG (privacy benefit, bandwidth cost)

---

### Cross-Cutting Integration

#### 17. Embeddings Pipeline
- Complete flow: document → n8n HTTP Request to Ollama `/api/embeddings` → store vector in pgvector → Open WebUI queries pgvector at chat time
- pgvector schema for Open WebUI (what tables/columns it creates)
- Choosing embedding dimensions: nomic-embed-text (768) vs mxbai-embed-large (1024)
- Cosine similarity vs L2 distance in pgvector — which does Open WebUI use?
- Indexing strategy for pgvector (IVFFlat vs HNSW — which is better for our scale)

#### 18. n8n AI Workflow Patterns
- **Document summarization**: n8n receives document via webhook → HTTP Request to Ollama `/api/generate` → returns summary to ClickUp or Rocket.Chat
- **Classification**: n8n receives text → HTTP Request to Ollama with classification prompt → routes based on response
- **RAG-augmented response**: n8n queries SearXNG → injects results into Ollama prompt → returns enriched response
- **Embedding pipeline**: n8n receives document → chunks text → calls Ollama `/api/embeddings` for each chunk → upserts to pgvector via PostgreSQL node
- n8n community nodes for AI (LangChain nodes) — are they compatible with self-hosted Ollama?
- n8n self-hosted AI nodes (native Ollama node if it exists)

#### 19. Troubleshooting
- Ollama: model won't load (OOM), slow inference on CPU (expected, tune num_ctx), API not reachable from other pods
- Open WebUI: can't connect to Ollama (service name resolution in K3s), RAG returns irrelevant results (embedding model mismatch), OIDC login fails (Zitadel redirect URI)
- SearXNG: all engines returning errors (rate limited — add delays), JSON API returns HTML (format param missing), secret_key mismatch causing session errors
- pgvector: extension not installed (need to enable in CloudNativePG), slow similarity search (missing index), dimension mismatch between embedding model and stored vectors

---

## Required Output Format

Structure your response EXACTLY like this — it will be split into three separate skill files for AI agents. Use `# Tool Name` as top-level headers so the output can be split:

```markdown
# Ollama

## Overview
[2-3 sentences]

## K3s Deployment
[Helm values, manifests, env vars]

## Model Management
### Model Selection Guide
[table: model name, size, RAM needed, best for, quantization]
### CLI Reference
[pull, list, rm, show commands with examples]
### Modelfile Reference
[syntax, example for Helix Stax persona]

## REST API Reference
### /api/generate
[parameters, example curl, n8n body structure]
### /api/chat
[parameters, example]
### /api/embeddings
[parameters, example, response structure]
### Other Endpoints
[tags, pull, show]

## Resource Management
[memory limits, concurrency, env vars table]

## Prometheus Metrics
[scrape config, key metrics]

## Troubleshooting
[OOM, slow inference, API errors]

## Gotchas
[CPU-only limitations, model loading time, keep_alive]

---

# Open WebUI

## Overview
[2-3 sentences]

## K3s Deployment
[Helm values, env vars, PVC, PostgreSQL config]

## Zitadel OIDC Integration
[env vars, Zitadel client config, redirect URIs]

## User Management
[roles, API keys, signup settings]

## RAG Pipeline
### Document Ingestion
[upload flow, chunk config]
### Embedding Configuration
[embedding model selection, pgvector connection]
### Retrieval
[query flow, relevance thresholds]

## SearXNG Integration
[how to configure, trigger conditions]

## API Reference
[chat completions endpoint, file upload, auth]

## Admin Configuration
[model presets, tools, pipelines]

## Troubleshooting
[Ollama connection, RAG issues, OIDC errors]

## Gotchas
[SQLite vs PostgreSQL migration, pgvector extension requirement]

---

# SearXNG

## Overview
[2-3 sentences]

## K3s Deployment
[manifests, ConfigMap pattern, secret_key, resources]

## Configuration Reference
### settings.yml
[annotated example with our recommended values]
### Engine Selection
[table: engine, category, enable/disable, reason]

## API Reference
[endpoint, parameters, response structure, example curl]

## n8n Integration
[HTTP Request node config, response parsing]

## Open WebUI Integration
[configuration steps, internal URL]

## Privacy and Security
[cluster-internal only, logging, image proxy]

## Troubleshooting
[rate limits, secret_key errors, engine timeouts]

## Gotchas
[stateless — always use ConfigMap, secret_key must persist]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual Kubernetes manifests or Helm values, actual curl examples, and actual env var names. Do NOT give me theory — give me copy-paste-ready configs for a CPU-only K3s cluster on Hetzner with Zitadel OIDC, CloudNativePG PostgreSQL with pgvector, and Traefik ingress.
