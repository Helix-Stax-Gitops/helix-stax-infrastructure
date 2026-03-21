# Gemini Deep Research: GitOps CI/CD (ArgoCD + Devtron)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

ArgoCD and Devtron are the GitOps and CI/CD engines that deploy everything to K3s:

- **ArgoCD** is our GitOps continuous deployment engine. It watches our GitHub repositories for changes to Kubernetes manifests, Helm charts, and Kustomize configs, then automatically syncs the cluster to match the desired state declared in git. It is the source of truth for what runs in our cluster — specifically for infrastructure-level components (Prometheus, Traefik, cert-manager, Zitadel, and all platform services).
- **Devtron** is our CI/CD platform. It provides a unified dashboard for building container images, managing deployment pipelines, and promoting releases across environments. It uses its own bundled ArgoCD instance under the hood for GitOps-based application deployments and integrates with Harbor for image storage. It handles the developer-facing CI/CD workflow for application workloads.

These two tools are deeply coupled and must be understood together. Devtron runs its own ArgoCD instance internally — if you don't understand the namespace isolation and naming conventions, you will create conflicts between Devtron-managed apps and standalone ArgoCD-managed infra. The recommended split is: Devtron manages application workloads (CI builds, image promotion, app deployments); standalone ArgoCD manages infrastructure GitOps (Prometheus, Traefik, cert-manager, Zitadel, and the platform layer).

## Our Specific Setup

- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart CP: 178.156.233.12, helix-worker-1 worker: 138.201.131.157)
- **GitOps repos**: GitHub (KeemWilliams org), manifests in `helix-stax-infrastructure/`
- **ArgoCD ingress**: Traefik routes ArgoCD UI at argocd.helixstax.net, behind Cloudflare Zero Trust
- **Devtron ingress**: Traefik routes Devtron UI at devtron.helixstax.net, behind Cloudflare Zero Trust
- **Identity**: Zitadel is our OIDC IdP — both ArgoCD and Devtron SSO authenticate via Zitadel (they are configured separately — do NOT conflate their OIDC config)
- **Registry**: Harbor on K3s stores all built container images (`harbor.helixstax.net`)
- **CI**: Devtron runs CI pipelines (Kaniko builds) and pushes images to Harbor; ArgoCD handles CD for infra
- **Secrets**: SOPS+age encrypts secrets in git; External Secrets Operator pulls from OpenBao at runtime
- **Notifications**: Rocket.Chat for build/deploy alerts; n8n webhooks for automation triggers
- **Monitoring**: Prometheus scrapes ArgoCD metrics; Grafana dashboards visualize sync state and pipeline health
- **ArgoCD co-existence**: Devtron's internal ArgoCD runs in `devtroncd` namespace; standalone ArgoCD runs in `argocd` namespace — they manage separate sets of applications

---

## What I Need Researched

---

# ArgoCD Research Areas

### AC-1. CLI Reference (argocd)
- Complete `argocd` CLI command reference with flags and examples
- `argocd app create`, `argocd app sync`, `argocd app diff`, `argocd app rollback`, `argocd app delete`
- `argocd app get`, `argocd app list`, `argocd app history`, `argocd app set`
- `argocd proj create`, `argocd proj list`, `argocd proj get`, `argocd proj set`
- `argocd repo add`, `argocd repo list` for GitHub repos and Harbor OCI
- `argocd cluster add`, `argocd cluster list` for multi-cluster (single now, future-proofing)
- `argocd login`, `argocd account update-password`, `argocd admin settings`
- How to use `--grpc-web` flag when behind Traefik (important for our setup)
- Scripting patterns: using `--auth-token` for CI/CD automation without interactive login

### AC-2. Application Manifests
- `Application` CRD structure: spec.source, spec.destination, spec.syncPolicy, spec.project
- Helm source: `chart`, `repoURL`, `targetRevision`, `helm.values`, `helm.valueFiles`
- Kustomize source: `kustomize.images` for image overrides, `kustomize.version`
- Plain YAML/directory source: `directory.recurse`, `directory.include`, `directory.exclude`
- `AppProject` CRD: sourceRepos, destinations, roles, namespaceResourceWhitelist
- `ApplicationSet` CRD: cluster generator, git generator, list generator — when to use each
- How to pin a specific chart version vs track latest
- Annotations that control ArgoCD behavior: `argocd.argoproj.io/sync-wave`, `argocd.argoproj.io/hook`

### AC-3. Multi-Source Applications
- Multi-source app spec: combining a Helm chart from OCI (Harbor) with values from a git repo
- Why multi-source matters: separating chart releases from environment-specific values
- How to reference Harbor OCI charts: `repoURL: oci://harbor.helixstax.net/charts`
- Helm values from git + chart from Artifact Hub or Harbor: exact YAML structure
- Limitations of multi-source apps (ArgoCD version requirements, known bugs)
- Multi-source with Kustomize overlays on top of Helm output

### AC-4. Sync Policies
- `automated.prune: true` — what gets deleted and when, safety considerations
- `automated.selfHeal: true` — how it detects and corrects drift, polling interval
- `syncOptions`: `CreateNamespace=true`, `PruneLast=true`, `ApplyOutOfSyncOnly=true`, `RespectIgnoreDifferences=true`, `ServerSideApply=true`
- Sync retry: `retry.limit`, `retry.backoff.duration`, `retry.backoff.factor`, `retry.backoff.maxDuration`
- Manual sync triggers: when to use `argocd app sync --force`, `--replace`, `--prune`
- Sync windows: scheduling maintenance windows where auto-sync is blocked
- Ignore differences: `ignoreDifferences` for fields that change at runtime (e.g., replicas managed by HPA)
- Resource hooks: `PreSync`, `Sync`, `PostSync`, `SyncFail` — ordering and use cases

### AC-5. RBAC and SSO with Zitadel
- ArgoCD OIDC configuration in `argocd-cm` ConfigMap: `oidc.config` block with Zitadel endpoints
- Zitadel OIDC client setup for ArgoCD: client ID, secret, redirect URIs, scopes
- Group claims from Zitadel: how to map Zitadel roles/groups to ArgoCD RBAC policies
- `argocd-rbac-cm` ConfigMap: `policy.csv` format, `g` (group) and `p` (policy) lines
- Built-in roles: `role:admin`, `role:readonly` — customizing them
- Project-scoped RBAC: restricting teams to specific ArgoCD projects
- `argocd-secret` for OIDC client secret: how to inject it from External Secrets Operator / OpenBao
- Token expiry and refresh: session management with Zitadel OIDC

### AC-6. Notifications
- ArgoCD Notifications controller: installing via Helm, enabling in ArgoCD Helm chart
- Rocket.Chat webhook integration: trigger format, webhook URL configuration in `argocd-notifications-cm`
- Notification triggers: `on-sync-failed`, `on-sync-succeeded`, `on-health-degraded`, `on-deployed`
- Notification templates: Go template syntax for Rocket.Chat message formatting
- n8n webhook integration: sending ArgoCD events to n8n for automation workflows
- `argocd-notifications-secret` for webhook secrets: injecting via External Secrets Operator
- Subscription model: subscribing applications to notification triggers via annotations

### AC-7. Repository and Registry Management
- Adding GitHub repos: HTTPS with token vs SSH with deploy key — which to use
- `argocd repo add https://github.com/KeemWilliams/helix-stax-infrastructure --username --password`
- Harbor OCI registry: `argocd repo add oci://harbor.helixstax.net --type helm --enable-oci`
- Repository credentials templates: sharing credentials across multiple repos with same prefix
- `argocd-repositories` secret structure for storing repo credentials
- How ArgoCD handles private Helm chart repositories with authentication
- Refresh intervals: how often ArgoCD polls git for changes, how to force immediate refresh

### AC-8. Health Checks and Custom Assessments
- Built-in health checks: Deployment, StatefulSet, DaemonSet, Service, Ingress, PVC
- Custom health checks in `argocd-cm`: Lua scripts for CRDs (CloudNativePG Cluster, Traefik IngressRoute)
- Writing a Lua health check for CloudNativePG `Cluster` resource
- Writing a Lua health check for Traefik `IngressRoute` CRD
- Health check for `CertificateRequest` and `Certificate` (cert-manager)
- How degraded health blocks auto-sync, how to override
- `argocd app wait --health` for scripting deployment verification

### AC-9. Secrets Integration (SOPS + OpenBao)
- The core problem: ArgoCD syncs git, but secrets in git must be encrypted
- SOPS+age approach: encrypting secret manifests in git, decrypting at sync time with ArgoCD-vault-plugin or Helm secrets
- ArgoCD Vault Plugin (AVP): architecture, how it intercepts manifests and injects secrets from OpenBao
- AVP installation as an init container in ArgoCD repo-server
- AVP annotation: `argocd.argoproj.io/manifest-generate-command` for triggering AVP
- External Secrets Operator alternative: ArgoCD syncs ESO `ExternalSecret` CRDs, ESO fetches from OpenBao
- Which approach is better for our stack: AVP vs ESO (trade-offs, our recommendation)
- Helm secrets plugin: using SOPS-encrypted `values.yaml` files with Helm sources

### AC-10. Troubleshooting
- Sync status meanings: `Synced`, `OutOfSync`, `Unknown`, `Error` — what each means and first steps
- `ComparisonError`: usually CRD not installed or API version mismatch — debugging steps
- `SyncFailed`: resource hook failed, webhook timeout, manifest render error
- How to read `argocd app get <app> --show-operation` output for sync failure details
- `argocd app diff <app>` — reading the diff output to understand what would change
- Stuck in `Progressing`: Deployment not rolling out, health check failing — diagnosis
- ArgoCD repo-server errors: manifest generation failures, plugin crashes, git clone errors
- `argocd admin app generate-spec` for reverse-engineering existing apps
- Log locations: repo-server, application-controller, server — what each logs
- Devtron co-existence issues: Devtron also uses ArgoCD internally — avoiding conflicts, namespacing apps

### AC-11. Devtron Co-existence
- How Devtron uses ArgoCD under the hood: Devtron installs its own ArgoCD or shares existing
- Namespace isolation: Devtron-managed apps vs manually-managed ArgoCD apps
- Avoiding resource conflicts: Devtron's ArgoCD instance vs our standalone ArgoCD apps
- Whether to use one ArgoCD instance or two separate installations
- How to query Devtron's ArgoCD state from CLI without interfering
- Recommended pattern for our setup: Devtron for app CI/CD, standalone ArgoCD for infra GitOps
- Port-forwarding to Devtron's ArgoCD for debugging: `kubectl port-forward -n devtroncd svc/argocd-server`

### AC-12. Monitoring and Metrics
- ArgoCD Prometheus metrics: `argocd_app_info`, `argocd_app_sync_total`, `argocd_app_health_status`
- ServiceMonitor CRD for Prometheus scraping ArgoCD controller, server, repo-server
- Grafana dashboard IDs for ArgoCD (community dashboards that work well)
- Key alerts to configure in Alertmanager: sync failures, degraded health, repo errors
- How to expose ArgoCD metrics endpoint when running behind Traefik

---

# Devtron Research Areas

### DV-1. CLI and API Reference
- Devtron REST API: base URL structure, authentication (API token generation, Bearer token usage)
- Key API endpoints: `/orchestrator/api/v1/app`, `/orchestrator/api/v1/cd-pipeline`, `/orchestrator/api/v1/artifact`
- How to trigger CI builds via API: POST to pipeline trigger endpoint with payload structure
- How to trigger CD deployments via API: promote image to environment, rollback via API
- `devtron` CLI tool (if it exists): installation, commands, authentication
- Scripting patterns for CI/CD automation: polling build status, waiting for deploy completion
- API pagination, rate limits, and error response formats
- How to generate and rotate API tokens in Devtron UI and programmatically

### DV-2. CI Pipeline Configuration
- CI pipeline anatomy: source config (branch, tag, PR), build config, pre-CI tasks, post-CI tasks
- Build strategies: Docker build (Dockerfile path), Buildpack (auto-detect), Kaniko (rootless in-cluster)
- Kaniko vs Docker daemon: why Kaniko is preferred in K3s, configuration differences
- Build arguments: how to pass `ARG` values, environment variables into build
- Pre-CI tasks: running lint, tests, security scans before build
- Post-CI tasks: image scanning (Trivy), SBOM generation, tagging conventions
- Multi-architecture builds: building for amd64 and arm64 from K3s
- Build caching: layer caching with Kaniko, cache storage in Harbor or MinIO
- Webhook triggers: GitHub webhook configuration for auto-trigger on push/PR
- How to configure branch filters: only trigger on `main`, ignore `feat/*` branches

### DV-3. CD Pipeline Configuration
- CD pipeline anatomy: deployment strategy, environment targets, pre/post deployment tasks
- Deployment strategies: Rolling, Blue-Green, Canary — how each works in Devtron on K3s
- Deployment template: Devtron's Helm chart wrapper — key fields (image, resources, ingress, env vars)
- Environment promotion flow: dev -> staging -> prod with image locking
- Pre-deployment tasks: database migration hooks, smoke test scripts
- Post-deployment tasks: health check verification, notification triggers
- Manual approval gates: configuring required approvals before production deploy
- Auto-deploy on image push vs manual trigger — configuration options
- How Devtron generates and manages Helm releases under the hood
- Rollback: how to roll back to a previous image via UI and API

### DV-4. Environment Management
- Environment CRD in Devtron: how environments map to K3s namespaces
- Creating environments: namespace, cluster, default namespace for app deployments
- Environment-specific config override: different values.yaml per environment
- How Devtron handles namespace creation and RBAC on K3s
- Cluster management: adding the local K3s cluster, kubeconfig management
- Namespace isolation: ensuring dev/staging/prod don't share resources
- Environment variables: injecting per-environment secrets via External Secrets Operator in Devtron templates
- How to use ConfigMaps and Secrets in the Devtron deployment template

### DV-5. Harbor Integration
- Configuring Harbor as a container registry in Devtron global settings
- Registry URL format: `harbor.helixstax.net`, project mapping, robot account credentials
- Robot account vs user account for Devtron-to-Harbor authentication
- How Devtron pushes images: image naming convention `harbor.helixstax.net/<project>/<app>:<tag>`
- Image tag strategy: commit SHA, build number, semver — configuration
- Harbor replication: does Devtron trigger Harbor replication policies?
- Image vulnerability scanning: Trivy integration via Devtron vs Harbor's built-in scanner (Trivy)
- Pull secrets: how K3s pods pull from private Harbor registry (imagePullSecret management in Devtron)

### DV-6. GitOps Mode vs Helm Mode
- GitOps mode: Devtron commits Helm values to a git repo, ArgoCD syncs — full GitOps flow
- Helm mode: Devtron directly applies Helm charts to cluster — simpler but less auditable
- Which mode to use for our setup: recommendation with trade-offs
- How ArgoCD is used internally by Devtron in GitOps mode: Devtron's ArgoCD vs standalone ArgoCD
- GitOps repo structure Devtron creates/expects
- How to migrate from Helm mode to GitOps mode without downtime
- Configuration drift handling in each mode

### DV-7. RBAC and SSO with Zitadel
- Devtron OIDC configuration: where to configure in Devtron UI (Global Config > SSO Login Services)
- Zitadel OIDC client setup for Devtron: client ID, secret, redirect URIs, required scopes
- Group/role claims from Zitadel: mapping Zitadel roles to Devtron permission groups
- Devtron permission model: super-admin, manager, trigger, view — what each can do
- Project-level permissions: restricting teams to specific Devtron projects
- API token scopes: generating tokens with limited permissions for automation
- How Devtron stores and manages auth state: session management, token expiry
- `argocd-cm` OIDC vs Devtron's own SSO: they are separate — don't conflate

### DV-8. Devtron Chart Store
- What the chart store is: deploying third-party Helm charts through Devtron UI
- Connecting chart repositories: Artifact Hub, Bitnami, our Harbor OCI registry
- Deploying a chart from store: select chart, version, configure values, deploy to namespace
- Chart store vs app-level deployment: when to use chart store vs full CI/CD pipeline
- Version management: pinning chart versions, upgrading, rollback
- Custom chart repositories: adding `harbor.helixstax.net/chartrepo/<project>` to chart store
- Limitations: what can't be done via chart store that requires a full pipeline

### DV-9. Global Configuration
- Container registries: adding Harbor, DockerHub — fields, auth formats
- Git accounts: adding GitHub with personal access token or GitHub App
- Cluster management: kubeconfig upload, cluster health verification
- Notification settings: Rocket.Chat webhook, SMTP via Postal, SES fallback
- External secrets integration: how Devtron references External Secrets Operator for app secrets
- Docker build config: default builder, resource limits for build pods
- Blob storage: connecting MinIO for build artifacts, logs, cache storage
- System configurations: API rate limits, log retention, audit log settings

### DV-10. ArgoCD Co-existence
- Devtron's internal ArgoCD: which namespace it runs in, how to identify its apps
- Standalone ArgoCD (our infra GitOps): runs separately for non-app infrastructure
- Naming conflicts: ensuring Devtron app names don't collide with standalone ArgoCD app names
- Shared cluster: both Devtron's ArgoCD and standalone ArgoCD managing the same K3s cluster
- How to query Devtron's ArgoCD without interfering: read-only access patterns
- Recommended split: Devtron manages application workloads (CI/CD); standalone ArgoCD manages infra (Prometheus, Traefik, cert-manager, Zitadel)
- Port-forwarding to Devtron's ArgoCD for debugging: `kubectl port-forward -n devtroncd svc/argocd-server`

### DV-11. Notifications
- Devtron notification architecture: SES, SMTP, Slack, Webhook
- Rocket.Chat webhook: configuring as a generic webhook destination in Devtron
- Notification triggers: build started, build success, build failure, deployment success, deployment failure
- Postal SMTP integration: Devtron email via Postal for pipeline failure alerts
- n8n webhook: sending Devtron events to n8n for complex automation (ClickUp task creation, etc.)
- Per-pipeline notification subscriptions: subscribing specific pipelines to notification channels
- Notification template customization: what fields are available in templates

### DV-12. Troubleshooting
- Build failures: where to find build logs (Devtron UI, `kubectl logs` on build pod in `devtron-ci` namespace)
- Build pod stuck: Kaniko pod pending, out of resources, node selector issues
- Deployment stuck in `Progressing`: ArgoCD health check failing, pod crash loop — diagnosis
- Image pull errors: Harbor auth failure, imagePullSecret not propagated — fix steps
- Rollback procedure: via UI, via API, via `kubectl rollout undo` as emergency fallback
- Pipeline not triggering on push: GitHub webhook misconfiguration, event filtering
- Devtron UI not loading: ingress issue, pod crash — `kubectl get pods -n devtroncd`
- Database issues: Devtron uses PostgreSQL (CloudNativePG) — connection errors, migration failures
- Resource limits: build pods OOMKilled — increasing limits in global config
- `argocd app` commands that work against Devtron's ArgoCD for emergency debugging

---

## Required Output Format

Structure your response using the following top-level `#` headers — one per tool — so the output can be split into two separate skill files:

```markdown
# ArgoCD

## Overview
[2-3 sentence description of what ArgoCD does and why we use it]

## CLI Reference
### Login and Authentication
[Commands with examples]
### App Management
[argocd app create/sync/diff/rollback with real examples]
### Project Management
[argocd proj commands]
### Repository Management
[argocd repo add for GitHub and Harbor OCI]

## Application Manifests
### Application CRD
[Full annotated YAML example]
### Helm Source
[Helm values, valueFiles, targetRevision examples]
### Kustomize Source
[Image overrides, overlay examples]
### Multi-Source Applications
[Helm chart from Harbor OCI + values from git — exact YAML]
### AppProject CRD
[Full example with RBAC]
### ApplicationSet
[Git generator and cluster generator examples]

## Sync Policies
### Auto-Sync Configuration
[prune, selfHeal, retry — with YAML]
### Sync Options Reference
[Each syncOption explained with when to use]
### Resource Hooks
[PreSync, PostSync examples]
### Ignore Differences
[ignoreDifferences for HPA-managed replicas, runtime fields]

## RBAC and SSO
### Zitadel OIDC Setup
[argocd-cm oidc.config block, Zitadel client config]
### RBAC Policy
[argocd-rbac-cm policy.csv examples]
### Group Mapping
[Zitadel groups -> ArgoCD roles]

## Notifications
### Rocket.Chat Integration
[Webhook config, trigger definitions, message templates]
### n8n Webhook Integration
[Sending ArgoCD events to n8n]
### Trigger Reference
[on-sync-failed, on-health-degraded examples]

## Repository Management
### GitHub Repos
[argocd repo add with SSH and HTTPS]
### Harbor OCI Registry
[OCI chart repo configuration]

## Health Checks
### Custom Lua Scripts
[CloudNativePG Cluster health check, Traefik IngressRoute health check]
### Health Check Reference
[Built-in resources and their health semantics]

## Secrets Integration
### External Secrets Operator Approach (Recommended)
[How ESO + OpenBao works with ArgoCD]
### ArgoCD Vault Plugin Approach
[AVP init container setup, annotation usage]
### SOPS+age with Helm
[Helm secrets plugin usage]

## Devtron Co-existence
[Architecture, namespace isolation, recommended split]

## Troubleshooting
### Sync Failures
[ComparisonError, SyncFailed — diagnosis steps]
### Health Issues
[Stuck Progressing, degraded health]
### Repo Server Errors
[Manifest generation failures, git errors]
### Common Commands for Debugging
[argocd app get --show-operation, argocd app diff, log locations]

## Monitoring
### Prometheus Metrics
[Key metrics, ServiceMonitor config]
### Grafana Dashboards
[Dashboard IDs, what to monitor]
### Alertmanager Rules
[Sync failure and health degraded alerts]

## Gotchas
[Things that break, anti-patterns, Devtron conflicts]

---

# Devtron

## Overview
[2-3 sentence description of what Devtron does and why we use it]

## API Reference
### Authentication
[Token generation, Bearer header usage]
### Triggering CI Builds
[API endpoint, payload, polling status]
### Triggering CD Deployments
[Promote image, rollback via API]
### Common API Patterns
[Scripting examples for automation]

## CI Pipeline Configuration
### Build Strategies
[Docker, Buildpack, Kaniko — config for each]
### Pre/Post CI Tasks
[Lint, test, Trivy scan setup]
### Webhook Triggers
[GitHub webhook setup, branch filters]
### Build Caching
[Kaniko layer cache with Harbor/MinIO]

## CD Pipeline Configuration
### Deployment Strategies
[Rolling, Blue-Green, Canary on K3s]
### Deployment Template Reference
[Key fields: image, resources, ingress, env vars]
### Pre/Post Deployment Tasks
[Migration hooks, smoke tests]
### Approval Gates
[Manual approval configuration]
### Rollback
[UI and API rollback procedures]

## Environment Management
### Environment Setup
[Namespace mapping, cluster config]
### Environment-Specific Config
[Per-env values override]
### Secret Injection
[External Secrets Operator in Devtron templates]

## Harbor Integration
### Registry Configuration
[Robot account setup, URL format, image naming]
### Pull Secrets
[imagePullSecret management for K3s pods]
### Image Scanning
[Trivy via Devtron vs Harbor built-in scanner]

## GitOps Mode vs Helm Mode
[Trade-offs, recommendation, ArgoCD internals]

## RBAC and SSO
### Zitadel OIDC Setup
[Global Config SSO, Zitadel client config, scopes]
### Permission Model
[super-admin, manager, trigger, view — explained]
### Group Mapping
[Zitadel roles -> Devtron permission groups]

## Chart Store
### Connecting Repositories
[Artifact Hub, Harbor OCI — config]
### Deploying a Chart
[Step-by-step with Harbor OCI chart]

## Global Configuration
### Container Registries
[Harbor robot account setup]
### Git Accounts
[GitHub PAT or GitHub App]
### Blob Storage
[MinIO connection for build artifacts]
### Notifications
[Rocket.Chat webhook, Postal SMTP]

## ArgoCD Co-existence
[Namespace isolation, naming conventions, recommended split]

## Troubleshooting
### Build Failures
[Log locations, Kaniko pod debugging]
### Deployment Stuck
[ArgoCD health check, pod crash loop diagnosis]
### Image Pull Errors
[Harbor auth, imagePullSecret propagation]
### Emergency Rollback
[kubectl rollout undo as fallback]
### Pod and Log Reference
[kubectl commands for devtroncd namespace]

## Gotchas
[Things that break, anti-patterns, ArgoCD conflicts]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual YAML manifests, actual API curl commands, actual Lua scripts, and actual kubectl debug commands. Do NOT give me theory — give me copy-paste-ready configs for ArgoCD and Devtron running on K3s behind Traefik with Zitadel SSO, Harbor OCI registry, Rocket.Chat notifications, and both tools co-existing on the same cluster without conflicts.
