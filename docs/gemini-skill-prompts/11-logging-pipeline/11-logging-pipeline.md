# Gemini Deep Research: Logging Pipeline (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These tools form the complete log shipping pipeline for our K3s cluster. They form an inseparable chain:

- **Promtail** — the legacy log collection agent (DaemonSet, scrapes pod logs from /var/log/pods). Still maintained but Grafana Alloy is the recommended successor.
- **Grafana Alloy** — the successor to Promtail, collects logs + metrics + traces in one agent (River config language). Single binary for logs + metrics + traces (OTel), more expressive than Promtail YAML.
- **Loki** — log aggregation system. All pods running on our K3s cluster ship their logs to Loki via the collection agent. Grafana queries Loki as its log data source. Loki stores log chunks in MinIO (S3-compatible) for cost-effective long-term retention.

You cannot troubleshoot one without understanding the others.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, 2 nodes (heart: 178.156.233.12 control plane, helix-worker-1: 138.201.131.157 worker), Hetzner Cloud
- **Container runtime**: containerd (K3s default) — logs in CRI format under /var/log/pods
- **OS**: AlmaLinux 9.7 — systemd journal logs in addition to container logs
- **Loki deployment**: Helm chart on K3s
- **Loki mode**: Simple scalable OR monolithic — need guidance on which fits our 2-node cluster
- **Storage backend**: MinIO (S3-compatible, running on same K3s cluster) for chunks; TSDB index (preferred over BoltDB shipper)
- **Log collection agent**: Promtail or Grafana Alloy (DaemonSet on each node) — need guidance on which
- **Visualization**: Grafana Explore + log panels in dashboards
- **Metrics consumer**: Prometheus scrapes Loki's `/metrics` endpoint via ServiceMonitor
- **Alerting**: Loki ruler evaluates LogQL alert rules → Alertmanager → Rocket.Chat + Postal
- **Tracing correlation**: Future — Grafana Tempo planned for Phase 6+; Loki must be ready with derived fields
- **Log sources**: All K3s pods: Traefik, CloudNativePG, Valkey, MinIO, Harbor, Zitadel, ArgoCD, Devtron, CrowdSec, n8n, Rocket.Chat, Grafana, Prometheus, Alertmanager, Loki itself, Outline, Backstage, Ollama, Open WebUI

---

## What I Need Researched

### SECTION A: Promtail vs Grafana Alloy — Decision Guide
- Promtail status: still maintained but Grafana Alloy is the recommended successor as of Grafana 10+
- Feature comparison matrix: Promtail vs Alloy for our use case (log collection, K3s, AlmaLinux systemd, MinIO backend)
- Alloy advantages: single binary for logs + metrics + traces (OTel), River config language (more expressive than Promtail YAML), built-in component library, better performance on multi-pipeline scenarios
- Promtail advantages: simpler, battle-tested, less RAM, smaller DaemonSet footprint — matters on 2-node cluster
- Migration path: how to run Alloy alongside Promtail during transition, config translation tools
- Recommendation for 2-node K3s cluster with small Hetzner nodes: which to run today, at what point to migrate

---

### SECTION B: Grafana Alloy — Complete Reference

#### B1. Deployment on K3s
- DaemonSet deployment via Helm (grafana/alloy chart): key values to configure (replicas=null for DaemonSet, tolerations for control plane node, resource limits)
- RBAC requirements: ClusterRole needed for pod discovery (watch pods, namespaces, nodes, endpoints)
- Alloy ConfigMap structure: the alloy.config key, how changes are applied (ConfigMap update → pod restart or hot reload)
- Hot reload: Alloy supports config reload without restart (/-/reload endpoint) — how to trigger via kubectl
- Persistent volume: Alloy needs a PVC or hostPath for WAL (write-ahead log) to survive restarts without log gaps
- Resource sizing: memory and CPU requests/limits for a 2-node cluster scraping ~20 services

#### B2. River Language and Configuration
- River language fundamentals: blocks, components, attributes, references (component.output.field syntax), expressions
- Component categories: sources (log.file, loki.source.kubernetes, otelcol.receiver.*), processors (loki.process, otelcol.processor.*), exporters (loki.write, otelcol.exporter.*)
- Complete working Alloy config for K3s pod log collection:
  - discovery.kubernetes component for pod discovery
  - discovery.relabel to extract pod name, namespace, container, node
  - loki.source.kubernetes (uses K8s API to stream logs — preferred over file scraping for K3s)
  - loki.process for pipeline stages
  - loki.write pointing to Loki service
- Alternative: loki.source.file with /var/log/pods/**/*.log glob (if using file-based scraping instead of K8s API)
- Which source to prefer for K3s: loki.source.kubernetes vs loki.source.file — trade-offs (API-based avoids hostPath mount, file-based works without RBAC for pod log streaming)

#### B3. Pipeline Stages
- Pipeline stages (inside loki.process): docker, cri, json, logfmt, regex, multiline, drop, labels, structured_metadata, timestamp, metrics
- **CRI stage**: mandatory for K3s/containerd — parses the CRI log format prefix (timestamp, stream, flags) to extract the actual log line
- **JSON stage**: for services that log JSON (n8n, Zitadel, Traefik access logs in JSON mode) — extract fields as labels or structured_metadata
- **Regex stage**: for services that log in non-JSON text format — named capture groups become labels
- **Multiline stage**: for stack traces — startsWith pattern to collect multi-line exceptions as single log entry (Java, Python, Go panics)
- **Drop stage**: for filtering noisy logs before sending to Loki — match on label or line content, drop health check noise (GET /healthz, GET /readyz, kube-probe user-agent)
- **Metrics stage**: extract counters/histograms from log lines without Prometheus instrumentation — error rate, request duration, useful for services that don't expose /metrics
- **Structured metadata** (Loki 3.x): vs labels — structured_metadata is indexed differently (bloom filters), use for high-cardinality fields (trace_id, user_id) that would bloat label index

#### B4. OS-Level Log Collection (AlmaLinux systemd journal)
- Journal scraping on AlmaLinux 9.7: loki.source.journal component, reading systemd journal directly
- Key journal units to scrape: k3s.service, containerd.service, sshd.service, firewalld.service, auditd.service, crond.service
- journal_path vs journald.conf location on AlmaLinux 9.7 (under /var/log/journal/ for persistent, /run/log/journal/ for volatile)
- Filtering journal logs: only ship ERROR+ severity or specific units to avoid volume explosion
- Alloy running as non-root: systemd journal requires read access to /var/log/journal — either run as root or add Alloy service account to systemd-journal group

#### B5. Label Design Strategy
- What labels to extract for each log source:
  - Kubernetes pods: namespace, pod, container, node (from discovery.kubernetes), app (from pod label app.kubernetes.io/name)
  - Traefik: method, path (be careful — high cardinality), status_code (group into 2xx/3xx/4xx/5xx)
  - n8n: workflow_id (if logged), execution_id (if logged)
  - Zitadel: event_type (from structured log field)
  - SystemD journal: unit, priority
- High-cardinality label anti-patterns: user_id, request_id, trace_id as labels → use structured_metadata instead
- Label naming conventions: lowercase, underscores, match Prometheus label names where possible for correlation
- Minimum viable label set for small cluster: namespace + pod + container is sufficient; add app if pods don't have consistent naming

---

### SECTION C: Promtail — Reference (Legacy / Fallback)

#### C1. Deployment on K3s
- DaemonSet Helm values (grafana/promtail chart): RBAC, positions hostPath, resource sizing
- RBAC requirements: ClusterRole for pod log access
- positions.yaml: tracks file read positions to survive restarts, location on hostPath
- Resource sizing for 2-node cluster

#### C2. Configuration Reference
- Promtail config structure: server, positions, clients, scrape_configs
- Kubernetes pod discovery: kubernetes_sd_configs with role: pod, relabel_configs to extract labels
- Pipeline stages in Promtail: docker, cri, json, regex, multiline, drop (same concepts as Alloy but YAML syntax)
- How to check Promtail targets: /targets endpoint on Promtail service (port 3101 by default)
- How to check Promtail log sending: /metrics (promtail_sent_bytes_total, promtail_dropped_bytes_total)

#### C3. Promtail → Alloy Migration
- How to run Alloy alongside Promtail during transition
- `alloy convert` command for config translation if available
- Component mapping table: Promtail scrape_config → Alloy components
- Risk: duplicate log ingestion during migration window

---

### SECTION D: Loki — Complete Reference

#### D1. CLI Reference (logcli)
- Install logcli on AlmaLinux 9.7 (binary download, no package manager)
- `logcli query` — run LogQL queries from CLI with options: `--from`, `--to`, `--limit`, `--output`, `--timezone`
- `logcli labels` — list all label names in Loki
- `logcli series` — list matching log streams given a label selector
- `logcli instant-query` — instant query (like Prometheus instant query)
- Authentication flags: `--username`, `--password`, `--bearer-token`, `--addr` for targeting in-cluster Loki
- Output formats: `--output=raw`, `--output=jsonl`, `--output=default`
- Useful one-liners: tail logs for a namespace, count errors in last hour, search for specific string
- How to port-forward to Loki in K3s for local logcli access: `kubectl port-forward`

#### D2. LogQL Reference
- Stream selector syntax: `{namespace="monitoring", app="grafana"}` — label matchers (=, !=, =~, !~)
- Filter expressions: `|=` (contains), `!=` (not contains), `|~` (regex), `!~` (not regex)
- Parser expressions: `| json`, `| logfmt`, `| pattern`, `| regexp`, `| unpack`
- Label filter expressions after parsing: `| level="error"`, `| duration > 1s`, `| status_code >= 500`
- Line format expressions: `| line_format "{{.level}}: {{.msg}}"` — reshaping log lines
- Labels format: `| label_format` — renaming, dropping, composing labels
- Metric queries (log → metric): `rate()`, `count_over_time()`, `bytes_rate()`, `bytes_over_time()`
- Aggregation: `sum by()`, `avg_over_time()`, `max_over_time()`, `quantile_over_time()`
- Unwrapped range aggregations: `| unwrap duration | avg_over_time[5m]`
- Essential LogQL queries: error rate per service, slowest requests, CrashLoop detection, auth failures

#### D3. LogQL Reference by Service
- **Traefik access logs** (JSON format):
  - All 5xx errors: `{namespace="traefik"} | json | status >= 500`
  - Request rate by service: `rate({namespace="traefik"}[5m]) by (upstream_service)`
  - Slow requests: `{namespace="traefik"} | json | duration > 1000`
- **n8n logs**:
  - Workflow execution errors: `{namespace="n8n"} |= "error" | json`
  - Execution count over time: `count_over_time({namespace="n8n"} |= "Execution finished"[1h])`
- **Zitadel logs**:
  - Auth failures: `{namespace="zitadel"} | json | message =~ ".*failed.*"`
  - Event types: `{namespace="zitadel"} | json | line_format "{{.event_type}}"`
- **CloudNativePG / PostgreSQL**:
  - Slow queries: `{namespace="cnpg-system"} |= "duration:"`
  - Connection errors: `{namespace="cnpg-system"} |= "connection" |= "error"`
- **ArgoCD sync status**: `{namespace="argocd"} |= "sync" | json | status != "Synced"`
- **CrowdSec alerts**: `{namespace="crowdsec"} |= "ban"` or `|= "decision"`
- **Generic patterns**: error rate by namespace, recent errors across all namespaces, log volume dashboard

#### D4. Deployment on K3s
- Loki Helm chart: `grafana/loki` — key values for our setup
- Deployment modes: monolithic (single binary, `loki.deploymentMode: SingleBinary`) vs simple scalable (read/write/backend components) — recommendation for 2-node cluster
- Sizing guidance for 2-node cluster: replicas, resource requests/limits, storage sizing
- `loki.storage.type: s3` with MinIO: endpoint, bucket, region, access key, secret key via Kubernetes Secret
- `loki.storage.s3.insecure: true` — when needed for in-cluster MinIO without TLS
- Index type selection: `tsdb` (recommended, Loki 2.8+) vs `boltdb-shipper` (legacy) — which to use and why
- Schema config: `schema_config.configs` — period_start, object_store, store, schema version
- Compactor configuration: retention enforcement, compaction interval
- Ruler configuration: for LogQL alerting rules
- Traefik IngressRoute for Loki (if exposing for external logcli access)
- Prometheus ServiceMonitor for Loki metrics scraping

#### D5. Storage Architecture Deep-Dive
- **Chunks**: compressed log data stored as objects in MinIO — how chunk size affects query performance and storage efficiency (max_chunk_age, chunk_target_size)
- **TSDB index**: stored alongside chunks in MinIO (single-store), no separate index component needed, WAL for durability. Why TSDB over BoltDB-shipper
- **Compaction**: how Loki merges small chunks into larger ones (compactor component), why it matters for MinIO (fewer objects = lower LIST operation cost)
- Schema config: schema_config.configs array — must not be changed for existing data, only append new schemas
- MinIO bucket layout: what Loki stores at each path prefix (chunks/, index/, ruler/)

#### D6. MinIO S3 Backend Configuration
- Loki Helm values for MinIO S3 backend: storage.type=s3, storage.s3.endpoint, storage.s3.bucketnames, storage.s3.region (use "us-east-1" even for self-hosted MinIO)
- Credentials: how to provide MinIO access key/secret (K8s Secret + environment variable injection, NOT in Helm values directly)
- Bucket creation: must pre-create the bucket in MinIO before Loki starts (MinIO mc mb command)
- Common MinIO + Loki errors: 403 (wrong credentials), 404 (bucket doesn't exist), endpoint not reachable (use internal K8s service name not external URL)
- Loki single binary vs microservices mode for 2-node cluster: which to use, resource footprint difference

#### D7. Retention and Compaction
- Retention configuration: `limits_config.retention_period` (global), per-tenant retention via overrides
- Retention and compaction relationship: compactor must be enabled for retention to work (`compactor.retention_enabled: true`)
- Compactor schedule: `compaction_interval` (how often to compact, default 10m), `retention_delete_delay` (how long after expiry before deletion)
- Storage cost implication: without compaction, Loki accumulates many small chunks in MinIO — LIST operations are expensive on MinIO
- Recommended retention for small cluster: 30-90 days depending on disk/MinIO budget
- How to check current disk usage by Loki in MinIO: `mc du minio/loki-bucket`
- Global retention: `limits_config.retention_period` — how to set globally
- Compactor: `compactor.retention_enabled: true`, compaction interval, working directory
- How chunks are deleted from MinIO: tombstones, deletion via compactor
- How to manually delete a log stream (break-glass procedure)

#### D8. Label Design and Cardinality
- Loki label best practices: keep cardinality LOW — labels should be low-cardinality categorical values
- Recommended label set for K3s: `namespace`, `pod`, `container`, `app`, `node`
- High-cardinality anti-patterns: using `trace_id`, `request_id`, `user_id` as labels
- How to push high-cardinality data into structured metadata (Loki 3.x feature) instead of labels
- Label limits: default max labels per stream, how to configure
- Stream sharding: what happens when one stream gets too large
- How to audit cardinality: Loki `/loki/api/v1/labels` and series count

#### D9. Multi-Tenancy
- Single-tenant mode: `auth_enabled: false` — default for simple setup
- Multi-tenant mode: `X-Scope-OrgID` header, Grafana data source per-tenant config
- When to enable multi-tenancy (client isolation, cost attribution)
- Our current recommendation: single-tenant (auth_enabled: false) for now

#### D10. Loki Alerting (Ruler)
- Loki ruler: LogQL alerting rules that feed into Alertmanager (same as Prometheus alerting rules but log-based)
- `ruler.storage` config: how to store rules (local filesystem vs object store)
- Rule file format: same as Prometheus PrometheusRule CRD (groups, alert, expr in LogQL)
- Essential log-based alerts: ErrorRateHigh (errors/s > threshold), OOMKillDetected (kernel log pattern), AuthFailureSpike
- How Loki ruler integrates with Alertmanager: `ruler.alertmanager_url` config
- Difference between Loki ruler alerts and Grafana alerting on Loki data sources (two separate systems)
- When to use Loki ruler vs Grafana alerting for log-based alerts
- Ruler storage in MinIO: ruler.storage.type=s3 config, bucket path
- How Loki ruler sends alerts: to Alertmanager (same Alertmanager as Prometheus)
- Routing in Alertmanager: Loki ruler alerts vs Prometheus alerts — differentiate by alert labels

#### D11. Grafana Integration
- Loki data source configuration in Grafana: URL, auth, maximum lines
- Derived fields: linking `trace_id` in logs to Grafana Tempo (prepare for Phase 6+)
- Explore view: using LogQL in Grafana Explore, live tail, log context
- Log panels in dashboards: log panel type, log volume histogram panel
- Log to metric panels: converting LogQL metric queries into time series panels
- Label filters in Grafana: using Grafana variables to filter Loki queries by namespace/pod/app
- Correlating logs and metrics: Grafana exemplars, split pane Explore view

---

### SECTION E: End-to-End Pipeline Troubleshooting

#### E1. Log Not Appearing in Grafana — Systematic Diagnosis
1. Is Alloy/Promtail running on the node? (`kubectl get pods -n monitoring -o wide`, check node assignment)
2. Is Alloy scraping the pod? (check Alloy /metrics for loki_source_kubernetes_* or check targets endpoint)
3. Is Alloy sending to Loki? (check Alloy logs for push errors, check loki_distributor_bytes_received metric in Grafana)
4. Is Loki ingesting? (Loki /metrics: loki_distributor_lines_received, check for 429 rate limit errors)
5. Is Grafana querying the right data source? (check Loki data source URL, test connection in Grafana)

#### E2. Common Alloy Issues
- RBAC missing (can't discover pods)
- WAL full (disk pressure)
- OOM on large log bursts
- CRI format not parsed: Alloy not stripping CRI prefix from containerd logs

#### E3. Common Loki Issues
- MinIO connection error (endpoint wrong, credentials wrong, bucket missing)
- Chunk encoding error, schema mismatch after config change
- Rate limiting: Loki's `ingestion_rate_limit_mb` and `burst_size_mb` — how to increase for log-heavy periods
- Common errors: stream limit exceeded, rate limit errors

#### E4. Common Grafana Issues
- Time range mismatch, label selector returning no streams
- LogQL syntax error (run in Explore with full error message)

#### E5. Log Gaps After Node Restart
- WAL replay behavior in Alloy, how to avoid double-sending
- Promtail positions.yaml replay on restart

---

### Best Practices & Anti-Patterns
- What are the top 10 best practices for this tool in production?
- What are the most common mistakes and anti-patterns? Rank by severity (critical → low)
- What configurations look correct but silently cause problems?
- What defaults should NEVER be used in production?
- What are the performance anti-patterns that waste resources?

### Decision Matrix
- When to use X vs Y (for every major decision point in this tool)
- Clear criteria table: "If [condition], use [approach], because [reason]"
- Trade-off analysis for each decision
- What questions to ask before choosing an approach

### Common Pitfalls
- Mistakes that waste hours of debugging — with prevention
- Version-specific gotchas for current releases
- Integration pitfalls with other tools in our stack
- Migration pitfalls when upgrading

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CLI commands with examples
- Configuration patterns with copy-paste snippets
- Troubleshooting decision tree (symptom → cause → fix)
- Integration points with other tools in our stack
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Full API/CLI reference (every flag, every option)
- Complete configuration schema with all fields documented
- Advanced patterns and edge cases
- Performance tuning parameters
- Security hardening checklist
- Architecture diagrams (ASCII)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (178.156.233.12, 138.201.131.157), domains (helixstax.com, helixstax.net), and service names
- Annotated YAML/JSON manifests
- Before/after troubleshooting scenarios
- Step-by-step runbooks for common operations
- Integration examples with our specific stack (K3s, Traefik, Zitadel, CloudNativePG, etc.)

Use `# Tool Name` as top-level headers to separate each tool's output for splitting into separate skill directories.

Be thorough, opinionated, and practical. Include actual commands, actual configs, and actual error messages. Do NOT give theory — give copy-paste-ready content for a K3s cluster on Hetzner behind Cloudflare.

---

The original output structure requested was:

```markdown
# Promtail

## Overview
[2-3 sentences: what Promtail does, its status as legacy agent, when to still use it]

## Deployment on K3s
[DaemonSet Helm values, RBAC, positions hostPath, resource sizing]

## Configuration Reference
### Server and Positions
[Config snippet]
### Kubernetes Pod Discovery
[scrape_configs with kubernetes_sd_configs, relabel_configs — full working example]
### Pipeline Stages
[CRI, JSON, regex, multiline, drop — examples for each]

## Targets and Debugging
[/targets endpoint, /metrics for send rate, common errors]

## Migration to Alloy
[alloy convert command, component mapping table]

# Grafana Alloy

## Overview
[2-3 sentences: what Alloy does, why it replaces Promtail, River language]

## Deployment on K3s
### Helm Deployment
[Key values.yaml snippet for DaemonSet, tolerations, RBAC, WAL PVC]
### Hot Reload
[kubectl annotation or endpoint trigger]
### Resource Sizing
[CPU/memory requests and limits for 2-node cluster]

## River Language Fundamentals
[Block syntax, component references, expressions — minimal working example]

## Complete K3s Log Collection Config
[Full alloy.config: discovery.kubernetes → discovery.relabel → loki.source.kubernetes → loki.process → loki.write]

## Pipeline Stages Reference
### CRI Stage
[Why required for K3s, config snippet]
### JSON Stage
[Extract fields, example for Traefik/n8n/Zitadel]
### Regex Stage
[Named capture groups, example]
### Multiline Stage
[Stack trace collection, startsWith pattern]
### Drop Stage
[Health check noise filtering, kube-probe drop rule]
### Metrics Stage
[Error rate counter extraction, example]
### Structured Metadata
[High-cardinality fields, when to use vs labels]

## Journal Scraping (AlmaLinux systemd)
[loki.source.journal config, unit filter, permission requirements]

## Label Design
### Recommended Label Set
[Table: label, source, high-cardinality risk, recommendation]
### Anti-Patterns
[What NOT to use as labels and why]

# Loki

## Overview
[2-3 sentences: what Loki does, log aggregation without full-text index, label-based]

## CLI Reference (logcli)
### Installation on AlmaLinux 9.7
[Binary download commands]
### Query Commands
[logcli query, labels, series with examples]
### Authentication & Targeting
[Flags for in-cluster Loki, port-forward]

## LogQL Reference
### Stream Selectors
[Label matcher examples]
### Filter Expressions
[contains, regex, not patterns]
### Parser Expressions
[json, logfmt, pattern, regexp]
### Metric Queries
[rate, count_over_time, aggregations]
### Essential Queries
[Error rate, slowest requests, auth failures]

## LogQL Reference by Service
### Traefik
[5xx errors, request rate, slow requests — copy-paste queries]
### n8n
[Execution errors, execution count]
### Zitadel
[Auth failures, event type extraction]
### CloudNativePG / PostgreSQL
[Slow queries, connection errors]
### ArgoCD
[Sync failures]
### CrowdSec
[Ban/decision events]
### Cross-Service Patterns
[Error rate by namespace, recent errors across all, log volume dashboard]

## Deployment on K3s
### Deployment Mode Decision
[Monolithic vs simple scalable — recommendation for 2-node]
### Helm Values
[Key loki.* values with MinIO S3 config]
### Schema Config
[schema_config.configs YAML]
### Kubernetes Secret for MinIO Credentials
[Secret YAML + values.yaml reference]
### Prometheus ServiceMonitor
[Loki metrics scraping]
### Traefik IngressRoute
[If exposing for external logcli]

## Storage Architecture
### Chunks
[How logs are stored, chunk sizing parameters]
### TSDB Index
[Why TSDB over BoltDB-shipper, single-store with MinIO]
### Compaction
[Why it matters, compactor config, MinIO LIST cost]

## MinIO S3 Backend Configuration
### Helm Values
[Complete storage.s3 config snippet]
### Credentials
[K8s Secret pattern, environment variable injection]
### Bucket Setup
[mc mb command, pre-creation requirement]
### Common Errors
[403/404/connection — cause and fix for each]

## Retention and Compaction
[retention_period, compactor.retention_enabled, compaction_interval, storage cost impact]

## Label Design
### Recommended Label Set
[namespace, pod, container, app, node]
### Anti-Patterns
[High-cardinality labels to avoid]
### Cardinality Auditing
[API queries to check stream count]

## Multi-Tenancy
### Single-Tenant Config
[auth_enabled: false setup]
### When to Enable Multi-Tenancy
[Decision criteria]

## Alerting via Ruler
### Ruler Config
[alertmanager_url, storage]
### Rule File Format
[YAML example with alerting rule and recording rule]
### Essential Log-Based Alerts
[ErrorRateHigh, OOMKill, AuthFailure YAML]
### Loki Ruler vs Grafana Alerting
[Decision framework]
### Alertmanager Integration
[alertmanager_url config, routing differentiation from Prometheus alerts]

## Grafana Integration
### Data Source Config
[URL, auth, derived fields for Tempo]
### Explore View Patterns
[Live tail, log context]
### Log + Metric Correlation
[Split pane, exemplars]

## End-to-End Troubleshooting
### Log Not Appearing in Grafana
[5-step diagnostic with kubectl commands at each step]
### Rate Limiting
[ingestion_rate_limit_mb, how to detect and increase]
### MinIO Issues
[Connectivity test, credential check, bucket verification]
### Log Gaps After Node Restart
[WAL behavior, duplicate prevention]
### Common Errors
[Error messages and fixes]
```

Be thorough, opinionated, and practical. Include actual River language config snippets for Alloy, actual Loki Helm values YAML, actual LogQL queries for each service in our stack, and actual kubectl debugging commands. Do NOT give me theory — give me copy-paste-ready configs for a 2-node K3s cluster on AlmaLinux 9.7 with MinIO as the Loki backend, Promtail or Alloy as the collection agent, with Grafana as the frontend.
