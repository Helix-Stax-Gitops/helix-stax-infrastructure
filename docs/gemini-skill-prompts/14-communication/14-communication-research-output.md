Here is the comprehensive research document for your communication stack, structured for your AI agents. This output is designed to be split into two sets of skill files.

# Rocket.Chat

Rocket.Chat is our self-hosted communication platform for internal team chat, client-facing channels, and system alerts. It replaces Slack and Telegram, providing granular control, OIDC SSO with Zitadel, and powerful API/webhook integrations with our automation (n8n) and CI/CD (ArgoCD, Devtron) stacks.

---
### ## SKILL.md Content
---
**Core reference for daily operations: configuration, troubleshooting, and integration.**

#### **Deployment on K3s**

*   **Helm Chart:** `rocketchat/rocketchat`
*   **Dependencies:** Requires a MongoDB replica set. Use the `bitnami/mongodb` Helm chart.
*   **ArgoCD Sync-Wave Order:**
    1.  `sync-wave: -2`: Namespace, Secrets
    2.  `sync-wave: -1`: Bitnami MongoDB HelmRelease
    3.  `sync-wave: 0`: Rocket.Chat HelmRelease

#### **Key Environment Variables**
```
ROOT_URL=https://chat.helixstax.net
PORT=3000
MONGO_URL=mongodb://rc-user:<password>@mongodb-0.mongodb-headless.default.svc.cluster.local:27017/rocketchat?replicaSet=mongodb
MONGO_OPLOG_URL=mongodb://rc-user:<password>@mongodb-0.mongodb-headless.default.svc.cluster.local:27017/local?replicaSet=mongodb
DEPLOY_PLATFORM=helm-chart
```

#### **Traefik IngressRoute (with WebSocket)**
```yaml
# IngressRoute for Rocket.Chat Web & API
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: rocketchat-ingress
spec:
  entryPoints:
    - websecure
  routes:
    # Main route for all HTTP traffic
    - match: Host(`chat.helixstax.net`)
      kind: Rule
      services:
        - name: rocketchat-rocketchat # Helm chart service name
          port: 3000
      middlewares:
        - name: rocketchat-ws # WebSocket middleware
    # Specific route for websockets (required for some older clients/setups)
    - match: Host(`chat.helixstax.net`) && PathPrefix(`/websocket`)
      kind: Rule
      services:
        - name: rocketchat-rocketchat
          port: 3000
      middlewares:
        - name: rocketchat-ws
---
# Middleware to ensure WebSocket headers are correctly handled
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rocketchat-ws
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: "https"
```

#### **OIDC SSO with Zitadel**
1.  **In Rocket.Chat:** Admin -> Administration -> OAuth -> "Add custom OAuth"
2.  **Configuration:**
    *   **Name:** `zitadel` (this becomes part of the callback URL)
    *   **Enable:** ON
    *   **Client ID/Secret:** From your Zitadel Application
    *   **Authorization URL:** `https://auth.helixstax.net/oauth/v2/authorize`
    *   **Token URL:** `https://auth.helixstax.net/oauth/v2/token`
    *   **User Info URL:** `https://auth.helixstax.net/oidc/v1/userinfo`
    *   **Scope:** `openid profile email`
    *   **Redirect URI (read-only):** `https://chat.helixstax.net/_oauth/zitadel` (Use this in your Zitadel App config)
3.  **To make OIDC default:** Admin -> General -> Accounts -> Set "Show Default Login Form" to `false`.

#### **REST API: Common Commands**
*   **Authenticate (as bot/user):**
    ```bash
    # 1. Login to get tokens
    curl -X POST https://chat.helixstax.net/api/v1/login \
      -d "user=<bot_username>&password=<bot_password>"
    # Response: { "status": "success", "data": { "userId": "...", "authToken": "..." } }

    # 2. Store and use headers for subsequent requests
    export RC_USER_ID="<userId_from_response>"
    export RC_AUTH_TOKEN="<authToken_from_response>"
    ```
*   **Post a simple message:**
    ```bash
    curl -H "X-Auth-Token: $RC_AUTH_TOKEN" \
         -H "X-User-Id: $RC_USER_ID" \
         -H "Content-type: application/json" \
         https://chat.helixstax.net/api/v1/chat.postMessage \
         -d '{ "channel": "#ops-alerts", "text": "This is a test alert." }'
    ```
*   **Post a message with attachments (for alerts):**
    ```bash
    curl -H "X-Auth-Token: $RC_AUTH_TOKEN" \
         -H "X-User-Id: $RC_USER_ID" \
         -H "Content-type: application/json" \
         https://chat.helixstax.net/api/v1/chat.postMessage \
         -d '{
               "channel": "#ops-alerts",
               "attachments": [
                 {
                   "color": "#ff0000",
                   "title": "[FIRING:1] High CPU on helix-stax-cp",
                   "title_link": "http://grafana.helixstax.net/alerting/list",
                   "text": "The control plane node CPU usage is above 90%.",
                   "fields": [
                     { "title": "Severity", "value": "Critical", "short": true },
                     { "title": "Node", "value": "helix-stax-cp", "short": true }
                   ],
                   "footer": "Alertmanager"
                 }
               ]
             }'
    ```

#### **Integrations: Incoming Webhooks**
*   **URL Format:** `https://chat.helixstax.net/hooks/{id}/{token}`
*   **Alertmanager `receivers` config:**
    ```yaml
    receivers:
      - name: 'rocketchat-ops-alerts'
        webhook_configs:
          - url: 'https://chat.helixstax.net/hooks/...'
            send_resolved: true
    ```
    *   *Note:* A custom script in Rocket.Chat or an n8n workflow is needed to format the generic webhook payload from Alertmanager into a rich attachment. Better: use the built-in `rocket_chat_configs` if available or a community notification template.
*   **ArgoCD Notifications `ConfigMap`:**
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-notifications-cm
    data:
      service.webhook.rocketchat: |
        url: https://chat.helixstax.net/hooks/...
        headers:
        - name: Content-Type
          value: application/json
      template.app-sync-succeeded: |
        webhook:
          rocketchat:
            method: POST
            body: |
              {
                "text": "✅ Sync Succeeded: {{.app.metadata.name}}",
                "attachments": [{
                  "color": "#00ff00",
                  "title": "Application: {{.app.metadata.name}}",
                  "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
                  "fields": [
                    { "title": "Sync Status", "value": "{{.app.status.sync.status}}", "short": true },
                    { "title": "Revision", "value": "{{.app.status.sync.revision}}", "short": true }
                  ]
                }]
              }
    ```

#### **Troubleshooting Decision Tree**

*   **Symptom:** Chat connects, then immediately disconnects (reconnection loop).
    *   **Cause 1:** `ROOT_URL` environment variable does not exactly match the URL in the browser.
    *   **Fix 1:** Ensure `ROOT_URL` is `https://chat.helixstax.net` with no trailing slash.
    *   **Cause 2:** WebSocket connection is being dropped by Cloudflare or Traefik.
    *   **Fix 2:** Verify Cloudflare has WebSockets enabled (default). Verify the Traefik `IngressRoute` and `Middleware` are configured for WebSocket headers.
*   **Symptom:** OIDC login fails with "OAuth App not found" or redirect errors.
    *   **Cause:** Redirect URI in Zitadel does not exactly match the one shown in Rocket.Chat's OAuth settings (`https://chat.helixstax.net/_oauth/zitadel`).
    *   **Fix:** Copy the URI from Rocket.Chat and paste it into the Zitadel application configuration.
*   **Symptom:** Rocket.Chat pod is crash-looping on startup.
    *   **Cause:** MongoDB is not available or the replica set is not healthy. Rocket.Chat requires oplog access.
    *   **Fix:** Check the logs of the MongoDB pods (`kubectl logs -l app.kubernetes.io/name=mongodb`). Ensure the replica set initiated correctly. Verify `MONGO_URL` and `MONGO_OPLOG_URL` are correct.
*   **Symptom:** File uploads fail.
    *   **Cause:** Storage backend not configured or misconfigured. Default is GridFS in MongoDB.
    *   **Fix:** Ensure MongoDB is healthy and has sufficient disk space for its PVC. For large-scale use, configure external S3-compatible storage like MinIO.

---
### ## reference.md Content
---
**Deep reference for architecture, APIs, and advanced configuration.**

#### **A1. REST API Reference**

*   **Base URL:** `https://chat.helixstax.net/api/v1/`
*   **Authentication:**
    1.  **session-based (for UI):** Standard cookie auth.
    2.  **token-based (for API/bots):** Send `X-Auth-Token` and `X-User-Id` headers with every request. Obtain these via `POST /api/v1/login`.
    3.  **OAuth2:** For user-delegated access, not typically used for service bots.
*   **Key Endpoints:**
    *   `POST /api/v1/login`: Authenticate with `user` and `password` or `resume` token.
    *   `POST /api/v1/logout`: Invalidate the current session token.
    *   `GET /api/v1/me`: Get the current user's information.
    *   `POST /api/v1/chat.postMessage`: Post a message. Payload schema includes `roomId`, `channel`, `text`, `alias`, `emoji`, `avatar`, `attachments`, `blocks`.
    *   `GET /api/v1/channels.list`: List public channels the user is a member of.
    *   `GET /api/v1/groups.list`: List private channels (groups) the user is a member of.
    *   `POST /api/v1/channels.create`: Create a new public channel.
    *   `POST /api/v1/groups.create`: Create a new private channel.
    *   `POST /api/v1/dm.create`: Create a direct message session with one or more users.
    *   `GET /api/v1/users.list`: List users on the server.
    *   `POST /api/v1/users.create`: Create a new user.
*   **Pagination:** Use `count` (number of items) and `offset` (starting position) query parameters. Responses include `count`, `offset`, and `total`.
*   **Rate Limiting:** Configured in Admin -> General -> Rate Limiter. Default is 10 requests / 5 seconds. Exceeding the limit returns a `429 Too Many Requests` with a `Retry-After` header. Implement exponential backoff on clients.

#### **A2. Deployment on K3s: Deep Dive**

*   **MongoDB Requirement:** Rocket.Chat uses MongoDB's "oplog" (operations log) for its real-time data synchronization engine. The oplog is only available when MongoDB is running as a **replica set**, even a single-node replica set. This is a non-negotiable architectural requirement.
*   **Recommended MongoDB Chart:** `bitnami/mongodb`. It's well-maintained and simplifies replica set configuration.
    *   `architecture`: `replica-set`
    *   `replicaSet.enabled`: `true`
*   **Storage:** The default storage for file uploads is **GridFS**, which stores files as chunks inside the MongoDB database.
    *   **Pros:** Simple, no external dependencies.
    *   **Cons:** Bloats the database, makes backups larger and more complex, can impact database performance.
    *   **Alternative (Recommended for Scale):** Configure S3-compatible object storage (e.g., a MinIO deployment on K3s). This is set via environment variables (`S3_...`) or in the Admin -> File Upload -> S3 panel.
*   **Startup Order:** An `initContainer` in the Rocket.Chat pod that probes the MongoDB service (`mongosh --host ... --eval "db.adminCommand('ping')"`) is a robust way to ensure MongoDB is ready before Rocket.Chat starts. The official Helm chart has some retry logic built-in, but startup can still be fragile without explicit ordering.

#### **A3. OIDC: Deep Dive**

*   **Claim Mapping:** In the custom OAuth settings, map Zitadel claims to Rocket.Chat user attributes.
    *   **Username field:** `preferred_username`
    *   **Email field:** `email`
    *   **Name field:** `name`
    *   **Avatar field:** `picture`
*   **Role/Group Sync:** To map Zitadel groups to Rocket.Chat roles:
    1.  In Zitadel, create a custom claim for a project grant that includes the user's groups/roles.
    2.  In Rocket.Chat OAuth settings, specify the name of that claim in the **Roles/Groups Claim Name** field.
    3.  In the **Roles/Groups Field Mapping**, provide a JSON object to map claim values to Rocket.Chat roles: `{"zitadel_admins": "admin", "zitadel_users": "user"}`.
*   **Admin Bootstrap:** Before enabling OIDC as the only login method, ensure your primary admin account is created via username/password. After OIDC is working, you can either link your OIDC identity to this admin account or grant another OIDC user admin rights. *Never lock yourself out.*

#### **Best Practices & Anti-Patterns**

**Top 5 Best Practices:**
1.  **Separate Databases:** Run MongoDB on its own StatefulSet/Helm release, not as a sub-chart of Rocket.Chat. This allows for independent scaling, backup, and management.
2.  **Use OIDC for All Users:** Enforce SSO via Zitadel. It centralizes identity management, simplifies on/off-boarding, and improves security.
3.  **Use Bots for All Automation:** All programmatic messages (alerts, CI/CD) should come from dedicated bot users, not a real user's API token. This improves auditability and isolates permissions.
4.  **Externalize File Storage:** For any serious use, switch from GridFS to an S3-compatible object store (MinIO) early. It prevents database bloat and performance degradation.
5.  **Monitor WebSockets:** The most critical metric for user experience is WebSocket connection health. Monitor active WebSocket connections and look for rapid fluctuations.

**Top 5 Anti-Patterns:**
1.  **(Critical) Running MongoDB without a Replica Set:** Rocket.Chat will not function correctly. It may start, but real-time features will fail silently or intermittently.
2.  **(Critical) Misconfigured `ROOT_URL`:** The #1 cause of WebSocket connection issues and a multitude of hard-to-debug frontend problems. It must be `https://` and match the browser URL exactly.
3.  **(High) Using Default Admin Account:** Do not leave the initial admin account active with a simple password. Integrate it with OIDC or use a highly complex generated password stored in a secret manager.
4.  **(Medium) Storing Files in GridFS at Scale:** Leads to a massive, slow, and unwieldy MongoDB database.
5.  **(Low) Not Using Sync Waves in ArgoCD:** Deploying Rocket.Chat and its database simultaneously is a race condition. Rocket.Chat will fail to start if the database isn't fully ready. Use sync waves to enforce order.

---
### ## examples.md Content
---
**Copy-paste-ready configurations and manifests for the Helix Stax environment.**

#### **MongoDB: Bitnami Helm Chart `values.yaml`**
```yaml
# values-mongodb.yaml
# Deploys a single-node replica set suitable for Rocket.Chat.
architecture: "replica-set"
replicaSet:
  enabled: true
  replicas: 1 # For small scale, one is enough for oplog functionality.
auth:
  enabled: true
  rootPassword: "<your-mongo-root-password>" # From a secret
  usernames:
    - rc-user
  passwords:
    - "<your-rocketchat-db-password>" # From a secret
  databases:
    - rocketchat
persistence:
  enabled: true
  size: 10Gi # Adjust based on expected usage and GridFS use
```

#### **Rocket.Chat Helm Chart `values.yaml`**
```yaml
# values-rocketchat.yaml
image:
  repository: rocketchat/rocket.chat
  tag: "6.5.2" # Pin to a specific version

# We handle ingress manually with Traefik IngressRoute
ingress:
  enabled: false

# Configure environment variables via the 'extraEnv' block
extraEnv:
  - name: ROOT_URL
    value: "https://chat.helixstax.net"
  - name: PORT
    value: "3000"
  - name: DEPLOY_PLATFORM
    value: "helm-chart"
  - name: MONGO_URL
    valueFrom:
      secretKeyRef:
        name: rocketchat-secrets # A secret you create
        key: MONGO_URL
  - name: MONGO_OPLOG_URL
    valueFrom:
      secretKeyRef:
        name: rocketchat-secrets
        key: MONGO_OPLOG_URL
  # SMTP configuration for sending emails via Postal
  - name: SMTP_HOST
    value: "mail.helixstax.net"
  - name: SMTP_PORT
    value: "587"
  - name: SMTP_USERNAME
    value: "rocketchat@ps1.helixstax.com" # Example credential from Postal
  - name: SMTP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postal-smtp-credentials
        key: rocketchat-password
  - name: SMTP_PROTOCOL
    value: "smtp"
  - name: FROM_EMAIL
    value: "notifications@helixstax.net"

# We use the Bitnami chart, not the built-in MongoDB
mongodb:
  enabled: false

# Resource requests and limits for a small team (10-20 users)
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi
```

#### **Kubernetes Secret for MongoDB URLs**
```yaml
# rocketchat-secrets.yaml
# Production: Use ExternalSecret (ESO) to pull from OpenBao. Never commit plaintext credentials.
apiVersion: v1
kind: Secret
metadata:
  name: rocketchat-secrets
type: Opaque
stringData:
  # Replace <password> with the password set in the MongoDB chart.
  # The service name 'mongodb-0.mongodb-headless' is the default for the Bitnami chart.
  MONGO_URL: "mongodb://rc-user:<your-rocketchat-db-password>@mongodb-0.mongodb-headless.default.svc.cluster.local:27017/rocketchat?replicaSet=mongodb"
  MONGO_OPLOG_URL: "mongodb://rc-user:<your-rocketchat-db-password>@mongodb-0.mongodb-headless.default.svc.cluster.local:27017/local?replicaSet=mongodb"
```

#### **ArgoCD Application Manifest**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rocketchat
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/helix-stax/gitops-infra.git'
    path: 'apps/rocketchat'
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: communication
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# Example ArgoCD Application manifests within apps/rocketchat/ directory
# MongoDB deployed first via sync-wave -1
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mongodb-for-rc
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1" # Wave -1
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: mongodb
    targetRevision: "14.x"
    helm:
      releaseName: mongodb-for-rc
      # ... helm values for Bitnami MongoDB chart ...
  destination:
    server: https://kubernetes.default.svc
    namespace: communication
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# Rocket.Chat deployed after MongoDB via sync-wave 0
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rocketchat
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0" # Wave 0
spec:
  project: default
  source:
    repoURL: https://charts.rocket.chat/rocketchat
    chart: rocketchat
    targetRevision: "6.x"
    helm:
      releaseName: rocketchat
      # ... helm values for Rocket.Chat chart ...
  destination:
    server: https://kubernetes.default.svc
    namespace: communication
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

# Postal

Postal is our self-hosted transactional email server. It handles all programmatic email from our applications (Zitadel, Grafana, Alertmanager, n8n, etc.), ensuring high deliverability for alerts and notifications. Business email (`team@helixstax.com`) is handled separately by Google Workspace.

---
### ## SKILL.md Content
---
**Core reference for daily operations: DNS setup, service configuration, and troubleshooting.**

#### **Architecture**
Postal runs as multiple components within a single container image: `web` (UI/API), `worker` (email processing), `smtp` (server), `cron` (maintenance tasks).

#### **DNS Setup in Cloudflare (CRITICAL)**

*   **All records must be `DNS Only` (Grey Cloud), NOT `Proxied` (Orange Cloud).**
*   **SPF (for `helixstax.com`):** Combines Google Workspace and our Hetzner IP.
    *   Type: `TXT`
    *   Name: `@` (or `helixstax.com`)
    *   Content: `v=spf1 include:_spf.google.com ip4:178.156.233.12 ~all`
        *(Note: If sending from both nodes, add `ip4:5.78.145.30`)*
*   **DKIM:**
    1.  Generate the key in Postal UI: Organizations -> Your Org -> Domains -> Details -> Setup DNS.
    2.  Create the `TXT` record in Cloudflare.
    *   Type: `TXT`
    *   Name: `postal._domainkey`
    *   Content: `v=DKIM1; k=rsa; p=...` (copy the full value from Postal)
*   **DMARC (for `helixstax.com`):**
    *   Type: `TXT`
    *   Name: `_dmarc`
    *   Content: `v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@helixstax.com; sp=quarantine; fo=1`
*   **Return-Path:**
    *   Type: `CNAME`
    *   Name: `rp.helixstax.net` (or whatever you configure in `postal.yml`)
    *   Content: `mail.helixstax.net`
*   **PTR Record (Reverse DNS):**
    *   **Action:** In Hetzner Cloud Console, go to your server (`helix-stax-cp`), navigate to "Networking", and set the Reverse DNS for `178.156.233.12` to `mail.helixstax.net`.
    *   **Why:** This is crucial. Many mail servers will reject email from an IP without a matching PTR record.

#### **Port 25 Exposure on K3s**

Outbound port 25 is required. Inbound is handled by Traefik TCP.
*   **Hetzner Firewall:** Create a firewall rule allowing `TCP` traffic on port `25` from your worker node(s) to `Any IPv4/IPv6`.
*   **Traefik `IngressRouteTCP` for SMTP:**
    ```yaml
    apiVersion: traefik.io/v1alpha1
    kind: IngressRouteTCP
    metadata:
      name: postal-smtp-tcp
    spec:
      entryPoints:
        - smtp # Custom entrypoint for port 25
      routes:
        - match: HostSNI(`*`)
          services:
            - name: postal-service # Your Postal k8s service
              port: 25
    ```
    *You must define the `smtp` entrypoint in your Traefik static configuration.*

#### **Per-Service SMTP Configuration**

*   **Postal Server Name:** `ps1` (for `ps1.helixstax.com`)
*   **SMTP Host for all services:** `mail.helixstax.net`
*   **Port:** `587`
*   **Encryption:** `STARTTLS`

| Service | Postal SMTP Username | From Address |
| :--- | :--- | :--- |
| Alertmanager | `alertmanager@ps1.helixstax.com` | `alerts@helixstax.net` |
| Grafana | `grafana@ps1.helixstax.com` | `grafana@helixstax.net` |
| Zitadel | `zitadel@ps1.helixstax.com` | `auth@helixstax.com` |
| n8n | `n8n@ps1.helixstax.com` | `workflows@helixstax.net` |
| Outline | `outline@ps1.helixstax.com`| `docs@helixstax.net` |
| Rocket.Chat | `rocketchat@ps1.helixstax.com`| `notifications@helixstax.net` |

#### **Troubleshooting Decision Tree**

*   **Symptom:** Emails are not being sent, stuck in Postal queue.
    *   **Cause 1:** Outbound port 25 is blocked by Hetzner.
    *   **Fix 1:** Verify your Hetzner firewall rules. Contact Hetzner support to ensure they haven't blocked it upstream.
    *   **Cause 2:** DNS is misconfigured (PTR, SPF).
    *   **Fix 2:** Use MXToolbox to check your domain's health. Verify the PTR record is set correctly in the Hetzner console.
*   **Symptom:** Emails are sent but go straight to spam.
    *   **Cause 1:** IP is new and not warmed up.
    *   **Fix 1:** Implement a slow sending ramp-up (IP warming).
    *   **Cause 2:** DKIM or SPF failure/misalignment.
    *   **Fix 2:** Check the headers of a received spam email. It will show `spf=fail` or `dkim=fail`. Use a DKIM/SPF validator tool. Ensure alignment (From header domain must match DKIM/SPF domain).
    *   **Cause 3:** IP is on a blacklist.
    *   **Fix 3:** Use MXToolbox Blacklist Check. If listed, follow the delisting process for the specific list.
*   **Symptom:** Cannot connect to SMTP from other services (e.g., Grafana).
    *   **Cause:** K8s networking issue or incorrect credentials.
    *   **Fix:** `kubectl exec` into the Grafana pod and try to connect with `curl`: `curl -v --ssl-reqd smtp://mail.helixstax.net:587 -u "grafana@ps1.helixstax.com:<password>"`. This will verify connectivity and credentials.

---
### ## reference.md Content
---
**Deep reference for architecture, APIs, and advanced configuration.**

#### **B1. REST API Reference**

*   **Base URL:** `https://mail.helixstax.net/api/v1/`
*   **Authentication:** `X-Server-API-Key` header with a key generated for a specific mail server in your Postal organization.
*   **Key Endpoints:**
    *   `POST /api/v1/send/message`: Send a fully-formed email.
        *   **Payload:** `to`, `from`, `sender` (optional), `subject`, `plain_body`, `html_body`, `attachments` (array of `{name, content_type, data}` objects), `headers`, `tag`.
    *   `POST /api/v1/send/raw`: Send a pre-built raw MIME message.
    *   `GET /api/v1/messages/message`: Get details for a message by its ID.
    *   `GET /api/v1/messages/deliveries`: Get delivery information for a message.
*   **Webhook Event Payload (Schema):**
    ```json
    {
      "event": "MessageBounced", // or MessageDelivered, SpamComplaint, etc.
      "timestamp": 1515694738.12345,
      "payload": {
        "message": {
          "id": 123,
          "token": "aAbBcC",
          "direction": "outgoing",
          "message_id": "...",
          "to": "test@example.com",
          "from": "sender@helixstax.com",
          "subject": "Test Message",
          "timestamp": 1515694738.12345,
          "tag": "zitadel-pw-reset" // Extremely useful for routing
        },
        "original_message": { ... }, // if available
        "details": {
          "bounce": "Hard", // or "Soft"
          "reason": "NoMailbox",
          "diagnostic": "550 5.1.1 The email account that you tried to reach does not exist."
        }
      },
      "signature": {
        "signature": "...", // base64 encoded hmac
        "timestamp": 1715694738
      }
    }
    ```

#### **B2. Deployment on K3s: Deep Dive**

*   **MariaDB Compatibility:** Postal requires `utf8mb4` character set and `utf8mb4_unicode_ci` collation. The Bitnami MariaDB chart must be configured accordingly:
    *   `common.charset`: `utf8mb4`
    *   `common.collation`: `utf8mb4_unicode_ci`
*   **Valkey (Redis) Usage:** Postal uses Redis for its background job queue (Sidekiq). It's a critical component. If Redis is down, no emails will be processed.
*   **Initialization:** The first time Postal starts, it needs to initialize the database and create an admin user.
    1.  `postal initialize-config` - This generates the `postal.yml`. You should provide this config via a ConfigMap instead.
    2.  `postal initialize` - This sets up the database schema.
    3.  `postal make-user` - This prompts you to create the initial admin user.
    *This process can be automated with a Kubernetes `Job` that runs on initial deployment.*
*   **`postal.yml` Reference:** This is the main configuration file.
    *   `database`: MariaDB connection details.
    *   `redis`: Valkey/Redis connection details.
    *   `main_ip`: The public IP of the server. `178.156.233.12`.
    *   `web`: Web server settings, including `host` (`mail.helixstax.net`).
    *   `dns`: Configure `return_path_domain` (`rp.helixstax.net`), `track_domain` (`track.helixstax.net`), etc.
    *   `smtp`: Configure `port`, `host`, etc.

#### **B7. IP Warming & Deliverability**

*   **Why:** A new IP address has no sending history, so major ISPs (Gmail, Outlook) will heavily scrutinize and throttle its traffic. Warming builds a positive reputation.
*   **Schedule (Example):**
    *   **Week 1:** < 50-100 emails/day. Send only high-engagement mail (e.g., account verifications).
    *   **Week 2:** < 200-500 emails/day.
    *   **Week 3:** < 1000-2500 emails/day.
    *   **Week 4:** Gradually increase to your expected volume. Monitor bounce rates and deferrals closely.
*   **Deliverability Tools:**
    *   **mail-tester.com:** Send an email to the provided address to get a 1-10 score on your configuration (SPF, DKIM, content).
    *   **MXToolbox:** Check your IP against major blacklists and validate your DNS records.
    *   **Google Postmaster Tools:** Register `helixstax.com` to get reputation data directly from Google, including spam rate, domain reputation, and IP reputation. This is non-negotiable for sending to Gmail users.

#### **Best Practices & Anti-Patterns**

**Top 5 Best Practices:**
1.  **Isolate Senders:** Use a separate Mail Server and/or SMTP credential in Postal for *every single application*. This prevents a misbehaving app (e.g., sending spammy notifications) from ruining the reputation for all other apps.
2.  **Set the PTR Record:** This is the most commonly missed step and has a huge impact on deliverability.
3.  **Use Webhooks for Bounce Handling:** Actively process `MessageBounced` and `SpamComplaint` events. Use an n8n workflow to remove hard-bounced addresses from your systems to protect your reputation.
4.  **Tag Every Email:** Use the `tag` attribute in the API or an `X-Postal-Tag` header via SMTP to categorize emails (e.g., `pw-reset`, `new-alert`, `weekly-summary`). This makes analytics and webhook routing trivial.
5.  **Start with `p=quarantine` for DMARC:** Don't start with `p=reject`. Use `quarantine` and monitor your `rua` reports to ensure your legitimate mail (from both Google and Postal) is aligned correctly before switching to `reject`.

**Top 5 Anti-Patterns:**
1.  **(Critical) Ignoring Port 25 Blocking:** Assuming port 25 is open. It is often blocked by cloud providers by default. You **must** verify it's open.
2.  **(Critical) Proxying Mail DNS Records through Cloudflare:** Putting an orange cloud on your `MX`, `mail`, `rp`, `track`, or DKIM records will break email flow. They must be `DNS Only`.
3.  **(High) Merging SPF Records Incorrectly:** Creating multiple `TXT` records for SPF instead of a single merged one. This is invalid.
4.  **(Medium) Sharing SMTP Credentials:** Using one SMTP user for all your applications. This is an operational and security nightmare.
5.  **(Low) Sending Poorly Formatted HTML:** Not including a `text/plain` alternative or using broken HTML can get your mail flagged as spam.

---
### ## examples.md Content
---
**Copy-paste-ready configurations and manifests for the Helix Stax environment.**

#### **`postal.yml` ConfigMap**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postal-config
data:
  postal.yml: |
    # Main Postal Configuration for Helix Stax
    dns:
      # This MUST match the PTR record for the sending IP
      smtp_server_hostname: mail.helixstax.net
      # Domain for bounce processing
      return_path_domain: rp.helixstax.net
      # Domain for open/click tracking
      track_domain: track.helixstax.net
      # Custom MX record for inbound replies (if any)
      custom_return_path_prefix: ""

    main_ip: 178.156.233.12

    web:
      # Host must match the web UI domain
      host: mail.helixstax.net
      protocol: https

    smtp:
      # Port for app submission (STARTTLS)
      port: 587
      # Hostname clients use to connect
      host: mail.helixstax.net
      # Enable TLS (required for port 587)
      tls_enabled: true
      # Path to cert/key — mount from Cloudflare Origin CA K8s Secret (no cert-manager)
      tls_certificate_path: /etc/postal/certs/tls.crt
      tls_private_key_path: /etc/postal/certs/tls.key

    rails:
      secret_key: "<generate a long random secret key>"

    database:
      host: "mariadb-service.default.svc.cluster.local" # Adjust service name
      username: "postal"
      password: "<your-mariadb-postal-password>"
      database: "postal"
      
    redis:
      host: "valkey-service.default.svc.cluster.local" # Adjust service name
      port: 6379
      database: 0

    logging:
      # Log to STDOUT for K3s/Loki to capture
      smtp_server: STDOUT
      worker: STDOUT
      web: STDOUT
```

#### **Traefik `IngressRoute` (Web UI)**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: postal-web-ingress
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`mail.helixstax.net`)
      kind: Rule
      services:
        - name: postal-service
          port: 80 # Or whatever port the postal web UI listens on
  tls:
    secretName: mail-origin-ca-tls  # Cloudflare Origin CA cert — no ACME/cert-manager
```

#### **Traefik `IngressRouteTCP` (SMTP)**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: postal-smtp-submission-tcp
spec:
  # This entrypoint 'smtps' must be defined on your Traefik Service for port 587
  entryPoints:
    - smtps
  routes:
    - match: HostSNI(`*`)
      services:
        - name: postal-service
          port: 587
  # Enable TLS passthrough to let Postal handle STARTTLS
  tls:
    passthrough: true
```

#### **Alertmanager SMTP Configuration (`alertmanager.yml`)**
```yaml
global:
  smtp_smarthost: 'mail.helixstax.net:587'
  smtp_from: 'alerts@helixstax.net'
  # Username from Postal for the Alertmanager service
  smtp_auth_username: 'alertmanager@ps1.helixstax.com'

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'oncall@helixstax.com'
        # Password for the Postal SMTP credential
        smtp_auth_password: '<your-postal-alertmanager-password>'
        require_tls: true
```

#### **Grafana SMTP Configuration (Environment Variables)**
```env
GF_SMTP_ENABLED=true
GF_SMTP_HOST=mail.helixstax.net:587
GF_SMTP_USER=grafana@ps1.helixstax.com
GF_SMTP_PASSWORD=<your-postal-grafana-password>
GF_SMTP_FROM_ADDRESS=grafana@helixstax.net
GF_SMTP_FROM_NAME=Helix Stax Grafana
GF_SMTP_SKIP_VERIFY=false # Keep this false
```

#### **n8n Workflow for Bounce Handling**
1.  **Webhook Node:**
    *   `POST`, `JSON`, Path: `postal-events`
    *   Responds: `Immediately`
2.  **Switch Node:**
    *   Switches on `{{ $json.body.event }}`
    *   Output 1: `Equals`: `MessageBounced`
    *   Output 2: `Equals`: `SpamComplaint`
3.  **MessageBounced Path -> Rocket.Chat Node:**
    *   Webhook URL: `https://chat.helixstax.net/hooks/...` for `#ops-alerts`
    *   Message Text:
        ```
        🔴 Email Bounce Detected
        To: {{ $json.body.payload.message.to }}
        Subject: {{ $json.body.payload.message.subject }}
        Reason: {{ $json.body.payload.details.bounce }} - {{ $json.body.payload.details.diagnostic }}
        Tag: {{ $json.body.payload.message.tag }}
        ```
4.  Optionally, add a function node to add the email to a suppression list in a database.
