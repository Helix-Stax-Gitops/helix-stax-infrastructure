# System Design: Databases and Caching Reference

**Author**: Remy Alcazar (Research Analyst)
**Date**: 2026-03-20
**Source**: ByteByteGo System Design 101 + official documentation
**Stack context**: CloudNativePG (PostgreSQL) + Valkey + MinIO on K3s/AlmaLinux 9

---

## Purpose

This document translates core system design concepts — databases, caching, data patterns, and CAP theorem — into specific architectural decisions for Helix Stax. Every concept is mapped to the actual stack running on the K3s cluster.

---

## Table of Contents

1. [SQL vs NoSQL](#1-sql-vs-nosql)
2. [ACID Properties and Transaction Isolation](#2-acid-properties-and-transaction-isolation)
3. [Database Indexing](#3-database-indexing)
4. [Database Replication](#4-database-replication)
5. [Database Sharding and Partitioning](#5-database-sharding-and-partitioning)
6. [Caching Strategies](#6-caching-strategies)
7. [Valkey (Redis Fork) Patterns](#7-valkey-redis-fork-patterns)
8. [Data Architecture Patterns](#8-data-architecture-patterns)
9. [CAP Theorem and Its Implications](#9-cap-theorem-and-its-implications)
10. [Summary: Design Decisions for Helix Stax](#10-summary-design-decisions-for-helix-stax)

---

## 1. SQL vs NoSQL

### What It Is

SQL databases (relational) store data in structured tables with fixed schemas and enforce ACID guarantees. NoSQL databases use flexible schemas (document, key-value, wide-column, graph) and trade strict consistency for horizontal scale and performance.

### Key Differences

| Dimension | SQL (PostgreSQL) | NoSQL (e.g. MongoDB, Cassandra) |
|-----------|------------------|---------------------------------|
| Schema | Fixed, enforced | Flexible, schema-optional |
| Scaling | Vertical (scale up) | Horizontal (scale out) |
| Consistency model | ACID | BASE (Basically Available, Soft state, Eventually consistent) |
| Query language | SQL (standardized) | Varies per product |
| Joins | Native, optimized | Application-side or limited |
| Transactions | Full multi-row | Limited or eventual |
| Best for | Complex queries, integrity | High volume, simple access patterns |

### Helix Stax Decision

PostgreSQL (via CloudNativePG) is the right choice for all core services:

- **Zitadel**: Identity data requires ACID guarantees — partial writes to user/session state would be a security incident.
- **n8n**: Workflow execution history and credentials must be transactionally consistent.
- **Custom apps**: Any financial or operational data should default to PostgreSQL.

NoSQL is not in scope for current Helix Stax services. If a future service has high-volume, simple key-value access patterns (e.g. feature flags, session tokens at scale), Valkey serves that role without introducing a separate NoSQL database.

**Risk**: Resist the temptation to reach for a document store for "flexible data." PostgreSQL's JSONB column type handles flexible/schema-optional data with SQL query capability and full indexing support — no need to add MongoDB.

---

## 2. ACID Properties and Transaction Isolation

### What It Is

ACID is the set of guarantees that make database transactions reliable:

- **Atomicity**: A transaction either completes fully or not at all. No partial writes. If a Zitadel user creation involves inserting into 3 tables and the third fails, all three roll back.
- **Consistency**: The database moves from one valid state to another. Constraints (foreign keys, NOT NULL, CHECK) are enforced.
- **Isolation**: Concurrent transactions do not interfere. A transaction reading data sees a consistent snapshot regardless of concurrent writes.
- **Durability**: Once a transaction commits, it survives crashes. PostgreSQL achieves this via the Write Ahead Log (WAL) — changes are written to WAL before applying to data pages.

### PostgreSQL Isolation Levels

PostgreSQL implements three levels (SQL standard defines four, but "Read Uncommitted" behaves as "Read Committed" in PostgreSQL):

| Level | Dirty Reads | Non-repeatable Reads | Phantom Reads | Use Case |
|-------|-------------|----------------------|---------------|----------|
| **Read Committed** (default) | No | Possible | Possible | OLTP, API backends, most workloads |
| **Repeatable Read** | No | No | Possible (Postgres handles via SSI) | Reporting queries, analytics |
| **Serializable** | No | No | No | Financial totals, double-spend prevention |

### Helix Stax Decisions

**Default: Read Committed for all services.**

Read Committed is the PostgreSQL default and correct for Zitadel, n8n, and API backends. It prevents dirty reads while allowing maximum concurrency.

**Use Serializable for**:
- Any future billing/payment transaction that must prevent double-charges
- Any operation involving balance calculations or quota enforcement

**Use Repeatable Read for**:
- Any reporting or analytics query that joins multiple tables and needs a consistent snapshot across the query

**Risk: n8n workflow locking.** n8n can create lock contention on workflow execution tables if multiple workers run concurrently. Monitor `pg_stat_activity` for long-held locks. CloudNativePG's connection pooling (PgBouncer) reduces this risk.

### Diagram Reference

ByteByteGo: "What does ACID mean?" — https://bytebytego.com/guides/database-and-storage/

---

## 3. Database Indexing

### What It Is

An index is a data structure maintained alongside a table that accelerates query lookups at the cost of write overhead and storage. Without an index, PostgreSQL performs a sequential scan (reads every row). With an index, it jumps directly to matching rows.

### PostgreSQL Index Types

| Type | Structure | Best For | Avoid When |
|------|-----------|----------|------------|
| **B-tree** (default) | Balanced tree | Equality (`=`), ranges (`>`, `<`, `BETWEEN`), `ORDER BY`, most queries | Large JSONB structures, text search |
| **GIN** | Inverted index | JSONB queries, arrays, full-text search (`tsvector`) | Frequently updated columns (slow writes) |
| **GiST** | Generalized search tree | Geometric data, IP ranges, range types | Exact equality (B-tree is faster) |
| **BRIN** | Block range index | Very large, naturally-ordered tables (timestamps, sequential IDs) | Random-access patterns |
| **Hash** | Hash table | Equality-only queries at extreme volume | Range queries (useless for ranges) |
| **Partial** | Any type, filtered | Indexing only a subset of rows (e.g. `WHERE deleted_at IS NULL`) | Always-true conditions |

### Helix Stax Index Strategy

**Zitadel PostgreSQL instance:**
Zitadel manages its own schema and migrations. Do not add indexes to Zitadel's tables directly — Zitadel maintains its own index strategy. Monitor slow queries via `pg_stat_statements`.

**n8n PostgreSQL instance:**
n8n's primary query patterns are on `execution_entity` (workflow runs) filtered by workflow ID, status, and timestamp:
- Composite B-tree index on `(workflow_id, status, created_at)` is the most impactful
- n8n generates significant write volume on executions — avoid GIN on frequently updated columns

**Custom app databases:**
- Use partial indexes for soft-delete patterns: `CREATE INDEX idx_active_users ON users(email) WHERE deleted_at IS NULL`
- Use GIN for any JSONB metadata columns queried with `@>` or `?` operators
- Use BRIN for event/log tables that are append-only and ordered by timestamp

**Operational rules:**
1. Always run `EXPLAIN ANALYZE` before creating an index on a production table
2. Create indexes `CONCURRENTLY` to avoid table locks: `CREATE INDEX CONCURRENTLY idx_name ON table(col)`
3. Unused indexes cost write performance — query `pg_stat_user_indexes` monthly to identify and drop zero-scan indexes

---

## 4. Database Replication

### What It Is

Replication copies data from a primary database instance to one or more secondary (standby/replica) instances. It serves two purposes: **high availability** (failover if primary dies) and **read scaling** (distribute read queries).

### Replication Modes

**Asynchronous replication** (default in PostgreSQL):
- Primary commits the transaction and acknowledges to the application immediately
- WAL data is shipped to replicas in the background
- Trade-off: replica may lag behind primary by milliseconds to seconds
- Risk: if primary crashes before WAL is shipped, the committed transaction is lost (RPO > 0)

**Synchronous replication**:
- Primary waits for at least one replica to confirm WAL receipt before acknowledging the commit
- Trade-off: write latency increases (must wait for network round-trip to replica)
- Benefit: RPO = 0 — no committed transaction is ever lost
- PostgreSQL uses `synchronous_commit = on` (or `remote_write`, `remote_apply` levels)

**Quorum-based synchronous (CloudNativePG)**:
- CloudNativePG supports `minSyncReplicas` and `maxSyncReplicas` configuration
- Quorum requires acknowledgment from a minimum number of replicas before commit confirms
- Balances durability with availability: cluster survives minority replica failure

### CloudNativePG Topology

CloudNativePG builds HA on top of PostgreSQL's native streaming replication (WAL-based). The architecture on K3s:

```
Application
    |
    |--- Primary Service (rw) → Primary Pod (PostgreSQL primary)
    |                                   |
    |--- Read-Only Service (ro) →  Standby Pod(s) (hot standby, readable)
```

- **Primary** (`-rw` service): All writes go here. Single primary at all times.
- **Read-Only** (`-ro` service): Hot standbys accept read queries. Applications should use `-ro` for read-heavy operations.
- **WAL Archiving**: CloudNativePG ships WAL to object storage (MinIO or S3) for point-in-time recovery (PITR)

### Helix Stax Decisions

**Current state**: Single-instance PostgreSQL per service (Zitadel, n8n). No replication active.

**Target state**:

| Service | Replication Mode | Rationale |
|---------|-----------------|-----------|
| Zitadel | 1 primary + 1 async standby | Auth outage is critical. Standby for fast failover. |
| n8n | 1 primary + 1 async standby | Workflow data loss is disruptive but not catastrophic. |
| Custom apps | 1 primary initially; add standby when needed | Right-size before adding complexity. |

**WAL Archiving to MinIO**: CloudNativePG should be configured to archive WAL to MinIO (`barmanObjectStore`). This enables PITR — restoring the database to any point in time, not just the last backup. This is the most important single HA feature to enable.

**Read scaling**: Use the `-ro` service for:
- n8n execution history queries
- Reporting/analytics queries
- Any read-heavy dashboard that doesn't require latest data

**Risk: Replication lag on async standby.** Reads from the `-ro` service may return slightly stale data. Applications must be designed to tolerate this. For operations requiring the absolute latest data (e.g. auth token validation in Zitadel), always use the primary (`-rw`) service.

---

## 5. Database Sharding and Partitioning

### What It Is

**Partitioning** divides a large table into smaller physical pieces (partitions) within the same database instance. PostgreSQL 11+ supports declarative partitioning natively.

**Sharding** distributes partitions across multiple database servers (nodes), each holding a subset of the data. True sharding requires external tooling on PostgreSQL (Citus extension, or application-level routing).

### Sharding Strategies

| Strategy | How It Works | Hot Spots | Resharding |
|----------|-------------|-----------|------------|
| **Range-based** | Rows split by value range (IDs 1-1000 → shard 1) | Yes — recent data hits one shard | Difficult |
| **Hash-based** | Hash function applied to key, result determines shard | No — uniform distribution | Difficult without consistent hashing |
| **Directory-based** | Lookup table maps records to shards | No | Easiest — update lookup table |
| **Consistent hashing** | Hash ring minimizes data movement on reshard | No | Best for dynamic cluster size |

### Helix Stax Decision

**Sharding is not needed at current scale.** Helix Stax is a consultancy managing its own infrastructure — not a multi-tenant SaaS with millions of rows. Sharding adds significant operational complexity (cross-shard queries break, foreign keys cannot span shards, schema changes must coordinate across all shards).

**PostgreSQL table partitioning IS appropriate for**:
- n8n `execution_entity` table: partition by month on `created_at`. This keeps recent executions in a small, fast partition and allows old partitions to be archived or dropped.
- Any future audit/event log table that will grow to millions of rows.

**Implementation pattern** (PostgreSQL declarative partitioning):
```sql
CREATE TABLE n8n_executions (
    id BIGSERIAL,
    workflow_id TEXT NOT NULL,
    status TEXT,
    created_at TIMESTAMP NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE n8n_executions_2025_q1
    PARTITION OF n8n_executions
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
```

**When to reconsider sharding**: If Helix Stax adds a multi-tenant product (SaaS) with per-tenant data isolation requirements, evaluate Citus or a managed distributed PostgreSQL (CockroachDB, YugabyteDB) at that point.

---

## 6. Caching Strategies

### What It Is

A cache is a fast in-memory data store that sits between the application and the database, serving frequently accessed data without hitting the database on every request. Caching reduces latency, reduces database load, and provides headroom during traffic spikes.

### The Five Core Strategies

#### Cache-Aside (Lazy Loading)

The application manages the cache manually:
1. Check cache for the key
2. On cache miss: query the database, store result in cache, return result
3. On cache hit: return cached data directly

```
Application → Cache [miss] → Database → Application populates cache → Returns data
Application → Cache [hit] → Returns cached data (no DB)
```

**Pros**: Only caches data that is actually requested. Cache failure does not break the application — it just falls through to the database.

**Cons**: First request always misses (cold start latency). Cache can contain stale data if the database is updated without invalidating the cache.

**Best for**: Read-heavy workloads with infrequent writes. General-purpose caching of database query results.

#### Write-Through

Every write goes to both the cache and the database simultaneously. The write completes only when both confirm.

```
Application → Cache + Database (simultaneously) → Confirms when both written
```

**Pros**: Cache is always consistent with the database. No stale reads.

**Cons**: Write latency doubles (must wait for both). Cache stores data even if it is never read (cache pollution for write-heavy data).

**Best for**: Data that is frequently written AND frequently read. Session state. Configuration data.

#### Write-Back (Write-Behind)

Write is acknowledged when data reaches the cache. The cache asynchronously flushes to the database in the background.

```
Application → Cache (acknowledged immediately) → Background job → Database
```

**Pros**: Lowest write latency of all strategies.

**Cons**: Data loss risk — if the cache node fails before flushing, the write is lost. Cache and database are temporarily inconsistent.

**Best for**: High-frequency writes where some data loss is acceptable (metrics, counters, analytics). Not appropriate for financial or auth data.

#### Write-Around

Writes go directly to the database, bypassing the cache entirely. The cache is only populated on reads.

```
Application → Database (write, cache bypassed)
Application → Cache [miss] → Database (first read populates cache)
```

**Pros**: Prevents cache pollution from write-heavy data that may never be re-read.

**Cons**: Cache miss on first read after every write.

**Best for**: Data that is written once and rarely re-read (e.g. audit logs, file metadata written on upload).

#### Read-Through

The cache layer sits between application and database and handles its own population:
1. Application requests data from cache
2. On miss: cache fetches from database and stores it
3. Application always talks to the cache, never directly to the database

**Pros**: Simplified application logic — only one data source to query.

**Cons**: Cache failure breaks reads entirely (tight coupling). First request still misses.

**Best for**: When the cache layer supports this (Redis/Valkey do not implement this natively — it is an application-level pattern).

### Strategy Comparison

| Strategy | Write Latency | Read Latency | Consistency | Loss Risk |
|----------|--------------|--------------|-------------|-----------|
| Cache-Aside | Low (writes skip cache) | High on first miss | Eventual | None |
| Write-Through | High (waits for both) | Low after first write | Strong | None |
| Write-Back | Very low | Low | Eventual | Yes (cache failure) |
| Write-Around | Low (bypasses cache) | High on first read | Strong | None |
| Read-Through | Depends on write strategy | Low after first miss | Depends | None |

### Helix Stax Decisions

| Service | Strategy | Rationale |
|---------|----------|-----------|
| Zitadel session tokens | Cache-Aside | Tokens are read frequently, written once on login. Miss is acceptable on first use. |
| Zitadel user profiles | Cache-Aside with short TTL (5 min) | Profile data changes infrequently. Short TTL prevents stale display. |
| n8n workflow definitions | Cache-Aside | Workflow configs are read on every execution trigger, written rarely. |
| n8n execution status | Write-Through | Status must be current — dashboards and webhooks read it frequently. |
| API rate limit counters | Write-Back | High-frequency increments, minor count inaccuracy acceptable. |
| Static config / feature flags | Write-Through | Small data, read constantly, must be fresh. |
| MinIO file metadata | Write-Around | Metadata written on upload, not re-read frequently. |

**Diagram Reference**: ByteByteGo "Top 5 Caching Strategies" — https://blog.bytebytego.com/p/top-caching-strategies

---

## 7. Valkey (Redis Fork) Patterns

### What It Is

Valkey is a BSD-licensed fork of Redis 7.2.4, initiated by the Linux Foundation in March 2024 after Redis changed its license to a dual-source-available model. AWS, Google Cloud, and other major cloud vendors maintain it. Valkey 8.x retains wire protocol compatibility with Redis 7.x. Valkey 9.0 (September 2025) began significant divergence, adding native JSON, Bloom filters, search modules, and multi-database support in cluster mode.

**For Helix Stax**: Valkey is a drop-in Redis replacement. All Redis client libraries (ioredis, redis-py, Jedis) work against Valkey. The key governance difference: no single vendor can change its license.

### Valkey Data Structures and Their Uses

| Structure | Use Case | Helix Stax Application |
|-----------|----------|------------------------|
| **String** | Simple key-value cache, counters | Session tokens, rate limit counters, feature flags |
| **Hash** | Object with multiple fields | User profile cache (one key per user, fields per attribute) |
| **List** | Queues, recent activity | n8n job queue, recent webhook event buffer |
| **Set** | Unique members, membership checks | Active session IDs, role memberships |
| **Sorted Set** | Ranked data, TTL-like priority queues | Leaderboards, delayed job scheduling |
| **Stream** | Append-only log, consumer groups | Real-time event streaming (alternative to Kafka for small scale) |

### Memory Management and Eviction Policies

Valkey must be configured with `maxmemory` to prevent unbounded growth. When memory is full, the `maxmemory-policy` determines what gets evicted.

**Configuration** (in `values.yaml` for Valkey Helm chart):
```yaml
configuration: |
  maxmemory 512mb
  maxmemory-policy allkeys-lru
  maxmemory-samples 10
```

**Policy selection guide for Helix Stax**:

| Policy | Behavior | When to Use |
|--------|----------|-------------|
| `allkeys-lru` | Evict least recently used across all keys | Default recommendation — general-purpose cache |
| `allkeys-lfu` | Evict least frequently used across all keys | When access follows power law (some keys 100x more popular) |
| `volatile-ttl` | Evict keys with TTL, shortest first | When you explicitly manage TTL per key and want fine control |
| `noeviction` | Reject new writes when full | NEVER use for caching — use only for message queues or session stores where data loss is unacceptable |

**Recommendation**: Start with `allkeys-lru` and `maxmemory-samples 10` (higher precision, marginal CPU cost).

### TTL Strategy

Every cached key must have a TTL (expiration time). Keys without TTL accumulate and eventually fill memory.

| Data Type | Recommended TTL | Rationale |
|-----------|-----------------|-----------|
| Session tokens | Match auth token lifetime (e.g. 15 min) | Auto-expire stale sessions |
| User profiles | 5 minutes | Short enough to catch updates, long enough to benefit |
| Workflow definitions (n8n) | 10 minutes | Definitions change rarely; 10 min is safe |
| Rate limit counters | 1 minute sliding window | Counters must expire per window |
| Feature flags | 60 seconds | Fast propagation of flag changes |
| Presigned URL metadata | Match URL expiry | Security — don't cache after URL expires |

### Valkey Persistence

Valkey supports two persistence mechanisms. For caching use cases, persistence is optional:

- **RDB (snapshot)**: Periodic full-memory snapshot to disk. Low overhead, acceptable data loss window. Good for caching — you can rebuild the cache from the database on restart.
- **AOF (Append Only File)**: Logs every write command. Near-zero data loss. Use this for data that cannot be rebuilt (e.g. if Valkey is used as a primary store, not just a cache).

**Helix Stax decision**: RDB-only for caching. If Valkey is also used for session state (where rebuilding from PostgreSQL is expensive), enable AOF with `appendfsync everysec`.

### Valkey on K3s — Helm Deployment

Bitnami provides a Valkey Helm chart that is the canonical deployment option:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install valkey bitnami/valkey --version <pinned>
```

Key Helm values to set:
```yaml
# Standalone (single instance) vs Cluster mode
architecture: standalone  # or replication

# Resource limits for K3s (right-size per node capacity)
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m

# Persistence (RDB)
persistence:
  enabled: true
  size: 2Gi

# Auth
auth:
  enabled: true
  password: ""  # Use external-secrets/OpenBao — never hardcode
```

**Gotcha**: Valkey 9.x modules (JSON, Search) are not included in the Bitnami chart by default. If you need JSON or search capability from Valkey, pin to a version that supports your required module or use a custom image.

---

## 8. Data Architecture Patterns

### CQRS (Command Query Responsibility Segregation)

**What it is**: Separates write operations (commands, which change state) from read operations (queries, which return data). They use different models, different services, and optionally different data stores.

```
Write Path: Application → Command Handler → PostgreSQL Primary (writes)
Read Path:  Application → Query Handler  → PostgreSQL Replica (reads) or Valkey cache
```

**Helix Stax application**: This pattern maps naturally to CloudNativePG's primary/standby topology. The `-rw` service is the command path, the `-ro` service is the query path.

Full CQRS with separate read models (e.g. denormalized views in Valkey or a separate read database) is not needed at current scale. Introduce only if read patterns diverge significantly from write schemas.

### Event Sourcing

**What it is**: Instead of storing current state, store the sequence of events that produced the state. The current state is derived by replaying all events from the beginning (or from a snapshot).

```
Traditional: users table — row with current user state
Event sourced: user_events table — INSERT (created), UPDATE (email_changed), UPDATE (role_assigned)
              Current state = replay all events for user_id
```

**Helix Stax application**: n8n's execution history is naturally event-sourced (each execution step is an event). Do not implement pure event sourcing for new applications unless there is a specific requirement for full audit history or temporal queries. The operational complexity (event schema evolution, snapshot management, replay time) is high.

For audit logging requirements (HIPAA-ready architecture), a simpler pattern suffices: append-only audit table with immutable rows.

### CDC (Change Data Capture)

**What it is**: Captures row-level changes (INSERT, UPDATE, DELETE) from the database transaction log and streams them as events to downstream consumers.

```
PostgreSQL WAL → Debezium → Kafka → Downstream services
```

**Helix Stax application**: CDC is the correct mechanism for:
- Syncing PostgreSQL data to a search index (e.g. Elasticsearch/OpenSearch)
- Propagating Zitadel user changes to other services without polling
- Building real-time dashboards from operational data

The Debezium PostgreSQL connector reads WAL via logical replication slots. This requires enabling `wal_level = logical` in PostgreSQL.

**CloudNativePG support**: CloudNativePG supports logical replication slots via `spec.replicationSlots` configuration. This is the mechanism needed for Debezium CDC.

**Gotcha**: Logical replication slots that are not consumed grow the WAL indefinitely. If a downstream consumer (Debezium) is offline for an extended period, the WAL can fill the disk. Monitor slot lag: `SELECT slot_name, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag FROM pg_replication_slots`.

### MinIO as an Object Storage Tier

**What it is**: Object storage (S3-compatible) for unstructured data — files, backups, logs, model artifacts, media. MinIO provides the same API as AWS S3, running on-premises on K3s.

**Integration patterns for Helix Stax**:

| Pattern | Description | Implementation |
|---------|-------------|----------------|
| **PostgreSQL WAL backup** | CloudNativePG archives WAL to MinIO for PITR | `barmanObjectStore` in Cluster spec |
| **Application file storage** | Apps write user uploads to MinIO via S3 API | Presigned URLs for client-side uploads |
| **Tiered storage** | Move cold data from PostgreSQL to MinIO | Archive old executions/logs from PostgreSQL to MinIO + store reference |
| **Static asset CDN origin** | MinIO as origin for images/files, Cloudflare as CDN | Public bucket + Cloudflare Cache |
| **n8n binary data** | n8n supports S3-compatible storage for workflow binary data | `N8N_DEFAULT_BINARY_DATA_MODE=s3` env var |

**Lifecycle policy pattern** (MinIO): Configure lifecycle rules to move old objects to cheaper storage tiers or delete them:
```json
{
  "Rules": [{
    "ID": "expire-old-logs",
    "Status": "Enabled",
    "Filter": {"Prefix": "logs/"},
    "Expiration": {"Days": 90}
  }]
}
```

### The Three-Tier Data Architecture for Helix Stax

```
HOT TIER:  Valkey (in-memory, <1ms latency)
           - Session tokens, active user profiles, rate limit state,
             workflow definitions, feature flags

WARM TIER: PostgreSQL/CloudNativePG (NVMe SSD, ~5ms latency)
           - All transactional data: users, orgs, workflows, executions,
             audit records

COLD TIER: MinIO (object storage, ~50ms latency)
           - WAL archives, database backups, binary workflow data,
             file uploads, old execution logs
```

Data should flow: HOT ← written-back-from → WARM ← archived-to → COLD

---

## 9. CAP Theorem and Its Implications

### What It Is

The CAP theorem (Brewer's theorem) states that a distributed data system can guarantee at most two of three properties simultaneously:

- **Consistency (C)**: Every read receives the most recent write or an error. All nodes see the same data at the same time.
- **Availability (A)**: Every request to a non-failing node receives a response (though not necessarily the most recent data).
- **Partition Tolerance (P)**: The system continues to operate even when network partitions occur (some nodes cannot communicate).

**The practical reality**: Network partitions are not optional in any distributed system — they happen. Therefore, every distributed system must choose between C and A when a partition occurs:
- **CP systems**: During a partition, sacrifice availability to maintain consistency (refuse reads/writes from the isolated partition)
- **AP systems**: During a partition, sacrifice consistency to maintain availability (serve potentially stale data)

### Database Classification

| Database | CAP | Behavior |
|----------|-----|---------|
| **PostgreSQL** (single node) | CA | Not distributed — partitions not applicable. ACID guarantees. |
| **PostgreSQL** (with replicas) | CP by default | Primary refuses writes if it cannot reach quorum replicas (when sync replication configured) |
| **Valkey/Redis** (single) | CA | Not distributed. |
| **Valkey/Redis** (cluster) | AP | Continues serving potentially stale data during partition |
| **MinIO** | AP (distributed) | Continues serving during partition; consistency via quorum writes |
| **MongoDB** | CP | Consistent reads; may reject during partition |
| **Cassandra** | AP | Eventually consistent; always available |

### How CAP Applies to Helix Stax

**PostgreSQL (CloudNativePG) with synchronous replication**:
- Configured as CP: the primary waits for replica acknowledgment before confirming writes
- During a network partition between primary and standby, the primary will stall writes rather than diverge
- This is the correct choice for Zitadel (auth) and n8n — data loss is worse than temporary write unavailability

**PostgreSQL with asynchronous replication**:
- Closer to AP behavior: primary acknowledges writes immediately, replica may lag
- During a partition, primary continues accepting writes; standby falls behind
- Risk: if primary fails during partition, committed transactions not yet shipped to standby are lost

**Valkey in standalone mode (current)**:
- Single node — CAP does not apply (no distribution)
- If the Valkey pod dies, the cache is lost — applications must handle cache-miss and fall through to PostgreSQL
- This is acceptable and expected behavior for a cache

**Valkey in cluster mode (future)**:
- AP — prefers availability; a small window of data loss possible during failover
- Appropriate for caching use cases where stale data for milliseconds is acceptable
- Not appropriate if Valkey is used as a primary data store for critical state

### BASE vs ACID

Systems that choose AP tend to implement BASE semantics instead of ACID:

| Property | ACID (PostgreSQL) | BASE (Cassandra, Dynamo) |
|----------|-------------------|--------------------------|
| Availability | May refuse during partition | Basically Available — always responds |
| State | Always consistent | Soft state — may be inconsistent temporarily |
| Consistency timing | Immediately consistent | Eventually consistent |

**Helix Stax decision**: All primary data storage (PostgreSQL) follows ACID. Valkey cache is BASE by nature but that is acceptable because it is a cache, not a source of truth.

### PACELC Extension

The PACELC theorem extends CAP: even when no partition exists (the normal case), there is a trade-off between Latency and Consistency:

- **Lower latency**: Accept stale reads (eventual consistency)
- **Higher consistency**: Incur latency waiting for all replicas to confirm

**Practical implication for Helix Stax**:
- Zitadel `-ro` read replicas: accept slight replication lag for lower read latency — AP/EL (availability + lower latency)
- Zitadel auth token validation: always hit primary — CP/EC (consistency at cost of higher latency)

### Design Rule

For each query in your application, ask:
1. Does this query require the absolute latest data, or is 1-second-old data acceptable?
2. If latest is required → use PostgreSQL primary (`-rw` service)
3. If stale is acceptable → use PostgreSQL replica (`-ro` service) or Valkey cache

---

## 10. Summary: Design Decisions for Helix Stax

### Firm Decisions

| Concept | Decision | Rationale |
|---------|----------|-----------|
| SQL vs NoSQL | PostgreSQL for all transactional data | ACID required for auth, billing, workflows |
| NoSQL for flexible data | PostgreSQL JSONB columns | Avoids adding a separate document database |
| Default isolation level | Read Committed | PostgreSQL default; correct for all current services |
| Index creation | Always CONCURRENTLY on production | Prevents table lock during index builds |
| Replication mode | Async replication + WAL archiving to MinIO | Balance of durability and write latency |
| WAL archiving | Enable immediately via barmanObjectStore | PITR is the most impactful HA feature |
| Sharding | Not needed; use table partitioning instead | Current scale does not justify sharding complexity |
| Partition strategy for large tables | Range partition by month on timestamp columns | Enables partition pruning, easy archival |
| Caching default strategy | Cache-Aside | Handles cold start gracefully, resilient to cache failure |
| Valkey eviction policy | allkeys-lru with maxmemory-samples 10 | Best general-purpose policy |
| Valkey persistence | RDB only for cache; add AOF if used as primary store | Appropriate trade-off |
| All cached keys | Must have explicit TTL | Prevents unbounded memory growth |
| CAP choice for PostgreSQL | CP (sync replication for Zitadel) | Auth data loss is worse than write stall |
| Read replica usage | Route read-heavy queries to `-ro` service | Offload primary, reduce latency |
| MinIO role | WAL backup, binary data, file uploads, cold archival | Three-tier storage architecture |

### Open Questions for User Input

1. **Valkey cluster mode**: Should Valkey run as standalone or cluster? Cluster mode adds resilience but requires at least 6 pods (3 primary + 3 replica). Given K3s cluster is 2 nodes, standalone with sentinel may be the right middle ground.

2. **CloudNativePG instance count**: How many instances per PostgreSQL cluster (Zitadel, n8n)? Recommended minimum for HA is 3 instances (1 primary + 2 standbys) for proper quorum-based sync replication. Currently unknown what is deployed.

3. **Logical replication / CDC**: Is there a current requirement for CDC? If yes, `wal_level = logical` must be configured in CloudNativePG, which increases WAL volume and requires slot monitoring.

4. **Valkey module requirements**: Are JSON, full-text search, or Bloom filter capabilities needed from Valkey (Valkey 9.x modules)? This affects which Helm chart version and image to pin.

5. **n8n execution pruning**: What is the retention policy for n8n execution history? Without pruning or partitioning, the `execution_entity` table will grow unboundedly. n8n has built-in pruning settings (`EXECUTIONS_DATA_PRUNE` env var) — confirm this is configured.

### Pipeline Compatibility (Required by Role)

| Concept | Helm-chartable? | vCluster testable? | GitHub Actions needed? |
|---------|-----------------|--------------------|-----------------------|
| CloudNativePG replication config | Yes — Cluster spec in values.yaml | Yes — CloudNativePG operator runs in vCluster | No — Helm deploy only |
| Valkey deployment | Yes — bitnami/valkey chart | Yes | No |
| WAL archiving to MinIO | Yes — barmanObjectStore in Cluster spec | Yes — MinIO also deployed in vCluster | No |
| PostgreSQL table partitioning | Yes — migration via Helm hook Job | Yes — runs against vCluster DB | No (or add migration step to Actions) |
| Valkey TTL/eviction config | Yes — values.yaml configuration block | Yes | No |
| CDC via Debezium | Yes — Debezium Helm chart available | Yes — but requires Kafka in vCluster too | No |

---

## References

- [ByteByteGo: Database and Storage guides](https://bytebytego.com/guides/database-and-storage/)
- [ByteByteGo: Top Caching Strategies](https://blog.bytebytego.com/p/top-caching-strategies)
- [ByteByteGo: CAP, BASE, SOLID, KISS acronyms](https://bytebytego.com/guides/cap-base-solid-kiss-what-do-these-acronyms-mean/)
- [CloudNativePG Replication documentation](https://cloudnative-pg.io/documentation/1.24/replication/)
- [CloudNativePG Architecture](https://cloudnative-pg.io/documentation/1.26/architecture/)
- [Valkey Key Eviction documentation](https://valkey.io/topics/lru-cache/)
- [PostgreSQL Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- [PostgreSQL Index Types](https://www.postgresql.org/docs/current/indexes-types.html)
- [Understanding Database Sharding — DigitalOcean](https://www.digitalocean.com/community/tutorials/understanding-database-sharding)
- [Valkey Helm chart announcement](https://valkey.io/blog/valkey-helm-chart/)
- [Debezium: Event Sourcing vs CDC](https://debezium.io/blog/2020/02/10/event-sourcing-vs-cdc/)
- [IBM: What is CAP Theorem](https://www.ibm.com/think/topics/cap-theorem)
- [Synchronous vs Asynchronous Replication — Design and Execute](https://www.designandexecute.com/designs/when-to-use-synchronous-vs-asynchronous-replication/)
