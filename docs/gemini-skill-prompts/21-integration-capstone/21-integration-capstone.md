# Gemini Deep Research: Helix Stax Infrastructure Integration (Capstone)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive capstone reference document that shows how ALL 26 tools in my stack connect and interact. This research will become the master integration reference — the document agents load when they need to understand the full system, not just one component.

## What This Document Is
This is the capstone integration reference for the full Helix Stax infrastructure stack. It covers all data flows (traffic, auth, logs, metrics, alerts, backups, secrets, CI/CD), the service dependency graph, failure analysis, bootstrap order, day-2 operations, and cross-cutting operational tasks. The goal is a single document an AI agent can load to understand how ALL services relate to each other.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Domains**: helixstax.com (public, Google Workspace), helixstax.net (internal apps)
- **Edge**: Cloudflare (CDN + WAF + Zero Trust + DNS)
- **Ingress**: Traefik with cert-manager
- **Identity**: Zitadel (OIDC/SAML for ALL services — no exceptions)
- **Database**: CloudNativePG (PostgreSQL) — shared cluster, multiple databases
- **Cache**: Valkey
- **Storage**: MinIO (object storage) → Backblaze B2 (offsite)
- **Registry**: Harbor
- **Secrets**: SOPS+age (git encryption) + OpenBao (runtime vault) + External Secrets Operator (K8s sync)
- **CI/CD**: Devtron (CI) + ArgoCD (CD/GitOps)
- **Monitoring**: Prometheus + Grafana + Loki + Alertmanager
- **Security**: CrowdSec (IDS) + Kyverno (policy) + Gitleaks (secret scanning) + SOPS (encryption)
- **Apps**: n8n, Rocket.Chat, Backstage, Outline, Postal
- **Backup**: Velero → MinIO → Backblaze B2
- **IaC**: OpenTofu (provisioning) + Ansible (OS hardening) + Helm (app deployment)

## What I Need Researched

### 1. Full Architecture Map & Traffic Flow
- Internet → Cloudflare (WAF, DDoS, CDN) → Cloudflare Tunnel or direct to Hetzner IP → Traefik → Service
- Exactly how CrowdSec sits in this path: bouncer in Traefik middleware vs Cloudflare integration
- Which services are orange-cloud (Cloudflare-proxied) vs DNS-only
- Split between helixstax.com (public) and helixstax.net (internal, not proxied or Zero Trust)
- How Traefik IngressRoutes map to services: naming conventions, TLS termination, middleware chains
- cert-manager: which ClusterIssuers are used (Let's Encrypt ACME via Cloudflare DNS challenge vs HTTP challenge)
- WebSocket services (Rocket.Chat, n8n webhooks) — special Traefik config required
- gRPC services if any — Traefik h2c support
- How Devtron builds containers and pushes to Harbor, and how ArgoCD pulls from Harbor to deploy

### 2. Service Dependency Graph
- Full directed acyclic graph (DAG) of service dependencies — which services MUST be running before others can start
- PostgreSQL (CloudNativePG) is the root dependency: Zitadel, n8n, Outline, Rocket.Chat, Postal, Backstage all need a database
- Zitadel is second-order root: every service needing OIDC auth depends on Zitadel being healthy
- MinIO dependencies: Velero needs MinIO, Loki needs MinIO for log storage, Harbor needs MinIO for artifact storage, CloudNativePG WAL archiving needs MinIO
- Harbor dependencies: Devtron needs Harbor to push/pull images
- ArgoCD dependencies: deploys everything else, so needs to be up but doesn't block others directly
- External Secrets Operator dependencies: every pod that needs secrets depends on ESO being healthy AND OpenBao being reachable
- Traefik dependency: every ingress-exposed service depends on Traefik
- Cert-manager dependency: TLS for every service depends on cert-manager
- Complete list: what can be deployed in parallel, what must be sequential

### 3. Authentication Flow (Zitadel as Central IdP)
- How every service integrates with Zitadel — OIDC client IDs, redirect URIs, scopes required
- Services using OIDC: Grafana, n8n, Devtron, ArgoCD, Outline, Rocket.Chat, Backstage, Harbor, MinIO, OpenBao
- Services using SAML: any? (Google Workspace uses Zitadel as IdP via SAML if configured)
- Machine-to-machine (M2M) flows: Devtron → Harbor, n8n → Zitadel API, Alertmanager → Rocket.Chat webhook
- Service accounts vs human users in Zitadel — when to use which
- Token lifetimes: access token vs refresh token — what each service expects
- How to add a new service to Zitadel: step-by-step OIDC client creation, scopes, redirect URIs, role mappings
- Cloudflare Access integration with Zitadel: which services use CF Access vs direct Zitadel OIDC
- Session management across services: how SSO works end-to-end for a human user
- Group/role synchronization from Zitadel to downstream services (Grafana org roles, ArgoCD RBAC, etc.)

### 4. Observability Flow (Metrics, Logs, Traces, Alerts)
- **Metrics flow**: Every service exposes /metrics → Prometheus scrapes → Grafana queries → Alertmanager fires
  - ServiceMonitor CRDs for all services: which are built-in, which need custom exporters
  - Key metrics to alert on per service (Postgres connections, Harbor disk, MinIO capacity, Zitadel auth failures, Traefik 5xx rate, CrowdSec bans)
- **Logging flow**: Every service container → Promtail (or Grafana Alloy) DaemonSet → Loki → Grafana Explore
  - Which services write structured JSON logs vs plaintext
  - Promtail pipeline stages for common log formats (Traefik access logs, PostgreSQL logs, K3s audit logs)
  - Log retention policy: what to keep, what to drop
  - MinIO as Loki storage backend — bucket configuration, IAM policy needed
- **Alerting flow**: Alertmanager → Rocket.Chat (primary) + Postal email (secondary)
  - Alertmanager routing rules: severity labels → which Rocket.Chat channel
  - n8n as alert webhook receiver — when to use n8n vs direct Alertmanager routing
  - Dead man's switch: how to ensure the alerting pipeline itself is monitored
- **Grafana dashboards**: which are imported from Grafana.com, which are custom
  - Dashboard provisioning via ConfigMaps or Helm values
  - Multi-datasource dashboards: correlating Prometheus metrics + Loki logs in one panel

### 5. Backup & Recovery Flow
- **Velero flow**: Scheduled backup → K8s resources + PVC snapshots → MinIO (S3-compatible) → Backblaze B2 (via MinIO lifecycle or separate sync)
  - What Velero backs up: namespace resources, PVC data, CRDs, secrets (with caution)
  - What Velero does NOT back up: database contents (use CloudNativePG WAL for that)
  - Backup schedules: full cluster daily, per-namespace on different schedules
  - Restoration procedure: cluster wipe → restore order (which namespaces first)
- **CloudNativePG backup flow**: Continuous WAL archiving → MinIO → point-in-time recovery (PITR)
  - WAL archiving config: bucket, path, credentials (via ESO from OpenBao)
  - Scheduled base backups: frequency, retention policy
  - Cross-region backup: MinIO → Backblaze B2 via mc mirror or lifecycle rules
  - Recovery procedure: new cluster manifest with bootstrap.recovery spec
- **MinIO → Backblaze B2**: how to configure MinIO to replicate to B2 (bucket replication vs mc mirror vs lifecycle)
- **Harbor backup**: how to back up Harbor registry data (artifact storage in MinIO, database in PostgreSQL — both covered above)
- **Full DR scenario**: cluster total loss → how to recover everything in order, how long it takes

### 6. CI/CD Flow
- **Developer push flow**: git push → GitHub webhook → Devtron CI pipeline triggers
  - Devtron CI: clone → build Docker image → Gitleaks scan (pre-push hook vs CI step) → push to Harbor
  - Harbor vulnerability scanning: Trivy integrated with Harbor — block deploy on CRITICAL?
  - ArgoCD detects new image tag in Helm values → deploys to K3s
- **GitOps config change flow**: PR to infrastructure repo → review → merge → ArgoCD auto-syncs
  - ArgoCD sync policies: auto-sync with self-heal vs manual sync for production
  - ArgoCD App of Apps pattern: how to structure application manifests
  - Helm chart updates: how ArgoCD handles Helm releases vs raw manifests
- **Secret injection flow**: SOPS-encrypted secrets in git → git repo → ESO reads from OpenBao → K8s Secret → pod env vars
  - SOPS+age: how to encrypt/decrypt per-file, key rotation procedure
  - OpenBao: KV v2 paths, AppRole auth for ESO, transit engine for dynamic secrets
  - External Secrets Operator: ExternalSecret CRD → OpenBao → K8s Secret sync interval
  - Which secrets are in SOPS (git-stored, bootstrapping) vs OpenBao (runtime, rotatable)
- **New service deployment checklist**: step-by-step to add a new service to the cluster end-to-end

### 7. Secret Management Flow
- **SOPS + age**: encrypting Helm values files, bootstrapping secrets that must exist before OpenBao is running
  - age key management: where the key lives, how agents access it, backup procedure
  - SOPS config (.sops.yaml): which files to encrypt, which keys to use, partial encryption
  - GitOps with SOPS: ArgoCD SOPS plugin (helm-secrets or ksops) — which one, how configured
- **OpenBao (HashiCorp Vault fork)**: the runtime secret store
  - Auth methods enabled: Kubernetes auth (for pods), AppRole (for ESO/Ansible), userpass (for humans)
  - Secret engines: KV v2 (app secrets), PKI (internal CAs), Transit (encryption-as-a-service), Database (dynamic PostgreSQL credentials)
  - Seal/unseal: auto-unseal with what? (cloud KMS? Shamir? risk analysis for small cluster)
  - OpenBao HA: is HA needed on a 2-node cluster? integrated storage (Raft) config
- **External Secrets Operator**: bridge between OpenBao and K8s Secrets
  - SecretStore CRD: one per namespace or cluster-scoped ClusterSecretStore?
  - ExternalSecret refresh interval: how often to re-sync
  - What happens when OpenBao is down: cached secrets, pod restarts fail
- **Dynamic secrets**: PostgreSQL dynamic credentials via OpenBao database engine — which services use this vs static credentials

### 8. Network Flow & Security Layers
- **Inbound traffic layers**: Internet → Cloudflare (L7 WAF, rate limit, DDoS) → Hetzner firewall (L4) → CrowdSec bouncer in Traefik (L7 ban list) → Traefik (routing) → Service
  - Hetzner firewall rules: which ports are open (80, 443, 6443 K8s API from specific IPs only, SSH from specific IPs only)
  - K3s API server exposure: should the API be behind Cloudflare or direct IP access only?
  - CrowdSec: community threat intel + local decisions, how bouncer in Traefik is configured
- **Cluster-internal network**: Flannel CNI, pod CIDR, service CIDR, DNS (CoreDNS)
  - Which services communicate pod-to-pod vs through the service mesh
  - No service mesh currently — how to handle mTLS between services if needed later
  - NetworkPolicy: does K3s + Flannel support NetworkPolicy? (Flannel alone does NOT — needs Flannel + NetworkPolicy controller or migrate to Cilium)
- **Kyverno policies**: what policies are enforced cluster-wide
  - Pod security: require non-root, drop capabilities, read-only root FS where possible
  - Image policy: only allow pulls from Harbor (block Docker Hub, quay.io in production namespaces)
  - Resource limits: require all pods to have CPU/memory limits
  - Label requirements: all deployments must have app/version labels
- **DNS architecture**: Cloudflare DNS for helixstax.com and helixstax.net
  - Which records are A records (direct to Hetzner IP), which are CNAME to Cloudflare
  - Internal DNS: CoreDNS in K3s for cluster-internal service discovery (service.namespace.svc.cluster.local)
  - Split DNS for helixstax.net: internal-only resolution vs public Cloudflare records

### 9. Failure Analysis & Blast Radius
- **Single node failure (helix-worker-1 down)**: which services fail, which survive on control plane, how to recover
  - K3s control plane on heart: etcd survives, API server survives, but workloads on worker are down
  - StatefulSets with PVCs on worker node: data not lost (local-path PVs are node-local — THIS IS A RISK)
  - Recovery: worker restores, K3s rejoins, pods reschedule
- **Control plane failure (heart down)**: catastrophic — API server gone, no scheduling, etcd gone
  - How to recover K3s single-CP cluster: restore from etcd snapshot + Velero
  - Etcd backup: K3s embedded etcd snapshot schedule, where snapshots are stored
- **PostgreSQL cluster failure**: CloudNativePG cluster — what happens when primary goes down
  - Automatic failover to replica (if replicas configured — are they on 2-node cluster?)
  - Applications that buffer vs applications that hard-fail
  - CloudNativePG switchover vs failover procedure
- **Zitadel down**: auth fails for ALL services that require OIDC — blast radius is massive
  - Which services fail immediately (active session checking) vs which survive on cached tokens
  - Recovery: Zitadel depends on PostgreSQL — if PostgreSQL is up, Zitadel restarts quickly
- **MinIO down**: Loki can't write logs, Velero can't write backups, Harbor can't store artifacts, CloudNativePG WAL archiving fails
  - None of these are immediately catastrophic but degrade quickly
  - MinIO single-node: no HA — this is a known risk
- **OpenBao sealed/down**: ESO can't refresh secrets, new pods that need secrets fail to start, existing pods continue until token expiration
- **Cloudflare down**: all public traffic blocked, but internal helixstax.net services still work if not CF-proxied
- **ArgoCD down**: no new deployments but existing workloads continue running — low blast radius
- **Traefik down**: ALL ingress traffic fails — highest blast radius after PostgreSQL and Zitadel
- **Per-service: mean time to detect, mean time to recover, data loss risk**

### 10. Bootstrap Order & Day-2 Operations
- **Bootstrap order from scratch** (complete ordered list):
  1. OpenTofu: provision Hetzner VPS, Cloudflare DNS records, firewall rules
  2. Ansible: AlmaLinux hardening (SELinux, SSH, CIS Benchmark, firewall)
  3. Ansible: K3s installation on heart (CP) and helix-worker-1 (worker)
  4. Helm: Traefik (ingress must exist before any service is exposed)
  5. Helm: cert-manager + ClusterIssuers (TLS before any service gets a cert)
  6. Helm: External Secrets Operator (must be up before any secret-dependent service)
  7. Manual: Bootstrap OpenBao (initialize, unseal, configure auth methods, load initial secrets)
  8. Helm: CloudNativePG operator + PostgreSQL cluster (root database dependency)
  9. Helm: MinIO (needed by Loki, Velero, Harbor, CloudNativePG WAL archiving)
  10. Helm: Harbor + configure robot accounts
  11. Helm: Valkey (cache layer)
  12. Helm: Zitadel (needs PostgreSQL) + configure OIDC clients for all services
  13. Helm: Devtron + ArgoCD (needs Harbor + Zitadel)
  14. Helm: Prometheus + Grafana + Loki + Alertmanager (observability stack)
  15. Helm: CrowdSec (needs Traefik middleware hook)
  16. Helm: Kyverno + policies (enforce after other services are stable)
  17. Helm: n8n (needs PostgreSQL + Zitadel)
  18. Helm: Rocket.Chat (needs Zitadel)
  19. Helm: Outline (needs PostgreSQL + Zitadel + MinIO)
  20. Helm: Postal (needs PostgreSQL + DNS setup)
  21. Helm: Velero (needs MinIO)
  22. Helm: Backstage (Phase 3+)
- **Day-2 operations**:
  - Helm chart upgrades: procedure for upgrading each chart with zero-downtime
  - K3s version upgrades: drain worker, upgrade CP, upgrade worker, verify
  - AlmaLinux OS patching: patch nodes with K3s workloads, cordon/drain procedure
  - Certificate rotation: cert-manager auto-renews Let's Encrypt, but manual certs need tracking
  - OIDC client secret rotation in Zitadel + coordinated update in OpenBao + ESO refresh
  - PostgreSQL major version upgrade with CloudNativePG
  - Harbor garbage collection: when and how to run without disrupting CI/CD
  - CrowdSec hub updates: new parsers, scenarios, postoverflow rules
  - Kyverno policy updates: test in audit mode before enforcement
- **Adding a new service** (complete checklist):
  1. Create Zitadel OIDC client → note client ID + secret
  2. Store client secret in OpenBao (kv/data/services/<name>/oidc)
  3. Create ExternalSecret CRD to sync into K8s Secret
  4. Write Helm values with OIDC config pointing to Zitadel
  5. Create CloudNativePG database (if needed): new Database CRD
  6. Add Traefik IngressRoute with correct middleware chain (auth? crowdsec? rate-limit?)
  7. Add Cloudflare DNS record (A or CNAME)
  8. Add ServiceMonitor for Prometheus scraping
  9. Add Promtail pipeline stage if log format is non-standard
  10. Add ArgoCD Application or AppProject pointing to Helm chart
  11. Create Velero backup schedule annotation on namespace
  12. Add Kyverno policy exceptions if needed (e.g., service needs root)

## Required Output Format

Structure your response EXACTLY like this — it will be directly saved as a reference document for AI agents:

```markdown
# Helix Stax Infrastructure Integration

## Overview
[2-3 sentence description of the full stack and the purpose of this capstone document]

## Architecture Map
### Traffic Flow
[Internet -> Cloudflare -> Traefik -> Services, with each hop annotated]
### DNS Architecture
[Cloudflare DNS records, split DNS, CoreDNS internals]
### Network Layers
[Hetzner firewall -> CrowdSec -> Traefik middleware -> Service]

## Service Dependency Graph
### Tier 0 (No Dependencies)
[Services that can boot with only K8s]
### Tier 1 (Depends on Tier 0)
[Services with single upstream dependencies]
### Tier 2 (Depends on Tier 1)
[Services with multi-layer dependencies]
### Tier 3 (Depends on Tier 2)
[Application layer services]
### Dependency Table
[Table: Service | Depends On | Required For]

## Authentication Flow
### Zitadel as Central IdP
[OIDC flow diagram in text, client registration summary]
### Per-Service OIDC Config
[Table: Service | Client ID pattern | Scopes | Redirect URI pattern | Role mapping]
### Machine-to-Machine (M2M)
[Service accounts, client credentials flow]
### SSO Session Flow
[End-to-end: user hits Grafana -> redirected to Zitadel -> token -> Grafana session]

## Observability Flow
### Metrics Pipeline
[Every service -> Prometheus -> Grafana, ServiceMonitor setup]
### Logging Pipeline
[Promtail -> Loki -> Grafana, pipeline stages]
### Alerting Pipeline
[Alertmanager -> Rocket.Chat -> Postal, routing rules]
### Key Alerts per Service
[Table: Service | Alert condition | Severity | Channel]

## Backup & Recovery Flow
### Velero Backup Flow
[Schedule -> what's captured -> MinIO -> B2]
### CloudNativePG WAL Archiving
[Continuous WAL -> MinIO -> PITR procedure]
### MinIO to Backblaze B2
[Replication method, schedule]
### Full DR Procedure
[Ordered recovery from total cluster loss]

## CI/CD Flow
### Developer Push Flow
[git push -> Devtron -> Harbor -> ArgoCD -> K3s]
### GitOps Config Change Flow
[PR -> merge -> ArgoCD sync]
### Gitleaks Integration
[Where scanning happens in the pipeline]
### Harbor Vulnerability Scanning
[Trivy integration, blocking policy]

## Secret Management Flow
### SOPS + age (Git Layer)
[What's encrypted, how agents decrypt, key location]
### OpenBao (Runtime Layer)
[Auth methods, secret engines, paths reference]
### External Secrets Operator (K8s Layer)
[SecretStore -> ExternalSecret -> K8s Secret]
### Secret Lifecycle
[Creation -> rotation -> revocation procedure]

## Failure Analysis
### Blast Radius Table
[Table: Component | Failure Mode | Services Affected | Recovery Time | Data Loss Risk]
### Critical Path Analysis
[The 3-4 most dangerous single points of failure and how to mitigate]
### Recovery Procedures
[Per-component recovery runbook references]

## Bootstrap Order
### Phase 1: Infrastructure
[OpenTofu + Ansible steps]
### Phase 2: Core Platform
[Traefik, cert-manager, ESO, OpenBao, PostgreSQL, MinIO]
### Phase 3: Identity & Registry
[Zitadel, Harbor, Valkey]
### Phase 4: CI/CD & Observability
[Devtron, ArgoCD, Prometheus, Grafana, Loki, CrowdSec, Kyverno]
### Phase 5: Applications
[n8n, Rocket.Chat, Outline, Postal, Velero]
### Phase 6+: Extended Platform
[Backstage, OpenTelemetry]

## Day-2 Operations
### Upgrade Procedures
[K3s, Helm charts, OS patching — with cordon/drain steps]
### Certificate Management
[Auto-renew tracking, manual cert rotation]
### Credential Rotation
[OIDC secrets, PostgreSQL passwords, MinIO access keys — coordinated rotation steps]
### Capacity Management
[MinIO growth, PostgreSQL connections, Loki log volume]

## Adding a New Service
[Complete 10-step checklist: Zitadel -> OpenBao -> ESO -> Helm -> DNS -> Traefik -> Prometheus -> Loki -> ArgoCD -> Velero]

## Common Cross-Cutting Tasks
### Adding a New Client (Business)
[Zitadel org/project, Outline workspace, Rocket.Chat channel, ClickUp folder]
### Rotating All Credentials
[Emergency full rotation procedure]
### Debugging Auth Failures
[Flowchart: is Zitadel up? -> is OIDC client correct? -> is redirect URI matching? -> check token scopes]
### Debugging Missing Logs
[Promtail -> Loki -> Grafana troubleshooting chain]
### Debugging Missing Metrics
[ServiceMonitor -> Prometheus targets -> Grafana datasource]
```

Be thorough, opinionated, and practical. Include actual resource names, actual Kubernetes manifest snippets, actual CLI commands, and actual error messages where relevant. Do NOT give me theory — give me copy-paste-ready configs and commands for this specific K3s cluster on Hetzner. Reference the actual service names (helixstax.net domains, Zitadel at auth.helixstax.net, Grafana at grafana.helixstax.net, etc.). Where you must make naming assumptions, state them explicitly so I can correct them.
