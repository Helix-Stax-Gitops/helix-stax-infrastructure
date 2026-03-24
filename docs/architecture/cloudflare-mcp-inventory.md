# Cloudflare MCP Server Inventory

> Researched: 2026-03-23 by Remy Alcazar (stax-preparer)
> Author: Wakeem Williams

## Current State

We currently have ONE Cloudflare MCP configured as `cloudflare-edge` in `~/.claude/settings.json`:

```
exec npx -y mcp-remote https://observability.mcp.cloudflare.com/sse
```

This connects to the **Workers Observability** server via the deprecated SSE transport. The current transport standard is **Streamable HTTP** (`/mcp` endpoints). SSE (`/sse`) still works but is deprecated.

---

## Complete Cloudflare MCP Server Catalog

Cloudflare provides **17 remote MCP servers** (1 unified API + 16 product-specific). All use OAuth or API token auth. All endpoints follow the pattern `https://{service}.mcp.cloudflare.com/mcp`.

### Tier 1: Unified API Server (NEW -- Replaces Individual Servers)

| Server | Endpoint | Description |
|--------|----------|-------------|
| **Cloudflare API** | `https://mcp.cloudflare.com/mcp` | Unified access to ALL 2,500+ Cloudflare API endpoints via 2 tools: `search()` and `execute()`. Uses "Code Mode" -- agent writes JS that runs in a V8 sandbox. Only ~1,000 tokens vs 244K for individual tool definitions. |

**Key insight**: This single server covers DNS, Workers, R2, Zero Trust, KV, D1, Queues, Pages, and every other Cloudflare product. When Cloudflare adds new products, they are automatically available through the same `search()` + `execute()` interface. No new MCP definitions needed.

### Tier 2: Product-Specific Servers

| # | Server | Endpoint | What It Does | Plan Required |
|---|--------|----------|--------------|---------------|
| 1 | **Documentation** | `https://docs.mcp.cloudflare.com/mcp` | Search Cloudflare developer docs. Up-to-date reference info. | Free |
| 2 | **Workers Bindings** | `https://bindings.mcp.cloudflare.com/mcp` | Build Workers with D1, R2, KV, AI bindings on the fly. | Free (Workers Free) |
| 3 | **Workers Builds** | `https://builds.mcp.cloudflare.com/mcp` | Insights and management for Workers Builds CI/CD. | Workers Paid ($5/mo) |
| 4 | **Observability** | `https://observability.mcp.cloudflare.com/mcp` | Debug Workers via invocation logs, errors, analytics. Browse/filter/stats. | Free (basic), Paid (full logs) |
| 5 | **Radar** | `https://radar.mcp.cloudflare.com/mcp` | Global internet traffic insights, domain trends, URL scanning. | Free (CC BY-NC 4.0 license) |
| 6 | **Container** | `https://containers.mcp.cloudflare.com/mcp` | Spin up isolated sandbox dev environments on CF network for code execution/testing. | Workers Paid |
| 7 | **Browser Rendering** | `https://browser.mcp.cloudflare.com/mcp` | Fetch pages, convert to markdown, capture screenshots. RESTful browser actions. | Workers Paid |
| 8 | **Logpush** | `https://logs.mcp.cloudflare.com/mcp` | Logpush job health summaries and delivery analysis. | Workers Paid ($5/mo) |
| 9 | **AI Gateway** | `https://ai-gateway.mcp.cloudflare.com/mcp` | Search AI Gateway logs, review prompts and responses. | Free (100K logs), Paid (more) |
| 10 | **AI Search (AutoRAG)** | `https://autorag.mcp.cloudflare.com/mcp` | List and search documents in AutoRAG instances. | Workers Paid |
| 11 | **Audit Logs** | `https://auditlogs.mcp.cloudflare.com/mcp` | Query audit logs, generate compliance reports. | Enterprise |
| 12 | **DNS Analytics** | `https://dns-analytics.mcp.cloudflare.com/mcp` | DNS performance optimization, troubleshooting, config review. | Free (basic), Pro+ (full analytics) |
| 13 | **DEX (Digital Experience Monitoring)** | `https://dex.mcp.cloudflare.com/mcp` | Monitor application performance, availability, end-user connectivity. | Zero Trust Free (50 users), Paid (more) |
| 14 | **CASB** | `https://casb.mcp.cloudflare.com/mcp` | Identify SaaS security misconfigurations, shadow IT, unauthorized access. | Zero Trust Free (2 integrations), Enterprise (full) |
| 15 | **GraphQL** | `https://graphql.mcp.cloudflare.com/mcp` | Analytics data via Cloudflare GraphQL API. Flexible queries. | Free |
| 16 | **Agents SDK Docs** | `https://agents.cloudflare.com/mcp` | Search Agents SDK documentation. | Free |

---

## Authentication

All Cloudflare MCP servers support two auth methods:

### Option 1: OAuth 2.1 (Interactive)
- No pre-configuration needed beyond the MCP URL
- User authorizes via Cloudflare dashboard in browser
- Permissions selected interactively (progressive disclosure)
- Best for: human-in-the-loop, desktop usage

### Option 2: API Token (Headless/CI)
- Create token at https://dash.cloudflare.com/profile/api-tokens
- Pass as Bearer token in Authorization header
- Both user-level and account-level tokens supported
- Note: IP-filtered tokens not currently supported
- Best for: automation, CI/CD, server-side usage

### Our Current Auth
Our `mcp-cloudflare.sh` script fetches `CLOUDFLARE_API_TOKEN` from the secrets vault and passes it to `mcp-remote`. This pattern works for both `/sse` and `/mcp` endpoints.

---

## Transport: SSE vs Streamable HTTP

| Transport | Endpoint | Status |
|-----------|----------|--------|
| SSE | `/sse` | **Deprecated** but still functional |
| Streamable HTTP | `/mcp` | **Current standard** per MCP spec |

**Action needed**: Update our `mcp-cloudflare.sh` from `/sse` to `/mcp`.

### Connection via mcp-remote

The `mcp-remote` npm package bridges stdio-only MCP clients (like Claude Code) to remote HTTP/SSE servers. It handles OAuth flows automatically (launches browser if needed).

```json
{
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp.cloudflare.com/mcp"]
}
```

For API token auth, the token is typically passed via environment variable or Authorization header.

---

## Recommendation Table

### What to Add Now

| Server | Why | Config Change |
|--------|-----|---------------|
| **Cloudflare API** (`mcp.cloudflare.com/mcp`) | Replaces ALL individual servers with a single 1,000-token interface. Covers DNS, Workers, R2, KV, Zero Trust -- everything. One server to rule them all. | Add as new MCP entry |
| **Documentation** (`docs.mcp.cloudflare.com/mcp`) | Free, no auth needed. Instant access to current CF docs without web searching. | Add as new MCP entry |
| **Radar** (`radar.mcp.cloudflare.com/mcp`) | Free. Internet traffic insights, domain analysis, URL scanning. Useful for security research and competitive analysis. | Add as new MCP entry |
| **DNS Analytics** (`dns-analytics.mcp.cloudflare.com/mcp`) | We use CF DNS. Performance optimization and troubleshooting directly from agent. | Add as new MCP entry |
| **GraphQL** (`graphql.mcp.cloudflare.com/mcp`) | Free. Flexible analytics queries across all CF products. Complements the unified API server. | Add as new MCP entry |

### What to Add Later (When Relevant)

| Server | Why Later | Trigger to Add |
|--------|-----------|----------------|
| **Workers Builds** | We don't yet use CF Workers Builds for CI/CD (we use Devtron/ArgoCD). | When we adopt Workers Builds pipeline |
| **Container** | Useful for sandboxed code execution but not critical for infra consulting. | When agents need isolated runtime environments |
| **Browser Rendering** | We already have `playwright-browser` MCP configured. Redundant unless we need CF-hosted rendering. | If Playwright MCP proves insufficient |
| **AI Gateway** | We don't currently route AI calls through CF AI Gateway. | When we set up AI Gateway for LLM proxy/caching |
| **AI Search (AutoRAG)** | We don't use AutoRAG. | When we build RAG pipelines on CF |
| **Logpush** | Requires Workers Paid. We use Grafana/Loki for log aggregation. | When we route CF logs to our stack |
| **DEX** | Useful for Zero Trust monitoring but we only have <50 users. Free tier covers us but limited value now. | When Zero Trust scales beyond basic usage |

### What to Skip

| Server | Why Skip |
|--------|----------|
| **Observability** (standalone) | The unified Cloudflare API server covers this. Keep only if you want the specialized UX, but redundant. |
| **Workers Bindings** (standalone) | Covered by the unified API server. |
| **Audit Logs** | Enterprise-only. We're on Pro/Free. |
| **CASB** | Enterprise for full features. Free tier only allows 2 integrations. Low value for our setup. |
| **Agents SDK Docs** | Only useful if actively developing MCP servers on CF (we already have 3 Workers deployed, but this is niche). |

---

## Recommended New Configuration

Replace the current single `cloudflare-edge` entry with a focused set:

```json
{
  "cloudflare-api": {
    "command": "bash",
    "args": ["~/.claude/scripts/mcp-cloudflare.sh"]
  },
  "cloudflare-docs": {
    "command": "npx",
    "args": ["-y", "mcp-remote", "https://docs.mcp.cloudflare.com/mcp"]
  },
  "cloudflare-radar": {
    "command": "npx",
    "args": ["-y", "mcp-remote", "https://radar.mcp.cloudflare.com/mcp"]
  },
  "cloudflare-dns-analytics": {
    "command": "bash",
    "args": ["~/.claude/scripts/mcp-cloudflare-dns.sh"]
  },
  "cloudflare-graphql": {
    "command": "bash",
    "args": ["~/.claude/scripts/mcp-cloudflare-graphql.sh"]
  }
}
```

**Note**: The unified API server (`mcp.cloudflare.com/mcp`) should replace the current `cloudflare-edge` (observability) as the primary Cloudflare MCP. It covers observability AND everything else.

### Script Update for Primary Server

Update `mcp-cloudflare.sh` to point to the unified API:
```bash
exec npx -y mcp-remote https://mcp.cloudflare.com/mcp "$@"
```

### Servers Requiring Auth (reuse existing token pattern)
- `cloudflare-api` -- needs account-level token with broad read permissions
- `cloudflare-dns-analytics` -- needs DNS read permissions
- `cloudflare-graphql` -- needs analytics read permissions

### Servers NOT Requiring Auth
- `cloudflare-docs` -- public documentation, no auth
- `cloudflare-radar` -- free public data (may need basic token for rate limits)

---

## Key Findings

1. **The unified Cloudflare API server is a game-changer.** It replaces 15+ individual servers with 2 tools and ~1,000 tokens. This should be our primary Cloudflare MCP going forward.

2. **Our current setup uses the deprecated SSE transport** (`/sse`). All endpoints now support `/mcp` (Streamable HTTP). We should migrate.

3. **No additional cost needed.** The servers we recommend adding (API, Docs, Radar, DNS Analytics, GraphQL) are all available on the Free plan.

4. **The unified API server makes most product-specific servers redundant.** The only reason to keep a product-specific server is if its specialized tools offer a significantly better UX for a specific workflow than the generic `search()` + `execute()` pattern.

5. **MCP server count consideration.** Each MCP server consumes a connection and adds startup latency. The unified API server is specifically designed to solve this problem -- one connection covers everything. Adding too many individual servers is counterproductive.

---

## Sources

- [Cloudflare's own MCP servers](https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/)
- [Thirteen new MCP servers from Cloudflare](https://blog.cloudflare.com/thirteen-new-mcp-servers-from-cloudflare/)
- [Code Mode: give agents an entire API in 1,000 tokens](https://blog.cloudflare.com/code-mode-mcp/)
- [GitHub: cloudflare/mcp-server-cloudflare](https://github.com/cloudflare/mcp-server-cloudflare)
- [GitHub: cloudflare/mcp](https://github.com/cloudflare/mcp)
- [mcp-remote on npm](https://www.npmjs.com/package/mcp-remote)
- [MCP Transport documentation](https://developers.cloudflare.com/agents/model-context-protocol/transport/)
- [Zero Trust Plans & Pricing](https://www.cloudflare.com/plans/zero-trust-services/)
- [Cloudflare Radar docs](https://developers.cloudflare.com/radar/)
- [AI Gateway Pricing](https://developers.cloudflare.com/ai-gateway/reference/pricing/)
