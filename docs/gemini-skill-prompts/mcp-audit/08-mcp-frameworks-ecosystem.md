# MCP Audit — 08: MCP Frameworks & Ecosystem

> **Model**: alibaba/tongyi-deepresearch-30b-a3b (via OpenRouter)
> **System prompt**: Use contents of `00-system-prompt.md` as the SYSTEM prompt.
> **Scope**: MCP SDKs, builder frameworks, tooling, hosting patterns, spec health, best practices

---

<context>
I run Helix Stax, a small IT consulting company with 23 AI agents (Claude Code + Gemini CLI) managing 50+ infrastructure tools. I currently have 15 MCP servers configured: github-core, clickup-pm, opentofu-iac, postgres-db, n8n-automation, cloudflare-edge, zitadel-iam, grafana-obs, openbao-vault, trivy-sec, obsidian-docs, loki-logs, ansible-ops, valkey-cache, harbor-registry.

Stack: K3s on AlmaLinux 9.7, Hetzner Cloud, Cloudflare, Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, OpenBao, CrowdSec, Kyverno, Devtron, ArgoCD, OpenTofu, Ansible, Prometheus, Grafana, Loki, Alertmanager, n8n, Rocket.Chat, Backstage, Outline, Ollama, Open WebUI, SearXNG, pgvector, Google Workspace, ClickUp.
</context>

<task>
This prompt is NOT about finding MCP servers for tools. This is about the MCP DEVELOPMENT ecosystem itself — how to build, test, host, and maintain MCP servers.

**Part A: Official SDKs**
Find every official MCP SDK by Anthropic. For each:
| Language | Repo URL | Package | Install | Key Features | Maturity | Notes |

Languages to check: Python, TypeScript/Node, Go, Rust, Java, C#/.NET, Ruby, Swift, Kotlin

**Part B: Community Frameworks**
Find every community framework for building MCP servers faster. For each:
| Framework | Language | Repo URL | Stars | Install | Key Feature | vs Official SDK |

Include at minimum: FastMCP (Python), any other Python frameworks, any TypeScript frameworks, any Go frameworks.

**Part C: MCP Tooling**
Find every tool for working with MCP servers. For each:
| Tool | Purpose | Repo URL | Install | Notes |

Tool categories to cover:
- MCP Inspector (testing/debugging UI)
- MCP CLI tools (list, call, test from terminal)
- Schema generators (generate MCP from OpenAPI spec, etc.)
- Proxy tools (mcp-remote, HTTP-to-stdio bridges)
- Aggregators (combine multiple MCPs into one)
- Auth middleware (add OAuth/token auth to any MCP)
- Rate limiting middleware
- Logging/telemetry middleware
- Server templates / boilerplates

**Part D: MCP Hosting Patterns**
Document concrete patterns for hosting MCP servers on my K3s cluster. For each pattern:
| Pattern | Transport | Use Case | Pros | Cons | K3s Suitable? |

Patterns to cover:
- Local stdio via npx
- Local stdio via uvx (Python)
- Local stdio via Docker
- Cloudflare Workers (SSE)
- Self-hosted HTTP/SSE as K8s Deployment
- Docker Compose sidecar

**Part E: MCP Ecosystem Health**
Answer these questions with sources:
1. What is the current MCP spec version?
2. What features are on the MCP roadmap?
3. What are the top 3 security best practices for running MCP servers?
4. What are the top 3 performance best practices?
5. How do you properly test an MCP server (unit, integration, end-to-end)?
6. What are the 3 most common anti-patterns (what NOT to do)?
7. How does MCP compare to: OpenAI function calling, Google tool use, LangChain tools — when should you use MCP vs alternatives?
</task>

<output_format>
Return your findings organized exactly by the five parts (A through E) above, using tables for Parts A, B, C, D and numbered Q&A for Part E.

Add a **TL;DR for Builders** section at the end: if I need to build a custom MCP server for a self-hosted tool with a REST API, what is the fastest path (language, framework, hosting pattern)?
</output_format>
