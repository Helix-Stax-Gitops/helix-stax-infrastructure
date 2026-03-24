---
template: operational-backup-recovery-plan
category: operational
task_type: backup-plan
clickup_list: "04 Service Management"
auto_tags: ["backup", "recovery", "disaster-recovery", "infrastructure"]
required_fields: ["TLDR", "Service Overview", "Backup Strategy", "Recovery Procedures", "Testing", "Compliance Mapping"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "NIST SP 800-53", "PCI DSS", "HIPAA"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Backup and Disaster Recovery Plan

Use for documenting backup strategy, recovery procedures, and RTO/RPO targets for a service or cluster. Store in `docs/runbooks/backup-recovery/{service-name}-backup-plan.md`.

---

## TLDR

<!-- One sentence: what's being backed up, where, how often, and RTO/RPO targets. -->

Example: Zitadel database backed up hourly to MinIO via Velero; RTO 1 hour, RPO 1 hour. PostgreSQL data restored via point-in-time recovery if needed.

---

## Service Overview

### [REQUIRED] Service Information

| Field | Value |
|-------|-------|
| **Service Name** | |
| **Service Owner** | |
| **Data Classification** | Public / Internal / Confidential / Sensitive |
| **Data Sensitivity** | Low / Medium / High / Critical |
| **Regulatory Requirements** | SOC 2 / HIPAA / PCI DSS / ISO 27001 / GDPR |

### [REQUIRED] RTO & RPO Targets

| Metric | Target | Justification |
|--------|--------|---------------|
| **RTO** (Recovery Time Objective) | ___ minutes | How long users can tolerate downtime |
| **RPO** (Recovery Point Objective) | ___ minutes | How much data loss is acceptable |

---

## Backup Strategy

### [REQUIRED] What Gets Backed Up

| Component | Type | Size (approx.) | Frequency |
|-----------|------|----------------|-----------|
| PostgreSQL database | Full + incremental | ___ GB | Daily full, hourly incremental |
| Persistent volumes | Snapshots | ___ GB | Daily |
| Configuration | Git snapshots | ___ MB | On every config change |
| Secrets | Encrypted export | ___ MB | Manual (never automated) |
| Application state | Velero backups | ___ GB | Daily |

### [REQUIRED] Backup Destinations

| Destination | Path | Retention | Notes |
|-------------|------|-----------|-------|
| MinIO (primary) | s3://backups/prod/{service}/ | 30 days | On-cluster, fast restore |
| Backblaze B2 (offsite) | s3://helix-stax-backups/{service}/ | 90 days | Geographically separated |
| Cold storage | Archive | 1 year | Compliance archival |

### [OPTIONAL] Backup Frequency & Window

- **Full backup**: Daily at 02:00 UTC (low-traffic window)
- **Incremental backup**: Hourly (00, 60, 120 min after full)
- **Configuration backup**: On every git commit to main
- **Secrets backup**: Manual, encrypted, stored offline

### [OPTIONAL] Backup Tooling

- **Velero**: Application-aware Kubernetes backups (PVCs, ConfigMaps, Secrets)
- **Automated PostgreSQL backups**: CloudNativePG WAL archiving to MinIO
- **Git history**: Immutable config history in GitHub
- **Manual exports**: Encrypted database dumps for compliance archival

---

## Recovery Procedures

### [REQUIRED] Full Cluster Recovery

**Use this if the entire cluster is lost.**

**Prerequisites**:
- [ ] Offsite backups verified to be intact in Backblaze B2
- [ ] New cluster provisioned with same networking
- [ ] OpenBao unseal keys and recovery codes accessible
- [ ] Access to root credentials in secure vault

**Steps**:

1. **Provision new cluster** (via OpenTofu):
   ```bash
   cd terraform/prod
   terraform apply -var "restore_mode=true"
   # Wait for K3s to initialize and Traefik to be ready
   ```

2. **Restore Velero backup** (from MinIO):
   ```bash
   velero restore create --from-backup {backup-name} --wait
   velero restore logs {restore-name}  # Monitor progress
   ```

3. **Restore PostgreSQL databases** (from WAL archive):
   ```bash
   # Deploy CloudNativePG cluster
   kubectl apply -f helm/postgresql/restore-values.yaml

   # Point recovery to specific backup
   kubectl annotate cluster postgresql-prod restore-point="2026-03-21T02:00:00Z"

   # Monitor recovery
   kubectl get cnpg postgresql-prod
   ```

4. **Verify data integrity**:
   ```bash
   # Connect to restored database
   kubectl port-forward -n default svc/postgresql-prod 5432:5432
   psql -U postgres -d postgres -c "SELECT version();"
   ```

5. **Unseal secrets** (OpenBao):
   ```bash
   kubectl exec -n security deployment/openbao -- bao operator unseal {key1} {key2} {key3}
   ```

6. **Restore application secrets** (External Secrets Operator):
   ```bash
   kubectl delete secret -n {namespace} --all
   kubectl annotate externalsecretsync -n security sync.spec.refreshInterval="1s"
   # Wait for External Secrets to pull from OpenBao
   ```

7. **Verify cluster health**:
   ```bash
   kubectl get nodes -o wide
   kubectl get pods --all-namespaces | grep -E "(Error|CrashLoop)"
   kubectl get svc --all-namespaces
   ```

**Expected duration**: 30-60 minutes

**Restore verification checklist**:
- [ ] All nodes healthy and ready
- [ ] All critical pods running
- [ ] PostgreSQL accepting connections
- [ ] Application services responding
- [ ] Monitoring/Loki showing current data
- [ ] No data loss visible (spot-check databases)

### [REQUIRED] Single Service Recovery

**Use this if a specific application needs recovery.**

1. **Identify backup timestamp**:
   ```bash
   velero backup get
   velero backup describe {backup-name}
   ```

2. **Restore specific namespace**:
   ```bash
   velero restore create --from-backup {backup-name} \
     --include-namespaces {namespace} \
     --wait
   ```

3. **Restore specific PersistentVolumes**:
   ```bash
   # If Velero restore didn't restore data
   velero restore logs {restore-name}
   # Check for failed PVs and manually restore from MinIO
   kubectl get pvc -n {namespace}
   ```

4. **Verify application startup**:
   ```bash
   kubectl rollout status deployment/{deployment} -n {namespace}
   kubectl logs -n {namespace} deployment/{deployment} --tail=50
   ```

**Expected duration**: 10-20 minutes

### [OPTIONAL] Database Point-in-Time Recovery (PITR)

**Use this if you need to recover to a specific moment in time.**

```bash
# List available recovery points
kubectl get backups.postgresql.cnpg.io -n default -o wide

# Create recovery by specifying target time
kubectl patch cnpg postgresql-prod --type merge -p '{
  "spec": {
    "bootstrap": {
      "recovery": {
        "sourceClusterExternalClusterName": "postgresql-prod-backup",
        "recoveryTarget": {
          "targetTime": "2026-03-21T15:30:00Z"
        }
      }
    }
  }
}'

# Monitor recovery progress
kubectl logs -n default statefulset/postgresql-prod
```

---

## Testing & Validation

### [REQUIRED] Backup Verification Schedule

- **Monthly**: Restore a backup to staging, verify data integrity
- **Quarterly**: Full cluster recovery drill (on non-production)
- **Annually**: Offsite backup restoration from Backblaze B2

### [REQUIRED] Recovery Testing Log

| Date | Test Type | Result | Notes |
|------|-----------|--------|-------|
| YYYY-MM-DD | Single-service restore | ✓ / ✗ | Took 15 min, all data present |
| YYYY-MM-DD | Database PITR | ✓ / ✗ | Recovered to 2h before failure |
| YYYY-MM-DD | Full cluster restore | ✓ / ✗ | Took 45 min, one PVC needed manual intervention |

### [OPTIONAL] Failure Scenarios Tested

- [ ] Single pod deletion
- [ ] Node failure (kill node, rebuild)
- [ ] Database corruption (truncate table, recover)
- [ ] Complete cluster loss (provision new, restore)
- [ ] Storage loss (restore from offsite backup)

---

## Compliance & Governance

### [REQUIRED] Backup Encryption

- [ ] Backups encrypted in transit (TLS)
- [ ] Backups encrypted at rest (AES-256)
- [ ] Encryption keys stored in OpenBao
- [ ] Key rotation policy: __________ (quarterly/annually)

### [REQUIRED] Access Controls

| Role | Access | Frequency | Notes |
|------|--------|-----------|-------|
| SRE Team | Restore service/cluster | Per incident | Via Rocket.Chat bot |
| Security Team | Backup integrity audit | Quarterly | Verify encryption, retention |
| Compliance Team | Restore testing evidence | Annually | For SOC 2 audit |

### [REQUIRED] Documentation & Runbooks

- [ ] Runbook for each recovery scenario (Full cluster, single service, PITR)
- [ ] Runbook stored in `docs/runbooks/recovery/`
- [ ] Runbook tested and verified to work (monthly)
- [ ] Contact list for on-call escalation (backup owner, DBA, SRE lead)

### [REQUIRED] Compliance Mapping

| Framework | Control | Requirement | How This Plan Satisfies It |
|-----------|---------|-------------|---------------------------|
| SOC 2 | A1.2 | Availability and resilience | Daily backups with RTO/RPO targets |
| SOC 2 | A1.3 | Disaster recovery | Documented recovery procedures, regular testing |
| ISO 27001 | A.12.3.1 | Information backup | Automated daily backups to redundant locations |
| NIST CSF | RC.RP-1 | Recovery processes documented | Recovery runbooks maintained |
| NIST SP 800-53 | CP-9 | Information system backup | Backups on-site and offsite, tested quarterly |
| PCI DSS 3.4 | Data backup | Encryption at rest and in transit | All backups encrypted AES-256 |
| HIPAA | 45 CFR § 164.308(a)(7) | Disaster recovery plan | Documented with testing cadence |

---

## Contacts & Escalation

| Role | Name | Email | Phone |
|------|------|-------|-------|
| **Service Owner** | | | |
| **Backup Administrator** | | | |
| **On-Call SRE** | | | |
| **Compliance Lead** | | | |

**Escalation**: If recovery fails after 30 minutes, page on-call SRE and security team lead.

---

## Review & Maintenance

- [ ] Plan reviewed quarterly
- [ ] Backup procedures tested monthly
- [ ] Recovery tested at least annually
- [ ] RTO/RPO targets reviewed annually
- [ ] Offsite backup integrity verified quarterly

**Last recovery test**: ___________
**Last plan review**: ___________
**Next scheduled test**: ___________

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Internal |
