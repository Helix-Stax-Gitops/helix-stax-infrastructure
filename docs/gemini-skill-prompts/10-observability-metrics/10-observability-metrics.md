# Gemini Deep Research: Observability Metrics Pipeline (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into three separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These three tools form the metrics observability pipeline at Helix Stax — each stage hands off to the next:

- **Prometheus**: Scrapes metrics from all services running on our K3s cluster, stores them as time-series data, evaluates alerting rules, and ships alerts to Alertmanager. Grafana queries Prometheus as its primary data source for all monitoring dashboards.
- **Grafana**: Our unified visualization platform — serves triple duty as monitoring dashboards (Prometheus + Loki data), public status page (replacing Gatus via public dashboards), and business intelligence layer (replacing Metabase via PostgreSQL data sources). Single pane of glass for all observability and business metrics.
- **Alertmanager**: Alert routing, deduplication, grouping, and silencing engine. Both Prometheus and Grafana ship alerts to Alertmanager. Routes alerts to the correct receiver (Rocket.Chat, Postal email, n8n webhook) based on severity and label matchers, deduplicates repeated alerts, and suppresses child alerts when a parent condition is already firing.

## Our Specific Setup
- **Deployment**: `kube-prometheus-stack` Helm chart on K3s (AlmaLinux 9.7, Hetzner Cloud)
- **Nodes**: heart (CP, 178.156.233.12) + helix-worker-1 (worker, 138.201.131.157)
- **Operator**: Prometheus Operator (bundled in kube-prometheus-stack) manages CRDs
- **Grafana data sources**: Prometheus (metrics), Loki (logs), PostgreSQL via CloudNativePG (business data), Alertmanager (alert state visualization)
- **Auth**: OIDC SSO via Zitadel for all three services
- **Alert sources**: Prometheus alerting rules (PrometheusRule CRDs) → Alertmanager; Grafana unified alerting → external Alertmanager; Loki ruler → Alertmanager
- **Receivers**: Rocket.Chat (webhook), Postal (self-hosted SMTP — admin@helixstax.com), n8n (webhook for alert-driven automations)
- **Routing**: severity-based (critical → all channels, warning → Rocket.Chat, info → email only)
- **Dead man's switch**: Prometheus Watchdog alert → Alertmanager → Grafana → Postal directly (bypasses n8n to avoid circular dependency if n8n is down)
- **Storage**: Local persistent volume on K3s (local-path provisioner), no remote write at this scale
- **Grafana status page**: public dashboards at status.helixstax.com (replaces Gatus)
- **BI dashboards**: Business metrics queried from CloudNativePG
- **Dashboard provisioning**: JSON models stored in git, loaded via ConfigMaps + Grafana provisioning sidecar
- **HA**: 2-node Alertmanager cluster (mesh gossip) for resilience across our 2 K3s nodes
- **Scrape targets** (all running on K3s): Traefik, CloudNativePG, Valkey, MinIO, Harbor, ArgoCD, Devtron, CrowdSec, Zitadel, Loki, n8n, Node Exporter, kube-state-metrics, Alertmanager

---

## What I Need Researched

### SECTION A: Prometheus

#### A1. CLI Reference (promtool)
- `promtool check config <file>` — validate prometheus.yml before applying
- `promtool check rules <file>` — validate alerting and recording rule files
- `promtool query instant`, `query range` — run PromQL queries from CLI
- `promtool test rules` — unit test alerting rules with test fixtures
- `promtool tsdb analyze` — analyze TSDB for cardinality issues
- `promtool tsdb list` — list blocks in TSDB
- HTTP API query examples via `curl`: instant query, range query, labels, series, targets
- How to reload Prometheus config without restart: `curl -X POST http://localhost:9090/-/reload`
- How to check Prometheus readiness and health: `/-/ready`, `/-/healthy` endpoints

#### A2. Deployment on K3s (kube-prometheus-stack)
- Key `prometheus.*` values in kube-prometheus-stack Helm chart
- PrometheusSpec: retention, storage, replicas, resource requests/limits for 2-node cluster
- How to set storage retention by time (`--storage.tsdb.retention.time`) and size (`--storage.tsdb.retention.size`)
- Persistent volume claim configuration (local-path provisioner on K3s)
- How to configure external labels (`externalLabels`) for cluster identification
- Scrape interval and evaluation interval global defaults
- Enabling the Prometheus web UI behind Traefik IngressRoute
- How to upgrade kube-prometheus-stack without losing TSDB data
- RemoteWrite configuration (when and how to add Grafana Cloud or Thanos remote write)
- Thanos sidecar — when to add it (scaling decision), what it provides

#### A3. Prometheus Operator CRDs
- `ServiceMonitor`: spec fields — selector, namespaceSelector, endpoints (port, path, interval, scheme, tlsConfig)
- `PodMonitor`: when to use PodMonitor vs ServiceMonitor (no Service object exposed)
- `PrometheusRule`: spec fields — groups, rules (alert, expr, for, labels, annotations)
- `Probe`: for blackbox monitoring (HTTP checks, TCP checks)
- `AlertmanagerConfig`: scoped routing rules and receivers without editing global Alertmanager config
- How the operator discovers and reconciles CRD objects
- Label selectors: how kube-prometheus-stack selects ServiceMonitors (default `release: prometheus` label)
- How to debug why a ServiceMonitor is not being picked up

#### A4. ServiceMonitor Examples (All Helix Stax Services)
- Traefik ServiceMonitor: port name, metrics path `/metrics`, interval
- CloudNativePG ServiceMonitor: pg_exporter endpoint, authentication
- Valkey ServiceMonitor: valkey-exporter sidecar pattern, port config
- MinIO ServiceMonitor: MinIO built-in `/minio/v2/metrics/cluster` endpoint
- Harbor ServiceMonitor: Harbor metrics endpoint, basic auth if required
- ArgoCD ServiceMonitor: which ArgoCD components expose metrics (server, repo-server, application-controller)
- Devtron ServiceMonitor: metrics endpoint if available
- CrowdSec ServiceMonitor: local API metrics endpoint
- Zitadel ServiceMonitor: metrics endpoint and auth
- Loki ServiceMonitor: Loki `/metrics` endpoint
- n8n ServiceMonitor: n8n metrics endpoint (if enabled), what metrics it exposes
- Node Exporter: already bundled in kube-prometheus-stack — key metrics, textfile collector

#### A5. PromQL Reference (Essential Queries)
- Node-level queries: CPU usage %, memory usage %, disk usage %, network I/O
- Pod-level queries: CPU throttling, OOMKill events, pod restarts, container memory
- K3s cluster queries: node readiness, deployment replica drift, PVC usage
- Traefik queries: request rate, error rate (4xx, 5xx), latency percentiles (p50, p95, p99)
- PostgreSQL (CloudNativePG) queries: connections, replication lag, query duration
- Loki queries: ingestion rate, chunk cache hit rate, query duration
- Alertmanager queries: alerts firing count, silences active
- General patterns: `rate()` vs `irate()`, `increase()`, `histogram_quantile()`, `topk()`, `sum by()`
- Label matchers: exact `=`, regex `=~`, not `!=`, not-regex `!~`
- Aggregation operators: `sum`, `avg`, `max`, `min`, `count`, `stddev`, `quantile`
- Binary operators: arithmetic, comparison, logical (`and`, `or`, `unless`)

#### A6. Recording Rules
- When to use recording rules: expensive queries, frequently used sub-expressions, federation aggregation
- Recording rule naming convention: `level:metric:operations` pattern
- How to write a recording rule for CPU usage per namespace
- How to write a recording rule for HTTP request rate per service
- How to write a recording rule for p99 latency (histogram_quantile pre-computation)
- Testing recording rules with `promtool test rules`
- How recording rules reduce query latency in Grafana dashboards

#### A7. Alerting Rules (PrometheusRule CRDs)
- Alert rule structure: `alert`, `expr`, `for`, `labels`, `annotations`
- Severity levels: `critical`, `warning`, `info` — what each means for routing
- Essential K3s cluster alerts: NodeDown, NodeHighCPU, NodeHighMemory, NodeDiskRunningFull
- Essential pod alerts: PodCrashLooping, PodOOMKilled, PodNotReady, DeploymentReplicasMismatch
- Essential service alerts: TraefikHighErrorRate, PostgreSQLDown, LokiIngestionError
- Watchdog (dead man's switch) alert: always-firing alert, how it works, why it matters
- Alert inhibition labels: how to add labels so Alertmanager can inhibit child alerts when parent fires
- Alert annotations templating: using `{{ $labels }}`, `{{ $value }}`, `{{ $externalLabels }}` in messages
- How to write a `for` duration: difference between `for: 0m` (instant) vs `for: 5m` (sustained)
- Testing alert rules: `promtool test rules` with test case files (YAML format)

#### A8. Scrape Configuration
- Global scrape config: `scrape_interval`, `scrape_timeout`, `evaluation_interval`
- Per-target overrides: `job_name`, `metrics_path`, `scheme`, `params`
- TLS config for scraping HTTPS endpoints: `ca_file`, `cert_file`, `key_file`, `insecure_skip_verify`
- Basic auth and bearer token for protected endpoints
- Metric relabeling: `relabel_configs` and `metric_relabel_configs` — when to use which
- Common relabeling patterns: dropping high-cardinality labels, renaming labels, filtering targets
- How to verify scrape targets: Prometheus UI `/targets` endpoint, `/api/v1/targets`

#### A9. Storage, Retention, and Performance
- TSDB storage layout: chunks, index, WAL, head block
- How to calculate storage needs for a 2-node cluster with 20+ scrape targets
- High cardinality problem: what it is, how to detect it (`promtool tsdb analyze`), how to fix it
- Series churn: what causes it (labels with high-entropy values like pod names), how to mitigate
- Memory usage: factors affecting Prometheus memory (series count, head block size, query concurrency)
- When to add Thanos or Grafana Mimir for long-term storage

#### A10. Security and Troubleshooting
- Prometheus authentication: `--web.config.file` for TLS and basic auth (Prometheus 2.24+)
- Missing targets debugging: check ServiceMonitor label selectors, check Service ports, check RBAC
- High cardinality debugging: `topk(10, count by(__name__)({__name__=~".+"}))` — finding offenders
- Slow queries debugging: query log, `--query.timeout`, Grafana query inspector
- Common errors: "context deadline exceeded", "no space left on device", "too many open files"
- RBAC: Prometheus needs ClusterRole to discover ServiceMonitors across namespaces

---

### SECTION B: Grafana

#### B1. CLI & API Reference
- `grafana-cli` commands: plugin install, plugin list, plugin update, admin reset-admin-password
- Grafana HTTP API v1 reference: endpoints for dashboards, data sources, users, orgs, folders, alerts
- How to create, read, update, delete dashboards via API (`/api/dashboards/db`, `/api/dashboards/uid/:uid`)
- How to provision data sources via API (`/api/datasources`)
- How to manage alert rules via API (`/api/v1/provisioning/alert-rules`)
- How to manage notification policies via API (`/api/v1/provisioning/policies`)
- API authentication: service account tokens vs basic auth vs API keys (deprecated)
- How to use `curl` one-liners for common Grafana API operations

#### B2. Deployment on K3s (kube-prometheus-stack)
- `kube-prometheus-stack` Helm chart: key values for Grafana sub-chart (`grafana.*`)
- How to set admin password via Kubernetes secret (not plain-text in values.yaml)
- Persistent volume configuration for Grafana data on K3s (local-path provisioner)
- Traefik IngressRoute CRD example for Grafana (with TLS, middleware for auth headers)
- Resource requests/limits appropriate for a 2-node cluster
- How to upgrade Grafana within kube-prometheus-stack without data loss
- Sidecar container pattern for dashboard and datasource provisioning (grafana-sc-dashboard)
- ConfigMap labeling conventions for automatic dashboard pickup by the sidecar

#### B3. Data Source Configuration
- Prometheus data source: URL (in-cluster service), scrape interval, exemplars, Loki derived fields
- Loki data source: URL, max lines, derived fields linking logs to Tempo traces
- PostgreSQL data source: CloudNativePG connection string, SSL mode, connection pooling, read-only user best practices
- Alertmanager data source: URL, how it enables alert list panels in dashboards
- Data source provisioning via YAML (`/etc/grafana/provisioning/datasources/`)
- How to store data source credentials in Kubernetes Secrets + reference in provisioning YAML
- Testing data source connectivity from within a K3s pod

#### B4. Dashboard Provisioning (GitOps)
- Dashboard JSON model structure: panels, targets, variables, annotations, templating
- How to export a dashboard as JSON from the UI
- Provisioning dashboards via ConfigMaps: label selector the sidecar watches
- Folder provisioning YAML to organize dashboards by category
- How to prevent UI edits from overriding provisioned dashboards (`editable: false` vs allow UI edits + git sync)
- Dashboard version control patterns: naming, UID management, avoid UID collisions
- Community dashboard import: Grafana.com dashboard IDs for K3s, node exporter, Loki, Postgres, Traefik, CrowdSec, Kyverno
- Grafana dashboard JSON schema reference (panel types, query targets, transformations)

#### B5. Dashboard Development
- Panel types: time series, stat, gauge, bar chart, table, logs, node graph, geomap, canvas — when to use each
- PromQL panel targets: instant vs range queries, legend formatting, min interval
- LogQL panel targets: log panels, metric panels from log queries
- Variables (template variables): data source, query, custom, constant, interval, ad-hoc filters
- Chained variables: using one variable's value to filter another's query
- Transformations: merge, join by field, filter by value, organize fields, calculate field, group by
- Overrides: per-field color, unit, threshold, display name
- Annotations: query annotations from Prometheus, manual annotations for events

#### B6. OIDC SSO with Zitadel
- Grafana `[auth.generic_oauth]` config block: full parameter reference
- Zitadel OIDC client setup for Grafana: client ID, secret, redirect URIs, scopes
- Role mapping from Zitadel groups/claims to Grafana roles (Viewer, Editor, Admin, GrafanaAdmin)
- How to disable basic auth after OIDC is working (and how to keep an emergency break-glass account)
- Auto-login vs login page with OIDC button
- How to provision the OIDC config via Kubernetes secret + Grafana values.yaml env vars
- Debugging OIDC login failures: Grafana logs, token inspection, Zitadel audit logs

#### B7. Public Dashboards (Status Page)
- How public dashboards work: what data is exposed, authentication bypass mechanics
- How to enable public dashboards in Grafana config (`public_dashboards_enabled`)
- Creating a public dashboard from an existing dashboard
- URL structure for public dashboards (unique token-based URL)
- Embedding public dashboards in helixstax.com status page via iframe
- Limitations of public dashboards: no variables, no drill-down, snapshot-like behavior
- How to design a status-page-style dashboard: service health panels, uptime stat panels, SLA gauges
- Custom domain for status page (status.helixstax.com pointing to the public dashboard URL)

#### B8. BI Dashboards (PostgreSQL)
- PostgreSQL data source query editor: raw SQL mode vs query builder
- Time series queries from PostgreSQL: `$__timeFilter()`, `$__interval`, time column requirements
- Table panel from PostgreSQL: column aliases, column types, pagination
- Business metrics examples: revenue, client count, ticket volume
- Mixing Prometheus and PostgreSQL panels on the same dashboard
- PostgreSQL connection pooling: using PgBouncer (CloudNativePG built-in) vs direct connection
- Read-only PostgreSQL user setup for Grafana (CloudNativePG `spec.managed.roles`)
- Alerting on PostgreSQL data: Grafana alerting rules with PostgreSQL queries

#### B9. Alerting (Grafana Alerting vs Prometheus Alerting)
- When to use Grafana alerting rules vs Prometheus alerting rules — decision framework
- Grafana unified alerting: alert rules, evaluation groups, contact points, notification policies, silences, mute timings
- How Grafana alert rules route through Alertmanager (Grafana can use its own Alertmanager OR external)
- Configuring Grafana to use the external Alertmanager (kube-prometheus-stack's Alertmanager)
- Contact points in Grafana: Rocket.Chat webhook config, SMTP (Postal) config, n8n webhook config
- Notification policy tree: routing by labels (severity, team, service)
- Dead man's switch / watchdog alert: how to configure it in Grafana alerting to email via Postal directly
- Alert rule state machine: Normal → Pending → Firing → OK
- Silences: creating via UI, API, and amtool

#### B10. Performance & Troubleshooting
- Retention and storage: Grafana's own SQLite vs PostgreSQL backend for production use
- Switching Grafana database from SQLite to PostgreSQL (CloudNativePG)
- Slow dashboard debugging: query inspector, query profiling, Explore for ad-hoc queries
- High memory dashboards: reducing panel count, increasing min interval, using recording rules
- Data source connectivity issues: timeout config, proxy settings, in-cluster DNS
- Provisioning errors: ConfigMap not picked up, YAML syntax errors, sidecar container logs
- Plugin issues: install from grafana-cli, air-gapped install for K3s, plugin compatibility
- Log locations in K3s pod: `kubectl logs -n monitoring deployment/prometheus-grafana`
- Common Grafana errors: "datasource not found", "plugin not found", "dashboard already exists"

---

### SECTION C: Alertmanager

#### C1. CLI Reference (amtool)
- Install amtool on AlmaLinux 9.7: binary download, path setup
- `amtool alert query` — list active alerts with filtering by label, state (active, suppressed, unprocessed)
- `amtool alert query --alertmanager.url` — targeting in-cluster Alertmanager
- `amtool silence add` — create a silence: duration, matchers, author, comment
- `amtool silence query` — list active silences
- `amtool silence expire <id>` — expire a silence early
- `amtool silence import / export` — bulk silence management (useful for maintenance windows)
- `amtool config routes test` — test that a given set of labels routes to the correct receiver
- `amtool config show` — dump current running config
- `amtool check-config <file>` — validate alertmanager.yml before applying
- Port-forward to Alertmanager in K3s: `kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring`
- Alertmanager HTTP API: `GET /api/v2/alerts`, `POST /api/v2/silences`, `GET /api/v2/status`

#### C2. Deployment on K3s (kube-prometheus-stack)
- Key `alertmanager.*` values in kube-prometheus-stack Helm chart
- AlertmanagerSpec: replicas (2 for HA), resource requests/limits, storage, retention
- Storage for Alertmanager: PVC for silences persistence (local-path provisioner)
- Configuration delivery: `alertmanager.config` in values.yaml vs separate Kubernetes Secret vs `AlertmanagerConfig` CRD — when to use each
- How to provide Alertmanager config as a Kubernetes Secret: secret name, key name, values.yaml reference
- Storing receiver credentials (Rocket.Chat webhook URL, Postal SMTP password) in Kubernetes Secrets and referencing via `secretKeyRef`
- Traefik IngressRoute for Alertmanager UI (restrict to internal access only)
- Upgrading Alertmanager within kube-prometheus-stack without losing silences

#### C3. Configuration: Routes, Receivers, and Grouping
- Top-level alertmanager.yml structure: `global`, `route`, `receivers`, `inhibit_rules`, `mute_time_intervals`
- Global defaults: `smtp_*`, `slack_api_url`, `resolve_timeout`
- Route tree: `receiver`, `group_by`, `group_wait`, `group_interval`, `repeat_interval`, `routes[]`
- `group_by`: what to group on — `[alertname, namespace, severity]`
- `group_wait`: how long to buffer before first notification (collect related alerts into one message)
- `group_interval`: how long to wait before resending same group if new alerts added
- `repeat_interval`: how long before re-alerting if still firing (don't spam — 4h for warning, 1h for critical)
- `continue` flag: when a route should continue matching child routes even after a match
- Matchers: new syntax `matchers: [severity="critical"]` vs old `match:` syntax
- How to route by `namespace`, `service`, `severity`, `team` labels
- Catch-all receiver: always define a default receiver so no alert is ever silently dropped

#### C4. Receiver Configurations
- **Rocket.Chat webhook receiver**:
  - Setting up incoming webhook in Rocket.Chat (steps, channel selection)
  - `webhook_configs` in alertmanager.yml: `url`, `send_resolved`, `http_config`
  - Custom message templating for Rocket.Chat (Rocket.Chat uses Markdown + attachment format)
  - Credential storage: Rocket.Chat webhook URL in Kubernetes Secret
- **Postal SMTP receiver**:
  - `email_configs`: `to`, `from`, `smarthost` (Postal SMTP endpoint), `auth_username`, `auth_password`, `require_tls`
  - Postal SMTP configuration: port (587 STARTTLS or 465 SSL), API key vs password auth
  - Email template: `html` and `text` body templates for alert emails
  - Credential storage: Postal SMTP password in Kubernetes Secret
- **n8n webhook receiver**:
  - `webhook_configs` targeting n8n webhook trigger URL
  - Payload structure that n8n receives (JSON body with alerts array)
  - Use cases: auto-create ClickUp tasks, run remediation workflows, log to database
  - Timeout and retry behavior for n8n webhooks
  - How n8n handles alert resolution events (`send_resolved: true`)
- **Dead man's switch receiver (Postal direct)**:
  - Separate email receiver that bypasses n8n for the Watchdog alert
  - Why: if n8n is down, the watchdog alert must still deliver
  - Config: dedicated `email_configs` receiver for watchdog, routed before other rules

#### C5. Notification Templates
- Template syntax: Go template language, `{{ }}` notation
- Built-in data: `.Alerts`, `.GroupLabels`, `.CommonLabels`, `.CommonAnnotations`, `.ExternalURL`
- Alert data fields: `.Status` (firing/resolved), `.Labels`, `.Annotations`, `.StartsAt`, `.EndsAt`, `.GeneratorURL`
- `range` iteration: looping over `.Alerts.Firing` and `.Alerts.Resolved`
- Template functions: `humanize`, `humanizeDuration`, `humanizePercentage`, `title`, `toUpper`, `toLower`
- How to define named templates in `templates:` section of alertmanager.yml
- Rocket.Chat template: compact single-line format with emoji severity indicators
- Email template: HTML email with alert table, severity color coding, links to Grafana dashboards
- Template file loading: `templates: ['/etc/alertmanager/templates/*.tmpl']`
- Testing templates: `amtool template render` or manual curl to webhook receiver

#### C6. Silences
- What silences are: temporary suppression of alerts matching label matchers, NOT a fix
- `amtool silence add` syntax: `--duration=2h --author="Wakeem" --comment="Scheduled maintenance" alertname=NodeDown`
- Regex silences: `alertname=~".*Disk.*"` — silence all disk alerts during storage migration
- Silence scope: silences affect ALL receivers (cannot silence per-receiver)
- `mute_time_intervals` config: day_of_week, times, months — cron-like schedule for recurring maintenance
- How to reference mute_time_intervals in routes: `active_time_intervals` / `mute_time_intervals` on route
- Bulk silence creation for multiple services: import via amtool

#### C7. Inhibition Rules
- What inhibition is: when alert A fires, suppress alert B (prevents alert storms)
- `inhibit_rules` structure: `source_matchers`, `target_matchers`, `equal` (labels that must match)
- Essential inhibition rules for K3s:
  - NodeDown inhibits all pod/service alerts on that node
  - KubernetesMasterDown inhibits all workload alerts
  - WatchdogDead inhibits everything (if Alertmanager itself is down, no point alerting)
- How `equal` works: both source and target alert must share the same value for these labels
- Anti-patterns: over-inhibiting (hiding real problems), under-inhibiting (alert storms)
- Inhibition vs silences: inhibition is automatic logic, silences are manual/scheduled

#### C8. High Availability (2-Node Alertmanager Cluster)
- Alertmanager HA: gossip-based mesh using `--cluster.*` flags
- kube-prometheus-stack HA setup: `alertmanager.alertmanagerSpec.replicas: 2`
- How deduplication works in HA: each instance evaluates independently, gossip ensures only one sends
- `--cluster.peer` flag: how instances discover each other (headless service DNS)
- `--cluster.settle-timeout`: how long to wait at startup before sending alerts
- Behavior when one node goes down: the remaining instance takes over with no notification gap
- Load balancing: Prometheus sends to all Alertmanager instances; Alertmanager deduplicates
- Testing HA: kill one Alertmanager pod, verify alerts still route correctly

#### C9. Grafana Alerting Integration
- Two alerting systems: Grafana unified alerting AND Prometheus alerting — both route to Alertmanager
- Configuring Grafana to use external Alertmanager: `unifiedAlerting.alertmanagerConfigNamespaces`
- How Grafana sends alerts to Alertmanager: Grafana acts as a "Prometheus-compatible" source
- Labels from Grafana alerts vs Prometheus alerts: how to unify label naming
- Recommended architecture: use Alertmanager as the single routing layer; configure Grafana to NOT use its own contact points
- Silences: creating silences from Grafana UI (it proxies to Alertmanager silences API)

#### C10. Dead Man's Switch and Troubleshooting
- Dead man's switch / Watchdog alert: Prometheus always-firing alert → Alertmanager → Grafana → Postal
- How to implement: PrometheusRule with `expr: vector(1)`, `for: 0m`, severity: watchdog
- Why it matters: if Prometheus or Alertmanager dies, the Watchdog stops firing, and you get an absence-of-alert alert
- Alert not firing: check Prometheus `/alerts` page, check Alertmanager `/api/v2/alerts`, check receiver logs
- Wrong receiver: use `amtool config routes test --verify-receivers` to trace routing
- Duplicate notifications: check `group_interval` and `repeat_interval` settings, check HA deduplication
- Missing resolved notifications: `send_resolved: true` must be set on each receiver config
- Alertmanager pod OOMKilled: check `--storage.path` PVC size, check retention (default 120h)
- Rocket.Chat webhook failures: 4xx vs 5xx, payload format issues, auth token expiry
- Postal SMTP failures: TLS handshake errors, auth failures, relay denied errors
- Common errors: "Error on notify", "context deadline exceeded", "connection refused to receiver"

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

```markdown
# Prometheus

## Overview
[2-3 sentence description of what Prometheus does and why we use it]

## CLI Reference (promtool)
### Config Validation
[Commands with examples]
### Rule Validation & Testing
[Commands with examples]
### HTTP API via curl
[Query, reload, health check examples]

## Deployment on K3s
### kube-prometheus-stack Values
[Key Helm values for prometheus.* sub-chart]
### PrometheusSpec
[Storage, retention, resources YAML]
### Traefik IngressRoute
[CRD YAML for Prometheus UI]
### Upgrade Procedure
[Steps to upgrade without data loss]

## Prometheus Operator CRDs
### ServiceMonitor
[Full spec example]
### PodMonitor
[Full spec example]
### PrometheusRule
[Full spec example]
### Label Selector Gotchas
[How the operator discovers CRDs]

## ServiceMonitor Examples (All Services)
### Traefik
[ServiceMonitor YAML]
### CloudNativePG
[ServiceMonitor YAML]
### Valkey
[ServiceMonitor YAML]
### MinIO
[ServiceMonitor YAML]
### Harbor
[ServiceMonitor YAML]
### ArgoCD
[ServiceMonitor YAML]
### Loki
[ServiceMonitor YAML]
### CrowdSec
[ServiceMonitor YAML]
### Kyverno
[ServiceMonitor YAML]
### Node Exporter
[Key metrics, textfile collector]

## PromQL Reference
### Node & Pod Queries
[Essential queries with examples]
### Service Queries
[Traefik, PostgreSQL, Loki]
### Aggregation Patterns
[rate, histogram_quantile, topk]

## Recording Rules
### Naming Convention
[level:metric:operations pattern]
### Essential Recording Rules
[CPU, latency, request rate examples]

## Alerting Rules
### Rule Structure
[alert, expr, for, labels, annotations]
### Essential Cluster Alerts
[NodeDown, CrashLooping, DiskFull]
### Essential Service Alerts
[Traefik, PostgreSQL, Loki]
### Watchdog Alert
[Dead man's switch config]
### Alert Testing
[promtool test rules YAML format]

## Storage & Performance
### Retention Configuration
[Time and size flags]
### Cardinality Debugging
[tsdb analyze, offender queries]
### Memory Sizing
[For 2-node cluster with 20+ targets]

## Security & Troubleshooting
### Authentication
[web.config.file TLS + basic auth]
### Missing Targets
[Debugging ServiceMonitor pickup]
### Common Errors
[Error messages and fixes]
### RBAC
[ClusterRole requirements]

---

# Grafana

## Overview
[2-3 sentence description of what Grafana does and why we use it]

## CLI & API Reference
### grafana-cli
[Commands with examples]
### HTTP API
[Endpoint examples with curl]

## Deployment on K3s
### kube-prometheus-stack Values
[Key Helm values with examples]
### Traefik IngressRoute
[CRD YAML example]
### Persistent Storage
[PVC config for local-path]

## Data Sources
### Prometheus
[Provisioning YAML]
### Loki
[Provisioning YAML]
### PostgreSQL (CloudNativePG)
[Provisioning YAML + credentials via Secret]
### Alertmanager
[Provisioning YAML]

## Dashboard Provisioning
### ConfigMap Pattern
[Label selectors, folder provisioning]
### Recommended Community Dashboards
[Dashboard IDs and what they cover]

## Dashboard Development
### Panel Types
[When to use each type]
### Variables
[Query variables, chained variables]
### Transformations
[Common transformation patterns]

## Zitadel OIDC Integration
### Zitadel Client Setup
[Steps]
### Grafana Config
[grafana.ini / values.yaml blocks]
### Role Mapping
[Claims to Grafana roles]

## Public Dashboards (Status Page)
### Setup
[Enable, create, URL]
### Status Page Design
[Panel recommendations]
### Embedding
[iframe for helixstax.com]

## BI Dashboards (PostgreSQL)
### Query Patterns
[Time series, table examples]
### CloudNativePG Read-Only User
[spec.managed.roles YAML]

## Alerting
### Grafana vs Prometheus Rules (Decision Framework)
[When to use which]
### External Alertmanager Configuration
[Route all Grafana alerts through Alertmanager]
### Contact Points
[Rocket.Chat, Postal, n8n configs]
### Notification Policy
[Routing tree example]
### Dead Man's Switch
[Watchdog alert → Postal config]

## Performance & Troubleshooting
### Slow Dashboards
[Debugging steps]
### Data Source Issues
[Connectivity debugging]
### Provisioning Issues
[ConfigMap not picked up, sidecar logs]
### Common Errors
[Error messages and fixes]

---

# Alertmanager

## Overview
[2-3 sentence description of what Alertmanager does and why we use it]

## CLI Reference (amtool)
### Installation on AlmaLinux 9.7
[Binary download commands]
### Alert Management
[amtool alert query, filter examples]
### Silence Management
[amtool silence add, query, expire with examples]
### Config Validation & Testing
[amtool check-config, routes test]
### HTTP API via curl
[/api/v2/alerts, /api/v2/silences examples]

## Deployment on K3s
### kube-prometheus-stack Values
[Key Helm values for alertmanager.* sub-chart]
### AlertmanagerSpec
[Replicas, storage, retention YAML]
### Config Delivery Options
[values.yaml vs Secret vs AlertmanagerConfig CRD]
### Credential Storage
[Secrets for Rocket.Chat, Postal, n8n]
### Traefik IngressRoute
[CRD YAML restricted to internal]

## Configuration Reference
### Route Tree
[Full route example with severity routing]
### Grouping Strategy
[group_by, group_wait, group_interval, repeat_interval]
### Catch-All Receiver
[Default receiver config]

## Receiver Configurations
### Rocket.Chat Webhook
[Full webhook_configs YAML]
### Postal SMTP
[Full email_configs YAML]
### n8n Webhook
[Full webhook_configs YAML + payload structure]
### Dead Man's Switch (Postal Direct)
[Separate email receiver for Watchdog]

## Notification Templates
### Template Syntax
[Go template reference]
### Rocket.Chat Template
[Compact format with emoji severity]
### Email Template
[HTML table format]
### Template Testing
[How to test without firing real alerts]

## Silences
### Creating Silences
[amtool examples, regex silences]
### Mute Time Intervals
[Recurring maintenance window config]
### Maintenance Window Procedure
[Steps for planned downtime]

## Inhibition Rules
### Essential Rules
[NodeDown → pod alerts, complete examples]
### Equal Label Requirement
[How equal works, gotchas]

## High Availability
### 2-Node Cluster Config
[replicas: 2, gossip setup in kube-prometheus-stack]
### Deduplication Behavior
[How gossip prevents duplicate notifications]
### Testing HA
[Kill one pod, verify continuity]

## Grafana Integration
### External Alertmanager Config
[Grafana config to route to our Alertmanager]
### Unified Label Naming
[Aligning Grafana and Prometheus alert labels]
### Recommended Architecture
[Single routing layer decision]

## Dead Man's Switch
### Watchdog Alert Config
[PrometheusRule YAML: vector(1), for: 0m]
### Alertmanager Route for Watchdog
[Route to direct Postal receiver]
### Full Dead Man's Switch Flow
[Prometheus → Alertmanager → Grafana → Postal]

## Troubleshooting
### Alert Not Firing
[Prometheus /alerts, Alertmanager /api/v2/alerts debugging]
### Wrong Receiver
[amtool routes test --verify-receivers]
### Duplicate Notifications
[group_interval, repeat_interval, HA dedup]
### Receiver Failures
[Rocket.Chat, Postal, n8n error patterns]
### Common Errors
[Error messages and fixes]
```

Be thorough, opinionated, and practical. Include actual PromQL queries, actual ServiceMonitor YAML, actual PrometheusRule YAML, actual alertmanager.yml snippets, actual amtool commands, actual notification templates, actual Grafana provisioning YAML, and actual curl examples. Do NOT give me theory — give me copy-paste-ready configs for Prometheus + Grafana + Alertmanager running on K3s via kube-prometheus-stack on AlmaLinux 9.7 Hetzner Cloud, routing to Rocket.Chat + Postal + n8n.
