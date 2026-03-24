# Gemini Deep Research: Backup & Disaster Recovery

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What Velero Is
Velero is our backup and disaster recovery solution for the K3s cluster. It backs up Kubernetes objects (manifests, configs, secrets) and persistent volumes, stores them in MinIO (on-cluster), which then replicates to Backblaze B2 (offsite). Velero enables us to restore individual namespaces, recover from accidental deletions, perform cluster migration between Hetzner nodes, and validate our DR posture through scheduled restore drills.

## Our Specific Setup
- **Deployment**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Backup storage (primary)**: MinIO on K3s — S3-compatible object storage, `velero` bucket
- **Backup storage (offsite)**: Backblaze B2 — MinIO replicates to B2 using `mc mirror` or B2's native S3-compatible API
- **Volume backup method**: Restic or Kopia file-level backup (CSI snapshots may not be available on Hetzner K3s with Longhorn or local-path)
- **Database**: CloudNativePG clusters — require pre-backup hooks for consistency before snapshot
- **Ingress**: No public exposure — Velero runs as in-cluster operator only
- **CI/CD**: ArgoCD manages Velero deployment; backup schedule CRDs are GitOps-managed
- **Monitoring**: Prometheus metrics from Velero, Grafana dashboard for backup status, Alertmanager for backup failures

## What I Need Researched

### 1. CLI Reference (velero)
- Installation: `velero install` command — full flags for MinIO (S3-compatible) backend: `--provider aws`, `--plugins velero/velero-plugin-for-aws`, `--bucket velero`, `--secret-file`, `--use-volume-snapshots false`, `--backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.minio.svc:9000`
- `velero backup create {name}` — all flags: `--include-namespaces`, `--exclude-namespaces`, `--include-resources`, `--exclude-resources`, `--label-selector`, `--snapshot-volumes`, `--volume-snapshot-locations`, `--ttl`, `--storage-location`, `--wait`
- `velero backup get` — list backups, status fields (phase, errors, warnings, started, completed, expires)
- `velero backup describe {name}` — reading backup details, included resources, hook results
- `velero backup logs {name}` — streaming backup logs for debugging
- `velero backup delete {name}` — deleting a backup and its storage artifacts
- `velero restore create --from-backup {name}` — restore flags: `--include-namespaces`, `--exclude-namespaces`, `--include-resources`, `--restore-volumes`, `--namespace-mappings`
- `velero restore get` and `velero restore describe {name}` — checking restore status
- `velero schedule create {name}` — schedule flags: `--schedule` (cron), all backup flags
- `velero schedule get`, `velero schedule describe`, `velero schedule delete`
- `velero backup-location get` — verify backup storage location connectivity
- `velero snapshot-location get` — volume snapshot locations
- `velero plugin get` — list installed plugins
- `velero version` — check client/server version compatibility
- `velero debug` — collecting diagnostics for support/troubleshooting
- Completion: bash/zsh completion setup

### 2. Deployment on K3s via Helm
- Helm chart: `vmware-tanzu/velero` — key values to override: `configuration.backupStorageLocation`, `configuration.volumeSnapshotLocation`, `initContainers` for AWS plugin, `credentials.secretContents`
- Full `values.yaml` for MinIO backend: provider, bucket, region, s3ForcePathStyle, s3Url pointing to MinIO ClusterIP service
- Credentials secret: `cloud` key format for AWS provider with MinIO credentials — exact format of the credentials file
- Restic vs Kopia: how to enable file-level volume backup via `--use-restic` (deprecated) or `--use-node-agent` with Kopia — which is current best practice
- Node agent DaemonSet: Velero deploys a node agent (formerly restic) DaemonSet — resource requests/limits, how it mounts host paths
- RBAC: ClusterRole and ClusterRoleBinding Velero needs — what permissions are required
- Namespace: deploy Velero in `velero` namespace — any cross-namespace RBAC considerations
- Velero server resource requests/limits: realistic values for our cluster size
- ArgoCD Application manifest: Velero Helm app with `values.yaml` in GitOps repo
- Plugin image versions: matching `velero-plugin-for-aws` version to Velero version — compatibility matrix
- Upgrading Velero: safe upgrade path — backup CRDs first, then upgrade

### 3. Backup Strategy: What to Back Up
- Namespace-level backups: back up each namespace independently vs cluster-wide single backup — trade-offs
- Recommended backup schedule per tier:
  - Critical namespaces (`zitadel`, `monitoring`, `n8n`, `rocketchat`, `outline`): every 6 hours, 7-day TTL
  - Platform namespaces (`traefik`, `cert-manager`, `argocd`, `devtron`): daily, 14-day TTL
  - Full cluster backup: weekly, 30-day TTL
- What Velero backs up from Kubernetes: all objects in selected namespaces — Deployments, StatefulSets, Services, ConfigMaps, Secrets, PVCs, CRDs, RBAC, etc.
- What Velero does NOT back up by default: etcd data, node-level config, data in PVs (unless volume backup enabled)
- Cluster-scoped resources: how to include ClusterRoles, ClusterRoleBindings, StorageClasses, IngressClasses, CRDs in backups — `--include-cluster-resources=true`
- Secrets: Velero backs up Kubernetes Secrets (base64 encoded in etcd) — but OpenBao-managed secrets need separate consideration since they may be injected at runtime
- CRD backup: backing up custom resource definitions AND their instances (e.g., CloudNativePG Cluster CRD + Cluster objects)
- Label-based backup: using labels to tag resources for targeted backups (`velero.io/backup-included: "true"`)

### 4. Scheduled Backups and Retention
- Schedule CRD: `kind: Schedule` — full manifest example with cron expression, backup spec embedded
- Cron expressions for our tiers: every 6 hours (`0 */6 * * *`), daily at 2AM UTC (`0 2 * * *`), weekly Sunday 3AM UTC (`0 3 * * 0`)
- TTL (time-to-live): `--ttl 168h0m0s` for 7 days, `--ttl 336h0m0s` for 14 days, `--ttl 720h0m0s` for 30 days
- Backup count vs TTL: Velero deletes based on TTL, not count — understanding expiration behavior
- Manual backup outside of schedule: `velero backup create manual-$(date +%Y%m%d) --from-schedule {schedule-name}`
- Pausing a schedule: no direct pause — workaround (delete and recreate, or label manipulation)
- Backup phases: New -> InProgress -> Completed / Failed / PartiallyFailed — what each means
- Concurrent backup limits: can two schedules run at the same time? Any locking behavior?

### 5. Storage Locations: MinIO and Backblaze B2
- BackupStorageLocation CRD: full manifest for MinIO — `provider: aws`, `objectStorage.bucket`, `config.region`, `config.s3ForcePathStyle`, `config.s3Url`
- MinIO bucket setup: creating the `velero` bucket in MinIO, required permissions for the Velero IAM user (GetObject, PutObject, DeleteObject, ListBucket, GetBucketLocation)
- MinIO IAM policy for Velero: exact policy JSON
- Multiple backup storage locations: defining both MinIO (primary) and Backblaze B2 (secondary) as separate BackupStorageLocations
- BackupStorageLocation for Backblaze B2: B2 has S3-compatible API — endpoint URL, bucket naming, credential format
- Replication strategy: MinIO -> Backblaze B2 via `mc mirror --watch` vs B2's native replication vs Velero writing to both simultaneously
- `mc mirror` setup: MinIO Client command to continuously mirror `velero` bucket from MinIO to B2 — running as a CronJob on K3s
- Velero's `--storage-location` flag: using it to write a backup to a specific location (e.g., critical backup always goes to both MinIO and B2)
- Backup storage location availability check: `velero backup-location get` — Phase: Available vs Unavailable

### 6. Volume Snapshots: Restic/Kopia File-Level Backups
- Why CSI snapshots may not work on K3s with local-path provisioner: no VolumeSnapshotClass available — Restic/Kopia is the fallback
- Enabling Kopia (node agent): `--use-node-agent` flag, what the node agent DaemonSet does
- Annotating PVCs for backup: `backup.velero.io/backup-volumes: {pvc-name}` annotation on the Pod spec
- Annotating PVCs to OPT OUT: `backup.velero.io/backup-volumes-excludes: {pvc-name}` — for PVCs that should NOT be backed up (e.g., tmp volumes)
- How Kopia/Restic backs up: mounts the PVC on the node, streams data to object storage
- Backup performance: impact on running workloads during backup — I/O impact, CPU, network
- Large PVC backup: handling databases (CloudNativePG) — do NOT rely on Kopia for DB consistency; use hooks instead
- Restore of volumes: how Velero restores PVC data — creates PVC then populates from backup
- Verifying volume backup included: `velero backup describe {name}` shows `Restic Backups` or `CSI Volume Snapshots` section

### 7. Restore Procedures
- Full namespace restore: `velero restore create --from-backup {name} --include-namespaces {ns}` — what happens step by step
- Partial restore (single resource): `velero restore create --from-backup {name} --include-resources deployments --include-namespaces {ns}`
- Restore to a different namespace: `--namespace-mappings source-ns:target-ns` flag — use case for testing restores without affecting production
- Restore with label selector: restoring only resources with specific labels
- Checking restore status: `velero restore describe {name}` — warnings vs errors, partial failures
- Post-restore validation: what to check after a restore completes (pod status, service connectivity, DB data)
- Restoring cluster-scoped resources: `--include-cluster-resources=true` — CRDs, ClusterRoles
- Overwriting existing resources: `--existing-resource-policy none` (skip existing) vs `update` (overwrite) — default behavior and override
- Restoring from a different MinIO instance: changing BackupStorageLocation to point at Backblaze B2 for disaster recovery

### 8. Disaster Recovery: Full Cluster Rebuild
- Scenario: heart control plane is destroyed, helix-worker-1 is still running
- Step 1: Provision new Hetzner VPS, re-install K3s (connect to existing worker)
- Step 2: Install Velero and point it at Backblaze B2 BackupStorageLocation (since on-cluster MinIO is gone)
- Step 3: `velero backup get` — listing available backups from B2
- Step 4: Restore cluster-scoped resources first (CRDs, ClusterRoles, StorageClasses)
- Step 5: Restore namespaces in dependency order (cert-manager -> traefik -> zitadel -> monitoring -> apps)
- Step 6: Validate each namespace before restoring dependent namespaces
- RTO target: realistic time estimate for full cluster restore from B2 at our scale
- RPO target: with 6-hour backups, maximum data loss is 6 hours — what data is NOT covered (DB writes since last backup)
- Documenting the DR runbook: what the actual runbook should contain (step-by-step with velero commands)
- Runbook location: this DR runbook should live in Outline (our knowledge base)

### 9. Hooks: Pre/Post Backup for Database Consistency
- Hook types: `pre` (before backup) and `post` (after backup) — run as exec commands inside containers
- Hook annotation on Pod: `pre.hook.backup.velero.io/command`, `pre.hook.backup.velero.io/container`, `pre.hook.backup.velero.io/on-error`
- Hook configuration in backup spec (`Backup` CRD `spec.hooks`): resource hooks with label selector
- **CloudNativePG pre-backup hook**: how to trigger a CNPG consistent checkpoint before Velero snapshots the PVC — `kubectl cnpg backup {cluster-name}` or CNPG's own backup API — does Velero hook into CNPG backups or work alongside them?
- CNPG's own backup mechanism: CNPG has built-in WAL archiving and base backup to object storage — does Velero replace this or complement it?
- Recommended approach for CloudNativePG: use CNPG's native backup to MinIO/B2 for database-consistent backups; use Velero for everything else (K8s objects + non-DB PVCs)
- Hook for Valkey: `BGSAVE` command to trigger a memory snapshot before backup — `redis-cli -a {password} BGSAVE`
- Hook timeout: `pre.hook.backup.velero.io/timeout` — how long to wait for hook to complete
- Hook failure behavior: `Fail` vs `Continue` on hook error — recommendation for critical databases

### 10. Monitoring, Testing, and Troubleshooting
- Prometheus metrics: Velero exposes metrics at `/metrics` on port 8085 — enabling and scraping
- Key Velero metrics: `velero_backup_success_total`, `velero_backup_failure_total`, `velero_backup_partial_failure_total`, `velero_backup_duration_seconds`, `velero_backup_items_total`, `velero_restore_success_total`, `velero_restore_failed_total`, `velero_backup_last_successful_timestamp`
- Grafana dashboard: community dashboard ID for Velero — or building custom panels from the metrics above
- Alerting rules: PrometheusRule for backup failure (`velero_backup_failure_total > 0`), backup not completed in expected window, restore failure
- DR drill schedule: how to run a monthly restore drill — restore to test namespace, validate, then clean up
- Backup validation: `velero backup describe` + `velero restore create --from-backup {name} --namespace-mappings prod-ns:test-ns` pattern
- Troubleshooting backup stuck in `InProgress`:
  - Check node agent (Restic/Kopia) logs: `kubectl logs -n velero -l name=node-agent`
  - Check Velero server logs: `kubectl logs -n velero deploy/velero`
  - Common cause: node agent can't access the PVC mount path
- Troubleshooting partial backup failures: reading `velero backup describe` errors section, understanding which resources failed
- Troubleshooting MinIO connectivity: `velero backup-location get` shows Unavailable — network policy, MinIO credentials, bucket existence
- Troubleshooting restore conflict: resource already exists — `--existing-resource-policy update` or pre-delete
- Migration use case: using Velero to migrate a namespace from old cluster to new cluster — step-by-step

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
