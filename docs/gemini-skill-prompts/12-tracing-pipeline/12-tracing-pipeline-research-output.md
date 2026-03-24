Here is the comprehensive research document for OpenTelemetry and Grafana Tempo, tailored for Helix Stax and its AI coding agents.

***

# OpenTelemetry

## ## SKILL.md Content

### Overview

OpenTelemetry (OTel) is an observability framework for instrumenting, generating, collecting, and exporting telemetry data such as traces, metrics, and logs. For our stack, OTel instrumentation in applications sends traces to the OTel Collector. The Collector processes these traces and forwards them to Grafana Tempo for storage. Metrics are handled by Prometheus and logs by Loki; OTel complements them by providing distributed traces.

### OTel Collector Architecture

-   **Signal Flow**: App (SDK) → OTel Collector (Gateway) → Grafana Tempo
-   **Deployment Mode**: We use the **Gateway** pattern (`Deployment`). A single, centralized Collector is simpler to manage and scale for our 2-node cluster and is required for effective tail-based sampling.

### Key CLI Commands

```bash
# Define your collector release and namespace
export RELEASE_NAME=otel-collector
export NAMESPACE=observability

# Check Collector logs for errors (ingestion, processing, export)
kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-collector -f

# Check resource usage (CPU/Memory)
kubectl top pod -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-collector

# Verify the Collector service endpoint for apps to connect
kubectl get svc -n $NAMESPACE $RELEASE_NAME
# NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                               AGE
# otel-collector    ClusterIP   10.43.123.155   <none>        4317/TCP,4318/TCP,55679/TCP,13133/TCP   1d

# The application endpoint within the cluster is:
# otel-collector.observability.svc.cluster.local:4317 (for gRPC)
```

### OTel Collector Minimal Config (`config.yaml`)

This is a minimal working configuration for a gateway Collector.

```yaml
# This config is embedded in the Helm chart's values.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  # Processors are executed in the order they are defined
  memory_limiter:
    check_interval: 1s
    limit_mib: 200 # Max memory for the collector pod
    spike_limit_mib: 50
  batch:
    send_batch_size: 8192
    timeout: 200ms
  k8sattributes:
    # Adds pod, namespace, node metadata to spans
    # See reference.md for RBAC requirements
    passthrough: false
    extract:
      metadata:
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.deployment.name
        - k8s.namespace.name
        - k8s.node.name
        - k8s.pod.start_time
        - k8s.replicaset.name
  resource:
    attributes:
      - key: k8s.cluster.name
        value: "helix-stax-k3s"
        action: upsert

exporters:
  otlp/tempo:
    # Endpoint for Grafana Tempo (single-binary mode)
    endpoint: tempo.observability.svc.cluster.local:4317
    tls:
      insecure: true # Communication is internal to the cluster
  logging:
    # For debugging: logs traces/metrics to the collector's own log stream
    #loglevel: debug # Uncomment to see everything

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes, resource, batch]
      exporters: [otlp/tempo, logging] # Remove 'logging' for production
```

### Application Configuration (Environment Variables)

Set these in your Kubernetes `Deployment` or `StatefulSet` specs.

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "my-app-name" # e.g., "n8n", "traefik"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.observability.svc.cluster.local:4317" # gRPC endpoint — use http:// for in-cluster unencrypted
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "grpc" # Use 'grpc' or 'http/protobuf'
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "k8s.pod.name=$(POD_NAME),k8s.namespace.name=$(POD_NAMESPACE)"
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

### Troubleshooting Decision Tree

1.  **Symptom**: No traces visible in Grafana.
    *   **Check 1**: Are spans reaching the Collector?
        *   **Action**: `kubectl logs` on the **application pod**. Look for connection errors to the Collector endpoint (`otel-collector.observability.svc.cluster.local:4317`).
        *   **Action**: Check for `NetworkPolicy` blocking egress from the app pod to the Collector's namespace/port.
    *   **Check 2**: Is the Collector receiving and exporting spans?
        *   **Action**: `kubectl logs` on the **Collector pod**. Enable the `logging` exporter temporarily. If you see spans logged, the Collector is receiving them.
        *   **Cause**: If no spans are logged, the issue is between the App and Collector. If spans are logged, the issue is between the Collector and Tempo.
    *   **Check 3**: Is the Collector successfully exporting to Tempo?
        *   **Action**: `kubectl logs` on the **Collector pod**. Look for errors like `context deadline exceeded` or `connection refused` related to the Tempo endpoint (`tempo.observability.svc.cluster.local:4317`).
        *   **Fix**: Verify the Tempo service name and port in the Collector's `exporters` config. Use `kubectl get svc -n observability` to confirm.
2.  **Symptom**: Collector pod is OOMKilled or has high memory usage.
    *   **Cause**: A sudden spike in trace volume exceeded the memory limit.
    *   **Fix**: Ensure the `memory_limiter` processor is the **first** processor in your pipeline. It acts as a gatekeeper. Adjust `limit_mib` in the Collector config based on `kubectl top pod` observations.
3.  **Symptom**: Traces appear but are not linked together (broken trace).
    *   **Cause**: Context propagation format mismatch. Service A uses `W3C` but Service B expects `B3`.
    *   **Fix**: Standardize on `W3C TraceContext` across all services. This is the default for modern OTel SDKs. Ensure ingress controllers (Traefik) are configured to propagate this header.

## ## reference.md Content

### OpenTelemetry Architecture In-Depth

#### Signal Types & Our Stack

-   **Traces**: Handled by OTel. Applications are instrumented with OTel SDKs, which generate spans. These are sent to the OTel Collector, which processes and exports them to Grafana Tempo.
-   **Metrics**: Handled by Prometheus. While OTel can collect and export metrics (and we may use this for specific cases like the Tempo metrics-generator), our primary metrics pipeline is Application → Prometheus Scrape → Prometheus TSDB.
-   **Logs**: Handled by Loki. Applications write to `stdout`/`stderr`, which are collected by an agent (e.g., Promtail) and sent to Loki. We correlate logs and traces by injecting the `trace_id` into log lines.

#### Collector vs. No-Collector

Sending traces directly from an application to a backend like Tempo is possible but brittle. The Collector acts as a robust agent on the edge of our telemetry pipeline.

| Feature             | Direct Export (App → Tempo)                                | OTel Collector (App → Collector → Tempo)                                                                         |
| ------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Buffering/Retry** | App SDK's responsibility. Often basic.                     | Collector provides robust in-memory/disk buffering and retry mechanisms. The app offloads traces and moves on. |
| **Processing**      | Limited. Any change requires app redeployment.             | Centralized processing (e.g., adding attributes, redacting data, sampling) without touching application code.      |
| **Routing**         | App is hardcoded to one backend.                           | Collector can route to multiple backends simultaneously (e.g., Tempo for long-term, Jaeger for local dev, X-Ray).  |
| **Sampling**        | Only head-based sampling is possible.                      | Enables advanced **tail-based sampling** (sample based on the completed trace), critical for capturing all errors. |
| **Efficiency**      | Many small connections from every app pod to the backend.  | Collector batches data, reducing network overhead and load on the backend with fewer, larger requests.            |

**Verdict**: The Collector is non-negotiable for a production-grade tracing pipeline.

#### Collector Deployment Patterns

1.  **Agent (DaemonSet)**: One Collector pod per node.
    *   **Pros**: Receives data over local node network, ideal for host metrics, reduces cross-node traffic.
    *   **Cons**: Cannot perform tail-based sampling (a trace's spans can be spread across multiple agents). State (like sampling decisions) is fragmented.
2.  **Gateway (Deployment)**: A centralized cluster of Collector pods behind a Service.
    *   **Pros**: All spans for a trace can arrive at the same Collector instance (with a single replica), enabling tail-based sampling. Central point for configuration and policy.
    *   **Cons**: All trace traffic is funneled to one point, requires more careful scaling.
3.  **Sidecar (Container in App Pod)**: A Collector container per application pod.
    *   **Pros**: Language-agnostic collection, isolates app from Collector config.
    *   **Cons**: High resource overhead (one Collector per pod), complex to manage.

**Recommendation for Helix Stax**: Start with a **single-replica Gateway Deployment**. This is simple, sufficient for a 2-node cluster's traffic, and immediately enables powerful tail-based sampling. As we scale, we can add a second tier of Agent DaemonSets that forward to the Gateway.

#### OTel Operator for Kubernetes

The OTel Operator automates Collector deployment (via `OpenTelemetryCollector` CRD) and application instrumentation (via `Instrumentation` CRD and annotations).

| Aspect                  | OTel Operator                                                              | Manual Helm Chart                                                               |
| ----------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Collector Mgmt**      | Manages Collector lifecycle via a CRD (`OpenTelemetryCollector`).          | Standard Helm release (`helm install`, `helm upgrade`).                         |
| **Auto-Instrumentation** | Injects and configures SDKs via pod annotation (`instrumentation.opentelemetry.io/inject-java`). Supported: Java, Node.js, Python, .NET. Go is experimental. | Requires manual SDK setup or using services with native OTel support.         |
| **Complexity**          | Adds another operator and two CRDs to the cluster.                         | Simpler dependency graph; just one Helm release to manage.                      |
| **Use Case**            | Ideal for environments with many polyglot microservices needing instrumentation without code changes. | Ideal for stacks where most services have native OTel support (like ours: Traefik, Zitadel) or a few services requiring manual instrumentation. |

**Recommendation for Helix Stax**: **Start with the manual Helm chart for the Collector**. It is simpler and most of our initial targets (Traefik, Zitadel) have excellent native OTel support configured via environment variables. Re-evaluate using the Operator if/when we have a large number of custom applications (e.g., Python, Node.js) that would benefit from annotation-based injection.

### OTel Collector Configuration Schema

File: `config.yaml`

```yaml
# Root configuration structure
receivers:
  # Defines how data gets into the Collector. E.g., otlp, jaeger, zipkin, prometheus
  <receiver_name>/<classifier>:
    ...
processors:
  # Defines how data is processed. Executed in the order defined in the pipeline. E.g., batch, memory_limiter, attributes, tail_sampling
  <processor_name>/<classifier>:
    ...
exporters:
  # Defines where data is sent. E.g., otlp, logging, prometheusremotewrite, file
  <exporter_name>/<classifier>:
    ...
extensions:
  # Ancillary components, e.g., health checks, performance profiling.
  <extension_name>/<classifier>:
    # E.g., health_check, pprof, zpages
    ...
service:
  extensions: [<extension_name>, ...]
  pipelines:
    # A pipeline is a chain of receivers, processors, and exporters for a specific signal
    traces | metrics | logs:
      receivers: [<receiver_name>, ...]
      processors: [<processor_name>, ...]
      exporters: [<exporter_name>, ...]
```

### Processors Deep Dive

-   **`memory_limiter`**: Essential for preventing OOMKills. **Must be the first processor in the pipeline.**
    -   `check_interval`: How often to check memory usage (default `1s`).
    -   `limit_mib`: Hard memory limit in MiB. If exceeded, Collector starts rejecting data.
    -   `spike_limit_mib`: Additional buffer for short spikes. Data is still processed.
-   **`batch`**: Essential for performance. Batches spans/metrics before exporting.
    -   `send_batch_size`: Max number of items in a batch (default `8192`).
    -   `timeout`: Max time to wait before sending an incomplete batch (default `200ms`). **Tune this based on latency requirements vs. efficiency.** A lower timeout increases write frequency.
-   **`k8sattributes`**: Enriches spans with Kubernetes metadata.
    -   **RBAC**: Requires a `ClusterRole` with `get`, `watch`, `list` permissions on `pods` and `namespaces`. The Helm chart can create this for you.
    -   **How it works**: It watches the K8s API. When a span arrives, it uses the source IP to look up the corresponding pod and attaches its metadata as resource attributes (`k8s.pod.name`, etc.). This requires the app to signal its identity.
    -   **Identity Signal**: The app pod must have the `OTEL_RESOURCE_ATTRIBUTES` env var set with at least the pod IP. Better still, use the Downward API to inject `pod.name` and `namespace.name`, as this allows the processor to look up data more efficiently.
-   **`tail_sampling`**: The most powerful sampling method.
    -   **Requirement**: Needs all spans for a given trace to arrive at the same Collector instance. This works perfectly with a single-gateway-replica model.
    -   **Configuration**:
        ```yaml
        processors:
          tail_sampling:
            decision_wait: 10s # How long to wait for all spans of a trace
            num_traces: 50000  # Max number of traces to keep in memory while waiting
            policies:
              # Policies are evaluated in order. The first one that matches determines the decision.
              - name: errors-rule
                type: status_code
                status_code:
                  status_codes: [ERROR]
              - name: slow-traces-rule
                type: latency
                latency:
                  threshold_ms: 2000 # Sample traces slower than 2s
              - name: health-checks-rule # Drop health checks
                type: and
                and:
                  matchers:
                    - type: string_attribute
                      key: http.target
                      values: ["/healthz"]
              - name: probabilistic-rule
                type: probabilistic
                probabilistic:
                  sampling_percentage: 10 # Sample 10% of all other traces
        ```

### Security Hardening

-   **Disable Unused Receivers**: Only enable the receivers you need (`otlp`). Do not expose Jaeger/Zipkin ports unless legacy apps require them.
-   **NetworkPolicy**: Restrict access to the Collector's ports (4317, 4318) to pods within the cluster.
-   **TLS**: For communication between the Collector and backend (Tempo), use TLS if the backend is outside the cluster or in a different trust domain. For our in-cluster setup, `insecure: true` is acceptable.
-   **Authentication**: Use the `otel-contrib` `oauth2client` extension/authenticator if the backend requires authentication.

## ## examples.md Content

### Helm Deployment: OTel Collector

This `values.yaml` deploys the OpenTelemetry Collector as a single-replica gateway.

**File: `otel-collector-values.yaml`**

```yaml
# This runs: helm install otel-collector open-telemetry/opentelemetry-collector -n observability -f otel-collector-values.yaml

# Use the opentelemetry-collector chart
# We are NOT using the 'opentelemetry-operator' meta-chart for now.

mode: "deployment" # 'deployment' for Gateway mode, 'daemonset' for Agent mode

# A single replica is required for tail-based sampling to work reliably at small scale
replicas: 1

# Resource limits for our 2-node cluster. Monitor and adjust.
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 200Mi

# The Collector config is the most important part.
# It's defined here and passed to the Collector pods via a ConfigMap.
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"

  processors:
    # Processors are chained. Order matters.
    # 1. Reject data if memory is high to prevent OOMKill.
    memory_limiter:
      check_interval: 1s
      limit_mib: 400
      spike_limit_mib: 100

    # 2. Enrich with Kubernetes metadata.
    k8sattributes:
      auth_type: "serviceAccount"
      passthrough: false
      filter:
        node_from_env_var: K8S_NODE_NAME # Not strictly necessary but good practice
      extract:
        metadata:
          - k8s.pod.name
          - k8s.pod.uid
          - k8s.deployment.name
          - k8s.namespace.name
          - k8s.node.name
          - k8s.pod.start_time
      pod_association:
        - from: connection

    # 3. Add global resource attributes.
    resource:
      attributes:
        - key: deployment.environment
          value: "production"
          action: insert
        - key: k8s.cluster.name
          value: "helix-stax-k3s-hetzner"
          action: insert

    # 4. Make sampling decisions.
    tail_sampling:
      decision_wait: 10s
      num_traces: 50000
      policies:
        # Policy 1: Always sample traces with an error.
        - name: policy-errors
          type: status_code
          status_code:
            status_codes: [ERROR]
        # Policy 2: Always sample traces that are slower than 1 second.
        - name: policy-slow
          type: latency
          latency:
            threshold_ms: 1000
        # Policy 3: For everything else, sample 15% of traces.
        - name: policy-probabilistic
          type: probabilistic
          probabilistic:
            sampling_percentage: 15

    # 5. Batch data before sending to reduce network overhead. ALWAYS last processor before exporter.
    batch:
      send_batch_size: 8000
      timeout: 1s

  exporters:
    # Export to Grafana Tempo
    otlp/tempo:
      endpoint: "tempo.observability.svc.cluster.local:4317"
      tls:
        insecure: true

    # For debugging purposes, can be removed in production
    logging:
      loglevel: info # Use 'debug' to see full trace data

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, resource, tail_sampling, batch]
        exporters: [otlp/tempo, logging] # Remove 'logging' in prod

# The Helm chart can create the necessary ClusterRole and ClusterRoleBinding for the k8sattributes processor.
# It automatically detects that the processor is in use.
# Verify these settings if you have RBAC issues.
serviceAccount:
  create: true

clusterRole:
  create: true
  rules:
    - apiGroups: [""]
      resources: ["pods", "namespaces", "nodes"]
      verbs: ["get", "list", "watch"]
```

### Service-Specific Integrations

#### Traefik (v3+) OTel Tracing

Enable tracing in your Traefik Helm chart.

**File: `traefik-values.yaml` (snippet)**

```yaml
additionalArguments:
  - "--tracing.otel=true"
  - "--tracing.otel.grpc.insecure=true"
  # OTel Collector gRPC endpoint
  - "--tracing.otel.grpc.address=otel-collector.observability.svc.cluster.local:4317"
  # Ensure the service name is set for easy filtering
  - "--tracing.otel.attributes.service.name=traefik"

# To get trace IDs into access logs for correlation with Loki:
logs:
  access:
    enabled: true
    format: json
    fields:
      headers:
        defaultmode: keep
        names:
          # This will extract the W3C traceparent header into the access log
          traceparent: keep
```

#### n8n OTel Instrumentation

n8n has native OTel support via environment variables.

**File: `n8n-deployment.yaml` (env block snippet)**

```yaml
# ... in your Deployment spec.template.spec.containers[0]
env:
  # n8n specific env vars...
  - name: OTEL_SERVICE_NAME
    value: "n8n"
  # Use http/protobuf for node.js if grpc causes issues, but grpc is generally more efficient
  - name: OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
    value: "http://otel-collector.observability.svc.cluster.local:4317" # Yes, 'http' even for gRPC port
  - name: OTEL_EXPORTER_OTLP_TRACES_PROTOCOL
    value: "grpc"
  # For k8sattributes processor
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "k8s.pod.name=$(POD_NAME),k8s.namespace.name=$(POD_NAMESPACE)"
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

#### Zitadel OTel Instrumentation

Zitadel is a Go application with first-class OTel support. Configure it in the Zitadel YAML config.

**File: `zitadel-config.yaml` (snippet)**

```yaml
Tracing:
  # Must be set to 'otel' to enable OpenTelemetry
  Type: "otel"
  # Set a service name for filtering in Grafana/Tempo
  ServiceName: "zitadel"
  # The endpoint of your OpenTelemetry collector.
  Endpoint: "otel-collector.observability.svc.cluster.local:4317"
```

***

# Grafana Tempo

## ## SKILL.md Content

### Overview

Grafana Tempo is a high-volume, minimal-dependency distributed tracing backend. It stores traces efficiently in object storage (MinIO for us) and is queried using TraceQL. It's designed to integrate seamlessly with Grafana, Loki (logs), and Prometheus (metrics) to provide a unified observability experience. We use it in `single-binary` mode, which is perfect for our cluster size.

### Key CLI Commands

```bash
# Define your tempo release and namespace
export RELEASE_NAME=tempo
export NAMESPACE=observability

# Check Tempo logs for ingestion or query errors
kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=tempo -f

# Check resource usage
kubectl top pod -n $NAMESPACE -l app.kubernetes.io/name=tempo

# Verify the Tempo service endpoint
kubectl get svc -n $NAMESPACE $RELEASE_NAME
# NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                         AGE
# tempo   ClusterIP   10.43.200.100   <none>        3200/TCP,4317/TCP,9095/TCP                      1d

# Key Ports:
# 3200: Tempo HTTP API / Grafana data source
# 4317: OTLP gRPC endpoint (for receiving traces from OTel Collector)
# 9095: Service graph metrics (if enabled)
```

### Grafana Data Source Setup

1.  Navigate to `Connections -> Data sources` in Grafana.
2.  Click `Add new data source` and choose `Tempo`.
3.  **URL**: `http://tempo.observability.svc.cluster.local:3200`
4.  **Trace to Logs**:
    *   Data source: `Loki`
    *   Tags: `job`, `instance`, `pod` (or whatever labels your logs have)
    *   Filtered query: `{job="${__span.tags['job']}"} | json | line_format "{{.message}}" | has "trace_id=${__trace.id}"`
    *   **Important**: This requires your logs to contain `trace_id=...` or a similar field.
5.  Click `Save & test`.

### Common TraceQL Queries

Use these in Grafana's `Explore` view with the Tempo data source.

| Use Case                                  | TraceQL Query                                                                  |
| ----------------------------------------- | ------------------------------------------------------------------------------ |
| Find all traces for a service             | `{ resource.service.name = "traefik" }`                                        |
| Find error traces for any service         | `{ status = error }`                                                           |
| Find slow traces (> 500ms) for n8n        | `{ resource.service.name = "n8n" && duration > 500ms }`                        |
| Find traces for a specific HTTP path      | `{ resource.service.name = "traefik" && span.http.target = "/my/api/endpoint" }` |
| Find traces with a specific HTTP status   | `{ span.http.status_code = 500 }`                                              |
| Find traces by Trace ID                   | `{ traceid = "a1b2c3d4..." }`                                                  |
| Count spans in traces through Traefik     | `{ resource.service.name = "traefik" } | count()`                               |

### Troubleshooting Decision Tree

1.  **Symptom**: "Search" in Grafana shows no services, queries return "No traces found".
    *   **Check 1**: Is Tempo receiving traces from the OTel Collector?
        *   **Action**: `kubectl logs` on the **Tempo pod**. Look for lines about `ingester` processing spans. If you see errors about `s3` or `MinIO`, the problem is storage. If you see no traffic, the problem is upstream (at the Collector).
    *   **Check 2**: Is the Grafana data source configured correctly?
        *   **Action**: In Grafana, go to the Tempo data source settings. Verify the URL is correct and click `Save & test`. Check DNS resolution from the Grafana pod: `kubectl exec -it <grafana-pod> -- nslookup tempo.observability.svc.cluster.local`.
    *   **Check 3**: Is your time range correct?
        *   **Action**: In Explore, set the time range to "Last 4 hours" or longer. Recent traces might not be queryable yet if they are still in the ingester's WAL.
2.  **Symptom**: MinIO bucket is growing, but Tempo queries find nothing.
    *   **Cause**: Compaction might not be running, or retention is not configured, leading to unqueryable blocks.
    *   **Fix**: Check **Tempo** logs for `compactor` errors. Ensure the `compactor` component is enabled in your config and that it can write back to the MinIO bucket.
3.  **Symptom**: Tempo pod logs show MinIO `403 Forbidden` errors.
    *   **Cause**: Incorrect `access_key` or `secret_key`.
    *   **Fix**: Verify the Kubernetes Secret containing the MinIO credentials. Decode the values to ensure they are correct (`echo "dGVzdAo=" | base64 -d`). Ensure the secret is correctly mounted by the Tempo pod.

## ## reference.md Content

### Grafana Tempo Architecture (Single-Binary)

For our scale, we deploy Tempo in its `single-binary` or `monolithic` mode. This runs all logical components within a single process/pod, simplifying deployment and management.

**Target**: `all` (default for single-binary)

-   **Distributor**: Receives traces from clients (OTel Collector). Hashes the `traceID` to determine which ingester should handle it (in a scaled-out scenario). In single-binary, it just passes it to the local ingester.
-   **Ingester**: The stateful part. Receives traces, batches them in memory, and writes them to a Write-Ahead Log (WAL) on a PVC for durability. After a certain time/size, it "flushes" a completed block of traces to long-term object storage (MinIO).
-   **Querier**: Services queries from Grafana. It queries both the Ingesters (for recent data in the WAL) and the object storage (via the `query-frontend`).
-   **Query-Frontend**: An optional (but recommended) component that sits in front of the Querier. It splits large queries, caches results, and can queue queries. Included in `single-binary`.
-   **Compactor**: A background process that scans the object storage. It combines smaller blocks into larger, more efficient ones and enforces the data retention policy by deleting old blocks.

**Data Flow:**
`OTel Collector -> Distributor -> Ingester -> [WAL on PVC] -> [Flush to MinIO]`
`Grafana -> Query-Frontend -> Querier -> [Ingester (recent)] & [MinIO (older)]`

**ASCII Diagram:**
```
                     ┌───────────────────────┐         ┌─────────────────────────┐
                     │ OTel Collector        │         │ Grafana                 │
                     └───────────────────────┘         └─────────────────────────┘
                              │   ▲                            │
(OTLP gRPC, Port 4317)          │   │ (Metrics)                  │ (HTTP API, Port 3200)
                              ▼   │                            ▼
      .----------------------[Tempo Single-Binary Pod]------------------------.
      |                                                                       |
      |  ┌─────────────┐   ┌─────────────┐   ┌──────────────┐   ┌──────────┐  |
      |  │ Distributor ├─► │ Ingester    ├─► │ Query-        ├─► │ Querier  │  |
      |  └─────────────┘   └──────┬──────┘   │   Frontend   │   └─────┬────┘  |
      |                           │           └──────▲───────┘         │       |
      |               (WAL)       │                  │                 │       |
      |  ┌─────────────┐◄─────────┘                  │                 │       |
      |  │ PVC Volume  │                             │                 │       |
      |  └─────────────┘          ┌─────────────┐    │                 │       |
      |                           │ Compactor   ◄────┴─────────────────┤       |
      |                           └─────┬───────┘                      │       |
      '---------------------------------│------------------------------'       |
                                        │                                      │
               (Read/Write/Delete)      │             (Read)                   │
                                        ▼                                      ▼
                           ┌───────────────────────────┐
                           │ MinIO Object Storage      │
                           │ (tempo-traces bucket)     │
                           └───────────────────────────┘
```

### MinIO Backend Full Configuration

The `storage` block in Tempo's config is critical.

```yaml
# In Tempo Helm values.yaml
tempo:
  storage:
    trace:
      backend: s3 # Must be 's3' for MinIO
      s3:
        endpoint: minio.minio-operator.svc.cluster.local:9000 # Your MinIO service endpoint
        bucket: tempo-traces # A dedicated bucket for Tempo
        region: us-east-1 # MinIO doesn't care, but the field is required
        insecure: true # Use HTTP for in-cluster communication
        access_key: ${MINIO_ACCESS_KEY} # Injected from secret
        secret_key: ${MINIO_SECRET_KEY} # Injected from secret
```

### TraceQL Syntax Reference

TraceQL is composed of a set of span-selectors in curly braces `{}`, followed by an optional pipeline `|`.

`{ <span-selector> } | <pipeline_operation>`

**Span Selectors**:
-   `<attribute> <operator> <value>`
-   **Attributes**: Can be intrinsic (`name`, `status`, `duration`, `traceid`) or based on resource/span attributes.
    -   `resource.service.name`: The service name of the application.
    -   `span.http.method`: A standard span attribute from the OTel semantic conventions.
-   **Operators**: `=`, `!=`, `>`, `>=`, `<`, `<=`, `=~` (regex match), `!~` (regex not match).
-   **Values**: Strings (in double quotes), numbers, durations (`200ms`, `1.5s`, `1m`).
-   **Logical Operators**: `&&` (AND), `||` (OR). Use parentheses for grouping.

**Pipeline Operations**:
-   `| count()`: Counts the number of spans matching the selector, aggregated by trace.
-   `| avg(duration)`, `| max(duration)`, `| min(duration)`: Aggregates the duration of matching spans.
-   `| select(<attribute1>, <attribute2>)`: Projects specified attributes into the results.

### Metrics-Generator Deep Dive

The metrics-generator derives RED (Rate, Errors, Duration) metrics and service graph data from your trace stream. This is incredibly powerful as it gives you application metrics without needing to add Prometheus instrumentation for them.

**Configuration (in Tempo Helm `values.yaml`)**:
```yaml
tempo:
  metricsGenerator:
    enabled: true
    # This config gets passed to the Tempo process
    config:
      storage:
        path: /var/tempo/generator_wal
        remote_write:
          # Requires Prometheus --web.enable-remote-write-receiver flag (not enabled by default in kube-prometheus-stack)
          - url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/write # Your Prometheus remote_write URL
            send_exemplars: true # Send exemplars for trace correlation
      processor:
        # Derives span-to-span service graph data
        service_graphs:
          enabled: true
          # Wait time to ensure all spans for an edge are seen
          wait: 5s
          # Which attributes define a 'node' in the graph
          dimensions: [resource.service.name, resource.k8s.deployment.name]
        # Derives RED metrics for all spans
        span_metrics:
          enabled: true
          # Which attributes to create labels from in the resulting prometheus metrics
          dimensions:
            - resource.service.name
            - span.name
            - status.code
```
**Metrics Produced**:
-   `traces_service_graph_request_total`: Rate of requests between services.
-   `traces_service_graph_request_failed_total`: Rate of failed requests between services.
-   `traces_service_graph_request_server_seconds_bucket`: Histogram of server-side latency.
-   `traces_span_metrics_duration_seconds_bucket`: Histogram of latency for individual spans.

## ## examples.md Content

### Helm Deployment: Grafana Tempo

This `values.yaml` deploys Tempo in single-binary mode with a MinIO backend and the metrics-generator enabled.

**Prerequisites**:
1. A `Secret` named `tempo-minio-credentials` in the `observability` namespace with your MinIO `access_key` and `secret_key`.
   ```bash
   kubectl create secret generic tempo-minio-credentials \
     --from-literal=MINIO_ACCESS_KEY='your-minio-access-key' \
     --from-literal=MINIO_SECRET_KEY='your-minio-secret-key' \
     -n observability
   ```
2. A MinIO bucket named `tempo-traces` has been created.
   ```bash
   mc alias set k3s http://minio.helixstax.net <access_key> <secret_key>
   mc mb k3s/tempo-traces
   ```

**File: `tempo-values.yaml`**
```yaml
# This runs: helm install tempo grafana/tempo -n observability -f tempo-values.yaml

# Use singleBinary mode for Helix Stax's 2-node cluster
# It's simple and efficient at this scale.
singleBinary:
  enabled: true

# Mount the MinIO credentials secret
extraEnv:
  - name: MINIO_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: tempo-minio-credentials
        key: MINIO_ACCESS_KEY
  - name: MINIO_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: tempo-minio-credentials
        key: MINIO_SECRET_KEY

# Persist the ingester's WAL to a PVC for durability against pod restarts
persistence:
  enabled: true
  size: 10Gi

# Resource budget. Tempo is relatively lightweight when storage is on MinIO.
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 200m
    memory: 500Mi

tempo:
  # Configure the storage backend to use our in-cluster MinIO
  storage:
    trace:
      backend: s3
      wal:
        path: /var/tempo/wal # This will live on the PVC
      s3:
        # Endpoint for the MinIO service, assuming it's in the 'default' namespace
        # Adjust if MinIO is deployed elsewhere
        endpoint: minio.default.svc.cluster.local:9000
        bucket: tempo-traces
        region: us-east-1 # Required by the client, value doesn't matter for MinIO
        insecure: true
        # The access/secret keys are injected from the secret via extraEnv
        access_key: ${MINIO_ACCESS_KEY}
        secret_key: ${MINIO_SECRET_KEY}

  # Enable and configure the metrics-generator to create RED metrics and service graphs
  metricsGenerator:
    enabled: true
    config:
      storage:
        path: /var/tempo/generator_wal
        remote_write:
          # Requires Prometheus --web.enable-remote-write-receiver flag (not enabled by default in kube-prometheus-stack)
          # This must be the remote_write endpoint for your Prometheus instance
          # Find this via 'kubectl get svc -n monitoring'
          - url: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/write"
            send_exemplars: true # Critical for linking metrics back to traces
      processor:
        service_graphs:
          enabled: true
          # These dimensions will appear as nodes in the service graph
          dimensions: [resource.service.name, resource.k8s.deployment.name]
          wait: 5s
        span_metrics:
          enabled: true
          dimensions:
            - resource.service.name
            - span.name
            - status.code
            - span.http.method
            - span.http.status_code

# Configure retention in the compactor
compactor:
  config:
    compaction:
      # Compact blocks to save space and improve query speed
      block_retention: 24h
      # Delete traces older than 14 days
      trace_retention: 336h # 14d
```

### Trace Correlation Runbook: Traefik Request

This runbook demonstrates how to correlate a slow request from logs to traces to metrics.

1.  **Symptom**: User reports a slow API call to `https://api.helixstax.com/v1/data`.

2.  **Log Search (Loki)**: Go to Grafana Explore and query Loki for slow Traefik access logs.
    *   **LogQL Query**:
        ```logql
        {job="ingress/traefik"} | json | Duration > 2000000000 # Duration is in nanoseconds
        ```
    *   Find a log line corresponding to the slow request. Because we configured Traefik to include the `traceparent` header in its JSON logs, you'll see a field like:
        `"traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"`
    *   The `trace_id` is the part after the first dash: `0af7651916cd43dd8448eb211c80319c`.

3.  **Jump to Trace (Log -> Tempo)**:
    *   If the Loki data source is configured with derived fields, Grafana will automatically detect this `traceparent` and create a "Tempo" button. Click it to jump directly to the trace.
    *   **Manual Fallback**: Copy the trace ID (`0af7651916cd43dd8448eb211c80319c`), switch to the Tempo data source, and paste the ID into the search bar.

4.  **Analyze Trace (Tempo)**:
    *   The trace view appears. It shows a flame graph of the entire request lifecycle.
    *   You see the initial span from `traefik`.
    *   There is a child span for the upstream service, e.g., `service.name: my-api`.
    *   You notice the `my-api` span has a long child span called `SELECT FROM users` from `service.name: cloudnative-pg`.
    *   **Conclusion**: The slowness is caused by a slow database query, not the network or the application logic itself.

5.  **Correlate with Metrics (Tempo -> Prometheus)**:
    *   The Tempo metrics-generator created histogram metrics from these traces.
    *   In a Grafana dashboard, you can view the `traces_span_metrics_duration_seconds_bucket` metric for `service.name="cloudnative-pg"`.
    *   Because `send_exemplars` was enabled, you will see small red dots on the histogram bars. Hovering over an exemplar from the time of the incident shows the `traceID`. Clicking it links you *back* to this exact trace in Tempo.
    *   This confirms that this slow trace was part of a wider pattern of slow DB queries at that time.

This end-to-end workflow, moving seamlessly between logs, traces, and metrics, is the primary value of deploying the complete observability stack.
