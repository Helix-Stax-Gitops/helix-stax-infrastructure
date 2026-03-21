# Gemini Deep Research: OpenTelemetry + Grafana Tempo

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
This prompt covers the DISTRIBUTED TRACING PIPELINE for our K3s cluster. This is a Phase 6+ capability — not deployed yet — but the skill must be research-complete and ready to use when we deploy. OpenTelemetry (OTel) instruments applications and collects spans → OTel Collector receives, processes, and routes → Grafana Tempo stores traces → Grafana visualizes and correlates with logs (Loki) and metrics (Prometheus).

Two grouped tools:
1. **OpenTelemetry** — the instrumentation standard and Collector (receives spans from apps, processes, exports to Tempo)
2. **Grafana Tempo** — the trace storage backend (MinIO S3 backend, TraceQL query language, metrics-generator for RED metrics)

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, 2 nodes (heart: 178.156.233.12 control plane, helix-worker-1: 138.201.131.157 worker), Hetzner Cloud
- **Status**: Phase 6+ placeholder — infrastructure decisions should be made now, deployment when client environments exist
- **Object storage**: MinIO (same cluster, already deployed for Loki and Velero — Tempo will share MinIO with a separate bucket)
- **Existing observability**: Prometheus + Grafana + Loki (metrics + logs already working — tracing completes the three pillars)
- **Ingress**: Traefik (first instrumentation candidate — sits in front of all traffic)
- **Services to trace**: Traefik, n8n (workflow executions), Zitadel (auth flows), custom client apps, Backstage, Outline
- **Languages in stack**: primarily services with existing OTel SDKs (Go for Traefik, Node.js for n8n, Go for Zitadel)
- **Grafana**: already deployed — Tempo will be added as a data source alongside Loki and Prometheus

## What I Need Researched

### 1. OpenTelemetry Architecture Overview
- OTel signal types: traces (spans), metrics, logs — which signals OTel Collector handles vs native Prometheus/Loki
- Collector vs no-Collector: why use a Collector instead of sending directly from app to Tempo (buffering, retry, multi-destination, sampling, processing without app changes)
- Agent vs Gateway pattern: DaemonSet Collector (one per node, close to pods) vs Deployment Collector (centralized gateway) — when to use which, can use both in pipeline
- OTel Operator for K8s: auto-instrumentation injection via annotations, manages Collector CRDs — worth deploying vs manual Helm?
- Semantic conventions: why standardized span/attribute names matter (service.name, http.method, db.statement, etc.) — enables vendor-neutral dashboards

### 2. OTel Collector Deployment on K3s
- DaemonSet vs Deployment vs Sidecar for our use case:
  - DaemonSet: agent mode, receives from pods on same node, lower network overhead, good for host metrics
  - Deployment: gateway mode, centralized processing, better for sampling decisions across all traces
  - Recommended for 2-node K3s: Deployment (gateway) for simplicity at small scale
- Helm deployment: open-telemetry/opentelemetry-collector chart, key values (mode: deployment vs daemonset, config section)
- Receivers to enable: otlp (gRPC port 4317, HTTP port 4318), jaeger (if any legacy apps), zipkin (if any legacy apps), prometheus (scrape metrics from OTel-instrumented apps)
- Processors to configure: batch (reduce export frequency, important for small clusters), memory_limiter (prevent OOM), resource (add cluster/environment attributes), attributes (manipulate span attributes)
- Exporters: otlp/tempo (gRPC to Tempo), debug (for testing), prometheus (for metrics pipeline to Prometheus)
- Resource requirements: CPU/memory for Collector handling ~20 services on 2-node cluster
- RBAC: if using K8s attributes processor (adds pod metadata to spans), needs ClusterRole to read pods/namespaces

### 3. OTel Collector Configuration Reference
- Complete working Collector config (config.yaml) for our stack:
  - receivers: otlp (grpc + http), prometheus (self-scrape)
  - processors: memory_limiter → batch → resource (add service.namespace, k8s.cluster.name) → k8sattributes (add pod name, namespace, node from K8s metadata)
  - exporters: otlp to Tempo, debug (sampling logs), prometheus (expose metrics)
  - service pipelines: traces pipeline, metrics pipeline
- k8sattributes processor: what it adds (k8s.pod.name, k8s.namespace.name, k8s.node.name, k8s.deployment.name), how to configure, RBAC requirements, how apps signal their pod identity (downward API OTEL_RESOURCE_ATTRIBUTES env var)
- batch processor tuning: send_batch_size (default 8192), timeout (default 200ms), send_batch_max_size — impact on latency vs throughput
- memory_limiter: limit_mib, spike_limit_mib, check_interval — how to size for small cluster
- Sampling in Collector: probabilistic sampler (head-based, simple percentage), tail sampling processor (head-based decision deferred — requires all spans from a trace to arrive at same Collector instance, needs sticky routing or single Collector)

### 4. Auto-Instrumentation with OTel Operator
- OTel Operator: K8s operator that manages Instrumentation CRs and Collector CRs
- Auto-instrumentation: inject OTel SDK via pod annotations (instrumentation.opentelemetry.io/inject-*) without code changes
- Supported languages for auto-instrumentation: Java, Node.js, Python, .NET, Go (experimental)
- Instrumentation CR: specify endpoint (Collector service), sampler, resource attributes, propagation
- Traefik auto-instrumentation: Traefik has native OTel support (v3+) — configure via Helm values rather than auto-instrumentation
- n8n auto-instrumentation: n8n is Node.js — auto-instrumentation via annotation possible, or use n8n's built-in OTel support if available
- Zitadel auto-instrumentation: Go — auto-instrumentation is experimental for Go, check Zitadel's native OTel config instead
- Trade-off: OTel Operator adds complexity (another CRD, another operator), worth it only if many services need auto-instrumentation

### 5. Manual Instrumentation Patterns
- Python manual instrumentation: opentelemetry-sdk + opentelemetry-exporter-otlp, trace context setup, span creation, context propagation across async calls
- Node.js manual instrumentation: @opentelemetry/sdk-node, auto-instrumentation packages (http, express, pg), OTEL_EXPORTER_OTLP_ENDPOINT environment variable
- Go manual instrumentation: go.opentelemetry.io/otel, TracerProvider setup, span creation, context propagation with context.Context
- Key patterns: creating spans (tracer.Start), adding attributes (span.SetAttributes), recording errors (span.RecordError + span.SetStatus), creating child spans for database calls
- Environment variable configuration (preferred over code config): OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL (grpc vs http/protobuf), OTEL_TRACES_SAMPLER, OTEL_RESOURCE_ATTRIBUTES
- K8s deployment pattern: set OTel env vars in Deployment spec (environment variables section), use Downward API for k8s.pod.name

### 6. Context Propagation
- W3C TraceContext (traceparent header): the standard, supported by all modern OTel SDKs and Traefik — use this
- B3 propagation (X-B3-TraceId etc.): legacy format used by Zipkin/Jaeger, still relevant for some services
- How propagation works: incoming request has traceparent header → service extracts → creates child span → propagates to outgoing calls
- Traefik propagation: Traefik v3 propagates W3C TraceContext automatically when OTel tracing is enabled
- Cross-service tracing: for a trace to span multiple services, all services must use the same propagation format AND extract/inject headers correctly
- Baggage: W3C Baggage for propagating key-value pairs (user_id, tenant_id) — how to use, performance caution (sent on every HTTP request)

### 7. Traefik OTel Integration
- Traefik v3 native OTel support: tracing.openTelemetry configuration in Traefik Helm values
- Config: endpoint (OTel Collector gRPC address), insecure (true for internal cluster), sampler (type: rateLimiting or always), headers
- What Traefik traces: HTTP request in, routing decision, upstream service call — full ingress span
- Traefik trace attributes: http.method, http.url, http.status_code, net.peer.name, traefik-specific router/service attributes
- Enabling for all IngressRoutes vs per-IngressRoute: Traefik traces all routes when OTel is enabled globally
- Access log correlation: can add trace ID to Traefik access logs (for Loki correlation), how to configure

### 8. n8n OTel Integration
- n8n observability: does n8n have built-in OTel support? If yes, environment variables to configure
- If no native support: Node.js auto-instrumentation via OTel Operator annotation — what gets instrumented (HTTP calls, database queries)
- Workflow execution tracing: ideal trace would show workflow trigger → node execution → external API calls → database writes
- Correlation with n8n logs: if n8n logs execution_id, can use Loki derived field → Tempo to jump from log line to trace
- Custom instrumentation for n8n: using n8n's hook system to add OTel spans (if hooks allow custom code)

### 9. Grafana Tempo — Deployment on K3s
- Helm deployment: grafana/tempo chart, single binary mode vs microservices — use single binary (monolithic) for 2-node cluster
- Key Helm values: storage backend (s3), MinIO endpoint, bucket name, credentials, compactor, ingester settings
- Tempo single binary (target: all): ingester + querier + compactor + distributor in one pod, sufficient for small cluster, lower operational overhead
- Resource requirements: CPU/memory for Tempo with MinIO backend on 2-node cluster — storage is offloaded to MinIO so Tempo itself is relatively lightweight
- Ports: gRPC (4317 for OTel), HTTP (3100 for Tempo API), Tempo UI (not standalone, accessed via Grafana)
- Persistence: Tempo needs a WAL volume (local PVC) for in-progress traces before they're flushed to MinIO — size recommendation

### 10. Grafana Tempo — MinIO S3 Backend Configuration
- Tempo Helm values for MinIO: storage.trace.backend=s3, storage.trace.s3.endpoint, storage.trace.s3.bucket, storage.trace.s3.region (use "us-east-1" for MinIO), storage.trace.s3.access_key, storage.trace.s3.secret_key
- Credentials: K8s Secret, reference via existingSecret in Helm values
- Bucket creation: pre-create with mc mb (same pattern as Loki bucket)
- MinIO path layout: what Tempo stores in the bucket (blocks/, wal/, compacted/)
- Common errors: same as Loki (403/404/endpoint unreachable) — systematic diagnosis
- Shared MinIO with Loki: separate buckets (loki-chunks, loki-ruler, tempo-traces), same MinIO instance — no conflict, ensure bucket permissions are per-service

### 11. Grafana Tempo — TraceQL
- TraceQL basics: span-selector {} with pipeline | operations — analogous to LogQL for traces
- Span selectors: {resource.service.name="traefik"}, {name=~".*http.*"}, {status=error}, {duration>200ms}
- Pipeline operations: | select (pick attributes), | count() (count matching spans per trace), | avg(duration) (aggregate)
- Trace-level vs span-level queries: by default TraceQL matches spans but returns full traces
- Common queries:
  - All traces through Traefik: {resource.service.name="traefik"}
  - Slow traces (>1s): {resource.service.name="traefik" && duration > 1s}
  - Error traces: {status=error}
  - Database calls: {span.db.system="postgresql"}
  - Traces for specific user: {span.user.id="abc123"} (if propagated via baggage)
  - Root spans only: {rootName=~".*"} with rootService filter
- Grafana integration: TraceQL in Explore → Tempo data source, building trace dashboards with Tempo data source variables

### 12. Grafana Tempo — Metrics-Generator
- What metrics-generator does: derives RED metrics (Rate, Error, Duration) from ingested traces without requiring Prometheus instrumentation on services
- Enables service graph: auto-discovers service-to-service call relationships from trace parent/child spans
- Configuration: processor.service_graphs and processor.span_metrics in Tempo config, remote_write to Prometheus
- Metrics produced: traces_service_graph_request_total, traces_service_graph_request_failed_total, traces_span_metrics_duration_seconds_bucket
- Grafana dashboards: Tempo provides pre-built dashboards for service graph visualization (import from grafana.com)
- Resource implication: metrics-generator adds CPU load proportional to trace volume — monitor on small cluster
- Integration with existing Prometheus: Tempo remote_writes to Prometheus (or Prometheus scrapes Tempo /metrics/generate endpoint)

### 13. Grafana — Trace Correlation with Logs and Metrics
- Tempo data source setup in Grafana: URL (http://tempo:3100), Trace to Logs (Loki data source, derived fields), Trace to Metrics (Prometheus data source)
- Trace to Logs (Loki): configure derived field in Loki data source — when viewing a trace in Grafana, can jump to logs for the same trace ID; requires trace ID to appear in log lines (Traefik access log trace ID injection)
- Logs to Traces (Loki derived fields): in Loki data source config, add derived field matching trace ID pattern in log line → link to Tempo data source URL with traceId variable
- Trace to Metrics (exemplars): Prometheus stores exemplars (sample + trace ID), Grafana shows exemplar points on metric graph → jump to Tempo trace; requires histogram metrics with exemplar support
- Service graph in Grafana: if metrics-generator is enabled, Grafana NodeGraph panel shows call graph derived from traces
- Unified search across pillars: Grafana Explore allows switching between logs/metrics/traces for same time window + service

### 14. Instrumentation Priorities and Sampling Strategy
- Prioritization for 2-node K3s cluster (highest value first):
  1. Traefik: single point all traffic flows through, native OTel support, minimal effort
  2. n8n: workflow executions are opaque without tracing, high value for debugging
  3. Zitadel: auth flows are latency-sensitive, tracing reveals slow OIDC paths
  4. Custom client apps: highest business value, instrument during build
  5. Backstage/Outline: lower priority, less complex call patterns
- Head-based sampling: sample percentage at ingestion — simple, low overhead, loses rare errors
- Tail-based sampling: OTel Collector tail_sampling processor — keep 100% of error traces, sample 10% of successful traces; requires all spans from a trace at one Collector (single gateway Deployment works for our scale)
- Recommended strategy for small cluster: tail sampling in Collector Deployment — 100% errors + slow traces (>2s) + 10% of successful fast traces
- Storage sizing: 1 trace ≈ 5-50KB depending on span count; at 1000 req/sec with 10% sample + 100% errors ≈ X GB/day — calculate for our expected load

### 15. Cost and Resource Considerations at 2-Node Scale
- Is distributed tracing worth it at 2-node scale? Arguments for (debugging, client demonstration, SEO "observability done right") and against (operational overhead, resource cost, MinIO usage)
- Minimum viable tracing: Traefik only, 1% sampling, no metrics-generator — how little can we run and still get value
- Resource budget: Tempo (single binary, MinIO backend) ≈ 200-500MB RAM at rest, OTel Collector ≈ 100-200MB, low CPU — fits on 2-node cluster alongside existing stack
- MinIO usage: with tail sampling, low-traffic consulting firm cluster generates minimal trace data — estimate GB/month
- Operational overhead: Tempo + OTel Collector = 2 additional Helm releases, 1-2 CRDs, 1 MinIO bucket — manageable
- Recommendation: deploy now at minimal config (Traefik tracing → Collector → Tempo → Grafana), expand instrumentation as services are built

## Required Output Format

Structure your response EXACTLY like this — it will be split into separate skill files for AI agents, with one file per top-level `#` header:

```markdown
# OpenTelemetry

## Overview
[2-3 sentences: what OTel is, the three signals (traces/metrics/logs), why Collector matters]

## Architecture
### Signal Flow
[Diagram as ASCII: App -> SDK -> Collector -> Tempo/Prometheus/Loki]
### Collector Deployment Modes
[DaemonSet vs Deployment vs Sidecar — recommendation for 2-node K3s]
### OTel Operator
[What it does, whether to use it, trade-offs]

## Collector Deployment on K3s
### Helm Deployment
[Key values.yaml snippet: mode, config section, RBAC]
### Complete Collector Config
[Full config.yaml: receivers, processors, exporters, service pipelines]

## Receivers Reference
### OTLP (gRPC + HTTP)
[Ports, config snippet, when to use each protocol]
### Prometheus Receiver
[For scraping OTel-instrumented app metrics]

## Processors Reference
### memory_limiter
[Config, sizing guidance]
### batch
[Config, latency vs throughput tuning]
### resource
[Adding cluster/environment attributes]
### k8sattributes
[What it adds, RBAC, Downward API for pod identity]
### tail_sampling
[Config for 100% errors + 10% success, single Collector requirement]

## Auto-Instrumentation
### OTel Operator
[Installation, Instrumentation CR example]
### Language Support Matrix
[Table: language, auto-instrumentation status, annotation]
### Traefik Native OTel
[Helm values config, no annotation needed]

## Manual Instrumentation Patterns
### Environment Variable Configuration
[OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT, sampler — K8s Deployment env block]
### Go
[TracerProvider setup, span creation, context propagation skeleton]
### Node.js
[SDK setup, auto-instrumentation packages, n8n pattern]
### Python
[SDK setup, span creation pattern]

## Context Propagation
[W3C TraceContext vs B3, how Traefik propagates, cross-service requirement]

## Service-Specific Integration
### Traefik
[tracing.openTelemetry Helm values, attributes produced, access log trace ID]
### n8n
[Auto-instrumentation annotation, what gets traced, custom span option]
### Zitadel
[Native OTel config if available, fallback approach]

## Troubleshooting
### Spans Not Reaching Collector
[Check app env vars, network connectivity, Collector receiver logs]
### Collector Dropping Spans
[memory_limiter OOM, batch timeout, export errors]
### Traces Not Correlated
[Propagation format mismatch, missing traceparent header]

# Grafana Tempo

## Overview
[2-3 sentences: what Tempo does, label-less trace storage, MinIO backend, TraceQL]

## Deployment on K3s
### Helm Deployment (Single Binary)
[Key values.yaml: storage, resources, ports, WAL PVC]
### MinIO Backend Configuration
[Complete storage.trace.s3 config, credentials Secret, bucket pre-creation]
### Common MinIO Errors
[403/404/endpoint — cause and fix]
### Resource Requirements
[CPU/memory estimate for 2-node cluster]

## Storage Architecture
[Blocks in MinIO, WAL for durability, compactor, retention]

## Grafana Data Source Setup
[URL, Trace to Logs config, Trace to Metrics config, TraceQL query type]

## TraceQL Reference
### Syntax
[Span selector + pipeline, attribute namespaces: resource.* vs span.*]
### Common Queries
[Table: use case -> TraceQL query — Traefik errors, slow traces, DB calls, service-specific]
### Grafana Explore
[How to use TraceQL in Explore, building trace-based dashboards]

## Metrics-Generator
### Configuration
[Helm values to enable, processors, remote_write to Prometheus]
### Metrics Reference
[Table: metric name, description, use in Grafana]
### Service Graph
[What it shows, NodeGraph panel setup, Grafana dashboard]

## Correlation with Logs and Metrics
### Tempo -> Loki (Trace to Logs)
[Derived field config in Loki data source, trace ID injection in Traefik logs]
### Loki -> Tempo (Logs to Traces)
[Derived field in Loki data source -> Tempo link]
### Prometheus -> Tempo (Exemplars)
[Exemplar support requirement, Grafana graph panel config]

## Sampling Strategy
### Head-Based (Simple)
[OTel SDK sampler config, when adequate]
### Tail-Based (Recommended)
[Collector tail_sampling config, 100% errors + 10% success, sizing]
### Storage Estimate
[Trace size estimate, GB/month at consulting firm scale]

## Troubleshooting
### Traces Not Appearing in Tempo
[Check Collector export logs, Tempo ingester logs, MinIO connectivity]
### TraceQL No Results
[Data source URL, time range, service.name label check]
### MinIO Storage Growing Unexpectedly
[Compaction not running, retention not configured, fix commands]

## Is It Worth It? (2-Node Scale)
[Honest assessment: minimum viable config, resource cost, value for Helix Stax]
```

Be thorough, opinionated, and practical. Include actual OTel Collector config.yaml snippets, actual Tempo Helm values, actual TraceQL queries, and actual Grafana data source configuration. Do NOT give me theory — give me copy-paste-ready configs for a 2-node K3s cluster on AlmaLinux 9.7 with MinIO as the Tempo backend and the existing Prometheus + Grafana + Loki stack already running.
