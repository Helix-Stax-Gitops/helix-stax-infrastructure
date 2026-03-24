Absolutely. Here is the comprehensive research on Velero, structured for your AI agents, following your detailed requirements for Helix Stax.

***

# Velero

### ## SKILL.md Content
<!-- 
  Velero Skill File for AI Agents
  Purpose: Quick reference for daily backup & restore operations.
  Version: 1.0
  Author: Gemini Deep Research
-->

#### **1. Core CLI Commands**

**Create Backup (Manual)**
- **Namespace-specific:**
  ```bash
  velero backup create zitadel-manual-$(date +%F) --include-namespaces zitadel --wait
  ```
- **Full cluster (objects only):**
  ```bash
  velero backup create full-cluster-objects-$(date +%F) --include-cluster-resources=true --snapshot-volumes=false --wait
  ```
- **Full cluster (objects + volumes):**
  ```bash
  velero backup create full-cluster-complete-$(date +%F) --wait
  ```
- **With a 7-day TTL:**
  ```bash
  velero backup create my-backup --ttl 168h0m0s
  ```

**Check Backup Status**
```bash
# List all backups
velero backup get

# Describe a specific backup to see details and errors
velero backup describe full-cluster-complete-20231027

# Get logs for a failing backup
velero backup logs full-cluster-complete-20231027
```

**Restore from Backup**
- **Restore a whole namespace:**
  ```bash
  velero restore create restore-zitadel --from-backup zitadel-daily-20231027-abcdef --include-namespaces zitadel --wait
  ```
- **Restore a single deployment:**
  ```bash
  velero restore create restore-n8n-deployment --from-backup n8n-hourly-20231027-ghijkl --include-resources deployments --include-namespaces n8n
  ```
- **Restore to a different namespace (for testing):**
  ```bash
  velero restore create test-restore-zitadel --from-backup zitadel-daily-20231027-abcdef --namespace-mappings zitadel:zitadel-test
  ```
- **Overwrite existing resources during restore:**
  ```bash
  velero restore create restore-and-overwrite --from-backup my-backup --existing-resource-policy update
  ```

**Check Restore Status**
```bash
# List all restores
velero restore get

# Describe a restore to see details, errors, and warnings
velero restore describe restore-zitadel
```

**Manage Schedules**
```bash
# List all backup schedules
velero schedule get

# Describe a schedule to see its spec and last backup time
velero schedule describe critical-tier-backups
```

**Check System Status**
```bash
# Check client/server versions
velero version

# Verify backup storage location is available
velero backup-location get

# List installed plugins
velero plugin get
```

#### **2. Configuration & Integration**

**ArgoCD `values.yaml` for Velero Helm Chart**
A minimal `values.yaml` for deploying Velero to back up to an in-cluster MinIO service.
```yaml
# values.yaml for Velero Helm deployed via ArgoCD
configuration:
  provider: aws
  backupStorageLocation:
    - name: minio-primary
      provider: aws
      bucket: velero
      config:
        region: minio
        s3ForcePathStyle: "true"
        s3Url: http://minio.minio.svc:9000
  volumeSnapshotLocation: [] # We use file-level backup, not CSI snapshots

credentials:
  # This secret is managed separately, not stored in Git.
  # It contains the MinIO access/secret keys.
  useSecret: true
  existingSecret: velero-s3-credentials

# Enable Kopia for file-level volume backup (best practice)
deployNodeAgent: true

# Set appropriate resource limits for your cluster
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

nodeAgent:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Install the AWS S3 plugin
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.9.0 # Match this to your Velero version
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins
```

**Backing up Volumes (Kopia)**
Annotate pods to include their PVCs in the backup.
```yaml
apiVersion: apps/v1
kind: Deployment
# ...
spec:
  template:
    metadata:
      annotations:
        # Tells Kopia to back up the volume attached to this pod
        backup.velero.io/backup-volumes: my-pvc-data
    # ...
    spec:
      volumes:
        - name: my-pvc-data
          persistentVolumeClaim:
            claimName: data-claim-for-app
```

**Database Backup Strategy (CloudNativePG)**
- **DO NOT** rely on Velero's Kopia/Restic to back up the database PVC directly. This is not application-aware and will lead to a corrupt restore.
- **DO** use CloudNativePG's own backup mechanisms to S3 (MinIO).
- **DO** use Velero to back up the `Cluster` CRD, secrets, and other Kubernetes objects associated with CloudNativePG. Velero complements CNPG; it does not replace its backup functionality.

#### **3. Troubleshooting Decision Tree**

1.  **Symptom: Backup is stuck in `InProgress` phase.**
    *   **Cause?** Volume backup (Kopia/Restic) is hanging.
    *   **Check:**
        1.  `kubectl logs -n velero -l name=node-agent --tail=100 -f` on the node where the pod with the PVC is running. Look for errors mounting or accessing paths.
        2.  `velero backup logs <backup-name>`. Look for timeout errors.
    *   **Fix:**
        *   Ensure the `node-agent` DaemonSet has correct permissions and hostPath mounts.
        *   Check for node I/O pressure that could be slowing down the copy process.

2.  **Symptom: Backup is `PartiallyFailed` or `Failed`.**
    *   **Cause?** Some resources could not be backed up.
    *   **Check:**
        1.  `velero backup describe <backup-name>`
        2.  Scroll to the `Errors` and `Warnings` sections at the bottom. The message will specify which resource failed and why (e.g., "could not be found").
    *   **Fix:**
        *   Commonly, a resource defined in the backup spec was deleted before Velero could back it up. Adjust backup selectors or investigate the missing resource.
        *   For API errors, check permissions: `kubectl logs -n velero deploy/velero`.

3.  **Symptom: `velero backup-location get` shows `Phase: Unavailable`.**
    *   **Cause?** Velero server cannot connect to the object storage (MinIO).
    *   **Check:**
        1.  **Credentials:** `kubectl get secret -n velero velero-s3-credentials -o yaml`. Are the keys correct?
        2.  **Network:** Is there a `NetworkPolicy` blocking egress from the `velero` namespace to the `minio` namespace on port 9000?
        3.  **Service URL:** Is `s3Url: http://minio.minio.svc:9000` correct and resolvable from the Velero pod? Use `kubectl exec -n velero deploy/velero -- curl -v http://minio.minio.svc:9000`.
    *   **Fix:** Correct the secret, network policy, or `s3Url` in the `BackupStorageLocation` CRD.

***

### ## reference.md Content
<!-- 
  Velero Deep Reference Specification
  Purpose: Exhaustive details for advanced configuration, troubleshooting, and architecture.
  Version: 1.0
  Author: Gemini Deep Research
-->

#### **1. Full CLI Reference**

##### `velero install`
Installs Velero into your cluster. While Helm is recommended for GitOps, the CLI is useful for initial setup and understanding parameters.

**Full command for your MinIO setup:**
```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.minio.svc:9000 \
  --use-node-agent \
  --wait
```
*   `--provider aws`: Use the S3-compatible API provider.
*   `--plugins`: Specifies the plugin image to use. The version should be compatible with the Velero server version.
*   `--bucket`: The S3 bucket name (`velero` in your case).
*   `--secret-file`: Path to a local file containing the S3 credentials.
*   `--backup-location-config`: Key-value pairs for the S3 provider. `s3ForcePathStyle` is required for MinIO. `s3Url` points to the MinIO service.
*   `--use-volume-snapshots false`: (Default with `--use-node-agent`) Explicitly disables CSI-style volume snapshots.
*   `--use-node-agent`: Enables the file-level backup agent (Kopia), deploying it as a DaemonSet. This is the current best practice over the deprecated `--use-restic`.
*   `--wait`: Waits For Velero deployment to be ready.

##### `velero backup create {name}`
*   `--include-namespaces`: (string) Comma-separated list of namespaces to include.
*   `--exclude-namespaces`: (string) Comma-separated list of namespaces to exclude.
*   `--include-resources`: (string) Comma-separated list of resource types to include (e.g., `pods,deployments`).
*   `--exclude-resources`: (string) Comma-separated list of resource types to exclude.
*   `--label-selector`: (string) Backup resources matching this label selector (e.g., `app=nginx`).
*   `--snapshot-volumes`: (bool) Take snapshots of persistent volumes (default: `true`). Set to `false` to back up manifests only.
*   `--volume-snapshot-locations`: DEPRECATED. Use `velero.io/volume-snapshot-class` annotation on PVC.
*   `--ttl`: (duration) How long the backup should be retained. e.g., `24h0m0s`, `168h`. Default is 30 days.
*   `--storage-location`: (string) Which backup storage location to use. Defaults to the one marked as primary.
*   `--include-cluster-resources`: (bool) Include cluster-scoped resources like CRDs, ClusterRoles (default may be `nil` or `true` depending on version, best to be explicit `true` for cluster backups).
*   `--ordered-resources`: (string) A map string of resource kinds to a comma-separated list of objects of that kind. e.g. `'pods=ns1/pod1,ns1/pod2'`.
*   `--wait`: (bool) Wait for the backup to complete before returning.

##### `velero restore create [--from-backup {backup-name}]`
*   `--from-backup`: (string, required) The name of the backup to restore from.
*   `--include-namespaces`, `--exclude-namespaces`, `--include-resources`, `--exclude-resources`, `--label-selector`: Same as backup.
*   `--restore-volumes`: (bool) Restore persistent volume data. Default is true. Requires Kopia/Restic data in backup.
*   `--namespace-mappings`: (string) Remap namespaces during restore. Format: `source-ns1:target-ns1,source-ns2:target-ns2`.
*   `--existing-resource-policy`: (string) `none` (default) or `update`. If `none`, skip restoring resources that already exist. If `update`, try to update them.
*   `--include-cluster-resources`: (bool) Restore cluster-scoped resources from the backup.
*   `--wait`: (bool) Wait for the restore to complete (or partially fail).

##### Other Management Commands
*   `velero backup get / describe / logs / delete {name}`: Manage individual backups.
*   `velero restore get / describe / logs / delete {name}`: Manage individual restores.
*   `velero schedule get / describe / delete {name}`: Manage backup schedules.
*   `velero debug`: Creates a gzipped tarball of logs and resource definitions for debugging.
*   `velero completion bash|zsh`: Generates shell completion script. Add `source <(velero completion zsh)` to your `.zshrc`.

#### **2. Full `values.yaml` for Helm**
This provides a comprehensive `values.yaml` detailing important configurations.

```yaml
# Full values.yaml for vmware-tanzu/velero Helm chart
image:
  # Pin the version for reproducibility
  repository: velero/velero
  tag: v1.13.0
  pullPolicy: IfNotPresent

# Credentials for MinIO/B2 are stored in a pre-existing secret
# to avoid storing secrets in Git.
credentials:
  useSecret: true
  existingSecret: velero-s3-credentials # Secret must exist in 'velero' namespace
  # The secret must contain a key 'cloud' with content like:
  # [default]
  # aws_access_key_id = YOUR_MINIO_ACCESS_KEY
  # aws_secret_access_key = YOUR_MINIO_SECRET_KEY

# Deploys Kopia node agent for file-level volume backups.
# This is the modern replacement for Restic.
deployNodeAgent: true

# Main Velero server configuration
configuration:
  # Provider for S3-compatible storage
  provider: aws
  
  # Define the primary backup storage location (on-cluster MinIO)
  backupStorageLocation:
    - name: minio-primary
      provider: aws
      bucket: velero
      # This location is the default for all backups
      default: true
      config:
        region: minio
        s3ForcePathStyle: "true"
        s3Url: http://minio.minio.svc:9000

    - name: b2-offsite
      provider: aws
      bucket: helixstax-velero-b2 # Your Backblaze B2 bucket name
      config:
        region: us-west-001 # Your B2 region
        s3Url: https://s3.us-west-001.backblazeb2.com # Your B2 S3 endpoint

  # We are not using CSI snapshots with local-path-provisioner
  volumeSnapshotLocation: []

# Install the AWS S3 plugin via an initContainer
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.9.0 # Version must be compatible with Velero
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

# Set realistic resource requests and limits
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# Resource configuration for the Kopia node-agent DaemonSet
nodeAgent:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

# RBAC is created by the Helm chart by default.
# It creates a 'velero' ServiceAccount, a ClusterRole, and a ClusterRoleBinding.
# The ClusterRole grants permissions to read all resources in the cluster and
# create/update/delete resources during restore. It's necessarily broad.
serviceAccount:
  server:
    create: true

# Sane defaults
# Run Velero in its own dedicated namespace
namespace: velero
# Enable Prometheus metrics scraping
metrics:
  enabled: true
  scrapeInterval: 30s
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8085"
    prometheus.io/path: "/metrics"
```

#### **3. Architecture and Data Flow**

**Backup Flow (with Kopia):**
```mermaid
graph TD
    subgraph K3s Cluster
        subgraph velero namespace
            A[Velero Server Pod] --> B{Backup CRD};
            B -- Scans --> K8s_API[Kubernetes API Server];
        end
        subgraph app namespace
            P[App Pod] -- has --> PVC[PersistentVolumeClaim] -- uses --> PV[PV on HostPath];
            NA[Node Agent Pod (Kopia)] -- on same node --> PV;
        end
    end

    K8s_API -- "GET objects (Deployments, Secrets...)" --> A;
    A -- "Stream manifests" --> MinIO[MinIO (on-cluster)];
    A -- "Instructs Node Agent" --> NA;
    NA -- "Reads files from PV path" --> NA;
    NA -- "Streams volume data" --> MinIO;

    subgraph Offsite Replication
        MC[MinIO Client (mc mirror CronJob)] -- Watches --> MinIO;
        MC -- "Replicates objects" --> B2[Backblaze B2];
    end

    style A fill:#cce5ff,stroke:#333
    style NA fill:#ccffcc,stroke:#333
    style MinIO fill:#ffcccc,stroke:#333
    style B2 fill:#ffdccc,stroke:#333
```

#### **4. Best Practices & Anti-Patterns**

**Top 10 Best Practices:**
1.  **Use GitOps:** Manage Velero deployment (Helm chart) and `Schedule` CRDs via ArgoCD.
2.  **Use Kopia:** Enable the `nodeAgent` (`--use-node-agent`) for file-level backups instead of the deprecated Restic.
3.  **Separate DB Backups:** For databases (CloudNativePG), use their native, application-aware backup tools. Use Velero to back up the Kubernetes objects around them, not the data volumes.
4.  **Tiered Schedules:** Create multiple `Schedule` CRDs with different frequencies and TTLs (e.g., critical, platform, full).
5.  **Offsite Replication:** Implement a robust replication from your primary (MinIO) to a secondary, offsite location (Backblaze B2).
6.  **Regular Restore Drills:** Schedule monthly restores of a non-critical namespace to a test namespace (`--namespace-mappings`) to validate backup integrity.
7.  **Monitor & Alert:** Scrape Velero's Prometheus metrics and set up alerts for backup failures and backups not running on schedule.
8.  **Version Pinning:** Pin Velero, its plugins, and the Helm chart version for stable, reproducible deployments. Check compatibility matrices before upgrading.
9.  **Resource Limits:** Set appropriate CPU/Memory requests and limits for the `velero` pod and the `node-agent` DaemonSet to prevent resource starvation or abuse.
10. **Immutable Backups:** Configure object lock/immutability on your B2 bucket to protect against ransomware or accidental deletion.

**Common Anti-Patterns (Severity: Critical -> Low):**
1.  **(Critical) Backing Up Active Databases with File-Level Backup:** Using Kopia/Restic on a live PostgreSQL/MySQL volume will almost certainly result in a corrupt, unusable backup. It is not transaction-aware.
2.  **(Critical) No Offsite Backups:** Relying solely on an in-cluster MinIO instance is a single point of failure. If the cluster is lost, the backups are also lost.
3.  **(High) Not Testing Restores:** Assuming backups are good without ever performing a restore is a recipe for disaster.
4.  **(Medium) Using a Single Cluster-Wide Backup:** While simple, it makes granular restores harder and can be inefficient. Namespace-specific schedules are more flexible.
5.  **(Medium) Not Pinning Versions:** Allowing `:latest` tags for Velero or its plugins can lead to unexpected breakages on upgrade.
6.  **(Low) Storing Credentials in Git:** Pushing `credentials-velero` or including `credentials.secretContents` in a public/private Git repo is a security risk. Use a secret management solution or pre-create the secret in the cluster.
7.  **(Low) No Resource Limits:** Letting Velero and its agents run without limits can cause them to consume excessive resources during a large backup, impacting other workloads.

#### **5. Decision Matrix**

| If you need to...                                     | Use this Approach                                                                                             | Because...                                                                                                                              |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Back up application manifests (Deployments, etc.)     | `velero backup create`                                                                                        | This is Velero's core function, capturing the state of Kubernetes objects.                                                            |
| Back up persistent data for a stateless/simple app    | Enable Kopia (`deployNodeAgent: true`) and annotate pods (`backup.velero.io/backup-volumes`).                 | Kopia provides reliable file-level backup for data where strict consistency isn't required (e.g., file uploads, caches, config files). |
| Back up a database (e.g., CloudNativePG)              | Use the database's native backup tool (e.g., CNPG's S3 backup). Use Velero ONLY for the Kubernetes CRDs/Secrets. | This ensures application-consistent, point-in-time recovery. Velero's file-level backup is not transaction-aware and is unsafe for DBs. |
| Migrate a namespace to a new cluster                  | `velero backup create` on old cluster, configure new cluster Velero to read from same S3 bucket, `velero restore create` on new. | Velero is an excellent tool for cluster migration, as it re-creates objects and can restore volume data.                                   |
| Test a restore without impacting production          | `velero restore create --namespace-mappings prod-ns:test-ns`                                                  | This redirects all restored resources to a new, isolated namespace, allowing for safe validation.                                       |
| Have an offsite copy of backups                       | Configure MinIO to replicate to Backblaze B2 (e.g., via `mc mirror`).                                           | This decouples the replication from the backup process, providing a robust and independently verifiable disaster recovery copy.           |
| Back up cluster-scoped resources (CRDs, ClusterRoles) | Use `--include-cluster-resources=true` on a dedicated cluster backup schedule.                                  | These resources are not part of any single namespace and must be explicitly included to be backed up.                                   |

***

### ## examples.md Content
<!-- 
  Velero Examples for Helix Stax
  Purpose: Copy-paste-ready configurations and runbooks for our specific environment.
  Version: 1.0
  Author: Gemini Deep Research
-->

#### **1. ArgoCD Application Manifest for Velero**

This manifest deploys Velero via Helm and should be committed to your GitOps repository.

```yaml
# argocd-apps/velero.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velero
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://vmware-tanzu.github.io/helm-charts'
    chart: velero
    targetRevision: 5.1.0 # Pin chart version
    helm:
      values: |
        # See full values in reference.md, this is the core config
        # for Helix Stax setup.
        image:
          tag: v1.13.0 # Pin Velero version
        
        credentials:
          useSecret: true
          # This secret must be created manually in the velero namespace.
          # kubectl create secret generic velero-s3-credentials --namespace velero --from-file=cloud=./credentials-velero
          existingSecret: velero-s3-credentials

        # Deploy Kopia for file-level volume backup
        deployNodeAgent: true

        configuration:
          provider: aws
          backupStorageLocation:
            - name: minio-primary
              provider: aws
              bucket: velero
              default: true
              config:
                region: minio
                s3ForcePathStyle: "true"
                s3Url: http://minio.minio.svc:9000
            - name: b2-offsite
              provider: aws
              bucket: helixstax-velero-b2
              config:
                # Get region and endpoint from your B2 bucket page
                region: us-west-001 
                s3Url: https://s3.us-west-001.backblazeb2.com

        # Install AWS S3 plugin, version compatible with Velero v1.13.0
        initContainers:
          - name: velero-plugin-for-aws
            image: velero/velero-plugin-for-aws:v1.9.0
            imagePullPolicy: IfNotPresent
            volumeMounts:
              - mountPath: /target
                name: plugins
        
        # Enable Prometheus metrics
        metrics:
          enabled: true
          podAnnotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "8085"

        # Resource limits for our cluster
        resources:
          requests: { cpu: 250m, memory: 256Mi }
          limits: { cpu: 1000m, memory: 1Gi }
        nodeAgent:
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits: { cpu: 500m, memory: 512Mi }
  
  destination:
    server: https://kubernetes.default.svc
    namespace: velero
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### **2. MinIO -> Backblaze B2 Replication CronJob**

This CronJob uses the MinIO Client (`mc`) to mirror the `velero` bucket from our on-cluster MinIO to Backblaze B2 every hour.

```yaml
# cluster-jobs/mc-mirror-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mc-mirror-to-b2
  namespace: minio
spec:
  schedule: "0 * * * *" # Run at the top of every hour
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mc-mirror
            image: minio/mc:RELEASE.2024-01-01T00-00-00Z  # Pin to specific release tag — never use :latest
            command:
            - /bin/sh
            - -c
            - "mc alias set local http://minio.minio.svc:9000 $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY) && mc alias set b2 https://s3.us-west-001.backblazeb2.com $(B2_KEY_ID) $(B2_APP_KEY) && mc mirror --overwrite --remove --watch local/velero b2/helixstax-velero-b2"
            env:
            - name: MINIO_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials # Your MinIO credential secret
                  key: accesskey
            - name: MINIO_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secretkey
            - name: B2_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: b2-credentials # Your B2 credential secret
                  key: keyID
            - name: B2_APP_KEY
              valueFrom:
                secretKeyRef:
                  name: b2-credentials
                  key: applicationKey
          restartPolicy: OnFailure
```
*Note: The `--watch` flag will make this process long-running. `mc mirror` will run once, then watch for changes. For a cronjob, you may want to remove `--watch` to ensure it completes and doesn't run forever.*

#### **3. Backup `Schedule` CRD Manifests**
Store these in your GitOps repo to be managed by ArgoCD.

**Critical Tier (Every 6 hours, 7-day TTL)**
```yaml
# velero-schedules/critical-tier.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: critical-tier-backups
  namespace: velero
spec:
  schedule: "0 */6 * * *"
  template:
    includeNamespaces:
      - zitadel
      - n8n
      - rocketchat
      - outline
    # NOTE: 'monitoring' is excluded as it's often better to rebuild from GitOps.
    # Backing up active Prometheus data can be large and has limited value.
    storageLocation: minio-primary
    ttl: 168h0m0s # 7 days
```

**Platform Tier (Daily, 14-day TTL)**
```yaml
# velero-schedules/platform-tier.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: platform-tier-backups
  namespace: velero
spec:
  schedule: "0 2 * * *" # 2 AM UTC daily
  template:
    includeNamespaces:
      - traefik
      # - cert-manager  # Remove if cert-manager is not deployed (Cloudflare Origin CA setup)
      - argocd
      - devtron
    storageLocation: minio-primary
    ttl: 336h0m0s # 14 days
```

**Full Cluster (Weekly, 30-day TTL)**
```yaml
# velero-schedules/full-cluster.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: full-cluster-backup
  namespace: velero
spec:
  schedule: "0 3 * * 0" # 3 AM UTC every Sunday
  template:
    # Exclude namespaces already backed up frequently
    excludeNamespaces:
      - zitadel
      - n8n
      - rocketchat
      - outline
    includeClusterResources: true
    storageLocation: minio-primary
    ttl: 720h0m0s # 30 days
```

#### **4. Runbook: Full Cluster Disaster Recovery**

**Scenario:** The control plane node (`helix-stax-cp`, 178.156.233.12) is destroyed. The on-cluster MinIO is gone. We must restore the cluster from the Backblaze B2 offsite backup.

**Runbook Steps:**

1.  **Provision New Control Plane:**
    *   Create a new Hetzner Cloud VPS with AlmaLinux 9.x.
    *   Assign the same IP (178.156.233.12) or update DNS records for a new IP.
    *   Install K3s as the new control plane. The existing worker `helix-stax-vps` should rejoin automatically if the join token is reused or if you re-establish trust.
        ```bash
        # On new control plane
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --token <YOUR_TOKEN>" sh -
        # You may need to get the token from the existing worker if you don't have it:
        # cat /var/lib/rancher/k3s/agent/node-password.txt
        ```

2.  **Install `velero` CLI:**
    *   Install the `velero` CLI locally on your workstation. Make sure its version matches what was running on the cluster.

3.  **Install Velero Pointed to Backblaze B2:**
    *   Create a `credentials-velero-b2` file with your Backblaze B2 App Key credentials.
    *   **Crucially**, we now install Velero but point its configuration directly at the B2 offsite location.
    ```bash
    velero install \
      --provider aws \
      --plugins velero/velero-plugin-for-aws:v1.9.0 \
      --bucket helixstax-velero-b2 \
      --secret-file ./credentials-velero-b2 \
      --backup-location-config region=us-west-001,s3Url=https://s3.us-west-001.backblazeb2.com \
      --use-node-agent \
      --wait
    ```

4.  **Verify Access to Backups:**
    *   The Velero server will start and sync with the B2 bucket. This may take a few minutes.
    ```bash
    # Location should become 'Available'
    velero backup-location get
    
    # You should now see the backups that were replicated from MinIO
    velero backup get
    ```

5.  **Restore Cluster-Scoped Resources First:**
    *   Find the most recent full cluster backup. It's critical to restore CRDs, ClusterRoles, etc., before you restore applications that depend on them.
    ```bash
    # e.g., full-cluster-backup-20231022030000
    LATEST_FULL_BACKUP=$(velero backup get | grep full-cluster-backup | sort -r | head -n 1 | awk '{print $1}')
    
    echo "Restoring cluster resources from: $LATEST_FULL_BACKUP"
    
    velero restore create restore-cluster-resources --from-backup $LATEST_FULL_BACKUP --include-cluster-resources=true --wait
    
    # Describe to check for errors. It's okay if some resources already exist (e.g., from Velero's own install)
    velero restore describe restore-cluster-resources
    ```

6.  **Restore Platform Namespaces:**
    *   Restore in dependency order. `cert-manager` is often first. ArgoCD is needed to bring GitOps back online.
    ```bash
    # Find latest platform backup
    LATEST_PLATFORM_BACKUP=$(velero backup get | grep platform-tier-backup | sort -r | head -n 1 | awk '{print $1}')

    velero restore create restore-platform \
      --from-backup $LATEST_PLATFORM_BACKUP \
      --include-namespaces traefik,argocd,devtron \
      --wait
    
    # Check status
    velero restore describe restore-platform
    ```

7.  **Restore Critical Application Namespaces:**
    *   Once the platform is stable, restore the applications.
    ```bash
    # Find latest critical backup
    LATEST_CRITICAL_BACKUP=$(velero backup get | grep critical-tier-backup | sort -r | head -n 1 | awk '{print $1}')

    velero restore create restore-critical-apps \
      --from-backup $LATEST_CRITICAL_BACKUP \
      --include-namespaces zitadel,n8n,rocketchat,outline \
      --restore-volumes=true \
      --wait

    velero restore describe restore-critical-apps
    ```

8.  **Post-Restore Validation:**
    *   Check pod statuses: `kubectl get pods --all-namespaces`.
    *   Verify data in apps (e.g., can you log into Zitadel? Are Outline documents present?).
    *   Check Ingress routes and TLS certificates.
    *   At this point, the cluster is recovered. You can now re-establish the MinIO -> B2 replication flow.

#### **5. Prometheus Alerting Rule**

Add this `PrometheusRule` to your monitoring stack to get alerts on backup failures.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: velero-alerts
  namespace: monitoring
  labels:
    app: prometheus-operator
    release: prometheus
spec:
  groups:
  - name: velero.rules
    rules:
    - alert: VeleroBackupFailed
      expr: velero_backup_failure_total{job="velero"} > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Velero backup failed"
        description: "Velero backup has failed. Check `velero backup describe <backup-name>` and `velero backup logs <backup-name>` for details."

    - alert: VeleroBackupPartialFailure
      expr: velero_backup_partial_failure_total{job="velero"} > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Velero backup partially failed"
        description: "Velero backup completed with partial failures. Some resources may not have been backed up. Check `velero backup describe <backup-name>`."
    
    - alert: VeleroNoSuccessfulBackupIn24h
      expr: time() - velero_backup_last_successful_timestamp{job="velero"} > 86400 # 24 hours
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "No successful Velero backup in 24 hours"
        description: "No successful Velero backup has completed in the last 24 hours. Check Velero server logs and schedules."
```
