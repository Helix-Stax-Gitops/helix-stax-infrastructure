# Cloudflare Workers — MCP Deployment Architecture

**Date**: 2026-03-21
**Author**: Wakeem Williams
**Document Author**: Quinn Mercer, Documentation Lead

---

## Overview

This document records the architecture decisions made when deploying Model Context Protocol (MCP) servers as Cloudflare Workers for the Helix Stax platform. It covers what was deployed, what was deleted and why, security posture, and operational runbook for adding new Workers.

---

## 1. Deployed Workers

| Worker | URL | Auth Model | Purpose |
|--------|-----|------------|---------|
| `mcp-clickup` | `mcp-clickup.helixstax.workers.dev/mcp` | Bearer token (`MCP_AUTH_TOKEN`) + ClickUp API key (`CLICKUP_API_KEY`) | ClickUp project management — 9 MCP tools |
| `mcp-google` | `mcp-google.helixstax.workers.dev/mcp` | OAuth 2.1 with PKCE + refresh tokens | Google Workspace integration with branded consent screen |

### mcp-clickup Tools

Verified from `shared/cloudflare-workers/mcp-clickup-proper/src/index.ts`:

| Tool | Description |
|------|-------------|
| `create_task` | Create a new task in a ClickUp list |
| `get_task` | Get details of a specific task |
| `update_task` | Update an existing task |
| `search_tasks` | Search for tasks in a list |
| `create_comment` | Add a comment to a task |
| `get_lists` | Get all lists in a folder |
| `get_folders` | Get all folders in a space |
| `get_spaces` | Get all spaces in the workspace |
| `add_dependency` | Add a dependency between two tasks |
| `add_tag` | Add a tag to a task |

### mcp-google Scope

Deployed with OAuth 2.1 infrastructure. The Worker currently exposes only a placeholder `add` tool. Google Workspace tools (Gmail, Drive, Calendar, Sheets, Docs) are the planned next addition to this Worker. Source: `shared/cloudflare-workers/mcp-google/src/index.ts`.

---

## 2. Deleted Workers (and Why)

Five proxy Workers were deleted during this session:

| Deleted Worker | Reason |
|----------------|--------|
| `mcp-github` | Open HTTP forwarder — no auth, exposed API keys to any caller who knew the URL |
| `mcp-n8n` | Same — unauthenticated proxy to internal n8n instance |
| `mcp-zitadel` | Same — unauthenticated proxy, Zitadel PAT forwarded without protection |
| `mcp-harbor` | Same — Harbor credentials forwarded over open HTTP |
| `mcp-trivy` | Same — unauthenticated proxy |

**Decision**: These services are now accessed via local `npx` MCP servers in `settings.json` instead. Local servers authenticate using environment variables resolved at runtime, keeping credentials out of network transit entirely.

---

## 3. Security Architecture

### mcp-google (Strong)

Security controls implemented per Ezra Raines' review:

| Control | Implementation |
|---------|---------------|
| OAuth 2.1 with PKCE | `code_challenge` + `code_challenge_method=S256`; no implicit flow |
| CSRF protection | Cryptographic `state` parameter; validated on callback |
| State signing | HMAC-signed state prevents forgery |
| Timing-safe comparison | `crypto.subtle.timingSafeEqual` on all secret comparisons |
| CSP headers | Strict Content-Security-Policy on all responses |
| Hosted domain validation | Enforces `@helixstax.com` Google accounts only |
| Refresh token rotation | Tokens stored in Durable Object SQLite; rotated on use |

### mcp-clickup (Baseline)

The Worker uses a **two-secret model**:

| Secret | Wrangler Name | Purpose |
|--------|---------------|---------|
| `MCP_AUTH_TOKEN` | `wrangler secret put MCP_AUTH_TOKEN` | Authenticates the MCP client connecting to the Worker. Checked via timing-safe Bearer token comparison on every `/mcp` request. Returns 401 on mismatch. |
| `CLICKUP_API_KEY` | `wrangler secret put CLICKUP_API_KEY` | Authenticates the Worker to ClickUp's API. Injected as the `Authorization` header on all outbound `clickupFetch` calls. |

The `/health` endpoint is unauthenticated by design (returns `{"status":"ok"}`). The `/mcp` endpoint requires a valid `Authorization: Bearer <MCP_AUTH_TOKEN>` header.

**Current gap**: No Cloudflare Access policy in front of this Worker. The endpoint has Bearer token auth, but the gap is that there is no IP/identity restriction at the Cloudflare edge layer — anyone who obtains the token URL can attempt brute-force or replay attacks.

### Vault Strategy — Two-Store Model

| Secret Location | Used For | Tool |
|-----------------|----------|------|
| `.env.secrets` (local file, gitignored) | Local `npx` MCP servers; resolved via `${VAR}` in settings.json | Shell environment |
| `wrangler secret put` | Cloudflare Worker runtime secrets | Wrangler CLI |
| OpenBao (K3s) | K3s workload secrets; long-term vault | OpenBao MCP server |

---

## 4. Next Steps

| Priority | Action |
|----------|--------|
| HIGH | Move Workers to custom domains: `mcp-clickup.helixstax.net`, `mcp-google.helixstax.net` |
| HIGH | Add Cloudflare Access policies with service tokens in front of both Workers |
| MEDIUM | Add Google Workspace tools to `mcp-google` Worker (Gmail, Drive, Calendar, Sheets, Docs) |
| LOW | Rebuild any deleted proxy Workers as proper `McpAgent` Workers if/when needed |

---

## 5. How to Add a New MCP Worker

### Step 1 — Scaffold

```bash
npm create cloudflare@latest mcp-<service> -- --template cloudflare/ai/demos/remote-mcp-authless
cd mcp-<service>
```

### Step 2 — Define Tools

In `src/index.ts`, extend `McpAgent` and define tools using Zod schemas:

```typescript
import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

export class MyServiceMCP extends McpAgent<Env> {
  server = new McpServer({ name: "my-service", version: "1.0.0" });

  async init() {
    this.server.tool(
      "tool_name",
      "Description of what this tool does",
      { param: z.string().describe("Parameter description") },
      async ({ param }) => {
        // implementation
      }
    );
  }
}
```

### Step 3 — Configure wrangler.jsonc

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "mcp-<service>",
  "account_id": "57046d4890f574ed90c545f51acb67d8",
  "main": "src/index.ts",
  "compatibility_date": "2025-03-10",
  "compatibility_flags": ["nodejs_compat"],
  "migrations": [{ "new_sqlite_classes": ["MyServiceMCP"], "tag": "v1" }],
  "durable_objects": {
    "bindings": [{ "class_name": "MyServiceMCP", "name": "MCP_OBJECT" }]
  },
  "observability": { "enabled": true }
}
```

### Step 4 — Wire Auth (Two-Secret Pattern)

For Workers that require auth, implement the two-secret model in `src/index.ts`:

1. **`MCP_AUTH_TOKEN`** — gates the `/mcp` endpoint. The MCP client (via `mcp-remote`) must present this as a Bearer token.
2. **`SERVICE_API_KEY`** — used by the Worker to authenticate outbound calls to the upstream service.

Add auth enforcement in the `fetch` handler before routing to the McpAgent:

```typescript
if (url.pathname === "/mcp") {
  const authHeader = request.headers.get("Authorization");
  const expected = `Bearer ${env.MCP_AUTH_TOKEN}`;
  if (!authHeader || !(await timingSafeCompare(authHeader, expected))) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  return MyServiceMCP.serve("/mcp").fetch(request, env, ctx);
}
```

Set both secrets via wrangler:

```bash
wrangler secret put MCP_AUTH_TOKEN     # Client-facing auth token
wrangler secret put SERVICE_API_KEY    # Upstream service credential
```

### Step 5 — Test Locally

```bash
wrangler dev
# Worker runs on http://localhost:8787 by default
# Test health: curl http://localhost:8787/health
# Test auth: curl -H "Authorization: Bearer <token>" http://localhost:8787/mcp
```

Note: `mcp-remote` passes auth headers automatically when the remote server returns a 401 and the client has a stored token for that URL.

### Step 6 — Deploy

```bash
npm run deploy
# Output: https://mcp-<service>.helixstax.workers.dev
```

### Step 7 — Wire to Claude Code

Add to `~/.claude/settings.json` under `mcpServers`:

```json
"service-name": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp-<service>.helixstax.workers.dev/mcp"]
}
```

`mcp-remote` handles the stdio-to-HTTP translation. It caches auth tokens locally after the first successful handshake — no credentials in the args.

### Step 8 — Rollback if Needed

```bash
wrangler rollback
# Reverts to the previous deployment. Check Cloudflare dashboard for deployment IDs.
# To rollback to a specific version: wrangler rollback <deployment-id>
```

### Step 9 — Verify Observability

Cloudflare Workers observability is enabled via `"observability": { "enabled": true }` in `wrangler.jsonc`. After deploy, verify in the Cloudflare dashboard:
- Workers & Pages > your worker > Logs (real-time log tail)
- Workers & Pages > your worker > Metrics (request count, error rate, CPU time)

### Step 10 — Security Review

Dispatch `stax-security-engineer` (Ezra Raines) to audit:
- Auth enforcement (is the endpoint gated?)
- Secret handling (no hardcoded values)
- Input validation on all tool parameters
- Add Cloudflare Access service token before production use

---

## 6. Claude Code settings.json — MCP Bridge Pattern

Workers connect to Claude Code via `mcp-remote`, a thin bridge that translates the remote SSE/HTTP MCP protocol to the local stdio MCP protocol that Claude Code expects.

### Current Worker Entries

```json
"clickup-pm": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp-clickup.helixstax.workers.dev/mcp"]
},
"google-workspace": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp-google.helixstax.workers.dev/mcp"]
}
```

**How it works**: `npx mcp-remote <url>` spawns a local process that Claude Code talks to over stdio. That local process connects to the Worker over HTTPS and relays MCP messages. No credentials are passed in the args — `mcp-remote` handles auth token storage and header injection automatically.

**Config file**: `C:\Users\MSI LAPTOP\.claude\settings.json`

---

## 7. Repository Structure

```
shared/cloudflare-workers/
  mcp-clickup-proper/      # ClickUp McpAgent Worker
    src/index.ts
    wrangler.jsonc
    package.json
    worker-configuration.d.ts
  mcp-google/              # Google OAuth Worker
    src/index.ts
    src/google-handler.ts
    wrangler.jsonc
    package.json
```

---

*Document produced by Quinn Mercer. Author: Wakeem Williams.*
