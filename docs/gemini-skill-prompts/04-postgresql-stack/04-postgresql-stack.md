# Gemini Deep Research: PostgreSQL Stack (Grouped Prompt)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
The complete PostgreSQL stack — operator (K8s), DBA (database internals), and vector search (AI). This group covers three tightly-coupled layers that agents must understand together:

1. **CloudNativePG** — the Kubernetes operator that provisions, manages, and backs up PostgreSQL clusters on K3s. Everything about the cluster CRD, Pooler CRD, ScheduledBackup CRD, and kubectl plugin.
2. **PostgreSQL DBA + SQL Patterns** — what happens INSIDE the database: psql CLI mastery, query performance, indexing, VACUUM, partitioning, replication monitoring, zero-downtime migrations, JSON/JSONB, CTEs, window functions, and batch operations.
3. **pgvector** — vector storage, indexing, distance functions, hybrid search, and Ollama embedding integration for the Helix Stax RAG pipeline. Also: Research RuVector (github.com/ruvnet/ruvector) as a potential pgvector replacement — compare performance, maturity, CloudNativePG compatibility.

These three are grouped because agents frequently need to cross-reference them: tuning `postgresql.parameters` in the CRD while understanding `work_mem` semantics; creating HNSW indexes while knowing the operator's image requirements; running migrations while knowing which connection hits PgBouncer vs the primary directly.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, 2 nodes (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Operator**: CloudNativePG installed via Helm
- **Storage**: Hetzner Cloud persistent volumes (CSI driver)
- **Backup target**: MinIO (S3-compatible) running on K3s, ultimately synced to Backblaze B2
- **TLS**: cert-manager issues certificates; all client connections encrypted
- **Services depending on PostgreSQL**: Zitadel, n8n, Backstage, Outline, Devtron, Harbor, Grafana
- **Connection pooling**: PgBouncer via CloudNativePG's Pooler CRD
- **Monitoring**: Prometheus + Grafana + Loki stack already deployed
- **AI stack**: Ollama (local LLM inference) + Open WebUI + pgvector for RAG and embeddings
- **Access pattern**: Agents connect via psql CLI or application connection strings; no pgAdmin

---

## What I Need Researched

---

# SECTION 1: CloudNativePG (Operator + K8s Layer)

### 1. Cluster CRD Reference
- Complete `Cluster` CRD spec — every field that matters for a small production cluster
- How to set `instances`, `primaryUpdateStrategy`, `primaryUpdateMethod`
- How to configure `postgresql.parameters` inline in the CRD (shared_buffers, work_mem, max_connections, etc.)
- `nodeAffinity` and `podAntiAffinity` rules so primary and replicas land on different nodes
- `topologySpreadConstraints` for a 2-node cluster — what makes sense
- `bootstrap` section: `initdb` (new cluster) vs `recovery` (restore from backup) — both variants with full examples
- `superuserSecret` and `enableSuperuserAccess` — how operator manages postgres superuser
- `inheritedMetadata` for labels and annotations
- How `minSyncReplicas` and `maxSyncReplicas` affect durability vs availability trade-off on 2 nodes
- `walStorage` as a separate PVC — when and why to use it
- `storage.size` and `storage.storageClass` — how to specify Hetzner's CSI storage class

### 2. Database and User Management
- How to create application databases per service (Zitadel DB, n8n DB, Backstage DB, Outline DB, Devtron DB, Harbor DB, Grafana DB) — using `managed.databases` and `managed.roles` in the CRD
- How `managed.roles` works — creating roles with login, password secrets, privileges
- Granting `CREATE` privileges on specific databases to specific roles
- How to reference Kubernetes secrets for role passwords
- Running `psql` inside the operator pod vs using `kubectl exec` on the Postgres pod
- `kubectl cnpg` plugin — installation and command reference (status, promote, backup, reload, restart, maintenance)
- How to create read-only replicas accessible to monitoring/reporting users
- Schema separation within a single database vs separate databases per service — recommendation for our scale

### 3. Connection Pooling with PgBouncer
- The `Pooler` CRD — full spec with examples
- `poolMode`: transaction vs session vs statement — which mode for each service type (Zitadel, n8n, Harbor)
- How `Pooler` references the parent `Cluster`
- PgBouncer `pgbouncer.ini` parameters tunable via CRD (`maxClientConn`, `defaultPoolSize`, `reservePoolSize`)
- How application services connect to Pooler service vs direct Cluster service (read-write vs read-only)
- PgBouncer metrics and monitoring
- Connection limits per database per user — preventing one service from starving others
- `authQuerySecret` — how PgBouncer authenticates users

### 4. Backup: Continuous Archiving to MinIO
- Full `backup` section in Cluster CRD for S3/MinIO: `endpointURL`, `destinationPath`, `s3Credentials`, `wal.compression`, `wal.encryption`
- How WAL archiving works — what `archive_command` does under the hood, what CloudNativePG manages automatically
- `ScheduledBackup` CRD — full spec, cron syntax, `backupOwnerReference`, `immediate`
- How to reference MinIO credentials as Kubernetes secrets in the Cluster spec
- Base backup vs WAL-only backup — storage implications
- Backup retention: `retentionPolicy` field — how to configure, what happens when old backups are pruned
- How to verify a backup was successful — `kubectl cnpg backup` status, MinIO bucket contents check
- `barman-cloud-backup-list` — checking backup catalog from inside the pod
- TLS for MinIO connections from the backup process

### 5. Recovery: PITR and Cluster Cloning
- Recovery bootstrap full example — `cluster.spec.bootstrap.recovery.source`, `recoveryTarget.targetTime`
- `externalClusters` spec — how to point at a MinIO backup for recovery
- Point-in-time recovery (PITR) — `targetTime`, `targetXID`, `targetName`, `targetLSN` — syntax and use cases
- Full cluster restore workflow: step-by-step from MinIO backup to running cluster
- Cloning a cluster from another cluster (for staging environments): `bootstrap.recovery` with live source
- How long PITR takes — what to monitor, how to estimate recovery time
- Testing your backup without replacing production — parallel cluster restore approach
- `kubectl cnpg backup` vs `ScheduledBackup` for ad-hoc pre-upgrade snapshots

### 6. High Availability: Failover and Switchover
- Automatic failover — how CloudNativePG detects primary failure, elects new primary, updates service endpoints
- `switchover` — graceful promotion (`kubectl cnpg promote`) — when and how to use
- Fencing — what it is, when operator uses it, how to manually fence/unfence a node
- `primaryUpdateStrategy: unsupervised` vs `supervised` — implications for rolling updates
- How Kubernetes services (`-rw`, `-r`, `-ro`) route to primary vs replicas automatically
- What happens to in-flight transactions during failover — application connection retry expectations
- `minAvailable` and pod disruption budgets — does CloudNativePG create these automatically?
- On a 2-node cluster: primary + 1 replica — what quorum/failover behavior to expect
- Monitoring failover events in Grafana/Loki — what log lines and metrics to watch

### 7. Monitoring: Prometheus and Grafana
- CloudNativePG's built-in metrics endpoint — what it exposes by default
- `monitoring.enablePodMonitor: true` — how to enable PodMonitor for Prometheus Operator scraping
- Key metrics to alert on: replication lag, WAL archive delay, connection count, transaction rate, tuple counts, cache hit ratio
- `pg_stat_statements` — how to enable via `postgresql.parameters` in the CRD, what queries it exposes
- Official CloudNativePG Grafana dashboard — where to find it, how to import, what panels it has
- Custom Prometheus rules for CloudNativePG — alerting on failover, backup failures, replication lag > threshold
- Loki log queries for CloudNativePG pod logs — useful LogQL patterns for errors, slow queries, failover events
- `shared_preload_libraries` — which extensions to load (pg_stat_statements, pgaudit, etc.)

### 8. Storage: Hetzner CSI and Volume Management
- Hetzner Cloud CSI driver — which StorageClass to use, `hcloud-volumes` provisioner details
- `ReclaimPolicy: Retain` vs `Delete` — which is safer for database PVCs, how to configure
- Volume expansion — `allowVolumeExpansion: true` on StorageClass, how to resize a CloudNativePG PVC without downtime
- `walStorage` as a separate PVC — sizing recommendations relative to `storage`
- Performance characteristics of Hetzner volumes — IOPS limits, throughput limits, what that means for PostgreSQL workloads
- Persistent volume access modes for CloudNativePG — `ReadWriteOnce` implications in K3s on 2 nodes
- How CloudNativePG handles PVC deletion on cluster scale-down — orphaned volumes risk

### 9. Major and Minor Version Upgrades
- Minor version upgrades (e.g., 16.1 → 16.3) — rolling update process, zero-downtime procedure
- Major version upgrades (e.g., 15 → 16) — `pg_upgrade` approach via cluster clone or in-place
- `imageName` field in Cluster CRD — how to pin and update the PostgreSQL version
- CloudNativePG operator upgrades — Helm upgrade process, CRD migration gotchas
- How to test a major upgrade without touching production — parallel cluster technique
- Rollback strategy if upgrade fails — restore from pre-upgrade backup
- `primaryUpdateMethod: restart` vs `switchover` — what CloudNativePG does during image updates

### 10. Security: TLS, Secrets, and Network Policies
- TLS architecture — how CloudNativePG uses cert-manager to issue server certificates, client certificates
- `certificates.serverCASecret`, `certificates.serverTLSSecret`, `certificates.clientCASecret` — full spec
- How application services authenticate: password auth vs TLS client certificates
- Kubernetes Secrets management for database passwords — how `managed.roles[*].passwordSecret` works
- Network policies — example Kubernetes NetworkPolicy restricting PostgreSQL pod ingress to only authorized service pods
- `sslMode` for each client service: `require` vs `verify-full` — recommendations per service
- `pgaudit` extension — enabling audit logging for compliance, what it logs
- Restricting superuser access — `enableSuperuserAccess: false` in production, when it's needed
- Secret rotation — how to rotate a role password without downtime

### 11. Performance Tuning for a Small Cluster
- Starting `postgresql.parameters` values for a Hetzner 4-vCPU / 8GB RAM node
- `shared_buffers`: 25% RAM rule — exact value for 8GB node
- `work_mem`: how to calculate safely for concurrent connections through PgBouncer
- `effective_cache_size`, `maintenance_work_mem`, `checkpoint_completion_target`
- `max_connections` — interaction with PgBouncer pool sizes, recommended value when using transaction pooling
- `wal_level`, `archive_mode`, `archive_timeout` — what CloudNativePG sets automatically vs what you configure
- `random_page_cost` for SSD/network-attached storage (Hetzner volumes are network-attached)
- `autovacuum` tuning for tables with high write rates (n8n workflows, Zitadel sessions)
- Connection overhead with vs without PgBouncer — why PgBouncer is mandatory for more than 3 services

### 12. CloudNativePG Troubleshooting
- Pod CrashLoopBackOff — how to read CloudNativePG pod logs, common causes (PVC not bound, bad config, cert issues)
- WAL archiving failures — symptoms, how to check `pg_stat_archiver`, fix and resume archiving
- Replication lag growing — diagnosis with `pg_stat_replication`, common causes on a 2-node cluster
- Connection limit exhaustion — `FATAL: sorry, too many clients already` — fix via PgBouncer or `max_connections`
- Primary election stuck after failover — how to diagnose, force-promote a replica
- PVC resize stuck in `Pending` — Hetzner CSI resize gotchas
- `kubectl cnpg status` output interpretation — what each field means
- Backup job failures — checking `ScheduledBackup` status, MinIO connectivity, S3 credential errors
- `pg_hba.conf` equivalent in CloudNativePG — where host-based auth is configured
- Recovering from split-brain — what CloudNativePG does, how to confirm no split-brain occurred

---

# SECTION 2: PostgreSQL DBA + SQL Patterns (Database Internals Layer)

### 1. psql CLI Mastery
- Essential psql meta-commands: \d, \dt, \di, \df, \dp, \l, \c, \x (expanded output), \timing, \watch
- psql from inside CloudNativePG pods: how to exec into the primary pod and connect
- .pgpass file setup for passwordless script connections
- How to run SQL files non-interactively (psql -f, psql -c, heredoc patterns)
- Connection string formats (URI vs keyword-value) for CloudNativePG service names
- How to set search_path per session vs per database vs per role
- How to identify the primary vs replica in a CloudNativePG cluster from psql

### 2. Query Performance
- pg_stat_statements: how to enable (shared_preload_libraries in CloudNativePG), key columns (total_exec_time, calls, mean_exec_time, stddev_exec_time), reset with pg_stat_statements_reset()
- EXPLAIN output: reading cost=(startup..total), rows, width, actual time, loops — what each field means
- EXPLAIN ANALYZE: buffers option, track_io_timing, JIT sections — when to use which flags
- Reading common plan node types: Seq Scan, Index Scan, Index Only Scan, Bitmap Heap Scan, Hash Join, Merge Join, Nested Loop — when each appears and what it means for performance
- How to find the top 10 slowest queries in pg_stat_statements
- How to find queries causing the most I/O (shared_blks_hit + shared_blks_read)
- auto_explain: enabling in CloudNativePG, log_min_duration threshold, log_analyze

### 3. Indexing Strategy
- B-tree: default index type, when it's optimal, multi-column index column ordering (selectivity order), covering indexes (INCLUDE clause), partial indexes (WHERE clause to exclude NULLs or inactive rows)
- GIN: when to use (full-text search, JSONB containment @>, array operators), GIN vs GiST for tsvector, gin_pending_list_limit for write-heavy tables
- GiST: when to use (geometric types, range types, full-text with ranking), slower builds but better update performance than GIN
- BRIN: when to use (large append-only tables with physical correlation — logs, time-series), block range size tuning, drastically smaller than B-tree
- Hash: when to use (equality-only lookups, PostgreSQL 10+), limitations (not WAL-logged pre-10, no multi-column)
- Bloom: when to use (multi-column equality filters on many columns), vs GIN
- Index bloat: how to detect (pgstatindex extension, pg_relation_size vs pg_total_relation_size), REINDEX CONCURRENTLY to rebuild without locking
- How to check index usage: pg_stat_user_indexes (idx_scan = 0 means unused)
- Unused index detection query: join pg_stat_user_indexes + pg_indexes filtered on idx_scan

### 4. VACUUM and Bloat
- How VACUUM works: marks dead tuples as reusable without reclaiming disk space; VACUUM FULL reclaims disk but needs exclusive lock
- Autovacuum: key parameters (autovacuum_vacuum_scale_factor, autovacuum_vacuum_threshold, autovacuum_analyze_scale_factor), how to tune for write-heavy tables by overriding per-table (ALTER TABLE SET autovacuum_*)
- How to check autovacuum status: pg_stat_user_tables (last_autovacuum, n_dead_tup, n_live_tup), pg_stat_activity for running autovacuum workers
- Table bloat detection query: estimate dead tuple ratio from pg_stat_user_tables
- How to force vacuum on specific tables without downtime: VACUUM ANALYZE tablename
- Transaction ID wraparound: what it is, how to monitor (pg_database.datfrozenxid age), emergency autovacuum triggers
- TOAST: what it is, when Postgres uses it, how it affects bloat and queries

### 5. Partitioning
- Declarative partitioning (PostgreSQL 10+): PARTITION BY RANGE, LIST, HASH — when to use each
- Range partitioning: ideal for time-series data (logs, audit trails, n8n execution history), partition pruning to skip old partitions in queries
- List partitioning: ideal for known discrete values (status, tenant_id, region)
- Hash partitioning: ideal for even distribution when no natural range (user_id sharding)
- Creating and attaching partitions: CREATE TABLE ... PARTITION OF, attaching existing tables
- Partition maintenance: adding new time-based partitions (pg_partman extension), dropping old partitions vs archiving
- Gotchas: primary keys must include partition key, foreign keys to partitioned tables have limitations pre-PG15, global indexes not supported
- When partitioning helps vs hurts: threshold (~50M+ rows for range, less clear for others)

### 6. Connection Pooling with PgBouncer (DBA Perspective)
- PgBouncer modes: session pooling vs transaction pooling vs statement pooling — what breaks in each mode (prepared statements in transaction mode, SET in statement mode)
- CloudNativePG's built-in Pooler CRD: how to configure transaction pooling per cluster
- PgBouncer parameters: max_client_conn, default_pool_size, max_db_connections, pool_mode
- How to monitor PgBouncer: SHOW POOLS, SHOW CLIENTS, SHOW SERVERS, SHOW STATS via psql to the admin interface
- Common application issues with connection poolers: prepared statements (use protocol-level instead of named), advisory locks (session-scoped, break in transaction mode), LISTEN/NOTIFY (not compatible with transaction pooling)
- Sizing formulas: how many connections does the app need vs what PostgreSQL can handle (max_connections tuning for small nodes)

### 7. Replication Monitoring
- pg_stat_replication: key columns (client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, replay_lag)
- How to calculate replication lag in bytes: sent_lsn - replay_lsn
- How to calculate replication lag in time: replay_lag column (PG10+)
- pg_stat_wal_receiver: on the replica side, shows connection status and lag
- CloudNativePG-specific: how to check primary/replica status via kubectl (cnpg plugin), pg_replication_slots for slot monitoring
- Replication slot monitoring: pg_replication_slots (active, wal_status, retained_wal) — dangling slots cause WAL accumulation and disk fill

### 8. Backup and WAL (DBA Perspective)
- pg_dump: when to use (logical, single-database, portable), pg_dump -Fc (custom format) vs -Fp (plain SQL), pg_dumpall for roles/tablespaces
- pg_restore: -j flag for parallel restore (speeds up large restores), --section=data for data-only restore
- WAL archiving vs PITR: how CloudNativePG handles WAL archiving to MinIO, recovery_target_time syntax for point-in-time recovery
- wal_keep_size vs replication slots for retaining WAL
- How to check WAL generation rate: pg_stat_bgwriter (buffers_checkpoint, checkpoint_write_time)

### 9. Memory Tuning for Small Nodes
- shared_buffers: recommended 25% of RAM, how to set in CloudNativePG cluster spec (postgresql.parameters)
- work_mem: per-sort/hash operation (not per connection), danger of setting too high with many connections, formula: (available RAM - shared_buffers) / (max_connections * 2)
- effective_cache_size: planner hint only (does not allocate), set to 75% of RAM to guide index vs seq scan decisions
- maintenance_work_mem: for VACUUM, CREATE INDEX, ALTER TABLE — safe to set higher than work_mem
- wal_buffers: default 1/32 of shared_buffers, cap at 16MB for most workloads
- max_connections: cost per idle connection (~5-10MB), prefer PgBouncer + lower max_connections (50-100) over high max_connections (500+)

### 10. Monitoring Queries Reference
- Active connections by state: SELECT state, count(*) FROM pg_stat_activity GROUP BY state
- Long-running queries: SELECT pid, now()-query_start, query FROM pg_stat_activity WHERE state='active' AND query_start < now() - interval '30s'
- Lock waits: join pg_locks + pg_stat_activity to find blocker/blocked pairs
- Table sizes: pg_size_pretty(pg_total_relation_size('tablename'))
- Index bloat estimate: query using pgstattuple or approximation from pg_stat_user_tables
- Dead tuple ratio: n_dead_tup / (n_live_tup + n_dead_tup) per table
- Checkpoint frequency: pg_stat_bgwriter checkpoints_timed vs checkpoints_req (req means WAL or manual trigger, not scheduled — investigate if high)
- Cache hit ratio: sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) from pg_statio_user_tables (target >99% for OLTP)

### 11. Security (DBA Perspective)
- Role design: superuser for DBA tasks only, application roles with minimum privilege (SELECT/INSERT/UPDATE on specific schemas), readonly role for monitoring
- Row-Level Security (RLS): how to enable (ALTER TABLE ENABLE ROW LEVEL SECURITY), creating policies (CREATE POLICY), BYPASSRLS attribute for admin roles
- How CloudNativePG manages pg_hba.conf: via cluster spec (pg_hba entries), what defaults are set, how to add custom rules
- Schema isolation: using schemas as namespace boundaries for multi-tenant (one schema per tenant), search_path manipulation
- SSL enforcement: require_ssl in CloudNativePG, how to verify connections are encrypted
- Audit logging: pgaudit extension, log_statement parameter ('none', 'ddl', 'mod', 'all')

### 12. SQL Patterns — Multi-Tenant Database Design
- Three approaches with trade-offs:
  - Shared schema (row-level tenant_id column): simplest, RLS enforces isolation, risk of data leak if RLS misconfigured, single schema migration
  - Schema-per-tenant (CREATE SCHEMA per client): better isolation, search_path switching, harder to query across tenants, schema proliferation
  - Database-per-tenant (separate PostgreSQL cluster or database): strongest isolation, most resource overhead, complex with CloudNativePG (separate Cluster CR per tenant)
- Which approach fits Helix Stax consulting clients (likely schema-per-tenant for moderate isolation without separate clusters)
- Tenant_id indexing patterns: partial indexes per tenant, how to avoid cross-tenant query accidents
- Connection routing for schema-per-tenant: SET search_path or connection string options parameter

### 13. SQL Patterns — Zero-Downtime Migrations
- The expand-contract pattern for schema changes: phase 1 (add column nullable, deploy code that writes both old and new), phase 2 (backfill), phase 3 (add NOT NULL constraint, drop old column)
- Why ALTER TABLE ADD COLUMN NOT NULL DEFAULT is dangerous in old PostgreSQL (rewrites table), safe in PostgreSQL 11+ with a constant default (metadata-only change)
- Adding indexes without locking: CREATE INDEX CONCURRENTLY (runs without AccessShareLock, takes longer but non-blocking)
- How CloudNativePG handles migrations: no built-in migration runner, use application migration tools (Flyway, Liquibase, golang-migrate) via init containers or job
- Migration sequencing for CloudNativePG: run migrations against primary only, replicas catch up via WAL, do NOT run migrations on replicas
- Rollback strategies: always write a down migration, test rollback before production, consider feature flags for application-level rollback

### 14. SQL Patterns — JSON/JSONB Operations
- JSON vs JSONB: always prefer JSONB (binary storage, indexed, more operators), JSON only for preserving key order or whitespace
- Key JSONB operators: -> (get field as JSON), ->> (get field as text), #> (path), @> (contains), <@ (contained by), ? (key exists), ?| (any key), ?& (all keys)
- Indexing JSONB: GIN index on full column for containment queries, functional index on extracted field for equality/range
- n8n workflow storage: n8n stores workflow definitions and execution data as JSONB — useful queries for inspecting workflow state
- jsonb_set for updates, jsonb_delete for removing keys, jsonb_build_object for constructing
- jsonb_array_elements for unnesting arrays, jsonb_each for iterating keys
- Performance: avoid ->> on unindexed large JSONB in WHERE clause (forces full table scan with function call)

### 15. SQL Patterns — CTEs, Window Functions, Upserts, Batch
- CTEs (WITH clause): standard vs MATERIALIZED (forces CTE to execute once as optimization fence), RECURSIVE for tree/graph traversal, when CTEs hurt performance (planner can't push predicates into non-materialized CTEs in older PG)
- Window functions: ROW_NUMBER(), RANK(), DENSE_RANK(), LAG(), LEAD(), FIRST_VALUE(), LAST_VALUE(), NTILE() — OVER (PARTITION BY ... ORDER BY ...) syntax, ROWS vs RANGE frame
- Upserts: INSERT ... ON CONFLICT (column) DO UPDATE SET ... (EXCLUDED pseudo-table), ON CONFLICT DO NOTHING, partial unique indexes as conflict targets
- Batch operations: INSERT with multi-row VALUES (much faster than single-row inserts), COPY for bulk load (fastest), batch size tuning (1000-10000 rows per transaction as starting point)
- RETURNING clause: get inserted/updated values back without a second query
- FOR UPDATE / FOR SHARE: row-level locking in SELECT, SKIP LOCKED for queue-style processing (n8n job queues pattern)

---

# SECTION 3: pgvector (Vector Search + AI Layer)

### 1. Installation on CloudNativePG
- How to enable the pgvector extension in CloudNativePG: cluster spec postgresql.shared_preload_libraries is NOT needed (it's a regular extension), use CREATE EXTENSION vector in the target database
- CloudNativePG image requirements: the operator's default image includes pgvector starting from specific versions — which versions include it, how to check
- Custom image approach if pgvector is not bundled: building a custom Docker image FROM ghcr.io/cloudnative-pg/postgresql:16 with pgvector, how to reference a custom image in the Cluster CR (imageName field)
- Harbor as the registry for custom CloudNativePG images: tag, push to Harbor, reference in Cluster CR
- Verifying installation: SELECT * FROM pg_extension WHERE extname = 'vector'; SELECT vector_version();

### 2. RuVector Research (Potential Replacement)
- Research RuVector at github.com/ruvnet/ruvector — what it is, what problem it solves vs pgvector
- Performance comparison: RuVector vs pgvector on ANN recall@10, QPS, index build time for 768-dim vectors (nomic-embed-text scale)
- Maturity comparison: release version, GitHub stars, production usage reports, known bugs
- CloudNativePG compatibility: can RuVector be installed in a CloudNativePG-managed PostgreSQL cluster? Custom image requirements?
- API compatibility: does RuVector expose the same SQL interface as pgvector (vector type, <->, <=>, <#> operators, HNSW/IVFFlat indexes)? Or is it a different approach entirely?
- Migration path: if switching from pgvector to RuVector, what changes in schema, index definitions, query syntax?
- Recommendation: should Helix Stax adopt RuVector over pgvector now, later, or not at all?

### 3. Vector Column Types and Basic Operations
- Column type syntax: column_name vector(dimensions) — dimensions must match the embedding model output
- Ollama embedding dimensions: common models and their output dimensions (nomic-embed-text: 768, mxbai-embed-large: 1024, all-minilm: 384)
- Inserting vectors: standard INSERT with array literal '[0.1, 0.2, ...]'::vector or from application array
- Basic distance queries: SELECT * FROM embeddings ORDER BY embedding <-> '[...]' LIMIT 10 (L2 distance operator)
- Three distance operators: <-> (L2/Euclidean), <#> (negative inner product / cosine for normalized vectors), <=> (cosine distance) — when to use each
- Cosine similarity for semantic search: normalize vectors at insert time + inner product, or use <=> operator directly
- NULL handling: vector columns can be NULL, embedding may be NULL for records not yet embedded — filter with IS NOT NULL

### 4. Indexing: IVFFlat vs HNSW
- No index (exact KNN): always returns correct results, O(n) scan — acceptable for <100K vectors
- IVFFlat: inverted file index, approximate search, parameters: lists (number of clusters, sqrt(n) as starting point), probes (lists to search at query time, higher = more accurate + slower), build requires data already in table (no incremental), faster to build than HNSW
- HNSW (pgvector 0.5+): hierarchical navigable small world graph, parameters: m (connections per layer, default 16), ef_construction (build-time search width, default 64), ef_search (query-time search width, set via SET hnsw.ef_search), incremental inserts supported (index updates as you insert), slower build but faster query and better recall than IVFFlat
- When to choose: IVFFlat for datasets built offline (batch insert then index), HNSW for production systems with ongoing inserts
- Index creation syntax: CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops) WITH (m=16, ef_construction=64)
- Operator classes: vector_l2_ops (L2), vector_ip_ops (inner product), vector_cosine_ops (cosine) — must match distance operator used in queries
- Memory: HNSW indexes are memory-resident during queries — estimate 1.5x the index size in RAM needed during search

### 5. RAG and Embedding Storage Patterns
- Table schema for RAG: id, content (text), embedding (vector), source (text), chunk_index (int), metadata (jsonb), created_at — include metadata JSONB for filtering
- Chunking strategy: store chunk size used at insert time in metadata for debugging, typical 256-512 tokens per chunk
- Hybrid search (vector + full-text): combine pgvector ANN search with PostgreSQL tsvector full-text; use RRF (Reciprocal Rank Fusion) to merge result sets, or use weighted sum of scores
- Filtering before vector search: WHERE metadata @> '{"source": "docs"}' ORDER BY embedding <-> query_embedding LIMIT 10 — pre-filter reduces candidate set, improves speed but index cannot always be used for filtered ANN
- Ollama embedding integration: call Ollama HTTP API (/api/embeddings) from n8n workflow or application code, store returned embedding array in pgvector column
- Incremental updates: re-embed on content change (track content hash), DELETE + INSERT pattern or UPDATE embedding WHERE id = ?
- pgvector + Grafana: not directly visualizable, but can query embedding similarity stats as metrics

### 6. Performance and Memory Implications
- Vector index memory: HNSW index for 100K 768-dim vectors ≈ 300-500MB RAM — significant on small Hetzner nodes
- work_mem for vector queries: ANN queries may use additional memory for candidate lists, monitor with EXPLAIN ANALYZE
- Partitioning with pgvector: HNSW indexes are per-partition, vector search must UNION across partitions or use un-partitioned table — avoid partitioning vector tables unless necessary
- Dimensionality: higher dimensions = larger storage per row, slower distance computation, more index memory; use smaller embedding models if node RAM is constrained
- Storage sizing: 768-dim float32 vector = 3072 bytes per row; 1M vectors = 3GB just for embeddings before index
- Vacuum implications: vector indexes are not affected by dead tuples differently — standard VACUUM applies, HNSW does not reindex on vacuum (unlike IVFFlat which may need REINDEX if bloated)

---

## Required Output Format

Structure your response EXACTLY like this — it will be split into separate skill files for AI agents, with one file per top-level `#` header. Use `# Tool Name` as the top-level headers so the output can be mechanically split:

```markdown
# CloudNativePG (PostgreSQL)

## Overview
[2-3 sentence description of what CloudNativePG does and why we use it]

## Cluster CRD Reference
### Core Cluster Spec
[Annotated YAML example of a production-ready Cluster CRD]
### Key Fields Reference
[Table or list of critical fields with descriptions and example values]

## Database and User Management
### Creating Databases and Roles
[managed.databases and managed.roles examples for each service]
### kubectl cnpg Plugin
[Command reference with examples]

## Connection Pooling (PgBouncer)
### Pooler CRD
[Annotated YAML example]
### Pool Mode Selection
[Table: service -> recommended pool mode -> rationale]
### Connection Routing
[How apps connect to -rw vs Pooler service]

## Backup to MinIO
### Cluster Backup Spec
[Annotated YAML for S3/MinIO backup configuration]
### ScheduledBackup CRD
[Example with cron, retention]
### Verifying Backups
[Commands to check backup status]

## Recovery and PITR
### Full Cluster Restore
[Step-by-step procedure]
### Point-in-Time Recovery
[Bootstrap recovery YAML with targetTime example]
### Cluster Cloning
[Example for staging environment]

## High Availability
### Failover Behavior
[What happens automatically, what to monitor]
### Manual Switchover
[kubectl cnpg promote procedure]
### Service Endpoints
[-rw, -r, -ro service routing explanation]

## Monitoring
### Enabling Prometheus Metrics
[PodMonitor config]
### Key Metrics Reference
[Table: metric name -> meaning -> alert threshold]
### Grafana Dashboard
[Import instructions, key panels]
### Useful LogQL Queries
[Loki queries for CloudNativePG errors and events]

## Storage (Hetzner CSI)
### StorageClass Configuration
[YAML, reclaim policy, volume expansion]
### Sizing Recommendations
[storage vs walStorage sizing guidance]
### Volume Expansion
[Step-by-step resize procedure]

## Version Upgrades
### Minor Version Rolling Update
[Procedure, what to watch]
### Major Version Upgrade
[pg_upgrade approach, parallel cluster technique]
### Operator Upgrade
[Helm upgrade steps and CRD migration]

## Security
### TLS Configuration
[Cluster TLS spec with cert-manager integration]
### Network Policies
[Example NetworkPolicy YAML]
### Role Password Rotation
[Procedure without downtime]
### Audit Logging (pgaudit)
[How to enable, what it captures]

## Performance Tuning
### postgresql.parameters for 8GB Node
[Recommended values with rationale]
### PgBouncer Sizing
[Pool size calculations per service]
### max_connections Strategy
[Formula when using transaction pooling]

## Troubleshooting
### Diagnostic Commands
[kubectl commands for status, logs, replication check]
### Common Failures
[Error message -> cause -> fix table]
### WAL Archiving Issues
[Diagnosis and recovery steps]
### Backup Failures
[ScheduledBackup debugging steps]

# PostgreSQL DBA

## Overview
[2-3 sentences: what PostgreSQL DBA skills cover, why agents need them for CloudNativePG clusters]

## psql CLI Reference
### Connecting to CloudNativePG Pods
[kubectl exec pattern, psql connection strings, .pgpass setup]
### Essential Meta-Commands
[Table with command, description, example]
### Non-Interactive Usage
[psql -f, psql -c, heredoc patterns with examples]

## Query Performance Analysis
### pg_stat_statements
[Enable, key queries, reset]
### EXPLAIN / EXPLAIN ANALYZE
[Reading output, key flags, example annotated plan]
### Finding Slow Queries
[Copy-paste queries against pg_stat_statements]

## Indexing Strategy
### B-tree
[When to use, multi-column ordering, covering indexes, partial indexes]
### GIN
[When to use, JSONB, full-text, parameters]
### GiST
[When to use, trade-offs vs GIN]
### BRIN
[When to use, block range size]
### Index Maintenance
[Bloat detection, REINDEX CONCURRENTLY, unused index queries]

## VACUUM and Bloat
[Autovacuum tuning, monitoring queries, TOAST, wraparound monitoring]

## Partitioning
[Range/list/hash with examples, gotchas, when it helps vs hurts]

## Connection Pooling (PgBouncer)
[Modes, CloudNativePG Pooler CRD, monitoring, application gotchas, sizing]

## Replication Monitoring
[pg_stat_replication queries, lag calculation, slot monitoring, cnpg plugin]

## Backup and WAL
[pg_dump patterns, pg_restore -j, WAL archiving with MinIO, PITR]

## Memory Tuning (Small Nodes)
[shared_buffers, work_mem formula, effective_cache_size, max_connections]

## Monitoring Query Reference
[Copy-paste queries for: active connections, long-running, lock waits, table sizes, cache hit ratio, checkpoint frequency]

## Security
[Role design, RLS, pg_hba.conf in CloudNativePG, SSL, pgaudit]

# SQL Patterns

## Overview
[2-3 sentences: SQL patterns for our services, focus on zero-downtime and multi-tenant]

## Multi-Tenant Design
### Approach Comparison
[Table: shared schema vs schema-per-tenant vs db-per-tenant — isolation, complexity, migration, CloudNativePG fit]
### Recommended Approach for Helix Stax
[Which pattern, why, implementation example]
### Tenant Isolation with RLS
[CREATE POLICY example, testing isolation]

## Zero-Downtime Migrations
### Expand-Contract Pattern
[Step-by-step with SQL examples]
### Safe vs Unsafe DDL
[Table: operation, safe in PG11+?, lock type, workaround]
### CREATE INDEX CONCURRENTLY
[Syntax, caveats, monitoring progress]
### Migration Tooling with CloudNativePG
[Init container pattern, job pattern, which tools work well]

## JSON/JSONB Operations
### Operators Reference
[Table: operator, description, example — all key operators]
### Indexing JSONB
[GIN on column, functional index on path, examples]
### n8n Workflow Queries
[Useful queries for inspecting n8n data stored as JSONB]

## CTEs and Window Functions
### CTE Patterns
[Standard, MATERIALIZED, RECURSIVE with examples]
### Window Functions Reference
[ROW_NUMBER, LAG/LEAD, FIRST_VALUE examples with OVER syntax]

## Upserts and Batch Operations
### INSERT ON CONFLICT
[Syntax, EXCLUDED table, partial index targets]
### Batch Insert Patterns
[Multi-row VALUES, COPY, batch size guidance]
### SKIP LOCKED for Queues
[Pattern for job queue processing, relevance to n8n]

# pgvector

## Overview
[2-3 sentences: what pgvector does, role in Helix Stax RAG pipeline with Ollama]

## Installation on CloudNativePG
[Extension enablement, version requirements, custom image with Harbor, verification commands]

## RuVector Evaluation
### What RuVector Is
[Description, GitHub repo, stated advantages]
### Performance Comparison
[pgvector vs RuVector: recall, QPS, build time — actual benchmark data if available]
### Maturity Assessment
[Version, adoption, production readiness]
### CloudNativePG Compatibility
[Can it be installed? Custom image requirements?]
### API Compatibility
[Same SQL interface? Different operators? Migration effort?]
### Recommendation
[Adopt now / later / never — with rationale]

## Vector Column Types
### Supported Types
[vector(n), embedding dimensions for common Ollama models]
### Basic Operations
[INSERT, SELECT, UPDATE syntax with examples]

## Distance Functions
### Operator Reference
[Table: operator, distance type, when to use, normalized vs unnormalized vectors]
### Choosing the Right Operator
[Semantic search -> cosine, retrieval ranking -> inner product, geometric -> L2]

## Indexing
### No Index (Exact KNN)
[When adequate, performance ceiling]
### IVFFlat
[Parameters, build requirements, when to choose, CREATE INDEX syntax]
### HNSW
[Parameters, incremental insert support, memory implications, when to choose, CREATE INDEX syntax]
### Operator Classes
[vector_l2_ops, vector_ip_ops, vector_cosine_ops — match to query operator]

## RAG Storage Patterns
### Schema Design
[Full table DDL for embeddings/chunks table]
### Hybrid Search
[Vector + full-text query pattern, RRF fusion]
### Filtered ANN
[Pre-filter pattern, index usage caveats]
### Ollama Integration
[API call pattern, storing result, n8n workflow example]
### Incremental Updates
[Content hash tracking, re-embed pattern]

## Performance and Sizing
[Memory estimates for HNSW, storage sizing by dimension, work_mem, partitioning caveat, dimensionality trade-offs]

## Troubleshooting
### Index Not Used
[EXPLAIN ANALYZE, operator class mismatch, ef_search tuning]
### Slow Queries
[Probes tuning for IVFFlat, ef_search for HNSW, exact fallback]
### Extension Missing After Restore
[CREATE EXTENSION idempotently in migration]
```

Be thorough, opinionated, and practical. Include actual CRD YAML, actual CLI commands, actual SQL queries, actual error messages and their fixes. Do NOT give me theory — give me copy-paste-ready manifests, commands, and configs for a 2-node K3s cluster on Hetzner with MinIO as backup target and Ollama for embeddings. Explicitly call out which configuration applies to which dependent service (Zitadel, n8n, Backstage, Outline, Devtron, Harbor, Grafana) wherever relevant.
