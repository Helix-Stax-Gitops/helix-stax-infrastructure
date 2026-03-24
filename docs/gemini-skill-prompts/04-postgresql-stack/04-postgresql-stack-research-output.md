Of course. Here is the comprehensive research document for the PostgreSQL stack, tailored for your Helix Stax AI agents. The output is structured according to your progressive disclosure format (`SKILL.md`, `reference.md`, `examples.md`) for each of the three tools.

# CloudNativePG (Operator + K8s Layer)

## SKILL.md Content
Core reference for daily AI agent operations.

### 1. Cluster Provisioning & Status
**Bootstrap a New Production Cluster:**
```bash
# See full YAML in examples.md
kubectl apply -f postgres-cluster-helix-stax.yaml
```

**Check Cluster Status:**
```bash
# High-level status, endpoints, instances
kubectl get cluster
kubectl cnpg status helix-stax-cluster

# Detailed pod status
kubectl get pods -l cnpg.io/cluster=helix-stax-cluster -o wide
```

**Connect to Primary with psql:**
```bash
# Get primary pod name
PRIMARY_POD=$(kubectl get pod -l cnpg.io/cluster=helix-stax-cluster,cnpg.io/role=primary -o jsonpath='{.items[0].metadata.name}')

# Exec in and connect
kubectl exec -it ${PRIMARY_POD} -c postgres -- psql
```

### 2. Common Operations (`kubectl cnpg`)
**Force a Switchover (Graceful Failover):**
```bash
# Promote a replica to primary
kubectl cnpg promote helix-stax-cluster
```

**Trigger an Immediate Backup:**
```bash
# Create a one-off backup to MinIO
kubectl cnpg backup helix-stax-cluster --immediate
```

**Reload/Restart the Cluster:**
```bash
# Reload config (postgresql.parameters) without restart
kubectl cnpg reload helix-stax-cluster

# Restart all pods in a rolling fashion (e.g., after image update)
# Setting the annotation triggers a rolling update.
kubectl annotate cluster helix-stax-cluster cnpg.io/restartedAt=$(date)
```

**Enable/Disable Maintenance Mode:**
```bash
# Set maintenance mode ON (disables automatic failover)
kubectl cnpg maintenance helix-stax-cluster --set

# Set maintenance mode OFF (enables automatic failover)
kubectl cnpg maintenance helix-stax-cluster --unset
```

### 3. Configuration Snippets (Cluster CRD)
**Set PostgreSQL Parameters:**
```yaml
spec:
  postgresql:
    parameters:
      shared_buffers: "2GB"
      work_mem: "32MB"
      max_connections: "100"
      random_page_cost: "1.1" # For network-attached SSDs
      pg_stat_statements.track: "all"
      auto_explain.log_min_duration: "500ms"
      log_statement: "ddl"
```

**Add a New Database and User:**
```yaml
spec:
  managed:
    databases:
      - name: n8n
      - name: backstage
    roles:
      - name: n8n_user
        passwordSecret:
          name: n8n-db-password # K8s secret you create
        # Verify managed.roles schema against your CNPG operator version — the privileges format varies between versions
        privileges:
          - type: database
            object: "n8n"
            grant: ALL PRIVILEGES
```

**Pin Primary/Replica to Different Nodes:**
```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: cnpg.io/cluster
            operator: In
            values:
            - helix-stax-cluster
        topologyKey: "kubernetes.io/hostname"
```

### 4. Troubleshooting Decision Tree
| Symptom                               | Probable Cause                                           | Fix Command / Check                                             |
| ------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------- |
| Pod in `CrashLoopBackOff`             | Bad `postgresql.parameters` config OR PVC not bound. OR Certs invalid.    | `kubectl logs <pod-name> -c cloudnative-pg` for config error.<br>`kubectl describe pvc <pvc-name>` for storage issues. |
| WAL Archiving failure (`archive_fails` > 0 in `cnpg status`) | MinIO unreachable / wrong credentials.                   | `kubectl logs <pod-name> -c postgres` and look for `barman` errors.<br>Check S3 secret & MinIO endpoint URL. |
| Replication lag increasing (`Replication lag` > 1s in `cnpg status`) | Network issue between nodes OR replica is overloaded. | `kubectl exec <replica-pod> -- pg_stat_wal_receiver`.<br>Check node CPU/IO on worker `5.78.145.30` (helix-stax-vps). |
| `FATAL: sorry, too many clients`      | `max_connections` exhausted on PostgreSQL primary.     | Apps must connect to PgBouncer pooler service. Verify app connection strings. Check `Pooler` CRD config. |
| Restore from backup fails             | `externalClusters` spec is wrong OR MinIO credentials issue. | `kubectl describe cluster <new-cluster-name>` for events. Check logs of the new cluster's init pod. |
| PVC resize stuck in `Pending`         | Hetzner CSI controller has an issue OR StorageClass `allowVolumeExpansion` is false. | `kubectl describe pvc <pvc-name>`. Check logs of `csi-hcloud-controller` pod. |

---

## reference.md Content
Deep specifications and advanced patterns.

### 1. Cluster CRD Reference (Key Fields)
| Field Path                                | Description                                                                                                                              | Example Value                       |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `spec.instances`                          | Number of PostgreSQL instances (pods) in the cluster. Always >= 1. For HA, use >= 2.                                                   | `2`                                 |
| `spec.primaryUpdateStrategy`              | How to handle pod updates for the primary. `unsupervised` (default) is a rolling update, `supervised` requires manual switchover.          | `unsupervised`                      |
| `spec.primaryUpdateMethod`                | During rolling updates, how to demote the primary. `switchover` is graceful (default), `restart` is faster but causes brief downtime.      | `switchover`                        |
| `spec.postgresql.parameters`              | A map of key-value pairs to set in `postgresql.conf`.                                                                                    | `shared_buffers: "2GB"`             |
| `spec.affinity.nodeAffinity`              | Constrains pods to nodes with specific labels.                                                                                           | (see examples.md)                   |
| `spec.affinity.podAntiAffinity`           | Ensures pods (e.g., primary and replica) don't run on the same node. Crucial for HA on 2 nodes.                                           | (see examples.md)                   |
| `spec.topologySpreadConstraints`          | A more flexible way to spread pods across failure domains (nodes, zones). Good for >2 nodes.                                              | (see examples.md)                   |
| `spec.bootstrap.initdb`                   | Bootstraps a brand new, empty cluster.                                                                                                   | (see examples.md)                   |
| `spec.bootstrap.recovery`                 | Bootstraps a cluster by recovering from a backup. `source` points to an `externalClusters` entry.                                          | (see examples.md for PITR)          |
| `spec.superuserSecret`                    | K8s Secret containing the `postgres` superuser password. Operator will create it if not specified.                                         | `{name: postgres-superuser-secret}`         |
| `spec.enableSuperuserAccess`              | If `false` (recommended for production), superuser access is disabled over the network. Access via `kubectl exec` still works. | `false`                             |
| `spec.inheritedMetadata`                  | Propagates labels and annotations from the Cluster CRD to child resources (Pods, PVCs, Services).                                        | `{labels: {app: my-db}}`            |
| `spec.minSyncReplicas` / `maxSyncReplicas`  | Controls synchronous replication. On 2 nodes, `min: 1`, `max: 1` ensures commits are written to the replica before returning success. Durability++. | `minSyncReplicas: 1`                |
| `spec.walStorage`                         | Defines a separate PVC for WAL files. Recommended for write-heavy workloads to separate I/O.                                           | `{size: 10Gi}`                      |
| `spec.storage.size` / `storage.storageClass` | Main data volume size and the `StorageClass` name to use. Must match your CSI provisioner.                                              | `size: "50Gi"`<br>`storageClass: "hcloud-volumes"` |

### 2. Database and User Management
-   **`managed.databases`**: Defines databases the operator should create. `owner` specifies the role that owns the database.
-   **`managed.roles`**: Defines roles (users). Operator creates the role and manages its password via a K8s secret.
    -   `passwordSecret`: Reference to a K8s `Secret` with a `password` key. The operator will read the password from here. If the secret doesn't exist, the operator creates it with a random password.
    -   `privileges`: Grants permissions. `type: database` and `object: "dbname"` are common. `grant: ALL PRIVILEGES` is broad; for read-only users, use `grant: CONNECT, TEMPORARY` on the database and `grant: SELECT` on tables in a schema.
-   **`kubectl exec` vs Operator Pod**: `kubectl exec -it <primary-pod> -- psql` is the standard way to get a shell. The operator pod itself does not contain `psql`.
-   **Schema vs Database**: For your listed services, separate databases (`managed.databases`) is the cleanest approach. It provides strong isolation for credentials, connection limits, and backups. Schema separation inside a single DB is more for multi-tenancy within a single application. **Recommendation:** Use separate databases.

### 3. Connection Pooling (`Pooler` CRD)
| Field Path                  | Description                                                                                                    | Recommended Value for Helix Stax Services                                  |
| --------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `spec.cluster.name`         | The `Cluster` this pooler connects to.                                                                           | `helix-stax-cluster`                                                       |
| `spec.type`                 | The only supported type is `rw` for read-write pooling.                                                        | `rw`                                                                       |
| `spec.instances`            | Number of PgBouncer pods. `1` is sufficient for your scale, but `2` provides HA for the pooler itself.             | `2`                                                                        |
| `spec.pgbouncer.poolMode`   | `transaction` (default, safe), `session` (high performance, careful with transactions), `statement` (breaks most apps). | `transaction` for Zitadel, n8n, Backstage, Harbor, etc. It's the safest bet. |
| `spec.pgbouncer.parameters` | A map to configure `pgbouncer.ini`.                                                                            | `max_client_conn: "1000"`<br>`default_pool_size: "20"`                      |
| `spec.authQuerySecret`      | Secret containing the SQL query PgBouncer uses to look up user passwords. **CloudNativePG manages this automatically.** Do not set. | (not set)                                                                  |

**Connection Routing**: Applications (Zitadel, n8n) should **always** connect to the `Pooler`'s service name (e.g., `helix-stax-cluster-pooler`). Monitoring tools or direct DBA access can use the `Cluster`'s read-write service (e.g., `helix-stax-cluster-rw`). The `-rw` service bypasses the pooler.

### 4. Backup & Recovery Deep Dive
-   **WAL Archiving**: CNPG automatically configures `archive_mode='on'` and `archive_command` to use `barman-cloud-wal-archive`. It streams WAL files to your MinIO bucket as they are generated.
-   **`ScheduledBackup` CRD**: Defines a cron schedule for base backups. `backupOwnerReference: self` ensures the backup objects are deleted if the `ScheduledBackup` object is deleted. `immediate: true` triggers a one-time backup.
-   **Retention**: `retentionPolicy: "7d"` will instruct Barman to keep a full week of WAL files and any base backups required to recover to any point within that week.
-   **Verification**: Inside any Postgres pod, run `barman-cloud-backup-list s3://minio/backups/helix-stax-cluster` to see the catalog of available backups.
-   **`recoveryTarget`**: In the `bootstrap.recovery` spec, this defines the Point-in-Time Recovery (PITR) goal.
    -   `targetTime`: "YYYY-MM-DD HH:MM:SS.ffffffZ"
    -   `targetXID`: A transaction ID.
    -   `targetName`: A named restore point created with `pg_create_restore_point()`.
    -   `targetLSN`: A specific WAL Log Sequence Number.
-   **Testing Backups**: The safest way is to restore to a new cluster in parallel. Create a new `Cluster` manifest (`helix-stax-cluster-test-restore`) with a `bootstrap.recovery` section pointing to the production backup path in MinIO. This validates the backup integrity without affecting production.

### 5. High Availability & Fencing
-   **Automatic Failover**: The operator's controller manager watches the health of the primary pod. If unresponsive, it "fences" the old primary (shuts it down, prevents it from rejoining as a master) to prevent split-brain. Then, it promotes the healthiest replica. It updates the `-rw` Kubernetes `Service` to point to the new primary's IP. Applications connected to the service endpoint will be automatically re-routed.
-   **Fencing**: An automated safety mechanism. You can manually fence instances via annotations for maintenance: `kubectl annotate pod/<name> cnpg.io/fenced=""`. To un-fence: `kubectl annotate pod/<name> cnpg.io/fenced-`.
-   **Pod Disruption Budgets (PDBs)**: Yes, CloudNativePG automatically creates a PDB for each cluster, ensuring that voluntary disruptions (like node drains) do not take down a majority of instances at once. The default is `minAvailable: 1`.

### 6. Monitoring Configuration
-   **`monitoring.enablePodMonitor: true`**: Creates a `PodMonitor` CRD, which the Prometheus Operator uses to discover and scrape the `/metrics` endpoint on each PostgreSQL pod.
-   **`pg_stat_statements`**: Enable via `shared_preload_libraries: 'pg_stat_statements'` and `pg_stat_statements.track: 'all'` in `postgresql.parameters`.
-   **Official Dashboard**: Grafana dashboard ID **455** (legacy — verify current ID). The official CloudNativePG dashboard may be ID 20417 or search grafana.com for "CloudNativePG".
-   **Key Metrics for Alerting**:
    -   `cnpg_collector_up`: Is the exporter running? `up != 1`
    -   `cnpg_pg_is_in_recovery`: Has a failover occurred? `changes(cnpg_pg_is_in_recovery[5m]) > 0`
    -   `cnpg_pg_replication_lag`: `cnpg_pg_replication_lag > 10` (bytes)
    -   `cnpg_backup_last_failed`: `cnpg_backup_last_failed != 0`
    -   `cnpg_wal_archive_fails_total`: `rate(cnpg_wal_archive_fails_total[5m]) > 0`

### 7. Storage Management (Hetzner CSI)
-   `ReclaimPolicy: Retain` is **critical** for database PVCs. If set to `Delete`, deleting the `Cluster` CRD or a PVC object will cause the CSI driver to delete the underlying cloud volume, resulting in data loss. `Retain` ensures the volume persists, allowing you to re-attach it later.
-   **Volume Expansion**:
    1.  Ensure the `hcloud-volumes` `StorageClass` has `allowVolumeExpansion: true`.
    2.  Edit the `Cluster` CRD's `spec.storage.size` to the new, larger value (e.g., `"75Gi"`).
    3.  The operator will not apply this change directly. You must manually edit each PVC object: `kubectl edit pvc <pvc-name>` and update `spec.resources.requests.storage` to the new size.
    4.  The operator will then perform a rolling restart of the cluster, and on startup, PostgreSQL will see the larger filesystem. This process has zero downtime.

### 8. Upgrades
-   **Minor (e.g., 16.2 -> 16.3)**: Simply update `spec.imageName` in the `Cluster` CRD to the new tag. The operator performs a rolling update. The `primaryUpdateMethod: switchover` ensures zero downtime for connected clients.
-   **Major (e.g., 15 -> 16)**: The safest method is using the `pg_upgrade` plugin introduced in CNPG 1.21.
    1. Create a `ScheduledBackup` and wait for it to complete.
    2. Update the `imageName` to the new major version (e.g., `ghcr.io/cloudnative-pg/postgresql:16.x`).
    3. The operator will detect the major version change, create a new temporary cluster with `pg_upgrade`, and then switch over.
    *Alternative (manual clone)*:
    1.  Clone the production cluster: `kubectl cnpg clone <new-cluster-name> <source-cluster-name>`.
    2.  Once cloned and running, upgrade the *new* cluster's `imageName` to the new major version.
    3.  Test the upgraded clone.
    4.  During a maintenance window, switch application traffic to the new cluster.

---

## examples.md Content
Copy-paste-ready manifests for the Helix Stax environment.

### Production Cluster `cluster.yaml`
```yaml
# postgres-cluster-helix-stax.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: helix-stax-cluster
  namespace: database
spec:
  # --- Cluster Size and Availability ---
  instances: 2 # One primary, one replica for 2-node K3s cluster
  minSyncReplicas: 1 # Ensure writes are confirmed on the replica before returning success (synchronous commit)
  maxSyncReplicas: 1

  # --- Scheduling on helix-stax-cp (CP) and helix-stax-vps (worker) ---
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: cnpg.io/cluster
            operator: In
            values:
            - helix-stax-cluster
        topologyKey: "kubernetes.io/hostname"

  # --- PostgreSQL Version and Configuration ---
  # Standard CNPG images do NOT include pgvector. Use ghcr.io/tensorchord/cloudnative-pgvecto.rs or build a custom image with pgvector extension.
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2

  postgresql:
    parameters:
      # Memory (for 8GB RAM nodes)
      shared_buffers: "2GB"
      effective_cache_size: "6GB"
      maintenance_work_mem: "512MB"
      work_mem: "32MB"
      # Connections (for use with PgBouncer)
      max_connections: "100"
      # Performance & Tuning
      random_page_cost: "1.1" # For network attached SSDs like Hetzner
      checkpoint_completion_target: "0.9"
      # Logging & Monitoring
      log_destination: "stderr" # Required for Loki
      logging_collector: "on"
      log_min_duration_statement: "1000" # Log queries longer than 1s
      log_checkpoints: "on"
      log_lock_waits: "on"
      pg_stat_statements.track: "all"
      # Security Audit
      pgaudit.log: "read, ddl"
    shared_preload_libraries:
      - "pg_stat_statements"
      - "pgaudit"

  # --- Storage Configuration (Hetzner CSI) ---
  storage:
    storageClass: "hcloud-volumes" # Hetzner CSI StorageClass
    size: "50Gi"
  # Optional: Separate WAL disk for high-write workloads
  # walStorage:
  #   storageClass: "hcloud-volumes"
  #   size: "10Gi"

  # --- Backup to MinIO on K3s ---
  backup:
    target: "primary"
    barmanObjectStore:
      destinationPath: "s3://backups/helix-stax-cluster/" # Your bucket and path
      endpointURL: "http://minio.minio.svc.cluster.local:9000" # MinIO service endpoint
      s3Credentials:
        accessKeyId:
          name: minio-creds
          key: accessKey
        secretAccessKey:
          name: minio-creds
          key: secretKey
      wal:
        compression: "gzip"

  # --- User and Database Management ---
  managed:
    databases:
      - name: zitadel
        owner: zitadel_user
      - name: n8n
        owner: n8n_user
      - name: backstage
        owner: backstage_user
      - name: outline
        owner: outline_user
      - name: devtron
        owner: devtron_user
      - name: harbor
        owner: harbor_core
      - name: harbor_notary
        owner: harbor_notary
      - name: grafana
        owner: grafana_user
    roles:
      - name: zitadel_user
        passwordSecret:
          name: zitadel-db-secret
          key: password
      - name: n8n_user
        passwordSecret:
          name: n8n-db-secret
          key: password
      - name: backstage_user
        passwordSecret:
          name: backstage-db-secret
          key: password
      - name: outline_user
        passwordSecret:
          name: outline-db-secret
          key: password
      - name: devtron_user
        passwordSecret:
          name: devtron-db-secret
          key: password
      - name: harbor_core
        passwordSecret:
          name: harbor-db-secret
          key: password
      - name: harbor_notary
        passwordSecret:
          name: harbor-notary-db-secret
          key: password
      - name: grafana_user
        passwordSecret:
          name: grafana-db-secret
          key: password
  # --- Secrets ---
  superuserSecret:
    name: postgres-superuser-secret # CNPG will create if it does not exist
  enableSuperuserAccess: false # Best practice

  # --- Monitoring ---
  monitoring:
    enablePodMonitor: true

  # TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
  # ssl: on
```

### PgBouncer Pooler `pooler.yaml`
```yaml
# pgbouncer-pooler-helix-stax.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: helix-stax-cluster-pooler
  namespace: database
spec:
  cluster:
    name: helix-stax-cluster # Connect to this cluster

  type: "rw" # Read-write pooling
  instances: 2 # HA for the pooler

  pgbouncer:
    poolMode: "transaction" # Safe default for all services
    parameters:
      max_client_conn: "2000"
      default_pool_size: "20"
      reserve_pool_size: "5"
      max_db_connections: "50" # Per-database pool limit
```
**Application Connection URI:**
`postgres://<user>:<password>@helix-stax-cluster-pooler.database.svc.cluster.local:5432/<dbname>?sslmode=verify-full`

### Scheduled Backup `backup.yaml`
```yaml
# scheduled-backup-helix-stax.yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: helix-stax-daily-backup
  namespace: database
spec:
  schedule: "0 0 3 * * *" # Every night at 3 AM UTC
  backupOwnerReference: self # Prune backups if this schedule is deleted
  cluster:
    name: helix-stax-cluster
```

### Restore from Backup (New Cluster) `restore.yaml`
```yaml
# cluster-restore-from-backup.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: helix-stax-cluster-restored
  namespace: database
spec:
  instances: 1 # Start with 1 to test, can scale up later
  storage:
    storageClass: "hcloud-volumes"
    size: "50Gi"

  # --- Point to the MinIO backup ---
  externalClusters:
    - name: production-backup-source
      barmanObjectStore:
        destinationPath: "s3://backups/helix-stax-cluster/"
        endpointURL: "http://minio.minio.svc.cluster.local:9000"
        s3Credentials:
          accessKeyId:
            name: minio-creds
            key: accessKey
          secretAccessKey:
            name: minio-creds
            key: secretKey

  # --- Bootstrap from recovery ---
  bootstrap:
    recovery:
      source: production-backup-source
      # Optional: For Point-in-Time Recovery
      # recoveryTarget:
      #   targetTime: "2024-05-15 10:30:00Z"
```
---
***(Continued in next response due to length)***
