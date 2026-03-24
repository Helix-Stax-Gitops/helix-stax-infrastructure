# Secrets Management Architecture — Helix Stax

**Author**: Quinn Mercer
**Date**: 2026-03-22
**Status**: Active

## Three-Store Model

| Store | What It Holds | Who Accesses | Where |
|-------|--------------|-------------|-------|
| Cloudflare Secrets Store | Worker secrets (API keys, tokens, OAuth creds) | Cloudflare Workers, AI Gateway | dash.cloudflare.com → Secrets Store |
| OpenBao | K8s pod secrets (dynamic DB creds, PKI certs, transit encryption) | K8s pods via ESO | Data server (planned CX22) |
| Local .env.secrets | Dev machine secrets (CLI tools, Claude Code env vars) | Local processes only | ~/.claude/.env.secrets |

## Cloudflare Secrets Store
- Store ID: 76b8b700e1a544659920dc3a843f9626
- Account: 57046d4890f574ed90c545f51acb67d8
- Capacity: 100 secrets (10 used, 90 available)
- Permission scopes: Workers + AI Gateway
- RBAC: Super Admin, Secrets Store Admin, Deployer, Reporter

### Secrets Inventory (10 active)
| Secret | Worker | Rotated |
|--------|--------|---------|
| CLICKUP_API_KEY | mcp-clickup | 2026-03-22 |
| GITHUB_PAT_PERSONAL | future Workers | 2026-03-22 |
| GOOGLE_CLIENT_ID | mcp-google | static |
| GOOGLE_CLIENT_SECRET | mcp-google | 2026-03-22 |
| CLOUDFLARE_API_TOKEN | wrangler deploys | 2026-03-22 |
| HETZNER_CLOUD_TOKEN | future Workers | 2026-03-22 |
| HETZNER_ROBOT_USER | future Workers | 2026-03-22 |
| HETZNER_ROBOT_PASS | future Workers | 2026-03-22 |
| COOKIE_ENCRYPTION_KEY | mcp-google | 2026-03-22 (new) |
| MCP_AUTH_TOKEN | mcp-clickup | 2026-03-22 (new) |

### Pending (cluster down)
N8N_API_KEY, N8N_API_URL, ZITADEL_DOMAIN, ZITADEL_PAT, VAULT_ADDR, VAULT_TOKEN, HARBOR_URL, HARBOR_USERNAME, HARBOR_PASSWORD, GRAFANA_URL, GRAFANA_API_KEY

## Worker Bindings
Workers access Secrets Store via wrangler.jsonc:
```json
"secrets_store_secrets": [
  {
    "binding": "SECRET_NAME",
    "store_id": "76b8b700e1a544659920dc3a843f9626",
    "secret_name": "SECRET_NAME"
  }
]
```

## Rotation Policy
- Cycle: 90 days
- Next rotation: 2026-06-20 (ClickUp: 86e0gphc9)
- Log: ~/.claude/helix-stax-secrets/rotation-log-YYYY-MM-DD.md
- Never have agents read .env.secrets

## What NOT to Store in Cloudflare
- PHI (HIPAA)
- Dynamic database credentials (use OpenBao)
- TLS certificates (use OpenBao PKI)
- K8s service account tokens (use OpenBao K8s auth)
