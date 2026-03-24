# Gemini Deep Research: Cloudflare Tunnels & Zero Trust Access — Deep Reference

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

Cloudflare Tunnel (cloudflared) creates an outbound-only encrypted connection from a server to the Cloudflare network — no inbound firewall holes, no public IP exposure, no NAT traversal headaches. The `cloudflared` daemon runs as a connector on the server side, establishes four persistent QUIC or HTTP/2 connections to Cloudflare's edge, and Cloudflare routes public traffic through those connections to internal services.

Cloudflare Zero Trust Access sits on top of the tunnel layer and adds identity-aware access control: every request to a protected application must pass through an Access policy before it reaches the service. Access integrates with OIDC identity providers (we use Zitadel), evaluates user identity and device posture, and issues short-lived JWT tokens that authorize the session.

Together, these two tools replace the traditional "VPN + firewall + public IP" model with a zero-trust architecture where:
- No server ports are exposed to the internet
- Every service is protected by identity policy, not just network rules
- Machine-to-machine access uses Service Tokens, not shared credentials
- SSH access is proxied through the browser or via short-lived certificates — no long-lived SSH keys required

For Helix Stax, this is the primary path from the public internet to all internal K3s services. Getting this right is critical because it is the security boundary for the entire platform.

## Our Specific Setup

- **K3s cluster**: helix-stax-cp (178.156.233.12, cpx31, Hetzner ash-dc1)
- **VPS**: helix-stax-vps (5.78.145.30, cpx31, Hetzner hil-dc1, role TBD)
- **SSH port**: 2222 (non-standard, affects cloudflared SSH access config)
- **Admin user**: `wakeem`
- **OS**: AlmaLinux 9.7
- **Ingress**: Traefik v3 deployed via Helm (bundled K3s Traefik disabled)
- **Identity**: Zitadel self-hosted at `zitadel.helixstax.net`
- **Secrets**: OpenBao (vault) + External Secrets Operator (ESO) for K8s secret injection
- **TLS**: Cloudflare Origin CA (15-year certs) — NO cert-manager, NO Let's Encrypt
- **DNS**: Cloudflare (authoritative for helixstax.com and helixstax.net)
- **Public domain**: helixstax.com (website, email)
- **Internal domain**: helixstax.net (all platform services)
- **Existing tunnel**: cloudflared tunnel exists for vault/secrets Worker access (JWT auth)
- **Cloudflare Access**: configured for secrets-vault Worker, expanding to all internal services
- **IaC**: OpenTofu for Cloudflare resources, Ansible for OS-level config, Helm for K8s workloads
- **CD**: Devtron + ArgoCD
- **Monitoring**: Prometheus + Grafana + Loki

### Services to expose via tunnel (complete list):

| Service | Internal address | Public hostname |
|---------|-----------------|-----------------|
| Traefik dashboard | traefik-dashboard.kube-system.svc:9000 | traefik.helixstax.net |
| Grafana | grafana.monitoring.svc:3000 | grafana.helixstax.net |
| n8n | n8n.n8n.svc:5678 | n8n.helixstax.net |
| ArgoCD | argocd-server.argocd.svc:443 | argocd.helixstax.net |
| Devtron | devtron-service.devtroncd.svc:80 | devtron.helixstax.net |
| Harbor | harbor-core.harbor.svc:80 | harbor.helixstax.net |
| Zitadel | zitadel.zitadel.svc:8080 | zitadel.helixstax.net |
| Outline | outline.outline.svc:3000 | outline.helixstax.net |
| Rocket.Chat | rocketchat.rocketchat.svc:3000 | chat.helixstax.net |
| MinIO Console | minio-console.minio.svc:9001 | minio.helixstax.net |
| Open WebUI | open-webui.ai.svc:8080 | ai.helixstax.net |
| Backstage | backstage.backstage.svc:7007 | backstage.helixstax.net |

---

## What I Need Researched

---

### CF-TUN-1. cloudflared Architecture

Understand exactly how the connector works before deploying it:

**Tunnel mechanics:**
- What is a named tunnel vs a legacy (TryCloudflare) tunnel — when each exists, why we always use named tunnels
- The four QUIC connections cloudflared establishes — purpose of multiple connections, what happens if one drops
- QUIC vs HTTP/2 fallback: when does cloudflared fall back, how to force one or the other
- Connector vs tunnel: a tunnel can have multiple connectors (for HA) — how this works, what `--ha-connections` does
- Tunnel UUID vs tunnel name: when you use each in DNS, in config, in the dashboard
- The `cloudflared tunnel token` command: what the token contains, why it can be revoked
- Tunnel credentials file (`credentials-file`): format, what it contains, where to store it securely
- How cloudflared authenticates to Cloudflare: the token flow from creation to connection
- Reconnection behavior: what happens on network interruption, exponential backoff, reconnection limits
- Health check mechanism: how Cloudflare knows a tunnel connector is healthy vs degraded

**Traffic path:**
- Exact path for a request: browser → Cloudflare edge → QUIC to cloudflared → internal service
- Where TLS terminates: at Cloudflare edge (public TLS), then within the tunnel (can be plaintext or TLS)
- `originServerName` and `noTLSVerify`: when to use each when the internal service is HTTP vs HTTPS
- HTTP vs HTTPS to the origin: for K3s services behind Traefik (which has our Cloudflare Origin CA cert), should tunnel connect via HTTP or HTTPS to Traefik?

---

### CF-TUN-2. Deploying cloudflared on K3s

The `cloudflared` connector must run inside K3s so it can reach internal services by cluster DNS:

**Deployment options:**
- cloudflared as a K3s Deployment (NOT DaemonSet): why Deployment is correct for a single-tunnel connector, replica count recommendations (2 for HA)
- Official Helm chart: `cloudflare/cloudflared` — repository URL, chart name, current version, values reference
- Raw Kubernetes manifests as alternative: when to prefer manifests over Helm (our case: Devtron manages everything via Helm, so use the chart)
- Namespace: where to deploy cloudflared (dedicated `cloudflare` namespace vs `kube-system`)
- Resource requests and limits appropriate for cloudflared on a cpx31 node
- Service account requirements: does cloudflared need any K8s RBAC, or is it purely outbound?
- Liveness and readiness probes: does the official Helm chart configure these? What health endpoint does cloudflared expose?

**Tunnel token delivery:**
- cloudflared requires the tunnel token at runtime — it must not be in plain text in Git
- Flow: OpenTofu creates tunnel → stores token in OpenBao → ESO syncs to K8s Secret → cloudflared Deployment reads from Secret via `valueFrom.secretKeyRef`
- Helm chart value for specifying the token secret reference (not the token value directly)
- Token rotation: how to rotate a tunnel token without downtime (create new connector, drain old)

**Multi-replica considerations:**
- Running 2 replicas of cloudflared for the same tunnel: does Cloudflare load-balance across them?
- Pod anti-affinity to spread replicas across nodes (relevant when VPS joins as worker)
- Connection behavior with 2 replicas: 4 connections each = 8 total connections to Cloudflare edge

---

### CF-TUN-3. Tunnel Ingress Configuration

The tunnel ingress config maps public hostnames to internal K8s services:

**Config file format:**
- `config.yaml` for cloudflared: full format for the `ingress` section
- Hostname matching: exact match vs wildcard (`*.helixstax.net`) — when each is appropriate
- `service` field: format for K8s service URLs (`http://service-name.namespace.svc.cluster.local:port`)
- Default catch-all rule: required `service: http_status:404` at the bottom — what happens without it
- `originRequest` options per hostname: `noTLSVerify`, `originServerName`, `connectTimeout`, `tlsTimeout`, `httpHostHeader`, `http2Origin`
- `httpHostHeader`: when you need to override the Host header sent to the origin (important for Traefik routing by hostname)

**Recommended routing pattern — tunnel to Traefik:**
- Pattern A (tunnel → Traefik → services): all hostnames route to `http://traefik.kube-system.svc.cluster.local:80`, Traefik handles host-based routing to individual services via IngressRoute
- Pattern B (tunnel → individual services): each hostname routes directly to the service
- Why Pattern A is almost always correct: single TLS termination point, Traefik middleware (ForwardAuth, rate limiting) applies to all services, one place to manage routing
- When Pattern B is correct: services that need direct passthrough without Traefik (none in our case)
- With Pattern A: cloudflared connects to Traefik via HTTP (port 80) inside the cluster — Traefik handles HTTPS to clients via Cloudflare Origin CA
- IngressRoute requirement: each service needs a Traefik IngressRoute with `Host()` matcher for its public hostname

**Wildcard tunnel routes:**
- Can one tunnel ingress rule handle `*.helixstax.net` → Traefik? Wildcard DNS considerations.
- Wildcard vs per-hostname: trade-offs for Access policy granularity (per-hostname Access apps require per-hostname tunnel entries)

---

### CF-TUN-4. DNS Configuration for Tunnels

**CNAME approach:**
- `cloudflared tunnel route dns <tunnel-name> <hostname>`: what this creates in Cloudflare DNS (CNAME to `<tunnel-uuid>.cfargotunnel.com`)
- Managing these CNAMEs in OpenTofu: `cloudflare_record` resource with `type = "CNAME"` and `value = "<tunnel-uuid>.cfargotunnel.com"`
- Proxy status: CNAME records for tunnels must be proxied (orange cloud) — confirm
- Wildcard CNAME: `*.helixstax.net → <tunnel-uuid>.cfargotunnel.com` — does this work? When to use it vs individual CNAMEs.
- DNS propagation: typical propagation time for Cloudflare-managed DNS

**DNS routing vs ingress routing:**
- Difference between DNS-level routing (which tunnel handles the hostname) vs tunnel ingress (what internal service it goes to)
- Multiple tunnels: could we have a separate tunnel per service? Reasons not to (complexity) vs single tunnel for everything.

---

### CF-TUN-5. Cloudflare Zero Trust Access

**Access application definitions:**
- What a Cloudflare Access Application is: the unit of protection (hostname or path)
- Application types: self-hosted (our use case), SaaS, private network
- Creating an Access Application for each Helix Stax service: required fields (name, domain, session duration, identity providers)
- Session duration: recommended for internal tools (8h vs 24h vs browser-session)
- CORS settings in Access applications: when to configure, what headers to allow

**Access policies:**
- Policy components: action (allow/deny/bypass), rules (email, email domain, IP range, OIDC claims, service token, country)
- Allow policy with OIDC/Zitadel: requiring authentication via Zitadel OIDC — exact policy rule configuration
- Bypass policy: for services that need public access without auth (webhook receivers in n8n, public API endpoints) — how to bypass for specific paths
- Service token policy: for machine-to-machine (CI/CD, n8n webhooks) — how service tokens work in Access policies
- Policy evaluation order: when multiple policies exist on one application

**OIDC integration with Zitadel:**
- Configuring Zitadel as an identity provider in Cloudflare Zero Trust: required fields (authorization endpoint, token endpoint, client ID, client secret, JWKS URI)
- Zitadel OIDC application type for Cloudflare: Web application, PKCE required?
- Redirect URI that Cloudflare Access uses (the `{account}.cloudflareaccess.com/cdn-cgi/access/callback` pattern)
- Scopes required: `openid email profile` minimum — any others?
- How Cloudflare Access validates OIDC tokens from Zitadel: what claims it uses for policy evaluation
- Using Zitadel roles/groups in Access policies: mapping Zitadel project roles to Access group rules
- OIDC token lifetime vs Access session duration: what to configure in Zitadel

---

### CF-TUN-6. Access Groups

**Group definitions:**
- What Cloudflare Access Groups are: reusable identity criteria referenced in multiple policies
- Group types: include, exclude, require — how they combine (AND/OR logic)
- Creating groups for Helix Stax:
  - `helix-admins`: Wakeem's email (wakeem@helixstax.com) — always allowed
  - `helix-team`: any @helixstax.com email domain
  - `machines`: service token only (for CI/CD, automation)
- Using group "require" for additional MFA enforcement

**Group-policy mapping for our services:**

| Service | Access Group | Reason |
|---------|-------------|--------|
| Grafana | helix-admins | Admin-only for now |
| n8n | helix-admins | Automation admin |
| ArgoCD | helix-admins | GitOps admin |
| Devtron | helix-admins | CI/CD admin |
| Harbor | helix-team | Container registry |
| Zitadel | helix-admins | Identity admin |
| Outline | helix-team | Knowledge base |
| Rocket.Chat | helix-team | Team chat |
| MinIO Console | helix-admins | Storage admin |
| Open WebUI | helix-team | AI interface |
| Backstage | helix-team | Internal portal |

---

### CF-TUN-7. Service Tokens

Service tokens enable machine-to-machine access through Cloudflare Access without browser-based authentication:

**What service tokens are:**
- A client ID and client secret pair that bypasses the browser OIDC flow
- How they are presented: `CF-Access-Client-Id` and `CF-Access-Client-Secret` HTTP headers
- Token expiry: service tokens have configurable expiry (1 year, never, etc.) — recommendation for CI/CD
- Storing service tokens: in OpenBao, synced to K8s Secrets via ESO

**Use cases in Helix Stax:**
- Devtron pipeline → Harbor (pull images): service token in pipeline environment
- n8n → internal APIs: service token as HTTP header in n8n HTTP node
- Ansible/OpenTofu → cluster API: if K8s API is ever proxied through Access
- Prometheus scraping services behind Access: service token in scrape config (or bypass policy for /metrics paths)

**Service token vs JWT bypass:**
- When to use service token (machine identity with Access enforcement) vs bypass policy (no Access check at all)
- Security implications of bypass: bypass removes all Access enforcement, use only for public-facing paths

---

### CF-TUN-8. SSH Access via Cloudflare Access

Cloudflare Access can proxy SSH connections, enabling browser-based SSH and short-lived certificate authentication:

**Short-lived SSH certificates:**
- How Cloudflare issues short-lived SSH certs: the flow from Access login to cert issuance
- Configuring the SSH Access application: `SSH` application type vs self-hosted with TCP
- Installing the Cloudflare CA on the server: `cloudflared access ssh-keygen` or the `TrustedUserCAKeys` sshd config
- `cloudflared access ssh` client command: what it does, how it wraps SSH
- SSH config file: `ProxyCommand cloudflared access ssh --hostname %h` pattern
- Port consideration: our SSH is on 2222, not 22 — how to configure this in the Access application and in the client SSH config
- Short-lived cert expiry: default is 1 minute — is this configurable?

**Browser-based SSH:**
- Cloudflare Access "Browser SSH" rendering: no local SSH client needed
- How to enable it: Application → Settings → Browser rendering → SSH
- Prerequisite: `cloudflared` must be running on the server and connected to the tunnel
- Limitations: no file transfer, session recording (if Access has audit logging)

**Restricting direct SSH:**
- After enabling SSH via Access: how to restrict firewalld so port 2222 is NOT accessible from the public internet, only via Cloudflare WARP or tunnel
- `AllowedIPAddresses` pattern: restricting SSH to Cloudflare WARP IP ranges or allowing only localhost/WARP addresses

---

### CF-TUN-9. WARP Client and Private Networks

Cloudflare WARP + tunnel enables a VPN-like experience for accessing private K8s services without exposing them publicly:

**WARP client enrollment:**
- Enrolling a device in Cloudflare WARP for Teams: enrollment certificate, device policy
- Enrolling on Windows 11 (my workstation): WARP client installer, Teams enrollment URL
- Device posture checks: disk encryption, OS version, serial number — which are feasible on a Windows 11 workstation
- Split tunneling: routing only `helixstax.net` (10.0.0.0/8 range) through WARP, not all traffic
- Split tunnel by domain: `helixstax.net` routes through WARP, everything else routes normally

**Private network access via WARP:**
- Enabling `cloudflared` to advertise private routes: `--private-network` or tunnel route IP configuration
- Advertising K3s cluster CIDR (10.42.0.0/16) and service CIDR (10.43.0.0/16) through the tunnel
- WARP routing: device enrolled in WARP can reach `10.42.x.x` services directly via tunnel
- K8s API access: WARP-enrolled workstation can `kubectl` directly without exposing 6443 publicly
- Node SSH access: WARP-enrolled workstation can SSH to 178.156.233.12:2222 without public firewall rule

**WARP vs Access:**
- Difference: WARP provides network-level access (like VPN), Access provides application-level protection
- Can be used together: WARP for network access + Access for application-level identity checks

---

### CF-TUN-10. OpenTofu Resources for Cloudflare Tunnel

Document the complete OpenTofu (terraform-provider-cloudflare) resource set for tunnel management:

**Tunnel resources:**
- `cloudflare_tunnel` resource: fields (account_id, name, secret — must be base64-encoded 32 bytes), output attributes (id = tunnel UUID, token)
- `cloudflare_tunnel_config` resource: ingress rules in HCL, `origin_request` block options
- `cloudflare_record` resource: creating CNAME records for tunnel routes
- `cloudflare_access_application` resource: all relevant fields (zone_id, name, domain, session_duration, auto_redirect_to_identity, allowed_idps)
- `cloudflare_access_policy` resource: include/exclude/require blocks, OIDC claim rules, service token rules
- `cloudflare_access_group` resource: group definition for reuse across policies
- `cloudflare_access_service_token` resource: creating service tokens, storing output in OpenBao

**Provider authentication:**
- `cloudflare` provider configuration: API token (not global API key) — which token permissions are needed for tunnel + Access + DNS management
- Scoped API token: `Cloudflare Tunnel:Edit`, `Access: Apps and Policies:Edit`, `DNS:Edit` — confirm scope names
- Storing API token: in OpenBao, injected as `CLOUDFLARE_API_TOKEN` env var during `tofu apply`

**State considerations:**
- Tunnel secret in state: `cloudflare_tunnel.secret` is sensitive — ensure state backend encrypts at rest (we use local state with SOPS encryption, or remote state)
- Service token secrets in state: similarly sensitive — use `sensitive = true` output

---

### CF-TUN-11. Routing Through Traefik vs Direct to Service

This is a critical architectural decision. Document both patterns with their implications:

**Pattern A: Tunnel → Traefik (recommended):**
- All tunnel ingress routes point to `http://traefik.kube-system.svc.cluster.local:80`
- Traefik IngressRoute with `Host()` matcher routes to the correct service
- Benefits: single egress point, Traefik middleware (auth, rate limit, headers) applies uniformly, one place to add/change routing
- Traefik must have the correct `Host` header: cloudflared passes the original public hostname as `Host` header, Traefik uses this for routing — confirm this works without additional config
- TLS: cloudflared → Traefik is HTTP (plaintext inside the cluster), Traefik → Cloudflare is HTTPS via Cloudflare Origin CA
- Traefik EntryPoints: external requests come in on port 80 (HTTP) from cloudflared — Traefik still redirects HTTP to HTTPS? No — the tunnel connection is already HTTPS from client to Cloudflare. What EntryPoint does Traefik use when receiving from cloudflared?

**Pattern B: Tunnel → individual services:**
- Each hostname has its own ingress rule pointing to the service directly
- Bypasses Traefik entirely: Traefik middleware does NOT apply
- When to use: services that do not work behind Traefik, or for emergency access when Traefik is down
- Security implication: no ForwardAuth, no rate limiting from Traefik

**Traefik + Access double-auth:**
- If using Traefik ForwardAuth (pointing to Zitadel) AND Cloudflare Access (pointing to Zitadel): users authenticate twice
- Recommendation: for services behind the tunnel, use Cloudflare Access ONLY as the authentication layer, disable Traefik ForwardAuth for those services
- Or: use Access as the outer gate and Traefik ForwardAuth as inner — document when double-auth makes sense (defense in depth for admin tools)

---

### CF-TUN-12. Monitoring and Audit Logging

**Tunnel health monitoring:**
- cloudflared metrics endpoint: what metrics it exposes, default port (2000), Prometheus scrape config
- Key metrics: `cloudflared_tunnel_active_streams`, `cloudflared_tunnel_request_errors`, `cloudflared_tunnel_timer_retries`
- Grafana dashboard: is there an official cloudflared Grafana dashboard? Community dashboards?
- Alerting: what to alert on (tunnel connection dropped, high error rate)

**Cloudflare Access audit logs:**
- Where Access audit logs live: Cloudflare dashboard → Zero Trust → Logs → Access
- Log fields: user email, IP, country, application, action (allow/block), timestamp
- Logpush to Loki: using Cloudflare Logpush to ship Access logs to an HTTP endpoint (our Loki push URL)
- Logpush configuration: `cloudflare_logpush_job` OpenTofu resource, required fields, dataset name for Access logs (`access_requests`)
- Loki label mapping: how to structure Logpush JSON to create useful Loki labels

**Tunnel connection logs:**
- `cloudflared` logs to stdout by default — captured by K3s/containerd → Loki via Promtail
- Log level: `--loglevel info` vs `debug` in production
- Structured JSON logging: `--logfile /dev/stdout --log-format json` for Loki parsing

---

### CF-TUN-13. Migration Plan

We currently have direct IP access (firewalld permits some ports). Document the cutover:

**Current state:**
- helix-stax-cp (178.156.233.12): SSH on 2222 open to internet, no other ports open publicly
- No active tunnel routes to internal services yet (tunnel exists for vault Worker only)

**Target state:**
- All services exposed via tunnel, zero public ports except SSH (and SSH moving to WARP-only)
- Firewalld rules: drop all inbound except SSH (eventually via WARP only, not public internet)

**Migration sequence:**
1. Deploy cloudflared Deployment to K3s (tunnel connects but no ingress routes yet)
2. Add Traefik IngressRoutes for all services (required before tunnel ingress can route through Traefik)
3. Add tunnel ingress rules for each service
4. Create DNS CNAMEs in Cloudflare for each hostname
5. Create Access Applications and policies for each service
6. Test each service: browser → Cloudflare → tunnel → Traefik → service
7. Enroll WARP on workstation
8. Test K8s API access via WARP (without 6443 being open)
9. Remove any lingering public firewalld rules
10. Enable SSH via Cloudflare Access (browser SSH or short-lived certs)

**Rollback plan:**
- If tunnel fails: re-open firewalld rules for emergency access
- Keep a known-good kubectl config with direct IP access until tunnel is fully validated

---

### CF-TUN-14. Common Failure Modes and Troubleshooting

Document every common failure mode with diagnosis and resolution:

**Tunnel connection failures:**
- `cloudflared: connection failed` — QUIC blocked by upstream firewall, fallback to HTTP/2, then diagnosis
- `unable to reach the origin service` — internal service DNS resolution failure, wrong port, service not running
- `TLS handshake error` — `noTLSVerify` not set when internal service has self-signed cert, or `originServerName` mismatch
- `tunnel not found` — token revoked or tunnel deleted, regenerate token

**DNS issues:**
- CNAME record not proxied (grey cloud instead of orange): Access policy bypassed, services exposed directly
- DNS not propagated yet: `dig <hostname> @1.1.1.1` to verify CNAME resolution
- Missing catch-all rule in ingress config: tunnel responds with `ERR_RESPONSE_EMPTY` for unmatched hostnames

**Access policy issues:**
- Access loop: misconfigured redirect, Access application domain doesn't match the hostname
- OIDC callback failure: Zitadel redirect URI not matching what Cloudflare sends, check Zitadel application allowed redirect URIs
- `Access denied`: user email not in Access group, group misconfigured
- Service token rejected: `CF-Access-Client-Id` header name typo, token expired

**Traefik routing issues through tunnel:**
- 404 from Traefik: IngressRoute missing or `Host()` matcher not matching the public hostname
- Redirect loop: Traefik HTTP-to-HTTPS redirect when cloudflared connects on port 80 — disable redirect for the tunnel EntryPoint or use a separate Traefik EntryPoint for tunnel traffic
- 502 Bad Gateway: backend service not running, wrong service name in IngressRoute

**SELinux interactions:**
- cloudflared running on K3s (inside containerd) — SELinux applies container_t context — any known AVC denials?

---

### Best Practices & Anti-Patterns

- Top 10 best practices for Cloudflare Tunnel on K3s in a small production cluster
- Security anti-patterns: what configurations look secure but are not (wildcard bypass policies, `noTLSVerify` everywhere, long session durations on admin tools)
- What to avoid when configuring OIDC with Zitadel as the identity provider for Cloudflare Access
- Tunnel naming conventions: how to name tunnels, Access applications, service tokens for clarity at scale
- Session duration recommendations by service type (admin tools vs user-facing vs machine access)
- How NOT to structure tunnel ingress (per-service routing when Traefik exists, redundant tunnels per service)
- When a bypass policy is acceptable vs when it is a security violation

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| Tunnel → Traefik vs tunnel → service | Traefik is the ingress for K3s | Tunnel → Traefik | Single routing layer, middleware applies |
| Tunnel → service directly | Emergency access when Traefik is down | Direct to service | Bypass single point of failure |
| Access OIDC vs bypass | Admin service (Grafana, ArgoCD, Devtron) | Access OIDC | All access is identity-verified |
| Access bypass | Public webhook endpoints (n8n) | Bypass on specific path | Webhooks can't do browser auth |
| WARP vs SSH certificate | Regular workstation access | WARP | Full network access, not just SSH |
| WARP vs SSH certificate | Server-to-server automation | SSH certificate | No WARP client for automated scripts |
| Deployment vs DaemonSet | Single tunnel, small cluster | Deployment (2 replicas) | Only one tunnel needed, DaemonSet wastes resources |
| Per-hostname Access apps vs wildcard | Services with different auth requirements | Per-hostname | Wildcard blocks policy differentiation |
| Service token expiry: 1 year vs never | CI/CD machine access | 1 year | Forces rotation, limits blast radius |

### Common Pitfalls

- Creating the tunnel CNAME as a non-proxied record (grey cloud): exposes the tunnel UUID and bypasses Access
- Configuring cloudflared with `--url` flag (legacy mode) instead of a `config.yaml` with named tunnel: legacy tunnels cannot be managed via API or OpenTofu
- Forgetting the catch-all `service: http_status:404` in tunnel ingress: unmatched routes return empty responses that confuse browsers
- Using `noTLSVerify: true` globally instead of per-hostname: masks TLS misconfigurations that would surface later
- Tunnel → Traefik on HTTPS (port 443) with a Cloudflare Origin CA cert that Traefik is serving: cloudflared needs `noTLSVerify: true` or the Cloudflare CA added to its trust store — HTTP (port 80) inside the cluster avoids this entirely
- Configuring Zitadel redirect URI without the Cloudflare Access callback URL: OIDC fails with redirect_uri_mismatch
- Setting Access session duration longer than Zitadel token lifetime: users appear logged in to Access but Zitadel session has expired, causing inconsistent auth state
- Running cloudflared as a DaemonSet when only one tunnel is needed: wastes resources, all instances share the same tunnel causing doubled connections per replica
- Not setting pod anti-affinity on cloudflared Deployment: both replicas land on the same node, defeating the purpose of HA
- Skipping Access on Zitadel itself: if Zitadel is compromised, attacker controls all SSO — protect Zitadel with Access + restrict to admin email only

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content

Core reference that an AI agent needs daily:
- cloudflared CLI quick reference (`cloudflared tunnel create`, `cloudflared tunnel run`, `cloudflared tunnel route dns`, `cloudflared tunnel info`, `cloudflared tunnel delete`, `cloudflared access ssh`)
- Tunnel health check commands: how to verify tunnel is connected and passing traffic
- DNS verification commands: `dig` patterns for confirming CNAME propagation
- Traefik + tunnel integration: the 3-line routing pattern (tunnel → Traefik → IngressRoute) as a quick reference
- Access troubleshooting tree: user gets 403 → check policy → check group → check OIDC provider → check Zitadel
- Common flags for cloudflared Deployment in K3s
- Service token header names (exact, case-sensitive): `CF-Access-Client-Id`, `CF-Access-Client-Secret`
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content

Deep specifications:
- Complete cloudflared `config.yaml` with all ingress rules for Helix Stax services
- Kubernetes Deployment manifest for cloudflared (2 replicas, anti-affinity, resource limits, secret reference)
- Helm values file for `cloudflare/cloudflared` chart covering our setup
- Complete OpenTofu resource definitions: `cloudflare_tunnel`, `cloudflare_tunnel_config`, `cloudflare_record`, `cloudflare_access_application`, `cloudflare_access_policy`, `cloudflare_access_group`, `cloudflare_access_service_token`
- Access Application configuration table for all 12 Helix Stax services
- OIDC integration spec: Zitadel application settings + Cloudflare identity provider settings (field by field)
- Logpush configuration for shipping Access logs to Loki
- Tunnel metrics Prometheus scrape config

### ## examples.md Content

Copy-paste-ready examples specific to Helix Stax:
- Real tunnel ingress config using our actual service names, namespaces, and hostnames
- Traefik IngressRoute examples for each service (showing how they pair with the tunnel config)
- Complete OpenTofu module: `modules/cloudflare-tunnel/` with main.tf, variables.tf, outputs.tf
- ESO ExternalSecret manifest to sync the tunnel token from OpenBao to a K8s Secret
- n8n service token usage: HTTP Request node headers for calling Access-protected APIs
- Prometheus scrape config with service token headers for scraping behind Access
- SSH config file (`~/.ssh/config`) for WARP-based SSH to helix-stax-cp on port 2222
- Logpush job HCL targeting our Loki push endpoint
- Migration runbook: step-by-step from current state (direct IP) to full tunnel-only access
- Firewalld final state: rules after migration (SSH only, eventually WARP-only)

Use `# Cloudflare Tunnels & Zero Trust Access` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual config files, actual OpenTofu HCL, actual Kubernetes manifests, and actual Cloudflare Access configurations. Do NOT give theory — give copy-paste-ready configurations for Cloudflare Tunnel + Zero Trust on K3s at Helix Stax. Every config must use our real hostnames (helixstax.net), our real service names, and our real infrastructure details.
