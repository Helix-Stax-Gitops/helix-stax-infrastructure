# Service Events Deep Research: Complete Event Catalog

> **Author**: Remy Alcazar, Research Analyst
> **Date**: 2026-03-20
> **Scope**: Every service in the Helix Stax stack EXCEPT ClickUp automations, Postal emails, and Devtron/ArgoCD/Harbor/GitHub CI/CD (covered by other agents)
> **Rule**: If something happens, someone gets told. No silent failures.

---

## Table of Contents

1. [K3s / Kubernetes Events](#1-k3s--kubernetes-events)
2. [Prometheus / Alertmanager Events](#2-prometheus--alertmanager-events)
3. [Grafana Events](#3-grafana-events)
4. [Loki Events](#4-loki-events)
5. [CrowdSec Events](#5-crowdsec-events)
6. [Zitadel Events](#6-zitadel-events)
7. [OpenBao (Vault) Events](#7-openbao-vault-events)
8. [PostgreSQL (CloudNativePG) Events](#8-postgresql-cloudnativepg-events)
9. [Valkey (Redis) Events](#9-valkey-redis-events)
10. [MinIO Events](#10-minio-events)
11. [Velero Events](#11-velero-events)
12. [Cloudflare Events](#12-cloudflare-events)
13. [Hetzner Events](#13-hetzner-events)
14. [Rocket.Chat Events](#14-rocketchat-events)
15. [n8n Self-Monitoring](#15-n8n-self-monitoring)
16. [Outline Events](#16-outline-events)
17. [Backstage Events](#17-backstage-events)
18. [Fleet / osquery Events](#18-fleet--osquery-events)
19. [Cross-Cutting Concerns](#19-cross-cutting-concerns)

---

## Global Severity Routing Matrix

All events across all services follow this routing:

| Severity | ClickUp | Rocket.Chat | Postal Email | Grafana |
|----------|---------|-------------|-------------|---------|
| **CRITICAL** | Task (urgent priority) | `#alerts-critical` + @wakeem mention | Email to admin@helixstax.com | Annotation (red) |
| **WARNING** | Task (high priority) | `#alerts-warning` channel post | None | Annotation (yellow) |
| **INFO** | Comment on existing task OR skip | `#alerts-info` (batched hourly) | None | Annotation (blue) only if noteworthy |

---

## 1. K3s / Kubernetes Events

### Capture Method
kube-state-metrics + kube-prometheus-stack -> Prometheus -> Alertmanager -> n8n webhook -> ClickUp + Rocket.Chat

### Required Components

| Component | Helm Chart | Chart Repo | Recommended Version |
|-----------|-----------|------------|---------------------|
| kube-prometheus-stack | `kube-prometheus-stack` | `prometheus-community` | `>=72.x` (latest stable) |
| kube-state-metrics | Included in kube-prometheus-stack | (bundled) | (bundled) |

### K3s-Specific Configuration (CRITICAL)

K3s requires custom values to disable components that do not exist in K3s. Without these overrides, Prometheus rules will fire false alerts constantly.

```yaml
# values-k3s.yaml for kube-prometheus-stack
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeProxy:
  enabled: false
kubeEtcd:
  enabled: false
# K3s exposes metrics at different endpoints
kubelet:
  serviceMonitor:
    metricRelabelings:
      - action: replace
        sourceLabels: [__address__]
        targetLabel: job
        replacement: k3s-server
```

**GOTCHA**: K3s bundles kube-controller-manager, kube-scheduler, kube-proxy, and etcd (actually SQLite by default) into a single binary. The default kube-prometheus-stack expects these as separate services. Disabling them prevents "target down" false alerts.

### Event Catalog

| Event | PrometheusRule Expression | Severity | For Duration |
|-------|--------------------------|----------|-------------|
| Node not ready | `kube_node_status_condition{condition="Ready",status="true"} == 0` | CRITICAL | 5m |
| Node recovered | Alert resolves automatically | INFO | - |
| Pod CrashLoopBackOff | `kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} > 0` | CRITICAL | 3m |
| Pod OOMKilled | `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} > 0` | WARNING | 0m (instant) |
| PVC pending | `kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1` | WARNING | 15m |
| Namespace quota exceeded | `kube_resourcequota{type="hard"} - kube_resourcequota{type="used"} <= 0` | WARNING | 5m |
| Ingress failing (5xx) | `rate(traefik_service_requests_total{code=~"5.."}[5m]) > 0.1` | WARNING | 5m |
| Ingress failing (sustained) | `rate(traefik_service_requests_total{code=~"5.."}[15m]) / rate(traefik_service_requests_total[15m]) > 0.05` | CRITICAL | 10m |
| New deployment created | `changes(kube_deployment_created[5m]) > 0` | INFO | - |
| HPA scaling event | `kube_horizontalpodautoscaler_status_current_replicas != kube_horizontalpodautoscaler_status_desired_replicas` | INFO | 2m |
| CronJob failed | `kube_job_status_failed{job_name=~".*cronjob.*"} > 0` | WARNING | 0m |
| Resource limit exceeded | `container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.9` | WARNING | 5m |
| Container restart rate high | `rate(kube_pod_container_status_restarts_total[1h]) > 3` | WARNING | 5m |

### n8n Workflow: K8s Alert Router

```
Trigger: Webhook (POST from Alertmanager)
  -> Switch node (route by severity label)
    -> CRITICAL:
       -> ClickUp: Create task (urgent, "Infrastructure" list)
       -> Rocket.Chat: Post to #alerts-critical with @wakeem
       -> Postal: Send email to admin@helixstax.com
       -> Grafana: Create annotation
    -> WARNING:
       -> ClickUp: Create task (high priority)
       -> Rocket.Chat: Post to #alerts-warning
    -> INFO:
       -> Grafana: Create annotation only
```

### ClickUp Action Details

| Event Type | ClickUp Action | List | Custom Fields |
|------------|---------------|------|---------------|
| Node down | Create task | Infrastructure | `source: k3s`, `node: <name>`, `severity: critical` |
| Pod crash | Create task | Infrastructure | `source: k3s`, `pod: <name>`, `namespace: <ns>` |
| Pod OOMKilled | Create task | Infrastructure | `source: k3s`, `pod: <name>`, `memory_limit: <val>` |
| CronJob failed | Create task | Operations | `source: k3s`, `job: <name>` |
| HPA scaling | Comment on service task | - | - |

### Deduplication Strategy

Alertmanager handles primary deduplication via `group_by` labels. Configure:

```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'namespace', 'pod']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
```

In n8n: Before creating ClickUp task, query ClickUp API for existing open task with matching `alertname` + `namespace` + `pod` custom fields. If found, add comment instead of creating duplicate.

### Alert Fatigue Prevention

- **group_wait: 30s** -- buffer related alerts before first notification
- **group_interval: 5m** -- wait 5 min before sending updates for same group
- **repeat_interval: 4h** -- do not re-notify for same alert within 4 hours
- **INFO alerts**: Batch into hourly digest (n8n Schedule trigger collects, then posts summary)

---

## 2. Prometheus / Alertmanager Events

### Capture Method
Alertmanager self-monitoring + Prometheus meta-metrics -> Alertmanager webhook -> n8n

### Event Catalog

| Event | Source Metric / Method | Severity |
|-------|----------------------|----------|
| Alert firing (critical) | Alertmanager webhook payload `status: firing`, `severity: critical` | CRITICAL |
| Alert firing (warning) | Alertmanager webhook payload `status: firing`, `severity: warning` | WARNING |
| Alert resolved | Alertmanager webhook payload `status: resolved` | INFO |
| Alertmanager silenced | `alertmanager_silences{state="active"}` changes + Alertmanager API `/api/v2/silences` | WARNING |
| Prometheus target down | `up == 0` | CRITICAL (after 5m) |
| Prometheus storage filling | `prometheus_tsdb_storage_retention_criteria_count` + `(node_filesystem_avail_bytes{mountpoint="/prometheus"} / node_filesystem_size_bytes{mountpoint="/prometheus"}) < 0.15` | WARNING |
| Recording rule failure | `prometheus_rule_evaluation_failures_total` increasing | WARNING |
| Alertmanager cluster degraded | `alertmanager_cluster_health_checks` != expected | CRITICAL |

### n8n Workflow: Alertmanager Meta-Monitor

```
Trigger: Webhook (POST from Alertmanager -- separate webhook receiver for meta-alerts)
  -> Parse alert payload
  -> If alertname == "PrometheusTargetDown":
     -> ClickUp: Create task "Prometheus target down: <target>"
     -> Rocket.Chat: #alerts-critical "@wakeem Prometheus target <target> is DOWN"
  -> If alertname matches silence event:
     -> Rocket.Chat: #alerts-warning "Silence created by <user> on <alert> until <expiry>"
     -> ClickUp: Comment on related task
```

### ClickUp Action

| Event | Action | Notes |
|-------|--------|-------|
| Prometheus target down | Create task | Auto-close when `resolved` webhook arrives |
| Storage filling | Create task | Include projected fill time |
| Silence created | Comment | Log who silenced what for audit trail (SOC 2 CC7.2) |
| Rule evaluation failure | Create task | Include rule name and error |

### Deduplication

Alertmanager's built-in `groupKey` field is the primary dedup mechanism. n8n stores the `groupKey` in ClickUp task custom field. On subsequent webhooks with same `groupKey`, update existing task instead of creating new.

---

## 3. Grafana Events

### Capture Method
Grafana webhooks (contact points) + Grafana API audit + n8n polling

### Event Catalog

| Event | Capture Method | Severity |
|-------|---------------|----------|
| Dashboard modified | Grafana webhook (via Alerting contact point on dashboard change) OR n8n polling `GET /api/search?query=&type=dash-db` with version tracking | INFO |
| Alert rule created/modified/deleted | Grafana webhook contact point | WARNING |
| User logged in (admin) | Grafana audit logs -> Loki -> Loki alert rule | WARNING |
| Annotation created | Grafana webhook on annotation event OR API polling | INFO |
| Data source connection failed | PrometheusRule: `grafana_datasource_request_duration_seconds_count{status_code="error"} > 0` | CRITICAL |
| Grafana OnCall incident created | Grafana OnCall webhook integration | CRITICAL |
| Grafana OnCall incident escalated | Grafana OnCall webhook | CRITICAL |
| Grafana OnCall incident resolved | Grafana OnCall webhook | INFO |

### Grafana Webhook Configuration

Grafana v12+ supports HMAC-SHA256 signed webhooks for contact points. Configure:

```yaml
# In Grafana provisioning
apiVersion: 1
contactPoints:
  - orgId: 1
    name: n8n-webhook
    receivers:
      - uid: n8n-receiver
        type: webhook
        settings:
          url: "https://n8n.helixstax.com/webhook/grafana-alerts"
          httpMethod: POST
          authorization_scheme: Bearer
          authorization_credentials: "<token-from-openbao>"
```

### n8n Workflow: Grafana Event Router

```
Trigger: Webhook (POST from Grafana contact point)
  -> Parse Grafana alert payload
  -> Switch on alert state (alerting / ok / no_data)
  -> Route by severity annotation
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Alert rule modified | Comment on Monitoring task |
| Dashboard modified | Skip (audit log only, low priority) |
| Data source failed | Create task (critical) |
| OnCall incident created | Create task (urgent) |
| Admin login | Comment on Security task for audit trail |

### Deduplication

Grafana alerts include `fingerprint` field. Use this as idempotency key in n8n to prevent duplicate ClickUp tasks.

---

## 4. Loki Events

### Capture Method
Loki Ruler (alerting rules) -> Alertmanager -> n8n webhook

### Required Configuration

The Loki Ruler must be enabled and configured to send alerts to Alertmanager:

```yaml
# loki values.yaml (loki-stack or grafana/loki Helm chart)
loki:
  rulerConfig:
    storage:
      type: local
      local:
        directory: /rules
    ring:
      kvstore:
        store: inmemory
    alertmanager_url: http://alertmanager.monitoring.svc.cluster.local:9093
    enable_alertmanager_v2: true
```

### Event Catalog (LogQL Alert Rules)

| Event | LogQL Expression | Severity |
|-------|-----------------|----------|
| Log volume spike (10x) | `sum(rate({namespace=~".+"} \| json [5m])) > 10 * avg_over_time(sum(rate({namespace=~".+"} \| json [5m]))[24h:1h])` | WARNING |
| Error rate spike | `sum(rate({namespace=~".+"} \|= "error" [5m])) by (namespace) > 5 * sum(rate({namespace=~".+"} \|= "error" [1h])) by (namespace)` | WARNING |
| Stack trace detected | `count_over_time({namespace=~".+"} \|~ "(?i)(stacktrace\|stack trace\|traceback\|panic\|fatal)" [5m]) > 0` | WARNING |
| Unauthorized access attempts | `count_over_time({namespace=~".+"} \|~ "(?i)(unauthorized\|403\|401)" [5m]) > 10` | WARNING |
| Log ingestion stopped | `absent_over_time({namespace="<service>"} [15m])` | CRITICAL |
| Retention policy triggered | Monitor via Loki compactor metrics: `loki_compactor_deleted_series_total` | INFO |

### n8n Workflow: Loki Alert Router

Same as K8s Alert Router -- Loki alerts go through Alertmanager, which forwards to the same n8n webhook. Differentiate by alert labels (`source: loki`).

### ClickUp Action

| Event | Action |
|-------|--------|
| Error rate spike | Create task with log sample in description |
| Stack trace / panic | Create task (high priority) |
| Unauthorized attempts | Create task + @mention security |
| Log ingestion stopped | Create task (critical) -- service may be down |

### Alert Fatigue Prevention

- Error rate alerts: Use `for: 10m` to avoid transient spikes
- Stack trace alerts: Deduplicate by `namespace` + `pod` + 1-hour cooldown
- Unauthorized: Batch per source IP over 15m window before alerting

---

## 5. CrowdSec Events

### Capture Method
CrowdSec HTTP notification plugin -> n8n webhook

### Configuration

CrowdSec supports a generic HTTP plugin for webhook notifications. Configure in `/etc/crowdsec/notifications/http.yaml`:

```yaml
type: http
name: n8n_webhook
log_level: info
format: |
  {
    "type": "crowdsec",
    "event": "{{.Type}}",
    "scenario": "{{.Scenario}}",
    "source_ip": "{{.Source.IP}}",
    "source_scope": "{{.Source.Scope}}",
    "decisions": [
      {{range .Decisions}}
      {
        "type": "{{.Type}}",
        "duration": "{{.Duration}}",
        "value": "{{.Value}}",
        "scenario": "{{.Scenario}}"
      }
      {{end}}
    ],
    "timestamp": "{{.StartAt}}"
  }
url: https://n8n.helixstax.com/webhook/crowdsec-alerts
method: POST
headers:
  Authorization: "Bearer <token-from-openbao>"
  Content-Type: "application/json"
```

Then add `n8n_webhook` to the `notifications` list in the profiles configuration.

### Helm Chart

| Component | Chart | Repo |
|-----------|-------|------|
| CrowdSec Security Engine | `crowdsec` | `crowdsecurity` |
| CrowdSec Bouncer (Traefik) | `crowdsec-traefik-bouncer` | `crowdsecurity` |

```bash
helm repo add crowdsecurity https://crowdsecurity.github.io/helm-charts
helm show values crowdsecurity/crowdsec --version <latest>
```

### Event Catalog

| Event | CrowdSec Signal | Severity |
|-------|----------------|----------|
| IP banned | Decision type: `ban` | WARNING |
| IP unbanned | Decision type: `unban` / expiry | INFO |
| New scenario triggered | Alert with scenario name | WARNING |
| Brute force detected | Scenario: `crowdsecurity/ssh-bf`, `crowdsecurity/http-bf` | CRITICAL |
| DDoS pattern detected | Scenario: `crowdsecurity/http-crawl-non_statics`, high-rate scenarios | CRITICAL |
| CrowdSec engine updated | Monitor via pod restart events (K8s) | INFO |
| Bouncer disconnected | `crowdsec_bouncers_last_api_pull` metric stale OR Loki log pattern | CRITICAL |

### n8n Workflow: CrowdSec Security Router

```
Trigger: Webhook (POST from CrowdSec HTTP plugin)
  -> Parse payload
  -> Switch on scenario type:
    -> Brute force / DDoS:
       -> ClickUp: Create task (urgent, "Security" list)
       -> Rocket.Chat: #security @wakeem "Brute force from <IP>, banned for <duration>"
       -> Postal: Email admin@helixstax.com
    -> Standard ban:
       -> Rocket.Chat: #security "IP <IP> banned: <scenario>"
    -> Unban:
       -> Rocket.Chat: #security "IP <IP> unbanned"
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Brute force attack | Create task (urgent, Security list) |
| DDoS pattern | Create task (urgent, Security list) |
| Standard ban | Comment on "Active Bans" tracking task |
| Bouncer disconnected | Create task (critical, Infrastructure list) |

### Deduplication

- Rate limit: Max 1 notification per source IP per scenario per 30 minutes
- In n8n: Use Function node to check a Redis/Valkey key `crowdsec:<ip>:<scenario>` with 30m TTL

---

## 6. Zitadel Events

### Capture Method
Zitadel Actions v2 (event type executions) -> webhook targets -> n8n

### Architecture

Zitadel Actions v2 uses a Target + Execution model:
1. **Target**: Define an HTTP endpoint (n8n webhook URL)
2. **Execution**: Bind events to that target

Zitadel streams a comprehensive event log. Unlike polling, Actions v2 pushes events in real-time via webhook.

### Configuration (via Zitadel API)

```bash
# 1. Create Target
curl -X POST "https://zitadel.helixstax.com/management/v1/targets" \
  -H "Authorization: Bearer <service-account-token>" \
  -d '{
    "name": "n8n-event-webhook",
    "restWebhook": {
      "interruptOnError": false
    },
    "endpoint": "https://n8n.helixstax.com/webhook/zitadel-events",
    "timeout": "10s"
  }'

# 2. Create Execution for events
curl -X POST "https://zitadel.helixstax.com/management/v1/executions" \
  -H "Authorization: Bearer <service-account-token>" \
  -d '{
    "condition": {
      "event": {
        "event": "user.human.added",
        "group": "user"
      }
    },
    "targets": [{"type": "target", "target": "<target-id>"}]
  }'
```

### Event Catalog

| Event | Zitadel Event Type | Severity |
|-------|-------------------|----------|
| User created | `user.human.added` | INFO |
| User deactivated | `user.deactivated` | WARNING |
| User locked | `user.locked` | WARNING |
| Failed login (admin) | `user.human.password.check.failed` (filter by admin user IDs) | CRITICAL |
| Failed login (standard) | `user.human.password.check.failed` | WARNING (if >5 in 10m) |
| OIDC client created | `project.application.oidc.added` | WARNING |
| OIDC client modified | `project.application.oidc.changed` | WARNING |
| MFA enrolled | `user.human.mfa.otp.added` | INFO |
| MFA removed | `user.human.mfa.otp.removed` | WARNING |
| Session from new device | `session.added` (correlate with device/IP fingerprint) | WARNING |
| Password changed | `user.human.password.changed` | INFO |
| Password reset requested | `user.human.password.code.added` | INFO |
| Token revoked | `user.token.removed` | INFO |
| Organization modified | `org.changed` | WARNING |

### Webhook Payload Structure

Zitadel event payloads include:
- `aggregateID`: Resource identifier
- `aggregateType`: Resource type (user, org, project)
- `resourceOwner`: Organization ID
- `event_type`: The specific event
- `created_at`: ISO 8601 timestamp
- `userID`: Actor who triggered the event
- `event_payload`: JSON with event-specific data

### n8n Workflow: Zitadel Auth Router

```
Trigger: Webhook (POST from Zitadel Actions v2)
  -> Parse event payload
  -> Switch on event_type:
    -> user.locked / password.check.failed (admin):
       -> ClickUp: Create task (urgent, "Security" list)
       -> Rocket.Chat: #security @wakeem "Admin login failed from <IP>"
       -> Postal: Email admin@helixstax.com
    -> user.human.added / user.deactivated:
       -> Rocket.Chat: #auth-events "User <email> created/deactivated"
       -> ClickUp: Comment on "User Management" task
    -> project.application.oidc.*:
       -> Rocket.Chat: #auth-events "OIDC client <name> created/modified"
       -> ClickUp: Create task (Security list) for review
    -> user.human.mfa.otp.removed:
       -> Rocket.Chat: #security "MFA removed for user <email>"
       -> ClickUp: Create task for security review
```

### ClickUp Action

| Event | Action | List |
|-------|--------|------|
| Admin failed login | Create task (urgent) | Security |
| User locked | Create task | Security |
| OIDC client change | Create task for review | Security |
| MFA removed | Create task for review | Security |
| User created | Comment on User Management task | Operations |

### Audit Trail (SOC 2 CC7.2)

ALL Zitadel events must be logged to Loki regardless of severity routing. Configure a second n8n branch that sends every event to a Loki push endpoint for immutable audit storage.

### Deduplication

- Failed logins: Aggregate per user over 10m window. Alert once per window.
- Session events: Deduplicate by session ID.

---

## 7. OpenBao (Vault) Events

### Capture Method
OpenBao audit device (file) -> Promtail/Alloy -> Loki -> Loki alerting rules -> Alertmanager -> n8n

### Architecture Note (IMPORTANT)

OpenBao does NOT have native webhook support for audit events. The audit device writes to a file (or syslog/socket). The approach is:

1. Enable the `file` audit device in OpenBao
2. Collect audit log files with Promtail (or Grafana Alloy)
3. Ship to Loki
4. Create Loki alerting rules for specific patterns
5. Loki Ruler fires alerts to Alertmanager
6. Alertmanager forwards to n8n

### OpenBao Audit Device Configuration

```hcl
# Enable audit device in OpenBao config
audit {
  type = "file"
  path = "file"
  options = {
    file_path = "/openbao/audit/audit.log"
    log_raw   = false  # Never log raw -- masks sensitive values
  }
}
```

### Helm Chart

| Component | Chart | Repo |
|-----------|-------|------|
| OpenBao | `openbao` | `https://openbao.github.io/openbao-helm` |

### Event Catalog

| Event | Detection Method (Loki LogQL) | Severity |
|-------|------------------------------|----------|
| Secret accessed | `{app="openbao"} \| json \| type="response" \| path=~"secret/.*" \| operation="read"` | INFO |
| Secret rotated | `{app="openbao"} \| json \| type="response" \| path=~"secret/.*" \| operation="update"` | INFO |
| Policy created/modified | `{app="openbao"} \| json \| path=~"sys/policy/.*" \| operation=~"create\|update"` | WARNING |
| Token created | `{app="openbao"} \| json \| path="auth/token/create"` | INFO |
| Token revoked | `{app="openbao"} \| json \| path=~"auth/token/revoke.*"` | INFO |
| Lease expired | `{app="openbao"} \| json \| type="response" \| error=~".*lease.*expired.*"` | WARNING |
| Seal/unseal event | `{app="openbao"} \| json \| path=~"sys/(seal\|unseal)"` | CRITICAL |
| Auth method enabled/disabled | `{app="openbao"} \| json \| path=~"sys/auth/.*"` | WARNING |
| Root token used | `{app="openbao"} \| json \| auth.policies=~".*root.*"` | CRITICAL |
| Failed authentication | `{app="openbao"} \| json \| type="response" \| error=~".*permission denied.*"` | WARNING |

### Loki Alert Rules

```yaml
groups:
  - name: openbao-security
    rules:
      - alert: OpenBaoSealEvent
        expr: |
          count_over_time({app="openbao"} |= "sys/seal" [5m]) > 0
        for: 0m
        labels:
          severity: critical
          source: openbao
        annotations:
          summary: "OpenBao seal/unseal event detected"
      - alert: OpenBaoRootTokenUsed
        expr: |
          count_over_time({app="openbao"} |~ "root" | json | auth_policies=~".*root.*" [5m]) > 0
        for: 0m
        labels:
          severity: critical
          source: openbao
        annotations:
          summary: "Root token used in OpenBao"
      - alert: OpenBaoPolicyChanged
        expr: |
          count_over_time({app="openbao"} |= "sys/policy" [5m]) > 0
        for: 0m
        labels:
          severity: warning
          source: openbao
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Seal/unseal | Create task (urgent, Security list) |
| Root token used | Create task (urgent, Security list) |
| Policy changed | Create task (high, Security list) |
| Auth method changed | Create task (high, Security list) |
| Failed auth (>5 in 10m) | Create task (high, Security list) |
| Secret accessed | Audit log only (Loki) |

### GOTCHA: OpenBao Audit Log Volume

OpenBao audit logs can be extremely verbose. Every API call generates an audit entry. Ensure:
- Loki retention for OpenBao namespace: 90 days (SOC 2 requirement)
- Promtail pipeline_stages filter to drop health check audit entries
- Storage budget: Estimate ~50-100MB/day for moderate usage

---

## 8. PostgreSQL (CloudNativePG) Events

### Capture Method
CloudNativePG operator metrics + pg_stat exporter -> Prometheus -> Alertmanager -> n8n

### Required Components

| Component | Chart | Notes |
|-----------|-------|-------|
| CloudNativePG Operator | `cloudnative-pg` | `cloudnative-pg` Helm repo |
| Built-in PG exporter | Included in CNPG | Port 9187, enabled via `.spec.monitoring.enablePodMonitor: true` |

### Configuration

```yaml
# CloudNativePG Cluster resource
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: helix-pg
spec:
  monitoring:
    enablePodMonitor: true
    customQueriesConfigMap:
      - name: pg-custom-queries
        key: queries
```

### Event Catalog

| Event | Detection Method | Severity |
|-------|-----------------|----------|
| Failover occurred | K8s event: `type: Normal, reason: Failover` + CNPG metrics: `cnpg_pg_replication_is_wal_receiver_up` changes | CRITICAL |
| Replication lag exceeded | `cnpg_pg_replication_lag > 30` (seconds) | WARNING |
| Replication lag critical | `cnpg_pg_replication_lag > 300` | CRITICAL |
| Connection pool exhausted | `cnpg_pg_stat_activity_count / cnpg_pg_settings_max_connections > 0.85` | WARNING |
| Long-running query | Custom query: `pg_stat_activity_max_tx_duration > 300` (5 min) | WARNING |
| Long-running query critical | `pg_stat_activity_max_tx_duration > 3600` (1 hour) | CRITICAL |
| Backup completed | CNPG metrics: `cnpg_pg_last_archived_wal_timestamp` advancing | INFO |
| Backup failed | `time() - cnpg_pg_last_archived_wal_timestamp > 3600` (no WAL archived in 1h) | CRITICAL |
| WAL archiving failed | `cnpg_pg_stat_archiver_failed_count` increasing | CRITICAL |
| Disk usage high | `cnpg_pg_database_size_bytes / <threshold>` | WARNING (>80%), CRITICAL (>90%) |
| Deadlock detected | `rate(cnpg_pg_stat_database_deadlocks[5m]) > 0` | WARNING |

### PrometheusRule Examples

```yaml
groups:
  - name: cloudnative-pg
    rules:
      - alert: CNPGReplicationLagHigh
        expr: cnpg_pg_replication_lag > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL replication lag is {{ $value }}s on {{ $labels.pod }}"
      - alert: CNPGFailover
        expr: changes(cnpg_pg_replication_is_wal_receiver_up[5m]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL failover detected in cluster {{ $labels.cluster }}"
      - alert: CNPGBackupStale
        expr: time() - cnpg_pg_last_archived_wal_timestamp > 3600
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "No WAL archived in >1h for {{ $labels.cluster }}"
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Failover | Create task (urgent, Infrastructure) -- investigate root cause |
| Backup failed | Create task (critical, Operations) |
| Replication lag critical | Create task (high, Infrastructure) |
| Disk >90% | Create task (urgent, Infrastructure) |
| Deadlock | Create task (warning, Infrastructure) |

---

## 9. Valkey (Redis) Events

### Capture Method
redis_exporter (oliver006/redis_exporter) -> Prometheus -> Alertmanager -> n8n

### Required Components

| Component | Image | Notes |
|-----------|-------|-------|
| redis_exporter | `oliver006/redis_exporter:v1.80.x` | Supports Valkey 7.x, 8.x, 9.x |

Deploy as sidecar in Valkey pod or as separate deployment pointing to Valkey service.

### Event Catalog

| Event | PrometheusRule Expression | Severity |
|-------|--------------------------|----------|
| Memory usage high | `redis_memory_used_bytes / redis_memory_max_bytes > 0.85` | WARNING |
| Memory usage critical | `redis_memory_used_bytes / redis_memory_max_bytes > 0.95` | CRITICAL |
| Eviction started | `rate(redis_evicted_keys_total[5m]) > 0` | WARNING |
| Connection refused | `redis_connected_clients >= redis_config_maxclients * 0.9` | WARNING |
| Max clients reached | `redis_connected_clients >= redis_config_maxclients` | CRITICAL |
| Persistence failed (RDB) | `redis_rdb_last_bgsave_status == 0` (0 = err) | CRITICAL |
| Persistence failed (AOF) | `redis_aof_last_bgrewrite_status == 0` | CRITICAL |
| Replication broken | `redis_connected_slaves < <expected>` | CRITICAL |
| Slow command | `redis_slowlog_length > 10` | WARNING |
| Latency spike | `redis_commands_duration_seconds_total / redis_commands_processed_total > 0.01` | WARNING |

### ClickUp Action

| Event | Action |
|-------|--------|
| Memory critical | Create task (urgent, Infrastructure) |
| Persistence failed | Create task (critical, Infrastructure) |
| Replication broken | Create task (critical, Infrastructure) |
| Eviction started | Create task (warning, Infrastructure) |

---

## 10. MinIO Events

### Capture Method
MinIO bucket notifications -> webhook -> n8n

### Configuration

MinIO supports native webhook notifications for bucket events. Configure via environment variables in Helm values:

```yaml
# MinIO Helm values
environment:
  MINIO_NOTIFY_WEBHOOK_ENABLE_N8N: "on"
  MINIO_NOTIFY_WEBHOOK_ENDPOINT_N8N: "https://n8n.helixstax.com/webhook/minio-events"
  MINIO_NOTIFY_WEBHOOK_AUTH_TOKEN_N8N: "<token-from-openbao>"
  MINIO_NOTIFY_WEBHOOK_QUEUE_DIR_N8N: "/tmp/minio/events"
  MINIO_NOTIFY_WEBHOOK_QUEUE_LIMIT_N8N: "10000"
```

Then attach events to buckets:

```bash
mc event add myminio/mybucket arn:minio:sqs::N8N:webhook \
  --event "put,delete,replica"
```

### Helm Chart

| Component | Chart | Repo |
|-----------|-------|------|
| MinIO | `minio` | `https://charts.min.io/` |

### Event Catalog

| Event | MinIO Event Type | Severity |
|-------|-----------------|----------|
| Object uploaded | `s3:ObjectCreated:*` | INFO |
| Object deleted | `s3:ObjectRemoved:*` | INFO |
| Bucket created | `s3:BucketCreated:*` | WARNING |
| Bucket deleted | `s3:BucketRemoved:*` | CRITICAL |
| Replication failed | `s3:Replication:Failed` | CRITICAL |
| Disk usage high | Prometheus: `minio_disk_storage_used_bytes / minio_disk_storage_total_bytes > 0.85` | WARNING |
| Health check failed | Prometheus: `minio_health_status == 0` | CRITICAL |
| Erasure coding degraded | Prometheus: `minio_cluster_drive_offline_total > 0` | CRITICAL |

### n8n Workflow: MinIO Event Router

```
Trigger: Webhook (POST from MinIO notifications)
  -> Parse S3 event payload
  -> Switch on eventName:
    -> s3:BucketRemoved: -> CRITICAL alert (bucket deletion is rare and dangerous)
    -> s3:Replication:Failed: -> CRITICAL alert
    -> s3:ObjectCreated (client-uploads bucket): -> INFO, log to audit
    -> Default: -> Grafana annotation only
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Bucket deleted | Create task (urgent, Security) -- may be unauthorized |
| Replication failed | Create task (critical, Infrastructure) |
| Health check failed | Create task (critical, Infrastructure) |
| Object uploaded (client bucket) | Comment on client task (if applicable) |

---

## 11. Velero Events

### Capture Method
Velero Prometheus metrics (port 8085, enabled by default in Helm chart) -> Prometheus -> Alertmanager -> n8n

### Helm Chart

| Component | Chart | Repo |
|-----------|-------|------|
| Velero | `velero` | `vmware-tanzu/helm-charts` |

Metrics are enabled by default when installed via Helm.

### Event Catalog

| Event | PrometheusRule Expression | Severity |
|-------|--------------------------|----------|
| Backup completed | `velero_backup_success_total` increases | INFO |
| Backup failed | `increase(velero_backup_failure_total[1h]) > 0` | CRITICAL |
| Backup partial failure | `increase(velero_backup_partial_failure_total[1h]) > 0` | WARNING |
| Restore started | `velero_restore_attempt_total` increases | WARNING |
| Restore failed | `increase(velero_restore_failed_total[1h]) > 0` | CRITICAL |
| Backup schedule missed | `time() - velero_backup_last_successful_timestamp{schedule!=""} > <expected_interval * 1.5>` | CRITICAL |
| Backup storage unavailable | `velero_backup_items_total` not advancing + Velero pod logs | CRITICAL |
| Volume snapshot failed | `increase(velero_volume_snapshot_failure_total[1h]) > 0` | CRITICAL |
| Backup duration excessive | `velero_backup_duration_seconds > <threshold>` | WARNING |

### PrometheusRule Examples

```yaml
groups:
  - name: velero-backups
    rules:
      - alert: VeleroBackupFailed
        expr: increase(velero_backup_failure_total[1h]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Velero backup failed"
      - alert: VeleroBackupMissed
        expr: time() - velero_backup_last_successful_timestamp{schedule!=""} > 90000
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Velero scheduled backup missed for {{ $labels.schedule }}"
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Backup failed | Create task (urgent, Operations) |
| Backup missed | Create task (critical, Operations) |
| Restore failed | Create task (urgent, Operations) |
| Volume snapshot failed | Create task (critical, Operations) |
| Backup completed | Comment on "Backup Status" tracking task |

---

## 12. Cloudflare Events

### Capture Method
Cloudflare Notifications (webhook destination) + Cloudflare API polling via n8n

### Webhook Setup

Cloudflare supports webhook destinations for notifications. Configure in the Cloudflare dashboard under **Notifications > Destinations > Webhooks**, or programmatically:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/<account_id>/alerting/v3/destinations/webhooks" \
  -H "Authorization: Bearer <cf-api-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "n8n-events",
    "url": "https://n8n.helixstax.com/webhook/cloudflare-events",
    "secret": "<shared-secret>"
  }'
```

### Available Notifications (by Plan)

| Event | CF Notification Type | Plan Required | Severity |
|-------|---------------------|---------------|----------|
| WAF rule triggered (spike) | Security Events Alert | Business+ | WARNING |
| DDoS attack detected | HTTP DDoS Attack Alert | All plans | CRITICAL |
| DDoS attack (L3/4) | Layer 3/4 DDoS Attack Alert | Magic Transit | CRITICAL |
| SSL certificate renewed | Universal SSL Alert | All plans | INFO |
| SSL cert expiring | Advanced Certificate Alert | Advanced certs | WARNING |
| Tunnel disconnected | Tunnel Health Alert | All Zero Trust | CRITICAL |
| Tunnel reconnected | Tunnel Health Alert (resolved) | All Zero Trust | INFO |
| Tunnel created/deleted | Tunnel Creation or Deletion | All Zero Trust | WARNING |
| Zero Trust access denied | NOT available as native notification | - | See below |
| Device connectivity anomaly | Device Connectivity Anomaly | Zero Trust | WARNING |
| Health check failed | Health Checks Status | Professional+ | CRITICAL |
| DNS record changed | NOT available as native notification | - | See below |
| Cache purged | NOT available as native notification | - | See below |
| Maintenance window | Incident Alerts | All plans | INFO |

### GAPS: Events Requiring API Polling

Several events are NOT available as Cloudflare notifications and require n8n scheduled polling:

| Event | Polling Method | Schedule |
|-------|---------------|----------|
| Zero Trust access denied | `GET /api/v4/accounts/<id>/access/logs/access_requests` | Every 5m |
| DNS record changed | `GET /api/v4/zones/<id>/dns_records` + compare with last snapshot | Every 15m |
| Firewall rule matched | Security Events API: `GET /api/v4/zones/<id>/security/events` | Every 5m |
| Cache purged | Audit log API: `GET /api/v4/accounts/<id>/audit_logs` | Every 15m |
| New device enrolled | WARP Devices API | Every 15m |

### n8n Workflow: Cloudflare Event Router

```
Trigger A: Webhook (POST from Cloudflare notifications)
  -> Parse notification payload
  -> Route by notification type

Trigger B: Schedule (every 5m for security, 15m for ops)
  -> Poll Cloudflare APIs
  -> Compare with previous state (stored in n8n static data or Valkey)
  -> On change: route to appropriate channel
```

### ClickUp Action

| Event | Action |
|-------|--------|
| DDoS attack | Create task (urgent, Security) |
| Tunnel disconnected | Create task (critical, Infrastructure) |
| WAF spike | Create task (high, Security) |
| SSL expiring | Create task (high, Operations) |
| Access denied (suspicious) | Comment on Security monitoring task |

### GOTCHA: Cloudflare Plan Requirements

- Helix Stax is currently on **Pro plan** for helixstax.com
- Security Events Alert requires **Business plan** -- either upgrade or use API polling as fallback
- DDoS alerts are available on all plans
- Tunnel Health alerts are available on all Zero Trust plans

**RISK**: If helixstax.com is on Free/Pro, several WAF-level webhook notifications will not be available. Must use API polling instead.

---

## 13. Hetzner Events

### Capture Method
n8n scheduled polling via Hetzner Cloud API (NO native webhook support)

### IMPORTANT: Hetzner Has No Webhooks

Hetzner Cloud does NOT support webhook notifications. All monitoring must use API polling.

### Configuration

```
# n8n HTTP Request node configuration
URL: https://api.hetzner.cloud/v1/servers
Headers:
  Authorization: Bearer <hetzner-api-token-from-openbao>
```

### Event Catalog

| Event | API Endpoint / Method | Poll Interval | Severity |
|-------|----------------------|---------------|----------|
| Server rebooted | `GET /v1/servers/<id>/actions` -- filter `action.command == "reboot"` | 5m | WARNING |
| Server unreachable | `GET /v1/servers/<id>` -- check `status != "running"` | 2m | CRITICAL |
| Bandwidth approaching | `GET /v1/servers/<id>/metrics?type=network` -- calculate usage vs limit | 1h | WARNING |
| Billing threshold | Hetzner Console only (no API) -- use Hetzner SysMon email | Daily | WARNING |
| Scheduled maintenance | `GET /v1/servers/<id>/actions` -- filter for maintenance | 6h | INFO |
| Backup created | `GET /v1/servers/<id>/actions` -- filter `action.command == "create_backup"` | 1h | INFO |
| Server rescue mode | `GET /v1/servers/<id>` -- check `rescue_enabled` | 5m | CRITICAL |
| Volume detached | `GET /v1/volumes` -- check attachment status | 5m | WARNING |

### n8n Workflow: Hetzner Poller

```
Trigger: Schedule (every 2m for critical, 5m for standard, 1h for billing)
  -> HTTP Request: GET /v1/servers
  -> For each server:
     -> Compare status with stored state (n8n static data / Valkey key)
     -> If status changed:
        -> Route by change type (down, rebooted, maintenance)
  -> Separate schedule: GET /v1/servers/<id>/metrics
     -> Calculate bandwidth usage percentage
     -> If >80%: WARNING
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Server unreachable | Create task (urgent, Infrastructure) |
| Server rebooted (unplanned) | Create task (high, Infrastructure) |
| Bandwidth >80% | Create task (warning, Operations) |
| Scheduled maintenance | Create task (info, Operations) with maintenance window |

### GOTCHA: API Rate Limits

Hetzner Cloud API rate limit: 3600 requests/hour. With 2 servers polled every 2 minutes + metrics every hour, budget:
- Server status: 2 servers * 30 polls/hr = 60 req/hr
- Actions: 2 * 12/hr = 24 req/hr
- Metrics: 2 * 1/hr = 2 req/hr
- Total: ~86 req/hr -- well within limits

---

## 14. Rocket.Chat Events

### Capture Method
Rocket.Chat outgoing webhooks + n8n

### Configuration

Create outgoing integration in Rocket.Chat:
- **Administration > Integrations > New Outgoing Webhook**
- Event trigger: Message Sent, Room Created, etc.
- Channel: (specify or all)
- URL: n8n webhook endpoint

### Event Catalog

| Event | RC Integration Type | Severity |
|-------|-------------------|----------|
| New user registered | Outgoing webhook on `user-joined` | INFO |
| Channel created | Outgoing webhook on channel event | INFO |
| Message from client channel | Outgoing webhook filtered by channel name prefix `client-*` | WARNING |
| Bot command executed | Outgoing webhook matching regex pattern | INFO |
| File shared in client channel | Outgoing webhook matching file attachments in `client-*` channels | WARNING |
| User mentioned @wakeem | Outgoing webhook matching `@wakeem` mention | WARNING |

### n8n Workflow: Rocket.Chat Event Router

```
Trigger: Webhook (POST from Rocket.Chat outgoing integration)
  -> Parse message payload
  -> If channel matches "client-*":
     -> ClickUp: Create task in Client Work list
     -> (Optional) Postal: Forward to client-specific email
  -> If mentions @wakeem:
     -> Postal: Email to admin@helixstax.com
  -> If new user:
     -> ClickUp: Comment on "Team Management" task
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Client channel message | Create/comment on client task |
| @wakeem mention | Email notification + ClickUp comment |
| New user | Comment on Team task |

---

## 15. n8n Self-Monitoring

### Capture Method
n8n Error Trigger workflow + Prometheus metrics + Loki logs

### Architecture

n8n monitors itself through:
1. **Error Trigger node**: Built-in node that fires when any workflow fails
2. **Prometheus metrics**: n8n exposes execution metrics
3. **Loki**: Container logs for operational issues

### CRITICAL: Error Workflow Configuration

Every workflow in n8n must have an Error Workflow configured:
- Go to each workflow's **Settings**
- Set **Error Workflow** to the designated "n8n-error-handler" workflow
- The error handler workflow starts with an **Error Trigger** node

### Error Handler Workflow

```
Trigger: Error Trigger (fires when any configured workflow fails)
  -> Extract: workflow name, execution ID, error message, timestamp
  -> Switch on workflow criticality tag:
    -> Critical workflows (backup, security, CI/CD):
       -> Rocket.Chat: #alerts-critical @wakeem "CRITICAL workflow failed: <name>"
       -> ClickUp: Create task (urgent, Operations)
       -> Postal: Email admin@helixstax.com
    -> Standard workflows:
       -> Rocket.Chat: #alerts-warning "Workflow failed: <name>"
       -> ClickUp: Create task (high, Operations)
```

### Event Catalog

| Event | Detection Method | Severity |
|-------|-----------------|----------|
| Workflow execution failed | Error Trigger node | WARNING-CRITICAL (by tag) |
| Workflow execution succeeded (critical) | Separate workflow polling execution API | INFO |
| Credential expired | Error message pattern matching in Error Trigger | CRITICAL |
| Webhook not responding | Loki log: `"webhook"` + `"timeout\|refused\|ECONNREFUSED"` | CRITICAL |
| Queue backlog growing | n8n Prometheus metric: `n8n_executions_waiting` > threshold | WARNING |
| Memory/CPU threshold | Container metrics: `container_memory_working_set_bytes` for n8n pod | WARNING |
| n8n pod restart | Kubernetes pod restart event (Section 1 handles this) | CRITICAL |

### GOTCHA: Error Trigger Limitations

- Error Trigger workflows do NOT fire when manually executing workflows -- only on automatic (production) executions
- If n8n itself crashes, the Error Trigger cannot fire. Monitor n8n pod health via K8s events (Section 1)
- Error workflows must be ACTIVE (enabled) to receive triggers
- Each workflow must have the error workflow explicitly set in its settings

### Deduplication

- Same workflow failing repeatedly: In n8n error handler, check Valkey key `n8n:error:<workflow_id>` with 30m TTL. If key exists, add comment to existing ClickUp task instead of creating new.

---

## 16. Outline Events

### Capture Method
Outline webhooks -> n8n

### Configuration

In Outline: **Settings > Webhooks > New webhook subscription**
- URL: `https://n8n.helixstax.com/webhook/outline-events`
- Select events to subscribe to

### Event Catalog

| Event | Outline Event Name | Severity |
|-------|-------------------|----------|
| Document created | `documents.create` | INFO |
| Document updated | `documents.update` | INFO |
| Document deleted | `documents.delete` | WARNING |
| Document published | `documents.publish` | INFO |
| User invited | `users.invite` | INFO |
| User joined | `users.create` | INFO |
| Collection created | `collections.create` | INFO |
| Collection deleted | `collections.delete` | WARNING |
| API key used | Not available via webhook -- use Loki log monitoring | WARNING |
| Comment created | `comments.create` | INFO |

### Webhook Payload

```json
{
  "id": "<delivery-uuid>",
  "actorId": "<user-uuid>",
  "webhookSubscriptionId": "<subscription-uuid>",
  "createdAt": "2026-03-20T12:00:00.000Z",
  "event": "documents.publish",
  "payload": {
    "id": "<document-uuid>",
    "model": { /* document/collection/user properties */ }
  }
}
```

Security: Verify `Outline-Signature` header (HMAC-SHA256) in n8n before processing.

### n8n Workflow: Outline Event Router

```
Trigger: Webhook (POST from Outline)
  -> Verify HMAC signature
  -> Switch on event type:
    -> documents.delete / collections.delete:
       -> Rocket.Chat: #general "Document/Collection deleted by <user>"
       -> ClickUp: Comment on Knowledge Base task
    -> documents.publish:
       -> Rocket.Chat: #general "New document published: <title>"
    -> Default: Log to Grafana annotation
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Document deleted | Comment on Knowledge Base task |
| Collection deleted | Create task (warning) |
| User invited | Comment on Team task |

---

## 17. Backstage Events

### Capture Method
Backstage Events Service + webhook plugin -> n8n OR API polling

### Architecture

Backstage uses an internal Events Service that receives events from external sources (GitHub webhooks, etc.) and makes them available to subscribers. The Catalog Webhook Plugin can emit events when entities change.

### IMPORTANT: Backstage Event Maturity

Backstage's event system is evolving. As of early 2026, the primary approach is:
1. GitHub webhooks -> Backstage Events Service -> catalog updates
2. Catalog Webhook Plugin -> external webhook on entity changes
3. API polling as a fallback for events not exposed via webhook

### Event Catalog

| Event | Detection Method | Severity |
|-------|-----------------|----------|
| Software template executed | API polling: `GET /api/scaffolder/v2/tasks` | INFO |
| New component registered | Catalog Webhook Plugin (if configured) OR API polling | INFO |
| TechDocs built | API polling: scaffolder task status | INFO |
| Plugin error | Loki logs: `{app="backstage"} \|= "error"` | WARNING |
| Entity validation failed | Loki logs: `{app="backstage"} \|= "validation" \|= "failed"` | WARNING |

### n8n Workflow: Backstage Poller

```
Trigger: Schedule (every 15m)
  -> HTTP Request: GET /api/catalog/entities?filter=metadata.uid
  -> Compare entity count/list with stored state
  -> On new entity: -> Rocket.Chat: #engineering "New component registered: <name>"
  -> HTTP Request: GET /api/scaffolder/v2/tasks?createdAfter=<last_check>
  -> For each new completed task: -> Rocket.Chat: #engineering "Template <name> executed"
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Template executed | Comment on Engineering task |
| New component | Comment on Engineering task |
| Plugin error | Create task (warning, Engineering) |

### RISK: Backstage Webhook Plugin Maturity

The Catalog Webhook Plugin is community-maintained, not core Backstage. Verify it is compatible with your Backstage version before relying on it. Fallback to API polling is recommended as primary approach until webhook support stabilizes.

---

## 18. Fleet / osquery Events

### Capture Method
Fleet webhook automations -> n8n

### Configuration

Fleet supports native webhook automations. In Fleet:
- **Settings > Integrations > Add webhook**
- URL: `https://n8n.helixstax.com/webhook/fleet-events`
- Select policy automations and/or host status changes

### Event Catalog

| Event | Fleet Webhook Type | Severity |
|-------|-------------------|----------|
| Device non-compliant | Policy automation webhook (host answered "No") | WARNING |
| New device enrolled | Host status webhook (`host_status_webhook`) | INFO |
| Device offline 24h+ | Host status webhook (offline threshold) | WARNING |
| Policy violation detected | Policy automation webhook | WARNING-CRITICAL (by policy) |
| Vulnerability detected | CVE webhook (Fleet Premium) | WARNING-CRITICAL (by CVSS) |
| Disk not encrypted | Policy webhook: "Is disk encryption enabled?" = No | CRITICAL |
| OS outdated | Policy webhook: "Is OS up to date?" = No | WARNING |

### Fleet Webhook Payload

```json
{
  "timestamp": "2026-03-20T12:00:00Z",
  "policy": {
    "id": 1,
    "name": "Is disk encryption enabled?",
    "query": "SELECT 1 FROM disk_encryption WHERE encrypted=1;",
    "description": "Checks if disk encryption is enabled",
    "resolution": "Enable FileVault / LUKS / BitLocker"
  },
  "hosts": [
    {
      "id": 1,
      "hostname": "wakeem-laptop",
      "url": "https://fleet.helixstax.com/hosts/1",
      "display_name": "Wakeem's Laptop"
    }
  ]
}
```

### n8n Workflow: Fleet Compliance Router

```
Trigger: Webhook (POST from Fleet)
  -> Parse policy payload
  -> Switch on policy name:
    -> Disk encryption / critical compliance:
       -> ClickUp: Create task (urgent, Security)
       -> Rocket.Chat: #security @wakeem "Device <hostname> non-compliant: <policy>"
       -> Postal: Email admin@helixstax.com
    -> OS outdated / software policies:
       -> ClickUp: Create task (high, Operations)
       -> Rocket.Chat: #alerts-warning
    -> Default policy failure:
       -> ClickUp: Create task (medium, Operations)
```

### ClickUp Action

| Event | Action |
|-------|--------|
| Disk not encrypted | Create task (urgent, Security) |
| CVE detected (critical) | Create task (urgent, Security) |
| Device offline 24h+ | Create task (warning, Operations) |
| OS outdated | Create task (high, Operations) |
| New device enrolled | Comment on Inventory task |

---

## 19. Cross-Cutting Concerns

### 19.1 Event Correlation

Multiple events from different systems often indicate the same root cause. The n8n routing layer must implement correlation to prevent alert storms.

| Correlated Events | Root Cause | Single Incident |
|-------------------|-----------|-----------------|
| K3s node down + pods crashing + Prometheus target down + Traefik 502s | Node failure | "Node <name> failure" (CRITICAL) |
| Zitadel failed logins + CrowdSec brute force + Cloudflare WAF spike | Brute force attack | "Brute force attack from <IP range>" (CRITICAL) |
| PostgreSQL replication lag + backup stale + WAL archive failed | Database issue | "PostgreSQL cluster degraded" (CRITICAL) |
| MinIO health failed + Velero backup failed | Storage issue | "Object storage failure" (CRITICAL) |
| Loki ingestion stopped + missing logs for service | Service down | Correlate with pod crash events |
| OpenBao seal event + all services auth errors | Vault sealed | "OpenBao sealed - all services affected" (CRITICAL) |

### Correlation Implementation

In n8n, implement a **Correlation Engine** workflow:

```
Trigger: Webhook (receives ALL alerts from Alertmanager)
  -> Store alert in Valkey with key: alert:<fingerprint>, TTL: 15m
  -> Wait 60s (collect correlated alerts)
  -> Query Valkey for alerts in same time window
  -> Apply correlation rules (matching namespace, node, IP)
  -> If correlated group found:
     -> Create SINGLE incident task in ClickUp
     -> Reference all individual alerts in description
  -> If standalone:
     -> Route normally per severity
```

### 19.2 Escalation Chains

| Level | Timeout | Action |
|-------|---------|--------|
| L1 | 0m | Rocket.Chat notification + ClickUp task |
| L2 | 15m (CRITICAL) / 30m (WARNING) | @wakeem mention in Rocket.Chat if not acknowledged |
| L3 | 30m (CRITICAL) / 2h (WARNING) | Postal email to admin@helixstax.com |
| L4 | 1h (CRITICAL only) | Postal SMS-to-email (if configured) OR repeat email with "UNACKNOWLEDGED" prefix |

### Escalation Implementation

```
ClickUp task created with due date = now + escalation timeout
  -> n8n Schedule: Every 5m, query ClickUp for overdue unacknowledged tasks
  -> If overdue:
     -> Check task status (is it still "Open"?)
     -> Escalate to next level
     -> Update task: add comment "Escalated to L<N>"
```

### 19.3 Quiet Hours

| Severity | Business Hours (8am-10pm ET) | Off-Hours (10pm-8am ET) |
|----------|------------------------------|------------------------|
| CRITICAL | All channels (ClickUp + RC + Email + Grafana) | All channels -- no suppression |
| WARNING | All channels | Rocket.Chat + ClickUp only (suppress email) |
| INFO | All channels | Suppress entirely, batch for morning digest |

### Implementation

In n8n, add a Function node before routing that checks current time:

```javascript
const now = new Date();
const hour = now.getUTCHours() - 5; // ET offset
const isQuietHours = hour < 8 || hour >= 22;

if (isQuietHours && items[0].json.severity === 'info') {
  // Store in Valkey for morning digest
  return []; // suppress
}
if (isQuietHours && items[0].json.severity === 'warning') {
  items[0].json.suppress_email = true;
}
return items;
```

### 19.4 Client-Facing vs Internal Events

| Category | Events | Visibility |
|----------|--------|-----------|
| Client-facing | Service outage affecting client, scheduled maintenance, deployment complete | Client channel in Rocket.Chat + email if extended outage |
| Internal only | Pod restarts, memory warnings, CrowdSec bans, audit events, HPA scaling | Internal channels only |
| Security (NEVER client-facing) | Brute force attacks, vulnerability detections, failed admin logins | #security channel + admin email only |

### 19.5 Audit Trail (SOC 2 CC7.2)

Every event must be logged for compliance:

| Requirement | Implementation |
|-------------|---------------|
| Immutable log storage | All events shipped to Loki with retention >= 90 days |
| Tamper-proof | Loki object storage (MinIO) with WORM/immutable policy |
| Centralized | Single Loki instance ingests all sources |
| Searchable | Grafana Explore for log queries |
| Exportable | Loki API for audit export |

### Loki Labels for Audit Events

```yaml
# Standard label set for all audit events
labels:
  source: "<service-name>"  # zitadel, openbao, crowdsec, etc.
  event_type: "<event-type>"  # user.created, secret.accessed, etc.
  severity: "<critical|warning|info>"
  actor: "<user-or-system>"
  namespace: "<k8s-namespace>"
```

### 19.6 Alert Fatigue Prevention Summary

| Mechanism | Where | Configuration |
|-----------|-------|---------------|
| Alertmanager grouping | Alertmanager | `group_by`, `group_wait`, `group_interval` |
| Repeat interval | Alertmanager | `repeat_interval: 4h` |
| n8n dedup via ClickUp query | n8n | Query before create, comment if exists |
| Valkey cooldown keys | n8n | TTL-based keys per alert fingerprint |
| Hourly batching for INFO | n8n | Schedule trigger collects, then sends digest |
| Quiet hours | n8n | Time-based routing suppression |
| Event correlation | n8n | 60s collection window for correlated alerts |

---

## Compatibility Verification

### Helm-Chartable?

| Service | Helm Chart Available | Notes |
|---------|---------------------|-------|
| kube-prometheus-stack | Yes (`prometheus-community/kube-prometheus-stack`) | Requires K3s-specific values |
| Grafana | Yes (bundled in kube-prometheus-stack) | - |
| Loki | Yes (`grafana/loki`) | - |
| CrowdSec | Yes (`crowdsecurity/crowdsec`) | - |
| Zitadel | Yes (`zitadel/zitadel`) | Already deployed |
| OpenBao | Yes (`openbao/openbao`) | - |
| CloudNativePG | Yes (`cloudnative-pg/cloudnative-pg`) | Operator pattern |
| Valkey | Yes (`valkey/valkey`) | Official Helm chart released 2025 |
| MinIO | Yes (`minio/minio`) | - |
| Velero | Yes (`vmware-tanzu/velero`) | - |
| Outline | Yes (`outline/outline` or community) | - |
| Backstage | Yes (`backstage/backstage`) | - |
| Fleet | Yes (`fleetdm/fleet`) | - |
| n8n | Yes (`8gears/n8n` or community) | - |
| Rocket.Chat | Yes (`rocketchat/rocketchat`) | - |

### Testable in vCluster?

All services above can be deployed in vCluster for testing. The exception is:
- **Cloudflare**: External service, not deployable. Test with mock webhook payloads.
- **Hetzner**: External service, not deployable. Test with mock API responses.

### GitHub Actions Workflows Needed?

| Workflow | Purpose |
|----------|---------|
| `validate-prometheus-rules.yml` | Lint PrometheusRule YAML on PR |
| `validate-loki-rules.yml` | Lint Loki alerting rules on PR |
| `test-n8n-workflows.yml` | Validate n8n workflow JSON schema on PR |

---

## Risks and Gotchas

### HIGH RISK

1. **K3s kube-prometheus-stack false alerts**: Without K3s-specific values disabling etcd/scheduler/controller-manager/proxy monitoring, you will get constant "target down" alerts. This is the most common K3s monitoring pitfall.

2. **OpenBao has no native webhooks**: Unlike HashiCorp Vault Enterprise, OpenBao cannot push events. You MUST use the file audit device -> Loki -> Loki alerting rules pipeline. This adds latency (30-60s) to OpenBao event detection.

3. **Cloudflare plan limitations**: Several WAF-level notifications require Business or Enterprise plans. If on Pro, you must use API polling for security events, which has 5-15 minute lag.

4. **n8n Error Trigger reliability**: Community reports indicate the Error Trigger node does not fire 100% reliably in self-hosted setups. Mitigate by also monitoring n8n pod health via K8s events and n8n execution metrics via Prometheus.

5. **Hetzner has NO webhooks**: All Hetzner monitoring is poll-based. Server status changes will have 2-5 minute detection lag.

### MEDIUM RISK

6. **Alertmanager webhook delivery**: If n8n is down, Alertmanager will retry but eventually drop alerts. Configure Alertmanager with a dead-letter queue or secondary receiver (email as fallback).

7. **Loki alerting rule evaluation**: Loki Ruler evaluates rules at fixed intervals (default 1m). High-volume log pattern alerts may miss events between evaluation windows.

8. **CrowdSec HTTP plugin**: The notification plugin runs as a separate process. If it crashes, CrowdSec continues to function (decisions still enforced) but notifications stop silently. Monitor the plugin process via Loki logs.

9. **Backstage webhook maturity**: The Catalog Webhook Plugin is community-maintained. Prefer API polling as primary strategy.

### LOW RISK

10. **Valkey exporter compatibility**: redis_exporter v1.80+ fully supports Valkey. No known issues.

11. **CloudNativePG monitoring**: Built-in exporter is well-maintained and stable. PodMonitor auto-creation works reliably.

12. **Fleet webhook delivery**: Fleet retries webhook delivery with exponential backoff. Reliable in practice.

---

## Open Questions Requiring User Input

1. **Cloudflare plan level**: What plan is helixstax.com currently on? This determines whether webhook notifications or API polling is needed for WAF/security events.

2. **Grafana OnCall**: Is Grafana OnCall planned for incident management? This affects how CRITICAL alerts escalate beyond Rocket.Chat.

3. **Client notification policy**: Which specific events should trigger client-facing notifications? Need a defined list per client SLA tier.

4. **n8n instance**: Where will n8n run? Same K3s cluster or separate? If same cluster, a K3s outage means n8n (the alerting router) is also down. Consider: should n8n run on the Services VPS (5.78.145.30) as a fallback?

5. **Velero backup schedule**: What is the expected backup interval? This determines the "backup missed" alert threshold.

6. **Fleet deployment scope**: Which devices will Fleet manage? Just servers, or also workstations/laptops? This affects policy webhook volume.

7. **Alertmanager fallback**: Should email be configured as a secondary Alertmanager receiver in case n8n is unreachable? This provides defense-in-depth for CRITICAL alerts.

8. **Quiet hours timezone**: Confirmed Eastern Time (ET) for quiet hours, or different timezone?

---

## Implementation Priority

| Priority | Service | Rationale |
|----------|---------|-----------|
| P0 (Deploy first) | kube-prometheus-stack (K8s + Prometheus + Alertmanager + Grafana) | Foundation -- everything else depends on this |
| P0 | Loki + Promtail/Alloy | Log collection enables OpenBao, error detection |
| P1 | Alertmanager -> n8n webhook | Central routing pipeline |
| P1 | Zitadel Actions v2 | Auth security events are compliance-critical |
| P1 | CrowdSec notifications | Security events need real-time visibility |
| P2 | CloudNativePG monitoring | Database health is critical but operator handles failover |
| P2 | Velero alerts | Backup failure detection |
| P2 | OpenBao audit -> Loki | Secrets access audit trail |
| P2 | n8n self-monitoring | The monitoring system must monitor itself |
| P3 | MinIO notifications | Storage events |
| P3 | Valkey monitoring | Cache health |
| P3 | Cloudflare events | Edge/security events |
| P3 | Hetzner polling | Infrastructure provider events |
| P4 | Outline webhooks | Knowledge base events (low urgency) |
| P4 | Backstage events | Developer portal events (low urgency) |
| P4 | Fleet webhooks | Device compliance (deploy Fleet first) |
| P4 | Rocket.Chat outgoing hooks | Chat events (low urgency) |

---

## Summary Statistics

- **Total services covered**: 18
- **Total unique events cataloged**: ~130
- **Events requiring webhooks**: ~85
- **Events requiring API polling**: ~20
- **Events requiring Prometheus/metrics**: ~45
- **Events requiring Loki log patterns**: ~15
- **n8n workflows needed**: ~12 (some shared via Alertmanager)
- **PrometheusRule groups needed**: ~8
- **Loki alerting rule groups needed**: ~3
