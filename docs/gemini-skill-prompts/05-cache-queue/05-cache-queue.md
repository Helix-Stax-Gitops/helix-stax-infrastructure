# Gemini Deep Research: Cache & Queue

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What Valkey Is
Valkey is a Redis-compatible, BSD-licensed key-value store forked from Redis 7.2.4 by the Linux Foundation after Redis changed to SSPL. It is our replacement for Redis across the entire Helix Stax platform. We use it for session caching, queue backends, and application caching.

Note: This prompt currently covers Valkey only. Future additions to this group may include NATS (lightweight pub/sub, JetStream for durable messaging) or RabbitMQ (if workloads outgrow BullMQ's Redis-backed queuing) — those would be added here as additional sections when the need arises.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, 2 nodes (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Deployment**: Helm chart on K3s as a StatefulSet
- **Services depending on Valkey**: n8n (queue mode / BullMQ), Postal (queue backend), application-level caching for any stateful service
- **TLS**: cert-manager for in-cluster TLS
- **Monitoring**: Prometheus + Grafana + Loki already deployed
- **Backup**: Velero for PVC snapshots, RDB/AOF for Valkey-native persistence
- **Network**: All inter-service communication within K3s cluster; no public exposure

## What I Need Researched

### 1. CLI Reference (valkey-cli)
- Full `valkey-cli` command reference for day-to-day operations
- Connecting: `valkey-cli -h <host> -p <port> -a <password>` and TLS variant (`--tls --cacert`)
- AUTH command and ACL-based auth (`AUTH <username> <password>`)
- `INFO` command sections: `server`, `clients`, `memory`, `stats`, `replication`, `keyspace`, `persistence` — what each field means
- `MONITOR` command — real-time command stream, how to use for debugging without leaving it running
- `SLOWLOG GET`, `SLOWLOG LEN`, `SLOWLOG RESET` — diagnosing slow queries
- `CLIENT LIST`, `CLIENT KILL` — managing connections
- `DEBUG SLEEP`, `DEBUG RELOAD` — testing and forcing operations
- `SCAN` vs `KEYS *` — why never use KEYS in production, SCAN pattern with cursor
- `MEMORY USAGE <key>`, `MEMORY DOCTOR` — diagnosing memory issues
- `OBJECT ENCODING`, `OBJECT IDLETIME`, `OBJECT FREQ` — key inspection
- `CONFIG GET`, `CONFIG SET`, `CONFIG REWRITE` — runtime config management
- Pub/Sub: `SUBSCRIBE`, `PUBLISH`, `PSUBSCRIBE` — use in n8n context
- `XADD`, `XREAD`, `XGROUP` — Streams API (relevant for BullMQ in n8n)
- `valkey-cli --pipe` — bulk loading data

### 2. Deployment on K3s via Helm
- Which Helm chart to use: Bitnami valkey chart vs community alternatives — recommendation with chart name and repo
- Complete `values.yaml` for a production-ready single-instance + Sentinel setup on 2 nodes
- `architecture: standalone` vs `architecture: replication` — which for 2-node K3s cluster
- StatefulSet configuration: `persistence.enabled`, `persistence.size`, `persistence.storageClass` (Hetzner CSI)
- Resource requests and limits: starting values for a shared K3s node with other workloads
- `podAntiAffinity` to spread Valkey pods across nodes
- `nodeSelector` and `tolerations` for K3s control plane taint
- `serviceAccount` creation and RBAC
- Headless service for StatefulSet DNS — how n8n and Postal connect
- `extraVolumes` and `extraVolumeMounts` for custom config
- Upgrading the Helm chart — rolling update behavior for StatefulSet

### 3. Configuration: maxmemory, Eviction, and Persistence
- `maxmemory` — how to calculate a safe limit when Valkey shares a node with other services
- `maxmemory-policy` options: `noeviction`, `allkeys-lru`, `volatile-lru`, `allkeys-lfu`, `volatile-lfu`, `allkeys-random`, `volatile-random`, `volatile-ttl` — which policy for each use case (n8n queue vs session cache vs application cache)
- `maxmemory-samples` — tuning LRU/LFU approximation accuracy
- RDB persistence: `save` directives — recommended schedule for a queue backend
- AOF persistence: `appendonly yes`, `appendfsync` options (`always`, `everysec`, `no`) — trade-offs for our use cases
- `aof-use-rdb-preamble yes` — hybrid persistence, why it's the default and best practice
- `no-appendfsync-on-rewrite yes` — preventing AOF rewrite from blocking writes
- `auto-aof-rewrite-percentage` and `auto-aof-rewrite-min-size` — controlling AOF bloat
- `lazyfree-lazy-eviction`, `lazyfree-lazy-expire`, `lazyfree-lazy-server-del` — async deletion tuning
- `activedefrag yes` — active memory defragmentation — when to enable on a small node
- `hz` — event loop frequency, default 10, when to increase to 100

### 4. Use Cases: n8n, Postal, and Application Caching
- **n8n queue mode**: n8n uses BullMQ which requires Redis/Valkey. What Valkey config does BullMQ need? (`RESP3` support, `notify-keyspace-events`, Streams support). Full connection config in n8n environment variables.
- **Postal queue backend**: Postal uses Redis for job queues (Sidekiq). What Valkey config does Sidekiq need? Connection string format for Postal config.
- **Application caching**: generic TTL-based caching — recommended maxmemory-policy, key naming conventions, TTL strategy
- Database numbers: using separate Redis DB numbers (0-15) per service vs single DB with key prefixes — recommendation for isolation
- Connection limits per use case: how many connections n8n workers open, how many Postal Sidekiq workers open
- Key expiration patterns: volatile keys for sessions vs persistent keys for queue state
- Pipeline and MULTI/EXEC transaction usage in BullMQ — what Valkey must support

### 5. Sentinel vs Cluster Mode for 2-Node K3s
- Redis/Valkey Sentinel architecture — how it works, what the quorum requirement is, why 3 sentinels are the minimum
- Valkey Cluster mode — hash slots, minimum 3 primaries requirement, not suitable for 2 nodes
- Standalone with Velero snapshot backup — the pragmatic choice for 2 nodes, trade-offs
- If using Sentinel: running sentinel as a sidecar or separate pod, quorum with 2 nodes (NOT supported — explain why)
- Recommended architecture for our 2-node cluster: standalone primary with AOF+RDB, Velero PVC snapshot, and runbook for manual restore
- What application clients (n8n, Postal) need to support for Sentinel client-side — `ioredis` sentinel config
- Future path: when/if to move to Sentinel (add a 3rd node), migration steps

### 6. Security: Passwords, ACLs, TLS, Network Policies
- `requirepass` — setting a password, where to store it (Kubernetes Secret), how to reference in Helm values
- ACL system: `ACL SETUSER`, `ACL LIST`, `ACL WHOAMI`, `ACL CAT`, `ACL LOG`
- Creating per-service ACL users: n8n-user (full access to DB 0), postal-user (full access to DB 1), read-only monitoring user
- ACL file: externalizing ACLs to a mounted config file vs inline `aclfile` directive
- TLS configuration: `tls-port`, `tls-cert-file`, `tls-key-file`, `tls-ca-cert-file` — integrating with cert-manager issued certs
- `tls-replication yes` — encrypting replica traffic (for Sentinel setup)
- Kubernetes NetworkPolicy — example restricting Valkey pod ingress to only n8n, Postal, and Prometheus exporter pods
- Disabling dangerous commands: `rename-command FLUSHALL ""`, `rename-command DEBUG ""`, `rename-command CONFIG ""` — what to disable in production
- `protected-mode yes` — what it does, when it matters in K3s pod network

### 7. Monitoring: Prometheus Exporter and Grafana
- `redis_exporter` (oliver006/redis_exporter) — confirmed Valkey compatible, Helm chart or sidecar deployment
- Prometheus scrape config or ServiceMonitor CRD for the exporter
- Key metrics to alert on:
  - `redis_memory_used_bytes` vs `redis_maxmemory_bytes` — memory pressure
  - `redis_keyspace_hits_total` vs `redis_keyspace_misses_total` — cache hit rate
  - `redis_connected_clients` — connection count
  - `redis_blocked_clients` — blocking command count (BLPOP, BRPOP, XREAD)
  - `redis_evicted_keys_total` — eviction rate (alert if non-zero for queue workloads)
  - `redis_rdb_last_save_time` — last successful RDB save
  - `redis_aof_last_rewrite_duration_sec` — AOF rewrite duration
  - `redis_replication_offset` — replication lag (if Sentinel)
- Grafana dashboard for Valkey — which community dashboard ID to import
- Loki log queries for Valkey pod logs — detecting OOM, slow commands, connection resets
- Alertmanager rules: memory > 80%, evictions on queue DB, RDB save failure

### 8. Backup and Restore
- RDB snapshot location in the container: `/data/dump.rdb` — how to verify it's current
- AOF file location: `/data/appendonly.aof` — how to check for corruption (`redis-check-aof`)
- `BGSAVE` — triggering a manual RDB save, checking with `LASTSAVE` and `DEBUG SLEEP`
- `BGREWRITEAOF` — forcing AOF compaction
- Velero PVC snapshot workflow for Valkey: annotating the StatefulSet PVC for backup, verifying snapshot
- Restore procedure from Velero snapshot — step-by-step
- Restore procedure from RDB file — copying dump.rdb into a new pod's PVC
- Testing restore without affecting production — spin up a separate Valkey pod from backup
- Backup frequency recommendation: RDB every 15 minutes + AOF + nightly Velero PVC snapshot

### 9. Migration from Redis: Compatibility and Differences
- Valkey 7.2 vs Redis 7.2 — what is guaranteed to be compatible (commands, protocol, data structures)
- RESP3 protocol support in Valkey — client library compatibility
- Known breaking changes or divergences since the fork (as of 2024-2025)
- Valkey 8.x features not in Redis — what's new, what our clients need to support
- Client library compatibility: `ioredis` (used by n8n/BullMQ), `redis` gem (used by Postal/Sidekiq) — confirmed working with Valkey?
- `redis://` vs `valkey://` connection string schemes — what client libraries accept
- Checking if existing Redis data can be migrated: RDB file format compatibility between Redis 7.x and Valkey 7.x
- `redis-cli` vs `valkey-cli` — are they interchangeable for scripting? Which to use in K8s exec commands?

### 10. Performance: Connection Pooling, Pipelining, Memory
- Connection pooling: Valkey itself doesn't pool — connection pooling is client-side
- `ioredis` connection pool config for n8n: `maxRetriesPerRequest`, connection timeout, retry strategy
- Pipelining: how BullMQ uses pipelining, what Valkey behavior to expect
- `tcp-keepalive 300` — preventing stale connections from Kubernetes pod restarts
- `tcp-backlog 511` — when to increase for high connection burst
- `timeout 0` — client idle timeout, recommended value for long-running queue workers
- Memory optimization: `hash-max-listpack-entries`, `list-max-listpack-size`, `set-max-intset-entries` — ziplist-style compact encoding thresholds
- `latency-tracking yes` and `latency-history` — built-in latency monitoring
- `jemalloc` vs `libc` allocator — Valkey uses jemalloc by default, why this matters for fragmentation
- Key expiration overhead — how many volatile keys are safe on a small node, `active-expire-effort` tuning

### 11. Troubleshooting: Memory, Slow Queries, Connections
- `OOM command not allowed` — what triggers it, immediate fix (`CONFIG SET maxmemory-policy allkeys-lru` or increase `maxmemory`)
- Memory fragmentation ratio > 1.5 — diagnosis (`INFO memory`: `mem_fragmentation_ratio`), fix options (restart vs activedefrag)
- Slow queries: `SLOWLOG GET 25` — interpreting output, common culprits (KEYS *, unindexed SCAN, large SMEMBERS)
- `LOADING` state — Valkey reloading RDB on startup, what to do while it loads
- AOF corruption: `redis-check-aof --fix appendonly.aof` — procedure
- RDB corruption: `redis-check-rdb dump.rdb` — procedure
- Connection refused: pod not ready, port mismatch, TLS misconfiguration — debugging checklist
- `READONLY` errors — connecting to a replica when writes are attempted, solution
- `MISCONF` errors — persistence config issues, common on K3s with restricted security contexts
- `ERR max number of clients reached` — finding the culprit (`CLIENT LIST`), fix
- Pod OOMKilled — `maxmemory` not set or set too high relative to container `limits.memory`
- Velero backup failing on Valkey PVC — annotation requirements, fsfreeze considerations

### 12. Integration with n8n, Postal, and Apps
- **n8n**: Environment variables for Valkey connection in queue mode — `QUEUE_BULL_REDIS_HOST`, `QUEUE_BULL_REDIS_PORT`, `QUEUE_BULL_REDIS_PASSWORD`, `QUEUE_BULL_REDIS_DB`, TLS env vars
- **n8n**: BullMQ requires Valkey >= 7.2 (Streams + XAUTOCLAIM) — confirm Valkey compatibility
- **Postal**: `config/postal.yml` Redis section — `host`, `port`, `password`, `database` fields
- **Postal**: Sidekiq connection pool sizing — how many threads, how many Valkey connections
- **Generic application caching**: recommended client library per language (Node.js: ioredis, Python: redis-py, Go: go-redis) — all confirmed Valkey-compatible
- Kubernetes Service DNS name for Valkey: `valkey-master.valkey.svc.cluster.local` (Bitnami chart default) — confirm naming
- Liveness and readiness probe config for Valkey pod: `valkey-cli ping` command, timing parameters
- Secret management: storing Valkey password in Kubernetes Secret, referencing via `secretKeyRef` in pod env

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

The following is the legacy output structure for reference — the progressive disclosure format above supersedes it:

```markdown

```markdown
# Valkey

## Overview
[2-3 sentence description of what Valkey is and why we use it over Redis]

## CLI Reference (valkey-cli)
### Connection and Auth
[Commands with examples]
### Inspection and Debugging
[INFO, MONITOR, SLOWLOG, CLIENT LIST examples]
### Key Operations
[SCAN, MEMORY USAGE, CONFIG GET/SET examples]
### Streams (BullMQ)
[XADD, XREAD, XGROUP examples]

## Deployment on K3s (Helm)
### Helm Chart and values.yaml
[Annotated values.yaml for production standalone deployment]
### StatefulSet Considerations
[Anti-affinity, storage class, resource limits]

## Configuration Reference
### maxmemory and Eviction Policies
[Policy selection table per use case]
### Persistence: RDB + AOF
[Recommended settings with rationale]
### Runtime Config Changes
[CONFIG SET examples without restart]

## Use Cases
### n8n (BullMQ Queue Mode)
[Environment variables, connection config, required Valkey features]
### Postal (Sidekiq Queue Backend)
[Connection config, pool sizing]
### Application Caching
[maxmemory-policy, TTL strategy, DB separation]

## Sentinel vs Standalone (2-Node Decision)
[Why standalone is correct for 2 nodes, trade-offs, future migration path]

## Security
### Password and ACL Setup
[requirepass, ACL SETUSER examples per service]
### TLS Configuration
[tls-port, cert-manager integration]
### Network Policies
[Example Kubernetes NetworkPolicy YAML]
### Dangerous Command Disablement
[rename-command examples]

## Monitoring
### Prometheus Exporter
[Deployment config, ServiceMonitor CRD]
### Key Metrics Reference
[Table: metric -> meaning -> alert threshold]
### Grafana Dashboard
[Dashboard ID and import instructions]
### Loki Queries
[Useful LogQL patterns for Valkey logs]

## Backup and Restore
### RDB and AOF Backup
[BGSAVE, BGREWRITEAOF, file locations]
### Velero PVC Snapshot
[Annotation requirements, verify procedure]
### Restore Procedures
[From RDB file, from Velero snapshot — step by step]

## Migration from Redis
### Compatibility Guarantees
[What's safe, what to verify]
### Client Library Status
[ioredis, redis gem — confirmed compatibility]
### Connection String Differences
[redis:// vs valkey://, what clients accept]

## Performance
### Connection and Timeout Tuning
[tcp-keepalive, timeout, tcp-backlog values]
### Memory Compact Encoding
[listpack/intset thresholds]
### Pipelining and BullMQ
[What to expect, how to verify]

## Troubleshooting
### Diagnostic Checklist
[kubectl commands, valkey-cli commands]
### Common Errors
[Error message -> cause -> fix table]
### Memory Issues
[OOM, fragmentation, eviction — diagnosis and fix]
### Persistence Recovery
[AOF fix, RDB check commands]

## Service Integration Reference
### Kubernetes DNS Names
[Service FQDNs for each environment]
### Environment Variable Reference
[Per-service env var table]
### Liveness and Readiness Probes
[Probe YAML for Valkey pod]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual Helm values, actual Kubernetes YAML, and actual error messages with fixes. Do NOT give me theory — give me copy-paste-ready configs for a 2-node K3s cluster on Hetzner. Explicitly call out which configuration applies to which dependent service (n8n, Postal) wherever relevant.
