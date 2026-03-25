# Helm Services

**Last Updated**: 2026-03-25

All production services deploy via Helm through Devtron CD. Values files live in `helm/{service}/values.yaml`. No Docker Compose in production.

## Services Overview

| Service | Namespace | Chart | Purpose | Depends On |
|---------|-----------|-------|---------|-----------|
| cloudnativepg | database | cloudnative-pg/cloudnative-pg | PostgreSQL operator + cluster | — |
| valkey | production | bitnami/valkey | Cache (Redis-compatible, BSD license) | — |
| minio | storage | minio/minio | S3-compatible object storage | — |
| harbor | registry | harbor/harbor | Container image registry + Trivy scanning | — |
| zitadel | identity | zitadel/zitadel | OIDC/SAML identity provider | CloudNativePG |
| devtron | devtroncd | devtron/devtron-operator | CI/CD platform (ArgoCD-backed) | CloudNativePG |
| rocketchat | comms | rocketchat/rocketchat | Team chat (bundled MongoDB) | Zitadel (OIDC, post-deploy) |
| ollama | ai | ollama-helm/ollama | Local LLM inference (CPU) | — |
| open-webui | ai | open-webui/open-webui | Chat UI for Ollama | Ollama |
| velero | velero | vmware-tanzu/velero | Cluster backup to MinIO | MinIO |

## Service Details

### CloudNativePG

**Values**: `helm/cloudnativepg/cluster-devtron.yaml` (Cluster CRD, apply with `kubectl apply -f`)

| Field | Value |
|-------|-------|
| Cluster name | `helix-pg` |
| Namespace | `database` |
| PostgreSQL version | 18.1 |
| Instances | 1 (single-node) |
| Storage | 10Gi, local-path |
| Initial database | `devtron` (owner: `devtron`) |

**Auto-created secrets** (in `database` namespace):

| Secret | Contents |
|--------|----------|
| `helix-pg-app` | App credentials (user=devtron, password, URI) |
| `helix-pg-ca` | CA certificate |
| `helix-pg-server` | Server TLS cert |
| `helix-pg-replication` | Replication TLS cert |

**Connection endpoints**:
- Read-write: `helix-pg-rw.database.svc.cluster.local:5432`
- Read-only: `helix-pg-ro.database.svc.cluster.local:5432`

**Additional databases** (create manually before deploying Devtron):
```bash
kubectl exec -n database helix-pg-1 -- psql -U postgres -c "CREATE DATABASE lens OWNER devtron;"
kubectl exec -n database helix-pg-1 -- psql -U postgres -c "CREATE DATABASE git_sensor OWNER devtron;"
kubectl exec -n database helix-pg-1 -- psql -U postgres -c "CREATE DATABASE casbin OWNER devtron;"
kubectl exec -n database helix-pg-1 -- psql -U postgres -c "CREATE DATABASE clairv4 OWNER devtron;"
```

---

### Valkey

**Values**: `helm/valkey/values.yaml`

| Field | Value |
|-------|-------|
| Mode | Standalone |
| Auth | Disabled (cluster-internal use only) |
| Storage | 1Gi, local-path |
| Resources | 100m/256Mi req, 250m/512Mi limit |

**Secrets required before deploy**: None (auth disabled).

**Note**: Valkey is the Linux Foundation fork of Redis (BSD license). Harbor bundles its own Redis — Valkey is available for other services that need caching.

---

### MinIO

**Values**: `helm/minio/values.yaml`

| Field | Value |
|-------|-------|
| Mode | Standalone |
| API port | 9000 |
| Console port | 9001 |
| Storage | 20Gi, local-path |
| Ingress | Disabled (Traefik IngressRoute) |

**Secrets required before deploy**:
```bash
kubectl create secret generic minio-credentials -n storage \
  --from-literal=rootUser="admin" \
  --from-literal=rootPassword="$(openssl rand -base64 24)"
```

**Used by**:
- Velero: backup target (bucket `velero`, created on first backup run)
- Loki: optional log storage (currently filesystem)
- Harbor: optional registry storage (currently local PVC)

---

### Harbor

**Values**: `helm/harbor/values.yaml`

| Field | Value |
|-------|-------|
| External URL | https://harbor.helixstax.net |
| TLS | Disabled (terminated at Traefik/Cloudflare) |
| Database | Internal (bundled PostgreSQL) |
| Cache | Internal (bundled Redis) |
| Registry storage | 10Gi, local-path |
| Trivy scanning | Enabled |
| ChartMuseum | Disabled (OCI push used instead) |

**Secrets required before deploy**:
```bash
kubectl create secret generic harbor-admin-secret -n registry \
  --from-literal=HARBOR_ADMIN_PASSWORD="$(openssl rand -base64 24)"
```

**Note**: Harbor uses its own internal PostgreSQL and Redis instances, not the shared CNPG cluster or Valkey. This simplifies operation at the cost of additional resource usage (~128Mi + 64Mi).

---

### Zitadel

**Values**: `helm/zitadel/values.yaml`

| Field | Value |
|-------|-------|
| External domain | zitadel.helixstax.net |
| TLS | Disabled (terminated at Traefik/Cloudflare) |
| Database | CloudNativePG `helix-pg` (external) |
| DB host | `helix-pg-rw.database.svc.cluster.local:5432` |
| Storage | 1Gi, local-path (key backup) |
| Init job | Enabled (creates first admin user) |

**Secrets required before deploy**:
```bash
# Master key (required — minimum 32 bytes)
kubectl create secret generic zitadel-masterkey -n identity \
  --from-literal=masterkey="$(openssl rand -base64 32)"

# DB credentials
kubectl create secret generic zitadel-db-secret -n identity \
  --from-literal=user-password="<password>" \
  --from-literal=admin-password="<password>"
```

**PostgreSQL database** must exist before deploy:
```bash
kubectl exec -n database helix-pg-1 -- psql -U postgres \
  -c "CREATE DATABASE zitadel OWNER devtron;"
```

**Post-deploy**: Configure OIDC clients for each service (Devtron, Rocket.Chat, Open WebUI, Grafana) via the Zitadel admin UI.

---

### Devtron

**Values**: `helm/devtron/values.yaml`

| Field | Value |
|-------|-------|
| Module | cicd (ArgoCD-backed CD) |
| DB host | `helix-pg-rw.database.svc.cluster.local` |
| DB user | `postgres` (superuser — required for migrations) |
| ArgoCD | Disabled (Devtron manages its own internal ArgoCD) |

**Prerequisites** (must exist before `helm install`):
1. CNPG `helix-pg` cluster running
2. Databases created: `orchestrator`, `lens`, `git_sensor`, `casbin`, `clairv4`
3. `postgres` superuser password set to match `PG_PASSWORD` in values
4. Four Kubernetes resources pre-created in `devtroncd` namespace (Devtron pre-install hook bug):
   - ServiceAccount `devtron-default-sa`
   - ConfigMap `devtron-cm`
   - ConfigMap `devtron-custom-cm`
   - ConfigMap `devtron-common-cm`

**Install command**:
```bash
PG_PASSWORD=$(kubectl -n database get secret helix-pg-app -o jsonpath='{.data.password}' | base64 -d)
helm upgrade --install devtron devtron/devtron-operator \
  --namespace devtroncd \
  --set global.externalPostgres.PG_PASSWORD="$PG_PASSWORD" \
  -f helm/devtron/values.yaml \
  --timeout 10m
```

---

### Rocket.Chat

**Values**: `helm/rocketchat/values.yaml`

| Field | Value |
|-------|-------|
| Host | rocketchat.helixstax.net |
| Database | Bundled MongoDB (standalone) |
| MongoDB storage | 5Gi, local-path |
| App storage | 5Gi, local-path |
| SMTP | Disabled (configure via admin UI post-deploy) |

**Secrets required before deploy**:
```bash
kubectl create secret generic rocketchat-mongodb-secret -n comms \
  --from-literal=mongodb-passwords="<password>" \
  --from-literal=mongodb-root-password="<root-password>"
```

**Post-deploy**: Configure Zitadel OIDC via Rocket.Chat admin UI:
Admin > OAuth > Add custom OAuth > provider: Zitadel

---

### Ollama

**Values**: `helm/ollama/values.yaml`

| Field | Value |
|-------|-------|
| GPU | Disabled (CPU-only on current nodes) |
| Models pre-pulled | `llama3.2:3b` (~2GB), `nomic-embed-text` (~274MB) |
| Model storage | 20Gi, local-path |
| Service port | 11434 (ClusterIP — internal only) |
| Ingress | Disabled (accessed by Open WebUI via ClusterIP) |
| Resources | 500m/2Gi req, 2000m/4Gi limit |

**Secrets required before deploy**: None.

**Note**: CPU inference is slow for large models. `llama3.2:3b` is the recommended starting model on CPU-only nodes. Startup takes up to 60 seconds for model loading — liveness probe accounts for this (`initialDelaySeconds: 60`).

---

### Open WebUI

**Values**: `helm/open-webui/values.yaml`

| Field | Value |
|-------|-------|
| Ollama URL | `http://ollama.ai.svc.cluster.local:11434` |
| Bundled Ollama | Disabled (uses in-cluster Ollama service) |
| Storage | 2Gi, local-path |
| Service port | 8080 |
| Pipelines | Disabled |

**Secrets required before deploy**: None.

**Post-deploy**: Configure Zitadel OIDC via admin panel:
Admin > Settings > Auth > OpenID Connect

---

### Velero

**Values**: `helm/velero/values.yaml`

| Field | Value |
|-------|-------|
| Backend | MinIO (S3-compatible, in-cluster) |
| Bucket | `velero` (created by Velero on first backup) |
| MinIO URL | `http://minio.storage.svc.cluster.local:9000` |
| Schedule | Nightly at 02:00 UTC |
| Retention | 7 days (168h TTL) |
| Volume backup | Filesystem backup via kopia (no CSI snapshots on local-path) |
| Node agent | Enabled (required for filesystem backup) |

**Secrets required before deploy**:
```bash
kubectl create secret generic velero-s3-credentials -n velero \
  --from-literal=cloud="[default]
aws_access_key_id=<minio-user>
aws_secret_access_key=<minio-password>"
```

**Excluded namespaces**: `kube-system`, `kube-public`, `kube-node-lease`

**Verify backup ran**:
```bash
kubectl -n velero get backups
```

---

## Deployment Order

Deploy in this sequence. Each service must reach `Running` state before its dependents start.

```
Stage 1 (no dependencies — deploy in parallel):
  cloudnativepg operator
  valkey
  minio
  harbor

Stage 2 (requires Stage 1 complete):
  helix-pg cluster (CNPG CRD)  — requires cloudnativepg operator

Stage 3 (requires helix-pg cluster):
  zitadel                       — requires helix-pg
  devtron                       — requires helix-pg

Stage 4 (requires Stage 3):
  rocketchat                    — OIDC from zitadel (configurable post-deploy)
  ollama                        — no strict dependency, but Stage 3 should be stable

Stage 5 (requires Stage 4):
  open-webui                    — requires ollama
  velero                        — requires minio (deploy anytime after Stage 1)
  prometheus-stack              — no strict dependency
```

## Secrets Summary

| Service | Secret Name | Namespace | Key Fields |
|---------|------------|-----------|-----------|
| MinIO | `minio-credentials` | storage | `rootUser`, `rootPassword` |
| Harbor | `harbor-admin-secret` | registry | `HARBOR_ADMIN_PASSWORD` |
| Zitadel | `zitadel-masterkey` | identity | `masterkey` |
| Zitadel | `zitadel-db-secret` | identity | `user-password`, `admin-password` |
| Rocket.Chat | `rocketchat-mongodb-secret` | comms | `mongodb-passwords`, `mongodb-root-password` |
| Velero | `velero-s3-credentials` | velero | `cloud` (AWS credentials format) |

## Related

- [devtron-config.md](devtron-config.md) — How to deploy through Devtron
- [cluster-topology.md](cluster-topology.md) — Node layout and workload placement
- `helm/` — All Helm values files
