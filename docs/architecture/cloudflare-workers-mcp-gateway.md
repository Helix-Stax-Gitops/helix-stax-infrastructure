# Cloudflare Workers MCP Gateway Architecture

**Author**: Cass Whitfield, System Architect
**Date**: 2026-03-20
**Status**: DRAFT -- Awaiting Review

---

## 1. Executive Summary

This document defines the architecture for migrating select MCP servers from local `npx`/`uvx` execution to Cloudflare Workers, and evaluates whether Cloudflare can also serve as the client-facing API gateway (replacing Gravitee/Kong).

**Key decisions**:
- 6 of 15 MCP servers move to Workers (stateless, API-proxy MCPs)
- 9 remain local (filesystem access, binary dependencies, or database sockets)
- Cloudflare API Gateway **can** replace Gravitee for Helix Stax's current scale
- Auth via Cloudflare Access (already deployed) + Worker-level JWT validation
- Secrets via Wrangler secrets (encrypted at rest, per-Worker)
- Agents connect via `mcp-remote` SSE adapter (same pattern as existing `cloudflare-edge`)

---

## 2. Architecture Diagram

```
                        CLOUDFLARE EDGE (Workers)
    +----------------------------------------------------------+
    |                                                          |
    |   mcp.helixstax.net                                      |
    |   +--------------------------------------------------+   |
    |   |  Cloudflare Access (Zero Trust)                  |   |
    |   |  - JWT validation                                |   |
    |   |  - Service token auth for K3s pods               |   |
    |   +--------------------------------------------------+   |
    |                         |                                |
    |   +-----------+  +-----------+  +-----------+            |
    |   | Worker:   |  | Worker:   |  | Worker:   |            |
    |   | clickup   |  | github    |  | n8n       |            |
    |   +-----------+  +-----------+  +-----------+            |
    |   +-----------+  +-----------+  +-----------+            |
    |   | Worker:   |  | Worker:   |  | Worker:   |            |
    |   | zitadel   |  | harbor    |  | trivy     |            |
    |   +-----------+  +-----------+  +-----------+            |
    |                                                          |
    |   api.helixstax.com (client-facing gateway)              |
    |   +--------------------------------------------------+   |
    |   |  API Gateway Workers                             |   |
    |   |  - Rate limiting, auth, OpenAPI validation       |   |
    |   |  - Routes to K3s backend via Cloudflare Tunnel   |   |
    |   +--------------------------------------------------+   |
    |                                                          |
    +----------------------------------------------------------+
              |                              |
              | SSE (mcp-remote)             | HTTPS (tunnel)
              |                              |
    +---------+----------+         +---------+---------+
    |  AGENT CLIENTS     |         |  K3s CLUSTER      |
    |                    |         |                    |
    | - Claude Code      |         | - Backend services |
    |   (local machine)  |         | - PostgreSQL       |
    | - Gemini CLI       |         | - Valkey           |
    |   (local machine)  |         | - Grafana/Loki     |
    | - K3s agent pods   |         | - OpenBao          |
    |   (via tunnel)     |         |                    |
    +--------------------+         +--------------------+

    LOCAL MCP SERVERS (remain on dev machine)
    +--------------------------------------------+
    | postgres-db   | valkey-cache  | obsidian    |
    | grafana-obs   | loki-logs     | openbao     |
    | opentofu-iac  | ansible-ops   | cloudflare  |
    +--------------------------------------------+
```

---

## 3. MCP Migration Matrix

| MCP Server | Current Transport | Move to Workers? | Rationale |
|---|---|---|---|
| **clickup-pm** | npx (stdio) | YES | Stateless API proxy to ClickUp cloud. No local deps. |
| **github-core** | npx (stdio) | YES | Stateless API proxy to GitHub. No local deps. |
| **n8n-automation** | npx (stdio) | YES | Stateless API proxy to n8n instance. No local deps. |
| **zitadel-iam** | npx (stdio) | YES | Stateless API proxy to Zitadel. No local deps. |
| **harbor-registry** | npx (stdio) | YES | Stateless API proxy to Harbor. No local deps. |
| **trivy-sec** | npx (stdio) | YES | Stateless API proxy. Trivy binary not needed for the MCP (it calls the Trivy API). |
| **postgres-db** | npx (stdio) | NO | Requires direct socket/TCP to PostgreSQL on K3s. Workers cannot hold persistent TCP connections. |
| **valkey-cache** | npx (stdio) | NO | Requires direct TCP to Valkey. Same TCP limitation. |
| **grafana-obs** | npx (stdio) | NO | Queries Grafana/Prometheus/Loki APIs on internal network. Could theoretically move, but latency-sensitive for dashboarding and deep PromQL. Keep local for now. |
| **loki-logs** | npx (stdio) | NO | High-volume log streaming. Workers have 128MB memory limit and 30s CPU time. Log queries can be large. |
| **openbao-vault** | npx (stdio) | NO | **Security-critical.** Vault tokens must never transit through edge. Keep local with direct tunnel access. |
| **opentofu-iac** | npx (stdio) | NO | Requires local `tofu` binary for state operations. Cannot run on Workers. |
| **ansible-ops** | npx (stdio) | NO | Requires local `ansible` binary and SSH access. Cannot run on Workers. |
| **cloudflare-edge** | mcp-remote (SSE) | NO (already remote) | Already runs as a Cloudflare remote MCP. No change needed. |
| **obsidian-docs** | uvx (stdio) | NO | Requires local filesystem access to Obsidian vault. Cannot run on Workers. |

**Summary**: 6 move, 9 stay local. The pattern is clear: stateless API-proxy MCPs move; anything needing local binaries, filesystem, persistent TCP, or security-critical secrets stays.

---

## 4. Worker Design Pattern

Each migrated MCP server runs as an individual Cloudflare Worker exposing an SSE endpoint compatible with the `mcp-remote` adapter.

### 4.1 Worker Structure

```
workers/
  mcp-clickup/
    src/index.ts          # Worker entry point
    wrangler.toml         # Worker config + secrets binding
  mcp-github/
    src/index.ts
    wrangler.toml
  mcp-n8n/
    ...
```

### 4.2 Worker Implementation Pattern

Each Worker:
1. Receives MCP JSON-RPC messages over SSE (HTTP streaming)
2. Validates the request via Cloudflare Access JWT
3. Translates MCP tool calls into upstream API calls (ClickUp API, GitHub API, etc.)
4. Returns structured JSON-RPC responses

```
Client (mcp-remote) --SSE--> CF Access --JWT--> Worker --HTTPS--> Upstream API
```

### 4.3 Wrangler Configuration (Example)

```toml
# workers/mcp-clickup/wrangler.toml
name = "mcp-clickup"
main = "src/index.ts"
compatibility_date = "2026-03-01"

[vars]
UPSTREAM_BASE_URL = "https://api.clickup.com/api/v2"

# Secrets set via: wrangler secret put CLICKUP_API_KEY
# Never in code, never in toml
```

### 4.4 Routing

All MCP Workers are exposed under a single domain with path-based routing:

| Worker | Endpoint |
|---|---|
| mcp-clickup | `https://mcp.helixstax.net/clickup/sse` |
| mcp-github | `https://mcp.helixstax.net/github/sse` |
| mcp-n8n | `https://mcp.helixstax.net/n8n/sse` |
| mcp-zitadel | `https://mcp.helixstax.net/zitadel/sse` |
| mcp-harbor | `https://mcp.helixstax.net/harbor/sse` |
| mcp-trivy | `https://mcp.helixstax.net/trivy/sse` |

Implemented via Cloudflare Workers Routes or a single dispatch Worker.

---

## 5. Auth & Secrets Model

### 5.1 Authentication Layers

| Layer | Mechanism | Purpose |
|---|---|---|
| **Edge** | Cloudflare Access | Identity verification (who is calling?) |
| **Worker** | JWT validation | Verify Access-issued JWT; extract identity claims |
| **Upstream** | API key (from Worker secrets) | Authenticate to upstream service (ClickUp, GitHub, etc.) |

### 5.2 Agent Authentication Patterns

| Agent Type | Auth Method |
|---|---|
| **Claude Code (local)** | `mcp-remote` connects via browser-based Cloudflare Access flow (one-time OAuth) |
| **Gemini CLI (local)** | Same as Claude Code -- `mcp-remote` or direct SSE with Access token |
| **K3s pods** | Cloudflare Service Token (already have `harbor-k3s-pull` and `minio-k3s-access` tokens; add `mcp-k3s-access`) |
| **n8n workflows** | Service Token stored in n8n credentials |

### 5.3 Secrets Management

| Secret Type | Storage | Access |
|---|---|---|
| Upstream API keys (ClickUp, GitHub, etc.) | Wrangler secrets (encrypted at rest) | Worker runtime only; never in code |
| Service tokens | OpenBao (`secret/cloudflare-zero-trust`) | Provisioned to K3s pods via k8s secrets |
| Cloudflare API token | OpenBao | Used by Wrangler CLI for deployments only |

**Non-negotiable**: No API keys in `wrangler.toml`, no secrets in git, no plaintext in Worker code.

---

## 6. Agent Connection Patterns

### 6.1 Claude Code (Local Machine)

Updated `settings.json` for migrated MCPs:

```json
{
  "mcpServers": {
    "clickup-pm": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/clickup/sse"]
    },
    "github-core": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/github/sse"]
    },
    "n8n-automation": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/n8n/sse"]
    },
    "zitadel-iam": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/zitadel/sse"]
    },
    "harbor-registry": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/harbor/sse"]
    },
    "trivy-sec": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/trivy/sse"]
    }
  }
}
```

Local-only MCPs remain unchanged (postgres-db, valkey-cache, grafana-obs, loki-logs, openbao-vault, opentofu-iac, ansible-ops, obsidian-docs, cloudflare-edge).

### 6.2 Gemini CLI

Gemini CLI supports MCP via the same SSE protocol. Configuration in `~/.gemini/settings.json` (or equivalent):

```json
{
  "mcpServers": {
    "clickup": {
      "uri": "https://mcp.helixstax.net/clickup/sse",
      "auth": "cloudflare-access"
    }
  }
}
```

Both Claude Code and Gemini CLI hit the same Workers -- single source of truth for MCP tool definitions.

### 6.3 K3s Pods

Pods that need MCP access (e.g., n8n workers, AI agent pods):

1. Pod spec mounts a Cloudflare Service Token from a Kubernetes secret
2. Pod calls `https://mcp.helixstax.net/{service}/sse` with `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers
3. Cloudflare Access validates the service token and forwards to the Worker

```yaml
# k8s secret (provisioned from OpenBao)
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-mcp-access
  namespace: stax-ai
data:
  CF_ACCESS_CLIENT_ID: <base64>
  CF_ACCESS_CLIENT_SECRET: <base64>
```

---

## 7. Cloudflare as API Gateway (Can It Replace Gravitee?)

### 7.1 Capability Comparison

| Capability | Cloudflare API Gateway | Gravitee | Kong |
|---|---|---|---|
| **Rate limiting** | YES -- native, per-route, configurable (free: basic; paid: advanced) | YES | YES |
| **Authentication** | YES -- Access (JWT, OAuth, SAML, service tokens) | YES | YES |
| **API key management** | YES -- via Workers KV or Access service tokens | YES | YES |
| **Request/response transformation** | YES -- Workers can rewrite anything (full JS runtime) | YES | YES |
| **OpenAPI spec validation** | PARTIAL -- via Workers (manual validation logic), or API Shield (Enterprise) | YES (native) | YES |
| **Analytics/logging** | YES -- Workers Analytics Engine, Logpush to Loki | YES | YES |
| **Developer portal** | NO -- would need custom build or Backstage | YES (native) | YES |
| **mTLS** | YES -- Cloudflare mTLS (free for authenticated origin pulls) | YES | YES |
| **WebSocket support** | YES | YES | YES |
| **GraphQL support** | YES -- Workers can proxy/validate GraphQL | YES | YES |
| **Self-hosted** | NO -- SaaS only (but data stays in-transit) | YES | YES |
| **Cost** | Free tier: 100K req/day. Paid: $5/mo for 10M req/mo | Open source (self-hosted cost) | Open source (self-hosted cost) |

### 7.2 Verdict: Cloudflare CAN Replace Gravitee

For Helix Stax's current scale and needs:

**YES, Cloudflare Workers can serve as the API gateway.** Here is why:

1. **Scale**: Helix Stax is pre-revenue with <100 API consumers. 100K req/day free tier is more than sufficient. Even the $5/mo Workers Paid plan (10M req/mo) covers massive growth.

2. **Auth is already there**: Cloudflare Access is deployed with Zero Trust. Adding API key validation in Workers is trivial.

3. **Transformation**: Workers have a full V8 JavaScript runtime. Any request/response transformation that Gravitee can do, a Worker can do with code.

4. **No developer portal needed yet**: Helix Stax does not have external API consumers requiring a self-service portal. When that day comes, Backstage can serve as the developer portal.

5. **Operational simplicity**: One platform (Cloudflare) for edge security, DNS, tunnels, MCP hosting, AND API gateway. No additional infrastructure to manage.

**What you lose vs Gravitee**:
- No built-in developer portal (build custom or use Backstage)
- No native OpenAPI spec validation (must implement in Worker code or use API Shield on Enterprise)
- No visual API management dashboard (manage via Wrangler CLI + git)
- No native API versioning UI (implement via Worker routing logic)

**Recommendation**: Use Cloudflare Workers as the API gateway. Defer Gravitee until Helix Stax has external paying API consumers who need a self-service portal.

### 7.3 API Gateway Worker Pattern

```
api.helixstax.com/v1/ctga/assess
    |
    v
CF Access (validate JWT/API key)
    |
    v
API Gateway Worker
    - Rate limit check (Workers KV counter)
    - Request validation
    - Transform request
    - Forward to K3s backend via CF Tunnel
    |
    v
helix-vps tunnel --> K3s service (ClusterIP)
    |
    v
Response back through Worker
    - Transform response
    - Log to Analytics Engine
    - Return to client
```

---

## 8. Cost Analysis

### 8.1 Workers Free Tier

| Resource | Free Tier | Helix Stax Estimate |
|---|---|---|
| Requests | 100,000/day | ~500-2,000/day (6 MCP Workers + API gateway) |
| CPU time | 10ms per invocation | Most MCP calls: 2-5ms (API proxy) |
| Workers | Unlimited | 7-10 Workers |
| KV reads | 100,000/day | ~1,000/day (rate limit counters) |
| KV writes | 1,000/day | ~200/day |

**Verdict**: Free tier is more than sufficient for current needs. Even at 10x growth, still within free limits.

### 8.2 When to Upgrade

| Trigger | Plan | Cost |
|---|---|---|
| >100K req/day sustained | Workers Paid | $5/mo |
| Need Durable Objects (WebSocket state) | Workers Paid | $5/mo + usage |
| Enterprise API Shield (OpenAPI validation) | Enterprise | Contact sales |

### 8.3 Comparison to Self-Hosted Gateway

| Option | Monthly Cost | Ops Overhead |
|---|---|---|
| Cloudflare Workers (free) | $0 | Zero (serverless) |
| Cloudflare Workers (paid) | $5 | Zero |
| Gravitee (self-hosted on K3s) | $0 license + ~$10 compute | Medium (JVM, upgrades, monitoring) |
| Kong (self-hosted on K3s) | $0 license + ~$10 compute | Medium (Lua/Go, plugins, DB) |

---

## 9. Fallback Strategy

### 9.1 Worker Outage Handling

| Scenario | Fallback |
|---|---|
| Single Worker down | `mcp-remote` returns error; agent retries. If persistent, agent falls back to CLI tool (e.g., `gh` instead of `github-core` MCP). |
| Cloudflare global outage | Restore local npx configs from git. `settings.json` has both remote and local configs commented; uncomment local. |
| Upstream API down (ClickUp, GitHub) | Worker returns structured error. Agent handles gracefully (this happens with local npx too). |

### 9.2 Fallback Configuration Strategy

Maintain a `settings.local.json.fallback` file with local npx configs for all 6 migrated MCPs. If Workers are unavailable:

```bash
cp ~/.claude/settings.local.json.fallback ~/.claude/settings.local.json
# Local overrides take precedence; agents use local npx execution
```

Recovery:
```bash
rm ~/.claude/settings.local.json
# Agents return to remote Workers
```

---

## 10. Migration Steps

### Phase 1: Infrastructure Setup (1 day)

1. Create `mcp.helixstax.net` DNS record (CNAME to Workers, proxied)
2. Create Cloudflare Access Application for `mcp.helixstax.net` (session: 24h)
3. Create Service Token `mcp-k3s-access` for pod authentication
4. Store service token in OpenBao at `secret/cloudflare-zero-trust/mcp-k3s-access`

### Phase 2: Worker Development (2-3 days)

5. Scaffold Worker projects (one per MCP) using `wrangler init`
6. Implement MCP JSON-RPC over SSE handler (shared library across Workers)
7. Implement upstream API proxy logic per Worker
8. Set secrets via `wrangler secret put` for each Worker
9. Deploy to Cloudflare Workers via `wrangler deploy`

### Phase 3: Agent Migration (1 day)

10. Update `~/.claude/settings.json` -- change 6 MCPs from npx to mcp-remote
11. Test each MCP from Claude Code (verify tool list, execute sample calls)
12. Configure Gemini CLI with same endpoints
13. Create K3s secret for pod-based access

### Phase 4: API Gateway (2-3 days, can run in parallel with Phase 2)

14. Create `api.helixstax.com` DNS record
15. Build API Gateway Worker with rate limiting, auth, and routing
16. Configure tunnel routes for K3s backend services
17. Test end-to-end client API flow

### Phase 5: Validation & Cleanup (1 day)

18. Run full agent workflow exercising all 6 remote MCPs
19. Test fallback procedure (disable Workers, restore local)
20. Document runbook at `docs/runbooks/cloudflare-workers-mcp.md`
21. Create fallback config file `settings.local.json.fallback`

**Total estimated effort**: 5-8 days

---

## 11. Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| **Workers CPU limit (10ms free, 30ms paid)** causes timeout on complex MCP calls | Medium | Low | MCP calls are API proxies (2-5ms). Monitor via Workers Analytics. Upgrade to paid if needed. |
| **Cloudflare outage** takes down all remote MCPs | High | Very Low | Fallback config restores local npx execution within 30 seconds. |
| **SSE connection drops** on long-running MCP operations | Medium | Medium | `mcp-remote` handles reconnection. Workers have 30s timeout; ensure MCP calls are short-lived. |
| **Secret rotation** across 6 Workers is error-prone | Low | Medium | Script rotation via Wrangler CLI. Store rotation procedure in runbook. |
| **Vendor lock-in** to Cloudflare platform | Medium | N/A | MCPs are standard JSON-RPC over SSE. Workers can be replaced with any HTTP server. The protocol is portable. |
| **Free tier exceeded** during heavy agent sessions | Low | Low | 100K/day = ~70 req/min sustained. 18-agent swarm peaks at ~10-20 req/min. Comfortable margin. |
| **OpenBao secrets** accidentally exposed via Worker logs | High | Low | Workers do not log by default. Explicitly disable `console.log` of secrets. Use Wrangler secrets (never env vars in toml). |

---

## 12. Future Considerations

1. **Durable Objects**: If MCP servers need stateful sessions (e.g., long-running database queries), Durable Objects provide per-session state on Workers. Not needed now.

2. **Workers AI**: Cloudflare Workers AI could run lightweight models at the edge for MCP request preprocessing or response summarization. Evaluate when AI inference at the edge becomes valuable.

3. **Cloudflare D1**: If the API gateway needs a managed database for rate limit state, analytics, or API key storage, D1 (SQLite at the edge) is a natural fit.

4. **Custom domains per Worker**: Currently using path-based routing under `mcp.helixstax.net`. If Workers need isolation, can move to `clickup-mcp.helixstax.net`, etc.

5. **Gravitee re-evaluation**: When Helix Stax onboards external API consumers who need a developer portal, self-service API key management, and API marketplace features, re-evaluate Gravitee. Until then, Cloudflare Workers + Backstage is sufficient.

---

## Appendix A: Updated settings.json (Post-Migration)

```json
{
  "mcpServers": {
    "github-core": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/github/sse"]
    },
    "clickup-pm": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/clickup/sse"]
    },
    "n8n-automation": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/n8n/sse"]
    },
    "zitadel-iam": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/zitadel/sse"]
    },
    "harbor-registry": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/harbor/sse"]
    },
    "trivy-sec": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.helixstax.net/trivy/sse"]
    },
    "opentofu-iac": {
      "command": "npx",
      "args": ["-y", "@opentofu/opentofu-mcp-server"]
    },
    "postgres-db": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_CONNECTION_STRING}"
      }
    },
    "cloudflare-edge": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://observability.mcp.cloudflare.com/sse"],
      "env": {
        "CLOUDFLARE_API_TOKEN": "${CLOUDFLARE_API_TOKEN}"
      }
    },
    "grafana-obs": {
      "command": "npx",
      "args": ["-y", "@grafana/mcp-grafana"],
      "env": {
        "GRAFANA_URL": "${GRAFANA_URL}",
        "GRAFANA_API_KEY": "${GRAFANA_API_KEY}"
      }
    },
    "openbao-vault": {
      "command": "npx",
      "args": ["-y", "@hashicorp/vault-mcp-server"],
      "env": {
        "VAULT_ADDR": "${VAULT_ADDR}",
        "VAULT_TOKEN": "${VAULT_TOKEN}"
      }
    },
    "obsidian-docs": {
      "command": "uvx",
      "args": ["mcp-obsidian-advanced"],
      "env": {
        "OBSIDIAN_VAULT_PATH": "${OBSIDIAN_VAULT_PATH}"
      }
    },
    "loki-logs": {
      "command": "npx",
      "args": ["-y", "@cardinalhq/loki-mcp"],
      "env": {
        "LOKI_URL": "${LOKI_URL}"
      }
    },
    "ansible-ops": {
      "command": "npx",
      "args": ["-y", "@ansible/mcp-server"]
    },
    "valkey-cache": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-redis"],
      "env": {
        "REDIS_URL": "${VALKEY_URL}"
      }
    }
  }
}
```

## Appendix B: Fallback Config (settings.local.json.fallback)

```json
{
  "mcpServers": {
    "github-core": {
      "command": "npx",
      "args": ["-y", "@github/mcp-server"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    },
    "clickup-pm": {
      "command": "npx",
      "args": ["-y", "@taazkareem/clickup-mcp-server"],
      "env": { "CLICKUP_API_KEY": "${CLICKUP_API_KEY}" }
    },
    "n8n-automation": {
      "command": "npx",
      "args": ["-y", "n8n-mcp-server"],
      "env": { "N8N_API_URL": "${N8N_API_URL}", "N8N_API_KEY": "${N8N_API_KEY}" }
    },
    "zitadel-iam": {
      "command": "npx",
      "args": ["-y", "zitadel-mcp-server"],
      "env": { "ZITADEL_DOMAIN": "${ZITADEL_DOMAIN}", "ZITADEL_PAT": "${ZITADEL_PAT}" }
    },
    "harbor-registry": {
      "command": "npx",
      "args": ["-y", "mcp-harbor"],
      "env": { "HARBOR_URL": "${HARBOR_URL}", "HARBOR_USERNAME": "${HARBOR_USERNAME}", "HARBOR_PASSWORD": "${HARBOR_PASSWORD}" }
    },
    "trivy-sec": {
      "command": "npx",
      "args": ["-y", "@aquasecurity/trivy-mcp"]
    }
  }
}
```
