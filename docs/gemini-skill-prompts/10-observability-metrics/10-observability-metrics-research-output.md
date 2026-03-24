Of course. This is an excellent project for a deep research document. I will generate a comprehensive three-part reference for Prometheus, Grafana, and Alertmanager, tailored specifically to the Helix Stax infrastructure.

The output will be structured as requested, with `SKILL.md`, `reference.md`, and `examples.md` sections for each tool.

---

# Prometheus

## Overview
Prometheus is the core of our metrics observability pipeline. It actively scrapes time-series data from configured targets, stores it efficiently, and provides a powerful query language (PromQL) to analyze it. At Helix Stax, it's our single source of truth for all system and service performance metrics, as well as the engine that evaluates and fires alerts to Alertmanager.

---
## ## SKILL.md Content
### Core Prometheus Reference for Daily Operations

#### **CLI Reference (promtool)**
**Validate Configs:**
```bash
# Validate the main prometheus.yml config
promtool check config /etc/prometheus/prometheus.yml

# Validate rule files before applying
promtool check rules /etc/prometheus/rules/*.yml
```

**Test Alerting/Recording Rules:**
```bash
# Test all rules in a file against a mock time-series test file
promtool test rules my-rules.test.yml
```

**Run CLI Queries:**
```bash
# Get the current value of a metric
promtool query instant http://localhost:9090 'up{job="kubelet"}'

# Get a metric's value over the last hour
promtool query range http://localhost:9090 'rate(container_cpu_usage_seconds_total[5m])' --start=-1h
```

**Debug Cardinality:**
```bash
# Analyze TSDB for high-cardinality labels and metrics (run on server)
promtool tsdb analyze /prometheus/
```

**HTTP API & Control:**
```bash
# Reload Prometheus config without a restart
curl -X POST http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/-/reload

# Check health & readiness (useful for k8s probes)
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready

# Get a list of all targets
curl http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/targets
```

#### **Deployment on K3s (kube-prometheus-stack)**
**Key `values.yaml` snippet:**
```yaml
prometheus:
  # The Prometheus Operator will create a Prometheus object from this spec.
  prometheusSpec:
    # 2 replicas for HA scraping jobs, but each has its own TSDB.
    replicas: 2
    # How long to keep metrics data.
    retention: 30d
    # How large the TSDB can get before old data is pruned.
    retentionSize: "50GiB"
    # Labels added to every time series and alert. Identifies the source cluster.
    externalLabels:
      cluster: "helix-stax-k3s-hetzner"
    # Scrape and evaluation interval defaults.
    scrapeInterval: "1m"
    evaluationInterval: "1m"
    # Resource allocation for our 2-node cluster.
    resources:
      requests:
        cpu: "500m"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
    # Persistence config for the TSDB.
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "local-path" # K3s default provisioner
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
```

**Upgrade Procedure:**
1.  `helm repo update prometheus-community`
2.  `helm get values kube-prometheus-stack -n monitoring > current-values.yaml`
3.  `helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f current-values.yaml`

#### **Prometheus Operator CRDs**
*   **`ServiceMonitor`**: Scrapes metrics from a `Service`'s endpoints. **Use this by default.**
*   **`PodMonitor`**: Scrapes metrics directly from a `Pod`. Use when a `Service` is not available or you need to scrape non-service pods.
*   **`PrometheusRule`**: Defines alerting and recording rules. This is how we configure all alerts.
*   **Label Selectors**: The Prometheus Operator finds CRDs using label selectors defined in the `prometheusSpec`. Our `kube-prometheus-stack` is configured to look for `ServiceMonitors` with the label `release: kube-prometheus-stack`. **Any new ServiceMonitor MUST have this label to be discovered.**

#### **PromQL Reference (Essential Queries)**
**Node Health:**
```promql
# CPU Usage % per node (excluding idle)
(1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100

# Memory Usage % per node
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Disk Usage % on root filesystem
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100
```

**Pod Health:**
```promql
# Pods in a crash loop
rate(kube_pod_container_status_restarts_total[5m]) * 60 * 5 > 0

# CPU Throttling % per pod
rate(container_cpu_cfs_throttled_seconds_total[5m]) / rate(container_cpu_cfs_periods_total[5m]) * 100
```

**Service Health (Traefik Example):**
```promql
# 5xx Server Error Rate per service
sum(rate(traefik_service_requests_total{code=~"5.*"}[5m])) by (service) / sum(rate(traefik_service_requests_total[5m])) by (service) * 100

# p99 Latency per service
histogram_quantile(0.99, sum by (le, service) (rate(traefik_service_request_duration_seconds_bucket[5m])))
```

#### **Recording Rules**
*   **When to Use:** Pre-compute expensive or frequently used PromQL queries. Reduces dashboard load times and query complexity.
*   **Naming Convention:** `level:metric:operations` (e.g., `namespace:container_cpu_usage_seconds_total:sum_rate`)
*   **Example (CPU usage per namespace):**
    ```yaml
    - name: namespace_cpu
      rules:
      - record: namespace:container_cpu_usage_seconds_total:sum_rate
        expr: sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
    ```

#### **Alerting Rules**
*   **Structure:** Defined in `PrometheusRule` CRDs.
    *   `alert`: Name of the alert.
    *   `expr`: PromQL expression that triggers the alert.
    *   `for`: Duration the expression must be true before firing (e.g., `5m`).
    *   `labels`: Metadata, especially `severity` (`critical`, `warning`, `info`).
    *   `annotations`: Human-readable message (`summary`, `description`).
*   **Essential Alert (`PodCrashLooping`):**
    ```yaml
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace!="kube-system"}[15m]) * 60 * 5 > 3
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash-looping.
        description: "The container {{ $labels.container }} has restarted {{ $value | humanize }} times in the last 15 minutes."
    ```
*   **Watchdog (Dead Man's Switch):** An alert that *must* always be firing. If it stops, our monitoring is broken.
    ```yaml
    - alert: Watchdog
      expr: vector(1)
      labels:
        severity: watchdog
      annotations:
        summary: "This is a watchdog alert to ensure the entire alerting pipeline is functional."
    ```

#### **Troubleshooting**
*   **Target Not Scraped?**
    1.  **Check Labels:** Does the `ServiceMonitor` or `PodMonitor` have the `release: kube-prometheus-stack` label?
    2.  **Check Selector:** Does the `ServiceMonitor`'s `selector` match the `Service`'s labels?
    3.  **Check Port Name:** Is the `port` name in the `ServiceMonitor`'s `endpoints` section exactly the same as the port name in the `Service` spec?
    4.  **Check Prometheus UI:** Go to `Status -> Targets`. Find your target and check for errors in the `Error` column.

*   **High Cardinality?**
    1.  **Symptom:** Prometheus memory usage is very high, queries are slow.
    2.  **Find Offender:** Run `topk(10, count by(__name__)({__name__=~".+"}))` in Prometheus to see which metrics have the most series.
    3.  **Fix:** Use `metric_relabel_configs` in your scrape config to `drop` labels that contain unique IDs, timestamps, or pod names (when an aggregate is better).


---
## ## reference.md Content
### Prometheus Deep Specifications and Advanced Patterns

#### **A1. CLI Reference (promtool)**

*   `promtool check config <file>`: Validates one or more Prometheus configuration files.
    *   Flags: `--prometheus.url` to check against a running instance's version.
*   `promtool check rules <file>`: Validates one or more rule files.
*   `promtool check web-config <file>`: Validates the `--web.config.file` YAML.
*   `promtool query instant <url> <expr>`: Executes an instant query.
    *   Flags: `--time` to specify evaluation timestamp.
*   `promtool query range <url> <expr>`: Executes a range query.
    *   Flags: `--start`, `--end`, `--step`.
*   `promtool test rules <test-file.yml>`: Unit tests rule files. Requires a test file defining input series and expected alert/metric outputs.
*   `promtool tsdb analyze <path>`: Analyzes TSDB data for cardinality issues.
    *   Flags: `--limit` to control number of results.
*   `promtool tsdb list [<path>]`: Lists all blocks in the local TSDB.
*   `promtool tsdb dump [<path>]`: Dumps raw samples for a given time range.

**HTTP API via `curl`:**

*   **Instant Query:**
    ```bash
    curl 'http://localhost:9090/api/v1/query' --data-urlencode 'query=up'
    ```
*   **Range Query:**
    ```bash
    curl 'http://localhost:9090/api/v1/query_range' --data-urlencode 'query=rate(node_cpu_seconds_total[1m])' --data-urlencode 'start=2024-03-15T10:00:00Z' --data-urlencode 'end=2024-03-15T11:00:00Z' --data-urlencode 'step=1m'
    ```
*   **Get Label Names:**
    ```bash
    curl http://localhost:9090/api/v1/labels
    ```
*   **Get Series by Matchers:**
    ```bash
    curl 'http://localhost:9090/api/v1/series' --data-urlencode 'match[]=up{job="prometheus"}'
    ```
*   **Get Target Metadata:**
    ```bash
    curl http://localhost:9090/api/v1/targets
    ```
*   **Reload Prometheus Config:**
    ```bash
    curl -X POST http://localhost:9090/-/reload
    ```
*   **Health & Readiness Checks:**
    ```bash
    curl http://localhost:9090/-/healthy
    curl http://localhost:9090/-/ready
    ```

#### **A2. Deployment on K3s (kube-prometheus-stack)**
The `kube-prometheus-stack` chart deploys the Prometheus Operator, which then deploys a `Prometheus` Custom Resource. The configuration for the Prometheus server itself lives under `prometheus.prometheusSpec`.

**Retention:**
*   `retention` / `--storage.tsdb.retention.time`: Controls time-based retention (e.g., `30d`). Data older than this is deleted.
*   `retentionSize` / `--storage.tsdb.retention.size`: Controls size-based retention (e.g., `50GB`). If the DB exceeds this size, the oldest data is deleted, even if it's within the time retention period. **This is a new feature in Prometheus; check chart version compatibility.** Size-based retention is disabled by default (`0`).

**Remote Write:** Configure this to send metrics to a long-term storage solution like Grafana Cloud, Mimir, or Thanos. Add when `30d` retention is not enough or for cross-cluster federation.
```yaml
# In values.yaml -> prometheus.prometheusSpec
remoteWrite:
  - url: "https://prometheus-prod-13-prod-us-east-0.grafana.net/api/prom/push"
    # Credentials should be stored in a Kubernetes secret
    basic_auth:
      username:
        name: grafana-cloud-credentials
        key: username
      password:
        name: grafana-cloud-credentials
        key: password
```

**Thanos Sidecar:** An alternative to remote write for long-term storage and global query view.
*   **When to add it:** When you have multiple Prometheus instances (e.g., per cluster, per region) and need a single pane of glass to query them all. It also offloads historical data to object storage (like MinIO).
*   **What it provides:** Global query view, unlimited retention via object storage, downsampling.
*   It's a heavier lift than remote write and best suited for larger, multi-cluster deployments. For a single 2-node cluster, remote write to a managed service is simpler.

#### **A3. Prometheus Operator CRDs**
*   **`ServiceMonitorSpec`**:
    *   `selector`: Label selector to find the `Service`(s) to monitor.
    *   `namespaceSelector`: Selects `Service`s from specific namespaces. `any: true` for all namespaces.
    *   `endpoints`: Array of endpoints on the service to scrape.
        *   `port`: The *name* of the service port. Must match `service.spec.ports.name`.
        *   `path`: The metrics path (e.g., `/metrics`). Defaults to `/metrics`.
        *   `interval`: Scrape interval for this endpoint, overrides global default.
        *   `scrapeTimeout`: Timeout for this endpoint, overrides global default.
        *   `scheme`: `http` or `https`.
        *   `tlsConfig`: For scraping TLS endpoints (e.g., `ca`, `cert`, `key` from secrets).
        *   `relabelings`, `metricRelabelings`: Target and metric relabeling rules.

*   **`PodMonitor`**: Similar to `ServiceMonitor`, but `selector` targets pods directly via their labels. Used for headless services, statefulsets, or daemons not exposed via a `Service`.

*   **`PrometheusRuleSpec`**:
    *   `groups`: A list of rule groups.
        *   `name`: Name of the group.
        *   `rules`: Array of alerting or recording rules.
            *   `alert`: Name of the alert.
            *   `expr`: The PromQL expression.
            *   `for`: Sustained duration for firing.
            *   `labels`: Key-value pairs attached to the alert (e.g., `severity`, `team`).
            *   `annotations`: Human-readable information (e.g., `summary`, `description`, `runbook_url`). Supports Go templating.

*   **`Probe`**: For blackbox monitoring. Scrapes the Blackbox Exporter, which in turn probes a target. For `HTTP GET`, `TCP connect`, etc.
    ```yaml
    # Example Probe target
    targets:
      staticConfig:
        - targets:
          - https://helixstax.com
    relabeling_configs:
      # ... config to pass target to blackbox exporter ...
    ```

*   **`AlertmanagerConfig`**: Scoped Alertmanager configuration (routes, receivers, inhibitions) that applies only to alerts from a specific namespace. Avoids editing the global `alertmanager.yml`. **Useful for multi-tenant clusters or letting teams manage their own alerting.**

*   **Operator Reconciliation:** The Prometheus Operator continuously watches for changes to these CRDs. When a `ServiceMonitor` is created/updated, the operator generates new scrape configurations and updates the `prometheus-operated` secret, which is mounted into the Prometheus pods. Prometheus then automatically reloads this new configuration.

#### **A9. Storage, Retention, and Performance**
*   **TSDB Layout:**
    *   `chunks`: Compressed time-series data.
    *   `index`: Inverted index mapping labels to series.
    *   `WAL` (Write-Ahead Log): New data is written here first for durability against crashes. It's replayed on startup.
    *   `head block`: The most recent data, held in memory for fast writes and reads. Periodically compacted to disk.
*   **Storage Calculation:**
    `retention_in_seconds * series_ingested_per_second * bytes_per_sample`
    For a 2-node cluster with ~20 targets, a rough estimate is ~200k series. At 1-2 bytes/sample:
    `30d*86400s * 200,000 series / (30s scrape_interval) * 1.5 bytes/sample ≈ 41.5 GB`
    So, a `50GiB` `retentionSize` and PVC is a reasonable starting point.
*   **High Cardinality:** The number of unique time series. Caused by labels with highly variable values (IDs, hashes, IPs). This explodes memory usage and index size. Detect with `promtool tsdb analyze` or by graphing `prometheus_tsdb_head_series`. Fix by dropping or rewriting labels with `metric_relabel_configs`.
*   **Series Churn:** High rate of new series creation and old series disappearing. Often caused by ephemeral pod names in labels. Mitigate by aggregating away the volatile label (e.g., `sum by (deployment)`).

#### **A10. Security and Troubleshooting**
*   **Prometheus Authentication:** The `kube-prometheus-stack` does not expose the UI with auth by default. We rely on Traefik + Authelia/Zitadel middleware. For direct access, use `kubectl port-forward` or configure `--web.config.file` for TLS/basic auth on the Prometheus server itself.
*   **RBAC**: The Prometheus Operator needs a `ClusterRole` with `get`, `list`, `watch` permissions on `Services`, `Pods`, and `Endpoints` across all namespaces to discover targets defined in `ServiceMonitors`. `kube-prometheus-stack` handles this automatically.
*   **Common Errors:**
    *   `"context deadline exceeded"`: Query is too slow/complex or the server is overloaded. Increase `--query.timeout`, use recording rules, or add resources.
    *   `"no space left on device"`: The PVC is full. Increase `storage` size in the `volumeClaimTemplate` and resize the PVC.
    *   `"too many open files"`: The `ulimit` is too low for the number of TSDB files. Adjust limits on the host node or in the pod's `securityContext`.

---
## ## examples.md Content
### Copy-Paste Examples for Helix Stax Prometheus

#### **Full `values.yaml` Snippet for kube-prometheus-stack**
This is the core configuration for Prometheus in our `helm` deployment.
```yaml
# In a file like prometheus-values.yaml, then apply with:
# helm upgrade -f prometheus-values.yaml ...

prometheus:
  # The Prometheus Operator will create a Prometheus object from this spec.
  prometheusSpec:
    # We run 2 replicas on our 2-node cluster. Prometheus itself isn't a clustered DB,
    # but this provides HA for scraping and alerting. Each has its own data.
    replicas: 2
    # Rule and scrape config files can be selected by this label selector.
    # The chart's default is good enough.
    ruleSelector: {}
    serviceMonitorSelector: {}

    # Crucial for identifying which cluster alerts/metrics are coming from.
    externalLabels:
      cluster: "helix-stax-k3s-main"
      region: "fsn1" # Falkenstein, Hetzner

    # Keep metrics for 30 days.
    retention: 30d
    # Cap storage at 50GiB per replica to prevent runaway disk usage.
    retentionSize: "50GiB"

    # Global scrape interval. ServiceMonitors can override this.
    scrapeInterval: "1m"
    evaluationInterval: "1m" # How often to evaluate rules.

    # Resource allocation. Tune based on actual usage.
    resources:
      requests:
        cpu: "500m"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "4Gi"

    # Use the K3s default 'local-path' StorageClass for persistence.
    # Data will live on the node where the pod is running.
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "local-path"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

    # Enable the web UI for debugging, we will expose it via Traefik.
    web:
      enable: true

  # Ensure Prometheus Operator finds CRDs created by this chart release.
  # This matches the label added to ServiceMonitors etc. by the parent chart.
  serviceMonitorSelector:
    matchLabels:
      release: kube-prometheus-stack

# We disable the chart's included Grafana, Alertmanager, etc. if we manage them separately.
# For our integrated setup, we will configure them in their own sections.
```

#### **Traefik `IngressRoute` for Prometheus UI**
This exposes the Prometheus UI at `prometheus.helixstax.net`. Access is controlled by Zitadel SSO via the `zitadel-forward-auth` middleware.
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: prometheus-ui
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`prometheus.helixstax.net`)
      services:
        - name: prometheus-kube-prometheus-prometheus # Service created by the chart
          port: 9090
      middlewares:
        - name: zitadel-forward-auth # Assumes a Traefik Middleware for OIDC
          namespace: auth
  tls:
    secretName: helixstax-net-tls # Wildcard cert for *.helixstax.net
```

#### **`ServiceMonitor` Examples for Helix Stax Services**

**General Note:** All `ServiceMonitor`s must have the `release: kube-prometheus-stack` label to be discovered by the Prometheus instance deployed by our Helm chart.

**Traefik:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: networking # Assuming Traefik is in 'networking' namespace
  labels:
    release: kube-prometheus-stack # VERY IMPORTANT LABEL
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  namespaceSelector:
    matchNames:
      - networking
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s # Scrape traefik more frequently
```

**CloudNativePG (PostgreSQL):** `pg_exporter` is built-in.
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cnpg-main-cluster
  namespace: databases
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      # This label is automatically added by CloudNativePG to its -metrics service
      cnpg.io/cluster: "main-db-cluster"
  namespaceSelector:
    matchNames:
      - databases
  endpoints:
  - port: metrics
    path: /metrics
    scheme: http
    interval: 1m
```

**Valkey (with exporter sidecar):**
```yaml
# In your Valkey deployment/statefulset YAML, add the exporter sidecar:
# containers:
#   - name: valkey-exporter
#     image: oliver006/redis_exporter:v1.56.0
#     env:
#     - name: REDIS_ADDR
#       value: "localhost:6379"
#     ports:
#     - name: metrics
#       containerPort: 9121
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: valkey-monitor
  namespace: cache
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: valkey # Label on your Valkey service
  namespaceSelector:
    matchNames:
      - cache
  endpoints:
  - port: metrics # This name must match the port name in the service definition
    interval: 1m
```

**MinIO:** MinIO exposes a Prometheus endpoint natively.
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio-monitor
  namespace: storage
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: minio # Label on the MinIO service
  namespaceSelector:
    matchNames:
      - storage
  endpoints:
  - port: 9000 # The main API port
    path: /minio/v2/metrics/cluster
    # MinIO requires bearer token auth for metrics
    bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    scheme: http # or https if configured
```

**ArgoCD:** Several ArgoCD components expose metrics.
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    # This will scrape argocd-server, repo-server, and application-controller
    # as they all have a 'metrics' port and the selector label.
```

**Loki:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: loki-monitor
  namespace: monitoring # Assuming Loki is also in the monitoring namespace
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: loki
  namespaceSelector:
    matchNames:
      - monitoring
  endpoints:
  - port: http-metrics
    path: /metrics
    interval: 30s
```

#### **`PrometheusRule` Example for Essential Helix Stax Alerts**
This file should be saved as `helix-stax-rules.yaml` and applied to the cluster.
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: helix-stax-cluster-rules
  namespace: monitoring
  labels:
    release: kube-prometheus-stack # VERY IMPORTANT LABEL
spec:
  groups:
    - name: node.alerts
      rules:
        - alert: NodeDown
          # Kubelet metrics are missing for a node for 5 minutes
          expr: up{job="kubelet"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is down"
            description: "The Kubelet on node {{ $labels.node }} has not been scraped for 5 minutes."

        - alert: NodeHighCPU
          expr: (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100 > 85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.instance }} has high CPU usage"
            description: "CPU usage is above 85% for 10 minutes. Current value is {{ $value | humanize }}%."

    - name: pod.alerts
      rules:
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total{namespace!="kube-system"}[15m]) * 60 * 5 > 3
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash-looping."
            description: "Container {{ $labels.container }} in pod {{ $labels.pod }} has restarted more than 3 times in the last 15 minutes."

    - name: service.alerts
      rules:
        - alert: TraefikHigh5xxErrorRate
          # More than 5% of requests to a service are 5xx errors
          expr: (sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) by (service) / sum(rate(traefik_service_requests_total[5m])) by (service)) * 100 > 5
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High 5xx error rate on Traefik service {{ $labels.service }}"
            description: "Over 5% of requests to {{ $labels.service }} are failing with 5xx errors. Current error rate: {{ $value | humanize }}%."

    - name: watchdog.alert
      rules:
        - alert: Watchdog
          # This is a dead man's switch. It should always be firing.
          # If this alert is not firing, the entire monitoring pipeline is broken.
          expr: vector(1)
          labels:
            severity: watchdog # Special severity for routing to a specific channel
          annotations:
            summary: "Watchdog alert, ensuring the pipeline is functional."
```

#### **Best Practices & Anti-Patterns (Prometheus)**

**Best Practices:**
1.  **Use Operator CRDs:** Always manage scrape configs with `ServiceMonitor`/`PodMonitor`. Avoid static configs in `prometheus.yml`.
2.  **External Labels:** Always set `externalLabels` to identify the source cluster.
3.  **Recording Rules:** Proactively create recording rules for complex dashboard queries.
4.  **Meaningful Labels:** Use labels consistently (e.g., `app`, `service`, `owner`).
5.  **`for` Clause in Alerts:** Use a `for` clause on all alerts to avoid flapping. `5m` is a good default.
6.  **Annotations with Value:** Include `{{ $value }}` and `{{ $labels.* }}` in alert annotations.
7.  **Resource Limits:** Always set CPU and memory requests/limits. Prometheus can be resource-intensive.
8.  **Persistent Storage:** Always use a `PersistentVolume` for the TSDB.
9.  **Watchdog Alert:** Always have a watchdog alert to monitor the monitors.
10. **Test Rules:** Use `promtool test rules` in CI to validate changes.

**Anti-Patterns:**
*   **Critical:** Using high-cardinality labels (e.g., `user_id`, `request_id`) in metrics. This will crash Prometheus.
*   **Critical:** Running without persistent storage. All metrics are lost on pod restart.
*   **High:** Disabling `podAntiAffinity` for replicas. If both replicas land on the same node and it goes down, you lose monitoring. `kube-prometheus-stack` sets this correctly by default.
*   **High:** No `for` clause on alerts, leading to alert spam on transient issues.
*   **Medium:** Manually editing `prometheus-operated` secret instead of using CRDs. Changes will be overwritten by the operator.
*   **Medium:** Using `irate()` in alerts. It's great for graphs but can miss spikes in alerts. `rate()` is safer for alerting.
*   **Low:** Over-aggressive scrape intervals (`< 15s`) for non-critical targets. It increases load for little benefit.

#### **Decision Matrix**
| Decision | Use Approach A | Use Approach B | Helix Stax Choice & Reason |
| :--- | :--- | :--- | :--- |
| **Target Discovery** | `static_configs` in `prometheus.yml` | `ServiceMonitor` / `PodMonitor` CRDs | **B**. Operator pattern is native to Kubernetes, declarative, and scales better. |
| **Long-Term Storage** | `remote_write` to SaaS/Mimir | `Thanos` Sidecar | **A (future)**. For our current scale, 30-day local retention is sufficient. Remote write is the simpler next step for longer retention. Thanos is overkill for a single cluster. |
| **Alerting** | All rules in Prometheus | Some rules in Grafana | **A**. All alerting logic should be in Prometheus via `PrometheusRule` CRDs. It's version-controlled and closer to the data. Grafana alerts will only be used for business metrics from PostgreSQL. |
| **Pod vs Service** | `PodMonitor` | `ServiceMonitor` | **B (default)**. `ServiceMonitor` is standard. Only use `PodMonitor` if a `Service` object doesn't exist for the target pods. |

---
# Grafana

## Overview
Grafana is our single pane of glass for all data at Helix Stax. It serves as our visualization layer for Prometheus metrics, our log aggregation viewer for Loki, our business intelligence dashboard for PostgreSQL data, and our public-facing status page. It unifies monitoring, observability, and business data into one central, SSO-protected platform.

---
## ## SKILL.md Content
### Core Grafana Reference for Daily Operations

#### **CLI & API Reference**
**CLI (run inside Grafana pod):**
```bash
# List installed plugins
grafana-cli plugins ls

# Install a new plugin
grafana-cli plugins install grafana-clock-panel

# Reset admin password (emergency use)
grafana-cli admin reset-admin-password 'new-password'
```

**HTTP API via `curl` (using a Service Account Token):**
```bash
# Create a folder
curl -X POST -H "Authorization: Bearer $GRAFANA_TOKEN" -H "Content-Type: application/json" \
  -d '{"title": "New Folder"}' https://grafana.helixstax.net/api/folders

# Get a dashboard by UID
curl -H "Authorization: Bearer $GRAFANA_TOKEN" https://grafana.helixstax.net/api/dashboards/uid/Abc123Def
```

#### **Deployment on K3s (kube-prometheus-stack)**
**Key `values.yaml` snippet:**
```yaml
grafana:
  enabled: true
  # Set admin password via a secret, not plaintext
  # Verify correct Helm values path: admin.existingSecret and admin.passwordKey for kube-prometheus-stack
  adminPassword:
    secretName: grafana-admin-credentials
    key: password
  # Persistence for Grafana's database (SQLite), plugins, etc.
  persistence:
    enabled: true
    type: pvc
    storageClassName: "local-path"
    accessModes:
      - ReadWriteOnce
    size: 10Gi
  # Provision datasources and dashboards from ConfigMaps
  sidecar:
    dashboards:
      enabled: true
      label: "grafana_dashboard" # Sidecar watches for ConfigMaps with this label
      labelValue: "1"
    datasources:
      enabled: true
      label: "grafana_datasource"
      labelValue: "1"
  # Grafana config via grafana.ini block
  grafana.ini:
    auth.generic_oauth:
      enabled: true
      name: "Zitadel"
      client_id: "1234567890@helixstax"
      # client_secret is set via env var from a secret
      scopes: "openid profile email"
      auth_url: "https://zitadel.helixstax.net/oauth/v2/authorize"
      token_url: "https://zitadel.helixstax.net/oauth/v2/token"
      api_url: "https://zitadel.helixstax.net/oauth/v2/userinfo"
    server:
      root_url: "https://grafana.helixstax.net"
    feature_toggles:
      # Required for public status page
      enable: publicDashboards
```

**Traefik IngressRoute:**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`grafana.helixstax.net`)
      services:
        - name: kube-prometheus-stack-grafana # Service created by the chart
          port: 80
  tls:
    secretName: helixstax-com-tls
```

#### **Dashboard Provisioning (GitOps)**
1.  Create or export dashboard JSON from the Grafana UI.
2.  Save the JSON into a Kubernetes `ConfigMap`.
3.  Add the label `grafana_dashboard: "1"` to the `ConfigMap`.
4.  Apply the `ConfigMap`. The sidecar will automatically pick it up and load it into Grafana.

**Example `ConfigMap`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1" # This label makes it discoverable
spec:
  data:
    traefik-dashboard.json: |
      {
        "__inputs": [],
        "__requires": [],
        "annotations": { ... },
        "panels": [ ... ],
        ...
      }
```

#### **Data Source Provisioning**
Similar to dashboards, create a YAML file in a `ConfigMap` with the label `grafana_datasource: "1"`.

**Prometheus Data Source Snippet:**
```yaml
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  uid: prometheus
  access: proxy
  # In-cluster URL for the Prometheus service
  url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
  isDefault: true
  jsonData:
    exemplars:
      - labelName: trace_id
        name: TraceID
        url: http://tempo:3100/trace/${__value__}
        datasourceUid: tempo
```

#### **Zitadel OIDC Integration**
Integration is configured in `grafana.ini`.
*   **Enable `auth.generic_oauth`**.
*   Populate `client_id`, `auth_url`, `token_url`, `api_url` from your Zitadel Application settings.
*   Store `client_secret` in a Kubernetes `Secret` and pass it as an environment variable to the Grafana pod.
*   **Role Mapping:** Use `role_attribute_path` and JMESPath expressions to map Zitadel roles to Grafana roles.
    ```ini
    [auth.generic_oauth]
    role_attribute_path = contains(roles, 'grafana-admin') && 'GrafanaAdmin' || contains(roles, 'grafana-editor') && 'Editor' || 'Viewer'
    ```

#### **Public Dashboards (Status Page)**
1.  **Enable Feature Toggle:** `enable = publicDashboards` in `grafana.ini`.
2.  In Grafana UI, go to a dashboard -> Share -> Public dashboards tab.
3.  Enable public access. Grafana generates a unique, non-guessable URL.
4.  **Design a status page:** Use `Stat` panels for uptime, `Bar gauge` for SLA thresholds, and a simple `Time series` for key metrics like p99 latency.
5.  Use a CNAME record `status.helixstax.com` to point to our Grafana instance and use a reverse proxy or Cloudflare redirect to map the path to the public dashboard URL. (Or simply link to the generated URL).

#### **Troubleshooting**
*   **Provisioned Dashboard Not Showing Up?**
    1.  Check the logs of the `grafana-sc-dashboard` sidecar container: `kubectl logs -n monitoring deploy/kube-prometheus-stack-grafana -c grafana-sc-dashboard`.
    2.  Verify the `ConfigMap` has the correct label: `grafana_dashboard: "1"`.
    3.  Check for JSON syntax errors in your dashboard model.

*   **OIDC Login Fails?**
    1.  Check Grafana logs for errors during the OIDC callback.
    2.  Verify the `redirect_uri` in Zitadel exactly matches `https://grafana.helixstax.net/login/generic_oauth`.
    3.  Ensure `client_id` and `client_secret` are correct.

*   **Dashboard Slow to Load?**
    1.  Open the Query Inspector for slow panels.
    2.  Check the query duration and number of data points.
    3.  Optimize the PromQL query or create a recording rule in Prometheus for it.
    4.  Increase the `Min interval` in the query options to reduce data points.

---
## ## reference.md Content
### Grafana Deep Specifications and Advanced Patterns

#### **B1. CLI & API Reference**
**`grafana-cli` Commands (full reference):**
*   `grafana-cli admin reset-admin-password <new password>`: Resets the admin password.
*   `grafana-cli plugins install <plugin-id> [<version>]`: Installs a plugin.
*   `grafana-cli plugins list-remote`: Lists available plugins from the repository.
*   `grafana-cli plugins ls`: Lists installed plugins.
*   `grafana-cli plugins update <plugin-id>`: Updates a plugin.
*   `grafana-cli plugins update-all`: Updates all installed plugins.
*   `grafana-cli plugins remove <plugin-id>`: Removes a plugin.

**Grafana HTTP API v1:**
*   **Authentication:** Use Service Account Tokens (preferred) or API Keys (legacy). Generate Service Account tokens in `Configuration -> Service Accounts`. They are more secure as they can be scoped with specific roles.
    ```bash
    export GRAFANA_TOKEN="glsa_..."
    export GRAFANA_URL="https://grafana.helixstax.net"
    ```
*   **Dashboards:**
    *   `GET /api/dashboards/uid/:uid`: Get dashboard by UID.
    *   `POST /api/dashboards/db`: Create/update a dashboard. Payload: `{"dashboard": {...}, "folderId": 123, "overwrite": true}`.
    *   `DELETE /api/dashboards/uid/:uid`: Delete a dashboard.
*   **Data Sources:**
    *   `GET /api/datasources`: List data sources.
    *   `POST /api/datasources`: Create a data source.
    *   `PUT /api/datasources/:id`: Update a data source.
    *   `DELETE /api/datasources/:id`: Delete a data source.
*   **Provisioning API (Unified Alerting):**
    *   `GET /api/v1/provisioning/alert-rules`: Get all alert rules.
    *   `POST /api/v1/provisioning/alert-rules`: Create a rule.
    *   `GET /api/v1/provisioning/policies`: Get notification policy tree.
    *   `PUT /api/v1/provisioning/policies`: Replace the policy tree.

#### **B3. Data Source Configuration**
**YAML Structure for Provisioning (`/etc/grafana/provisioning/datasources/`)**
```yaml
apiVersion: 1
# 'deleteDatasources' allows you to remove datasources provisioned from other files.
deleteDatasources:
  - name: OldPrometheus
    orgId: 1
datasources:
  - name: Prometheus # The name shown in the UI
    type: prometheus # The plugin type
    uid: 'prometheus-main' # A unique identifier for this datasource
    access: proxy # 'proxy' (Grafana backend sends queries) or 'direct' (browser sends queries)
    url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
    isDefault: true
    jsonData: # Type-specific settings
      httpMethod: POST
      scrapeInterval: '1m'
      exemplars:
        - labelName: trace_id
          name: TraceID
          # Use Tempo: http://tempo.observability.svc:3100
          url: http://tempo.observability.svc:3100/api/traces/${__value__}
          datasourceUid: tempo-ds
    # For credentials that should not be in plaintext
    secureJsonData:
      # e.g., for basic auth
      httpHeaderValue1: 'my-secret-token'
```

**Storing Credentials in Secrets:**
When provisioning, you can reference variables that are populated from Kubernetes secrets.
```yaml
# In your datasource provisioning file:
secureJsonData:
  # The password for the read-only user
  password: "$PG_PASSWORD"

# In your values.yaml for the kube-prometheus-stack chart:
grafana:
  # ...
  env:
    name: PG_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-grafana-user-secret
        key: password
```

#### **B4. Dashboard Provisioning (GitOps)**
*   **Dashboard UID Management:** A dashboard's UID is its unique, permanent identifier. Always define a unique UID for provisioned dashboards to prevent collisions and allow stable linking. If you export a dashboard, it will have a UID. If you create one from scratch, generate a new short UID.
*   **`editable: false`:** In the dashboard JSON, setting `"editable": false` prevents users from saving changes in the UI. This enforces the GitOps workflow. The default is `true`.
*   **Community Dashboards:** To import a dashboard from grafana.com (e.g., ID `12345`), you can use a tool or script to download the JSON model and place it into a ConfigMap.
    *   Node Exporter Full: `1860`
    *   K3s Cluster Monitoring: `15794`
    *   Traefik: `11348`
    *   Loki: `13337`
    *   PostgreSQL Database: `9628`

#### **B6. OIDC SSO with Zitadel**
**`grafana.ini` configuration block (`[auth.generic_oauth]`):**
```ini
[auth.generic_oauth]
enabled = true
allow_sign_up = true
team_ids =
team_ids_sync_interval = 60m
client_id = 1234567890@helixstax
client_secret = ${ZITADEL_CLIENT_SECRET} ; Loaded from env var
scopes = openid profile email offline_access urn:zitadel:iam:org:project:id:zitadel:master
auth_url = https://zitadel.helixstax.net/oauth/v2/authorize
token_url = https://zitadel.helixstax.net/oauth/v2/token
api_url = https://zitadel.helixstax.net/oauth/v2/userinfo
; Role mapping from Zitadel roles claim
; This JMESPath expression checks for 'grafana-admin' role, then 'grafana-editor', and defaults to 'Viewer'.
role_attribute_path = "contains(resource_owner_roles, 'grafana-admin') && 'Admin' || contains(resource_owner_roles, 'grafana-editor') && 'Editor' || 'Viewer'"
; Extract user's login from the preferred_username claim
login_attribute_path = "preferred_username"
; Extract user's display name from the name claim
name_attribute_path = "name"
; Extract user's email from the email claim
email_attribute_path = "email"
```
**Break-glass account:** To keep a local admin account after disabling basic auth (`disable_login_form = true`), you can navigate directly to `https://grafana.helixstax.net/login` and add `?disable_login_form=false` to the URL. Alternatively, keep one local admin user (`admin` by default) and rely on `grafana-cli` to reset the password if needed.

#### **B9. Alerting Decision Framework**
| Feature | Use Prometheus Alerting | Use Grafana Alerting | Decision |
| :--- | :--- | :--- | :--- |
| **Data Source** | Prometheus | Prometheus, Loki, PostgreSQL, etc. | Grafana wins on flexibility. |
| **Configuration** | `PrometheusRule` CRDs (YAML) | Grafana UI or Provisioning API | Prometheus is better for GitOps. |
| **Multi-tenancy** | `AlertmanagerConfig` CRD | Alert routing is centralized | Prometheus offers finer namespace control. |
| **Complexity** | Simple key-value labels | Rich UI, complex query types | Grafana is easier for non-PromQL experts. |
| **State** | Stateless (fires based on expr) | Can have complex state logic | Depends on the need. |
| **Our Rule:** | **Use Prometheus for all infrastructure/service alerts (CPU, disk, latency, errors).** The rules live with the code, are versioned, and use the native query engine. | **Use Grafana only for alerts on non-Prometheus data sources (e.g., business metrics in PostgreSQL).** Example: "Alert if total client count drops by 5% in one hour". |

**Configuring Grafana to use external Alertmanager:**
```yaml
# In kube-prometheus-stack values.yaml
grafana:
  grafana.ini:
    unified_alerting:
      # This is critical. It tells Grafana where to discover Alertmanagers.
      # We tell it to look for Alertmanager custom resources in the 'monitoring' namespace.
      alertmanager_config_path: /etc/grafana/alertmanager.ini
  
  # This file will be mounted into the Grafana pod
  extraConfigmapMounts:
    - name: grafana-alertmanager-config
      mountPath: /etc/grafana/alertmanager.ini
      subPath: alertmanager.ini
      configMap: grafana-alertmanager-config
      readOnly: true

# And the ConfigMap itself:
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-alertmanager-config
  namespace: monitoring
data:
  alertmanager.ini: |
    [alertmanager]
    # Use the Alertmanager custom resource managed by the Prometheus Operator
    # This enables Grafana to discover the Alertmanager replicas automatically.
    enable_alertmanager_ha_from_operator = true
    alertmanager_ha_namespace = "monitoring"
    alertmanager_ha_name = "alertmanager-main"
```

---
## ## examples.md Content
### Copy-Paste Examples for Helix Stax Grafana

#### **Data Source Provisioning `ConfigMap`**
This `ConfigMap` provisions all our essential data sources. Apply it to the `monitoring` namespace.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources-helixstax
  namespace: monitoring
  labels:
    grafana_datasource: "1" # This label makes it discoverable by the sidecar
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      uid: prometheus-main
      access: proxy
      url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      isDefault: true
      jsonData:
        scrapeInterval: "1m"
        disableRecordingRules: true # We don't want Grafana to create rules
      
    - name: Loki
      type: loki
      uid: loki-main
      access: proxy
      url: http://loki-stack.monitoring.svc.cluster.local:3100
      jsonData:
        maxLines: 1000
        # Derived field to link to traces from logs
        derivedFields:
          - datasourceUid: tempo-main # UID of our Tempo/Jaeger source
            matcherRegex: 'traceID=(\w+)'
            name: TraceID
            url: '$${__value.raw}'

    - name: Alertmanager
      type: alertmanager
      uid: alertmanager-main
      access: proxy
      url: http://alertmanager-operated.monitoring.svc.cluster.local:9093
      jsonData:
        # For HA setup, Grafana needs to know how to handle notifications
        implementation: 'prometheus'
        
    - name: "Helix Stax Business DB (PostgreSQL)"
      type: postgres
      uid: postgres-business-db
      access: proxy
      url: postgres-grafana-user:DB_PASSWORD_HERE@main-db-cluster-rw.databases.svc:5432/app_db
      jsonData:
        sslmode: "require" # Important for CloudNativePG with TLS
        # Pool settings for our read-only user
        maxOpenConns: 10
        maxIdleConns: 10
        connMaxLifetime: 14400
        postgresVersion: 16
        timescaledb: false
      # For production, retreive password from a secret instead of hardcoding
      # secureJsonData:
      #   password: "${PG_GRAFANA_PASSWORD}"
```

#### **Zitadel OIDC `values.yaml` Configuration**
This snippet goes into your `kube-prometheus-stack` values file to configure Grafana for Zitadel SSO.
```yaml
# In your helm values file...
grafana:
  # Mount the Zitadel client secret into the Grafana pod as an env var
  envFromSecret: "grafana-zitadel-oidc-secret" # Secret must contain key 'ZITADEL_CLIENT_SECRET'

  grafana.ini:
    server:
      root_url: "https://grafana.helixstax.net"
      serve_from_sub_path: false
    auth:
      disable_login_form: false # Keep true for initial setup, change to true after OIDC works
      # After successful OIDC login, redirect users to the home dashboard
      login_cookie_name: grafana_session
      login_maximum_inactive_lifetime_days: 7
    auth.generic_oauth:
      enabled: true
      allow_sign_up: true
      name: "Zitadel SSO"
      client_id: "2417xxxxxxxxxxxxxx577@helixstax" # Your Zitadel Client ID
      # The client secret is loaded from the env var defined above
      client_secret: ${ZITADEL_CLIENT_SECRET}
      # All URLs point to our Zitadel instance
      auth_url: "https://zitadel.helixstax.net/oauth/v2/authorize"
      token_url: "https://zitadel.helixstax.net/oauth/v2/token"
      api_url: "https://zitadel.helixstax.net/oauth/v2/userinfo"
      scopes: "openid profile email urn:zitadel:iam:org:project:roles"
      # Map Zitadel roles to Grafana roles. The role must be present in the ID token.
      role_attribute_path: "contains(roles, 'grafana-admin') && 'Admin' || 'Viewer'"
    feature_toggles:
      enable: publicDashboards
```

#### **CloudNativePG Read-Only User Setup**
In your CloudNativePG `Cluster` manifest, define a managed role and user for Grafana.
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: main-db-cluster
  namespace: databases
spec:
  # ... other cluster settings ...
  
  # Leverage CNPG's managed roles feature to create a read-only user for Grafana
  managed:
    roles:
    - name: grafana_reader
      # This user can only connect, not create roles or DBs
      privileges:
        - LOGIN
    users:
    - name: grafana-user
      # This user gets the 'grafana_reader' role
      role: grafana_reader
      # CNPG will automatically create and manage the secret 'grafana-user-secret'
      # containing the password.
      password:
        secret:
          name: grafana-user-secret

  # After the cluster is running, you must grant SELECT privileges to this role.
  # Connect to the database and run:
  # GRANT USAGE ON SCHEMA public TO grafana_reader;
  # GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_reader;
  # ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana_reader;
```

#### **Public Status Page Dashboard Design**
A good status page is simple, fast, and clear.
*   **Overall Status:** A single `Stat` panel at the top. Use value mappings
