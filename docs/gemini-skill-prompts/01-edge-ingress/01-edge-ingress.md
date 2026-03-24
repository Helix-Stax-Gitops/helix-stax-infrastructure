# Gemini Deep Research: Edge & Ingress (Cloudflare + Traefik + Helm)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

Cloudflare, Traefik, and Helm form the complete edge-to-cluster ingress chain for Helix Stax:

- **Cloudflare** is the outermost edge layer — CDN, DDoS protection, WAF, DNS management, and Zero Trust access. All traffic to helixstax.com flows through Cloudflare before ever reaching our cluster.
- **Traefik** is our Kubernetes ingress controller running inside K3s. It receives traffic from Cloudflare and routes it to internal services, handling TLS termination, middleware chaining (auth, rate limiting, headers), and exposing Prometheus metrics.
- **Helm** is the Kubernetes package manager that deploys and upgrades every application in the cluster — including Traefik itself (via K3s HelmChartConfig) and every service sitting behind Traefik. ArgoCD manages ongoing Helm reconciliation in our GitOps workflow.

These three tools are deeply coupled: Cloudflare's TLS mode determines what certificate Traefik must present; Traefik's IngressRoute CRDs define how Helm-deployed services are exposed; Helm's HelmChartConfig is the only correct way to configure the bundled Traefik on K3s. Understanding all three together prevents misconfigurations that are invisible when looking at each tool in isolation.

## Our Specific Setup

- **Domain**: helixstax.com (public), helixstax.net (internal services)
- **DNS**: Cloudflare manages all DNS records for both domains
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (helix-stax-cp: 178.156.233.12 cpx31 ash-dc1 control plane; helix-stax-vps: 5.78.145.30 cpx31 hil-dc1 role TBD)
- **Edge**: Cloudflare CDN/WAF/Zero Trust sits in front — all traffic arrives with CF-Connecting-IP header; real client IP must be extracted by Traefik
- **Zero Trust**: Cloudflare Access + Tunnel configured for internal services; Zitadel is our IdP, Cloudflare Access uses it for authentication
- **Ingress style**: Traefik CRDs exclusively — IngressRoute, Middleware, TLSOption, IngressRouteTCP. We do NOT use Kubernetes Ingress resources.
- **TLS**: Cloudflare Origin CA certificates (15-year), managed manually. NO cert-manager, NO Let's Encrypt. Cloudflare handles edge TLS (client-to-Cloudflare); Origin CA certs handle the Cloudflare-to-Traefik leg. Certs are stored as Kubernetes Secrets and referenced in IngressRoute TLS sections.
- **WAF**: Cloudflare managed rulesets active
- **Auth**: forwardAuth middleware pointing to Zitadel OIDC for protected services (Grafana, n8n, Devtron, ArgoCD, Outline, Backstage, Rocket.Chat)
- **Helm version**: Helm 3 (no Tiller)
- **Chart storage**: Harbor is our internal OCI-compatible Helm chart registry; public charts pulled from upstream repos
- **GitOps**: ArgoCD deploys all Helm charts from git; values files live in the infra repo under `helm/`
- **K3s Helm built-ins**: HelmChart CRD and HelmChartConfig CRD for bundled components (Traefik overridden via HelmChartConfig, NOT by disabling and reinstalling)
- **Secrets in values**: External Secrets Operator pulls secrets from OpenBao; Helm values reference Kubernetes Secrets — we do NOT put raw secrets in values files
- **Downstream services**: CloudNativePG, Valkey, MinIO, Harbor, Zitadel, Devtron, ArgoCD, Prometheus, Grafana, Loki, CrowdSec, n8n, Velero, Rocket.Chat, Backstage, Outline

---

## What I Need Researched

---

# Cloudflare Research Areas

### CF-1. CLI Reference (wrangler)
- Complete wrangler CLI command reference for DNS, Tunnel, Access, WAF, and Zero Trust
- How to manage DNS records via CLI (add, update, delete, bulk import/export)
- How to create and manage Cloudflare Tunnels via CLI
- How to configure Access policies via CLI
- How to manage WAF custom rules via CLI

### CF-2. DNS Management Patterns
- Best practices for split DNS (public helixstax.com vs internal helixstax.net)
- DNSSEC configuration and gotchas
- SPF, DKIM, DMARC records for email (we use Google Workspace + Postal)
- Wildcard DNS patterns for K3s ingress
- DNS propagation debugging techniques

### CF-3. Zero Trust Configuration
- Cloudflare Access + Tunnel architecture for self-hosted services
- How to integrate Cloudflare Access with Zitadel (OIDC IdP)
- Service tokens for machine-to-machine access
- Per-application access policies (Grafana, n8n, Devtron, ArgoCD)
- Browser rendering for SSH/RDP access to Hetzner nodes

### CF-4. WAF & Security
- Managed ruleset selection for a small K3s cluster
- Custom WAF rules for API protection
- Rate limiting configuration
- Bot management for a consulting website
- Page rules vs transform rules vs redirect rules

### CF-5. Performance
- Cache configuration for Astro static site
- Argo Smart Routing — worth it at our scale?
- Image optimization (Polish, Mirage)
- Early Hints and HTTP/3 configuration

### CF-6. Cloudflare + Traefik Integration
- How Cloudflare proxy interacts with Traefik
- Real IP forwarding (CF-Connecting-IP header)
- TLS modes (Full Strict vs Full) with Traefik origin certs
- How to avoid double-proxying issues

### CF-7. API & Automation
- Cloudflare API v4 reference for common operations
- Terraform/OpenTofu provider for Cloudflare
- How to automate DNS record creation when deploying new services

### CF-8. Troubleshooting
- Common Cloudflare errors (520, 521, 522, 523, 524, 525, 526) and what they mean
- How to debug "Origin is unreachable" when Traefik is up
- How to diagnose SSL/TLS handshake failures
- Ray ID tracing for support tickets

### CF-9. Gotchas & Anti-Patterns
- Things that break when you enable Cloudflare proxy (orange cloud)
- WebSocket gotchas behind Cloudflare
- gRPC support limitations
- Free vs Pro vs Business tier differences that matter

### CF-10. Cost Optimization
- What's actually free vs what costs money
- When to upgrade from Free to Pro
- Argo, Workers, R2 — which are worth it at small scale

---

# Traefik Research Areas

### TR-1. IngressRoute CRD Reference
- Complete IngressRoute spec: apiVersion, kind, metadata, spec.entryPoints, spec.routes, spec.tls — every field with type and description
- Route matching syntax: Host(), Path(), PathPrefix(), Headers(), Method(), Query() — operator precedence and combining with && and ||
- Priority rules: how Traefik resolves conflicts between overlapping routes; how to set explicit priority
- IngressRouteTCP and IngressRouteUDP CRDs: when to use them, full spec reference
- TLSOption CRD: configuring min TLS version, cipher suites, client auth (mTLS)
- ServersTransport CRD: configuring backend TLS (insecureSkipVerify, rootCAs, certificates for mTLS to backends)
- Difference between IngressRoute (Traefik CRD) and Ingress (Kubernetes native) — why we exclusively use CRDs and what we lose by not using Ingress

### TR-2. Middleware Configuration
- Complete list of all Traefik middleware types with purpose: BasicAuth, DigestAuth, ForwardAuth, RateLimit, RedirectRegex, RedirectScheme, StripPrefix, StripPrefixRegex, AddPrefix, Compress, Headers, IPWhiteList/IPAllowList, CircuitBreaker, Retry, InFlightReq, PassTLSClientCert, Plugin
- **ForwardAuth** deep dive: how to configure forwardAuth to delegate auth to Zitadel; which headers Zitadel must return (X-Forwarded-User, X-Auth-User, etc.); trustForwardHeader setting; authResponseHeaders to forward to upstream
- **RateLimit**: burst, average, period fields; how to scope per IP vs global; integration with CrowdSec for dynamic banning
- **Headers middleware**: securityHeaders preset (HSTS, X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy); CORS configuration; custom request/response headers; how to strip headers coming from Cloudflare before they reach the backend
- **Compress**: supported algorithms (gzip, brotli, zstd), minResponseBodyBytes, excludedContentTypes
- **Retry and CircuitBreaker**: when to use each; configuration fields; interaction with each other
- Middleware chaining order: how Traefik applies middleware in order and what happens when one fails
- Middleware scoping: namespace-scoped vs cross-namespace via provider.kubernetescrd.allowCrossNamespace

### TR-3. TLS Configuration
- Cloudflare Origin CA certificate management: generating 15-year Origin CA certs in Cloudflare dashboard, installing as Kubernetes TLS Secrets, referencing via tls.secretName in IngressRoute. NO cert-manager, NO Let's Encrypt.
- How Traefik references the Origin CA cert: `tls.secretName` in IngressRoute spec, or via TLSStore defaultCertificate for a cluster-wide fallback
- TLS modes aligned with Cloudflare: Full vs Full (Strict) — Full Strict requires a valid CA-signed cert on the origin; Cloudflare Origin CA satisfies this for the Cloudflare→Traefik leg
- Wildcard Origin CA certificates: generating *.helixstax.com and *.helixstax.net wildcard certs in Cloudflare dashboard; how to reference a wildcard cert from multiple IngressRoutes
- Default TLS certificate: configuring a fallback cert for unmatched SNI; defaultCertificate in TLSStore CRD
- TLSOption CRD: enforcing TLS 1.2 minimum, disabling weak cipher suites, configuring sniStrict

### TR-4. Cloudflare Integration
- CF-Connecting-IP header: how to configure Traefik to trust this header and use it as the real client IP (proxyProtocol vs trustedIPs approach)
- Cloudflare IP ranges: how to populate trustedIPs with Cloudflare's published CIDR list so Traefik doesn't trust spoofed CF headers from non-Cloudflare sources
- Proxy Protocol: when Cloudflare sends PROXY protocol headers; how to enable proxyProtocol on Traefik entryPoints
- TLS passthrough mode: when to use it vs terminate at Traefik; how to configure on IngressRouteTCP
- Cloudflare → Traefik TLS: configuring Traefik to present an origin certificate Cloudflare trusts; Full Strict mode requirements
- Avoiding double-compression: Cloudflare compresses responses; Traefik compress middleware may conflict — how to detect and resolve
- WebSocket support: Traefik WebSocket proxying behind Cloudflare; required headers; timeout configuration
- gRPC support: Traefik h2c (HTTP/2 cleartext) for gRPC backends; Cloudflare gRPC limitations

### TR-5. Dashboard & API
- Enabling the Traefik dashboard securely: how to expose it via IngressRoute with forwardAuth middleware (not basicAuth in production)
- Dashboard IngressRoute example: host rule, TLS, forwardAuth pointing to Zitadel
- Traefik REST API: base path /api/, useful endpoints (/api/http/routers, /api/http/services, /api/http/middlewares, /api/overview, /api/entrypoints, /api/version)
- API authentication: how to secure the API endpoint; difference between dashboard and API access
- Using the API for debugging: how to query current routing state, verify middleware is loaded, check backend health

### TR-6. Metrics & Observability
- Prometheus metrics: how to enable the Prometheus metrics provider in Traefik; which metrics are exposed (traefik_requests_total, traefik_request_duration_seconds, traefik_open_connections, traefik_backend_up, etc.)
- ServiceMonitor CRD: configuring a Prometheus Operator ServiceMonitor to scrape Traefik
- Key Grafana dashboard panels for Traefik: request rate, error rate, p50/p95/p99 latency, active connections, backend health — which Grafana dashboard IDs are production-quality
- Access logs: enabling structured JSON access logs; key fields (ClientHost, RequestPath, DownstreamStatus, Duration, RouterName, ServiceName); shipping to Loki via Promtail
- Tracing: OpenTelemetry trace export from Traefik; configuration for future Grafana Tempo integration
- Health check endpoint: /ping endpoint; how to use it for K3s liveness/readiness probes

### TR-7. K3s-Specific Configuration
- Bundled Traefik: what version K3s ships; where it stores Helm values; how to find the bundled HelmChart resource
- HelmChartConfig CRD: the correct way to override bundled Traefik values without forking the Helm chart; valuesContent field; which values are safe to override
- HelmChart CRD vs HelmChartConfig: difference, when to use each; why HelmChartConfig is preferred for bundled charts
- Disabling bundled Traefik to install your own: --disable=traefik K3s flag; when this is necessary vs when HelmChartConfig is sufficient
- Traefik entryPoints in K3s: default ports (80, 443, 8080); how to add custom entryPoints (e.g., for PostgreSQL TCP passthrough on 5432)
- LoadBalancer service in K3s: how K3s assigns external IPs to Traefik's LoadBalancer service using klipper-lb; IP assignment behavior on single-node vs multi-node
- Node ports vs LoadBalancer: K3s Traefik listens on which ports on the host; firewall rules required on Hetzner

### TR-8. Load Balancing & Advanced Routing
- Weighted round-robin: TraefikService CRD for weighted traffic splitting between two backend services; use case for canary deployments
- Sticky sessions: how to configure cookie-based session affinity in Traefik; which CRD fields control it
- Canary deployments: using TraefikService weighted routing alongside ArgoCD rollouts; step-by-step pattern
- Mirror traffic: TraefikService mirroring to shadow a percentage of traffic to a test service
- Health checks: passive health checks (circuit breaker) vs active health checks (healthCheck in service config); configuration fields
- Service discovery: how Traefik discovers K3s Services via the Kubernetes provider; label vs annotation requirements; provider.kubernetescrd vs provider.kubernetesingress

### TR-9. Troubleshooting
- 502 Bad Gateway: Traefik can reach the service but the backend returns an error — how to distinguish from Traefik-level vs backend-level
- 503 Service Unavailable: no healthy backends; how to verify backend pod health from Traefik's perspective; check /api/http/services endpoint
- 504 Gateway Timeout: backend too slow; how to increase per-route timeouts (forwardingTimeouts.responseHeaderTimeout, readTimeout, writeTimeout); default timeout values
- Connection refused: Traefik can't reach the K3s Service at all — ClusterIP vs Pod IP routing; kube-proxy vs kube-router
- TLS handshake failures: cert not found, cert expired, SNI mismatch; how to read Traefik debug logs for TLS errors
- forwardAuth 401/403 loops: Zitadel returning auth errors; how to debug the forwardAuth chain; common misconfiguration (missing authResponseHeaders, wrong trustForwardHeader value)
- IngressRoute not picked up: Traefik not loading a new CRD resource; RBAC issues, namespace issues, provider config issues
- Debug logging: how to enable debug-level logging in Traefik via HelmChartConfig; what additional information appears; how to grep for specific router/service names
- `kubectl` commands for Traefik debugging: checking the Traefik pod logs, describing the Service, checking Endpoints

### TR-10. CLI & Day-2 Operations
- Traefik does not have a standalone CLI for management — clarify this vs the `traefik` binary flags used at startup
- How to apply configuration changes: editing HelmChartConfig triggers a Helm upgrade automatically in K3s — explain the reconciliation loop
- Rolling restart: `kubectl rollout restart deployment/traefik -n kube-system` — when needed and safe
- Checking current Traefik version: how to find it via kubectl, via the API, via the dashboard
- Scaling Traefik: replica count considerations in K3s; leader election for a single ingress controller; when to run multiple Traefik replicas
- Upgrading Traefik: process for upgrading the bundled K3s Traefik via HelmChartConfig pinning a specific chart version
- Plugin system: Traefik Pilot is deprecated; how to install community plugins (e.g., CrowdSec bouncer plugin) via experimental.plugins in HelmChartConfig; plugin catalog location

---

# Helm Research Areas

### HE-1. Helm CLI Reference
- Complete `helm install` flags: --values, --set, --set-string, --set-file, --set-json, --namespace, --create-namespace, --version, --wait, --timeout, --atomic, --dry-run, --debug, --render-subchart-notes
- `helm upgrade` vs `helm upgrade --install`: when each is appropriate; --reuse-values vs --reset-values; --force flag and when it causes downtime
- `helm rollback`: syntax, selecting a revision, --wait flag; what rollback does NOT roll back (PersistentVolumeClaims, CRDs, secrets created outside Helm)
- `helm template`: rendering charts locally for inspection and diffing; --validate flag to check against live cluster; piping to kubectl apply
- `helm diff`: the helm-diff plugin; how to install it; `helm diff upgrade` to preview changes before applying; output format
- `helm test`: running chart test hooks; what makes a good Helm test; timeout behavior
- `helm get`: subcommands (all, hooks, manifest, notes, values) — how to inspect a deployed release
- `helm history`: viewing release revision history; understanding REVISION, STATUS, CHART, and DESCRIPTION columns
- `helm list`: filtering by namespace, status, selector; output formats (table, json, yaml)
- `helm uninstall`: --keep-history flag; what happens to CRDs, PVCs, and namespaces on uninstall
- `helm repo` commands: add, update, list, remove, index — managing public chart repositories
- `helm search`: repo vs hub; how to find available versions of a chart; --versions flag
- `helm show`: chart, values, readme, crds — inspecting a chart before installing
- `helm plugin`: install, list, remove; must-have plugins for production (helm-diff, helm-secrets, helm-mapkubeapis)

### HE-2. Chart Development
- Chart.yaml: all fields — apiVersion (v2 only), name, version, appVersion, description, type (application vs library), dependencies, keywords, maintainers, icon, home, sources, annotations
- Chart versioning: semantic versioning rules; appVersion vs chart version; when to bump each
- values.yaml: structure best practices; using null as an optional value; how nested values merge with --set; documenting values with comments
- templates/ directory: naming conventions (deployment.yaml, service.yaml, ingress.yaml, _helpers.tpl, NOTES.txt); the role of each
- _helpers.tpl: defining named templates with `define`; calling with `include` vs `template`; the `.` vs `$` context; passing context with `dict`
- Template functions: toYaml + nindent pattern for nested blocks; required vs default; tpl for rendering values as templates; lookup for querying live cluster state; printf, trim, trimSuffix, replace, b64enc, b64dec, sha256sum
- Conditionals and loops: if/else/with, range over maps and lists; common patterns like optional resource creation
- hooks: pre-install, post-install, pre-upgrade, post-upgrade, pre-delete, post-delete, pre-rollback, post-rollback; hook weights; hook deletion policies; use cases (DB migrations, secret seeding)
- NOTES.txt: how it renders after install; using template functions to print service URLs
- Chart linting: `helm lint` flags; what linting catches and what it misses; CI integration
- Library charts: type: library; how to create reusable template snippets; how application charts declare library chart dependencies

### HE-3. Repository Management
- Adding upstream public repos: Bitnami, Jetstack (cert-manager), Traefik, Prometheus Community, ArgoCD, CloudNativePG, CrowdSec, Velero — exact `helm repo add` commands for each
- Repo update cadence: when to run `helm repo update`; CI/CD pattern to always update before install/upgrade
- OCI registries as Helm repos: Harbor as OCI registry; `helm push` to Harbor; `helm pull` from Harbor OCI URL (oci://); authentication with `helm registry login`
- Difference between classic HTTP repos (index.yaml) and OCI registries: feature gaps, authentication differences, how ArgoCD handles each
- Hosting a private Helm repo without Harbor: chartmuseum vs plain HTTP file server vs S3-backed repo
- Chart caching: where Helm caches pulled charts (~/.cache/helm/); how to clear cache; offline install from cache

### HE-4. Values Management
- Multiple values files: `helm install -f base.yaml -f prod.yaml` — merge order (last file wins at leaf level, NOT deep merge); gotchas when overriding nested arrays
- --set precedence: --set overrides -f files; --set-string forces string type; --set-json for complex types; --set-file for file contents
- Environment-specific values pattern: directory structure recommendation (helm/{chart}/values.yaml, values-prod.yaml, values-dev.yaml); how ArgoCD references environment-specific files
- Secrets in values: why secrets must NOT appear in values files in git; pattern for referencing Kubernetes Secrets created by External Secrets Operator in Helm chart templates (env.valueFrom.secretKeyRef); helm-secrets plugin for encrypted values with SOPS+age
- Values schema validation: values.schema.json in charts; JSON Schema types; how Helm validates values at install time; writing custom schemas for your own charts
- Documenting values: helm-docs tool for auto-generating values documentation from comments; comment format (# -- description)

### HE-5. K3s-Specific Helm Patterns
- HelmChart CRD: full spec (chart, repo, version, valuesContent, targetNamespace, set, jobImage); how K3s reconciles it; where HelmChart resources live (kube-system namespace); how to inspect the Helm job that runs the install
- HelmChartConfig CRD: purpose (override values for bundled charts without replacing the HelmChart); spec.valuesContent; which charts support it (traefik, coredns, metrics-server, local-path-provisioner); interaction with HelmChart when both exist
- Bundled chart list: which charts K3s ships by default and their chart names; how to find current bundled chart versions; how HelmChart resources are created automatically
- Disabling bundled charts: --disable flag at K3s install time vs post-install; risks of disabling and reinstalling (version drift, CRD conflicts)
- Auto-deploy from /var/lib/rancher/k3s/server/manifests/: how K3s watches this directory; how to drop a HelmChart manifest there for auto-installation; idempotency behavior
- K3s and Helm releases: K3s-managed Helm releases show up in `helm list` in the target namespace; how to identify them; whether manual `helm upgrade` conflicts with K3s auto-management

### HE-6. ArgoCD Integration
- ArgoCD Application manifest: spec.source.helm fields — chart, repoURL, targetRevision, values, valueFiles, parameters, releaseName, version, passCredentials
- Helm in ArgoCD vs direct Helm CLI: ArgoCD runs `helm template` internally and applies the manifests via kubectl — it does NOT run `helm install`; implications for hooks (Helm hooks may not work as expected in ArgoCD)
- Multi-source Applications: ArgoCD 2.6+ spec.sources array; combining a chart from one repo with values files from another repo
- values files in ArgoCD: path is relative to the source repo root; how to reference environment-specific values files per ArgoCD Application
- Helm secrets with ArgoCD: using ArgoCD Vault Plugin (AVP) or External Secrets Operator instead of helm-secrets plugin (ArgoCD cannot run helm-secrets natively)
- App of Apps pattern: one ArgoCD Application that deploys a chart containing other ArgoCD Application manifests; bootstrapping a cluster
- Sync waves: argocd.argoproj.io/sync-wave annotation; controlling install order (Traefik before services that need ingress, CloudNativePG before apps that need PostgreSQL, Zitadel before apps that need OIDC)
- Resource health checks: ArgoCD built-in health checks for Helm-deployed resources; custom health checks for CRDs (e.g., CloudNativePG Cluster resource)
- Drift detection: ArgoCD detecting when someone ran `helm upgrade` manually outside GitOps; self-heal behavior

### HE-7. Dependency Management
- Chart.yaml dependencies: name, version, repository (URL or alias), condition, tags, import-values, alias fields
- `helm dependency update`: downloads dependency charts to charts/ directory; lock file (Chart.lock); when to run it; committing charts/ vs .gitignore
- `helm dependency build`: uses Chart.lock to reproduce exact dependency versions; difference from update
- Subcharts and parent values: how parent chart values pass to subcharts (subchart name as key); global values that flow to all subcharts
- Conditional subcharts: condition field to enable/disable a subchart via a values flag
- Library chart as dependency: how application charts consume a library chart; what gets rendered vs what doesn't
- Umbrella charts vs individual charts: trade-offs for our stack; recommendation for a small cluster (per-service charts managed by ArgoCD App of Apps vs one umbrella)
- OCI dependency repos: specifying oci:// URLs in dependencies; authentication for private OCI repos

### HE-8. Debugging & Troubleshooting
- `helm template --debug`: verbose rendering with template source annotations; how to read which template file generated which YAML block
- `helm install --dry-run --debug`: simulates install against live cluster; difference from `helm template` (dry-run validates against API server)
- Decoding a deployed release secret: Helm stores releases as Kubernetes Secrets in the release namespace; `kubectl get secret -l owner=helm -n <ns>`; base64+gzip decode to read the stored manifest
- Common errors and fixes:
  - "rendered manifests contain a resource that already exists" — resource adopted by another release or created manually; how to fix with --force or annotation
  - "cannot patch X with kind Y" — immutable field changed; what fields are immutable in Deployment, StatefulSet, Service; workaround
  - "timed out waiting for condition" — --wait flag; how to debug which resource is blocking; common causes (image pull error, CrashLoopBackOff, PVC pending)
  - "couldnt find key in secret" — External Secrets not synced yet; Helm rendered before ESO created the secret; ordering solutions
  - CRD version conflicts — upgrading a chart that changes CRD apiVersion; how to handle CRD upgrades safely (CRDs are not updated by helm upgrade by default)
- helm-diff output reading: understanding +/- diff lines; identifying dangerous changes (field deletions, selector changes)
- Helm release stuck in "pending-upgrade" or "failed" state: how this happens; `helm rollback` to recover; manually patching the release secret as last resort

### HE-9. Security
- Chart signing: `helm package --sign`; provenance files (.prov); `helm verify`; keyring management with GPG; why most public charts are unsigned and what to do about it
- Supply chain security: verifying chart integrity without signing; comparing chart content hash; using Harbor's vulnerability scanner on chart images; Kyverno policies to enforce image provenance
- Secrets anti-patterns: --set password=... in shell history; values.yaml with secrets committed to git; how to audit for accidental secret exposure in Helm history (values stored in release secret)
- RBAC for Helm: what permissions Helm needs to install charts (cluster-admin vs scoped); service account for CI/CD runners running helm; ArgoCD service account permissions
- Network policies for Helm-deployed services: how to layer Kyverno or native NetworkPolicy on top of Helm-deployed apps

### HE-10. Best Practices for Our Stack
- One chart per service vs umbrella chart: recommendation for Helix Stax with 20+ services; how ArgoCD App of Apps handles per-service charts
- Helm release naming convention: consistent naming pattern for releases (e.g., `traefik`, `cert-manager`, `zitadel`, `cnpg`, `kube-prometheus-stack`)
- Namespace strategy: which services share namespaces vs get their own; recommended namespace layout for our stack
- Values file organization: directory layout under `helm/` in the infra repo; base vs environment overrides; how to keep values DRY across services
- Chart version pinning: always pinning chart version in ArgoCD Application; never using `*` or `latest`; update cadence and process
- Upgrade strategy: test in staging vs direct prod upgrade for a single-cluster setup; use of --atomic for rollback on failure
- Post-install validation: what to check after every helm upgrade (pod status, Prometheus alerts, Traefik routes, application health endpoint)
- Handling CRD upgrades: separate CRD management from chart upgrades; crds/ directory in charts; manual CRD apply pattern for cert-manager, CloudNativePG, Kyverno

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

---

## Required Output Format

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

The following is the legacy output structure for reference — the progressive disclosure format above supersedes it:

```markdown

```markdown
# Cloudflare

## Overview
[2-3 sentence description of what Cloudflare does and why we use it]

## CLI Reference (wrangler)
### DNS Management
[Commands with examples]
### Tunnel Management
[Commands with examples]
### Access Policies
[Commands with examples]
### WAF Rules
[Commands with examples]

## DNS Patterns
[Best practices, record examples, debugging]

## Zero Trust
### Architecture
[How Access + Tunnel work together]
### Zitadel Integration
[OIDC setup steps]
### Per-Service Policies
[Examples for Grafana, n8n, etc.]

## WAF & Security
[Ruleset selection, custom rules, rate limiting]

## Performance
[Cache, Argo, image optimization]

## Traefik Integration
[Real IP, TLS modes, double-proxy avoidance]

## API & Automation
[API examples, OpenTofu provider]

## Troubleshooting
[Error codes, debugging steps]

## Gotchas
[Things that break, anti-patterns]

## Cost
[Free vs paid breakdown]

---

# Traefik

## Overview
[2-3 sentence description of what Traefik does and why we use it]

## IngressRoute CRD Reference
### IngressRoute Spec
[Full field reference with examples]
### Route Matching
[Syntax, operators, priority]
### IngressRouteTCP / IngressRouteUDP
[Spec and use cases]
### TLSOption & ServersTransport
[Spec and examples]

## Middleware
### ForwardAuth (Zitadel)
[Config with Zitadel-specific fields]
### RateLimit
[Config fields and CrowdSec integration]
### Headers
[Security headers, CORS, custom headers]
### Other Middleware Types
[Quick reference for remaining types]
### Middleware Chaining
[Order, failure behavior, cross-namespace]

## TLS
### Cloudflare Origin CA Certificate Management
[How to generate 15-year Origin CA certs, install as K8s Secrets, reference in IngressRoute. NO cert-manager, NO Let's Encrypt.]
### TLS Modes with Cloudflare
[Full vs Full Strict requirements — Full Strict requires Origin CA cert on Traefik]
### Wildcard Origin CA Certs
[Generating *.helixstax.com and *.helixstax.net in Cloudflare dashboard, referencing from multiple IngressRoutes]
### TLSOption & TLSStore
[Minimum version, cipher suites, fallback cert]

## Cloudflare Integration
### Real IP Forwarding
[CF-Connecting-IP, trustedIPs config]
### Proxy Protocol
[When Cloudflare sends it, how to enable]
### TLS Passthrough
[IngressRouteTCP config]
### WebSocket & gRPC
[Required config, Cloudflare limitations]

## Dashboard & API
### Securing the Dashboard
[IngressRoute + forwardAuth example]
### REST API Endpoints
[Useful endpoints for debugging]

## Metrics & Observability
### Prometheus Metrics
[How to enable, key metric names]
### ServiceMonitor
[CRD example]
### Grafana Dashboards
[Dashboard IDs, key panels]
### Access Logs to Loki
[JSON log config, Promtail pipeline]

## K3s-Specific Configuration
### HelmChartConfig Overrides
[CRD example, safe overrides]
### Disabling Bundled Traefik
[When and how]
### EntryPoints & LoadBalancer
[Default ports, klipper-lb behavior, firewall rules]

## Load Balancing & Advanced Routing
### Weighted Routing (Canary)
[TraefikService CRD example]
### Sticky Sessions
[Config fields]
### Health Checks
[Passive vs active, config]

## Troubleshooting
### 502 / 503 / 504 Errors
[Diagnosis steps for each]
### TLS Handshake Failures
[Debug log reading]
### forwardAuth Loops
[Common misconfigs, fix steps]
### IngressRoute Not Loaded
[RBAC, namespace, provider checks]
### Debug Logging
[How to enable, what to look for]

## Day-2 Operations
### Applying Config Changes
[HelmChartConfig reconciliation]
### Upgrading Traefik
[Chart version pinning]
### Plugins
[Installation via HelmChartConfig, CrowdSec bouncer]

---

# Helm

## Overview
[2-3 sentence description of what Helm does and why we use it]

## CLI Reference
### install / upgrade / rollback
[Commands with flags and examples]
### template / diff / test
[Commands with examples]
### get / history / list
[Commands with examples]
### repo / search / show
[Commands with examples]
### plugin
[Must-have plugins and install commands]

## Chart Development
### Chart.yaml
[All fields with examples]
### values.yaml
[Structure, null defaults, documentation]
### templates/
[Naming conventions, _helpers.tpl patterns]
### Template Functions
[toYaml+nindent, required, tpl, lookup, common patterns]
### Hooks
[Types, weights, deletion policies, use cases]
### Library Charts
[Type: library, define/include patterns]

## Repository Management
### Adding Public Repos
[helm repo add commands for each upstream we use]
### OCI Registries (Harbor)
[helm registry login, helm push, oci:// URLs]
### Repo vs OCI Differences
[Feature gaps, ArgoCD behavior]

## Values Management
### Multiple Values Files
[Merge order, gotchas]
### --set Precedence
[--set vs -f vs --set-string vs --set-json]
### Secrets in Values
[ESO pattern, helm-secrets with SOPS+age]
### Values Schema Validation
[values.schema.json, JSON Schema types]

## K3s-Specific Patterns
### HelmChart CRD
[Full spec, reconciliation, inspecting jobs]
### HelmChartConfig CRD
[Overriding bundled charts, valuesContent]
### Bundled Charts
[List, versions, auto-deploy from manifests dir]
### Manual Helm vs K3s Auto-Management
[Conflicts, identification, safe patterns]

## ArgoCD Integration
### Application Manifest (Helm source)
[Full spec.source.helm fields]
### Helm in ArgoCD vs CLI
[helm template behavior, hook limitations]
### Multi-source Applications
[spec.sources, values from separate repo]
### Helm Secrets with ArgoCD
[ESO approach, AVP alternative]
### App of Apps
[Bootstrap pattern]
### Sync Waves
[Annotation, install order for our stack]

## Dependency Management
### Chart.yaml Dependencies
[All fields, lock file, update vs build]
### Subcharts and Values
[Parent -> subchart value passing, global values]
### Umbrella vs Per-Service Charts
[Trade-offs, recommendation for our stack]

## Debugging
### helm template --debug
[Reading template source annotations]
### helm install --dry-run
[vs helm template, API validation]
### Common Errors
[Resource exists, immutable fields, timeout, CRD conflicts — each with fix]
### Helm Release Secrets
[Decoding, stuck states, recovery]

## Security
### Chart Signing
[GPG, provenance files, helm verify]
### Secrets Anti-patterns
[Shell history, git exposure, audit]
### RBAC
[Helm permissions, CI/CD service accounts, ArgoCD]

## Best Practices for Our Stack
### Release Naming & Namespace Layout
[Conventions for all 20+ services]
### Values File Organization
[Directory structure under helm/]
### Version Pinning & Upgrade Process
[Pinning, cadence, --atomic]
### CRD Upgrade Handling
[Separate CRD management, manual apply pattern]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual CRD YAML examples, actual HelmChartConfig snippets, and actual kubectl commands. Do NOT give me theory — give me copy-paste-ready manifests and commands for a K3s cluster behind Cloudflare on Hetzner with Zitadel as the IdP and ArgoCD + Harbor in the GitOps chain.
