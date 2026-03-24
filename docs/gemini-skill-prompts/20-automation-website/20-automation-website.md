# Gemini Deep Research: Automation + Website

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are (Group Introduction)
The automation hub (n8n) + TLS management (Cloudflare Origin CA) + infrastructure services (Flannel) + the website (Astro) + version control (Git) — these are the remaining tools that connect everything. n8n is the central orchestration hub that receives webhooks from every service and drives cross-tool workflows. TLS is handled by Cloudflare Origin CA certificates (15-year, manual management — NO cert-manager, NO Let's Encrypt). Flannel CNI provides pod networking. Astro builds and delivers the helixstax.com website. Git is the backbone of the GitOps pipeline — every deployment and config change flows through a commit.

---

## Part 1: n8n + Cloudflare Origin CA TLS + Flannel CNI

## Our Specific Setup (Automation Services)
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (helix-stax-cp: 178.156.233.12 cpx31 ash-dc1 control plane; helix-stax-vps: 5.78.145.30 cpx31 hil-dc1 role TBD)
- **n8n**: Deployed on K3s via Helm, CloudNativePG PostgreSQL backend (NOT SQLite), Valkey for queue (worker mode), receives webhooks from all services
- **TLS**: Cloudflare Origin CA certificates (15-year), managed manually. NO cert-manager, NO Let's Encrypt. Certs stored as Kubernetes Secrets and referenced in Traefik IngressRoute TLS sections. Cloudflare handles edge TLS; Origin CA handles the Cloudflare-to-Traefik leg.
- **Flannel**: Bundled with K3s (VXLAN backend), no separate installation needed, Hetzner private network as underlay
- **Ingress**: Traefik — all services terminate TLS at Traefik using Cloudflare Origin CA certificates
- **Secrets**: OpenBao + External Secrets Operator — all sensitive credentials stored in OpenBao
- **Identity**: Zitadel OIDC — n8n authenticates users via Zitadel; Flannel is infrastructure-only (no user auth)
- **Internal domain**: helixstax.net for all internal services

## What I Need Researched

### n8n

#### 1. K3s Deployment
- Official Helm chart (`n8n/n8n`) — complete values reference for production deployment
- CloudNativePG PostgreSQL configuration (env vars: `DB_TYPE=postgresdb`, `DB_POSTGRESDB_HOST`, `DB_POSTGRESDB_PORT`, `DB_POSTGRESDB_DATABASE`, `DB_POSTGRESDB_USER`, `DB_POSTGRESDB_PASSWORD`)
- Valkey (Redis-compatible) queue configuration for worker mode (`EXECUTIONS_MODE=queue`, `QUEUE_BULL_REDIS_HOST`, `QUEUE_BULL_REDIS_PORT`)
- Main vs worker mode: when to use each, how to scale workers horizontally
- PersistentVolumeClaim for n8n data (workflows, credentials backup — even with DB backend)
- Encryption key configuration (`N8N_ENCRYPTION_KEY` — must be consistent, stored in OpenBao)
- Zitadel OIDC SSO for n8n (`N8N_AUTH_ENABLED`, OIDC env vars — does n8n support OIDC natively or need a proxy?)
- Traefik IngressRoute with TLS (Cloudflare Origin CA — secretName referencing the Origin CA TLS Secret)
- Webhook URL configuration (`WEBHOOK_URL` — must be the public URL for external webhooks)
- Resource requests/limits (n8n is memory-hungry — realistic limits for production)
- Rolling update strategy for n8n (stateful considerations)

#### 2. Workflow Development
- Node types: Trigger nodes vs Action nodes vs Logic nodes
- Core node reference:
  - **Webhook** — receiving HTTP POST/GET from external services (ArgoCD, GitHub, etc.)
  - **HTTP Request** — calling external APIs (Ollama, ClickUp, Rocket.Chat, Postal, Harbor, Alertmanager)
  - **Code** — JavaScript/Python code execution for custom logic
  - **IF / Switch** — conditional routing
  - **Set** — data transformation
  - **Merge** — combining branches
  - **Wait** — delays and pause-until-resume patterns
  - **Schedule Trigger** — cron-based workflows
  - **Execute Workflow** — calling sub-workflows
  - **Error Trigger** — global error handling workflow
- Expressions: `{{ $json.field }}`, `{{ $node["NodeName"].json.field }}`, `{{ $items() }}`, `{{ $now }}`, DateTime formatting
- Binary data handling (file attachments, images — passing between nodes)
- Looping patterns (SplitInBatches for processing arrays)
- Pinning data for development (mock incoming data without live trigger)

#### 3. Credential Management
- Credential types for our stack:
  - **HTTP Header Auth** / **Bearer Token** — Ollama, Open WebUI API, SearXNG
  - **PostgreSQL** — CloudNativePG databases
  - **Redis** — Valkey connection
  - **GitHub** — repo access for CI/CD notifications
  - **ClickUp API** — task creation and updates
  - **Rocket.Chat API** — sending messages
  - **Postal SMTP** — sending transactional email
  - **Cloudflare API** — DNS management workflows
  - **Zitadel** (if calling management API)
- Credential encryption at rest (uses `N8N_ENCRYPTION_KEY`)
- Exporting/importing credentials (for backup and migration)
- Environment variable credentials (for secrets that must not touch n8n DB)

#### 4. Webhook Integration Patterns
- ArgoCD: sync status webhooks → n8n → Rocket.Chat notification + ClickUp status update
- Devtron: build success/failure → n8n → Rocket.Chat + optional rollback trigger
- Harbor: image push event → n8n → trigger ArgoCD sync or log to ClickUp
- CrowdSec: alert webhook → n8n → Rocket.Chat #security-alerts + ClickUp incident task creation
- Alertmanager: Prometheus alert → n8n → Rocket.Chat #alerts + PagerDuty (future) or on-call notification
- GitHub: PR/push events → n8n → Devtron build trigger or ClickUp task update
- Webhook security: validating HMAC signatures (GitHub), bearer tokens (ArgoCD), shared secrets
- Webhook URL patterns: `https://n8n.helixstax.net/webhook/{path}` vs test URL

#### 5. HTTP Request Node Patterns
- Calling Ollama REST API (`/api/generate`, `/api/chat`, `/api/embeddings`) — URL, method, headers, body, response handling
- Calling ClickUp API — authentication, creating tasks, adding comments, updating status
- Calling Rocket.Chat REST API — sending messages to channels, direct messages
- Calling Postal API — sending transactional email via HTTP (not SMTP)
- Calling Harbor API — listing images, checking scan results
- Calling Grafana API — querying dashboards, creating annotations
- Calling Cloudflare API — DNS record management from workflows
- Pagination handling (ClickUp, GitHub APIs paginate — how to handle in n8n)
- Response parsing: `{{ $json.results[0].title }}` pattern

#### 6. Error Handling
- Per-node error handling: `Continue on Fail`, `Retry on Fail` (max retries, wait between retries)
- Global error workflow (`Error Trigger` node) — catch all uncaught errors
- Dead letter pattern: failed items → store to PostgreSQL node for review
- Timeout configuration per node vs global execution timeout
- Alerting on workflow failure: Error Trigger → Rocket.Chat #ops-alerts
- Execution history: how long to retain, where stored (DB), how to query

#### 7. Workflow Versioning and Backup
- Workflow export: `GET /api/v1/workflows` → save JSON to Git
- Automated backup pattern: n8n workflow that exports all workflows to Git on schedule
- Importing workflows: `POST /api/v1/workflows` — idempotency considerations
- n8n `@n8n/n8n-workflow` package — version pinning in Helm values
- Source control integration (n8n 1.x feature) — Git-backed workflow storage

#### 8. Community Nodes
- How to install community nodes in self-hosted n8n (`N8N_COMMUNITY_PACKAGES_ENABLED=true`)
- Notable community nodes for our stack:
  - n8n-nodes-minio — MinIO S3-compatible operations
  - n8n-nodes-pgvector — direct pgvector operations (if exists)
  - LangChain nodes (n8n-nodes-langchain) — Ollama integration, vector stores, chains
- Security considerations for community nodes (code execution, network access)

#### 9. n8n API for External Automation
- `GET /api/v1/workflows` — list all workflows
- `POST /api/v1/workflows/{id}/activate` — activate workflow
- `POST /api/v1/executions/{id}/retry` — retry failed execution
- `GET /api/v1/executions` — list executions with status filter
- API key generation and usage (`X-N8N-API-KEY` header)
- How Claude Code agents call n8n API to trigger workflows programmatically

#### 10. Monitoring
- Prometheus metrics endpoint (does n8n expose `/metrics`? Which env var enables it?)
- Key metrics: execution count, execution duration, queue depth, active workflows
- Grafana dashboard for n8n (community dashboards available?)
- Loki log shipping (n8n log format — JSON or plaintext? How to configure structured logging)
- Queue monitoring: Valkey queue depth for worker mode

---

### Cloudflare Origin CA Certificate Management

#### 11. Overview and Architecture
- We do NOT use cert-manager or Let's Encrypt. TLS is handled by Cloudflare Origin CA certificates (15-year validity), managed manually.
- Architecture: Cloudflare handles edge TLS (client-to-Cloudflare leg, public CA). Origin CA handles the Cloudflare-to-Traefik leg (Cloudflare's own CA — trusted only by Cloudflare).
- Cloudflare TLS mode must be "Full (Strict)" — requires a valid cert on the origin. Origin CA satisfies this.
- No automatic renewal: 15-year certs expire in 2039+. Set a calendar reminder to regenerate before expiry.

#### 12. Generating Origin CA Certificates
- Cloudflare Dashboard: SSL/TLS → Origin Server → Create Certificate
- Choose RSA 2048 or EC P-256 (EC is preferred — smaller, faster)
- Hostnames to cover: `*.helixstax.com`, `helixstax.com`, `*.helixstax.net`, `helixstax.net` (single cert covers both domains if added)
- Validity: select 15 years (maximum)
- Download: Origin Certificate (.pem) and Private Key (.key) — the private key is shown ONCE; store it in OpenBao immediately
- Do NOT use this cert for non-Cloudflare traffic — it is only trusted by Cloudflare's CA

#### 13. Installing as Kubernetes TLS Secrets
- Create a TLS Secret from the downloaded cert and key:
  ```bash
  kubectl create secret tls cloudflare-origin-ca \
    --cert=origin-cert.pem \
    --key=origin-key.key \
    -n <namespace>
  ```
- For a cluster-wide wildcard cert: create in `kube-system` or a dedicated `tls` namespace and reference via TLSStore
- Referencing in IngressRoute: `spec.tls.secretName: cloudflare-origin-ca`
- Referencing as default cert in TLSStore CRD for cluster-wide fallback

#### 14. Integration with OpenBao PKI (Internal Certificates)
- Internal service-to-service mTLS uses OpenBao PKI secret engine as an internal CA — separate from the public-facing Cloudflare Origin CA
- OpenBao PKI issues short-lived certs (1-30 days) for service mesh mTLS
- External Secrets Operator syncs OpenBao-issued certs into Kubernetes Secrets for consumption by pods
- When to use each: Cloudflare Origin CA for Traefik (internet-facing, Cloudflare-proxied traffic); OpenBao PKI for internal service-to-service encryption

#### 15. Verifying the Certificate
- Check the cert is valid and covers the right domains: `openssl x509 -in origin-cert.pem -text -noout | grep -A2 "Subject Alternative Name"`
- Verify Traefik is presenting the correct cert: `echo | openssl s_client -connect 178.156.233.12:443 -servername helixstax.com 2>/dev/null | openssl x509 -noout -issuer -dates`
- Cloudflare dashboard shows "Full (Strict)" in SSL/TLS overview when Origin CA is correctly configured
- Common issue: cert not found in IngressRoute — check Secret exists in correct namespace and secretName matches

#### 16. Gotchas and Anti-Patterns
- Origin CA certs are ONLY trusted by Cloudflare — do not use them for services accessed directly by IP or non-Cloudflare traffic
- If Cloudflare proxy is disabled (grey cloud DNS-only), the Origin CA cert will cause browser SSL errors — use a publicly trusted cert for grey-cloud records
- Store the private key in OpenBao immediately on download — it is shown only once in the Cloudflare dashboard
- TLS mode must be "Full (Strict)" — "Full" without Strict allows self-signed certs and is less secure; "Flexible" sends traffic to origin unencrypted (never use)
- Wildcard certs cover one level deep (`*.helixstax.com` covers `app.helixstax.com` but NOT `deep.app.helixstax.com`)

---

### Flannel CNI

#### 17. Architecture and Installation
- Flannel VXLAN overlay: how it works on Hetzner (pod traffic encapsulated in UDP on port 8472)
- How K3s bundles Flannel (embedded, not a separate Helm install)
- K3s Flannel configuration options: `--flannel-backend` (vxlan, host-gw, wireguard-native), `--cluster-cidr` (default 10.42.0.0/16), `--service-cidr` (default 10.43.0.0/16)
- Hetzner private network as the underlay (Flannel VXLAN runs on top — which interface does it bind to?)
- Flannel DaemonSet: `kube-flannel-ds` pods in `kube-system` namespace
- `flanneld` process: what it does, what config files it writes

#### 18. Network Configuration
- Pod CIDR and service CIDR — how to choose values that don't conflict with Hetzner private network (10.0.0.0/8 is common Hetzner range)
- MTU configuration: VXLAN adds 50 bytes overhead — Hetzner MTU is 1450, so pod MTU should be 1400
- How to check current Flannel MTU: `ip link show flannel.1`
- Cross-node pod communication: packet flow (pod → flannel.1 → VXLAN encap → eth0 → Hetzner → eth0 → decap → flannel.1 → destination pod)
- Flannel backend comparison for Hetzner:
  - **vxlan** (default): works everywhere, small overhead
  - **host-gw**: faster but requires flat L2 network (Hetzner private network supports this if nodes on same VLAN)
  - **wireguard-native**: encrypted overlay (performance cost, but encrypted pod traffic)

#### 19. Network Policy Limitations
- Flannel alone does NOT enforce Kubernetes NetworkPolicy (this is a critical limitation)
- Current state: all pods can reach all other pods by default (no network isolation)
- Options for adding NetworkPolicy support:
  - **Calico** (Canal mode with Flannel) — NetworkPolicy enforcement while keeping Flannel for routing
  - **Cilium** — replace Flannel entirely, eBPF-based, full NetworkPolicy + L7 policy + Hubble observability
  - **kube-router** — add NetworkPolicy enforcement alongside Flannel
- Recommendation for our scale: Cilium migration path (when and why)
- Kyverno as partial compensation (admission control can block pods, but can't enforce runtime network policy)

#### 20. Debugging
- Flannel pod logs: `kubectl logs -n kube-system -l app=flannel`
- Check VXLAN interface: `ip link show flannel.1`, `bridge fdb show dev flannel.1`
- Check routing table: `ip route | grep flannel`
- Check pod-to-pod connectivity: `kubectl exec -it <pod> -- curl http://<other-pod-ip>:<port>`
- Common issue: pod can't reach other pod on different node → check Hetzner firewall rules (UDP 8472 must be open between nodes)
- Common issue: MTU mismatch causing packet fragmentation → check `ip link show flannel.1` MTU
- Common issue: Flannel pod CrashLoopBackOff → usually RBAC or etcd connectivity issue
- `flannel.1` interface not present → Flannel DaemonSet not running or crashing

#### 21. Migration Considerations (Flannel → Cilium)
- Why migrate: NetworkPolicy enforcement, eBPF performance, Hubble network observability, L7 policy
- Migration complexity: **high** — requires draining nodes, replacing CNI, restarting all pods
- K3s Cilium migration: `--flannel-backend=none` + install Cilium Helm chart
- When NOT to migrate: when the cluster is stable and NetworkPolicy isn't needed yet
- Current recommendation: stay on Flannel until K3s cluster is fully provisioned; evaluate Cilium at Phase 3+ when NetworkPolicy becomes a compliance requirement

---

### Cross-Cutting Integration (Automation Services)

#### 22. How These Three Work Together
- Cloudflare Origin CA certificates (15-year) are stored as Kubernetes Secrets and referenced by Traefik IngressRoutes — no automated renewal needed
- Flannel ensures all pods (including n8n and all services) can communicate across nodes
- n8n receives Alertmanager webhook when a cert expiry alert fires → posts to Rocket.Chat `#ops-alerts`
- n8n workflow: check cert expiry by querying Prometheus metric `x509_cert_expiry` (from x509-certificate-exporter) or via OpenSSL probe → alert if < 90 days (well before 15-year expiry becomes a concern)
- Prometheus x509-certificate-exporter scrapes Kubernetes TLS Secrets → Grafana dashboard → Alertmanager rule for cert near expiry → n8n webhook

#### 23. n8n Webhook Processing Order (Reference Architecture)
- Alertmanager fires → n8n receives → classifies severity → routes to Rocket.Chat channel + optionally creates ClickUp incident task
- ArgoCD sync fails → n8n receives → checks if TLS cert issue (calls k8s API to inspect TLS Secret expiry or Traefik logs) → posts diagnostic to Rocket.Chat
- CrowdSec bans IP → n8n receives → logs to ClickUp Security Operations list → optionally adds Cloudflare WAF rule via API

---

### Best Practices & Anti-Patterns
- What are the top 10 best practices for this tool in production?
- What are the most common mistakes and anti-patterns? Rank by severity (critical → low)
- What configurations look correct but silently cause problems?
- What defaults should NEVER be used in production?
- What are the performance anti-patterns that waste resources?

### Decision Matrix
- When to use X vs Y (for every major decision point in this tool)
- Clear criteria table: "If [condition], use [approach], because [reason]"
- Trade-off analysis for each decision
- What questions to ask before choosing an approach

### Common Pitfalls
- Mistakes that waste hours of debugging — with prevention
- Version-specific gotchas for current releases
- Integration pitfalls with other tools in our stack
- Migration pitfalls when upgrading

## Required Output Format (Part 1)

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CLI commands with examples
- Configuration patterns with copy-paste snippets
- Troubleshooting decision tree (symptom → cause → fix)
- Integration points with other tools in our stack
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Full API/CLI reference (every flag, every option)
- Complete configuration schema with all fields documented
- Advanced patterns and edge cases
- Performance tuning parameters
- Security hardening checklist
- Architecture diagrams (ASCII)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (helix-stax-cp: 178.156.233.12, helix-stax-vps: 5.78.145.30), domains (helixstax.com, helixstax.net), and service names
- Annotated YAML/JSON manifests
- Before/after troubleshooting scenarios
- Step-by-step runbooks for common operations
- Integration examples with our specific stack (K3s, Traefik, Zitadel, CloudNativePG, etc.)

Use `# Tool Name` as top-level headers to separate each tool's output for splitting into separate skill directories.

Be thorough, opinionated, and practical. Include actual commands, actual configs, and actual error messages. Do NOT give theory — give copy-paste-ready content for a K3s cluster on Hetzner behind Cloudflare.

---

## Part 2: Astro + Git

## Our Specific Setup (Website & Version Control)
- **Website**: helixstax.com — IT consulting firm website
- **Framework**: Astro 4.x (static site generation, SSG mode)
- **Styling**: Tailwind CSS v3 + shadcn/ui components (React islands for interactive components)
- **Deployment target**: K3s on Hetzner Cloud (NOT Vercel/Netlify — self-hosted)
- **Container build**: Kaniko via Devtron CI, pushed to Harbor registry
- **GitOps**: ArgoCD syncs Helm chart → K3s deployment, watches the Git repo for changes
- **Ingress**: Traefik IngressRoute with Cloudflare Origin CA TLS (15-year cert stored as K8s Secret)
- **Domain**: helixstax.com (Cloudflare CDN + WAF in front)
- **Git platform**: GitHub (KeemWilliams organization)
- **Author**: All commits are authored by Wakeem Williams. No Co-Authored-By lines. No GPG signing (broken on Windows).
- **Local dev**: Windows 11 (WSL2 for some tooling), Claude Code as primary development agent
- **Secrets management**: No secrets in Git — OpenBao + External Secrets Operator
- **Security scanning**: Gitleaks pre-commit hook (scans for credential leaks before commit)

## What I Need Researched

### Astro

#### 1. Project Structure
- Standard Astro project layout: `src/`, `public/`, `dist/`, `astro.config.mjs`, `package.json`, `tsconfig.json`
- `src/pages/` — file-based routing (`.astro`, `.md`, `.mdx` files)
- `src/layouts/` — layout components
- `src/components/` — reusable components (Astro vs React)
- `src/content/` — content collections (type-safe content with schema validation)
- `src/styles/` — global CSS + Tailwind base
- `public/` — static assets (fonts, favicons, images not processed by Astro)
- `dist/` — build output (what gets containerized)
- Config files: `astro.config.mjs`, `tailwind.config.mjs`, `tsconfig.json`, `components.json` (shadcn)

#### 2. Configuration (astro.config.mjs)
- `output` mode: `'static'` (SSG, all pages pre-rendered) vs `'server'` (SSR, Node.js adapter) vs `'hybrid'` (per-page)
- Integrations: `@astrojs/react`, `@astrojs/tailwind`, `@astrojs/sitemap`, `@astrojs/mdx`
- `site` — canonical base URL (`https://helixstax.com`) — required for sitemap, canonical tags
- `base` — base path (if serving from a subpath — we don't, but good to know)
- `vite` configuration block — custom Vite plugins, build options
- `image` — remote image pattern allowlist, service configuration
- `compressHTML` — minify HTML output
- `trailingSlash` — `'always'`, `'never'`, `'ignore'` — affects routing
- `build.assets` — directory for hashed asset files in dist

#### 3. Pages and Routing
- File-based routing: `src/pages/index.astro` → `/`, `src/pages/about.astro` → `/about`
- Dynamic routes: `src/pages/[slug].astro`, `getStaticPaths()` for SSG
- Catch-all routes: `src/pages/[...slug].astro`
- 404 page: `src/pages/404.astro`
- API routes (SSR only): `src/pages/api/*.ts` for server-side endpoints
- Redirects in `astro.config.mjs` → `redirects: { '/old': '/new' }`
- Page metadata pattern: `<head>` in layout with `title`, `description`, canonical URL

#### 4. Astro Components vs React Islands
- `.astro` component syntax: frontmatter (---), template (HTML-like), scoped styles
- Passing props to Astro components
- `client:` directives for React islands (hydration strategies):
  - `client:load` — hydrate immediately on page load (use sparingly — increases JS)
  - `client:idle` — hydrate when browser is idle
  - `client:visible` — hydrate when component enters viewport
  - `client:only="react"` — skip SSR entirely, render client-side only
  - No directive — renders as static HTML with no JS (zero-JS by default)
- When to use React components vs Astro components: interactivity (forms, toggles, modals) = React; static content = Astro
- Sharing state between islands: nanostores (`@nanostores/react`) — lightweight state without Redux

#### 5. Tailwind CSS Integration
- `@astrojs/tailwind` integration — auto-injects Tailwind base styles
- `tailwind.config.mjs` — content paths (must include `src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}`)
- Using Tailwind classes in `.astro` templates and React components
- Custom theme extension: colors (Helix Stax brand colors), fonts, spacing
- `@apply` in Astro `<style>` blocks — when to use vs inline classes
- Dark mode: `class` strategy vs `media` strategy in Tailwind config
- CSS variables for theming (Tailwind + shadcn/ui pattern)

#### 6. shadcn/ui Integration
- `components.json` — shadcn configuration (style, baseColor, cssVariables, aliases)
- `npx shadcn@latest add <component>` — adding components to `src/components/ui/`
- Components as React islands (they require React — use `client:` directive)
- Theming: CSS variables in `src/styles/global.css` (`:root` and `.dark`)
- Commonly used components for a consulting site: Button, Card, Badge, Dialog, Sheet, NavigationMenu, Accordion, Form
- Customizing components after adding them (they're your code — edit directly)
- shadcn/ui + Tailwind dark mode — ensuring class strategy matches

#### 7. Content Collections
- `src/content/config.ts` — schema definitions with Zod
- Collection types: `blog`, `case-studies`, `services` (relevant for Helix Stax)
- Frontmatter schema definition: `title`, `description`, `pubDate`, `tags`, `draft`
- `getCollection()` — fetching all entries
- `getEntry()` — fetching a single entry
- Rendering markdown content: `<Content />` component
- Type safety: auto-generated types from schema
- Draft filtering: `import.meta.env.PROD ? entry.data.draft !== true : true`

#### 8. Static Site Generation and Build
- `npm run build` → generates `dist/` directory
- Build output: HTML files + hashed CSS/JS chunks + copied public assets
- `npm run preview` — preview the built site locally
- Environment variables in Astro: `import.meta.env.PUBLIC_*` (client-safe), `import.meta.env.*` (server-only during build)
- Build-time data fetching: `fetch()` in frontmatter runs at build time (SSG)
- Build performance: `--experimental-svg` and other flags

#### 9. Docker Containerization for K3s
- Multi-stage Dockerfile for Astro static site:
  - Stage 1: Node builder — `npm install && npm run build`
  - Stage 2: Nginx (or Caddy) to serve `dist/` directory
- Nginx configuration for SPA-style routing (if using client-side routing)
- Caddy vs Nginx as static file server in the container
- Container image size optimization (alpine base)
- How Kaniko builds this Dockerfile (same as Docker — Kaniko is Docker-compatible)
- Health check endpoint for K3s liveness probe (`/health` static file or nginx stub)
- Non-root user in container (security best practice)

#### 10. SEO
- `<head>` meta tags: `title`, `description`, `og:title`, `og:description`, `og:image`, `og:url`, `twitter:card`
- Canonical URL: `<link rel="canonical" href={canonicalURL} />`
- Sitemap: `@astrojs/sitemap` integration — auto-generates `/sitemap-xml`
- Robots.txt: static file in `public/robots.txt`
- JSON-LD structured data: `<script type="application/ld+json">` for `Organization`, `Service`, `FAQPage`
- `@astrojs/mdx` for blog posts with SEO-friendly URLs
- Open Graph image: static OG image in `public/` vs dynamic generation

#### 11. Image Optimization
- `<Image>` component from `astro:assets` — auto-optimizes, generates WebP, adds width/height
- `<Picture>` component — responsive images with multiple formats and sizes
- Remote images: must allowlist domains in `astro.config.mjs` (`image.domains`)
- Static images in `src/assets/` — processed by Astro
- Static images in `public/` — NOT processed (served as-is)
- `inferSize` attribute — avoids specifying width/height manually

#### 12. Performance
- Zero JS by default (Astro's key strength for static pages)
- Partial hydration via islands — only ship JS where needed
- View Transitions API: `<ViewTransitions />` — SPA-like transitions with MPA architecture
- `astro:prefetch` — prefetching links on hover/focus
- Critical CSS inlining vs external stylesheet
- Font optimization: `font-display: swap`, self-hosted fonts in `public/`
- Lighthouse scoring targets: aim for 95+ across all categories for a consulting site
- Bundle analysis: `npx astro build --verbose` or Vite bundle visualization

#### 13. Accessibility
- Semantic HTML in Astro components
- ARIA attributes with shadcn/ui (they handle most of this)
- Focus management for interactive components
- Color contrast: Tailwind's accessibility utilities
- Skip navigation link
- `alt` text for all images (enforced by `astro:assets` requiring alt)

---

### Git

#### 14. Workflow for Helix Stax
- Trunk-based development vs feature branches — recommendation for a solo developer with AI agents
- Branch naming conventions:
  - `feature/{description}` — new features
  - `bugfix/{issue-number}-{description}` — bug fixes (issue first per MEMORY.md)
  - `hotfix/{description}` — urgent production fixes
  - `chore/{description}` — maintenance, dependency updates
  - `docs/{description}` — documentation-only changes
- Default branch: `main` (NOT `master`)
- Branch protection rules on `main`: require PR review (even solo — self-review)
- Squash vs merge commits: recommendation for clean history on small team

#### 15. Commit Message Conventions
- Format: `<type>(<scope>): <subject>` (Conventional Commits)
- Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, `perf`, `ci`
- Scope examples: `website`, `infra`, `ci`, `auth`, `n8n`
- Subject: imperative mood, lowercase, no period, max 72 chars
- Body: optional, wrap at 72 chars, explain WHY not what
- Footer: `Closes #123`, `BREAKING CHANGE: description`
- Author: Wakeem Williams — `git config user.name "Wakeem Williams"` + email
- NO Co-Authored-By lines (per user preference)
- NO GPG signing (`git config commit.gpgsign false` locally)
- Example good commit: `feat(website): add services page with CTGA framework section`
- Bad commit: `update stuff`, `WIP`, `fix`

#### 16. Git Hooks (pre-commit, pre-push)
- `pre-commit` hook with Gitleaks: scan staged files for credential leaks
  - Gitleaks command: `gitleaks detect --staged --verbose`
  - Install Gitleaks on AlmaLinux/Windows WSL2
  - `.gitleaks.toml` configuration — allowlist for false positives (e.g., example API key patterns in docs)
- `pre-push` hook: run `npm run build` to catch build errors before push (optional — slow)
- Husky vs plain shell hooks: recommendation for our setup (plain hooks are simpler)
- Hook installation: `cp hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
- Sharing hooks across team: `core.hooksPath` config pointing to committed `hooks/` directory
- `.gitleaksignore` for test fixtures that contain example tokens

#### 17. GitOps Principles for ArgoCD
- Git as single source of truth: all K3s manifests and Helm values committed, no manual kubectl apply
- Application repo (source code) vs config repo (K8s manifests) — we use a monorepo: `infra/` contains manifests
- ArgoCD watches `infra/` directory (or specific path per app)
- Commit that triggers deploy: Devtron updates image tag in the Helm values file → ArgoCD detects drift → syncs
- Rollback via Git: `git revert` the image tag commit → ArgoCD reverts deployment
- Never `kubectl edit` in production — always edit Git and let ArgoCD sync
- Environment promotion: dev → staging → prod via separate branches or directories (we have one env now — good to know for future)

#### 18. Rebasing vs Merging
- `git rebase main` on feature branches before PR — keeps history linear
- Interactive rebase: `git rebase -i HEAD~n` — squashing WIP commits before PR
- When NOT to rebase: shared branches, branches with open PRs being reviewed
- `git merge --squash` for merging feature branches — single commit on main
- Fast-forward merge when possible (linear history is cleaner for ArgoCD)
- `git pull --rebase` as default: `git config pull.rebase true`

#### 19. Stash Patterns
- `git stash` — save uncommitted work temporarily
- `git stash push -m "WIP: description"` — named stash
- `git stash list` — view all stashes
- `git stash pop` vs `git stash apply` — difference
- `git stash branch <name>` — create branch from stash
- Stash gotcha: untracked files not included by default — use `git stash -u`

#### 20. Worktree for Parallel Development (AI Agent Pattern)
- `git worktree add ../repo-feature feature/branch-name` — create worktree for agent work
- Why Claude Code agents use worktrees: multiple agents work on different branches simultaneously without switching
- `git worktree list` — list active worktrees
- `git worktree remove ../repo-feature` — clean up after merge
- Worktree vs branch switching: worktrees are cheaper for AI agents (no stash/unstash cycle)
- Path convention for our projects: `worktrees/{feature-name}/` adjacent to main checkout

#### 21. .gitignore Patterns for Our Stack
- Node.js: `node_modules/`, `.npm`, `npm-debug.log`
- Astro: `dist/`, `.astro/`
- Environment: `.env`, `.env.local`, `.env.*.local` (never commit — use OpenBao)
- Secrets: `*.pem`, `*.key`, `kubeconfig`, `*-credentials.json`, `secrets/`
- OS: `.DS_Store`, `Thumbs.db`, `desktop.ini`
- Editor: `.vscode/settings.json` (but DO commit `.vscode/extensions.json`), `.idea/`
- Terraform/OpenTofu: `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfplan`
- Helm: do NOT ignore `charts/` if checking in chart dependencies
- Gitleaks: `.gitleaks.toml` should be committed

#### 22. Git LFS (Large File Storage)
- When to use: binary assets > 5MB (brand images, design files, video)
- Install Git LFS: `git lfs install`
- Track pattern: `git lfs track "*.png"` → adds to `.gitattributes`
- `.gitattributes` patterns for our assets
- GitHub LFS storage limits (free tier: 1GB storage, 1GB/month bandwidth)
- LFS vs just using MinIO for large assets — recommendation

#### 23. Tag Management for Releases
- Semantic versioning: `v{major}.{minor}.{patch}` (e.g., `v1.2.0`)
- Annotated tags: `git tag -a v1.0.0 -m "Release v1.0.0: initial public website"`
- Push tags: `git push origin v1.0.0` or `git push --tags`
- GitHub Releases from tags: `gh release create v1.0.0 --notes "..."`
- Automated tagging on deployment: Devtron can tag on successful deploy
- How ArgoCD uses image tags (Devtron pushes image tag like `v1.0.0-a1b2c3d` to Harbor → ArgoCD deploys that tag)

#### 24. Debugging Git
- `git bisect start/good/bad` — binary search for regression-introducing commit
- `git log --oneline --graph --all` — visual branch history
- `git diff HEAD~1 HEAD -- src/pages/index.astro` — file-specific diff
- `git blame src/components/Hero.astro` — who changed what line
- `git reflog` — recover from bad rebase or reset (your safety net)
- `git cherry-pick <sha>` — apply a specific commit to current branch
- `git log --all --full-history -- "path/to/file"` — find deleted file history
- `git shortlog -sn` — commit count by author

---

### Cross-Cutting Integration (Website & Version Control)

#### 25. Full Deployment Pipeline
- Developer (or Claude Code agent) edits Astro source on feature branch
- `pre-commit` hook: Gitleaks scans staged files — blocks commit if credential found
- `git commit` → commit message follows Conventional Commits
- `git push origin feature/branch-name`
- PR opened on GitHub → triggers Devtron CI pipeline
- Devtron: checkout code → `npm install` → `npm run build` (inside Kaniko build) → push image to Harbor as `harbor.helixstax.net/helix-stax/website:{git-sha}`
- PR merged to `main` → Devtron promotes image to production tag
- ArgoCD detects new image tag in Helm values → syncs deployment → K3s pulls image from Harbor → Traefik serves helixstax.com
- Full roundtrip: commit to live deployment in < 5 minutes

#### 26. Rollback Pattern
- Identify bad commit: `git log --oneline main` → find last good commit
- Option A (fast): `git revert <bad-sha>` on main → push → ArgoCD deploys reverted version
- Option B (image): manually update image tag in Helm values to previous tag → ArgoCD syncs
- Option C (ArgoCD): use ArgoCD UI "Rollback" to previous sync state (does not update Git — use sparingly)
- Preferred: Option A (Git is source of truth, revert creates audit trail)

---

## Required Output Format (Part 2)

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CLI commands with examples
- Configuration patterns with copy-paste snippets
- Troubleshooting decision tree (symptom → cause → fix)
- Integration points with other tools in our stack
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Full API/CLI reference (every flag, every option)
- Complete configuration schema with all fields documented
- Advanced patterns and edge cases
- Performance tuning parameters
- Security hardening checklist
- Architecture diagrams (ASCII)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (helix-stax-cp: 178.156.233.12, helix-stax-vps: 5.78.145.30), domains (helixstax.com, helixstax.net), and service names
- Annotated YAML/JSON manifests
- Before/after troubleshooting scenarios
- Step-by-step runbooks for common operations
- Integration examples with our specific stack (K3s, Traefik, Zitadel, CloudNativePG, etc.)

Use `# Tool Name` as top-level headers to separate each tool's output for splitting into separate skill directories.

Be thorough, opinionated, and practical. Include actual commands, actual configs, and actual error messages. Do NOT give theory — give copy-paste-ready content for a K3s cluster on Hetzner behind Cloudflare.
