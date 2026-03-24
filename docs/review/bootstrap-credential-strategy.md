# Bootstrap Credential Strategy: Cloudflare Secrets Vault Access

**Author**: Ezra Raines (Security Engineer)
**Date**: 2026-03-23
**Revised**: 2026-03-23 (v2 -- vault-first approach per Wakeem's direction)
**Status**: ADVISORY
**Severity**: Architectural Decision -- no active vulnerability

---

## 1. Problem Statement (Revised)

All Helix Stax secrets live in the Cloudflare Secrets Store (store ID: `76b8b700e1a544659920dc3a843f9626`), exposed via the `secrets-vault` Worker at `secrets-vault.helixstax.workers.dev`. The Worker reads secrets through Secrets Store bindings at runtime -- these bindings require zero external auth from the Worker's perspective. Cloudflare Access sits in front of the Worker and currently demands a **Service Token** (`CF_ACCESS_CLIENT_ID` + `CF_ACCESS_CLIENT_SECRET`) for programmatic access.

The v1 analysis recommended Windows Credential Manager to store the service token locally. **Wakeem's pushback is correct**: the vault was built to be the single source of truth. Storing anything in Windows Credential Manager defeats that intent. The right question is not "where do we store the bootstrap secret locally" but **"can we eliminate the need for a local bootstrap secret entirely?"**

**Revised Constraints**:
- EVERYTHING in the Cloudflare Secrets Vault -- no Windows Credential Manager, no local files, no env vars
- Single developer, Windows 11 workstation
- Access patterns: Claude Code agents (via `mcp-remote`), local Python/bash scripts, `curl`
- The Worker already has direct access to its own Secrets Store bindings without external auth

---

## 2. The Key Insight: The Worker IS Inside the Trust Boundary

The v1 analysis treated the bootstrap problem as unsolvable ("something must live outside the vault"). That framing assumed the only entry path was through Cloudflare Access with a service token. But the Worker itself runs inside Cloudflare's edge -- it already has unauthenticated access to its own Secrets Store bindings. The Worker is the trust root, not the client.

This means the Worker can implement **its own authentication logic** on specific routes, independent of Cloudflare Access. Cloudflare Access is one auth layer; the Worker can add or replace it with alternatives that do not require a pre-shared static secret.

---

## 3. Options Analysis (Vault-First)

### Option A: WARP + Device Posture (RECOMMENDED -- Phase 1)

**How it works**: Enroll Wakeem's workstation in Cloudflare Zero Trust via the WARP client. Modify the Access Application policy for `secrets-vault.helixstax.workers.dev` to accept **device posture checks** (WARP enrolled + user identity) as an alternative to service tokens. When WARP is connected, all HTTPS requests to `*.helixstax.workers.dev` are automatically authenticated by the WARP tunnel -- no headers, no tokens, no local secrets.

**Why this works for Claude Code**: Claude Code agents use `curl` and Python `requests` to hit the vault. When WARP is in "Gateway with WARP" mode and `*.helixstax.workers.dev` is in the split tunnel include list, all traffic from the machine routes through the WARP tunnel. Cloudflare Access sees the device identity and passes the request through. The agent code does not change -- it just stops needing to send `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers.

**Security level**: HIGH

| Pro | Con |
|-----|-----|
| Zero static credentials anywhere | WARP client must be running |
| Device-bound identity (revocable) | If WARP disconnects, vault access fails |
| Session-based, auto-rotating | Initial WARP enrollment requires a one-time browser auth |
| Cloudflare manages the entire auth chain | Requires Zero Trust Teams plan (free tier includes WARP) |
| Scripts and agents work unchanged (remove headers) | Split tunnel config must include `*.helixstax.workers.dev` |

**Implementation**:
1. Download and install Cloudflare WARP client on Windows
2. Enroll in the `helix-hub-tunnel` Zero Trust org (one-time browser auth via GitHub SSO)
3. In Cloudflare Zero Trust dashboard, update the `secrets-vault` Access Application:
   - Add policy: "Allow -- Device Posture: Warp is connected + Identity: GitHub user KeemWilliams"
   - Keep existing service token policy for K3s pods (they cannot run WARP)
4. Configure WARP split tunnel to include `*.helixstax.workers.dev`
5. Test: `curl https://secrets-vault.helixstax.workers.dev/health` (no headers needed)
6. Update all scripts to remove `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers
7. DO NOT delete the service token yet -- K3s pods still need it

**Complexity**: Medium. WARP install is 5 minutes. Policy change is 10 minutes in the dashboard. Split tunnel config is 5 minutes. Testing all access paths is 30-60 minutes.

**Verdict**: This is the right Phase 1. Zero local secrets. The vault is the single source of truth. WARP is the identity layer.

---

### Option B: Browser-Based SSO with Cached JWT (Complement to A)

**How it works**: Cloudflare Access already supports GitHub SSO (configured in `cloudflare-zero-trust-setup.sh`). For interactive sessions, Wakeem authenticates via browser, and Cloudflare Access issues a JWT cookie (`CF_Authorization`). This cookie can be extracted and used in scripts for the duration of its TTL (configurable: 1h-24h).

**How it complements WARP**: If WARP is temporarily disconnected (network issue, VPN conflict), Wakeem can fall back to browser-based auth:
1. Open `https://secrets-vault.helixstax.workers.dev/health` in the browser
2. GitHub SSO flow completes, sets `CF_Authorization` cookie
3. Extract the JWT and use it in scripts: `curl -H "Cookie: CF_Authorization=<jwt>" https://secrets-vault.helixstax.workers.dev/secret/CLICKUP_API_KEY`

**Security level**: HIGH (short-lived JWT, no static secrets)

| Pro | Con |
|-----|-----|
| No static credentials | Requires browser interaction to obtain JWT |
| JWT auto-expires (configurable) | Cannot be used by fully automated/unattended scripts |
| Leverages existing GitHub SSO | JWT in shell history if not careful |
| Works when WARP is down | |

**Verdict**: Good fallback for when WARP is unavailable. Not a standalone solution because it requires human interaction.

---

### Option C: Worker-Level Auth Bypass for Localhost (NOT RECOMMENDED)

**How it works**: Modify the Worker to check `CF-Connecting-IP` against a known IP allowlist (e.g., Wakeem's home IP or a Cloudflare WARP egress IP). If the source IP matches, skip Access auth and serve the secret directly.

**Why I do not recommend this**:
1. **IP addresses change.** Home ISP IPs are dynamic. Hardcoding IPs creates maintenance burden and lockout risk.
2. **IP spoofing is possible** at certain network layers, though Cloudflare's `CF-Connecting-IP` is trustworthy within their network.
3. **Source IP is a weak identity signal.** It tells you which network, not which human or device.
4. **Cloudflare Access already does this better.** Device posture (WARP) is strictly superior to IP allowlisting.

**Security level**: LOW-MEDIUM (IP is not identity)

**Verdict**: Skip. WARP device posture provides the same "no local secret" benefit with much stronger identity guarantees.

---

### Option D: Worker `/bootstrap` Endpoint with Time-Limited Token (INTERESTING BUT PREMATURE)

**How it works**: Add a `/bootstrap` route to the Worker that serves the service token itself, protected by a different auth mechanism:
- The `/bootstrap` endpoint requires a one-time code (TOTP-style) or responds only during a narrow time window after a manual "unlock" action in the Cloudflare dashboard
- The client calls `/bootstrap`, receives a short-lived token, caches it in memory for the session

**Why it is interesting**: The vault becomes fully self-referential -- it bootstraps itself. No external secret storage needed anywhere.

**Why it is premature**:
1. Implementing TOTP in a Worker adds code complexity and a new attack surface
2. The "unlock window" approach requires manual dashboard interaction (worse UX than WARP)
3. WARP already solves this more elegantly with zero custom code
4. If you are going to interact with a browser anyway, Option B (SSO JWT) is simpler

**Security level**: MEDIUM-HIGH (depends on the auth mechanism for `/bootstrap`)

**Verdict**: Architecturally elegant but over-engineered for the current situation. Revisit if WARP proves unreliable or if the system needs to support non-WARP clients (CI/CD runners, etc.).

---

### Option E: Cloudflare Access Service Token (Original Approach -- DEMOTED)

**How it works**: This was the original assumption. Create a Cloudflare Access Service Token, store `CF_ACCESS_CLIENT_ID` + `CF_ACCESS_CLIENT_SECRET` somewhere on the local machine (env vars, Credential Manager, etc.), and send them as headers with every vault request.

**Why it is demoted**: It requires storing a static secret locally. The entire point of the vault was to centralize secrets. Storing a secret to access the secrets defeats the architecture.

**When it is still needed**: K3s pods and CI/CD runners cannot run WARP. They still need service tokens, stored in OpenBao and injected as K8s Secrets. This is acceptable for machine-to-machine auth where WARP is not available.

**Verdict**: Keep for K3s/CI only. Not for Wakeem's workstation.

---

## 4. Revised Comparison Matrix

| Option | Security | Complexity | Local Secrets? | Agent-Compatible | Recommended |
|--------|----------|------------|----------------|-----------------|-------------|
| A. WARP Device Posture | High | Medium | **NONE** | Yes (transparent) | **YES -- Phase 1** |
| B. Browser SSO + JWT | High | Low | None (JWT is ephemeral) | Partial (interactive) | Fallback |
| C. IP Allowlisting | Low-Med | Low | None | Yes | Skip |
| D. Self-Bootstrap Endpoint | Med-High | High | None | Yes | Future/if needed |
| E. Service Token (local) | Medium | Trivial | YES (the problem) | Yes | K3s/CI only |

---

## 5. Recommendation: WARP-First, Single Source of Truth

### Phase 1 (Now): WARP Device Auth

1. Install Cloudflare WARP on Wakeem's Windows machine
2. Enroll in Zero Trust org via GitHub SSO (one-time browser flow)
3. Update Access Application policy for `secrets-vault`:
   - Add: "Allow -- Require WARP + Require Identity: GitHub `KeemWilliams`"
   - Keep: Existing service token policy (for K3s pods)
4. Configure split tunnel to include `*.helixstax.workers.dev`
5. Remove `CF-Access-Client-Id` / `CF-Access-Client-Secret` from all local scripts:
   - `shared/scripts/set-clickup-statuses.sh` (line 11 area)
   - `shared/scripts/sync_clickup_templates.py` (line 87 area)
   - `shared/scripts/clickup_audit.py` (line 44 area)
   - `shared/scripts/migrate_to_space03.py` (line 20 area)
   - `shared/cloudflare-workers/secrets-vault/update_clickup_tasks.py` (line 66 area)
   - `helix-stax-infrastructure/scripts/cloudflare-zero-trust-setup.sh` (line 24)
6. Test all access paths work through WARP without headers
7. Document the setup in `docs/runbooks/warp-enrollment.md`

**Security properties**:
- Zero static credentials on the workstation
- Device-bound identity managed by Cloudflare
- Session-based, auto-rotating
- Revocable per-device from Zero Trust dashboard
- The vault remains the single source of truth

### Phase 1.5 (Immediate follow-up): Fallback path

1. Document the browser SSO fallback (Option B) in the runbook
2. If WARP disconnects, Wakeem can auth via browser and extract the JWT
3. This is a manual fallback -- not a permanent auth path

### Phase 2 (K3s/CI hardening): Scoped Service Tokens

For machine-to-machine auth (K3s pods, future CI/CD):
- Service tokens stored in OpenBao, injected as K8s Secrets
- Each token scoped to exactly one Access Application
- 90-day rotation via automation
- These machines cannot run WARP, so service tokens are the correct pattern here

### Phase 3 (Team growth): Per-User Identity

When Helix Stax has employees:
- Each user enrolls their device via WARP
- Access policies use identity groups (not individual usernames)
- Service tokens for shared infrastructure, WARP for humans
- Audit logging via Cloudflare Access logs (already available)

---

## 6. Security Notes

### What to AVOID

1. **Windows Credential Manager for vault access** -- unnecessary when WARP eliminates the bootstrap secret entirely
2. **`.env.secrets` in any project directory** -- even gitignored, these get copied, backed up, and forgotten
3. **Hardcoded values in scripts** -- the existing `cloudflare-zero-trust-setup.sh` has `CF_ACCOUNT_ID` hardcoded (line 22). Account IDs are not secret, but this pattern encourages credential creep.
4. **Storing anything in Claude's `.claude/` directory** -- this directory is synced, version-controlled, and read by hooks
5. **Environment variables as a permanent solution** -- acceptable only as a temporary bridge while WARP is being configured

### WARP Operational Considerations

1. **WARP conflicts with other VPNs**: If Wakeem uses a personal VPN, WARP may conflict. Test coexistence or configure WARP in split tunnel mode to minimize interference.
2. **WARP must be running**: If WARP disconnects (laptop sleep, network change), vault access fails until reconnected. This is a feature (no ambient credential to exfiltrate) but requires awareness.
3. **WARP enrollment is device-specific**: If Wakeem gets a new machine, re-enrollment is required. The old device should be revoked in the Zero Trust dashboard.
4. **Monitoring**: Cloudflare Access logs show all vault access attempts. Set up an n8n alert for failed access attempts to detect anomalies.

### Service Token Scoping (for K3s/CI only)

- Scope each token to ONE Access Application only
- Set 90-day expiry (not the 1-year default)
- Name descriptively: `k3s-vault-access`, `ci-vault-deploy`
- Store in OpenBao at `secret/cloudflare-zero-trust/{token-name}`
- Rotate via automation, never manually

---

## 7. The Corrected Fundamental Truth

The v1 analysis stated: "The bootstrap credential problem has no zero-secret solution at the local level." **This was wrong for this specific architecture.** The Cloudflare WARP client IS the zero-secret solution. It replaces static credentials with a device-bound, session-based identity that Cloudflare manages end-to-end:

- **No static secret** exists on the workstation
- **No file** to commit, encrypt, or rotate
- **No environment variable** to leak
- **The vault** remains the single source of truth for all secrets
- **The identity** is managed by Cloudflare, not by the local machine

The bootstrap problem still exists in the abstract -- WARP's enrollment is the "secret zero" (it happens once via browser SSO and is cached as a device identity). But this is qualitatively different from storing a credential: the enrollment is interactive, the session is ephemeral, and the identity is revocable from a central dashboard. For a single-developer setup, this effectively eliminates the problem.

| Property | Service Token (old) | WARP (new) |
|----------|--------------------|----|
| **Local secret exists?** | YES | NO |
| **Rotation needed?** | Every 90 days | Never (session-based) |
| **Exfiltration risk** | Any process can read env var | No credential to exfiltrate |
| **Revocation** | Rotate token + update all consumers | Click "revoke device" in dashboard |
| **Audit trail** | Must be configured separately | Built into Cloudflare Access logs |
| **Works for K3s pods?** | YES | No (pods use service tokens) |
| **Vault is single source of truth?** | No (token lives outside vault) | YES |

---

## Appendix: Scripts Requiring Update

These scripts currently send `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers to the vault. After WARP is configured, these headers become unnecessary for local execution (WARP handles auth transparently). Remove the header logic but keep the vault URL.

| File | Line(s) | Current Pattern |
|------|---------|-----------------|
| `shared/scripts/set-clickup-statuses.sh` | ~11 | `curl` with CF-Access headers |
| `shared/scripts/sync_clickup_templates.py` | ~87 | `requests.get()` with CF-Access headers |
| `shared/scripts/clickup_audit.py` | ~44 | `requests.get()` with CF-Access headers |
| `shared/scripts/migrate_to_space03.py` | ~20 | `requests.get()` with CF-Access headers |
| `shared/cloudflare-workers/secrets-vault/update_clickup_tasks.py` | ~66 | `requests.get()` with CF-Access headers |
| `helix-stax-infrastructure/scripts/cloudflare-zero-trust-setup.sh` | 24 | `curl` with CF-Access headers to fetch API token |
