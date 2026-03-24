Here is the comprehensive research document for Valkey, tailored for Helix Stax's AI agents.

# Valkey

Valkey is a high-performance, in-memory key-value store, forked from Redis 7.2.4 by the Linux Foundation. We use it as a direct, open-source replacement for Redis, providing session caching, message queue backends (for n8n and Postal), and general-purpose application caching across the Helix Stax platform.

***

### ## SKILL.md Content
This is the core reference for daily AI agent operations. It is concise, actionable, and focused on the 95% of common tasks.

#### **Quick Start: Connecting to Valkey**
```bash
# Get pod name
VALKEY_POD=$(kubectl -n valkey get pods -l "app.kubernetes.io/name=valkey,app.kubernetes.io/component=master" -o jsonpath="{.items[0].metadata.name}")

# Get password from secret
VALKEY_PASSWORD=$(kubectl -n valkey get secret valkey -o jsonpath="{.data.valkey-password}" | base64 -d)

# Connect to the pod
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD
```

#### **CLI Quick Reference**

| Command | Description & Example |
| :--- | :--- |
| `INFO <section>` | Get server stats. **Use:** `INFO memory`, `INFO stats`, `INFO keyspace`. |
| `MONITOR` | Live stream of all commands. **Use for brief debugging only.** |
| `SLOWLOG GET 10` | Get the 10 most recent slow queries. |
| `CLIENT LIST` | See all connected clients. |
| `SCAN <cursor> MATCH <pattern> COUNT <count>` | Safely iterate keys. **NEVER use `KEYS *`**. |
| `MEMORY USAGE <key>` | Check memory used by a single key. |
| `XREADGROUP GROUP <group> <consumer> COUNT 1 STREAMS <stream> >` | Read from a stream (BullMQ). |
| `TTL <key>` | Check a key's remaining time-to-live in seconds (-1 for no expiry, -2 for not found). |
| `DEL <key>` | Delete a key. |
| `SELECT <db_index>` | Switch to a different database (e.g., `SELECT 1` for Postal). |
| `CONFIG GET <parameter>` | View a configuration parameter (e.g., `CONFIG GET maxmemory`). |

#### **Troubleshooting Decision Tree**

1.  **Symptom:** Application reports `(error) OOM command not allowed`.
    *   **Check:** `kubectl exec -it $POD -- valkey-cli -a $PASS INFO memory`
    *   **Verify:** `used_memory` is at or near `maxmemory`.
    *   **Fix (Immediate):** If a cache, temporarily change policy: `valkey-cli -a $PASS CONFIG SET maxmemory-policy allkeys-lru`.
    *   **Fix (Permanent):** Increase `master.resources.limits.memory` and `maxmemory` in `values.yaml` and redeploy.

2.  **Symptom:** Application latency is high.
    *   **Check:** `kubectl exec -it $POD -- valkey-cli -a $PASS SLOWLOG GET 10`
    *   **Verify:** Look for long-running commands like `KEYS`, `SMEMBERS` on large sets, or complex Lua scripts.
    *   **Fix:** Refactor application code to use `SCAN` instead of `KEYS` or break down large operations.

3.  **Symptom:** Application reports `ERR max number of clients reached`.
    *   **Check:** `kubectl exec -it $POD -- valkey-cli -a $PASS CLIENT LIST`
    *   **Verify:** A specific service has an abnormally high number of connections.
    *   **Fix:** Check the client application's connection pool settings. It may be leaking connections. Increase `maxclients` in Valkey config as a temporary measure.

4.  **Symptom:** Valkey pod is in `CrashLoopBackOff`.
    *   **Check:** `kubectl -n valkey logs $POD`
    *   **Verify:** Look for `FATAL` errors related to AOF/RDB loading or configuration `MISCONF`.
    *   **Fix (AOF):** Exec into a recovery pod with the PVC, run `valkey-check-aof --fix appendonly.aof`.
    *   **Fix (RDB):** Restore from a previous Velero snapshot.

#### **Integration Points**

*   **Service DNS Name:** `valkey-master.valkey.svc.cluster.local` on port `6379`.
*   **n8n Env Vars (Queue Mode):**
    ```env
    # n8n-values.yaml
    - name: QUEUE_BULL_REDIS_HOST
      value: "valkey-master.valkey.svc.cluster.local"
    - name: QUEUE_BULL_REDIS_PORT
      value: "6379"
    - name: QUEUE_BULL_REDIS_DB
      value: "0" # Use DB 0 for n8n
    - name: QUEUE_BULL_REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: valkey-acl-n8n # Use the n8n-specific ACL user secret
          key: password
    - name: N8N_EXECUTION_PROCESS
      value: "main" # For workers
    - name: EXECUTIONS_MODE
      value: "queue"
    ```
*   **Postal Config (`postal.yml`):**
    ```yaml
    # postal.yml section
    redis:
      host: valkey-master.valkey.svc.cluster.local
      port: 6379
      # Must use secretKeyRef — never hardcode. See n8n example above for correct pattern.
      password: "YOUR_POSTAL_ACL_USER_PASSWORD"
      database: 1 # Use DB 1 for Postal
      sidekiq_options:
        pool_size: 15 # Match worker threads + 5
    ```

***

### ## reference.md Content
This is the deep-dive specification for advanced configuration, troubleshooting, and understanding Valkey's architecture.

#### **1. CLI Reference (valkey-cli)**
*   **Connecting:**
    *   **Standard:** `valkey-cli -h <host> -p <port>`
    *   **Password:** `valkey-cli -a <password>` or will be prompted.
    *   **Password (from env):** `VALKEYCLI_AUTH=<password> valkey-cli`
    *   **ACL User:** `valkey-cli --user <username> --pass <password>` or `AUTH <username> <password>` command after connecting.
    *   **TLS:** `valkey-cli --tls --cacert /path/to/ca.crt -h <host> -p <tls-port>`
*   **`INFO` Sections:**
    *   `server`: Valkey version, OS, uptime, `hz`, executable path.
    *   `clients`: `connected_clients`, `maxclients`, `blocked_clients`.
    *   `memory`: `used_memory` (total from OS perspective), `used_memory_human`, `used_memory_dataset` (actual key data), `maxmemory`, `maxmemory_policy`, `mem_fragmentation_ratio` (ideal: 1.0-1.5, >1.5 indicates fragmentation).
    *   `persistence`: `loading` (0/1), `rdb_changes_since_last_save`, `rdb_last_save_time`, `aof_enabled`, `aof_rewrite_in_progress`.
    *   `stats`: `total_connections_received`, `total_commands_processed`, `instantaneous_ops_per_sec`, `keyspace_hits`, `keyspace_misses`, `evicted_keys`.
    *   `replication`: `role` (master/replica), `connected_slaves`, replication lag.
    *   `keyspace`: `db0: keys=123,expires=10,avg_ttl=...`. Per-database key stats.
*   **`MONITOR`:** Streams every command processed. **High performance impact.** Use only for brief debugging sessions. Do not leave it running.
*   **`SLOWLOG`:**
    *   `SLOWLOG GET [count]`: Retrieve slowlog entries. Each entry shows unique ID, timestamp, execution time (microseconds), command.
    *   `SLOWLOG LEN`: Get the number of entries in the slowlog.
    *   `SLOWLOG RESET`: Clear the slowlog.
*   **`CLIENT` Subcommands:**
    *   `CLIENT LIST`: Lists all connected clients with details like `addr`, `idle` time, `cmd` being run.
    *   `CLIENT KILL <ip:port>` or `CLIENT KILL ID <client-id>`: Forcibly disconnect a client.
*   **`DEBUG` Subcommands:** **Potentially dangerous.**
    *   `DEBUG SLEEP <seconds>`: Blocks the server for the specified time. Useful for testing timeouts.
    *   `DEBUG RELOAD`: Reloads the RDB/AOF file. Avoid in production.
*   **`SCAN` vs `KEYS *`:**
    *   `KEYS *`: Blocks the entire server while it scans all keys, causing massive latency. **Never use in production.**
    *   `SCAN <cursor> [MATCH pattern] [COUNT count]`: Iteratively scans keys without blocking. Returns a new cursor and a batch of keys. The client must call `SCAN` again with the new cursor until the cursor `0` is returned.
*   **`MEMORY` Subcommands:**
    *   `MEMORY USAGE <key> [SAMPLES count]`: Reports the bytes used by a key and its value.
    *   `MEMORY DOCTOR`: A diagnostic tool that reports memory issues and suggests remedies.
*   **`OBJECT` Subcommands:**
    *   `OBJECT ENCODING <key>`: Reveals the internal data structure used (e.g., `listpack`, `hashtable`, `intset`).
    *   `OBJECT IDLETIME <key>`: Seconds since the key was last accessed.
    *   `OBJECT FREQ <key>`: Logarithmic access frequency count (for LFU eviction).
*   **`CONFIG` Subcommands:**
    *   `CONFIG GET <parameter>`: Get current value (e.g., `CONFIG GET maxmemory`). Supports wildcards (`*`).
    *   `CONFIG SET <parameter> <value>`: Change a parameter at runtime. Not all parameters are settable.
    *   `CONFIG REWRITE`: Persists runtime changes made with `CONFIG SET` to the `valkey.conf` file.
*   **Pub/Sub:**
    *   `SUBSCRIBE <channel...>`: Subscribes the client to one or more channels. This is a blocking command.
    *   `PSUBSCRIBE <pattern...>`: Subscribes to channels matching a glob-style pattern.
    *   `PUBLISH <channel> <message>`: Posts a message to a channel.
*   **Streams (for BullMQ):**
    *   `XADD <stream> * <field> <value> ...`: Appends a new entry to a stream.
    *   `XGROUP CREATE <stream> <group> $ [MKSTREAM]`: Creates a consumer group. `MKSTREAM` creates the stream if it doesn't exist.
    *   `XREADGROUP GROUP <group> <consumer> [COUNT n] [BLOCK ms] STREAMS <stream> >`: Reads from a stream as part of a consumer group. `>` means read new messages only.
*   **Bulk Loading:** `valkey-cli --pipe` reads a raw protocol stream from stdin. Faster than sending commands one-by-one.
    ```bash
    # Generate Redis protocol format and pipe it
    (printf "SET key1 val1\r\nSET key2 val2\r\n") | valkey-cli -a $PASS --pipe
    ```

#### **3. Configuration: `maxmemory`, Eviction, Persistence**
*   **`maxmemory`:** Set to 70-80% of the container's memory limit (`spec.containers.resources.limits.memory`) to leave room for fragmentation, replication buffers, and OS overhead. For a 2GB limit, set `maxmemory` to `1610612736` (1.5GB).
*   **`maxmemory-policy`:**
| Policy | Use Case | Description |
| :--- | :--- | :--- |
| `noeviction` | **Queues (n8n, Postal)** | **CRITICAL for queues.** Returns error on write when memory is full. Prevents data loss for jobs. |
| `allkeys-lfu` | **Application Caching** | (Least Frequently Used) Evicts least frequently used keys. Best for general-purpose caching with "hot" key access patterns. |
| `volatile-lfu` | **Mixed Caching** | Evicts least frequently used keys *that have an expiration set*. Use when mixing cached and permanent data. |
| `allkeys-lru` | **Session Caching** | (Least Recently Used) Evicts least recently used keys. Good for session stores or caches with temporal locality. |
| `volatile-lru` | **Mixed Caching** | Evicts least recently used keys *that have an expiration set*. |
| `volatile-ttl` | **TTL Caching** | Evicts keys with the shortest time-to-live first. Good for objects with varying but known lifetimes. |
| `allkeys-random` | Testing/Niche | Evicts random keys. Predictable but not efficient. |
| `volatile-random` | Testing/Niche | Evicts random keys *with an expiration set*. |
*   **`maxmemory-samples` (Default: 5):** The number of keys sampled for LRU/LFU eviction. Higher values are more accurate but use more CPU. 5 is a good balance. Increase to 10 for very strict LRU/LFU needs.
*   **RDB Persistence (`save`):** Snapshot-based. `save <seconds> <changes>`.
    *   Recommended for queues/durable data: `save 900 1`, `save 300 10`, `save 60 10000` (default, good balance).
*   **AOF Persistence (`appendonly yes`):** Append-only log of write operations.
    *   `appendfsync`:
        *   `always`: Safest, but very slow. `fsync()` on every write.
        *   `everysec`: **Recommended default.** `fsync()` once per second. Can lose up to 1s of data.
        *   `no`: Let the OS decide when to `fsync()`. Fastest, least safe.
*   **Hybrid RDB/AOF Persistence:**
    *   `aof-use-rdb-preamble yes`: **Best Practice & Default.** When rewriting the AOF, Valkey creates an RDB snapshot for the base and appends new writes. This makes the AOF file smaller and startup much faster.
*   **AOF Tuning:**
    *   `no-appendfsync-on-rewrite yes`: Prevents `fsync` from blocking the main thread during AOF rewrites, reducing latency spikes.
    *   `auto-aof-rewrite-percentage 100`: Trigger rewrite when AOF size is 100% larger than the previous size.
    *   `auto-aof-rewrite-min-size 64mb`: Don't trigger rewrites until AOF reaches this size.
*   **Async Deletion (`lazyfree`):**
    *   `lazyfree-lazy-eviction yes`: Evicted keys are freed in a background thread.
    *   `lazyfree-lazy-expire yes`: Expired keys are freed in a background thread.
    *   `lazyfree-lazy-server-del yes`: Keys deleted via `DEL` are freed in a background thread.
    *   **Recommendation:** Enable all three to reduce latency spikes from large key deletions.
*   **Active Defragmentation (`activedefrag yes`):** Allows Valkey to defragment memory at runtime without restart. It consumes some CPU. **Recommendation:** Enable on nodes with `mem_fragmentation_ratio > 1.5` and available CPU headroom. Start with `active-defrag-cycle-min 5` and `active-defrag-cycle-max 25` to be conservative.
*   **`hz` (Default: 10):** Frequency of background tasks (like key expiry). For workloads with many expiring keys or high client timeouts, increasing to `20` or even `50` can be beneficial. Increasing to `100` uses more CPU but offers more granular background task processing.

#### **5. Sentinel vs Cluster Mode for 2-Node K3s**
*   **Valkey Sentinel:** Provides High Availability (HA). A small group of `sentinel` processes monitor the master. If it fails, they elect a new master from the replicas.
    *   **Quorum:** A majority of Sentinels must agree on a failure. Quorum = `floor(N/2) + 1`.
    *   **2-Node Problem:** With 2 Sentinels, quorum is 2. If one node (with its Sentinel) fails, the remaining Sentinel cannot form a quorum and no failover will occur. **Minimum of 3 Sentinels on 3 failure domains (nodes) is required for automatic failover.**
*   **Valkey Cluster:** Provides sharding (horizontal scaling) *and* HA. Data is split across `16384` hash slots distributed among master nodes.
    *   **Minimum Nodes:** Requires a minimum of 3 master nodes for a stable cluster. Not suitable for our 2-node setup.
*   **Standalone with Velero:** A single master instance with persistence enabled.
    *   **HA:** No automatic failover. Downtime occurs if the node or pod fails. Recovery is manual.
    *   **Trade-offs:** Simple, low resource usage, perfectly acceptable for many workloads where a few minutes of RTO (Recovery Time Objective) is tolerable. Durability is high with AOF+RDB and Velero.
*   **Recommended Architecture for 2-Node K3s:** **Standalone master with AOF+RDB persistence enabled.** Backups are handled by Velero taking PVC snapshots. This is the most robust and pragmatic solution for a 2-node cluster.
*   **Future Path to Sentinel:** To upgrade, add a 3rd K3s node. Deploy Valkey with `architecture: replication`, `replica.replicaCount: 2`, and `sentinel.enabled: true`. The Sentinels can then be spread across the 3 nodes for a resilient quorum.

#### **9. Migration from Redis: Compatibility and Differences**
*   **Valkey 7.2 vs Redis 7.2:** Valkey is a fork of Redis 7.2.4. It is a **drop-in replacement**. All commands, the RESP3 protocol, data structures, and RDB/AOF file formats are identical at the point of the fork.
*   **Client Library Compatibility:**
    *   `ioredis` (n8n/BullMQ): **Fully compatible.** Works out of the box.
    *   `redis` (Python/redis-py): **Fully compatible.**
    *   `redis` (Ruby/redis-rb, for Postal/Sidekiq): **Fully compatible.**
    *   Generally, any client library compatible with Redis 7.2 will work with Valkey 7.2.
*   **Connection Strings:** Most libraries still use the `redis://` scheme. `valkey://` is an alias and may be adopted over time, but `redis://` is the safe, compatible choice.
    ```
    redis://<user>:<password>@<host>:<port>/<db>
    ```
*   **`redis-cli` vs `valkey-cli`:** They are interchangeable for connecting to a Valkey 7.2 server. In our K8s environment, the deployed container image will have `valkey-cli`, so `kubectl exec` commands should use `valkey-cli`.
*   **Future Divergence:** As of mid-2024, there are no major breaking changes. Valkey 8.0 plans to introduce features like more reliable slot migration. These will be opt-in and won't break existing 7.2 compatibility. The community focus is on stability and gradual, backward-compatible feature additions.
*   **Migration Path:**
    1.  Take a final `BGSAVE` on the old Redis instance.
    2.  Copy the `dump.rdb` file.
    3.  Deploy a new Valkey StatefulSet.
    4.  Copy the `dump.rdb` into the new Valkey pod's PVC (`/data/dump.rdb`).
    5.  Start the Valkey pod. It will load the data from the RDB file.
    6.  Update application connection strings/DNS to point to the new Valkey service.

***

### ## examples.md Content
This section contains concrete, copy-paste-ready configurations and commands for the Helix Stax environment.

#### **Valkey Helm Deployment: `values.yaml`**
This `values.yaml` is for the `bitnami/valkey` chart, configured for a production-ready standalone instance on our 2-node K3s cluster.

**1. Add the Bitnami Helm repo:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

**2. Create the `valkey-secret` with the master password.**
```bash
# Generate a strong password
VALKEY_MASTER_PASSWORD=$(openssl rand -base64 24)

# Create the secret in the 'valkey' namespace
kubectl create namespace valkey
kubectl create secret generic valkey -n valkey \
  --from-literal=valkey-password=$VALKEY_MASTER_PASSWORD

# Save this password to a password manager.
echo "Valkey Master Password: $VALKEY_MASTER_PASSWORD"
```

**3. Create `valkey-prod-values.yaml`:**
```yaml
# valkey-prod-values.yaml for bitnami/valkey
# Deploys a single, persistent Valkey master instance
#
architecture: standalone # "replication" for master/replica, not used on 2 nodes

# Set the same password from the k8s secret
auth:
  enabled: true
  password: "" # This is intentionally left blank
  passwordFromSecret:
    name: "valkey"
    key: "valkey-password"

# Master pod configuration
master:
  count: 1
  # Pin the master to the worker node to keep the CP free
  nodeSelector:
    kubernetes.io/hostname: helix-stax-vps

  # Resource requests and limits for a shared node
  # Start small and monitor usage with Grafana
  resources:
    requests:
      cpu: "100m"
      memory: "512Mi"
    limits:
      cpu: "1000m" # 1 vCPU
      memory: "2Gi"

  # Persistence using Hetzner CSI
  persistence:
    enabled: true
    storageClass: "hcloud-volumes" # Hetzner CSI storage class
    accessModes:
      - ReadWriteOnce
    size: 10Gi

# Liveness and Readiness probes
livenessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 15
  timeoutSeconds: 5
readinessProbe:
  enabled: true
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 1

# Valkey configuration directives
# See reference.md for full details
# This config is optimized for mixed use (queues + cache) with AOF persistence
masterConfiguration: |
  # -- Memory Management (Critical) --
  # Set maxmemory to ~75% of the container's memory limit (2Gi limit -> 1.5Gi maxmemory)
  maxmemory 1610612736
  # Use different policies per DB. We use ACL selectors for this.
  # Default policy if none is specified for a user
  maxmemory-policy noeviction

  # -- Persistence (AOF + RDB Hybrid) --
  appendonly yes
  appendfsync everysec
  aof-use-rdb-preamble yes
  # Default save points are fine for RDB snapshots
  save 900 1
  save 300 10
  save 60 10000
  no-appendfsync-on-rewrite yes
  auto-aof-rewrite-percentage 100
  auto-aof-rewrite-min-size 64mb

  # -- Performance & Latency --
  lazyfree-lazy-eviction yes
  lazyfree-lazy-expire yes
  lazyfree-lazy-server-del yes
  tcp-keepalive 300
  hz 20

  # -- Security --
  # Disable risky commands for the default user
  # We will use specific ACL users instead
  rename-command FLUSHDB ""
  rename-command FLUSHALL ""
  rename-command DEBUG ""

# Disable replica and sentinel, as we are running standalone on 2 nodes
replica:
  replicaCount: 0
sentinel:
  enabled: false

# For Velero backup. Annotate the PVC created by the StatefulSet.
# The StatefulSet name is `valkey-master` by default.
# The PVC name will be `data-valkey-master-0`.
persistence:
  # This annotation tells Velero to perform a filesystem-level snapshot of the PVC
  annotations:
    backup.velero.io/backup-volumes: data
```

**4. Deploy Valkey:**
```bash
helm upgrade --install valkey bitnami/valkey -n valkey -f valkey-prod-values.yaml
```

#### **Security: ACL User and Network Policy Setup**
We will create dedicated users for each service (`n8n`, `postal`) and a read-only user for monitoring.

**1. Create ACL Users and store passwords in secrets.**

```bash
# --- n8n User ---
# Access to DB 0 for queue operations
N8N_USER_PASSWORD=$(openssl rand -base64 24)
kubectl create secret generic valkey-acl-n8n -n valkey \
  --from-literal=username='n8n-user' \
  --from-literal=password="$N8N_USER_PASSWORD"
echo "n8n user password stored in secret 'valkey-acl-n8n' in namespace 'valkey'"

# --- Postal User ---
# Access to DB 1 for queue operations
POSTAL_USER_PASSWORD=$(openssl rand -base64 24)
kubectl create secret generic valkey-acl-postal -n valkey \
  --from-literal=username='postal-user' \
  --from-literal=password="$POSTAL_USER_PASSWORD"
echo "postal user password stored in secret 'valkey-acl-postal' in namespace 'valkey'"

# --- Monitoring User ---
# Read-only access for Prometheus exporter
MONITOR_USER_PASSWORD=$(openssl rand -base64 24)
kubectl create secret generic valkey-acl-monitor -n valkey \
  --from-literal=username='monitor-user' \
  --from-literal=password="$MONITOR_USER_PASSWORD"
echo "monitor user password stored in secret 'valkey-acl-monitor' in namespace 'valkey'"
```

**2. Apply ACL rules to the running Valkey instance.**

```bash
# Get master password and pod name
VALKEY_POD=$(kubectl -n valkey get pods -l "app.kubernetes.io/name=valkey,app.kubernetes.io/component=master" -o jsonpath="{.items[0].metadata.name}")
VALKEY_PASSWORD=$(kubectl -n valkey get secret valkey -o jsonpath="{.data.valkey-password}" | base64 -d)

# Set n8n user ACLs. Needs full access to DB 0, all keys.
# The 'allkeys' and '~*' grants full key access. 'select 0' restricts to DB 0.
# The policy 'noeviction' is critical for queues.
# Memory eviction policy is set via maxmemory-policy in valkey.conf, not via ACL rules
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD -- \
  ACL SETUSER n8n-user on ">$N8N_USER_PASSWORD" allkeys "~*" +@all -@dangerous "select 0" "reset"

# Set Postal user ACLs. Needs full access to DB 1.
# Memory eviction policy is set via maxmemory-policy in valkey.conf, not via ACL rules
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD -- \
  ACL SETUSER postal-user on ">$POSTAL_USER_PASSWORD" allkeys "~*" +@all -@dangerous "select 1" "reset"

# Set Monitoring user ACLs. Read-only commands.
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD -- \
  ACL SETUSER monitor-user on ">$MONITOR_USER_PASSWORD" +info +client +slowlog +config +cluster +ping "reset"

# Save the ACL configuration to disk inside the container
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD -- ACL SAVE
```
*Note: `ACL SAVE` writes to the `aclfile` specified in the Valkey config. The Bitnami chart configures this automatically.*

**3. Kubernetes Network Policy (`valkey-netpol.yaml`)**
This policy restricts traffic to the Valkey master pod. It allows ingress ONLY from:
1.  Pods in the `n8n` namespace.
2.  Pods in the `postal` namespace.
3.  Pods in the `monitoring` namespace (for Prometheus).

```yaml
# valkey-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: valkey-allow-app-traffic
  namespace: valkey
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: valkey
      app.kubernetes.io/component: master
  policyTypes:
    - Ingress
  ingress:
    - from:
        # Allow from n8n namespace
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: n8n
        # Allow from postal namespace
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: postal
        # Allow from monitoring namespace (for prometheus)
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 6379
```
**Apply the policy:**
```bash
kubectl apply -f valkey-netpol.yaml
```

#### **Monitoring: Prometheus Exporter and Grafana**

**1. Deploy `redis_exporter`** (works perfectly for Valkey)
We will deploy it as a separate deployment and service.

`redis-exporter-values.yaml`:
```yaml
# redis-exporter-values.yaml for prometheus-community/prometheus-redis-exporter
redisAddress: "valkey-master.valkey.svc.cluster.local:6379"

# Use the monitoring user ACL password
redisPasswordFromSecret:
  name: valkey-acl-monitor
  key: password
redisUserFromSecret:
  name: valkey-acl-monitor
  key: username

# Create a ServiceMonitor for Prometheus Operator to discover
serviceMonitor:
  enabled: true
  namespace: monitoring # Assuming Prometheus Operator runs here
  labels:
    release: prometheus # Match your Prometheus Operator selector
```

**Deploy the exporter:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install valkey-exporter prometheus-community/prometheus-redis-exporter \
  -n valkey \
  -f redis-exporter-values.yaml
```

**2. Grafana Dashboard**
*   Go to your Grafana instance.
*   Click on "Dashboards" -> "Import".
*   Use Grafana.com dashboard ID: **`15424`** (`Redis Exporter Dashboard`). It is one of the most comprehensive and works well with Valkey.
*   Select your Prometheus data source. Click "Import".

**3. Key Alertmanager Rules (`valkey-alerts.yaml`)**
```yaml
# valkey-alerts.yaml
groups:
  - name: valkey.rules
    rules:
      - alert: ValkeyMemoryHigh
        expr: (redis_memory_used_bytes / redis_maxmemory_bytes) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Valkey high memory usage on {{ $labels.instance }}"
          description: "Valkey memory usage is at {{ $value | printf \"%.2f\" }}% of maxmemory. Evictions may occur soon."
      - alert: ValkeyEvictingKeys
        expr: rate(redis_evicted_keys_total[5m]) > 0 AND on(instance) redis_db_keys{db="db0"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Valkey is evicting keys from the queue database (db0) on {{ $labels.instance }}"
          description: "Evictions are occurring on db0, which is used by n8n. This can lead to job data loss. Increase maxmemory or investigate memory usage immediately."
      - alert: ValkeyDown
        expr: redis_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Valkey instance is down on {{ $labels.instance }}"
          description: "The Valkey instance is unreachable by the exporter."
      - alert: ValkeyPersistenceFailure
        expr: redis_rdb_last_bgsave_status != "ok" or redis_aof_last_bgrewrite_status != "ok"
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Valkey persistence failed on {{ $labels.instance }}"
          description: "RDB save or AOF rewrite has been failing. Backups may be stale."
```

#### **Backup and Restore Runbook**

**Backup Procedure:**
1.  **AOF+RDB:** This is running continuously as configured.
2.  **Velero PVC Snapshot (Daily):** Velero is configured with a daily schedule that backs up all PVCs with the `backup.velero.io/backup-volumes` annotation, which we added in our `values.yaml`.

**Manual Velero Backup:**
```bash
# Trigger a manual backup of the valkey namespace
velero backup create valkey-manual-backup --include-namespaces valkey
```

**Verify Backup:**
```bash
# Check backup status
velero backup get valkey-manual-backup

# Check for RDB save time before backup
VALKEY_POD=$(kubectl -n valkey get pods -l "app.kubernetes.io/name=valkey,app.kubernetes.io/component=master" -o jsonpath="{.items[0].metadata.name}")
VALKEY_PASSWORD=$(kubectl -n valkey get secret valkey -o jsonpath="{.data.valkey-password}" | base64 -d)
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD BGSAVE
# Wait a few seconds
kubectl -n valkey exec -it $VALKEY_POD -- valkey-cli -a $VALKEY_PASSWORD LASTSAVE
```

**Restore Procedure (from Velero Snapshot):**
This is a full disaster recovery scenario where the `valkey` namespace or its PVC is lost.

1.  **Identify the backup to restore:**
    ```bash
    velero backup get
    ```

2.  **Delete the broken Valkey Helm release (if it still exists) to prevent conflicts.**
    ```bash
    helm uninstall valkey -n valkey
    # Manually delete the PVC if it wasn't removed
    kubectl -n valkey delete pvc data-valkey-master-0
    ```

3.  **Restore the entire namespace from the backup:**
    ```bash
    velero restore create valkey-restore --from-backup <your-backup-name> --include-namespaces valkey
    ```
4.  **Verify Restore:**
    ```bash
    # Check restore status
    velero restore get valkey-restore
    # Check if the pod and PVC are back
    kubectl -n valkey get pod,pvc
    # Wait for pod to become ready, then test connection and data
    ```

**Testing Restore without Affecting Production:**
1.  **Restore to a new namespace:**
    ```bash
    velero restore create valkey-test-restore \
      --from-backup <your-backup-name> \
      --include-namespaces valkey \
      --namespace-mappings valkey:valkey-test
    ```

2.  **A new `valkey-test` namespace will be created with the restored resources.** You can now exec into the test pod and verify data integrity without touching the production instance.

3.  **Cleanup:**
    ```bash
    kubectl delete namespace valkey-test
    ```
