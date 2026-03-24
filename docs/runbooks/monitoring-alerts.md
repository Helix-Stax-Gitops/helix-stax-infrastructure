# Monitoring and Alerts

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: ACTIVE
**Platform**: Helix Stax (2-node k3s + CX32 Authentik VM)
**Stack**: kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

---

## Prerequisites

- kube-prometheus-stack deployed in `monitoring` namespace
- Grafana accessible at http://grafana.138.201.131.157.nip.io
- Prometheus scraping cluster metrics
- `kubectl` access to create PrometheusRule and ServiceMonitor CRDs

---

## 1. Metrics to Collect

### 1.1 Node Metrics (node-exporter, built into kube-prometheus-stack)

| Metric | PromQL | Purpose |
|--------|--------|---------|
| CPU usage | `100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Capacity planning |
| Memory usage | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | OOM prevention |
| Disk usage | `(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100` | Storage planning |
| Disk I/O | `rate(node_disk_read_bytes_total[5m])` / `rate(node_disk_written_bytes_total[5m])` | Bottleneck detection |
| Network traffic | `rate(node_network_receive_bytes_total[5m])` | Bandwidth monitoring |
| Load average | `node_load1`, `node_load5`, `node_load15` | System health |

### 1.2 Kubernetes Metrics (kube-state-metrics, built into kube-prometheus-stack)

| Metric | PromQL | Purpose |
|--------|--------|---------|
| Pod restarts | `increase(kube_pod_container_status_restarts_total[1h])` | Crash detection |
| Pods not ready | `kube_pod_status_ready{condition="false"}` | Health check |
| PVC usage | `kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes` | Storage alerts |
| Deployment replicas | `kube_deployment_status_replicas_available` | Availability |

### 1.3 Authentik Metrics (CX32 VM)

Authentik exposes Prometheus metrics at `/metrics/` when enabled.

| Metric | Purpose |
|--------|---------|
| `authentik_login_total` | Login volume |
| `authentik_login_failed_total` | Brute force detection |
| `authentik_outpost_connection` | Outpost health |
| `authentik_flow_execution_duration_seconds` | OIDC latency |
| `authentik_admin_token_count` | Token sprawl |

**Scrape config** (add as additional scrape target in Prometheus):
```yaml
- job_name: 'authentik'
  scheme: https
  static_configs:
    - targets: ['auth.helixstax.net']
  metrics_path: '/metrics/'
  bearer_token: 'VAULT://authentik/prometheus-token'
```

### 1.4 NetBird Metrics

| Metric | Source | Purpose |
|--------|--------|---------|
| Connected peers | NetBird API / management dashboard | Connectivity health |
| Peer last seen | NetBird API | Detect offline nodes |

NetBird does not natively export Prometheus metrics. Monitor via:
- API polling script (CronJob) writing to a Prometheus pushgateway, OR
- Grafana HTTP API datasource to NetBird management API

### 1.5 Certificate Expiry

| Metric | PromQL | Purpose |
|--------|--------|---------|
| TLS cert expiry | `probe_ssl_earliest_cert_expiry - time()` (blackbox exporter) | Cert renewal monitoring |
| cert-manager certs | `certmanager_certificate_expiration_timestamp_seconds - time()` | cert-manager health |

### 1.6 Backup Freshness

Custom metric via textfile collector or pushgateway:

| Metric | Source | Purpose |
|--------|--------|---------|
| `backup_last_success_timestamp` | Backup script writes to node-exporter textfile | Detect missed backups |
| `backup_size_bytes` | Backup script | Detect truncated backups |

---

## 2. Alert Thresholds

### 2.1 PrometheusRule: Cluster Health

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: helix-stax-cluster-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: node-health
      rules:
        - alert: HighCpuUsage
          expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage on {{ $labels.instance }}"
            description: "CPU usage above 85% for 10 minutes. Current: {{ $value }}%"

        - alert: HighMemoryUsage
          expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage on {{ $labels.instance }}"
            description: "Memory usage above 85% for 5 minutes. Current: {{ $value }}%"

        - alert: CriticalMemoryUsage
          expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 95
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "CRITICAL: Memory near exhaustion on {{ $labels.instance }}"
            description: "Memory usage above 95%. OOM kills imminent. Current: {{ $value }}%"

        - alert: DiskSpaceRunningOut
          expr: (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Disk space running low on {{ $labels.instance }}"
            description: "Root filesystem above 85%. Current: {{ $value }}%"

        - alert: NodeDown
          expr: up{job="node-exporter"} == 0
          for: 3m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.instance }} is down"
            description: "node-exporter unreachable for 3 minutes."

    - name: kubernetes-health
      rules:
        - alert: PodCrashLooping
          expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} crash looping"
            description: "{{ $value }} restarts in the last hour."

        - alert: PodNotReady
          expr: kube_pod_status_ready{condition="false"} == 1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} not ready"
            description: "Pod has been not ready for 10 minutes."

        - alert: DeploymentReplicasMismatch
          expr: kube_deployment_status_replicas_available != kube_deployment_spec_replicas
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has replica mismatch"

        - alert: PVCNearFull
          expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} above 85%"

    - name: authentication
      rules:
        - alert: HighAuthFailureRate
          expr: rate(authentik_login_failed_total[5m]) / (rate(authentik_login_total[5m]) + 0.001) > 0.01
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Auth failure rate above 1% for 5 minutes"
            description: "Possible brute force or misconfiguration."

        - alert: AuthServiceDown
          expr: up{job="authentik"} == 0
          for: 3m
          labels:
            severity: critical
          annotations:
            summary: "Authentik is unreachable"
            description: "Cannot scrape Authentik metrics. SSO may be down."

    - name: certificates
      rules:
        - alert: CertExpiringIn14Days
          expr: certmanager_certificate_expiration_timestamp_seconds - time() < 14 * 24 * 3600
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "Certificate {{ $labels.name }} expires in less than 14 days"

        - alert: CertExpiringIn3Days
          expr: certmanager_certificate_expiration_timestamp_seconds - time() < 3 * 24 * 3600
          for: 30m
          labels:
            severity: critical
          annotations:
            summary: "CRITICAL: Certificate {{ $labels.name }} expires in less than 3 days"

    - name: backups
      rules:
        - alert: BackupMissed
          expr: time() - backup_last_success_timestamp > 26 * 3600
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Backup {{ $labels.job }} has not run in 26 hours"

    - name: database
      rules:
        - alert: PostgreSQLDown
          expr: pg_up == 0
          for: 3m
          labels:
            severity: critical
          annotations:
            summary: "PostgreSQL {{ $labels.instance }} is down"

        - alert: PostgreSQLHighConnections
          expr: pg_stat_activity_count / pg_settings_max_connections > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "PostgreSQL connections above 80% of max"
```

### 2.2 Alert Summary Table

| Alert | Threshold | Duration | Severity |
|-------|-----------|----------|----------|
| High CPU | >85% | 10m | warning |
| High Memory | >85% | 5m | warning |
| Critical Memory | >95% | 2m | critical |
| Disk Space | >85% | 10m | warning |
| Node Down | unreachable | 3m | critical |
| Pod Crash Loop | >5 restarts/hr | 5m | warning |
| Pod Not Ready | not ready | 10m | warning |
| PVC Near Full | >85% | 10m | warning |
| Auth Failures | >1% | 5m | warning |
| Auth Service Down | unreachable | 3m | critical |
| Cert Expiring | <14 days | 1h | warning |
| Cert Critical | <3 days | 30m | critical |
| Backup Missed | >26 hours | 30m | warning |
| DB Down | unreachable | 3m | critical |
| DB High Connections | >80% max | 5m | warning |

---

## 3. Grafana Dashboard Recommendations

### 3.1 Dashboards to Import

| Dashboard | Grafana ID | Purpose |
|-----------|------------|---------|
| Node Exporter Full | 1860 | Node metrics (CPU, memory, disk, network) |
| Kubernetes Cluster | 6417 | Cluster overview |
| K8s Pod Resources | 15479 | Per-pod resource usage |
| CoreDNS | 15463 | DNS query metrics |
| Traefik v2 | 17347 | Ingress metrics |
| PostgreSQL | 9628 | Database metrics (when postgres-exporter added) |

Import via: Grafana > Dashboards > Import > Enter ID.

### 3.2 Custom Dashboard: Helix Stax Overview

Create a single overview dashboard with:

| Panel | Type | Query |
|-------|------|-------|
| Cluster Health | Stat | `count(up{job="node-exporter"} == 1)` |
| Node CPU | Time series | Per-node CPU usage |
| Node Memory | Gauge | Per-node memory % |
| Active Alerts | Table | `ALERTS{alertstate="firing"}` |
| Pod Status | Pie chart | Running / Pending / Failed counts |
| Ingress Request Rate | Time series | `rate(traefik_entrypoint_requests_total[5m])` |
| Auth Login Rate | Time series | `rate(authentik_login_total[5m])` |
| Backup Status | Stat | Time since last backup |

---

## 4. Log Retention

| Log Category | Retention | Storage |
|--------------|-----------|---------|
| Auth events (Authentik) | 90 days | Authentik built-in log + Loki (future) |
| System logs (journald) | 30 days | Configured via `SystemMaxUse=2G` in `/etc/systemd/journald.conf` |
| k3s logs | 30 days | journald (on helix-cp-1) |
| Application logs | 14 days | Container stdout/stderr via `kubectl logs` |
| Prometheus metrics | 15 days | kube-prometheus-stack default retention |
| Audit logs (k8s API) | 30 days | File on helix-cp-1 (if enabled) |

### Enable journald log size limits

On both nodes:
```bash
sudo mkdir -p /etc/systemd/journald.conf.d/
cat <<EOF | sudo tee /etc/systemd/journald.conf.d/retention.conf
[Journal]
SystemMaxUse=2G
MaxRetentionSec=30day
EOF
sudo systemctl restart systemd-journald
```

---

## 5. Prometheus Scrape Targets

### Current (kube-prometheus-stack defaults)

| Target | Job Name | Port | Interval |
|--------|----------|------|----------|
| node-exporter | node-exporter | 9100 | 30s |
| kube-state-metrics | kube-state-metrics | 8080 | 30s |
| kubelet | kubelet | 10250 | 30s |
| cAdvisor | kubelet | 10250 | 30s |
| CoreDNS | coredns | 9153 | 30s |
| Alertmanager | alertmanager | 9093 | 30s |
| Prometheus | prometheus | 9090 | 30s |

### To Add: Authentik

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: authentik-metrics
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  jobName: authentik
  prober:
    url: prometheus:9090
  targets:
    staticConfig:
      static:
        - auth.helixstax.net
      relabelingConfigs:
        - sourceLabels: [__address__]
          targetLabel: __param_target
```

Alternatively, if Authentik is in-cluster (Kubernetes deployment), use a ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: authentik
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames: [authentik]
  selector:
    matchLabels:
      app: authentik
  endpoints:
    - port: http
      path: /metrics/
      interval: 30s
```

### To Add: NetBird (if metrics become available)

NetBird does not currently expose Prometheus metrics. Monitor via:
1. Custom exporter script polling NetBird management API
2. Pushgateway approach
3. Wait for upstream Prometheus support

---

## 6. Alertmanager Configuration

### Notification Channels

For a single-admin platform, keep it simple:

| Channel | When | Setup |
|---------|------|-------|
| Grafana built-in alerts | All alerts | Grafana > Alerting > Contact points |
| Email to Wakeem | Critical alerts | Alertmanager SMTP config |
| Telegram (optional) | Critical alerts | Alertmanager Telegram webhook |

### Alertmanager Config Example

```yaml
# In kube-prometheus-stack Helm values
alertmanager:
  config:
    route:
      receiver: 'default'
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - match:
            severity: critical
          receiver: 'critical'
          repeat_interval: 1h
    receivers:
      - name: 'default'
        # Grafana notification or email
      - name: 'critical'
        email_configs:
          - to: 'VAULT://admin/email'
            from: 'alerts@helixstax.net'
            smarthost: 'smtp.example.com:587'
            auth_username: 'VAULT://smtp/username'
            auth_password: 'VAULT://smtp/password'
```

---

## 7. Verification

After deploying monitoring changes:

- [ ] `kubectl -n monitoring get prometheusrule` shows new rules
- [ ] `kubectl -n monitoring get servicemonitor` shows expected targets
- [ ] Grafana > Alerting > Alert rules shows all alerts
- [ ] Prometheus > Status > Targets shows all scrape targets as UP
- [ ] Test alert fires correctly (temporarily lower a threshold)
- [ ] Notification reaches Wakeem (email/Telegram)
