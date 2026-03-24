---
title: Dual Workflow Engine Architecture
author: Wakeem Williams
co_author: Quinn Mercer
date: 2026-03-23
status: Active
version: "1.0"
compliance_frameworks:
  - SOC 2 (CC7.2, CC8.1)
  - ISO 27001:2022 (A.8.15, A.8.34)
  - NIST CSF 2.0 (DE.CM-1, DE.CM-3)
references:
  - ADR-007 (KubernetesExecutor for Airflow)
  - ADR-008 (Dual workflow engine)
  - docs/architecture/compliance-scanning-architecture.md
  - docs/architecture/secrets-lifecycle-architecture.md
---

# Dual Workflow Engine Architecture

## 1. Overview

Helix Stax operates two workflow engines with clearly defined responsibilities (ADR-008):

- **Apache Airflow**: Scheduled, auditable compliance operations with persistent state
- **n8n**: Event-driven real-time integrations, notifications, and SaaS glue

This separation ensures that compliance-critical workflows have the auditability and retry semantics required by SOC 2 auditors, while real-time integrations remain lightweight and responsive.

---

## 2. Decision Framework: When n8n vs When Airflow

### 2.1 Decision Tree

```
Is this workflow triggered by a schedule/cron?
  |
  +-- YES --> Does it need auditable task-level logs?
  |             |
  |             +-- YES --> AIRFLOW
  |             +-- NO  --> Could be either; prefer AIRFLOW
  |                         if compliance-adjacent
  |
  +-- NO --> Is it triggered by a webhook/event?
               |
               +-- YES --> Does it need retries + backfill?
               |             |
               |             +-- YES --> AIRFLOW (sensor trigger)
               |             +-- NO  --> n8n
               |
               +-- NO --> Is it a SaaS integration?
                            |
                            +-- YES --> n8n
                            +-- NO  --> Evaluate case by case
```

### 2.2 Boundary Matrix

| Attribute | n8n | Apache Airflow |
|-----------|-----|----------------|
| **Trigger model** | Event-driven (webhooks, polls) | Time-based (cron) or sensor-based |
| **Audit quality** | Low (ephemeral execution logs) | High (immutable task-level logs, XCom) |
| **State management** | Ephemeral (no built-in backfill) | Persistent (retries, backfills, SLAs) |
| **Execution model** | Node.js process (in-container) | KubernetesExecutor (ephemeral pods) |
| **UI complexity** | Low-code visual builder | Python DAGs (code-first) |
| **Best for** | Alerts, ClickUp tasks, SaaS glue, notifications | Ansible drift, log archival, key rotation, scanning |
| **Compliance role** | Notification delivery channel | Evidence generation engine |
| **Failure handling** | Basic retry (configurable) | Advanced (retry policies, SLAs, callbacks) |

### 2.3 Boundary Rules

| Workflow | Engine | Rationale |
|----------|--------|-----------|
| Compliance scanning orchestration | Airflow | Auditable, retryable, scheduled |
| Configuration drift detection | Airflow | Ansible --check needs persistent state |
| Backup verification | Airflow | Velero restore tests need retry semantics |
| Secret rotation orchestration | Airflow | Must be auditable for SOC 2 |
| Alert routing to Rocket.Chat | n8n | Real-time, event-driven |
| ClickUp task creation from alerts | n8n | SaaS integration, webhook-triggered |
| Hetzner API monitoring | n8n | Event-driven, low audit requirement |
| Cloudflare Secrets Store sync | n8n | Webhook-triggered by Airflow |
| GitHub webhook processing | n8n | Event-driven |
| Grafana alert forwarding | n8n | Real-time notification relay |

---

## 3. Integration Architecture

### 3.1 Airflow -> n8n Bridge

Airflow delegates notification and SaaS integration to n8n via `SimpleHttpOperator`.

```
+--------------------------------------------+
|  Apache Airflow (Scheduler + Executor)     |
|                                            |
|  +--------------------------------------+  |
|  |  DAG: compliance_scanning            |  |
|  |    task_1: ssh_oscap_scan            |  |
|  |    task_2: hash_results              |  |
|  |    task_3: upload_to_minio           |  |
|  |    task_4: notify_n8n  <--- bridge   |  |
|  +--------------------------------------+  |
|              |                              |
|              | SimpleHttpOperator           |
|              | POST /webhook/airflow-notify |
|              v                              |
+--------------------------------------------+
              |
              v
+--------------------------------------------+
|  n8n (Event Processor)                     |
|                                            |
|  +--------------------------------------+  |
|  |  Workflow: airflow-notify            |  |
|  |    node_1: Webhook (receive)         |  |
|  |    node_2: Route by event_type       |  |
|  |    node_3a: Rocket.Chat message      |  |
|  |    node_3b: ClickUp task create      |  |
|  |    node_3c: Grafana annotation       |  |
|  +--------------------------------------+  |
+--------------------------------------------+
```

### 3.2 Webhook Contract

Airflow -> n8n webhook payload:

```json
{
  "event_type": "scan_complete | drift_detected | backup_verified | rotation_complete",
  "source_dag": "compliance_scanning",
  "source_task": "upload_to_minio",
  "timestamp": "2026-03-23T01:15:00Z",
  "node": "helix-stax-cp",
  "status": "success | failure",
  "details": {
    "tool": "openscap",
    "score": 94,
    "pass_count": 188,
    "fail_count": 12,
    "evidence_path": "s3://compliance-evidence/2026/03/openscap/helix-stax-cp/arf-results-2026-03-23.xml",
    "evidence_hash": "a1b2c3d4e5f6..."
  },
  "severity": "info | warning | critical"
}
```

### 3.3 n8n Webhook Endpoints

| Endpoint | Trigger Source | Action |
|----------|---------------|--------|
| `/webhook/airflow-notify` | Airflow SimpleHttpOperator | Route to Rocket.Chat/ClickUp |
| `/webhook/secret-rotation` | Airflow rotation DAG | Sync to Cloudflare Secrets Store |
| `/webhook/drift-alert` | Airflow drift DAG | Alert + ClickUp task |
| `/webhook/backup-result` | Airflow backup DAG | Alert + evidence log |

---

## 4. Airflow DAG Inventory

### 4.1 DAG: Compliance Scanning (`dag_compliance_scanning`)

**Schedule**: Weekly (Sunday 01:00 UTC)
**Purpose**: Run OpenSCAP CIS L1 scan on both nodes, hash results, archive to MinIO

```
dag_compliance_scanning
  |
  +--> [SSH] oscap_scan_cp        Run OpenSCAP on helix-stax-cp
  |         |
  |         +--> hash_results_cp  SHA-256 hash of ARF XML
  |                |
  |                +--> upload_cp  Upload to MinIO (Object Lock)
  |
  +--> [SSH] oscap_scan_vps       Run OpenSCAP on helix-stax-vps
  |         |
  |         +--> hash_results_vps SHA-256 hash of ARF XML
  |                |
  |                +--> upload_vps Upload to MinIO (Object Lock)
  |
  +--> [Join] notify_n8n          POST to n8n /webhook/airflow-notify
  |
  +--> [Join] update_dashboard    Write scan metadata to PostgreSQL
```

**Retry policy**: 2 retries, 5-minute delay
**SLA**: Must complete within 30 minutes
**On failure**: n8n alert to #compliance-alerts

### 4.2 DAG: Drift Detection (`dag_drift_detection`)

**Schedule**: Daily (04:00 UTC)
**Purpose**: Run Ansible --check --diff, Lynis, and AIDE on both nodes

```
dag_drift_detection
  |
  +--> [SSH] ansible_check_cp     Ansible --check --diff on CP
  |         |
  |         +--> parse_diff_cp    Parse for actual changes
  |
  +--> [SSH] ansible_check_vps    Ansible --check --diff on VPS
  |         |
  |         +--> parse_diff_vps   Parse for actual changes
  |
  +--> [SSH] lynis_cp             Lynis audit on CP
  |         |
  |         +--> scrape_score_cp  Extract hardening index
  |
  +--> [SSH] lynis_vps            Lynis audit on VPS
  |         |
  |         +--> scrape_score_vps Extract hardening index
  |
  +--> [SSH] aide_cp              AIDE --check on CP
  |
  +--> [SSH] aide_vps             AIDE --check on VPS
  |
  +--> [Join] evaluate_drift      Compare results to baseline
  |         |
  |         +--> [Branch] drift_found?
  |                |
  |                +--> YES: notify_drift    POST to n8n /webhook/drift-alert
  |                +--> NO:  log_clean       Record clean scan
  |
  +--> [Join] archive_results     Upload all results to MinIO
  |
  +--> [Join] update_dashboard    Write metrics to PostgreSQL
```

**Retry policy**: 2 retries, 3-minute delay
**SLA**: Must complete within 20 minutes
**On failure**: n8n alert to #compliance-alerts

### 4.3 DAG: Backup Verification (`dag_backup_verification`)

**Schedule**: Weekly (Saturday 03:00 UTC)
**Purpose**: Verify Velero backups by performing a test restore

```
dag_backup_verification
  |
  +--> list_backups               Query Velero for latest backup
  |         |
  |         +--> restore_test     Velero restore to test namespace
  |                |
  |                +--> health_check   Verify restored resources
  |                       |
  |                       +--> cleanup  Delete test namespace
  |                              |
  |                              +--> report  Generate verification report
  |                                     |
  |                                     +--> archive  Upload to MinIO
  |                                            |
  |                                            +--> notify  POST to n8n
```

**Retry policy**: 1 retry, 10-minute delay
**SLA**: Must complete within 45 minutes
**On failure**: n8n alert to #infra-alerts (backup failure is HIGH severity)

---

## 5. n8n Workflow Inventory

### 5.1 Alert Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| Airflow Notification Router | Webhook: /webhook/airflow-notify | Route by severity to Rocket.Chat channels |
| Drift Alert Handler | Webhook: /webhook/drift-alert | Rocket.Chat alert + ClickUp task in Security Ops |
| Backup Result Handler | Webhook: /webhook/backup-result | Rocket.Chat alert + evidence log |

### 5.2 Integration Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| Secret Rotation Sync | Webhook: /webhook/secret-rotation | Fetch from OpenBao -> PUT to Cloudflare Secrets Store API |
| Hetzner API Monitor | Schedule: every 15min | Check Hetzner Robot API for events -> Rocket.Chat |
| GitHub Webhook Handler | Webhook: /webhook/github | Process push/PR events -> Rocket.Chat + ClickUp |
| Grafana Alert Forwarder | Webhook: /webhook/grafana-alert | Forward Grafana alerts -> Rocket.Chat + ClickUp |

### 5.3 SaaS Glue Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| ClickUp Task Creator | Webhook (various) | Create ClickUp tasks from various event sources |
| Rocket.Chat Bot | Webhook | Process slash commands for infra status queries |
| Certificate Expiry Watcher | Schedule: daily | Check cert-manager certs, alert 14 days before expiry |

---

## 6. Airflow on K3s Architecture

### 6.1 KubernetesExecutor (ADR-007)

Airflow uses the KubernetesExecutor instead of CeleryExecutor for resource efficiency on a 2-node cluster.

```
+--------------------------------------------------+
|  K3s Cluster                                     |
|                                                  |
|  +--------------------------------------------+  |
|  |  airflow namespace                         |  |
|  |                                            |  |
|  |  +------------------+  +-----------------+ |  |
|  |  |  Scheduler Pod   |  |  Webserver Pod  | |  |
|  |  |  (persistent)    |  |  (persistent)   | |  |
|  |  +------------------+  +-----------------+ |  |
|  |         |                                  |  |
|  |         | Spawns ephemeral pods per task    |  |
|  |         v                                  |  |
|  |  +------------------+  +-----------------+ |  |
|  |  |  Task Pod 1      |  |  Task Pod 2     | |  |
|  |  |  (oscap scan)    |  |  (aide check)   | |  |
|  |  |  [ephemeral]     |  |  [ephemeral]    | |  |
|  |  +------------------+  +-----------------+ |  |
|  |                                            |  |
|  +--------------------------------------------+  |
|                                                  |
|  PostgreSQL (CloudNativePG) -- Airflow metadata  |
+--------------------------------------------------+
```

**Key benefits**:
- No persistent Celery workers consuming resources when idle
- Each task gets a fresh pod (clean environment, no state bleed)
- Task pods auto-terminate after completion
- Resource requests/limits per task type (scanning tasks get more CPU)

### 6.2 git-sync Sidecar for DAG Deployment

DAGs are stored in the infra repo and synced to the Airflow scheduler via a git-sync sidecar.

```
+------------------------------------------------+
|  Airflow Scheduler Pod                         |
|                                                |
|  +------------------+  +--------------------+  |
|  |  scheduler       |  |  git-sync sidecar  |  |
|  |  container       |  |  container         |  |
|  |                   |  |                    |  |
|  |  reads DAGs from  |  |  clones/pulls     |  |
|  |  /dags/           |<-|  infra repo        |  |
|  |                   |  |  -> /dags/         |  |
|  +------------------+  +--------------------+  |
+------------------------------------------------+

git-sync config:
  repo:     github.com/KeemWilliams/helix-stax-infrastructure
  branch:   main
  subpath:  airflow/dags/
  interval: 60s
  depth:    1
```

**GitOps flow**:
1. Developer pushes DAG changes to infra repo
2. git-sync detects new commit within 60 seconds
3. Scheduler picks up new/modified DAGs
4. No manual deployment or restart required

### 6.3 Airflow Authentication

Airflow webserver integrates with Zitadel via OIDC for single sign-on.

| Config | Value |
|--------|-------|
| Auth backend | `airflow.providers.fab.auth_manager.fab_auth_manager` |
| OIDC provider | Zitadel |
| Admin role mapping | Wakeem -> Admin |
| Default role | Viewer (read-only DAG access) |

---

## 7. Monitoring and Observability

### 7.1 Airflow Metrics

| Metric | Source | Dashboard |
|--------|--------|-----------|
| DAG run duration | Airflow StatsD -> Prometheus | Grafana: Airflow Operations |
| Task success/failure rate | Airflow StatsD -> Prometheus | Grafana: Airflow Operations |
| Scheduler heartbeat | Airflow health endpoint | Grafana: Airflow Health |
| Executor pod count | Kubernetes metrics | Grafana: K3s Resources |

### 7.2 n8n Metrics

| Metric | Source | Dashboard |
|--------|--------|-----------|
| Workflow execution count | n8n API | Grafana: n8n Operations |
| Webhook response time | n8n logs -> Loki | Grafana: n8n Performance |
| Error rate per workflow | n8n API | Grafana: n8n Health |

---

## 8. Failure Handling

### 8.1 Airflow Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| Scheduler pod crash | DAGs stop scheduling | K8s restarts pod; catches up on missed runs |
| Task pod OOM | Single task fails | Retry policy kicks in; increase resource limits |
| SSH to node fails | Scanning task fails | Retry after 5min; alert if 2 retries fail |
| MinIO unavailable | Evidence upload fails | Retry; evidence cached locally until MinIO recovers |
| PostgreSQL down | Airflow metadata lost | CloudNativePG handles HA; failover is automatic |

### 8.2 n8n Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| n8n pod crash | Webhooks return 503 | K8s restarts pod; Airflow retries webhook |
| Rocket.Chat down | Notifications not delivered | n8n retries; messages queued |
| ClickUp API rate limit | Task creation delayed | n8n built-in retry with backoff |
| Cloudflare API error | Secrets sync fails | n8n retries; alert to Rocket.Chat |

---

## 9. Related Documents

| Document | Relevance |
|----------|-----------|
| [compliance-scanning-architecture.md](compliance-scanning-architecture.md) | Scanning stack that Airflow orchestrates |
| [secrets-lifecycle-architecture.md](secrets-lifecycle-architecture.md) | Rotation pipeline using Airflow + n8n |
| [infrastructure-buildout-master-plan.md](infrastructure-buildout-master-plan.md) | Airflow + n8n deployed in Phase 5 |
| [defense-in-depth-architecture.md](defense-in-depth-architecture.md) | Layer 2 monitoring via scanning DAGs |
