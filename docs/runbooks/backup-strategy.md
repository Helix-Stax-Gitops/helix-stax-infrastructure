# Backup Strategy

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: ACTIVE
**Platform**: Helix Stax (2-node k3s + CX32 Authentik VM)

---

## Prerequisites

- SSH access to helix-cp-1 (138.201.131.157) and helix-worker-1
- SSH access to CX32 Authentik VM
- `kubectl` configured with cluster kubeconfig
- Hetzner Storage Box credentials (or S3-compatible bucket)
- `restic` installed on backup runner (or CronJob in cluster)

---

## 1. What to Back Up

### 1.1 k3s Cluster State (etcd/SQLite)

| Item | Location | Method | Frequency |
|------|----------|--------|-----------|
| k3s embedded SQLite | `/var/lib/rancher/k3s/server/db/` | `k3s etcd-snapshot save` | Daily 02:00 UTC |
| k3s token | `/var/lib/rancher/k3s/server/token` | File copy | On change |
| k3s TLS certs | `/var/lib/rancher/k3s/server/tls/` | File copy | Weekly |
| k3s manifests | `/var/lib/rancher/k3s/server/manifests/` | File copy | On change |

**Snapshot command:**
```bash
k3s etcd-snapshot save --name daily-$(date +%Y%m%d)
# Snapshots stored at /var/lib/rancher/k3s/server/db/snapshots/
```

### 1.2 Authentik (CX32 VM)

| Item | Location | Method | Frequency |
|------|----------|--------|-----------|
| Authentik PostgreSQL | Docker volume or host path | `pg_dump` via docker exec | Daily 02:30 UTC |
| Authentik media | `/data/authentik/media/` | restic/rsync | Daily |
| Authentik custom templates | `/data/authentik/templates/` | restic/rsync | Daily |
| Docker Compose file | `/opt/authentik/docker-compose.yml` | restic/rsync | On change |
| Authentik `.env` | `/opt/authentik/.env` | restic/rsync (encrypted) | On change |

**PostgreSQL dump command:**
```bash
docker exec -t authentik-postgresql \
  pg_dump -U authentik -d authentik \
  --format=custom \
  --file=/tmp/authentik-$(date +%Y%m%d).dump

docker cp authentik-postgresql:/tmp/authentik-$(date +%Y%m%d).dump \
  /backup/authentik-db/
```

### 1.3 Application PVCs (k3s)

| PVC | Namespace | Size | Method | Frequency |
|-----|-----------|------|--------|-----------|
| Devtron PostgreSQL | devtroncd | ~5Gi | `pg_dump` from pod | Daily 03:00 UTC |
| n8n data | ai-agents | ~1Gi | restic from host path | Daily |
| Ollama models | ai-agents | ~20Gi | restic from host path | Weekly (models rarely change) |
| Open WebUI data | open-webui | ~1Gi | restic from host path | Daily |
| pgvector data | ai-agents | ~2Gi | `pg_dump` from pod | Daily |
| Grafana data | monitoring | ~500Mi | restic from host path | Weekly |

**Devtron PostgreSQL dump:**
```bash
DEVTRON_PG_POD=$(kubectl -n devtroncd get pod -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
kubectl -n devtroncd exec "$DEVTRON_PG_POD" -- \
  pg_dump -U postgres --format=custom -d orchestrator \
  > /backup/devtron-db/devtron-$(date +%Y%m%d).dump
```

### 1.4 Cloudflare Configuration

| Item | Method | Frequency |
|------|--------|-----------|
| DNS records (all 3 domains) | `cf-terraforming` export or API dump | Weekly |
| Page rules / redirect rules | Cloudflare API export | Weekly |
| WAF rules | Cloudflare API export | Weekly |
| Zero Trust config | Cloudflare API export | Weekly |

**Export script (uses Cloudflare API token with read-only scope):**
```bash
for ZONE_ID in $HELIXSTAX_NET_ZONE $HELIXSTAX_COM_ZONE $VACANCYSERVICES_ZONE; do
  curl -s -H "Authorization: Bearer VAULT://cloudflare/api-token-readonly" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    | jq '.result' > /backup/cloudflare/dns-${ZONE_ID}-$(date +%Y%m%d).json
done
```

### 1.5 Git Repositories

All infrastructure code is in `KeemWilliams/helix-stax-infra` on GitHub. GitHub itself provides redundancy. For disaster recovery, maintain a mirror:

```bash
# Weekly mirror to Hetzner Storage Box
git clone --mirror git@github.com:KeemWilliams/helix-stax-infra.git /backup/git-mirror/helix-stax-infra.git
```

---

## 2. Backup Schedule

| Time (UTC) | What | Type |
|------------|------|------|
| 02:00 | k3s snapshot | Incremental (SQLite) |
| 02:30 | Authentik PostgreSQL dump | Full |
| 03:00 | Devtron PostgreSQL dump | Full |
| 03:15 | pgvector dump | Full |
| 03:30 | PVC file backups (restic) | Incremental |
| Sunday 04:00 | Full restic backup of all data | Full |
| 1st of month 05:00 | Monthly archive snapshot | Full |

---

## 3. Retention Policy

| Type | Retention | Storage Est. |
|------|-----------|-------------|
| Daily snapshots | 7 days | ~5 GB |
| Weekly full | 4 weeks | ~20 GB |
| Monthly archive | 3 months | ~15 GB |

Total estimated storage: **~40 GB** (fits in a Hetzner BX11 Storage Box at 1 TB).

---

## 4. Backup Storage

### Primary: Hetzner Storage Box

- Product: BX11 (1 TB, ~3.29 EUR/month)
- Protocol: SFTP / restic over SFTP
- Location: Falkenstein (same DC as servers)
- Encryption: restic handles client-side encryption

**restic repository init:**
```bash
export RESTIC_REPOSITORY="sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/backup/helix-stax"
export RESTIC_PASSWORD="VAULT://backup/restic-password"
restic init
```

### Secondary (recommended): Off-site S3

- Provider: Backblaze B2 or Hetzner Object Storage
- Purpose: Geographic redundancy (protects against DC-level failure)
- Sync: Weekly rsync/rclone from Storage Box

---

## 5. Restore Procedures

### 5.1 Restore k3s Cluster

**Scenario**: Complete k3s server loss on helix-cp-1.

```bash
# 1. Provision new VM (or reinstall AlmaLinux on existing)
# 2. Install k3s with existing token
cat /backup/k3s/token  # Use saved token

curl -sfL https://get.k3s.io | sh -s - server \
  --token "$(cat /backup/k3s/token)" \
  --node-external-ip 138.201.131.157

# 3. Stop k3s
systemctl stop k3s

# 4. Restore snapshot
k3s server --cluster-reset \
  --cluster-reset-restore-path=/backup/k3s/snapshots/daily-YYYYMMDD

# 5. Start k3s
systemctl start k3s

# 6. Verify
kubectl get nodes
kubectl get pods -A
```

**Recovery time**: ~15-30 minutes.

### 5.2 Restore Authentik

**Scenario**: CX32 VM lost or Authentik DB corrupted.

```bash
# 1. Provision CX32 VM, install Docker + Docker Compose
# 2. Copy docker-compose.yml and .env from backup
cp /backup/authentik/docker-compose.yml /opt/authentik/
cp /backup/authentik/.env /opt/authentik/

# 3. Start PostgreSQL only
cd /opt/authentik
docker compose up -d postgresql

# 4. Restore database
docker cp /backup/authentik-db/authentik-YYYYMMDD.dump authentik-postgresql:/tmp/
docker exec -t authentik-postgresql \
  pg_restore -U authentik -d authentik --clean --if-exists /tmp/authentik-YYYYMMDD.dump

# 5. Restore media files
rsync -av /backup/authentik/media/ /data/authentik/media/

# 6. Start all services
docker compose up -d

# 7. Verify login at https://auth.helixstax.net
```

**Recovery time**: ~20-30 minutes.

### 5.3 Restore Devtron PostgreSQL

```bash
# 1. Scale down Devtron API
kubectl -n devtroncd scale deployment devtron --replicas=0

# 2. Copy dump into PostgreSQL pod
DEVTRON_PG_POD=$(kubectl -n devtroncd get pod -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
kubectl -n devtroncd cp /backup/devtron-db/devtron-YYYYMMDD.dump "$DEVTRON_PG_POD":/tmp/

# 3. Restore
kubectl -n devtroncd exec "$DEVTRON_PG_POD" -- \
  pg_restore -U postgres -d orchestrator --clean --if-exists /tmp/devtron-YYYYMMDD.dump

# 4. Scale Devtron back up
kubectl -n devtroncd scale deployment devtron --replicas=1

# 5. Verify Devtron dashboard loads
```

### 5.4 Restore n8n / Open WebUI / pgvector

```bash
# Generic PVC restore via restic
export RESTIC_REPOSITORY="sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/backup/helix-stax"
export RESTIC_PASSWORD="VAULT://backup/restic-password"

# 1. Scale down the deployment
kubectl -n <namespace> scale deployment <name> --replicas=0

# 2. Find the host path for the PVC
kubectl get pv <pv-name> -o jsonpath='{.spec.hostPath.path}'

# 3. Restore from restic
restic restore latest --target /  --path <host-path>

# 4. Scale back up
kubectl -n <namespace> scale deployment <name> --replicas=1
```

---

## 6. Verification Checklist

Run after every restore:

- [ ] All nodes in `Ready` state (`kubectl get nodes`)
- [ ] All pods running (`kubectl get pods -A | grep -v Running | grep -v Completed`)
- [ ] Devtron dashboard accessible
- [ ] Grafana dashboard accessible
- [ ] Authentik login page loads (if restored)
- [ ] n8n workflows list loads
- [ ] Ollama responds to `/api/tags`
- [ ] DNS resolution works for all domains
- [ ] TLS certificates valid (if cert-manager active)

---

## 7. Backup Automation

### CronJob: k3s Snapshots (on helix-cp-1)

Create `/etc/cron.d/k3s-backup`:
```
0 2 * * * root /usr/local/bin/backup-k3s.sh >> /var/log/k3s-backup.log 2>&1
```

### CronJob: Authentik DB (on CX32)

Create `/etc/cron.d/authentik-backup`:
```
30 2 * * * root /usr/local/bin/backup-authentik.sh >> /var/log/authentik-backup.log 2>&1
```

### Backup Monitoring

Add Prometheus alerts for backup freshness:
- Alert if k3s snapshot older than 26 hours
- Alert if Authentik dump older than 26 hours
- Alert if restic repository last modified > 26 hours

See `runbooks/monitoring-alerts.md` for alert definitions.

---

## 8. Disaster Recovery Summary

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| Single pod crash | Minutes | 0 | K8s self-heals |
| PVC data corruption | 30 min | 24 hours | Restore from restic |
| k3s server node loss | 30 min | 24 hours | Re-provision + snapshot restore |
| Authentik VM loss | 30 min | 24 hours | Re-provision + pg_restore |
| Full DC outage | 2-4 hours | 24 hours | Provision at new DC + restore from off-site |
| Ransomware/compromise | 1-2 hours | 24 hours | Fresh provision + restore from off-site encrypted backups |
