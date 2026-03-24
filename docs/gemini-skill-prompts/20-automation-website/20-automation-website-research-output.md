Of course. Here is the comprehensive research document formatted for use by your AI agents, based on the Helix Stax infrastructure and best practices.

# Part 1: Automation Services

# n8n

### ## SKILL.md Content

This document provides the core operational knowledge for deploying, managing, and developing on n8n within the Helix Stax K3s environment.

**1. K3s Deployment (Helm)**

- **Update Helm Repo:**
  ```bash
  helm repo add n8n https://helm.n8n.io/
  helm repo update
  ```

- **Install/Upgrade Command (using values from `examples.md`):**
  ```bash
  helm upgrade --install n8n n8n/n8n \
    --namespace n8n --create-namespace \
    -f n8n-values.yaml
  ```

- **Core `values.yaml` Snippet (for external DB/Queue):**
  ```yaml
  n8n:
    # Use external secrets for credentials (populated by OpenBao)
    envFrom:
      - secretRef:
          name: n8n-secrets # Contains DB creds, encryption key etc.
    # Main process config
    env:
      - name: N8N_HOST
        value: "n8n.helixstax.net"
      - name: WEBHOOK_URL
        value: "https://n8n.helixstax.net/"
      - name: N8N_EDITOR_BASE_URL
        value: "https://n8n.helixstax.net/"
      - name: EXECUTIONS_MODE
        value: "queue" # Use worker mode
      - name: DB_TYPE
        value: "postgresdb"
      - name: QUEUE_BULL_REDIS_HOST
        value: "valkey-master.valkey.svc.cluster.local" # Or Valkey service name
      - name: N8N_AUTH_ENABLED
        value: "true"
      - name: N8N_AUTH_PROVIDER
        value: "oidc"
    # OIDC config using Zitadel
    oidc:
      authUrl: "https://zitadel.helixstax.net/oauth/v2/authorize"
      tokenUrl: "https://zitadel.helixstax.net/oauth/v2/token"
      userInfoUrl: "https://zitadel.helixstax.net/oidc/v1/userinfo"
      logoutUrl: "https://zitadel.helixstax.net/oidc/v1/end_session"
      clientId: "<ZITADEL_CLIENT_ID>" # From OpenBao
      clientSecret: "<ZITADEL_CLIENT_SECRET>" # From OpenBao
      scopes: "openid profile email"
      emailClaim: "email"

  # Worker deployment config
  workers:
    enabled: true
    replicas: 2
    envFrom:
      - secretRef:
          name: n8n-secrets
  ```

- **IngressRoute for `n8n.helixstax.net`:**
  ```yaml
  apiVersion: traefik.io/v1alpha1
  kind: IngressRoute
  metadata:
    name: n8n-ingress
    namespace: n8n
  spec:
    entryPoints:
      - websecure
    routes:
      - match: Host(`n8n.helixstax.net`)
        kind: Rule
        services:
          - name: n8n # Helm chart service name
            port: 5678
    tls:
      secretName: n8n-origin-ca-tls # Cloudflare Origin CA cert
  ```

**2. Core Workflow Development**

- **Node Types:**
  - **Trigger:** Starts a workflow (Webhook, Schedule, Error Trigger).
  - **Action:** Performs a task (HTTP Request, Execute Workflow).
  - **Logic:** Controls flow (IF, Switch, Merge, Set).

- **Core Nodes:**
  - **Webhook:** Entry point for APIs. Test URL is temporary; Production URL is permanent.
  - **HTTP Request:** Call external APIs (Ollama, ClickUp). Use credentials from Credential Store.
  - **Code:** Run custom JS/Python. `return $items(data)` to pass items along.
  - **IF/Switch:** Route data based on conditions. e.g., `{{ $json.status === "success" }}`.
  - **Set:** Create/modify fields. `Keep Only Set` to prune data.
  - **Execute Workflow:** Call a sub-workflow. Essential for reusable logic.
  - **Error Trigger:** A separate workflow that catches all unhandled errors from other active workflows.

- **Common Expressions:**
  - `{{ $json.some_field }}`: Access a field from the current node's input.
  - `{{ $node["Webhook"].json.body.id }}`: Access data from a specific previous node.
  - `{{ $items() }}`: Get all input items as an array (useful in Code node).
  - `{{ $now }}`: Current timestamp. Format: `{{ $now.toFormat('yyyy-MM-dd') }}`.

- **Looping:** Use `SplitInBatches` node with batch size 1 to process each item in an array individually.

**3. Troubleshooting Decision Tree**

- **Symptom:** Webhook not triggering.
  - **Cause 1:** `WEBHOOK_URL` in n8n config is wrong.
    - **Fix:** Ensure it's `https://n8n.helixstax.net/`. Restart n8n pods.
  - **Cause 2:** Traefik IngressRoute misconfigured.
    - **Fix:** Verify `Host()` rule and `secretName`. Check Traefik logs for TLS/routing errors.
  - **Cause 3:** Cloudflare blocking the request.
    - **Fix:** Check Cloudflare WAF events for `n8n.helixstax.net`.

- **Symptom:** Workflow execution fails.
  - **Cause 1:** Incorrect expression.
    - **Fix:** Open failed execution, click the red-flagged node, check Input/Output tabs. Re-evaluate expression.
  - **Cause 2:** Authentication failure in HTTP Request node.
    - **Fix:** Check credential selection. Verify the token/key in OpenBao is correct and has not expired.
  - **Cause 3:** Node timed out.
    - **Fix:** Increase timeout in that node's settings or optimize the upstream API call.

- **Symptom:** n8n pods `CrashLoopBackOff`.
  - **Cause 1:** Cannot connect to PostgreSQL or Valkey.
    - **Fix:** `kubectl logs -n n8n <pod-name>`. Check for connection refused errors. Verify service names and network policies.
  - **Cause 2:** `N8N_ENCRYPTION_KEY` is missing or changed.
    - **Fix:** Ensure the `n8n-secrets` Kubernetes Secret exists and contains the correct, consistent key. Revert to old key if changed.

### ## reference.md Content

**1. K3s Deployment - Complete Values Reference**

```yaml
# values.yaml for n8n/n8n Helm Chart (Production)

n8n:
  # Base n8n environment variables
  env:
    # -- Domain and URL Configuration --
    - name: N8N_HOST
      value: "n8n.helixstax.net"
    - name: WEBHOOK_URL
      value: "https://n8n.helixstax.net/" # Must have trailing slash
    - name: N8N_EDITOR_BASE_URL
      value: "https://n8n.helixstax.net/"
    
    # -- Execution and Scaling --
    - name: EXECUTIONS_MODE
      value: "queue" # Required for worker mode
    - name: EXECUTIONS_PROCESS
      value: "main" # This pod will handle webhooks/UI, not executions

    # -- Database Configuration (CloudNativePG) --
    - name: DB_TYPE
      value: "postgresdb"
    - name: DB_POSTGRESDB_HOST
      valueFrom:
        secretKeyRef:
          name: n8n-db-creds # Secret created by CloudNativePG
          key: host
    - name: DB_POSTGRESDB_PORT
      valueFrom:
        secretKeyRef:
          name: n8n-db-creds
          key: port
    - name: DB_POSTGRESDB_DATABASE
      valueFrom:
        secretKeyRef:
          name: n8n-db-creds
          key: dbname
    - name: DB_POSTGRESDB_USER
      valueFrom:
        secretKeyRef:
          name: n8n-db-creds
          key: user
    - name: DB_POSTGRESDB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: n8n-db-creds
          key: password
    - name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
      value: "false" # Adjust if using internal TLS for DB

    # -- Queue Configuration (Valkey/Redis) --
    - name: QUEUE_BULL_REDIS_HOST
      value: "valkey-cluster.valkey.svc.cluster.local" # FQDN of Valkey service
    - name: QUEUE_BULL_REDIS_PORT
      value: "6379"
    - name: QUEUE_BULL_REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: valkey-creds # Secret for Valkey password
          key: password

    # -- Security and SSO (Zitadel OIDC) --
    - name: N8N_ENCRYPTION_KEY # CRITICAL: MUST be consistent
      valueFrom:
        secretKeyRef:
          name: n8n-encryption-key
          key: key
    - name: N8N_AUTH_ENABLED
      value: "true"
    - name: N8N_AUTH_PROVIDER
      value: "oidc"
    # OIDC vars are now in a dedicated section:
    oidc:
      authUrl: "https://zitadel.helixstax.net/oauth/v2/authorize"
      tokenUrl: "https://zitadel.helixstax.net/oauth/v2/token"
      userInfoUrl: "https://zitadel.helixstax.net/oidc/v1/userinfo"
      logoutUrl: "https://zitadel.helixstax.net/oidc/v1/end_session"
      clientId: "<ZITADEL_CLIENT_ID>"
      clientSecret: "<ZITADEL_CLIENT_SECRET>"
      scopes: "openid profile email"
      emailClaim: "email"
      
    # -- Logging and Monitoring --
    - name: N8N_LOG_LEVEL
      value: "info"
    - name: N8N_LOG_OUTPUT
      value: "json" # For Loki/structured logging
    - name: N8N_METRICS_ENABLED
      value: "true"
    - name: N8N_METRICS_PORT
      value: "9102"
    
    # -- Community Nodes --
    - name: N8N_COMMUNITY_PACKAGES_ENABLED
      value: "true"
    - name: NODE_FUNCTION_ALLOW_EXTERNAL
      value: "n8n-nodes-minio,n8n-nodes-langchain" # Comma-separated list

  # Persistence for user data and SQLite backup (even with PG, it stores some files)
  persistence:
    enabled: true
    size: 5Gi
    storageClass: "longhorn" # Or your cluster's default

  # Kubernetes resource requests & limits
  resources:
    requests:
      cpu: "250m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  # Rolling update strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

# Worker configuration
workers:
  enabled: true
  replicas: 2
  env:
    - name: EXECUTIONS_PROCESS
      value: "worker" # This pod only processes jobs from the queue
  # Workers need the same creds and keys as main
  envFrom:
    - secretRef:
        name: n8n-db-creds
    - secretRef:
        name: n8n-encryption-key
  resources:
    requests:
      cpu: "500m"
      memory: "1.5Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

**2. Main vs. Worker Mode Architecture**

- **Main Mode (`EXECUTIONS_PROCESS=main`):** A single process handles everything: UI, API, webhooks, and workflow executions.
  - **When to use:** Simple setups, low-to-medium workflow volume.
  - **Downside:** A long-running execution can block the UI or cause timeouts for webhooks. Not horizontally scalable for executions.
- **Queue Mode (`EXECUTIONS_MODE=queue`):**
  - **Main Pod (`EXECUTIONS_PROCESS=main`):** Handles UI, API, webhook registration. When a workflow is triggered, it pushes an execution job to the queue (Valkey).
  - **Worker Pods (`EXECUTIONS_PROCESS=worker`):** These pods listen to the queue, pick up jobs, and execute them. They do not expose any ports.
  - **When to use:** Production. This is our setup.
  - **Scaling:** To handle more concurrent executions, increase `workers.replicas` in `values.yaml`. This is horizontal scaling.

**3. n8n API Reference (for Claude Code Agents)**

- **Authentication:** `X-N8N-API-KEY: <API_KEY>` header. Generate keys in n8n under Settings -> API.
- **Endpoints:**
  - `GET /api/v1/workflows`: List all workflows.
  - `GET /api/v1/workflows/{id}`: Get a single workflow's JSON structure.
  - `POST /api/v1/workflows`: Create a new workflow.
  - `POST /api/v1/workflows/{id}/activate`: Activate a workflow.
  - `POST /api/v1/workflows/{id}/deactivate`: Deactivate a workflow.
  - `GET /api/v1/executions`: List past executions. Filter with query params: `?status=failed`.
  - `GET /api/v1/executions/{id}`: Get details of a single execution.
  - `POST /api/v1/executions/{id}/retry`: Retry a failed execution.

**4. Monitoring and Logging**

- **Prometheus Metrics:**
  - Enable with `N8N_METRICS_ENABLED=true`.
  - Exposed on port `9102` (configurable with `N8N_METRICS_PORT`).
  - Scrape with a `PodMonitor` CRD targeting `app.kubernetes.io/name=n8n`.
- **Key Metrics:**
  - `n8n_workflows_executions_total`: Total executions count.
  - `n8n_workflows_executions_running`: Current running executions.
  - `n8n_workflows_executions_time_seconds`: Histogram of execution duration.
  - **Valkey Queue Metrics (via Valkey exporter):** `redis_list_length` for `bull:*:wait` keys shows queue depth.
- **Grafana:** Use the official "n8n stats" dashboard (ID 14435) as a starting point.
- **Logging:**
  - Set `N8N_LOG_OUTPUT=json` for structured logs.
  - Promtail/Loki can directly ingest this format.
  - Logs from main and worker pods should be aggregated.

**5. Credential Management**

- **Encryption:** All credentials created in the n8n UI are encrypted at rest in the PostgreSQL database using the `N8N_ENCRYPTION_KEY`. Loss of this key means loss of all credentials.
- **Export/Import:** Credentials can be exported/imported as JSON via the UI, but they will be encrypted. To move them, you need the same `N8N_ENCRYPTION_KEY` on the destination instance.
- **Environment Variable Credentials:** For credentials that must not touch the n8n DB (e.g., from a security policy), you can reference environment variables directly in credential fields: `{{ $env.SOME_SECRET }}`. This is less secure if the pod env can be inspected. The recommended pattern is using the UI with secrets sourced from OpenBao.

### ## examples.md Content

**1. Full `n8n-values.yaml` for Helix Stax**

This file is used with `helm upgrade --install n8n n8n/n8n -f n8n-values.yaml`.

```yaml
# n8n-values.yaml
# Production configuration for n8n on helix-stax-k3s cluster

# Ingress: disabled — use a separate Traefik IngressRoute manifest instead
# (Kubernetes Ingress resources are not used; Traefik IngressRoute CRDs are the standard)
ingress:
  enabled: false

# Deploy this IngressRoute separately (not part of Helm values):
# apiVersion: traefik.io/v1alpha1
# kind: IngressRoute
# metadata:
#   name: n8n-ingress
#   namespace: n8n
# spec:
#   entryPoints:
#     - websecure
#   routes:
#     - match: Host(`n8n.helixstax.net`)
#       kind: Rule
#       services:
#         - name: n8n
#           port: 5678
#   tls:
#     secretName: n8n-origin-ca-tls # Cloudflare Origin CA cert

# n8n main application configuration
n8n:
  image:
    # Pinning a specific version for stability. Update with care.
    repository: n8nio/n8n
    tag: "1.37.3" # Check for latest stable version
  
  # Inject secrets from Kubernetes Secret 'n8n-zitadel-oidc-creds'
  # This secret is managed by OpenBao External Secrets Operator
  envFrom:
    - secretRef:
        name: n8n-zitadel-oidc-creds

  env:
    # -- Base URLs --
    - name: N8N_HOST
      value: "n8n.helixstax.net"
    - name: WEBHOOK_URL
      value: "https://n8n.helixstax.net/"
    - name: N8N_EDITOR_BASE_URL
      value: "https://n8n.helixstax.net/"

    # -- Mode & Backend Config --
    - name: EXECUTIONS_MODE
      value: "queue"
    - name: EXECUTIONS_PROCESS
      value: "main"
    - name: DB_TYPE
      value: "postgresdb"
    - name: QUEUE_BULL_REDIS_HOST
      value: "valkey-cluster.valkey.svc.cluster.local"
    - name: QUEUE_BULL_REDIS_PORT
      value: "6379"

    # -- Secrets from OpenBao via ExternalSecrets --
    - name: DB_POSTGRESDB_HOST
      valueFrom: { secretKeyRef: { name: n8n-db-connection, key: host } }
    - name: DB_POSTGRESDB_PORT
      valueFrom: { secretKeyRef: { name: n8n-db-connection, key: port } }
    - name: DB_POSTGRESDB_DATABASE
      valueFrom: { secretKeyRef: { name: n8n-db-connection, key: dbname } }
    - name: DB_POSTGRESDB_USER
      valueFrom: { secretKeyRef: { name: n8n-db-connection, key: user } }
    - name: DB_POSTGRESDB_PASSWORD
      valueFrom: { secretKeyRef: { name: n8n-db-connection, key: password } }
    - name: QUEUE_BULL_REDIS_PASSWORD
      valueFrom: { secretKeyRef: { name: valkey-cluster-password, key: password } }
    - name: N8N_ENCRYPTION_KEY
      valueFrom: { secretKeyRef: { name: n8n-encryption-key, key: key } }

    # -- OIDC Configuration (n8n supports it natively) --
    - name: N8N_AUTH_ENABLED
      value: "true"
    - name: N8N_AUTH_PROVIDER
      value: "oidc"
    - name: N8N_OIDC_CLIENT_ID
      valueFrom: { secretKeyRef: { name: n8n-zitadel-oidc-creds, key: ZITADEL_CLIENT_ID } }
    - name: N8N_OIDC_CLIENT_SECRET
      valueFrom: { secretKeyRef: { name: n8n-zitadel-oidc-creds, key: ZITADEL_CLIENT_SECRET } }
    - name: N8N_OIDC_AUTH_URL
      value: "https://zitadel.helixstax.net/oauth/v2/authorize"
    - name: N8N_OIDC_TOKEN_URL
      value: "https://zitadel.helixstax.net/oauth/v2/token"
    - name: N8N_OIDC_USERINFO_URL
      value: "https://zitadel.helixstax.net/oidc/v1/userinfo"
    # Note: n8n constructs the .well-known URL itself.

    # -- Monitoring & Logging --
    - name: N8N_METRICS_ENABLED
      value: "true"
    - name: N8N_LOG_OUTPUT
      value: "json"
    
  # User data persistence
  persistence: { enabled: true, size: 5Gi, storageClass: "longhorn" }
  resources: { requests: { memory: "1Gi", cpu: "250m" }, limits: { memory: "2Gi", cpu: "1" } }

# Worker configuration
workers:
  enabled: true
  replicas: 2
  env:
    - name: EXECUTIONS_PROCESS
      value: "worker"
  envFrom: 
    - secretRef: { name: n8n-db-connection }
    - secretRef: { name: n8n-encryption-key }
    - secretRef: { name: valkey-cluster-password }
  resources: { requests: { memory: "1.5Gi", cpu: "500m" }, limits: { memory: "4Gi", cpu: "2" } }

# Disable PostgreSQL from this chart, we use CloudNativePG
postgresql:
  enabled: false
# Disable Redis from this chart, we use Valkey
redis:
  enabled: false
```

**2. Workflow Example: ArgoCD Webhook -> Rocket.Chat Notification**

This JSON can be imported directly into the n8n UI.

```json
{
  "name": "ArgoCD Sync Status to RocketChat",
  "nodes": [
    {
      "parameters": {
        "path": "argocd-sync-status-fh34fg",
        "options": {}
      },
      "id": "1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [450, 300]
    },
    {
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "{{ $json.body.application }}",
              "operation": "contains",
              "value2": "helix-stax"
            }
          ]
        }
      },
      "id": "2",
      "name": "IF: Helix Stax App?",
      "type": "n8n-nodes-base.if",
      "typeVersion": 1,
      "position": [650, 300]
    },
    {
      "parameters": {
        "url": "https://chat.helixstax.net/hooks/xxxxxxxx/yyyyyyyy",
        "options": {},
        "bodyParameters": {
          "parameters": [
            {
              "name": "text",
              "value": "✅ ArgoCD Sync Success: `{{ $json.body.application }}` sync status is `{{ $json.body.status }}`. Deployed commit: `{{ $json.body.commit }}`"
            }
          ]
        }
      },
      "id": "3",
      "name": "Post Success to RC",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.1,
      "position": [850, 200],
      "credentials": {}
    },
    {
      "parameters": {
        "url": "https://chat.helixstax.net/hooks/xxxxxxxx/yyyyyyyy",
        "options": {},
        "bodyParameters": {
          "parameters": [
            {
              "name": "text",
              "value": "🔥 ArgoCD Sync FAILED: `{{ $json.body.application }}` sync status is `{{ $json.body.status }}`. Check ArgoCD dashboard! <https://argo.helixstax.net>"
            }
          ]
        }
      },
      "id": "4",
      "name": "Post Failure to RC",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.1,
      "position": [850, 400],
      "credentials": {}
    }
  ],
  "connections": {
    "Webhook": { "main": [ [ { "node": "IF: Helix Stax App?", "type": "main" } ] ] },
    "IF: Helix Stax App?": {
      "main": [
        [ { "node": "Post Success to RC", "type": "main", "index": 0 } ],
        [ { "node": "Post Failure to RC", "type": "main", "index": 1 } ]
      ]
    }
  },
  "active": true,
  "settings": {},
  "id": "1"
}
```
**Webhook URL:** `https://n8n.helixstax.net/webhook/argocd-sync-status-fh34fg`
**Note:** The `IF` node condition should be `{{ $json.body.status === "Succeeded" }}`. The `IF` node in the example above branches on success/failure to different output pins.

**3. Runbook: Backing Up Workflows to Git**

This process uses the n8n API to backup all workflows. This should be a cron-based workflow within n8n itself.

1.  **Create an n8n API Key:** In n8n UI -> Settings -> API. Store this in OpenBao.
2.  **Create a Git Personal Access Token:** For GitHub, with `repo` scope. Store this in OpenBao.
3.  **Create a new n8n Workflow:**
    *   **Node 1: Schedule Trigger:** Run every 24 hours.
    *   **Node 2: HTTP Request (List Workflows):**
        *   Method: `GET`
        *   URL: `https://n8n.helixstax.net/api/v1/workflows`
        *   Authentication: `Header Auth`, use the n8n API key. Name it `X-N8N-API-KEY`.
    *   **Node 3: Code (Format for Git):**
        *   Language: JavaScript
        *   Code:
          ```javascript
          const workflows = $items();
          const commitFiles = workflows.map(workflow => {
            const content = JSON.stringify(workflow.json, null, 2);
            return {
              path: `n8n-workflows/${workflow.json.name.replace(/[\/\\?%*:|"<>]/g, '-')}.json`, // Sanitize filename
              content: Buffer.from(content).toString('base64'),
              encoding: 'base64'
            };
          });

          // This assumes using a community node for GitHub commit
          // Or build the API call yourself in the next node.
          return commitFiles;
          ```
    *   **Node 4: HTTP Request (Commit to GitHub):**
        *   Use a community node or craft a call to the GitHub API (`POST /repos/{owner}/{repo}/git/commits`) to commit the files.

---

# Cloudflare Origin CA Certificate Management

### ## SKILL.md Content

This document outlines the manual management of Cloudflare Origin CA certificates for TLS termination at Traefik. **We do not use cert-manager or Let's Encrypt.**

**1. Architecture Overview**

- **Path:** Client -> Cloudflare Edge (Public TLS) -> Encrypted Link -> Traefik on K3s (Origin CA TLS)
- **Cloudflare Mode:** Must be **Full (Strict)**. This is mandatory.
- **Certificate:** One wildcard certificate for `*.helixstax.com` and `*.helixstax.net`.
- **Validity:** 15 years. Renewal is a manual process scheduled for ~2039.
- **Trust:** These certificates are only trusted by Cloudflare proxies. Direct access to the origin IP will show a browser security warning.

**2. Generating a New Certificate (Infrequent Task)**

1.  Go to Cloudflare Dashboard -> `helixstax.com` -> SSL/TLS -> Origin Server.
2.  Click "Create Certificate".
3.  Select "Generate private key and CSR with Cloudflare".
4.  **Domains:** `helixstax.com`, `*.helixstax.com`, `helixstax.net`, `*.helixstax.net`.
5.  **Validity:** 15 years.
6.  Click "Create".
7.  **IMMEDIATELY** copy the **Origin Certificate** and **Private Key**. Store the Private Key in OpenBao under `secret/data/infra/cloudflare-origin-ca`. The key is shown only once.

**3. Installing Certificate as a Kubernetes Secret**

- **Prerequisites:** You have `origin-cert.pem` and `origin-key.key` files.
- **Command:** Create the secret in a namespace accessible by Traefik, e.g., `kube-system`.
  ```bash
  kubectl create secret tls cloudflare-origin-ca \
    --cert=path/to/origin-cert.pem \
    --key=path/to/origin-key.key \
    -n kube-system # Or a dedicated 'tls' namespace
  ```

**4. Using the Certificate in Traefik**

- **Default Certificate (TLSStore):** The best practice is to set this as the default cert for all IngressRoutes.
  ```yaml
  # traefik-tls-store.yaml
  apiVersion: traefik.io/v1alpha1
  kind: TLSStore
  metadata:
    name: default
    namespace: kube-system
  spec:
    defaultCertificate:
      secretName: cloudflare-origin-ca
  ```
- **Per-IngressRoute (if not using TLSStore):**
  ```yaml
  # my-app-ingressroute.yaml
  apiVersion: traefik.io/v1alpha1
  kind: IngressRoute
  metadata:
    name: my-app
    namespace: my-app-ns
  spec:
    entryPoints: ["websecure"]
    routes:
      - match: Host(`app.helixstax.net`)
        ...
    tls:
      secretName: app-origin-ca-tls # Cloudflare Origin CA cert
      # IMPORTANT: If the secret is in another namespace, you must use a
      # cross-namespace reference (via TLSStore) or duplicate the secret.
      # The above example assumes the secret is in the same namespace or
      # Traefik is configured to read from kube-system.
  ```

**5. Troubleshooting**

- **Symptom:** Browser shows "SSL Error" or "Invalid Certificate".
  - **Cause 1:** Your Cloudflare DNS record is "DNS Only" (grey cloud).
    - **Fix:** Enable the "Proxied" (orange cloud) setting for that DNS record. Origin CA is only valid for proxied traffic.
  - **Cause 2:** Cloudflare SSL/TLS mode is not "Full (Strict)".
    - **Fix:** In Cloudflare dashboard, set SSL/TLS to "Full (Strict)".

- **Symptom:** Traefik logs show "certificate not found" for an IngressRoute.
  - **Cause 1:** `secretName` in `IngressRoute.spec.tls` is misspelled.
    - **Fix:** Check spelling. IngressRoute `secretName` must match the secret in its namespace (e.g., `<service>-origin-ca-tls`, or omit `tls.secretName` to use the cluster-wide TLSStore default).
  - **Cause 2:** The Secret and IngressRoute are in different namespaces.
    - **Fix:** Create the secret in the same namespace as the IngressRoute, or configure Traefik to use a TLSStore that references the secret from a central namespace like `kube-system`.

### ## reference.md Content

**1. Architecture Deep Dive**

The TLS handshake is split into two distinct legs:

```
              [Public CA Trust]           [Cloudflare Private CA Trust]
+--------+    TLS Handshake 1    +------------+    TLS Handshake 2    +-----------+
| Client | <------------------> | Cloudflare | <------------------> |  Traefik  |
| Browser|   (e.g., Let's Enc)  |    Edge    | (Cloudflare Origin CA) |  on K3s   |
+--------+                      +------------+                      +-----------+
```

- **Leg 1 (Client to Cloudflare):** Cloudflare manages this using publicly trusted certificates (e.g., from Google Trust Services, Let's Encrypt). This is what the end-user's browser sees and trusts. No configuration is needed from our side other than enabling proxying.
- **Leg 2 (Cloudflare to Traefik):** This traffic traverses the internet to our Hetzner origin server (`178.156.233.12`). To ensure it's encrypted and authenticated, Traefik presents the Cloudflare Origin CA certificate. Cloudflare's edge servers are configured to trust their own Origin Certificate Authority, so they accept this certificate as valid.

**2. Security Anti-Patterns and Gotchas**

- **Critical:** Never use "Flexible" SSL mode. This sends unencrypted HTTP traffic from Cloudflare to the origin, defeating the purpose of TLS.
- **Critical:** Never expose the Origin CA private key publicly. It should live only in your local machine during creation and then immediately in OpenBao.
- **Anti-Pattern:** Using the Origin CA cert for any service that is not proxied by Cloudflare. For example, if you have an internal tool accessed by IP, it should use an internal certificate issued by the OpenBao PKI engine, not the Cloudflare Origin CA cert.
- **Wildcard Limitation:** A wildcard `*.helixstax.com` covers `app.helixstax.com` and `n8n.helixstax.com`, but it does **NOT** cover `nested.app.helixstax.com` (second-level subdomains). For those, you would need to add `*.app.helixstax.com` to a new certificate or use a specific hostname. Our current cert covers the root and first-level subdomains for both `.com` and `.net`.

**3. Verification Commands**

- **Check Secret Contents:**
  ```bash
  # Check if the secret exists and what it contains
  kubectl get secret cloudflare-origin-ca -n kube-system -o yaml

  # Decode the certificate data to verify its details
  kubectl get secret cloudflare-origin-ca -n kube-system -o jsonpath='{.data.tls\.crt}' | base64 --decode | openssl x509 -text -noout
  ```

- **Verify Origin is Presenting Correct Cert (from an external machine):**
  This command connects directly to the server IP but tells it we're looking for `n8n.helixstax.net` (using SNI). It will show an error about the certificate authority being unknown, which is *expected*. The important part is the `Issuer` and `Subject`.
  ```bash
  echo | openssl s_client -connect 178.156.233.12:443 -servername n8n.helixstax.net 2>/dev/null | openssl x509 -noout -issuer -subject -dates
  ```
  - **Expected Output:**
    ```
    issuer=C = US, ST = California, L = San Francisco, O = "Cloudflare, Inc.", CN = Cloudflare Origin CA
    subject=CN = cloudflare-origin-certificate, OU = "Cloudflare Origin, Inc.", O = "Cloudflare, Inc."
    notBefore=...
    notAfter=... (a date ~15 years in the future)
    ```

**4. Integration with OpenBao PKI**

- **Cloudflare Origin CA:** For **North-South** traffic (from internet to cluster), proxied by Cloudflare. Long-lived, manually managed.
- **OpenBao PKI:** For **East-West** traffic (service-to-service inside the cluster). Short-lived (e.g., 72h), automatically renewed by `cert-manager` or a similar tool. This is used for mTLS within a service mesh (like Istio/Linkerd) or for securing direct pod-to-pod communication over HTTPS.
- **Decision:**
  - If traffic is coming from the public internet via a `*.helixstax.com` or `*.helixstax.net` domain: Use Cloudflare Origin CA via Traefik.
  - If `service-a` in the cluster is calling `service-b.default.svc.cluster.local` over HTTPS: Use an internal certificate from OpenBao PKI.

### ## examples.md Content

**1. Runbook: Initial Setup of `cloudflare-origin-ca` Secret**

**Scenario:** You have just generated `origin-cert.pem` and `origin-key.key` from the Cloudflare dashboard.

1.  **Store Key in OpenBao:**
    ```bash
    # Ensure you have the key content in your clipboard or a file
    bao kv put secret/infra/cloudflare-origin-ca private_key=@/path/to/origin-key.key
    ```

2.  **Create the Kubernetes Secret:** For cluster-wide use, place it in `kube-system`.
    ```bash
    kubectl create secret tls cloudflare-origin-ca \
      --cert=./origin-cert.pem \
      --key=./origin-key.key \
      --namespace=kube-system

    # Verify creation
    kubectl get secret cloudflare-origin-ca -n kube-system
    # NAME                   TYPE                DATA   AGE
    # cloudflare-origin-ca   kubernetes.io/tls   2      5s
    ```

3.  **Delete Local Key File:**
    ```bash
    rm ./origin-key.key
    ```
    The private key should now only exist in OpenBao. The `.pem` file is public and can be kept.

**2. Example: Traefik `TLSStore` for Cluster-Wide Default**

This CRD tells Traefik to use our Origin CA certificate for any `IngressRoute` requesting TLS that doesn't specify its own `secretName`.

```yaml
# traefik-default-tlsstore.yaml
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default
  # IMPORTANT: The namespace must match what Traefik's RBAC allows it to read from.
  # If Traefik is in 'traefik' namespace, but cert is in 'kube-system',
  # ensure Traefik's ClusterRole has 'get','watch','list' on Secrets in 'kube-system'.
  # For simplicity, putting this in Traefik's namespace is also an option.
  namespace: kube-system
spec:
  defaultCertificate:
    secretName: cloudflare-origin-ca # This secret must exist in this same namespace (kube-system)
```
**Apply this manifest alongside your Traefik Helm installation.**

**3. Example: `IngressRoute` Relying on the Default `TLSStore`**

This `IngressRoute` for `argo.helixstax.net` is simpler because it omits the `tls` block. Traefik will automatically use the default certificate from the `TLSStore`.

```yaml
# argocd-ingress.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argo.helixstax.net`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
  # No 'tls:' section needed here. Traefik uses the default from the TLSStore.
  # This only works if Traefik is started with `--providers.kubernetescrd.tlsstore=default@kube-system`
  # or similar config telling it where to find the store.
```

---

# Flannel CNI

### ## SKILL.md Content

This document covers the Flannel CNI as bundled with K3s in the Helix Stax cluster.

**1. Architecture & Installation**

- **Type:** VXLAN Overlay Network.
- **Function:** Creates a virtual Layer 2 network over the existing Hetzner L3 private network. Pod traffic is encapsulated in UDP packets on port `8472`.
- **Installation:** Bundled with K3s. No separate installation is needed. K3s server is started with `--flannel-backend=vxlan` by default.
- **Components:** A `kube-flannel-ds` DaemonSet runs on every node in the `kube-system` namespace. Each pod runs the `flanneld` process.

**2. Network Configuration**

- **Pod CIDR:** `10.42.0.0/16` (K3s default). Each node gets a `/24` subnet (e.g., `10.42.1.0/24`).
- **Service CIDR:** `10.43.0.0/16` (K3s default).
- **Hetzner Firewall:** The Hetzner firewall for the private network interface MUST allow **UDP port 8472** between all cluster nodes. This is critical for cross-node pod communication.
- **MTU:** Hetzner physical NIC MTU is `1450`. VXLAN adds 50 bytes of overhead. Flannel automatically sets the `flannel.1` interface MTU to `1400`. Do not change this unless you have a specific reason.

**3. Key Limitation: No NetworkPolicy Enforcement**

- **Flannel does not enforce Kubernetes `NetworkPolicy` resources.**
- **Current State:** All pods can communicate with all other pods and services across all namespaces by default.
- **Mitigation:**
  - Use Kyverno for admission control policies (e.g., block pods from using `hostNetwork`). This is not a CNI-level network policy.
  - For true network isolation, a migration to Cilium is the recommended path. This is a high-effort task planned for a future phase.

**4. Debugging Commands**

- **Check Flannel Pods:**
  ```bash
  kubectl get pods -n kube-system -l app=flannel
  ```

- **Check Flannel Logs:** Look for errors about connecting to the K3s API server or network configuration.
  ```bash
  kubectl logs -n kube-system -l app=flannel -f
  ```

- **Inspect Flannel Interface on a Node:**
  ```bash
  # Check MTU and status
  ip link show flannel.1
  # Expected output: ...<BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 ...

  # Check routes for pod traffic
  ip route | grep flannel.1
  # Expected output: 10.42.2.0/24 dev flannel.1 ... (route to another node's pod subnet)
  ```

- **Troubleshooting Decision Tree:**

  - **Symptom:** Pod on `node-A` cannot reach pod on `node-B`, but can reach pods on `node-A`.
    - **Cause 1:** Hetzner firewall is blocking UDP/8472.
      - **Fix:** Login to Hetzner Cloud Console, go to Firewalls, edit the rule applied to your nodes, and add an inbound rule for protocol `UDP`, port `8472`, from source IPs of your other cluster nodes.
    - **Cause 2:** `flanneld` on one node is down or misconfigured.
      - **Fix:** Check `kubectl get pods -n kube-system -l app=flannel -o wide`. Ensure a pod is running on `node-B`. Check its logs. Restart the daemonset pod if necessary: `kubectl delete pod <flannel-pod-on-node-B> -n kube-system`.

  - **Symptom:** Pods have intermittent connectivity issues, especially with large data transfers.
    - **Cause:** MTU mismatch. A device in the path might have a smaller MTU, causing fragmentation.
    - **Fix:** Verify `ip link show flannel.1` and `ip link show eth0` (or private network interface) on all nodes. Ensure `flannel.1` MTU is 50 bytes less than the physical interface MTU. The default `1400` is correct for Hetzner's `1450`.

### ## reference.md Content

**1. Flannel VXLAN Packet Flow**

Packet from `pod-A` on `node-1` to `pod-B` on `node-2`:

1.  **pod-A -> veth:** Packet with destination `10.42.2.5` (`pod-B` IP) leaves `pod-A`'s network namespace.
2.  **veth -> cni0 bridge:** Packet arrives on the `cni0` bridge on `node-1`.
3.  **cni0 -> kernel routing:** The kernel on `node-1` consults its routing table. It finds a route: `10.42.2.0/24 dev flannel.1`.
4.  **kernel -> flannel.1:** The packet is sent to the `flannel.1` VXLAN interface.
5.  **flannel.1 -> VXLAN Encapsulation:** The `flanneld` process (or kernel VXLAN module) wraps the original Ethernet frame in a UDP header.
    -   Outer IP Header: `src=node-1_priv_ip`, `dst=node-2_priv_ip`
    -   Outer UDP Header: `dst_port=8472`
    -   VXLAN Header: Contains VNI (Virtual Network Identifier).
    -   Inner Ethernet Frame: Original packet from `pod-A`.
6.  **Encapsulation -> eth0 (private):** The new, larger UDP packet is sent out over `node-1`'s private network interface towards `node-2`.
7.  **Hetzner Network:** The packet is routed through the Hetzner private network.
8.  **eth0 (private) -> Decapsulation:** The UDP packet arrives at `node-2`. The kernel sees it's a VXLAN packet for port 8472 and passes it to the `flannel.1` interface for decapsulation.
9.  **flannel.1 -> cni0 bridge:** The original inner packet is unwrapped and placed on `node-2`'s `cni0` bridge.
10. **cni0 -> veth -> pod-B:** The bridge forwards the packet to the virtual ethernet device connected to `pod-B`, which receives the packet.

**2. K3s Flannel Configuration**

These options are passed to the K3s server process at startup. They are not changed post-install without significant disruption.

-   `--flannel-backend <string>`: (Default: `vxlan`) Type of backend to use.
    -   `vxlan`: Most flexible, works over any L3 network. Our current choice.
    -   `host-gw`: More performant, no encapsulation overhead. Requires all nodes to be on the same L2 network. Hetzner's private network *may* support this, but `vxlan` is safer and more portable.
    -   `wireguard-native`: Encapsulates all pod-to-pod traffic within a WireGuard tunnel. Provides encryption-in-transit by default, but has a performance overhead.
-   `--cluster-cidr <string>`: (Default: `10.42.0.0/16`) IPv4 CIDR for the entire pod network. Must not overlap with Hetzner's private network range or any other network.
-   `--flannel-iface <string>`: Specifies which interface Flannel should use for its traffic. If not set, it auto-detects. For Hetzner, it should auto-select the private network interface (`ens10` or similar). Forcing this can improve reliability: `--flannel-iface=ens10`.

**3. Migration Path: Flannel to Cilium**

-   **Why Migrate?**
    1.  **NetworkPolicy:** To enforce network isolation between pods/namespaces.
    2.  **Observability:** Hubble UI provides a visual map of network flows.
    3.  **Performance:** eBPF provides faster packet processing than traditional `iptables`/IPVS.
    4.  **Advanced Features:** L7-aware policies (e.g., allow `GET` but not `POST` to an API endpoint).
-   **When to Migrate:** When the cluster complexity grows and NetworkPolicy becomes a security or operational requirement. Do not undertake this migration lightly.
-   **High-Level Steps (Disruptive):**
    1.  Backup etcd data (`k3s etcd-snapshot`).
    2.  Stop K3s on all nodes.
    3.  Restart K3s server with CNI disabled: `k3s server --flannel-backend=none ...`.
    4.  Restart K3s agents with CNI disabled: `k3s agent --flannel-backend=none ...`.
    5.  Install Cilium via Helm chart. The chart needs to be configured with the correct cluster CIDRs and API server address.
    6.  Reboot/restart all nodes to ensure old CNI state is cleared.
    7.  Verify all pods come back up and have connectivity.

### ## examples.md Content

**1. Verifying Flannel Setup on a K3s Node**

**Scenario:** You `ssh` into the control plane node `helix-stax-cp` (`178.156.233.12`) to debug a networking issue.

1.  **Check the Flannel DaemonSet Pod:**
    ```bash
    [root@helix-stax-cp ~]# kubectl get pods -n kube-system -l app=flannel -o wide
    # Expected output shows a pod running on each node
    NAME                   READY   STATUS    RESTARTS   AGE   IP            NODE             NOMINATED NODE   READINESS GATES
    kube-flannel-ds-abcde  1/1     Running   0          10d   5.78.145.30   helix-stax-vps   <none>           <none>
    kube-flannel-ds-fghij  1/1     Running   0          10d   178.156.233.12  helix-stax-cp    <none>           <none>
    ```

2.  **Inspect the Flannel ConfigMap:** This shows the configured network and backend.
    ```bash
    [root@helix-stax-cp ~]# kubectl get cm kube-flannel-cfg -n kube-system -o yaml
    ...
    data:
      net-conf.json: |
        {
          "Network": "10.42.0.0/16",
          "Backend": {
            "Type": "vxlan"
          }
        }
    ...
    ```

3.  **Inspect Node Subnet Leases:** Check the annotations on the Kubernetes node object.
    ```bash
    [root@helix-stax-cp ~]# kubectl get node helix-stax-cp -o jsonpath='{.metadata.annotations}' | jq .
    {
      "flannel.alpha.coreos.com/backend-data": "{\"VtepMAC\":\"xx:xx:xx:xx:xx:xx\"}",
      "flannel.alpha.coreos.com/backend-type": "vxlan",
      "flannel.alpha.coreos.com/kube-subnet-manager": "true",
      "flannel.alpha.coreos.com/public-ip": "178.156.233.12",
      "flannel.alpha.coreos.com/public-ip-overwrite": "",
      "flannel.alpha.coreos.com/subnet": "10.42.0.0/24" # <-- This node's pod IP range
    }
    ```

4.  **Live Network Interface Check:**
    ```bash
    [root@helix-stax-cp ~]# ip a | grep -E "flannel.1|cni0"
    # cni0: bridge interface for pods on this node
    3: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
        inet 10.42.0.1/24 brd 10.42.0.255 scope global cni0
    # flannel.1: VXLAN overlay interface
    4: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UNKNOWN group default
        inet 10.42.0.0/32 scope global flannel.1
    ```

**2. Runbook: Diagnosing Cross-Node Pod Connectivity Failure**

**Symptom:** A pod in namespace `app-a` on `helix-stax-cp` cannot `curl` a pod in `app-b` on `helix-stax-vps`.

1.  **Get Pod IPs and Nodes:**
    ```bash
    POD_A_NAME=$(kubectl get pods -n app-a -o jsonpath='{.items[0].metadata.name}')
    POD_A_IP=$(kubectl get pod $POD_A_NAME -n app-a -o jsonpath='{.status.podIP}')
    POD_A_NODE=$(kubectl get pod $POD_A_NAME -n app-a -o jsonpath='{.spec.nodeName}')

    POD_B_NAME=$(kubectl get pods -n app-b -o jsonpath='{.items[0].metadata.name}')
    POD_B_IP=$(kubectl get pod $POD_B_NAME -n app-b -o jsonpath='{.status.podIP}')
    POD_B_NODE=$(kubectl get pod $POD_B_NAME -n app-b -o jsonpath='{.spec.nodeName}')

    echo "Pod A ($POD_A_NAME) is on $POD_A_NODE with IP $POD_A_IP"
    echo "Pod B ($POD_B_NAME) is on $POD_B_NODE with IP $POD_B_IP"
    ```

2.  **Test Connectivity from Pod:**
    ```bash
    kubectl exec -it -n app-a $POD_A_NAME -- curl -v $POD_B_IP:8080 # Use correct port
    # It times out.
    ```

3.  **Test Connectivity from Node:** SSH to `helix-stax-cp` (`$POD_A_NODE`).
    ```bash
    [root@helix-stax-cp ~]# ping $POD_B_IP
    # This also fails. This confirms it's a node-level routing issue.
    ```

4.  **Check Routes on Source Node:**
    ```bash
    [root@helix-stax-cp ~]# ip route get $POD_B_IP
    # Correct output should show routing via flannel.1 to the other node's IP.
    # Ex: 10.42.1.50 via 10.42.1.0 dev flannel.1 src 10.42.0.40
    # If the route is missing, flanneld is not working correctly.
    ```

5.  **Check Hetzner Firewall:** This is the most likely culprit.
    -   Log in to `https://console.hetzner.cloud/`.
    -   Navigate to Security -> Firewalls.
    -   Select the firewall attached to your servers.
    -   Go to "Rules".
    -   Ensure an "Inbound" rule exists:
        -   **Protocol:** `UDP`
        -   **Port:** `8472`
        -   **Sources:** Either `Any IPv4` (less secure) or create a new "IPs" source type containing the private IPs of your cluster nodes.

6.  **Re-test:** After adding the firewall rule, the `curl` from step 2 should now succeed.

---

### Best Practices & Decision Matrix (Automation Services)

**Top 10 Best Practices**

1.  **n8n in Queue Mode:** Always run n8n in `queue` mode with dedicated workers in production to ensure UI/webhook responsiveness.
2.  **Centralize TLS Secret:** Use a single wildcard Cloudflare Origin CA certificate stored in one namespace (`kube-system`) and referenced by a Traefik `TLSStore`. Do not manage certs per-ingress.
3.  **Immutable Encryption Key:** The `N8N_ENCRYPTION_KEY` is sacred. Store it in OpenBao, sync it via ESO, and never change it.
4.  **Stateless n8n Pods:** Keep n8n pods stateless. Persist workflow/credential data in CloudNativePG PostgreSQL and user data/backups on a PVC.
5.  **Use `Full (Strict)`
