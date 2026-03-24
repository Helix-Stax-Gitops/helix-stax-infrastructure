Of course. This is an excellent project for AI agents. A comprehensive, opinionated, and practical knowledge base is exactly what they need to operate effectively.

Here is the complete Gemini Deep Research on your logging pipeline, structured as requested. The content is broken down by tool and then by the `SKILL.md`, `reference.md`, and `examples.md` format you specified for easy splitting.

---

# Promtail vs Grafana Alloy — Decision Guide

This is a meta-level guide to inform the choice of logging agent.

### Decision Recommendation for Helix Stax
**Start with Grafana Alloy.**

For a new deployment on a 2-node K3s cluster, Alloy is the superior strategic choice, even with potentially higher initial resource usage. The benefits of a unified agent for logs, metrics, and traces (your future Phase 6+ requirement with Tempo) and the modern, more powerful River configuration language outweigh Promtail's simplicity and slightly smaller footprint. Your AI agents will benefit from a single configuration paradigm as your observability stack grows.

Migrate to Alloy from the start; do not deploy Promtail unless you hit severe, unsolvable resource constraints on your Hetzner nodes, which is unlikely with proper configuration.

### Feature Comparison Matrix

| Feature | Promtail (Legacy) | Grafana Alloy (Recommended) | Winner for Helix Stax |
| :--- | :--- | :--- | :--- |
| **Primary Function** | Log collection only | Logs, metrics, traces (OTLP) | **Alloy** |
| **Configuration** | YAML, declarative | River (HCL-based), procedural/declarative hybrid | **Alloy** (more expressive, reusable components) |
| **K8s Log Source** | `kubernetes_sd_configs` + `relabel_configs` | `loki.source.kubernetes` component (API-based) | **Alloy** (simpler, more direct) |
| **Systemd Logs** | `journal` scrape config | `loki.source.journal` component | **Alloy** (first-class component) |
| **Performance** | Excellent for single log pipelines | Better for complex, multi-pipeline scenarios | **Alloy** (future-proof) |
| **Resource Usage** | Lower base RAM/CPU | Slightly higher base RAM/CPU, but consolidates multiple agents | **Tie/Alloy** (consolidates future OTel collector) |
| **Ecosystem** | Loki only | Loki, Prometheus, Tempo, any OTLP-compatible backend | **Alloy** |
| **Migration** | N/A | `alloy convert` command provides a starting point from Promtail/Prometheus config | **Alloy** |
| **Community Support** | Maintained, but receives minimal new features | Actively developed, all new features land here | **Alloy** |

### At What Point to Migrate?
You should not start with Promtail. The migration path introduces risk (duplicate logs, config translation errors) that is unnecessary for a greenfield deployment. Start with Alloy. If you were already running Promtail, you would consider migrating when:
1.  You need to collect traces or metrics with the same agent (e.g., adding Tempo).
2.  Your logging pipelines become too complex to manage with Promtail's YAML `relabel_configs`.
3.  You need a feature only available in Alloy (e.g., advanced processing or a specific exporter).

---

# Grafana Alloy

## SKILL.md Content
- **Type**: Log/Metric/Trace Collection Agent
- **Role**: Collects all pod and systemd logs from K3s nodes and ships them to Loki.
- **Successor to**: Promtail

### Daily Operations

#### Check Alloy Pod Status
```bash
# Check if Alloy DaemonSet pods are running on all nodes
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy -o wide
```

#### View Alloy Logs
```bash
# Check logs of the Alloy pod on a specific node (e.g., helix-stax-vps)
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --field-selector spec.nodeName=helix-stax-vps -f
```

#### Trigger a Configuration Hot Reload
Alloy can reload its configuration without a restart. Update the ConfigMap first, then trigger the reload.
```bash
# 1. Edit the ConfigMap with the new config
kubectl edit configmap -n monitoring alloy

# 2. Find the pod name on one node
ALLOY_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy -o 'jsonpath={.items[0].metadata.name}')

# 3. Trigger the reload endpoint
kubectl exec -n monitoring $ALLOY_POD -- wget -qO- --post-data='' http://localhost:12345/-/reload
```

### Core Configuration Snippets (River)

#### 1. Discover Kubernetes Pods
This block finds all pods in the cluster and makes their metadata available.
```river
discovery.kubernetes "pods" {
  role = "pod"
}
```

#### 2. Scrape Pod Logs via K8s API
This is the preferred method. It uses the discovery results to stream logs directly from the K8s API for each container.
```river
loki.source.kubernetes "pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.process.pods.receiver]
}
```

#### 3. Process Logs (Parse CRI, Add Labels)
All logs from `containerd` are in CRI format. This stage is **mandatory**.
```river
loki.process "pods" {
  // Add common labels from K8s discovery
  stage.relabel {
    labels = {
      "job"     = "k3s/pods",
      "cluster" = "helix-stax-main",
    }
  }

  // Mandatory: Parse the CRI log format to get the real log line
  stage.cri {}

  // Example: Parse JSON logs if the 'format' label is 'json'
  stage.json {
    source       = "log"
    expressions  = { "level" = "level", "msg" = "msg" }
    drop_malformed = true
  }

  // Add the discovered labels to the final log stream
  stage.label_allow {
    values = [
      "cluster", "job", "namespace", "pod", "container", "app",
    ]
  }

  forward_to = [loki.write.loki_cluster.receiver]
}
```

#### 4. Send Logs to Loki
This block sends the processed logs to your in-cluster Loki service.
```river
loki.write "loki_cluster" {
  endpoint {
    url = "http://loki-write.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }
}
```

### Troubleshooting Decision Tree

**Symptom: Logs from a new pod are not in Grafana.**

1.  **Is Alloy running on the pod's node?**
    *   **Command**: `kubectl get pod -n <namespace> <pod_name> -o wide` (get node name). Then `kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy -o wide | grep <node_name>`.
    *   **Fix**: If no Alloy pod is on that node, check the DaemonSet tolerations. It must tolerate the control-plane taint: `key: node-role.kubernetes.io/control-plane, operator: Exists`.

2.  **Is Alloy discovering the pod?**
    *   **Command**: Port-forward to an Alloy pod and check the `targets` page:
        ```bash
        ALLOY_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy -o 'jsonpath={.items[0].metadata.name}')
        kubectl port-forward -n monitoring $ALLOY_POD 12345 &
        curl 'http://localhost:12345/alloy/v0/targets' | jq '.[] | select(.component_id | contains("loki.source.kubernetes")) | .reported_targets[] | select(.labels.__meta_kubernetes_pod_name == "<pod_name>")'
        ```
    *   **Fix**: If the pod is not listed, check Alloy's RBAC permissions (`ClusterRole` must have `watch` on `pods`). Check Alloy logs for permission errors.

3.  **Is Alloy sending to Loki? Any errors?**
    *   **Command**: `kubectl logs -n monitoring -l app.kubernetes.io/name=alloy -f | grep "loki.write"`
    *   **Fix**: Look for `error="server returned HTTP status 429"` (rate-limited), `400 "entry too old"` (timestamp issue), or connection refused errors.
        *   `429`: Increase Loki's ingestion limits (`ingestion_rate_mb`, `ingestion_burst_size_mb`).
        *   Connection refused: Verify the `loki.write` URL points to the correct Loki service name (`loki-write.monitoring.svc.cluster.local`).

4.  **Is Loki ingesting the logs?**
    *   **Check Loki metrics**: In Prometheus/Grafana, query `rate(loki_distributor_bytes_received_total[1m])`. If it's zero or dropping, Loki is the problem.
    *   **Fix**: Check Loki logs for errors related to storage (MinIO connection), schema, etc. See Loki troubleshooting section.

## reference.md Content
### Grafana Alloy Architecture
Grafana Alloy is a vendor-neutral distribution of the OpenTelemetry Collector, combined with components for Prometheus and Loki compatibility. It uses a component-based configuration language called River.

```plaintext
┌───────────────────────────┐      ┌───────────────────────────┐
│        Node: heart        │      │    Node: helix-stax-vps   │
│ ┌───────────────────────┐ │      │ ┌───────────────────────┐ │
│ │      Alloy Pod        │ │      │ │      Alloy Pod        │ │
│ │ (DaemonSet)           │ │      │ │ (DaemonSet)           │ │
│ │                       │ │      │ │                       │ │
│ │ loki.source.kubernetes│ │      │ │ loki.source.kubernetes│ │
│ │                       │ │      │ │                       │ │
│ │ loki.source.journal   │─┼──────┼─│ loki.source.journal   │ │
│ └──────────┬────────────┘ │      │ └──────────┬────────────┘ │
└────────────┼─────────────────────┼──────────────────────────┘
             │                     │
             │ Logs                │ Logs
             ▼                     ▼
┌───────────────────────────────────────────────┐
│             K3s Cluster Services              │
│  ┌──────────────────────────────────────────┐ │
│  │ Loki Service (loki-write.monitoring.svc) │ │
│  └──────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

### River Language Fundamentals
- **Blocks**: Define components. Syntax: `component_name "label" { ... }`.
  - `component_name`: Type of component (e.g., `loki.write`).
  - `"label"`: A user-defined name for the instance of the component (e.g., `"loki_cluster"`).
- **Attributes**: Key-value settings inside a block. Syntax: `attribute_name = value`.
- **References**: Use outputs of one component as inputs to another. Syntax: `component_name.label.output_field`. Example: `targets = discovery.kubernetes.pods.targets`.
- **Expressions**: Simple expressions and function calls are allowed for attribute values.

### K8s Deployment via Helm
Use the `grafana/alloy` Helm chart.

**Key `values.yaml` settings:**
```yaml
# Use DaemonSet mode, not deployment
controller:
  type: "daemonset"

# Tolerations to run on all nodes, including control-plane
daemonset:
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node-role.kubernetes.io/master" # For some K3s setups
      operator: "Exists"
      effect: "NoSchedule"

# ClusterRole for discovering all cluster resources
clustering:
  enabled: false # Not needed for log collection only mode

crds:
  create: true # Let Alloy create its CRDs

# Mount the configuration from a ConfigMap
configMap:
  create: true
  name: "alloy"
  content: |
    // River config goes here. See examples.md

# RBAC to read pod logs and metadata
rbac:
  create: true
  # The default chart role is usually sufficient for loki.source.kubernetes

# Persistent Volume for Write-Ahead Log (WAL) to prevent log loss on restart
extraVolumes:
  - name: alloy-wal
    hostPath:
      path: /var/lib/alloy/data # Use hostPath on each node
      type: DirectoryOrCreate
extraVolumeMounts:
  - name: alloy-wal
    mountPath: /var/lib/alloy/data

# Resource sizing for a small 2-node cluster
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 768Mi
```

### Component Reference

#### Log Sources
- **`loki.source.kubernetes`**: (Preferred for K8s) Streams logs via K8s API. Avoids hostPath mounts for logs, but requires RBAC for pod log access.
- **`loki.source.file`**: Scrapes log files from disk. Requires `hostPath` mount for `/var/log/pods`. Less efficient than the API method as it relies on file system watches.
- **`loki.source.journal`**: Reads from the systemd journal. Requires read access to `/var/log/journal`.

#### Pipeline Stages (`loki.process`)
- **`stage.cri`**: *Required for containerd/CRI-O*. Parses the prefix `2024-01-01T12:00:00.000000000Z stdout F log line`.
- **`stage.json`**: Parses a JSON log line. `source` specifies which field to parse (usually `log`). `expressions` extract values into labels or internal fields.
- **`stage.regex`**: Parses a log line with a regular expression. Named capture groups become internal fields.
- **`stage.multiline`**: Groups multiple lines into a single entry (e.g., Java stack traces). `first_line` is a regex that identifies the start of a block. `max_wait_time` controls how long to wait for the next line.
- **`stage.drop`**: Filters logs. `source` specifies a label to check. `value` is a regex to match against the label value. `older_than` can drop old logs. `drop_counter_reason` sets a reason for metrics.
- **`stage.labels`**: Sets static labels.
- **`stage.relabel`**: Dynamically creates/modifies labels using relabeling rules (similar to Prometheus).
- **`stage.structured_metadata`**: Moves extracted data into Loki's structured metadata, suitable for high-cardinality data like `trace_id`.
- **`stage.timestamp`**: Overrides the log's timestamp from a field in the log line. `source` is the field to use. `format` defines the time format (e.g., `RFC3339Nano`).

## examples.md Content

### Full `values.yaml` for Alloy Helm Chart
This configuration deploys Alloy as a DaemonSet on your K3s cluster.
```yaml
# values-alloy.yaml
---
# Deploy as a DaemonSet to run on every node
controller:
  type: "daemonset"

# Ensure Alloy runs on the control-plane node (heart) as well
daemonset:
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node-role.kubernetes.io/master" # Legacy taint for K3s
      operator: "Exists"
      effect: "NoSchedule"

# Don't enable Alloy's own clustering mode, it's for metric scraping primarily
clustering:
  enabled: false

# Create the ConfigMap that holds the River configuration
configMap:
  create: true
  name: "alloy-specific" # Use a unique name to avoid conflicts
  # The actual River config is defined below
  content: |
    // Alloy River components are used directly — no import statements needed

    // 1. Discover all pods in the cluster
    discovery.kubernetes "pods" {
      role = "pod"
    }

    // 2. Discover all nodes for systemd journal scraping
    discovery.kubernetes "nodes" {
      role = "node"
    }

    // 3. Scrape logs from all Kubernetes pods via API
    loki.source.kubernetes "k8s_pods" {
      targets    = discovery.kubernetes.pods.targets
      forward_to = [loki.process.k8s_pods.receiver]
      // Add a label to distinguish these logs
      labels = {
        "job" = "integrations/k3s-pods",
      }
    }

    // 4. Process logs from Kubernetes pods
    loki.process "k8s_pods" {
      // Drop noisy health checks early
      stage.drop {
        expression = `(kube-probe|HealthChecker|Prometheus)`
        drop_counter_reason = "health_check"
      }
      stage.drop {
        expression = `GET /healthz`
        drop_counter_reason = "health_check"
      }

      // Mandatory for K3s/containerd
      stage.cri {}

      // Add standard Kubernetes labels
      stage.label_allow {
        values = [
          "app",
          "component",
          "container",
          "filename",
          "job",
          "name",
          "namespace",
          "pod",
          "release",
          "app_kubernetes_io_name",
          "app_kubernetes_io_instance",
        ]
      }

      // If a log for Traefik access comes in, parse it as JSON
      stage.match {
        selector = `{app="traefik", container="traefik"}`
        stages = [
          stage.json {
            expressions = { "path" = "RequestPath", "status" = "DownstreamStatus" }
          },
        ]
      }

      // Forward to the Loki exporter
      forward_to = [loki.write.to_loki.receiver]
    }

    // 5. Scrape systemd journal logs from each node for critical services
    loki.source.journal "system_logs" {
      // Where to write the positions file to persist read state
      positions_file = "/var/lib/alloy/data/journal.pos"
      // Filter to specific services to reduce noise
      matches = [
        {
          unit = "k3s.service"
        },
        {
          unit = "containerd.service"
        },
        {
          unit = "sshd.service"
        }
      ]
      // Add labels identifying the source node
      // Verify River syntax for dynamic label assignment against your Alloy version
      labels = {
        "job" = "integrations/node-journal",
        "host" = discovery.kubernetes.nodes.targets[0].__meta_kubernetes_node_name,
      }
      forward_to = [loki.write.to_loki.receiver]
    }


    // 6. Define the Loki endpoint to send all logs to
    loki.write "to_loki" {
      endpoint {
        url = "http://loki-write.monitoring.svc.cluster.local:3100/loki/api/v1/push"

        // Set tenant ID if Loki is in multi-tenant mode (using 'fake' for single tenant)
        tenant_id = "fake"
      }
      // Add an external label to all logs sent by this Alloy instance
      external_labels = {
        cluster = "helix-stax-main",
        source  = "alloy",
      }
    }

mounts:
  # Mount /var/log for log file access (journal and pods)
  - type: 'bind'
    hostPath: '/var/log/'
    mountPath: '/var/log/'
    readOnly: true
  # Mount the pod log directory specifically
  - type: 'bind'
    hostPath: '/var/log/pods'
    mountPath: '/var/log/pods'
    readOnly: true
  # Persistent volume for WAL (Write-Ahead Log)
  - type: 'bind'
    hostPath: '/var/lib/alloy/data' # Use hostPath on each node
    mountPath: '/var/lib/alloy/data'

# The default RBAC role is sufficient.
rbac:
  create: true

# Define resource limits for the small 2-node cluster
resources:
  requests:
    cpu: 150m
    memory: 300Mi
  limits:
    cpu: 750m
    memory: 1Gi
```

### Runbook: Applying and Verifying New Alloy Config
1.  **Save the `values-alloy.yaml` and the `config.alloy` content locally.**
2.  **Install or upgrade the Alloy Helm release:**
    ```bash
    helm upgrade --install alloy grafana/alloy \
      --namespace monitoring \
      --create-namespace \
      -f values-alloy.yaml
    ```
3.  **Verify the DaemonSet is rolling out:**
    ```bash
    kubectl get daemonset -n monitoring alloy -w
    ```
4.  **Check logs for one of the new pods to ensure it starts without errors:**
    ```bash
    # Get a pod name from the 'helix-stax-vps' node
    ALLOY_WORKER_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy --field-selector spec.nodeName=helix-stax-vps -o 'jsonpath={.items[0].metadata.name}')

    # Tail its logs
    kubectl logs -n monitoring $ALLOY_WORKER_POD -f
    ```
    *Look for lines indicating components have started and there are no connection errors to Loki.*

5.  **Go to Grafana and check if new logs are arriving with the correct labels.** Use the Explore view with a query like `{job="integrations/k3s-pods", cluster="helix-stax-main"}`.

---

# Loki

## SKILL.md Content
- **Type**: Log Aggregation System
- **Role**: Receives logs from Alloy, indexes labels, stores log content in MinIO, and serves queries from Grafana.
- **Key Concept**: Indexes only metadata (labels), not the full log content. This makes it cheap to run.

### Daily Operations (logcli)

#### Install logcli on AlmaLinux
```bash
# Find the latest release from https://github.com/grafana/loki/releases
# Example for v2.9.4
wget https://github.com/grafana/loki/releases/download/v2.9.4/logcli-linux-amd64.zip
unzip logcli-linux-amd64.zip
sudo mv logcli-linux-amd64 /usr/local/bin/logcli
chmod +x /usr/local/bin/logcli
logcli --version
```

#### Port-Forward to Loki for CLI Access
```bash
# The Loki read-path is the 'loki-read' service on port 3100
kubectl port-forward -n monitoring svc/loki-read 3100:3100 &
# Set environment variable for convenience
export LOKI_ADDR=http://localhost:3100
```

#### Essential `logcli` Commands
```bash
# Tail logs for the 'traefik' namespace
logcli query '{namespace="traefik"}' --tail

# Search for all "error" logs in the last hour across all pods
logcli query '{job="integrations/k3s-pods"} |= "error"' --since=1h --limit=100

# Count error logs in the 'zitadel' namespace in the last 6 hours
logcli query 'count_over_time({namespace="zitadel"} |= "error" [1m])' --since=6h

# List all label names
logcli labels

# List all values for the 'namespace' label
logcli labels namespace
```

### Core LogQL Queries (for Grafana Explore)

- **Show all logs for an app**: `{app="traefik"}`
- **Filter by text**: `{app="crowdsec"} |= "decision"`
- **Filter by text with regex**: `{app="cloudnative-pg"} |~ "error|failed"`
- **Parse JSON and filter**: `{app="zitadel"} | json | level="error"`
- **Calculate per-second error rate by namespace**: `sum by (namespace) (rate({job="integrations/k3s-pods"} |= "error" [5m]))`
- **Top 10 log producers**: `topk(10, sum by (pod) (rate({job="integrations/k3s-pods"}[1m])))`

### Troubleshooting Decision Tree

**Symptom: Grafana says "Loki: Bad Gateway" or queries are failing.**

1.  **Is the Loki pod running?**
    *   **Command**: `kubectl get pods -n monitoring -l app.kubernetes.io/name=loki`.
    *   **Fix**: If `CrashLoopBackOff`, check logs with `kubectl logs -n monitoring <loki_pod_name>`. The error is likely in the next step.

2.  **Can Loki connect to MinIO?**
    *   **Command**: `kubectl logs -n monitoring <loki_pod_name> | grep "s3"`
    *   **Fix**: Look for errors like `AccessDenied` (check Secret `LOKI_S3_ACCESS_KEY_ID`/`LOKI_S3_SECRET_ACCESS_KEY`), `NoSuchBucket` (bucket wasn't created in MinIO), or `dial tcp` errors (check `s3.endpoint` in Loki config; use the K8s service name `http://minio.minio-ns.svc.cluster.local:9000`).

3.  **Is Loki being rate-limited or overwhelmed?**
    *   **Symptom**: Alloy logs show `429 Too Many Requests`.
    *   **Fix**: Increase ingestion limits in Loki's Helm `values.yaml` and redeploy.
        ```yaml
        loki:
          ingestion_rate_mb: 15
          ingestion_burst_size_mb: 30
        ```

4.  **Are queries slow or timing out?**
    *   **Cause**: This could be due to a high-cardinality query or too large of a time range.
    *   **Fix**:
        *   Narrow the time range in Grafana.
        *   Add more specific labels to your query (e.g., add `pod="xyz"` instead of just `namespace="abc"`).
        *   Check for high-cardinality labels using `logcli labels`. Avoid querying them over long time ranges.

## reference.md Content
### Loki Architecture for Helix Stax
**Recommendation**: `SingleBinary` (Monolithic) Mode.
For a 2-node cluster, this mode is simplest and most resource-efficient. It runs all Loki components (distributor, ingester, querier, ruler, compactor) in a single process/pod. The "simple scalable" mode adds complexity without significant HA benefit on a small cluster.

```plaintext
                                         ┌─────────────────────┐
                                      ┌─▶│ Grafana (Queries)   │
                                      │  └─────────────────────┘
                                      │
┌───────────────┐      ┌───────────────┐      ┌─────────────────────┐
│ Alloy on Node1│─────▶│ Loki Service  │◀─────┤      logcli         │
└───────────────┘      │  (loki-read /  │      └─────────────────────┘
   (write)             │   loki-write) │
                       └───────┬───────┘
                               ▼
┌─────────────────────────────────────────────────────┐
│                    Loki Pod (SingleBinary)          │
│ ┌───────────┐ ┌─────────┐ ┌─────────┐ ┌───────────┐ │
│ │Distributor│ │Ingester │ │Querier  │ │ Compactor │ │
│ └─────┬─────┘ └────┬────┘ └────┬────┘ └─────┬─────┘ │
└───────┼────────────┼───────────┼────────────┼───────┘
        │            │           │            │
        │ Writes     │ Writes    │ Reads      │ Manages
        └────────────┼───────────┼────────────┘
                     ▼           ▼
        ┌───────────────────────────────────┐
        │  MinIO S3 Bucket (on K3s)         │
        │ ┌─────────┐   ┌─────────┐         │
        │ │ Chunks  │   │  Index  │         │
        │ │(Log Data) │   │ (TSDB)  │         │
        │ └─────────┘   └─────────┘         │
        └───────────────────────────────────┘
```

### Helm Chart Configuration (`grafana/loki`)
**Key `values.yaml` for `SingleBinary` mode with MinIO:**
```yaml
# values-loki.yaml
loki:
  # This is the most important setting for a simple setup
  deploymentMode: SingleBinary

  # RBAC for the Loki pod itself (if needed, usually not)
  rbac:
    create: true

  # Configuration for Loki itself, passed as a config file
  config:
    # Use TSDB, the modern and recommended index store
    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb # Use the TSDB index
          object_store: s3
          schema: v12 # Use a recent, stable schema
          index:
            prefix: index_
            period: 24h

    # Backend storage configuration for MinIO
    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/boltdb-shipper-active
        cache_location: /data/loki/boltdb-shipper-cache
        cache_ttl: 24h
      # Define the S3 storage type
      aws:
        # Endpoint for your in-cluster MinIO. MUST be the K8s service FQDN
        endpoint: http://minio.minio-ns.svc.cluster.local:9000
        # Region must be set, even for MinIO. 'us-east-1' is a safe default.
        region: us-east-1
        # Bucket names MUST be pre-created in MinIO
        bucketnames: loki-data
        # Use path-style access, required for MinIO
        s3forcepathstyle: true
        # Credentials are provided by environment variables from a secret
        access_key_id: ${LOKI_S3_ACCESS_KEY_ID}
        secret_access_key: ${LOKI_S3_SECRET_ACCESS_KEY}

    # Configuration for the compactor, essential for retention & performance
    compactor:
      working_directory: /data/loki/compactor
      compaction_interval: 10m
      retention_enabled: true # THIS MUST BE TRUE FOR RETENTION TO WORK
      retention_delete_delay: 2h
      retention_delete_worker_count: 150

    # Global limits
    limits_config:
      # Enable retention
      retention_period: 30d # Keep logs for 30 days
      # Ingestion limits - adjust if Alloy gets 429 errors
      ingestion_rate_mb: 20
      ingestion_burst_size_mb: 40
      # Max query length
      max_query_length: 721h # ~30 days

    # Ruler for alerting
    ruler:
      alertmanager_url: http://alertmanager-operated.monitoring.svc:9093

# Service configuration
# Creates a single headless service for all components in SingleBinary mode
singleBinary:
  replicas: 1
  # Expose ports for read (querier), write (distributor), and metrics
  service:
    ports:
      - name: http
        port: 3100
        targetPort: 3100
  # Provide credentials via a secret
  extraEnv:
    - name: LOKI_S3_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: loki-s3-credentials
          key: access_key_id
    - name: LOKI_S3_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: loki-s3-credentials
          key: secret_access_key
  # Resource sizing for a 2-node cluster with moderate load
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 2000m # 2 cores
      memory: 4Gi

# Target the single binary for reads, writes, etc.
write:
  replicas: 0 # Disabled in favor of singleBinary
read:
  replicas: 0 # Disabled in favor of singleBinary
backend:
  replicas: 0 # Disabled in favor of singleBinary
```

### Storage: Chunks and TSDB Index
- **Chunks**: These are gzipped files containing raw log lines for a specific stream over a time period. They are stored in MinIO under prefixes like `fake/` (tenant) and a hash. Small chunks are inefficient.
    - **Tuning**: In `loki.config.ingester`, `chunk_target_size` (aim for ~1.5MB), `chunk_idle_period`, and `max_chunk_age` control when chunks are flushed to storage. Defaults are usually fine to start.
- **TSDB Index**: This is Loki's default index format since v2.8. It stores the label-to-chunk mappings in an efficient time-series database format.
    - **Advantage over BoltDB-shipper**: TSDB stores its index files *directly in the S3 bucket* alongside the chunks. This eliminates the need for a separate "shipper" process and local disk for the index, simplifying the architecture significantly. It is more performant and scalable.

### Common Pitfalls and Anti-Patterns
1.  **Critical: High-Cardinality Labels**: Using labels for unique IDs (`trace_id`, `user_id`, `request_id`). This causes an "index explosion," making Loki slow and expensive. **Use Structured Metadata for this data.**
2.  **Severe: Not Enabling the Compactor**: If `compactor.retention_enabled` is `false`, log retention will not work. Additionally, Loki will accumulate millions of small chunk objects in MinIO, killing query performance and increasing S3 API costs.
3.  **Severe: Incorrect MinIO Endpoint**: Using an external URL or public IP for the `s3.endpoint`. This routes traffic out of the cluster and back in. **Always use the internal Kubernetes service FQDN** (e.g., `http://minio.minio-ns.svc.cluster.local:9000`).
4.  **Moderate: Changing `schema_config`**: Once data is written with a schema, you should not change it. Only append new schemas for future dates. Changing an existing entry will make old data unreadable.
5.  **Low: Overly Broad LogQL Queries**: Running `{job="k8s-pods"}` over 30 days will time out. Always narrow with more labels and shorter time ranges first.

## examples.md Content

### Full Setup Runbook for Loki on K3s

**Pre-requisite:** You have a running MinIO instance in the `minio-ns` namespace with a service named `minio`.

#### 1. Create the MinIO Bucket
```bash
# Port-forward to the MinIO service
kubectl port-forward -n minio-ns svc/minio 9001:9001 &
export MC_HOST_minio=http://minioadmin:minioadmin@localhost:9001

# Create the bucket for Loki data
mc mb minio/loki-data

# Set a lifecycle policy to clean up failed uploads (optional but recommended)
mc ilm add minio/loki-data --expire-incomplete-days 7

# Kill the port-forward
kill %1
```

#### 2. Create the Kubernetes Secret for MinIO Credentials
Replace `YOUR_ACCESS_KEY` and `YOUR_SECRET_KEY` with your actual MinIO credentials.
```yaml
# loki-s3-secret.yaml
# Production: Use ExternalSecret (ESO) to pull from OpenBao instead of hardcoded stringData
apiVersion: v1
kind: Secret
metadata:
  name: loki-s3-credentials
  namespace: monitoring
type: Opaque
stringData:
  # These keys MUST match what the Helm chart expects
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```
```bash
kubectl apply -f loki-s3-secret.yaml
```

#### 3. Save the `values-loki.yaml`
Copy the complete `values-loki.yaml` from the `reference.md` section into a local file.

#### 4. Deploy Loki using Helm
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --create-namespace \
  -f values-loki.yaml
```

#### 5. Verify the Deployment
```bash
# Wait for the pod to be in 'Running' state
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki -w

# Check logs for successful startup and no S3 errors
LOKI_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n monitoring $LOKI_POD -f | grep "Loki started"
```

### LogQL Recipes for Helix Stax Services

#### Traefik
- **5xx Errors in last hour**:
  `{namespace="traefik"} | json | status_code >= 500 and status_code < 600`
- **Top 10 slowest endpoints (p99 latency)**:
  `topk(10, quantile_over_time(0.99, {namespace="traefik"} | json | unwrap duration | __error__="" [5m]) by (path))`
- **Request rate by upstream service**:
  `sum by (service) (rate({namespace="traefik"} | json | __error__="" [5m]))`

#### Zitadel
- **Authentication failures**:
  `{app="zitadel"} | json | message="Authentication failed"`
- **Count events by type**:
  `sum by (event_type) (count_over_time({app="zitadel"} | json | event_type!="" [1h]))`

#### CloudNativePG (PostgreSQL)
- **Slow queries (> 200ms)**:
  `{app="cloudnative-pg"} | regexp `.*duration: (?<duration_ms>\d+\.\d+) ms.*` | duration_ms > 200`
- **FATAL errors**:
  `{app="cloudnative-pg"} |= "FATAL"`

#### n8n
- **Workflow execution errors**:
  `{app="n8n"} | json | level="error" and message="Problem in node"`
- **Count of started vs finished executions**:
  `count_over_time({app="n8n"} |= "Workflow execution started"[1h])`
  `count_over_time({app="n8n"} |= "Workflow execution finished"[1h])`

#### ArgoCD
- **App sync failures**:
  `{app_kubernetes_io_name="argocd-application-controller"} | json | message=~".*Sync operation failed.*"`

### Ruler Alerting Rule Example
Save this as `loki-rules.yaml` and mount it into the Loki pod (or use the Helm chart's `ruler.config` value).

```yaml
# loki-alert-rules.yaml
groups:
  - name: AppErrorAlerts
    rules:
      - alert: HighErrorRateAcrossNamespace
        expr: |
          sum by (namespace) (rate({job="integrations/k3s-pods"} |~ "error|level=error|level=ERROR" [5m]))
          /
          sum by (namespace) (rate({job="integrations/k3s-pods"}[5m]))
          > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate in namespace {{ $labels.namespace }}"
          description: "More than 5% of log lines in namespace '{{ $labels.namespace }}' contain error messages over the last 5 minutes."

      - alert: OOMKillDetected
        expr: |
          count_over_time({job="integrations/node-journal"} |= "invoked oom-killer" [10m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "OOM Killer detected on node {{ $labels.host }}"
          description: "The kernel OOM killer was invoked on node '{{ $labels.host }}'. A pod was likely OOMKilled."
```
