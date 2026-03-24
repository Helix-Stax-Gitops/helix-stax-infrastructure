Here is the comprehensive research document for your storage chain, formatted for use by your AI agents.

# MinIO

## ## SKILL.md Content
### **Overview**
MinIO provides on-cluster, S3-compatible object storage. It is the primary storage backend for Harbor, Velero, Loki, and CloudNativePG. It replicates critical data to Backblaze B2 for offsite disaster recovery.

### **CLI Reference: mc (MinIO Client)**
- **Authentication**: `mc alias set myminio https://s3.helixstax.net MINIO_ACCESS_KEY MINIO_SECRET_KEY`
- **Test Connection**: `mc admin info myminio`
- **List Buckets**: `mc ls myminio`
- **Make Bucket**: `mc mb myminio/new-bucket`
- **Remove Bucket**: `mc rb myminio/old-bucket --force` (deletes contents too)
- **Copy Object**: `mc cp ./local-file.txt myminio/bucket/remote-file.txt`
- **Remove Object**: `mc rm myminio/bucket/file.txt`
- **Recursive Remove**: `mc rm --recursive --force myminio/bucket/`
- **List Objects (Recursive)**: `mc ls --recursive myminio/bucket`
- **Mirror Local to Remote**: `mc mirror --overwrite ./local-dir/ myminio/bucket/`
- **Get Bucket Disk Usage**: `mc du myminio/bucket`
- **Set Bucket Policy**: `mc policy set download myminio/public-bucket`
- **Enable Versioning**: `mc version enable myminio/versioned-bucket`
- **Set Object Lock**: `mc retention set --default GOVERNANCE 30d myminio/velero-backups`
- **Check Replication Status**: `mc replicate status myminio/velero-backups`
- **Create Service Account**: `mc admin accesskey create myminio --user <user_for_sa>`

### **Bucket Design & Management**
| Bucket Name | Service | Versioning | Object Lock | Quota | B2 Replica |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `velero-backups` | Velero | Yes | GOVERNANCE 30d | 100GiB | Yes |
| `loki-chunks` | Loki | No | No | 50GiB | No |
| `harbor-blobs` | Harbor | No | No | 200GiB | No |
- **Create a locked & versioned bucket**:
  ```bash
  mc mb --with-lock myminio/velero-backups
  mc version enable myminio/velero-backups
  mc retention set --default GOVERNANCE 30d myminio/velero-backups
  ```
- **Set a bucket quota**: `mc admin bucket quota myminio/loki-chunks --hard 50GiB`
- **Find what's taking up space**: `mc du --recursive myminio/loki-chunks`

### **Per-Service Access Control**
1.  **Create a policy JSON file** (see `reference.md` for examples).
2.  **Create the policy in MinIO**: `mc admin policy create myminio velero-policy ./velero-policy.json`
3.  **Create a dedicated user**: `mc admin user add myminio velero-user <long_random_password>`
4.  **Attach policy to user**: `mc admin policy attach myminio velero-policy --user velero-user`
5.  **Retrieve user's keys**: `mc admin user info myminio velero-user` (This gives you the access/secret key to put in a K8s secret).

### **Troubleshooting Decision Tree**
- **Symptom: `XMinioStorageFull` or Read-Only Mode**
  - **Cause**: The persistent volume is full.
  - **Check**: `mc admin info myminio` | `df -h` on the node.
  - **Fix**: Increase the PVC size. Delete old data using `mc rm --recursive --force --older-than 30d myminio/bucket`.
- **Symptom: `AccessDenied` from a service (Loki, Velero, etc.)**
  - **Cause**: Incorrect policy or credentials.
  - **Check**: `mc admin policy info myminio <policy-name>` and `mc admin accesskey info myminio --key <access-key>`.
  - **Trace**: `mc admin trace -v --all myminio` to see live API calls and denials.
  - **Fix**: Correct the policy JSON and update it with `mc admin policy update`. Ensure the correct K8s secret is mounted by the pod.
- **Symptom: `SignatureDoesNotMatch`**
  - **Cause**: Wrong secret key, or clock skew between client and server nodes.
  - **Check**: Verify the secret key in the K8s secret matches the one from `mc admin user info`.
  - **Fix**: Ensure NTP is running and synchronized on all K3s nodes (`chronyc sources`).
- **Symptom: Slow uploads/downloads**
  - **Cause**: Network bottleneck or disk I/O limit.
  - **Check**: `mc support perf object --size 128MiB myminio/general` to test bandwidth.
  - **Fix**: Check node CPU/memory/network stats. Check underlying storage performance.
- **Symptom: Replication to B2 is behind (`pending` count high)**
  - **Cause**: Network issue between Hetzner and B2, or MinIO is overloaded.
  - **Check**: `mc replicate status myminio/velero-backups`.
  - **Fix**: Check MinIO logs for errors. Ensure sufficient bandwidth is available. If stuck, consider `mc replicate reset`.

## ## reference.md Content
### **mc (MinIO Client) - Complete Reference**

- **Installation (AlmaLinux 9)**:
  ```bash
  wget https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x mc
  sudo mv mc /usr/local/bin/
  ```
- **Installation (K3s Pod/Job)**: Use an `initContainer` or add to a container image based on `minio/mc`.
  ```yaml
  initContainers:
  - name: mc-init
    image: minio/mc
    command: ['sh', '-c', "mc alias set myminio http://minio.minio-system.svc.cluster.local:9000 $(ACCESS_KEY) $(SECRET_KEY)"]
    env:
      - name: ACCESS_KEY
        valueFrom: { secretKeyRef: { name: minio-root-creds, key: rootUser } }
      - name: SECRET_KEY
        valueFrom: { secretKeyRef: { name: minio-root-creds, key: rootPassword } }
  ```

#### **Alias Management**
- `mc alias set <ALIAS> <URL> <ACCESS_KEY> <SECRET_KEY> [--api <API_SIGNATURE>]`: Add a host. Use `--api S3v4`.
- `mc alias list`: Show configured aliases.
- `mc alias remove <ALIAS>`: Remove a host.
- `mc ping <ALIAS>`: Check connectivity and latency to an alias/bucket, requires health check permissions.

#### **Bucket Operations**
- `mc mb <ALIAS>/<BUCKET>`: Make a bucket.
  - `--with-lock`: Enable object locking on the bucket at creation time.
- `mc rb <ALIAS>/<BUCKET>`: Remove a bucket (must be empty).
  - `--force`: Forcefully remove a non-empty bucket. **DANGEROUS**.
- `mc ls <ALIAS>/<BUCKET>`: List objects and prefixes.
  - `--recursive`: List all objects recursively.
  - `--versions`: List all versions of objects, including delete markers.
- `mc du <ALIAS>/<BUCKET>`: Calculate disk usage.
  - `--recursive`: Calculate usage for all prefixes.

#### **Object Operations**
- `mc cp <SOURCE> <TARGET>`: Copy objects.
- `mc mv <SOURCE> <TARGET>`: Move objects.
- `mc rm <ALIAS>/<BUCKET>/<OBJECT>`: Remove an object.
  - `--recursive`: Remove objects recursively.
  - `--older-than "7d"`: Remove objects older than 7 days.
  - `--newer-than "1d"`: Remove objects newer than 1 day.
  - `--vid <VERSION_ID>`: Remove a specific object version.
- `mc cat <ALIAS>/<BUCKET>/<OBJECT>`: Display object contents.
- `mc head <ALIAS>/<BUCKET>/<OBJECT>`: Display first 10 lines of an object.
- `mc stat <ALIAS>/<BUCKET>/<OBJECT>`: Show object metadata (size, date, ETag, user metadata).
- `mc find <ALIAS>/<PATH> --name "*.log"`: Find files matching patterns.

#### **Sync Operations**
- **`mc mirror`**: One-way sync. Makes the destination a replica of the source.
  - `mc mirror local-dir/ myminio/bucket/`
  - `--watch`: Continuously watch for changes and mirror.
  - `--remove`: **DANGEROUS**. Deletes objects in destination that are not in the source.
  - `--overwrite`: Overwrites destination files even if they are newer.
- **`mc sync`**: Bi-directional sync. More complex, generally not recommended for backup use cases. `mc mirror` is safer.
- **`mc diff <ALIAS1>/<BUCKET1> <ALIAS2>/<BUCKET2>`**: Show differences between two buckets. Essential for verifying backups.

#### **Policy Management**
- **Canned Policies**: `none`, `download`, `upload`, `public`.
- `mc policy set <POLICY> <ALIAS>/<BUCKET>`: `mc policy set download myminio/public-data`
- `mc policy get <ALIAS>/<BUCKET>`: Get the JSON policy for a bucket.
- `mc policy list <ALIAS>/<BUCKET>`: List policies set on a bucket.
- **Custom Policies (IAM)**: Use `mc admin policy` for user/group policies.

#### **Admin Operations**
- `mc admin info <ALIAS>`: Display server info (version, uptime, disk usage).
- `mc admin user add/remove/list/enable/disable <ALIAS> <USER>`
- `mc admin group add/remove/list/info <ALIAS> <GROUP> <MEMBERS>`
- `mc admin policy create/delete/list/info/attach/detach <ALIAS> <POLICY>`
- `mc admin service restart <ALIAS>`: Gracefully restart the MinIO server.
- `mc admin trace <ALIAS>`: Real-time trace of all S3 API calls.
  - `-v, --verbose`: Show verbose trace.
  - `--all`: Trace all types of requests.
  - `--bucket "loki-chunks"`: Filter trace to a specific bucket.
- `mc admin accesskey create/update/list/info/delete <ALIAS> --user <USERNAME>`: Create service account keys for a user.

#### **Bucket Lifecycle Management (ILM)**
- `mc ilm rule add <ALIAS>/<BUCKET> --expire-days 30 --tags "key=value"`: Add an expiration rule.
- `mc ilm rule ls <ALIAS>/<BUCKET>`: List ILM rules.
- `mc ilm rule rm <ALIAS>/<BUCKET> --id <RULE_ID>`: Remove a rule.
- `mc ilm export <ALIAS>/<BUCKET>`: Export rules to JSON.
- `mc ilm import <ALIAS>/<BUCKET> < file.json`: Import rules from JSON.
  - JSON allows for more complex rules like `NoncurrentVersionExpiration` and `Transition`.

#### **Versioning**
- `mc version enable/suspend/info <ALIAS>/<BUCKET>`
- `mc ls --versions <ALIAS>/<BUCKET>`: List versions and delete markers.
- To restore a deleted file: `mc cp --vid <VERSION_ID> myminio/bucket/file myminio/bucket/file`

#### **Object Locking / WORM**
- `mc retention set <ALIAS>/<BUCKET> <MODE> <VALIDITY>`: e.g., `GOVERNANCE 30d`.
  - `GOVERNANCE`: Can be overridden by users with `s3:BypassGovernanceRetention`.
  - `COMPLIANCE`: Cannot be overridden by anyone, including root. Use with extreme caution.
- `mc retention info <ALIAS>/<BUCKET>/<OBJECT>`: Check lock status.

#### **Server-Side Encryption (SSE)**
- **SSE-S3**: MinIO manages keys. Enabled by default if KMS is not configured.
- `mc encrypt set sse-s3 <ALIAS>/<BUCKET>`
- **SSE-C**: Client provides encryption key with each request. `mc` handles this via environment variables `MC_ENCRYPT_KEY_<ALIAS>`.

#### **Event Notifications**
- `mc event add <ALIAS>/<BUCKET> <ARN>`: Add a notification target. ARN is the webhook endpoint.
  - `arn:minio:sqs::1:webhook --event "put,delete" --prefix "images/"`
- `mc event list/remove <ALIAS>/<BUCKET> <ARN>`

#### **Replication Configuration**
- Prerequisite: Versioning must be enabled on both source and destination buckets.
- `mc replicate add <ALIAS>/<BUCKET> --remote-bucket <ARN>`
  - ARN format: `arn:minio:replication::<UUID>:b2/helix-velero-backups`
- `mc replicate ls <ALIAS>/<BUCKET>`: List replication rules.
- `mc replicate status <ALIAS>/<BUCKET>`: **Crucial**. Shows pending bytes, replication failures.
- `mc replicate rm <ALIAS>/<BUCKET> --id <RULE_ID>`
- Flags:
  - `--replicate delete,delete-marker`: Replicate deletions.
  - `--replicate existing-objects`: Replicate objects that existed before the rule was created.

#### **Performance Testing**
- `mc support perf object <ALIAS>/<BUCKET>`: Runs a throughput test.

#### **Deployment on K3s: In-depth**
- **Chart Choice**: For a single-node standalone deployment, the Bitnami chart (`oci://registry-1.docker.io/bitnamicharts/minio`) is simpler and sufficient. The official MinIO Operator chart is better for distributed, multi-tenant setups.
- **Standalone vs Distributed**: For a 2-node K3s cluster, standalone is the only practical option. Distributed erasure coding requires a minimum of 4 drives/nodes for data and parity, which isn't met.
- **StatefulSet vs Deployment**: The Bitnami chart uses a `StatefulSet` for standalone mode to ensure a stable network identity and persistent storage binding.
- **Upgrading**: `helm upgrade minio bitnami/minio -f values.yaml`. The StatefulSet performs a rolling update, terminating the old pod and starting a new one with the same PVC. Data on the PVC is safe.

#### **Policy JSON Examples**
- **velero-policy.json**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"],
        "Resource": [
          "arn:aws:s3:::velero-backups",
          "arn:aws:s3:::velero-backups/*"
        ]
      }
    ]
  }
  ```
- **loki-policy.json**: Read/Write/Delete/List on the bucket.
  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:DeleteObject"
              ],
              "Resource": "arn:aws:s3:::loki-chunks/*"
          },
          {
              "Effect": "Allow",
              "Action": "s3:ListBucket",
              "Resource": "arn:aws:s3:::loki-chunks"
          }
      ]
  }
  ```
- **harbor-policy.json**: Scoped actions on its bucket.
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"],
        "Resource": [
          "arn:aws:s3:::harbor-blobs",
          "arn:aws:s3:::harbor-blobs/*"
        ]
      }
    ]
  }
  ```
- **cnpg-policy.json**: Scoped actions on WAL and backup buckets.
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"],
        "Resource": [
          "arn:aws:s3:::cnpg-wal",
          "arn:aws:s3:::cnpg-wal/*",
          "arn:aws:s3:::cnpg-backups",
          "arn:aws:s3:::cnpg-backups/*"
        ]
      }
    ]
  }
  ```
- **read-only-audit-policy.json**:
  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "s3:GetObject",
                  "s3:ListBucket"
              ],
              "Resource": "arn:aws:s3:::*"
          }
      ]
  }
  ```

#### **Monitoring**
- **Metrics Endpoint Authentication**: For Prometheus Operator, `MINIO_PROMETHEUS_AUTH_TYPE: "public"` is the simplest. The endpoint `/minio/v2/metrics/cluster` will be accessible without authentication. Lock this down with a NetworkPolicy.
- **Health Endpoints**:
  - `GET /minio/health/live`: Checks if the server process is running. Use for liveness probes.
  - `GET /minio/health/ready`: Checks if the server is ready to accept traffic (storage is available). Use for readiness probes.

## ## examples.md Content
### **Deployment: values.yaml for Bitnami MinIO Helm Chart**
```yaml
# values-minio.yaml
# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm install minio bitnami/minio -n minio-system --create-namespace -f values-minio.yaml

# Use the non-root 'default' image for better security
image:
  registry: docker.io
  repository: bitnami/minio
  tag: 2024.5.21

# Standalone mode for single-node deployment
mode: standalone

# Use existing secret managed by OpenBao -> External Secrets Operator
# kubectl create secret generic minio-root-creds -n minio-system \
#   --from-literal=rootUser='minio' \
#   --from-literal=rootPassword='YOUR_STRONG_PASSWORD'
auth:
  existingSecret: "minio-root-creds"
  rootUserKey: "rootUser"
  rootPasswordKey: "rootPassword"

## Core environment variables for MinIO
## Sets the external URL for the API and Console for correct redirects and signatures
## This MUST match the IngressRoute host and TLS certificate common name
environment:
  MINIO_SERVER_URL: "https://s3.helixstax.net"
  MINIO_BROWSER_REDIRECT_URL: "https://minio.helixstax.net"
  # Enable Prometheus metrics endpoint without authentication
  MINIO_PROMETHEUS_AUTH_TYPE: "public"

# Configure persistence using Hetzner CSI
persistence:
  enabled: true
  # Size based on sum of expected usage for all services + buffer.
  # Velero(100GB) + Loki(50GB) + Harbor(200GB) + CNPG(50GB) + General(50GB) = 450GB. Start with 500Gi.
  size: 500Gi
  storageClass: "hcloud-volumes" # Hetzner CSI storage class name
  accessModes:
    - ReadWriteOnce

# Resource requests and limits for a shared K3s node
# Start with these and adjust based on Prometheus monitoring
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 2Gi
    cpu: 1000m

# Create two services: one for the API (9000) and one for the Console (9001)
apiService:
  type: ClusterIP
  port: 9000
consoleService:
  type: ClusterIP
  port: 9001

# Disable the chart's built-in ingress, we will use Traefik IngressRoute
ingress:
  enabled: false
consoleIngress:
  enabled: false
```

### **TLS Certificate**
```yaml
# TLS: Use Cloudflare Origin CA certificate stored as K8s Secret via ESO/OpenBao. No cert-manager needed.
# kubectl create secret tls minio-tls-secret --cert=origin.pem --key=privkey.pem -n minio-system
```

### **Network: Traefik IngressRoute**
```yaml
# ingressroute-minio.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: minio-api-ingress
  namespace: minio-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`s3.helixstax.net`)
      kind: Rule
      services:
        - name: minio # Service created by Bitnami chart for the API
          port: 9000
  tls:
    secretName: minio-tls-secret # TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: minio-console-ingress
  namespace: minio-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`minio.helixstax.net`)
      kind: Rule
      services:
        - name: minio-console # Service created for the console
          port: 9001
  tls:
    secretName: minio-tls-secret # Use the same secret
```

### **Runbook: Initial Bucket and Policy Setup**
```bash
# Set alias for your new MinIO instance
# Obtain keys from the 'minio-root-creds' Kubernetes secret
ACCESS_KEY=$(kubectl get secret minio-root-creds -n minio-system -o jsonpath='{.data.rootUser}' | base64 -d)
SECRET_KEY=$(kubectl get secret minio-root-creds -n minio-system -o jsonpath='{.data.rootPassword}' | base64 -d)
mc alias set myminio https://s3.helixstax.net "$ACCESS_KEY" "$SECRET_KEY"

# Create buckets
mc mb myminio/velero-backups
mc mb myminio/loki-chunks
mc mb myminio/harbor-blobs
mc mb myminio/cnpg-wal
mc mb myminio/cnpg-backups
mc mb myminio/general

# Enable versioning where needed
mc version enable myminio/velero-backups
mc version enable myminio/cnpg-backups
mc version enable myminio/cnpg-wal

# Set Object Locking for Velero
mc mb --with-lock myminio/velero-backups # Must be done at creation, or re-create bucket
mc retention set --default GOVERNANCE 30d myminio/velero-backups

# Set quotas
mc admin bucket quota myminio/velero-backups --hard 100GiB
mc admin bucket quota myminio/loki-chunks --hard 50GiB
mc admin bucket quota myminio/harbor-blobs --hard 200GiB

# --- Velero Setup ---
# 1. Create policy file velero-policy.json (from reference.md)
mc admin policy create myminio velero-policy ./velero-policy.json
mc admin user add myminio velero-user 'VERY_STRONG_PASSWORD_HERE'
mc admin policy attach myminio velero-policy --user velero-user
# 2. Get keys from `mc admin user info myminio velero-user`
# 3. Create K8s secret for Velero:
echo -e "[default]\naws_access_key_id=...KEY...\naws_secret_access_key=...SECRET..." > velero-credentials
kubectl create secret generic velero-s3-creds -n velero --from-file=cloud=./velero-credentials
```

### **Runbook: Setup Replication to Backblaze B2**
```bash
# 1. Get B2 Application Key and Key ID from B2 dashboard
B2_KEY_ID="your-b2-key-id"
B2_APP_KEY="your-b2-app-key"
B2_ENDPOINT="https://s3.us-west-004.backblazeb2.com" # Check your B2 region

# 2. Set alias for B2
mc alias set b2 $B2_ENDPOINT $B2_KEY_ID $B2_APP_KEY

# 3. Create buckets in B2 (must exist before setting replication)
mc mb b2/helix-velero-backups
mc mb b2/helix-cnpg-backups
mc mb b2/helix-cnpg-wal

# 4. Enable versioning on B2 buckets
mc version enable b2/helix-velero-backups
mc version enable b2/helix-cnpg-backups
mc version enable b2/helix-cnpg-wal

# 5. Add replication rules on MinIO source buckets
# Ensure versioning is already enabled on myminio/velero-backups
mc replicate add myminio/velero-backups --remote-bucket "b2/helix-velero-backups" --replicate "delete,delete-marker,existing-objects" --priority 1
mc replicate add myminio/cnpg-backups --remote-bucket "b2/helix-cnpg-backups" --replicate "delete,delete-marker,existing-objects" --priority 1
mc replicate add myminio/cnpg-wal --remote-bucket "b2/helix-cnpg-wal" --replicate "delete,delete-marker,existing-objects" --priority 1

# 6. Monitor status
mc replicate status myminio/velero-backups
# Look for low 'Pending Size' and 0 'Failed'
```

### **Velero Integration: BackupStorageLocation CRD**
```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: minio-bsl
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups
    prefix: backups # Optional: sub-folder within the bucket
  config:
    # Use the internal service URL for communication within the cluster
    s3Url: http://minio.minio-system.svc.cluster.local:9000
    region: us-east-1 # MinIO doesn't use regions, but the field is required
    s3ForcePathStyle: "true"
  credential:
    name: velero-s3-creds # Secret created earlier
    key: cloud
```

### **Loki Integration: values.yaml Snippet**
```yaml
# In your loki helm chart values.yaml
loki:
  storage:
    type: s3
    s3:
      # Use internal service URL
      endpoint: http://minio.minio-system.svc.cluster.local:9000
      bucketNames:
        # Loki will use a single bucket in boltdb-shipper/TSDB mode
        chunks: loki-chunks
      region: us-east-1
      accessKeyId: LOKI_MINIO_ACCESS_KEY
      secretAccessKey: LOKI_MINIO_SECRET_KEY
      s3ForcePathStyle: true
      insecure: true # Set to true if MinIO internal endpoint is http
```

### **CloudNativePG Integration: Cluster CRD Snippet**
```yaml
# In your CloudNativePG Cluster resource
spec:
  # ... other cluster config
  backup:
    barmanObjectStore:
      destinationPath: "s3://cnpg-backups/" # Path for base backups
      endpointURL: "http://minio.minio-system.svc.cluster.local:9000"
      s3Credentials:
        accessKeyId:
          name: cnpg-s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: cnpg-s3-creds
          key: ACCESS_SECRET_KEY
      # WAL archiving settings
      wal:
        compression: gzip
    retentionPolicy: "14d" # Keep base backups for 14 days
```

### **Monitoring: ServiceMonitor for Prometheus Operator**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio-monitor
  namespace: minio-system
  labels:
    release: prometheus # Your prometheus-operator a`label selector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: minio # Label from Bitnami chart service
      app.kubernetes.io/name: minio
  endpoints:
  - port: http-api # The API port name (default is 'http') - check your service
    path: /minio/v2/metrics/cluster
    interval: 30s
  namespaceSelector:
    matchNames:
    - minio-system
```

---

# Harbor

## ## SKILL.md Content
### **Overview**
Harbor is our self-hosted container registry and Helm chart repository. It integrates with MinIO for blob storage, CloudNativePG for its database, and Zitadel for OIDC SSO. Devtron pushes images to it, and ArgoCD pulls images from it.

### **CLI and API Reference**
- **Docker Login (Robot Account)**:
  `docker login harbor.helixstax.net --username 'robot$project+name' --password 'TOKEN'`
- **Docker Login (Human User w/ OIDC)**:
  1. Go to `https://harbor.helixstax.net` -> User Profile
  2. Copy the "CLI secret".
  3. `docker login harbor.helixstax.net --username 'your-zidatel-username' --password 'CLI_SECRET'`
- **Push Image**: `docker push harbor.helixstax.net/helix-stax/my-app:git-sha-12345`
- **Pull Image**: `docker pull harbor.helixstax.net/helix-stax/my-app:git-sha-12345`
- **Helm OCI Login**: `helm registry login harbor.helixstax.net --username 'robot$charts+helm' --password 'TOKEN'`
- **Helm OCI Push**: `helm push my-chart-0.1.0.tgz oci://harbor.helixstax.net/charts`

### **Project Management**
| Project Name | Purpose | Visibility | Key Config | Used By |
| :--- | :--- | :--- | :--- | :--- |
| `helix-stax` | Internal service images | Private | Auto-scan, Block High Vulns | Devtron, ArgoCD |
| `proxy-dockerhub`| Docker Hub cache | Private | Proxy Cache Project | K3s Nodes |
| `proxy-ghcr` | GHCR.io cache | Private | Proxy Cache Project | K3s Nodes |
| `charts` | OCI Helm Charts | Private | Tag Immutability | ArgoCD, Helm CLI |

### **Robot Accounts**
- **Purpose**: Provide non-human access for CI/CD and Kubernetes. Bypasses OIDC.
- **Naming**: `robot$<project_name>+<description>`. Full name is the username.
- **Creation**: UI: `Project -> Robot Accounts -> New Robot Account`. API: `POST /api/v2.0/robots`.
- **Key Accounts for Helix Stax**:
  - `robot$helix-stax+devtron`: Push/Pull permissions. Used by Devtron CI.
  - `robot$helix-stax+argocd`: Pull-only permissions. Used by ArgoCD.
  - `robot$charts+helm`: Push/Pull permissions. Used for publishing Helm charts.

### **Troubleshooting Decision Tree**
- **Symptom: `unauthorized: authentication required` on `docker push/pull`**
  - **Cause**: Wrong credentials, expired robot token, or missing login.
  - **Check**: Run `docker login` again. Verify username/password. Go to Harbor UI and check robot account status (not expired/disabled).
  - **Fix**: Regenerate robot token, update K8s secret/CI vars, and re-run `docker login`.
- **Symptom: `denied: requested access to the resource is denied`**
  - **Cause**: Correct login, but the robot account lacks permission for the action (e.g., push to a pull-only account).
  - **Check**: Harbor UI -> Project -> Robot Accounts -> Edit -> Verify permissions (push, pull).
  - **Fix**: Grant the necessary permissions to the robot account.
- **Symptom: Push/pull hangs, then `timeout` or `unknown: unknown`**
  - **Cause**: Harbor `registry` pod cannot contact its backend (MinIO or Redis/Valkey).
  - **Check**: `kubectl logs -n harbor -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=registry`. Look for connection errors to MinIO or Redis.
  - **Fix**: Troubleshoot MinIO/Valkey. Check network policies. `kubectl exec` into registry pod and `mc ls myminio/harbor-blobs` to test connectivity.
- **Symptom: Harbor UI is slow or `503 Service Unavailable`**
  - **Cause**: `core` pod is down or overloaded. Often due to database connection issues.
  - **Check**: `kubectl get pods -n harbor`. `kubectl logs -n harbor -l app.kubernetes.io/name=harbor,app.kubernetes.io/component=core`.
  - **Fix**: Verify CloudNativePG cluster is healthy. Check Harbor `core` pod resource usage.
- **Symptom: OIDC login fails with `redirect_uri_mismatch`**
  - **Cause**: The redirect URI in Zitadel doesn't exactly match what Harbor is sending.
  - **Check**: In Zitadel, verify the Redirect URI is `https://harbor.helixstax.net/c/oidc/callback`.
  - **Fix**: Update the URI in Zitadel.

## ## reference.md Content
### **API Reference (v2.0)**
Base URL: `https://harbor.helixstax.net/api/v2.0/`
Authentication: Use Basic Auth with a robot account token. `curl -u "robot$name:token" ...`

- **Projects**:
  - `GET /projects`: List projects.
  - `POST /projects`: Create a project.
    - Body: `{ "project_name": "new-project", "public": false, "storage_limit": 10737418240 }` (10GB)
- **Repositories & Artifacts**:
  - `GET /projects/{name}/repositories`: List repositories.
  - `GET /projects/{name}/repositories/{repo}/artifacts`: List artifacts (images/tags).
  - `DELETE /projects/{name}/repositories/{repo}/artifacts/{reference}`: Delete an artifact by tag or digest.
- **Robot Accounts**:
  - `POST /robots`: Create a robot account.
    - Body: `{ "name": "newrobot", "level": "project", "duration": -1, "permissions": [{"kind": "project", "namespace": "my-project", "access": [{"resource": "repository", "action": "pull"}]}] }`
- **Replication**:
  - `POST /replication/policies`: Create a replication rule.
  - `POST /replication/executions`: Trigger a replication.
    - Body: `{ "policy_id": 1 }`
- **Garbage Collection**:
  - `GET /system/gc/schedule`: Get GC schedule.
  - `POST /system/gc/schedule`: Create/update GC schedule.
    - Body: `{ "schedule": { "type": "Manual" | "Daily" | "Weekly" | "Custom", "cron": "0 0 * * *" } }`
  - `POST /system/gc`: Manually trigger a GC run.
- **Vulnerability Scanning**:
  - `POST /projects/{name}/repositories/{repo}/artifacts/{digest}/scan`: Trigger a scan.
  - `GET /projects/{name}/repositories/{repo}/artifacts/{digest}/additions/vulnerabilities`: Get scan results.

### **Deployment Deep Dive**
- **Chart Choice**: Use the official `goharbor/harbor` chart (`https://helm.goharbor.io`). It's designed for customization with external services like MinIO and CloudNativePG, which is our exact use case. The Bitnami chart is less flexible for this.
- **Harbor Components**:
  - `portal`: The UI frontend (Nginx).
  - `core`: The main API service.
  - `registry`: The Docker V2 API implementation. Talks to MinIO.
  - `jobservice`: Runs background jobs (GC, replication, scanning).
  - `trivy`: The vulnerability scanner.
  - `registryctl`: Helper for registry configuration.

### **OIDC: Zitadel Integration Details**
- **Zitadel Application Setup**:
  1.  Create a new Application of type `Web`.
  2.  Authentication Method: `Code`.
  3.  Redirect URIs: `https://harbor.helixstax.net/c/oidc/callback`
  4.  Post Logout URIs: `https://harbor.helixstax.net`
  5.  Enable "Grant Types": `Authorization Code`.
  6.  On the application page, get the `Client ID` and `Client Secret`.
- **Harbor OIDC Configuration (`Administration > Configuration > Authentication`)**:
  - **Auth Mode**: `OIDC`
  - **OIDC Provider Name**: `Zitadel`
  - **OIDC Endpoint**: `https://zitadel.helixstax.com` (Your Zitadel issuer URL)
  - **OIDC Client ID**: (From Zitadel)
  - **OIDC Client Secret**: (From Zitadel)
  - **OIDC Scope**: `openid profile email`
  - **OIDC Verify Cert**: `true` (since Zitadel will have a valid Let's Encrypt cert)
  - **Auto Onboard**: `true`
  - **Admin Groups**: (Optional) `harbor-admins` (A group name from Zitadel to grant admin rights)

### **Garbage Collection and Retention**
- **Workflow**:
  1.  **Retention Policy Runs**: Harbor evaluates rules like "keep the last 5 tags". Tags that don't match are "soft deleted" (untagged). The manifests still exist.
  2.  **Garbage Collection Runs**: The `jobservice` tells the `registry` to start GC. The registry identifies all manifests and blobs that are no longer referenced by any tag. It then sends `DELETE` API calls to MinIO for each unreferenced blob.
- **Verification**: Run `mc du myminio/harbor-blobs` before and after a full GC cycle to see the reclaimed space. The process can take hours for large registries.

### **Security: Cosign & Kyverno**
1.  **Generate a Cosign key pair**: `cosign generate-key-pair`
2.  **Sign an image after push**: `cosign sign --key cosign.key harbor.helixstax.net/helix-stax/my-app:v1.0.0`
3.  **Enable Content Trust in Harbor**: In the `helix-stax` project settings, enable `Enforce content trust`, blocking unsigned images from being pulled.
4.  **Enforce in K3s with Kyverno**: Create a `ClusterPolicy` to validate image signatures at admission time.
    ```yaml
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: check-image-signatures
    spec:
      validationFailureAction: Enforce
      background: false
      rules:
        - name: validate-helix-stax-images
          match:
            any:
            - resources:
                kinds:
                  - Pod
          validate:
            message: "Image signature verification failed."
            imageVerify:
              imageReferences:
              - "harbor.helixstax.net/helix-stax/*"
              key: |-
                -----BEGIN PUBLIC KEY-----
                ...YOUR COSIGN.PUB CONTENT HERE...
                -----END PUBLIC KEY-----
    ```

## ## examples.md Content
### **Deployment: values.yaml for Harbor Helm Chart**
```yaml
# values-harbor.yaml
# helm repo add harbor https://helm.goharbor.io
# helm install harbor harbor/harbor -n harbor --create-namespace -f values-harbor.yaml

expose:
  # Use clusterIP + separate Traefik IngressRoute CRD (traefik expose type does not exist in goharbor/harbor chart)
  type: clusterIP
  clusterIP:
    name: harbor
    ports:
      httpPort: 80
      httpsPort: 443
    # annotations:
    #   traefik.ingress.kubernetes.io/router.middlewares: "default-stripprefix@kubernetescrd,harbor-large-body@kubernetescrd"

externalURL: https://harbor.helixstax.net

# Configure to use external services instead of bundled ones
# Pre-requisites:
# 1. CloudNativePG must have a 'harbor' database created.
#    And a secret 'harbor-db-creds' with 'user' and 'password'.
# 2. MinIO must have a 'harbor-blobs' bucket.
#    And a secret 'harbor-minio-creds' with 'accesskey' and 'secretkey'.
# 3. An external Redis/Valkey must be running.

database:
  type: external
  external:
    host: "harbor-postgres-rw.harbor.svc.cluster.local" # CNPG service name
    port: "5432"
    username: "harbor"
    # Password will be read from existing secret
    # secretName and keys must match what CloudNativePG operator creates
    existingSecret: "harbor.harbor-postgres.credentials"
    pgUserKey: "username"
    pgPasswordKey: "password"
    database: "harbor"
    sslmode: "disable" # For internal cluster communication

redis:
  type: external
  external:
    # Bitnami chart convention: master service is named 'valkey-master'
    addr: "valkey-master.valkey.svc.cluster.local:6379"
    # No password if not set
    # password: ""

# Use MinIO for image storage
persistence:
  enabled: true
  imageChartStorage:
    type: s3
    s3:
      region: us-east-1
      # Use the internal MinIO service endpoint
      regionendpoint: http://minio.minio-system.svc.cluster.local:9000
      bucket: harbor-blobs
      # Store credentials in a dedicated secret
      existingSecret: "harbor-minio-creds"
      accesskeyKey: "accesskey"
      secretkeyKey: "secretkey"
      # IMPORTANT for MinIO
      forcepathstyle: true
      insecureskipverify: true # Because we're using http internally

# Initial admin password from a secret
harborAdminPassword:
  existingSecret: "harbor-admin-password"
  existingSecretKey: "password"

# Enable and configure Trivy scanner
trivy:
  enabled: true
  # Keep CVE database updated automatically
  autoUpdateDB: true
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi

# Resource allocations for core components
core:
  resources:
    requests: { cpu: 200m, memory: 512Mi }
    limits: { cpu: 1000m, memory: 1Gi }
jobservice:
  resources:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 500m, memory: 768Mi }
registry:
  resources:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 500m, memory: 1Gi }
```

### **Runbook: Pre-Flight Checks Before Harbor Install**
```bash
# 1. Create Harbor database user and database in CloudNativePG
# (Typically done by creating a secret that the CNPG operator uses)
kubectl create secret generic harbor-postgres-superuser \
  -n harbor --from-literal=username=harbor --from-literal=password='DB_PASSWORD'

# 2. Create MinIO secret for Harbor
# Get keys from the service account created for Harbor in MinIO
kubectl create secret generic harbor-minio-creds -n harbor \
  --from-literal=accesskey='HARBOR_MINIO_ACCESS_KEY' \
  --from-literal=secretkey='HARBOR_MINIO_SECRET_KEY'

# 3. Create MinIO 'harbor-blobs' bucket
mc mb myminio/harbor-blobs

# 4. Create Harbor admin password secret
kubectl create secret generic harbor-admin-password -n harbor \
  --from-literal=password='INITIAL_ADMIN_PASSWORD'
```

### **Runbook: ArgoCD Integration**
```bash
# 1. Create a pull-only robot account 'robot$helix-stax+argocd' in Harbor UI.
# Get its token.

# 2. Create the docker-registry secret for ArgoCD in the 'argocd' namespace.
ARGOCD_ROBOT_TOKEN="...paste token here..."
kubectl create secret docker-registry harbor-pull-secret \
  --namespace argocd \
  --docker-server=harbor.helixstax.net \
  --docker-username='robot$helix-stax+argocd' \
  --docker-password=$ARGOCD_ROBOT_TOKEN

# 3. Configure ArgoCD to use this secret for the registry.
# Edit the argocd-cm ConfigMap.
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data": {"repositories": "- name: harbor-helix-stax\n  type: helm\n  url: https://harbor.helixstax.net\n  enableOci: true"}}'
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data": {"repository.credentials": "- url: https://harbor.helixstax.net\n  usernameSecret:\n    name: harbor-pull-secret\n    key: .dockerconfigjson"}}'


# 4. In your application pods, add imagePullSecrets.
# Or better, patch the default service account in each relevant namespace.
kubectl patch serviceaccount default -n my-app-namespace \
  -p '{"imagePullSecrets": [{"name": "harbor-pull-secret-in-ns"}]}'
# Note: The secret must be copied to 'my-app-namespace'.
```

### **Runbook: Devtron Integration**
1.  Navigate to Devtron `Global Configurations -> Docker Registries`.
2.  Click `+ Add Docker Registry`.
3.  **Registry URL**: `harbor.helixstax.net`
4.  **Username**: `robot$helix-stax+devtron` (the push-enabled robot account).
5.  **Password**: The token for that robot account.
6.  **Save**.
7.  In your CI build pipeline configuration, select this registry as the `Container Registry`.
8.  Set the `Docker Image` format to `harbor.helixstax.net/helix-stax/$(appName):$(GIT_COMMIT_HASH)`.

---
# Backblaze B2

## ## SKILL.md Content
### **Overview**
Backblaze B2 is our offsite, S3-compatible cold storage for disaster recovery. MinIO replicates critical backups (Velero, CloudNativePG) to B2. It is a Cloudflare Bandwidth Alliance partner, meaning egress from B2 via Cloudflare is free.

### **CLI Reference**
- **S3 API with `mc` (Recommended)**:
  - **Set Alias**: `mc alias set b2 https://s3.us-west-004.backblazeb2.com <KEY_ID> <APP_KEY>`
  - **List Buckets**: `mc ls b2`
  - **List Objects**: `mc ls b2/helix-velero-backups`
  - **Copy from B2 to MinIO**: `mc cp b2/helix-velero-backups/object.dat myminio/velero-backups/`
  - **Diff local vs B2**: `mc diff myminio/velero-backups b2/helix-velero-backups`
- **Native `b2` CLI**:
  - **Authorize**: `b2 authorize-account <KEY_ID> <APP_KEY>`
  - **List Objects**: `b2 ls b2://helix-velero-backups/`

### **Account and Key Management**
- **ALWAYS** use Application Keys, not the Master Key.
- Create a specific Application Key for MinIO replication with permissions scoped **only** to the backup buckets (e.g., `helix-velero-backups`, `helix-cnpg-backups`).
- **Required Permissions for MinIO Replication**: `listBuckets`, `listFiles`, `readFiles`, `writeFiles`, `deleteFiles`.
- **Rotate keys** by creating a new key in B2, updating the MinIO alias (`mc alias set ...`), verifying replication health (`mc replicate status`), and then deleting the old key in B2.

### **Disaster Recovery Restore from B2**
If the MinIO PVC is lost, restore data from B2 into a new, empty MinIO instance.
```bash
# Mirror the entire Velero backup bucket from B2 back to the new MinIO
mc mirror b2/helix-velero-backups myminio/velero-backups

# Verify the restored data
mc du myminio/velero-backups
```

## ## reference.md Content
### **S3-Compatible API Details**
- **Endpoint**: Found in your B2 account's "Buckets" page. It is region-specific, e.g., `s3.us-west-004.backblazeb2.com`. Using the correct endpoint is critical.
- **Authentication**: The B2 Application Key ID maps to `AWS_ACCESS_KEY_ID`. The B2 Application Key itself maps to `AWS_SECRET_ACCESS_KEY`.
- **Using AWS CLI**:
  ```bash
  aws s3 ls s3://helix-velero-backups \
    --endpoint-url https://s3.us-west-004.backblazeb2.com
  ```

### **B2 Lifecycle Rules**
B2 lifecycle rules are used to manage long-term retention and cleanup, acting as a secondary layer to MinIO's own lifecycle rules.
- **Rule Structure**: Configured in the B2 Web UI per bucket.
  - `keepAllVersionsForDays`: (null)
  - `keepOnlyLastForDays`: (e.g., 90) - Hides older versions after 90 days.
  - `daysFromHidingToDeleting`: (e.g., 30) - Deletes files 30 days after they are hidden.
- **Recommended Config for `helix-velero-backups`**:
  - `File Name Prefix`: (empty)
  - `Keep only the last version of the file`
  - `Keep prior versions for this number of days`: `90`

### **Cloudflare Bandwidth Alliance**
- **How it Works**: Traffic from B2 servers to Cloudflare's edge network is not billed for egress by Backblaze. This is automatic.
- **Practical Implication**: When you serve a file from B2 through a Cloudflare-proxied domain (`cdn.helixstax.com`), Backblaze does not charge you for the download bandwidth. You still pay for Class C transactions (S3 API calls) and storage.
- **Hetzner -> B2 Cost**: The alliance does **NOT** cover traffic from Hetzner to B2. MinIO replication (uploads to B2) will incur Hetzner egress fees (approx. €1.19/TB) and B2 Class C transaction fees. This is the primary ongoing cost of the backup strategy.

## ## examples.md Content
### **Runbook: Creating a B2 Application Key for MinIO**
1.  Log in to `backblaze.com`.
2.  Navigate to `App Keys` under your account.
3.  Click `Add a New Application Key`.
4.  **Name of Key**: `minio-replication-key`.
5.  **Allow access to Bucket(s)**: Select `helix-velero-backups`, `helix-cnpg-backups`, and `helix-cnpg-wal`.
6.  **Type of Access**: `Read and Write`.
7.  **File name prefix**: (Leave blank).
8.  **Duration**: (Leave blank for no expiry).
9.  Click `Create New Key`.
10. **CRITICAL**: Copy the `keyID` and `applicationKey` immediately. The `applicationKey
