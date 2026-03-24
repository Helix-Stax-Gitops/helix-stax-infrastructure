# Cloudflare Product Audit — DevOps Review

**Reviewer:** Kit Morrow (stax-devops-engineer)
**Date:** 2026-03-23
**Source doc:** `docs/review/cloudflare-product-audit.md`

---

## 1. TUNNELS — cloudflared Deployment Strategy

**What the audit says:** Deploy cloudflared as a Kubernetes Deployment in K3s, route wildcard `*.helixstax.net` through the tunnel to the Traefik ClusterIP service. The architecture diagram calls it a "daemonset" in one place and a "Deployment" in another.

**Assessment:**

- **Deployment is correct, DaemonSet is wrong.** A DaemonSet runs one pod per node — that means two replicas here (heart + helix-worker-1), which would cause both to race for the same tunnel connection. cloudflared Deployments with `replicas: 2` are the correct HA pattern: both pods maintain outbound QUIC connections to the Cloudflare edge, and Cloudflare load-balances between them. Replicas beyond 2 provide no additional benefit for a two-node cluster.
- **Namespace:** Deploy in `kube-system` or a dedicated `cloudflare` namespace. Do NOT put it in `default`. Most production setups use a dedicated namespace for clarity. `kube-system` is acceptable since it is infrastructure, not an app workload.
- **Target service:** Route to `traefik` ClusterIP in `kube-system` (port 80 for HTTP). Traefik then handles all host-based routing via IngressRoutes as it does today. This is the correct approach — one tunnel entry point, Traefik does the internal dispatch.
- **Tunnel config:** The tunnel `config.yaml` must specify `ingress` rules. Use a catch-all rule pointing to `http://traefik.kube-system.svc.cluster.local:80`. Do NOT create per-service tunnel routes — that defeats the purpose of having Traefik.
- **Missing from the audit:** The audit does not mention that cloudflared needs a `TunnelToken` secret (or credentials file) created via `cloudflared tunnel create`. This is a real operational step that must happen before the Deployment can be applied. The token goes into a Kubernetes Secret, referenced as an env var or mounted file. The audit glosses over this entirely.
- **Inconsistency flagged:** The audit says "daemonset" in the Target Architecture section and "Deployment" in the product table. The product table is correct. The narrative is wrong.

---

## 2. HYPERDRIVE — Connectivity to CloudNativePG Through the Tunnel

**What the audit says:** Hyperdrive connects to CloudNativePG in K3s, using the cloudflared tunnel to bridge the network gap. Listed as FREE tier. "100 maximum origin connections."

**Assessment:**

- **The connectivity path is not as simple as stated.** Hyperdrive connects to a database using a standard PostgreSQL connection string (host:port). Since CloudNativePG runs on a private cluster IP, Hyperdrive at the Cloudflare edge cannot reach it directly. The audit says it "must be configured to utilize the Cloudflare Tunnel" — but this is not how Hyperdrive actually works. Hyperdrive does not route through `cloudflared`. It makes a direct outbound TCP connection to the database host. The supported workarounds are:
  - Expose CloudNativePG on a public IP (bad idea, defeats Zero Trust posture).
  - Use a Cloudflare tunnel with a **TCP** service (not HTTP) — specifically `cloudflared access tcp` which creates a local proxy. This is complex and not natively supported in Hyperdrive's connection flow.
  - The cleanest supported path: deploy a PgBouncer or connection pooler on the K3s node, expose it via the tunnel, and point Hyperdrive at the tunnel's public hostname over port 5432. This requires a `Spectrum` product for non-HTTP TCP proxying OR a specific tunnel TCP service config.
  - **Alternatively:** Keep Hyperdrive for future Workers that connect to a publicly reachable database (e.g., a future managed Postgres). For the current in-cluster CloudNativePG setup, the audit's claim that this "just works" via the tunnel is not accurate without significant additional configuration.

- **SSL / pgBouncer conflicts:** Hyperdrive performs its own connection pooling. If you put pgBouncer in front of CloudNativePG AND route through Hyperdrive, you have double pooling. This is actually fine for read performance but can cause confusion with prepared statement caching (pgBouncer in transaction mode drops prepared statements; Hyperdrive's caching layer may re-issue them). For the current scale (pre-revenue, few concurrent Workers), this is low risk but worth knowing.

- **Connection string format:** Hyperdrive requires a standard `postgresql://user:password@host:5432/dbname` string. The password cannot be pulled from OpenBao at Hyperdrive config time — it must be provided as a static credential when creating the Hyperdrive config via the API/dashboard. This means a dedicated, long-lived database user must exist for Hyperdrive, separate from app credentials. The audit does not mention this.

- **"100 max origin connections" on free tier:** Confirmed correct per Cloudflare docs. Sufficient for current scale.

- **Bottom line:** The audit's Hyperdrive recommendation is architecturally sound as a concept, but the claim that it connects through the tunnel transparently is misleading. Implementation requires non-trivial TCP tunnel configuration that the audit does not detail. Rate this as a Phase 2+ item, not a Phase 1 quick win.

---

## 3. COST — Is $25/mo (Pro + Workers Paid) Really Enough?

**What the audit implies:** Pro plan at $20/mo + Workers Paid at $5/mo = $25/mo covers the recommended stack.

**Assessment:**

**Confirmed included at $25/mo:**
- WAF Managed + Custom Rules
- Super Bot Fight Mode
- Rate Limiting
- DDoS Protection (unmetered)
- Cloudflare Tunnels (free, no plan needed)
- AI Gateway (free)
- R2 (free tier: 10 GB-month storage, 1M Class A ops, 10M Class B ops)
- Pages (free tier)
- Workers KV (free tier: 100K reads/day, 1K writes/day)
- Cloudflare Access (free up to 50 users — solo founder fits)
- WARP + Device Posture (free up to 50 users)
- Audit Logs v2 (free)
- Logpush (included in Pro — this is correct)

**Hidden costs the audit missed or understated:**

- **Durable Objects** — listed as "YES-PAID" but the audit does not quantify. Durable Objects billing is $0.15/million requests + $0.20/GB-month storage. For 23 agents doing frequent state operations, this can add up. Budget $5-15/mo depending on agent activity.
- **Queues** — "Paid Tier" means it requires Workers Paid ($5/mo base already accounted for), but message counts beyond the free allocation ($0.40 per million messages) could surprise. Low risk at current scale.
- **Browser Rendering** — listed as "YES-PAID" with no price. It is billed per-request ($0.001/request). If agents are scraping client sites frequently, this adds up fast. Not a fixed cost.
- **R2 egress to the internet** is free. R2 egress to non-Cloudflare origins (e.g., pulling R2 objects from the K3s cluster) does incur Class B operation charges. At small scale (free tier), fine. Worth knowing.
- **Workers KV write limits** — 1K writes/day on free tier. If the secrets-vault Worker is writing frequently (agent credentials rotation), this could be hit. Workers Paid bumps this significantly.
- **Logpush to R2** — Logpush itself is included in Pro, but if WAF events are high-volume and you push to R2, you'll consume R2 write operations. Monitor this.
- **Realistic monthly estimate:** $25/mo base + $5-15 Durable Objects + $0-5 misc = **$30-45/mo** for active agent usage. Not $25 flat.

**What the audit got right on cost:** The distinction between free/paid tiers is largely accurate. The major line items are correct. The "hidden" costs are usage-based, not subscription-based, so they are genuinely hard to predict upfront.

---

## 4. IMPLEMENTATION — Phase Order and Missing Dependencies

**What the audit recommends:**
- Phase 1 (Week 1): DNS cleanup, email security (DMARC/SPF/DKIM/MTA-STS), security.txt, MFA, Bot Fight Mode
- Phase 2 (Days 7-30): cloudflared deployment, Access policies, WARP device posture, Hyperdrive
- Phase 3 (Website launch): Pages, AI Gateway, Service Tokens, cloudflare/mcp Code Mode

**Assessment:**

**Phase 1 order is correct.** DNS hygiene and email auth are entirely independent of the K3s cluster. Zero risk, high value. This is right.

**Phase 2 dependencies that are missing from the audit:**

1. **cloudflared tunnel must be created and token provisioned BEFORE deploying the K8s manifest.** The audit jumps straight to "deploy cloudflared daemon on K3s" without mentioning the prerequisite: `cloudflared tunnel create helix-stax` via CLI or dashboard, save the credentials JSON to a Kubernetes Secret. Without this, the Deployment crashes immediately.

2. **Traefik must be configured to trust the cloudflared source before closing the firewall.** If you close ports 80/443 at the Hetzner firewall before verifying tunnel routing works end-to-end, you lock yourself out. The correct sequence is: (a) deploy cloudflared, (b) verify traffic flows through the tunnel, (c) THEN close inbound ports.

3. **Authenticated Origin Pulls (listed as YES-FREE in the audit) must be configured before Cloudflare Tunnels if you're doing a hybrid migration.** If you go straight to tunnels, Authenticated Origin Pulls are irrelevant and can be skipped. The audit recommends both, which creates confusion about sequencing.

4. **Access policies for Zitadel (identity provider) must be configured BEFORE enabling Access on other services.** If you lock down Grafana/Devtron behind Access but Zitadel is also behind Access without its own bypass rule, you create a circular auth dependency. The audit does not address this.

5. **Phase 2 puts Hyperdrive alongside cloudflared deployment.** As noted in Section 2, Hyperdrive's connectivity to in-cluster CloudNativePG is not a simple configuration. Treating it as a Week 2-4 item alongside tunnel setup is over-ambitious. Move Hyperdrive to Phase 3 or later.

**Phase 3 order is fine.** AI Gateway is a URL change in agent config. Service Tokens are straightforward once Access is running. Pages deployment is independent.

**One missing phase entirely:** The audit has no rollback/validation checkpoints. Every phase should end with a smoke test before proceeding. Specifically, after Phase 2, you need to verify that ALL services are reachable via the tunnel before closing the firewall, and that at least one Access-protected service authenticates correctly end-to-end.

---

## 5. PRACTICAL — First Thing to Do and Easiest Quick Win

**First thing I would do from this audit:**

Deploy cloudflared as a Kubernetes Deployment in `kube-system`, pointed at the Traefik ClusterIP, running in parallel with the existing proxied DNS. Do NOT change DNS yet. Just validate that traffic can flow from Cloudflare edge to Traefik via the tunnel. Once confirmed, update one non-critical DNS record to route through the tunnel. If it works for a day, migrate the rest. Only THEN close the Hetzner firewall ports.

This is the highest-leverage change in the entire audit (it closes the origin IP exposure vector) and it can be done incrementally without disrupting anything in production.

**Easiest quick win (least effort, immediate compliance value):**

DMARC record. It is a single DNS TXT record. Takes 5 minutes. Start with `p=none` (reporting only, no enforcement) to collect data without risking email delivery. The audit recommends jumping straight to `p=reject` — that is too aggressive without first validating SPF and DKIM alignment. Standard practice: `p=none` for 2-4 weeks to read reports, then escalate to `p=quarantine`, then `p=reject`. The audit skips this ramp-up entirely, which is a real operational risk if SPF/DKIM are misconfigured and you go straight to reject.

**Second quickest win:** Purge the stale DNS records (`auth.helixstax.net`, `s3.helixstax.net`). Zero risk if those services are not running. Subdomain takeover is a real threat and this takes 2 minutes.

---

## Summary of Corrections to the Audit

| Area | Issue | Severity |
|------|-------|----------|
| cloudflared deployment type | Audit says "daemonset" in the architecture narrative, "Deployment" in the table. Deployment is correct. | Low (terminology) |
| Tunnel token provisioning | Missing step: tunnel must be created and credentials stored in K8s Secret before Deployment works | High (blocks Phase 2) |
| Hyperdrive connectivity | Claim that Hyperdrive routes through cloudflared is not accurate. Requires non-trivial TCP tunnel config | High (architecture gap) |
| Hyperdrive timing | Listed as Phase 2 alongside tunnel setup. Should be Phase 3+ | Medium |
| DMARC ramp-up | Audit recommends jumping to `p=reject` immediately. Should start with `p=none` | Medium (ops risk) |
| Cost estimate | $25/mo understates Durable Objects costs for active agent usage. Realistic: $30-45/mo | Low |
| Firewall close sequencing | No warning about verifying tunnel end-to-end BEFORE closing inbound ports | High (lockout risk) |
| Zitadel / Access circular dependency | Not addressed. Access on all services including IdP needs careful policy ordering | Medium |
