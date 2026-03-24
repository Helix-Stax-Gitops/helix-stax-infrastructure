# Gemini Deep Research: Storage Chain (Grouped Prompt)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
The complete storage chain — on-cluster object storage (MinIO), container registry (Harbor), and offsite backup (Backblaze B2). This group covers three tightly-coupled layers that agents must understand together:

1. **MinIO** — our S3-compatible object storage running on K3s. Every service that needs object storage (Velero, Loki, Harbor, CloudNativePG WAL archives, general backups) talks to MinIO. It also replicates to Backblaze B2 for offsite durability.
2. **Harbor** — our self-hosted container registry on K3s. The single source of truth for all container images. Devtron pushes images after CI builds; ArgoCD pulls images for GitOps deployments. Uses MinIO for blob storage and CloudNativePG for its database.
3. **Backblaze B2** — offsite cold storage. MinIO replicates to B2 for disaster recovery. Zero egress cost between B2 and Cloudflare via the Bandwidth Alliance.

These three are grouped because Harbor depends on MinIO for blob storage, MinIO replicates to B2, and disaster recovery procedures span all three. Agents configuring Harbor must understand MinIO bucket setup; agents implementing backup must understand the MinIO→B2 replication chain.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, 2 nodes (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **MinIO**: Deployed on K3s via Helm (standalone single-node, not distributed); internal endpoint `http://minio.minio-system.svc.cluster.local:9000`, external via Traefik at `s3.helixstax.net`
- **Harbor**: Deployed via Helm on K3s; uses CloudNativePG (`harbor` database) and MinIO (`harbor` bucket)
- **Backblaze B2**: Offsite cold storage, S3-compatible API; Bandwidth Alliance partner with Cloudflare
- **TLS**: cert-manager + Traefik IngressRoute for MinIO Console/API and Harbor portal/registry
- **Identity**: Zitadel (OIDC SSO) — both MinIO Console and Harbor delegate login to Zitadel
- **CI/CD integration**: Devtron CI pushes images to Harbor; ArgoCD pulls from Harbor for GitOps
- **Image scanning**: Trivy built-in to Harbor
- **Monitoring**: Prometheus + Grafana + Loki already deployed
- **Secrets**: MinIO root credentials in OpenBao → External Secrets Operator → Kubernetes Secret

---

## What I Need Researched

---

# SECTION 1: MinIO (On-Cluster Object Storage)

### 1. CLI Reference: mc (MinIO Client) — Complete
- Authentication: `mc alias set myminio http://minio.helixstax.net ACCESS_KEY SECRET_KEY`, listing aliases, testing with `mc admin info myminio`
- Installing `mc` on AlmaLinux 9 and inside a K3s job/pod
- Bucket operations: `mc mb`, `mc rb` (remove bucket, `--force` for non-empty), `mc ls`, `mc du` (disk usage per bucket), `mc ls --recursive`
- Object operations: `mc cp`, `mc mv`, `mc rm` (with `--recursive`, `--older-than`, `--newer-than`), `mc cat`, `mc head`, `mc find`, `mc stat`
- Sync operations: `mc mirror` vs `mc sync` — differences, `--watch` mode, `--remove` flag (dangerous — understand before use), `--overwrite`
- Policy management: `mc policy set`, `mc policy get`, `mc policy list` — canned policies (`none`, `download`, `upload`, `public`) vs custom JSON
- Admin operations: `mc admin info`, `mc admin user`, `mc admin group`, `mc admin policy`, `mc admin service restart`, `mc admin trace`
- Bucket lifecycle: `mc ilm rule add`, `mc ilm rule ls`, `mc ilm rule rm`, `mc ilm export/import` — lifecycle rules in JSON
- Versioning: `mc version enable/suspend/info`, versioned object listing (`mc ls --versions`), deleting specific version, delete markers
- Object locking / WORM: `mc retention set`, `mc retention info`, GOVERNANCE vs COMPLIANCE mode — implications for backup buckets
- Encryption: SSE-S3 (MinIO-managed keys), SSE-C (client-provided keys), `mc encrypt set`, verifying encryption status
- Event notifications: `mc event add/remove/list` — configuring webhook notifications to n8n for object create/delete events
- Replication configuration: `mc replicate add`, `mc replicate ls`, `mc replicate rm`, `mc replicate status` — monitoring replication lag
- `mc support`: `mc support perf object` — bandwidth and latency testing, `mc support logs`
- `mc diff` — comparing two buckets or directories
- `mc admin accesskey create` — creating service account access keys
- `mc ping` — connectivity check to endpoint

### 2. Deployment on K3s: Standalone
- Why standalone (single-node) is appropriate for a 2-node K3s cluster — erasure coding requires 4+ drives
- Bitnami MinIO Helm chart vs MinIO Operator Helm chart — which to use for standalone, recommendation with chart name and repo
- Complete `values.yaml` for a production-ready standalone deployment
- `persistence.size` — how to size the PVC for Loki + Harbor + Velero + CloudNativePG WAL combined storage
- `persistence.storageClass` — Hetzner CSI driver StorageClass name
- `resources.requests` and `resources.limits` — starting values for a shared K3s node
- `mode: standalone` vs `mode: distributed` — confirming standalone config
- Exposing MinIO API and Console via Traefik IngressRoute with TLS — annotated YAML
- Internal service DNS: `minio.minio-system.svc.cluster.local` — API port 9000, Console port 9001
- `rootUser` and `rootPassword` — where to set, how to store in Kubernetes Secret via External Secrets Operator
- StatefulSet vs Deployment — which does the Bitnami chart use for standalone?
- Upgrading MinIO via Helm — rolling update behavior, data safety during upgrade
- Resource requests/limits: appropriate values for a standalone MinIO serving 5 services on a node

### 3. Bucket Design: Per-Service Buckets
- Recommended bucket layout for our setup:
  - `velero-backups` — Velero cluster backup data (WORM, versioning on)
  - `loki-chunks` — Loki log storage (no versioning, no B2 — high churn)
  - `harbor-blobs` — Harbor image blob storage (no expiry, Harbor GC manages)
  - `cnpg-wal` — CloudNativePG WAL archives (expire after 7 days)
  - `cnpg-backups` — CloudNativePG base backups (expire after 14 days)
  - `general` — miscellaneous uploads, temporary storage (expire after 90 days)
- Bucket naming constraints: lowercase, hyphens not underscores, DNS-compatible, impact on path-style vs virtual-hosted-style URLs
- Creating the required buckets: mc commands with flags for each bucket
- `mc mb --with-lock minio/velero-backups` — why object locking for Velero matters
- Bucket versioning: `mc version enable` — which buckets need versioning
- Bucket quotas: `mc admin bucket quota myminio/loki-chunks --hard 50GiB` — preventing one service from consuming all storage
- How to check what's taking the most space: `mc du --recursive minio/loki-chunks`

### 4. Access Policies: IAM Per Service Account
- MinIO IAM overview — users, groups, policies, service accounts (access keys)
- Creating a dedicated policy for each service:
  - **velero-policy**: `s3:*` on `arn:aws:s3:::velero-backups` and `arn:aws:s3:::velero-backups/*`
  - **loki-policy**: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on `loki-chunks`
  - **harbor-policy**: `s3:*` on `harbor-blobs` bucket
  - **cnpg-policy**: `s3:*` on `cnpg-wal` and `cnpg-backups` buckets
  - **backups-policy**: `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` on `general` bucket
- Policy JSON format — full example for each service
- Creating service accounts: `mc admin accesskey create` workflow
- Storing service account credentials in Kubernetes Secrets — naming conventions
- Read-only policy for monitoring/auditing
- Policy inheritance: attaching a policy to a group vs directly to a service account
- How to audit who has access to what: `mc admin policy list`, `mc admin accesskey list`
- Rotating access keys — creating new key, updating Kubernetes Secret, deleting old key without downtime

### 5. TLS: API and Console via Traefik
- MinIO TLS modes: `MINIO_SERVER_URL` and `MINIO_BROWSER_REDIRECT_URL` env vars
- cert-manager Certificate resource for MinIO — `dnsNames` including internal service name AND public hostname
- Traefik IngressRoute for MinIO API (port 9000) with TLS termination — annotated YAML
- Traefik IngressRoute for MinIO Console (port 9001) with TLS — annotated YAML
- Configuring MinIO to trust the internal CA (for Loki, Velero, Harbor, CloudNativePG connecting over TLS internally)
- `MINIO_SERVER_URL` — why it must match the TLS certificate CN
- Self-signed cert gotchas — how clients like `mc`, Loki, Harbor specify CA cert
- `mc alias set minio https://s3.helixstax.net --cacert /path/to/ca.crt` — CA trust for mc
- Renewing TLS certificates — cert-manager auto-renewal, MinIO hot-reload of certs without restart

### 6. Backup Strategy: MinIO → Backblaze B2
- Backblaze B2 S3-compatible API endpoint: `https://s3.us-west-004.backblazeb2.com` (check current region)
- Setting up `mc` alias for Backblaze B2: `mc alias set b2 https://s3.us-west-004.backblazeb2.com <keyID> <appKey>`
- **Option A: `mc mirror`** — cron job or continuous watch, pros, cons, failure modes
- **Option B: Bucket replication** — `mc replicate add` — asynchronous server-side replication, how to configure, monitoring replication lag
- Which buckets to replicate to B2: `velero-backups`, `cnpg-backups`, `cnpg-wal` (not `loki-chunks` — too large, not `harbor-blobs` — can rebuild from CI)
- Bucket Replication setup: enabling versioning (required for replication), creating replication rule pointing to B2
- Replication rule configuration: `--remote-bucket`, `--replicate delete,delete-marker,existing-objects`, `--priority`, `--bandwidth`
- Monitoring replication: `mc replicate status myminio/velero-backups`, what "pending" vs "failed" means
- Replication failure handling: `mc replicate reset` to force re-sync
- mc mirror as CronJob: Kubernetes CronJob YAML running `mc mirror --overwrite --remove`
- Verifying backup integrity: `mc diff myminio/velero-backups b2alias/helix-velero-backups`
- Bandwidth and cost: Hetzner → B2 egress (~€0.01/GB outbound from EU), minimizing with delta sync

### 7. Velero Integration: S3 Backend
- Velero BackupStorageLocation CRD spec for MinIO — `provider: aws`, `config.s3Url`, `config.region`, `config.s3ForcePathStyle: true`
- Kubernetes Secret format for Velero S3 credentials: `cloud` key with `[default]\naws_access_key_id=...\naws_secret_access_key=...`
- Full `BackupStorageLocation` YAML example pointing at MinIO
- `velero backup-location get` — verifying the BSL is available
- `velero backup create test-backup --storage-location minio` — ad-hoc backup
- `velero backup describe test-backup --details` — checking what was captured
- Velero backup schedule: `Schedule` CRD — daily backup, 30-day retention, pointing at MinIO BSL
- What Velero actually stores in MinIO: backup metadata, namespace manifests, volume data

### 8. Loki Integration: S3 Backend for Log Storage
- Loki `storage_config` for S3/MinIO: `aws.s3`, `aws.endpoint`, `aws.region`, `aws.access_key_id`, `aws.secret_access_key`, `aws.s3forcepathstyle: true`, `aws.insecure` (if no TLS internally)
- Full Loki `values.yaml` S3 storage section for the Loki Helm chart
- Required bucket for Loki: single `loki-chunks` bucket in single-store TSDB mode
- Loki chunk vs index storage — both to MinIO S3 in single-store TSDB mode
- How Loki handles MinIO unavailability — buffering, write-ahead log
- Compactor component: what it does to MinIO data, why it's important for storage reclamation
- `retention_period` for Loki — setting log retention to control MinIO bucket growth

### 9. CloudNativePG Integration: WAL Archiving Backend
- Full backup section in CloudNativePG Cluster CRD for S3/MinIO: `endpointURL`, `destinationPath`, `s3Credentials`
- How WAL archiving works — CloudNativePG automatically archives WAL segments to `cnpg-wal` bucket
- `ScheduledBackup` CRD for base backups to `cnpg-backups` bucket
- How to reference MinIO credentials as Kubernetes secrets in the Cluster spec
- Verifying CloudNativePG backups landed in MinIO: `mc ls minio/cnpg-backups/`, `barman-cloud-backup-list` from inside pod

### 10. Versioning and Lifecycle Strategy
- When to enable versioning: `velero-backups` and `cnpg-backups` (yes — accidental delete protection), `loki-chunks` (no — high churn)
- Lifecycle rule design per bucket:
  - `velero-backups`: expire objects older than 30 days, noncurrent versions after 7 days
  - `loki-chunks`: expire after 14 days (no versioning — Loki compactor manages)
  - `harbor-blobs`: no expiry (Harbor GC manages), versioning off
  - `cnpg-wal`: expire WAL after 7 days
  - `cnpg-backups`: expire base backups after 14 days
  - `general`: expire after 90 days, no versioning
- Lifecycle rule JSON structure: `Filter` (prefix, tags), `Expiration` (Days), `NoncurrentVersionExpiration`, `Transition` (Days, StorageClass)
- ILM Tier to B2: `mc admin tier add` — adding B2 as a remote tier for hot→cold tiering from MinIO
- WORM / Object Lock: GOVERNANCE mode vs COMPLIANCE mode, `mc retention set --default GOVERNANCE 30d myminio/velero-backups`

### 11. Monitoring: Prometheus Metrics and Grafana
- Enabling MinIO Prometheus metrics: MinIO exposes `/minio/v2/metrics/cluster` and `/minio/v2/metrics/node`
- Authentication for metrics endpoint: `MINIO_PROMETHEUS_AUTH_TYPE: public` vs JWT — which to use with Prometheus Operator
- ServiceMonitor or PodMonitor CRD for scraping MinIO metrics
- Key metrics to alert on:
  - `minio_cluster_capacity_usable_total_bytes` vs `minio_cluster_capacity_usable_free_bytes` — disk pressure
  - `minio_s3_requests_errors_total` — error rate
  - `minio_replication_pending_count` — replication lag to B2
  - `minio_node_disk_used_bytes` — per-node disk usage
  - `minio_node_process_uptime_seconds` — uptime (alert if restarted)
- MinIO official Grafana dashboard — dashboard ID 13502, import instructions
- Health check endpoints: `GET /minio/health/live` and `GET /minio/health/ready` — use for Kubernetes probes
- Audit logs: MinIO audit log to webhook (n8n), capturing all API operations for compliance

### 12. Troubleshooting MinIO
- Disk full: MinIO goes read-only — `mc admin info` shows low capacity, fix procedure
- `XMinioStorageFull` error — which clients emit it, triage steps
- Slow uploads from Harbor or Loki — diagnosis: `mc support perf` throughput test
- `AccessDenied` errors — policy misconfiguration debugging: `mc admin policy info minio <policyname>`
- `SignatureDoesNotMatch` — wrong secret key, clock skew (NTP on K3s nodes), wrong region
- CORS errors in MinIO Console — `MINIO_BROWSER_REDIRECT_URL` mismatch
- `mc alias set` fails with TLS error — CA cert not trusted, cert CN mismatch
- MinIO pod OOMKilled — memory limits too low
- Bucket replication stuck: `mc replicate status` showing backlog, causes and reset procedure
- Harbor push failing with `500 Internal Server Error` — MinIO connectivity from Harbor registry pod
- Loki ingestion failing — MinIO `403 Forbidden` on `loki-chunks` bucket, policy issue
- Velero backup `Partial Failure` — MinIO BSL unavailable, timeout, network policy blocking Velero pod
- `mc admin trace minio` — real-time request tracing, how to filter to a specific bucket

---

# SECTION 2: Harbor (Container Registry)

### 1. CLI and API Reference
- Harbor does not have an official CLI binary — options: `harbor-cli` (community), direct REST API, `docker` CLI against the registry
- `docker login harbor.helixstax.net` — authentication, credential storage
- `docker push harbor.helixstax.net/project/image:tag` — push syntax with Harbor project prefix
- `docker pull harbor.helixstax.net/project/image:tag` — pull syntax
- Harbor REST API v2.0 base URL: `https://harbor.helixstax.net/api/v2.0/`
- Key API endpoints:
  - `GET /projects` — list projects
  - `POST /projects` — create project
  - `GET /projects/{name}/repositories` — list repos in a project
  - `GET /projects/{name}/repositories/{repo}/artifacts` — list artifacts (images)
  - `DELETE /projects/{name}/repositories/{repo}/artifacts/{digest}` — delete image
  - `POST /robots` — create robot account (global or project-scoped)
  - `GET /replication/policies` — list replication rules
  - `POST /replication/executions` — trigger manual replication
  - `GET /system/gc` — garbage collection status
  - `POST /system/gc/schedule` — configure GC schedule
- API authentication: Basic auth with robot account credentials — `curl -u "robot$name:secret" -X GET https://harbor.helixstax.net/api/v2.0/projects`
- Helm OCI push/pull: `helm push chart.tgz oci://harbor.helixstax.net/charts/` and `helm pull oci://harbor.helixstax.net/charts/mychart --version 1.0.0`
- `helm registry login harbor.helixstax.net --username robot\$helm --password <token>`

### 2. Deployment on K3s: Helm Chart with CloudNativePG and MinIO
- Official Harbor Helm chart (`https://helm.goharbor.io`) vs Bitnami — recommendation, why official chart is preferred
- Complete `values.yaml` for production Harbor deployment with external PostgreSQL (CloudNativePG) and external MinIO (S3)
- `externalDatabase` section: `host`, `port`, `user`, `password`, `database` — pointing at CloudNativePG cluster service (`harbor-postgres-rw.harbor.svc.cluster.local`)
- `persistence.imageChartStorage.type: s3` — full S3 section pointing at MinIO (`harbor-blobs` bucket)
- Disabling Harbor's built-in database and Redis (using external CloudNativePG and Valkey)
- `redis.type: external` — pointing Harbor at Valkey for caching/job queues
- Harbor components on K3s: core, portal, jobservice, registry, trivy — which to enable, resource limits per component
- `harborAdminPassword` — where to set, how to reference from Kubernetes Secret
- Pre-deployment requirements: PostgreSQL `harbor` database and user must exist, MinIO `harbor-blobs` bucket must exist
- Traefik IngressRoute for Harbor: separate routes for portal (HTTPS) and registry (HTTPS on 443)
- TLS: cert-manager Certificate for `harbor.helixstax.net`, Traefik TLS termination

### 3. Project Management
- Harbor projects: the top-level namespace for images — `library/myimage` where `library` is the project
- Recommended project structure for Helix Stax:
  - `helix-stax` — all internal service images built by Devtron (private)
  - `proxy-dockerhub` — proxy cache for Docker Hub (rate limit mitigation)
  - `proxy-ghcr` — proxy cache for GHCR
  - `charts` — OCI Helm charts
  - `clients` — client-specific images (if any)
- Creating projects via API: `POST /projects` curl example
- `auto-scan` on push: enabling per-project so every pushed image is immediately scanned by Trivy
- `prevent vulnerable images from running` — severity threshold configuration per project
- Project-level quotas: storage quota per project to prevent one project from filling MinIO
- Tag immutability rules: preventing overwrite of `latest` or release tags
- Webhook per project — triggering n8n workflow on image push event (POST to n8n webhook URL)
- Proxy cache projects — creating proxy project for Docker Hub with authenticated upstream to avoid rate limits

### 4. Image Scanning: Trivy Integration
- Trivy adapter in Harbor — built-in since Harbor 2.x, no separate Trivy server needed
- `Scan on Push` toggle — enabling per project
- Trivy database update: `SCANNER_TRIVY_AUTO_UPDATE_DB: true` — how Harbor keeps Trivy CVE DB current
- Offline mode: if K3s has no direct internet access, how to pre-load Trivy DB
- Vulnerability report format: Critical / High / Medium / Low / Negligible / Unknown — which severities to block on
- `Block pulling of images with vulnerabilities above severity threshold` — configuration in project settings
- `allowlist` — per-project CVE allowlist for accepted false positives
- Viewing scan results via API: `GET /projects/{name}/repositories/{repo}/artifacts/{digest}/additions/vulnerabilities`
- Trivy scanning for Helm charts stored in Harbor OCI registry
- SBOM generation: Harbor + Trivy SBOM support

### 5. Replication: Proxying and Syncing
- **Pull-through proxy cache** (recommended over manual replication for public images):
  - Creating proxy projects for Docker Hub, GHCR, Quay.io
  - How pull-through works: first pull fetches from upstream and caches in Harbor
  - Authenticated upstreams: configuring Docker Hub credentials to avoid anonymous rate limits (100 pulls/6h)
- **Push replication** (sending images to another registry):
  - `Replication Policy`: `src_registry`, `dest_registry`, `dest_namespace`, `trigger`
  - Filter rules: replicate only specific tags
  - Manual trigger: `POST /replication/executions` with policy ID

### 6. Devtron Integration: CI Push Destination
- Configuring Harbor as a container registry in Devtron — `Global Configurations > Docker Registries`
- Devtron robot account: creating a Harbor robot account with push/pull to `helix-stax` project
- Devtron CI pipeline output: image name format `harbor.helixstax.net/helix-stax/appname:gitsha`
- Image tag strategy: `{git-commit-sha}` vs `{build-number}` vs semantic versioning — recommendation
- `ci-runner` service account: Kubernetes ServiceAccount for Devtron CI pods needing to push to Harbor
- `imagePullSecrets` referencing Harbor robot account credential for ArgoCD to pull

### 7. ArgoCD Integration: GitOps Pull Source
- Configuring Harbor as image registry in ArgoCD — `argocd-cm` ConfigMap vs `argocd secret` for private registry
- Creating a Kubernetes Secret for Harbor pull: `kubectl create secret docker-registry harbor-pull-secret --docker-server=harbor.helixstax.net --docker-username=robot\$argocd --docker-password=<token> -n <namespace>`
- Referencing `harbor-pull-secret` in pod specs and default service accounts
- ArgoCD Image Updater: watching Harbor for new image tags, auto-updating Git repo
- How ArgoCD handles Harbor self-signed certs: adding CA to ArgoCD config

### 8. OIDC: SSO with Zitadel
- Harbor OIDC configuration: `Administration > Configuration > Authentication` — set `Auth Mode: OIDC`
- Required Zitadel OIDC application settings:
  - Application type: Web
  - Redirect URI: `https://harbor.helixstax.net/c/oidc/callback`
  - Scopes: `openid`, `profile`, `email`, `groups`
- Harbor OIDC fields: `OIDC Provider Name`, `OIDC Endpoint` (Zitadel issuer URL), `OIDC Client ID`, `OIDC Client Secret`, `OIDC Scope`, `OIDC Verify Cert`
- `Auto Onboard` — automatically creating Harbor user on first OIDC login
- CLI login with OIDC: docker login doesn't work with OIDC — using Harbor CLI secret from `Settings > User Profile > CLI secret`
- Robot accounts bypass OIDC — always use username/password auth for robot accounts
- Troubleshooting OIDC: `invalid_client`, `redirect_uri_mismatch` — checklist

### 9. Robot Accounts: Per-Service Credentials
- System-level robot accounts vs project-level robot accounts — when to use each
- Creating project-scoped robot accounts:
  - `devtron-ci`: push + pull to `helix-stax` project only
  - `argocd-pull`: pull-only from `helix-stax` project
  - `helm-push`: push to `charts` project
- Robot account name format: `robot$projectname+accountname` — full name used for docker login
- Robot account token expiry: setting expiry date, rotating before expiry
- API to create robot account: `POST /robots` — full request body example
- Storing robot credentials in Kubernetes Secrets: `kubectl create secret docker-registry` one-liner per robot

### 10. Garbage Collection: Cleaning Up Old Images
- Harbor GC scope: removes untagged manifests and unreferenced blobs from MinIO `harbor-blobs` bucket
- GC schedule: configuring in `Administration > Garbage Collection` — cron expression
- `delete_untagged: true` — deleting manifests without any tag
- Running GC manually: `POST /system/gc/schedule` with `schedule: {type: Manual}`
- What GC does to MinIO: calls MinIO S3 API to delete blob objects — verify with `mc du minio/harbor-blobs` before and after
- Artifact retention policies: keeping only last N tags per repo, or tags matching pattern
- Tag retention vs GC: retention runs first (marks unused tags), GC runs second (deletes unreferenced blobs)

### 11. Helm Chart OCI Registry
- Harbor as OCI Helm chart repository (Harbor 2.0+ supports OCI natively)
- `charts` project setup, robot account with push permissions
- `helm push mychart-1.0.0.tgz oci://harbor.helixstax.net/charts`
- `helm pull oci://harbor.helixstax.net/charts/mychart --version 1.0.0`
- ArgoCD Helm OCI source: `repoURL: oci://harbor.helixstax.net/charts`, `chart: mychart`

### 12. Monitoring: Prometheus, Grafana, and Health Checks
- Harbor Prometheus metrics endpoint: `https://harbor.helixstax.net/metrics` — enable via `Administration > Configuration`
- ServiceMonitor CRD for Prometheus Operator to scrape Harbor metrics
- Key metrics:
  - `harbor_project_artifact_total` — image count per project
  - `harbor_artifact_pulled_total` — pull throughput
  - `harbor_artifact_pushed_total` — push throughput
  - `harbor_db_connection_pool_*` — PostgreSQL connection pool health
  - `harbor_jobservice_task_*` — background job queue health (replication, GC, scanning)
  - `harbor_quota_*` — storage quota utilization
- Harbor health endpoint: `GET /api/v2.0/health` — returns per-component health status (database, redis, storage, jobservice, portal, core, trivy)
- Kubernetes liveness probe: `GET /api/v2.0/ping`
- Kubernetes readiness probe: `GET /api/v2.0/health`
- Loki log queries for Harbor pod logs — detecting push failures, auth errors, scan failures

### 13. Security: Content Trust, RBAC, and Compliance
- **Cosign** (replaces Notary v1): signing images with Sigstore/Cosign, verifying signatures in Harbor
- `cosign sign --key cosign.key harbor.helixstax.net/helix-stax/myapp:v1.0.0`
- Harbor cosign integration: `Enforce content trust` project setting — blocks pulling unsigned images
- Kyverno policy to enforce only signed images from Harbor can run in K3s — example ClusterPolicy
- Harbor RBAC roles: `Project Admin`, `Maintainer`, `Developer`, `Guest` — what each can do
- Audit logging in Harbor: all API calls logged, LogQL query to find specific user actions
- Harbor core network policy: restrict Harbor pods to only talk to CloudNativePG, Valkey, MinIO, and Traefik

### 14. Troubleshooting: Push/Pull Failures, Auth, Storage
- `unauthorized: authentication required` on `docker push` — robot account credentials wrong or expired
- `denied: requested access to the resource is denied` — correct credentials but insufficient project permissions
- `unknown: unknown` on push — MinIO unreachable from Harbor registry pod
- `timeout` on image pull in K3s pods — Harbor overloaded, or `imagePullSecrets` missing
- Harbor `core` pod CrashLoopBackOff — database connection failure (CloudNativePG not ready)
- `jobservice` pod not processing scans — Trivy DB not updated, Valkey connection issue
- `413 Request Entity Too Large` — Traefik body size limit, add middleware annotation
- `503 Service Unavailable` from Harbor — all `registry` pods down, check Valkey connection
- Harbor GC stuck in `Running` — manual recovery via API
- `mc ls minio/harbor-blobs` shows no files after Harbor install — S3 config wrong, `s3.regionendpoint` must be internal MinIO service URL
- Checking Harbor database connectivity from inside the core pod: `psql -h $HARBOR_DB_HOST -U $HARBOR_DB_USERNAME -d $HARBOR_DB_NAME`

---

# SECTION 3: Backblaze B2 (Offsite Cold Storage)

### 1. Account Setup and Application Keys
- B2 application keys — master key vs application keys, creating per-bucket keys with limited permissions
- Application key scopes: `readFiles`, `writeFiles`, `deleteFiles`, `listBuckets`, `listFiles` — minimal permissions for MinIO replication (writeFiles + listFiles on target bucket)
- B2 bucket types: Public vs Private — always Private for backup buckets
- B2 bucket naming: matching MinIO bucket names or using prefixed names (helix-velero-backups, helix-cnpg-backups)
- Rotating B2 keys: procedure for key rotation without replication downtime — create new key, update MinIO alias, verify replication continues, delete old key

### 2. b2 CLI Reference
- `b2 authorize-account <applicationKeyId> <applicationKey>`
- `b2 ls b2://helix-velero-backups/`
- `b2 upload-file helix-velero-backups ./file.tar.gz remote/path/file.tar.gz`
- `b2 download-file-by-name helix-velero-backups remote/path/file.tar.gz ./local/file.tar.gz`
- `b2 sync /local/path b2://bucket/prefix/` — bidirectional sync
- `b2 get-bucket helix-velero-backups` — bucket info and settings
- `b2 delete-file-version` — deleting specific versions
- `b2 ls --versions b2://helix-velero-backups/` — listing all versions

### 3. S3-Compatible API
- B2 S3 API endpoint format: `https://s3.us-west-004.backblazeb2.com` (region varies — check your B2 account region)
- Authentication: AWS_ACCESS_KEY_ID = B2 key ID, AWS_SECRET_ACCESS_KEY = B2 application key
- mc alias for B2: `mc alias set b2 https://s3.us-west-004.backblazeb2.com KEY_ID APP_KEY`
- Using AWS CLI with B2: `aws s3 ls s3://helix-velero-backups --endpoint-url https://s3.us-west-004.backblazeb2.com`

### 4. Lifecycle Rules
- B2 lifecycle rules: keep only last N versions, hide (soft-delete) after N days, delete hidden files after N days — JSON rule structure
- Per-bucket config:
  - `helix-velero-backups`: keep 3 versions, delete hidden after 90 days
  - `helix-cnpg-backups`: keep 2 versions, delete hidden after 30 days
  - `helix-cnpg-wal`: keep 1 version, delete hidden after 14 days
- CORS configuration for B2: when needed (browser-direct upload)

### 5. Cloudflare Bandwidth Alliance
- How the Bandwidth Alliance works: B2 ↔ Cloudflare traffic is free — no egress charges between B2 and Cloudflare CDN nodes
- Practical implication: helixstax.com (behind Cloudflare) can serve assets from B2 with zero B2 download cost
- Setting up Cloudflare as CDN for B2 bucket: CNAME `cdn.helixstax.com → <bucket>.s3.us-west-004.backblazeb2.com`, Cloudflare caching rules
- B2 CORS headers required for Cloudflare CDN delivery
- What still costs money: Hetzner → B2 traffic (~€0.01/GB outbound) — not covered by Bandwidth Alliance (Hetzner is not a partner)

---

# SECTION 4: Storage Chain — Disaster Recovery

### Who Stores What Where (Full Matrix)
- Full matrix: service, MinIO bucket, B2 replica, retention period, recovery priority
- Velero backups: MinIO `velero-backups` (primary, WORM, 30 days) → B2 `helix-velero-backups` (replica, 90 days)
- Loki chunks: MinIO `loki-chunks` only (14-day retention, no B2 — acceptable log loss in DR)
- Harbor blobs: MinIO `harbor-blobs` only (images rebuilt from CI if lost — Harbor GC manages cleanup)
- CloudNativePG WAL: MinIO `cnpg-wal` (7-day WAL) → B2 replica; base backups MinIO `cnpg-backups` + B2
- General uploads: MinIO `general` only (90-day expiry, no B2 unless specifically needed)

### Restore Procedures
- **Scenario 1: Single object accidentally deleted from MinIO** — restore from versioned delete marker or from B2 via `mc cp`
- **Scenario 2: MinIO volume corrupted or lost** — rebuild MinIO from Helm, mount new Hetzner volume, restore critical buckets from B2 with `mc mirror b2alias/bucket myminio/bucket`
- **Scenario 3: Full cluster loss (both nodes gone)** — full restore sequence:
  1. Provision new nodes with OpenTofu + Ansible
  2. Bootstrap K3s
  3. Deploy MinIO via ArgoCD (or Helm directly)
  4. Restore MinIO data from B2: `mc mirror b2/helix-velero-backups myminio/velero-backups`
  5. Deploy Velero, point at MinIO
  6. Velero restore: `velero restore create --from-backup <latest>`
  7. Verify CloudNativePG cluster bootstraps from WAL archive in MinIO

### Restore Testing
- Monthly `mc diff` comparison between MinIO and B2 to verify replication completeness
- Quarterly restore drill restoring a Velero backup to a test namespace
- What "restore tested" means for each tier of data

### RTO / RPO
- RPO = replication lag to B2 (minutes for native replication, up to cron interval for mc mirror)
- RTO = 2-4 hours for full cluster restore on fresh hardware
- What degrades RTO: B2 egress speed (Hetzner→B2 bandwidth), CloudNativePG WAL replay time, Velero restore size

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
- Real configurations using our IPs (178.156.233.12, 138.201.131.157), domains (helixstax.com, helixstax.net), and service names
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
# MinIO

## Overview
[2-3 sentence description — on-cluster S3, consumers, relationship to B2 and Harbor]

## mc CLI Reference
### Authentication and Aliases
[alias setup, testing]
### Bucket Operations
[mb, rb, ls, du with examples]
### Object Operations
[cp, mv, rm, find, stat with examples]
### Sync and Mirror
[mc mirror flags, scheduling as K8s CronJob]
### Admin Operations
[info, user, policy, accesskey, service restart]
### Event Notifications
[webhook to n8n]
### Versioning and Object Lock
[version enable, retention set, GOVERNANCE vs COMPLIANCE]

## Deployment on K3s (Helm)
### Helm Chart and values.yaml
[Annotated values.yaml for production standalone]
### Traefik IngressRoute for API and Console
[Annotated YAML for both routes with TLS]
### Resource and Storage Sizing
[PVC sizing rationale, resource limits]

## Bucket Design
### Recommended Buckets per Service
[Table: bucket name -> service -> versioning -> locking -> quota -> B2 replica]
### Creating and Configuring Buckets
[mc commands for each bucket with flags]
### Bucket Quotas
[mc admin bucket quota examples]

## IAM: Per-Service Access Policies
### Policy Definitions
[Full JSON policy per service: velero, loki, harbor, cnpg, general]
### Creating Service Accounts
[mc admin accesskey create workflow]
### Kubernetes Secret Format
[How to store credentials for each service]
### Key Rotation Procedure
[Step-by-step without downtime]

## TLS Configuration
### cert-manager Certificate
[Certificate CRD YAML]
### Traefik IngressRoute with TLS
[Annotated YAML for API and Console]
### Client CA Trust
[How Loki, Velero, Harbor, CloudNativePG trust MinIO cert]

## Replication to Backblaze B2
### B2 Alias Setup
[mc alias set for B2]
### Native Bucket Replication
[mc replicate add — full example for velero and cnpg buckets, monitoring]
### mc mirror (CronJob Approach)
[Command, CronJob YAML, monitoring]
### Verifying Integrity
[mc diff, what to check]
### Restoring from B2
[mc cp commands for restore]

## Velero Integration
### BackupStorageLocation CRD
[Annotated YAML]
### Credentials Secret Format
[Kubernetes Secret YAML]
### Verification Commands
[velero backup-location get, velero backup create]

## Loki Integration
### Loki Helm values.yaml Storage Section
[Annotated S3 storage config]
### Bucket Structure
[What Loki creates in MinIO]
### Retention and Compactor
[How Loki cleans up MinIO storage]

## CloudNativePG Integration
### Backup Section in Cluster CRD
[Annotated YAML for MinIO as backup target]
### ScheduledBackup CRD
[Example with cron, retention]
### Verifying Backups
[mc ls and barman-cloud-backup-list commands]

## Versioning and Lifecycle
### Versioning Decision Per Bucket
[yes/no per bucket with rationale]
### Lifecycle Rules
[JSON structure, per-bucket config with mc ilm commands]
### ILM Tier to B2
[mc admin tier add, lifecycle Transition]

## Monitoring
### Enabling Prometheus Metrics
[MINIO_PROMETHEUS_AUTH_TYPE, ServiceMonitor YAML]
### Key Metrics Reference
[Table: metric -> meaning -> alert threshold]
### Grafana Dashboard
[Dashboard ID 13502 and import steps]
### Health Check Endpoints
[Kubernetes probe YAML using /minio/health/live]

## Troubleshooting
### Diagnostic Commands
[mc admin info, mc admin trace, mc support perf]
### Common Errors
[Error message -> cause -> fix table: XMinioStorageFull, AccessDenied, SignatureDoesNotMatch, TLS errors]
### Service-Specific Issues
[Harbor push failures, Loki ingestion errors, Velero backup failures, CloudNativePG WAL errors — per-service fix steps]
### Disk Full Recovery
[Step-by-step: identify, free space, bring MinIO back online]

# Harbor

## Overview
[2-3 sentence description — self-hosted registry, MinIO for blobs, CloudNativePG for DB, Zitadel for auth]

## CLI and API Reference
### Docker CLI Against Harbor
[Login, push, pull commands with Harbor project prefix]
### Harbor REST API
[Key endpoints with curl examples — projects, artifacts, robots, replication, GC]
### Helm OCI Operations
[helm push, helm pull, helm registry login]

## Deployment on K3s (Helm)
### Pre-Deployment Requirements
[CloudNativePG database setup, MinIO harbor-blobs bucket creation]
### Helm Chart and values.yaml
[Annotated values.yaml: external DB, external MinIO, external Valkey, Traefik ingress]
### Traefik IngressRoute
[Annotated YAML for portal and registry endpoints]
### Component Overview
[Table: component -> purpose -> resource recommendation]

## Project Management
### Recommended Project Structure
[Table: project name -> purpose -> visibility -> quota]
### Creating Projects via API
[curl example]
### Proxy Cache Projects
[Docker Hub, GHCR proxy setup with authenticated upstreams]
### Tag Immutability Rules
[Configuration for protecting release tags]
### Webhooks
[n8n integration via project webhook]

## Image Scanning (Trivy)
### Enabling Auto-Scan
[Per-project setting, API command]
### Vulnerability Thresholds
[Blocking policy per severity level]
### Viewing Scan Results
[API endpoint, UI navigation]
### CVE Allowlisting
[Per-project allowlist configuration]
### SBOM Generation
[How to enable and retrieve]

## Replication
### Pull-Through Proxy Cache
[Creating proxy endpoints for Docker Hub, GHCR, Quay.io — full config]
### Push Replication Policy
[Replication policy API example]
### Manual Replication Trigger
[API call to trigger execution, status check]

## Devtron Integration
### Registry Configuration in Devtron
[Step-by-step: where in Devtron UI, what fields to fill]
### Robot Account for Devtron CI
[Permissions, creation API call, credential storage]
### Image Tag Strategy
[Recommended tagging convention]
### imagePullSecrets Setup
[Kubernetes Secret creation for Devtron CI pods]

## ArgoCD Integration
### Registry Secret Configuration
[kubectl create secret docker-registry command]
### Default ServiceAccount imagePullSecrets
[How to set cluster-wide pull secret]
### ArgoCD Image Updater
[Config for Harbor as image source]
### Self-Signed Cert Handling
[Adding Harbor CA to ArgoCD]

## OIDC (Zitadel SSO)
### Zitadel Application Setup
[Required settings: redirect URIs, scopes, application type]
### Harbor OIDC Configuration
[UI fields with exact values]
### CLI Secret for docker login
[How to get and use the CLI secret with OIDC enabled]
### Group Mapping
[Zitadel group -> Harbor role mapping]
### Troubleshooting OIDC
[Common errors and fixes]

## Robot Accounts
### Per-Service Robot Accounts
[Table: robot name -> scope -> permissions -> used by]
### Creating Robot Accounts
[POST /robots API example]
### Kubernetes Secret Creation
[kubectl command per robot account]
### Token Rotation
[Procedure without service disruption]

## Garbage Collection
### GC Schedule Configuration
[Cron expression, UI/API setup]
### Manual GC Trigger
[API call]
### Retention Policy Setup
[Tag retention rules per project]
### GC + Retention Workflow
[Order of operations: retention first, GC second]
### Verifying Storage Reclaimed
[mc du before/after comparison on harbor-blobs]

## Helm OCI Registry
### Project Setup for Charts
[charts project creation, robot account]
### Push and Pull Workflow
[helm push, helm pull commands]
### ArgoCD OCI Source
[argocd Application spec with oci:// repoURL]

## Monitoring
### Enabling Prometheus Metrics
[HARBOR_METRICS config, ServiceMonitor YAML]
### Key Metrics Reference
[Table: metric -> meaning -> alert threshold]
### Grafana Dashboard
[Dashboard source and import steps]
### Health Endpoints
[/api/v2.0/ping and /api/v2.0/health — probe YAML]
### Loki Queries
[LogQL patterns for Harbor component errors]

## Security
### Cosign Image Signing
[cosign sign command, Harbor enforcement setting]
### Kyverno Policy for Signed Images
[ClusterPolicy YAML]
### RBAC Roles
[Table: role -> permissions]
### Audit Logging
[Enable verbose audit, useful LogQL queries]
### Network Policies
[Harbor pod network policy YAML]

## Troubleshooting
### Diagnostic Checklist
[kubectl commands, API health check, log queries]
### Common Errors
[Error message -> cause -> fix table]
### Push/Pull Failures
[401, 403, 413, 503 — per-error fix steps]
### Component-Level Issues
[core, jobservice, trivy, registry — crash causes and fixes]
### MinIO Connectivity Check
[mc ls command, checking from inside registry pod]

# Backblaze B2

## Overview
[2-3 sentence description — offsite cold storage, S3-compatible, Bandwidth Alliance with Cloudflare]

## Account Setup
### Application Keys
[master vs app keys, per-bucket scope, minimal permissions]
### Bucket Configuration
[private buckets, naming, per-bucket key creation]

## b2 CLI Reference
### Authentication
[authorize-account command]
### Bucket and Object Operations
[ls, upload, download, sync commands]
### Version Management
[listing versions, deleting versions]

## S3-Compatible API
### Endpoint Format
[region-specific endpoint, how to find your region]
### mc Alias for B2
[setup command]
### AWS CLI with B2
[--endpoint-url pattern]

## Lifecycle Rules
### Rule Structure
[JSON format for hide/delete lifecycle]
### Per-Bucket Config
[helix-velero-backups, helix-cnpg-backups, helix-cnpg-wal rules]

## Cloudflare Bandwidth Alliance
### How It Works
[zero egress B2 <-> Cloudflare]
### CDN Setup for B2 Assets
[CNAME, Cloudflare caching rules for helixstax.com static assets]
### What Costs Money Anyway
[Hetzner -> B2 egress, B2 API calls]

## Key Rotation
[procedure without replication downtime]

# Storage Chain — Disaster Recovery

## Who Stores What Where
[full matrix: service, MinIO bucket, B2 replica, retention, recovery priority]

## Restore Procedures
### Single Object Restore
[from versioning delete marker or B2]
### MinIO Volume Loss
[rebuild and restore from B2]
### Full Cluster Loss
[sequence: provision -> K3s -> MinIO -> Velero restore -> CloudNativePG WAL replay]

## Restore Testing
[monthly mc diff check, quarterly restore drill procedure]

## RTO / RPO
[realistic targets: RPO = replication lag, RTO = 2-4 hours, what degrades each]
```

Be thorough, opinionated, and practical. Include actual `mc` commands, actual `curl` API calls, actual Helm values, actual Kubernetes YAML, actual lifecycle rule JSON, and actual error messages with fixes. Do NOT give me theory — give me copy-paste-ready configs for MinIO standalone on K3s (Hetzner), Harbor on K3s backed by CloudNativePG and MinIO, and B2 as the offsite replication target. Explicitly call out cross-tool interactions: Harbor bucket creation in MinIO before Harbor deploy, CloudNativePG WAL backup to MinIO, MinIO→B2 replication chains. Devtron CI, ArgoCD, and Zitadel OIDC integration should be called out wherever relevant.
