Of course. This is an excellent capstone project that requires a holistic understanding of a modern, cloud-native infrastructure stack. The resulting reference document will be the "source of truth" for your AI agents, enabling them to operate the entire system cohesively.

Here is the comprehensive research document, structured to answer your specific integration questions.

***

# Gemini Deep Research: Helix Stax Infrastructure Integration (Capstone)

**Document Purpose:** This is the master integration reference for the Helix Stax infrastructure. It is designed to be loaded by an AI agent to provide a complete, end-to-end understanding of how all services connect, communicate, and depend on one another. It covers data flows, dependencies, failure modes, and operational procedures for the entire stack.

**Core Philosophy:**
1.  **GitOps is King:** The `infra` Git repository is the single source of truth. All changes are made via Pull Requests and synced by ArgoCD.
2.  **Centralized Identity:** Zitadel is the single source of truth for all human and machine identity. No service uses local users.
3.  **Secrets are Dynamic:** Secrets are managed centrally in OpenBao and dynamically injected into pods via the External Secrets Operator. Static secrets in Git are encrypted with SOPS and only used for bootstrapping.
4.  **Everything is Observable:** All components must expose metrics, structured logs, and health checks to the central observability stack.
5.  **Automate Recovery:** Backups are automated via Velero and CloudNativePG. Recovery procedures are documented and tested.

---

## 1. Full Architecture Map & Traffic Flow

This section details the journey of a request from the public internet to a service running inside the K3s cluster.

### ## SKILL.md Content
- **Public Traffic Flow:** `User -> Cloudflare (WAF/CDN) -> Traefik (Hetzner IP) -> K8s Service`
- **Internal Traffic Flow:** `User -> Cloudflare Zero Trust -> Traefik (Hetzner IP) -> K8s Service`
- **Domain Strategy:**
    - `helixstax.com`: Public-facing services, Cloudflare-proxied (orange-cloud).
    - `helixstax.net`: Internal tools, DNS-only (grey-cloud), protected by Cloudflare Access policies, not cached.
- **TLS Termination:** Happens at Traefik. TLS certificates are Cloudflare Origin CA (15-year wildcard), stored as Kubernetes Secrets and referenced in IngressRoute `tls.secretName`. No cert-manager or Let's Encrypt.
- **CrowdSec Integration:** The `crowdsec-bouncer-traefik` is deployed as middleware in Traefik. It intercepts requests *after* Cloudflare and *before* they reach the service. It makes a decision based on the source IP against the CrowdSec Local API.
- **CI/CD Image Flow:** `Devtron CI -> docker build -> docker push (harbor.helixstax.net) -> ArgoCD -> K3s Node -> docker pull (harbor.helixstax.net)`

### ## reference.md Content

**ASCII Architecture Diagram:**

```plaintext
                               +-------------------------------------------------------------+
                               |                      The Internet                           |
                               +-------------------------------------------------------------+
                                                    |
         +------------------------------------------------------------------------------------------+
         |                                     Cloudflare Edge                                      |
         |  +----------------+   +-----------------+    +----------------+    +------------------+  |
         |  | DNS            |   |   WAF / DDoS    |    |  Zero Trust    |    |  CDN (for .com)  |  |
         |  | helixstax.com  |-->| (for .com)      |--> | (for .net)     |--> |                  |  |
         |  | helixstax.net  |   +-----------------+    +----------------+    +------------------+  |
         +--------------------------------|---------------------------------------------------------+
                                          |
                                          | (A Records pointing to 178.156.233.12)
                                          v
+----------------------------------------------------------------------------------------------------+
|                                      Hetzner Cloud Network                                         |
|  +-----------------------------------------------------------------------------------------------+ |
|  | K3s Cluster (CP: 178.156.233.12, Worker: 5.78.145.30)                                          | |
|  |  +------------------------------------------------------------------------------------------+ | |
|  |  | Traefik Ingress Controller (Ports 80, 443)                                               | | |
|  |  | +--------------------------------------------------------------------------------------+ | | |
|  |  | | Middleware Chain                                                                     | | | |
|  |  | | 1. Rate Limiting                                                                     | | | |
|  |  | | 2. CrowdSec Bouncer (IP reputation check)                                            | | | |
|  |  | | 3. OIDC Auth (via forwardAuth to Zitadel for some apps)                              | | | |
|  |  | +--------------------------------------------------------------------------------------+ | | |
|  |  |                                          | (Routing via IngressRoute)                  | | |
|  |  |  +---------------------------------------+-------------------------------------------+ | | |
|  |  |  v                                       v                                           v | | |
|  |  | +-----------------+               +-------------------+                 +---------------+ | |
|  |  | | n8n Service     |               | Rocket.Chat Svc   |                 | Grafana Svc   | | |
|  |  | +-----------------+               +-------------------+                 +---------------+ | |
|  |  +------------------------------------------------------------------------------------------+ | |
|  +-----------------------------------------------------------------------------------------------+ |
+----------------------------------------------------------------------------------------------------+
```

**Traffic Flow Details:**

1.  **DNS Resolution:**
    -   `grafana.helixstax.net`: A DNS-only (grey-cloud) `A` record `178.156.233.12`. Access is controlled by Cloudflare Zero Trust policies, which require Zitadel login.
    -   `www.helixstax.com`: A proxied (orange-cloud) `A` record `178.156.233.12`. Traffic is filtered by Cloudflare's WAF and CDN.
2.  **Ingress:** All traffic hits the Traefik `LoadBalancer` Service on the control-plane node (`helix-stax-cp`).
3.  **TLS:** Traefik terminates TLS using Cloudflare Origin CA certificates (15-year wildcard for `*.helixstax.net` and `*.helixstax.com`). Certs are stored as Kubernetes Secrets managed via OpenBao/ESO. No cert-manager or Let's Encrypt.
4.  **Routing:** Traefik reads `IngressRoute` CRDs to determine where to send traffic.
5.  **Middleware:** Before forwarding to the backend service, Traefik applies a middleware chain defined in the `IngressRoute`. A typical chain is:
    -   `CrowdSec`: Checks the client IP against the local CrowdSec blocklist.
    -   `Auth`: For some internal services, Traefik might use `forwardAuth` to an authentication service which verifies the OIDC token provided by Cloudflare Access.
6.  **WebSockets:** For services like Rocket.Chat and n8n's webhooks, the `IngressRoute` needs no special configuration. Traefik v2+ handles WebSockets automatically over HTTP/1.1 connections.
7.  **gRPC:** Not currently in use, but if needed, Traefik supports gRPC over h2c (cleartext HTTP/2). This would require annotating the `IngressRoute` and Service to specify the `h2c` scheme.
8.  **CI/CD Registry Flow:**
    -   Devtron builds a container image during its CI pipeline.
    -   It uses a robot account from Harbor to authenticate to `harbor.helixstax.net`.
    -   It pushes the new image (e.g., `harbor.helixstax.net/helix-stax/n8n:v1.2.3`).
    -   The pipeline then updates a values file in a Git repository with the new image tag.
    -   ArgoCD detects the change in the Git repository.
    -   ArgoCD applies the updated Helm release, causing K3s to schedule a new pod.
    -   The K3s node pulls the new image from `harbor.helixstax.net` using a cluster-wide `imagePullSecret`.

### ## examples.md Content

**Example Traefik `IngressRoute` for Grafana (Internal):**

```yaml
# grafana-ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`grafana.helixstax.net`)
      kind: Rule
      services:
        - name: grafana
          port: 3000
      middlewares:
        - name: crowdsec-bouncer # From crowdsec namespace
          namespace: crowdsec
        - name: traefik-forward-auth # Optional: if you use a secondary auth gateway
          namespace: auth
  tls:
    secretName: grafana-origin-ca-tls # Cloudflare Origin CA cert
```

# TLS Architecture: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
# No cert-manager or Let's Encrypt. Wildcard cert covers *.helixstax.net and *.helixstax.com.
# Secret created with: kubectl create secret tls <service>-origin-ca-tls --cert=origin-cert.pem --key=origin-key.key -n <namespace>

---

## 2. Service Dependency Graph

This defines the bootstrap order and runtime dependencies. Failures in root services will cascade up the stack.

### ## SKILL.md Content
- **Tier 0 (The Foundation):** OpenTofu/Ansible -> K3s Cluster
- **Tier 1 (Core Services - Must be first):**
    1.  `Traefik` (Ingress)
    2.  `OpenBao` + `ESO` (Secrets — also manages Cloudflare Origin CA cert delivery)
    3.  `CloudNativePG` Operator (Database)
    4.  TLS: Cloudflare Origin CA secrets pre-loaded before Traefik routes go live (no cert-manager)
- **Tier 2 (Storage & Identity - Depends on Tier 1):**
    1.  `PostgreSQL Cluster` (created by CloudNativePG)
    2.  `MinIO` (Object Storage)
    3.  `Valkey` (Cache)
    4.  `Zitadel` (depends on PostgreSQL)
- **Tier 3 (Infrastructure Apps - Depends on Tier 2):**
    1.  `Harbor` (depends on PostgreSQL, MinIO)
    2.  `Observability Stack` (Prometheus, Loki, Grafana - Loki depends on MinIO, Grafana depends on Zitadel)
    3.  `ArgoCD` & `Devtron` (depends on Zitadel, Harbor)
    4.  `CrowdSec`, `Kyverno`
- **Tier 4 (User Applications - Depends on Tiers 2 & 3):**
    1.  `n8n`, `Outline`, `Rocket.Chat`, `Postal`, `Backstage` (all depend on PostgreSQL & Zitadel)
- **Tier 5 (Backup):**
    1.  `Velero` (depends on MinIO)

### ## reference.md Content

**Dependency DAG (Simplified):**

```plaintext
            K3s Cluster
                 |
      +----------+-----------+
      |          |           |
  Traefik   OpenBao+ESO (incl. Origin CA secrets)
      |          |           |
      +----------+-----------+
                 |
        CloudNativePG Operator
                 |
         PostgreSQL Cluster  <---------------------------------------------+
                 |                                                         |
      +----------+-------------------------------------------------------+ |
      |          |          |          |          |          |           | |
   Zitadel      MinIO     Valkey     Harbor     Postal      Outline     n8n |
      |          |                                                         |
      |          +----------------------+----------------------+           |
      |          |                      |                      |           |
      |        Loki (Logging)         Velero (Backup)  CloudNativePG (WAL)  |
      |                                                                    |
      +-------------------------------------------------------------+      |
      |                                                             |      |
   Grafana (Auth)                                               ArgoCD(Auth) Rocket.Chat Backstage
                                                                                (Auth)       (Auth)
```

**Detailed Dependency Breakdown:**

*   **PostgreSQL (`CloudNativePG`) is the ultimate data root.**
    *   **Depends on it:** Zitadel, Harbor, n8n, Outline, Rocket.Chat, Postal, Backstage, ArgoCD (optional, if using external DB). Failure here causes mass application outage.
*   **Zitadel is the identity root.**
    *   **Depends on it:** ALL user-facing services for login (Grafana, Harbor, ArgoCD, Devtron, n8n, Outline, etc.), and Cloudflare Access for perimeter auth. Failure here locks everyone out.
*   **MinIO is the object storage root.**
    *   **Depends on it:**
        *   `Loki`: For long-term log storage (chunks).
        *   `Velero`: For cluster backups.
        *   `Harbor`: For container image and chart storage.
        *   `CloudNativePG`: For continuous WAL archiving and base backups.
        *   `Outline`: For image/file uploads.
    *   Failure here degrades observability, backups, CI/CD, and application functionality.
*   **OpenBao + External Secrets Operator (ESO) are the secret management root.**
    *   **Depends on it:** Nearly *every pod* at startup. A pod's `initContainer` may fail if ESO cannot fetch secrets from OpenBao. Existing pods will run until their secrets/tokens need rotation.
*   **Traefik is the ingress root.**
    *   **Depends on it:** Any service exposed via `IngressRoute`. Failure means no external access to any service.
*   **Harbor is the image registry root.**
    - **Depends on it:** ArgoCD and K3s for deploying all applications. Devtron for pushing built images. Failure here halts all deployments and new pod rollouts.

### ## examples.md Content

**ArgoCD `Application` for a Tier 1 service (Traefik):**

```yaml
# argocd/app-traefik.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/helix-stax/infra.git'
    path: charts/traefik
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: traefik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**ArgoCD `Application` for a Tier 4 service (n8n):**
Note the dependencies are implicit in the bootstrap order, not explicitly defined in ArgoCD.

```yaml
# argocd/app-n8n.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: n8n
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/helix-stax/infra.git'
    path: charts/n8n
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: n8n
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 3. Authentication Flow (Zitadel as Central IdP)

Zitadel is the heart of all user and machine authentication.

### ## SKILL.md Content
- **Standard User Flow (SSO):**
    1. User navigates to `grafana.helixstax.net`.
    2. Cloudflare Access intercepts, redirects to `zitadel.helixstax.net`.
    3. User logs into Zitadel (MFA may be required).
    4. Zitadel redirects back to Cloudflare with an auth token.
    5. Cloudflare validates token, generates its own session JWT, and forwards user to Grafana.
    6. Grafana's OIDC login button (or auto-redirect) sends user to Zitadel again (this is fast due to SSO session).
    7. Zitadel returns an OIDC `id_token` and `access_token` to Grafana.
    8. Grafana validates the token and logs the user in.
- **Adding a new Service to Zitadel:**
    1. In Zitadel UI: Go to Project -> Applications -> Add Application.
    2. Choose **OIDC**.
    3. **Name:** `My New App`
    4. **Redirect URIs:** `https://my-new-app.helixstax.net/oauth/callback` (get this from app's docs).
    5. **Post Logout URI:** `https://my-new-app.helixstax.net/logout`
    6. Note the **Client ID** and generate a **Client Secret**.
    7. Store the client secret in OpenBao: `bao kv put kv/services/my-new-app/oidc client_secret="<secret>"`
- **Machine-to-Machine (M2M):** Use a **Service User** with a **PAT (Personal Access Token)** or **OIDC Client Credentials Flow**.
    - Example: Devtron uses a Harbor Robot Account secret, not a full OIDC flow. Alertmanager uses a simple webhook URL for Rocket.Chat, no auth needed on that endpoint.

### ## reference.md Content

**OIDC Integration Patterns:**

| Service | OIDC Integration Method | Key Configuration |
| :--- | :--- | :--- |
| **Grafana** | Built-in OIDC provider | `GF_AUTH_GENERIC_OIDC_CLIENT_ID`, `GF_AUTH_GENERIC_OIDC_CLIENT_SECRET`, `GF_AUTH_GENERIC_OIDC_SCOPES="openid profile email"`, `GF_AUTH_GENERIC_OIDC_AUTH_URL`, `GF_AUTH_GENERIC_OIDC_TOKEN_URL` |
| **ArgoCD** | `argocd-cm` ConfigMap `oidc.config` | `name`, `issuer`, `clientID`, `clientSecret`, `requestedScopes: ['openid', 'profile', 'email']` |
| **Harbor** | UI Configuration `Authentication` -> `OIDC` | `OIDC Provider Name`, `OIDC Endpoint`, `Client ID`, `Client Secret`, `Scope: "openid profile email"` |
| **Devtron** | `dex` configuration via Helm values | Dex connectors config pointing to Zitadel as an upstream OIDC provider. |
| **Outline** | Environment variables | `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_AUTH_URI`, `OIDC_TOKEN_URI`, `OIDC_USERINFO_URI`, `OIDC_PROVIDER_NAME="Zitadel"` |
| **Rocket.Chat**| `Administration` -> `OAuth` -> `Custom OAuth` | `URL`, `Token Path`, `Identity Path`, `Authorize Path`, `Scope: "openid profile email"`, `Client ID`, `Client Secret` |
| **OpenBao** | OIDC Auth Method | `bao auth enable oidc`, `bao write auth/oidc/config oidc_discovery_url=... client_id=... client_secret=...` |

**Role Synchronization:**
- Zitadel can pass user roles/groups via custom claims in the OIDC `id_token`.
- **Grafana:** You can map these claims to Grafana Org roles (Admin, Editor, Viewer). `GF_AUTH_GENERIC_OIDC_ROLE_ATTRIBUTE_PATH` is used to parse the claim. Example: `contains(groups, 'grafana-admins') && 'Admin' || 'Viewer'`
- **ArgoCD:** The `argocd-rbac-cm` ConfigMap can map OIDC groups to ArgoCD roles. `policy.csv: 'g, zitadel-admins, role:admin'`

**Cloudflare Access & Zitadel:**
1.  Configure Zitadel as a generic OIDC Identity Provider in Cloudflare Zero Trust.
2.  Create an Access Application for each `*.helixstax.net` service.
3.  The policy for the application should be "Allow" for users who successfully authenticate with Zitadel.
4.  Optionally, Cloudflare can pass the identity JWT to the origin (Traefik) in a header (`Cf-Access-Jwt-Assertion`). A middleware could validate this, providing a zero-trust network layer before the application's own OIDC login.

### ## examples.md Content

**Add a new Service to Zitadel (Full Workflow):**

1.  **Zitadel UI:**
    -   Project: `helix-stax-apps`
    -   Application Type: OIDC
    -   Name: `Outline`
    -   Redirect URIs: `https://outline.helixstax.net/auth/oidc.callback`
    -   *Save*, then copy the **Client ID** and generate/copy a **Client Secret**.

2.  **OpenBao CLI (or UI):**
    ```bash
    # Login to OpenBao first
    export BAO_ADDR='https://bao.helixstax.net'
    bao login <your_auth_method>

    # Store the secret
    bao kv put kv/services/outline/oidc \
      client_id="2169xxxxxxxxxxxxxx@helixstax" \
      client_secret="A_VERY_SECRET_VALUE_FROM_ZITADEL"
    ```

3.  **External Secrets Operator Manifest (`infra` repo):**
    ```yaml
    # infra/charts/outline/templates/external-secret.yaml
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: outline-oidc-secrets
    spec:
      secretStoreRef:
        name: openbao-cluster-store # A ClusterSecretStore pointing to OpenBao
        kind: ClusterSecretStore
      target:
        name: outline-oidc-secrets # This K8s secret will be created
        creationPolicy: Owner
      data:
      - secretKey: OIDC_CLIENT_ID
        remoteRef:
          key: kv/data/services/outline/oidc
          property: client_id
      - secretKey: OIDC_CLIENT_SECRET
        remoteRef:
          key: kv/data/services/outline/oidc
          property: client_secret
    ```
4.  **Outline Helm Values (`infra` repo):**
    ```yaml
    # infra/charts/outline/values.yaml
    env:
      - name: OIDC_PROVIDER_NAME
        value: "Zitadel"
      - name: OIDC_AUTH_URI
        value: "https://zitadel.helixstax.net/oauth/v2/authorize"
      - name: OIDC_TOKEN_URI
        value: "https://zitadel.helixstax.net/oauth/v2/token"
      - name: OIDC_USERINFO_URI
        value: "https://zitadel.helixstax.net/oidc/v1/userinfo"
      # These values will be mounted from the K8s secret created by ESO
      - name: OIDC_CLIENT_ID
        valueFrom:
          secretKeyRef:
            name: outline-oidc-secrets
            key: OIDC_CLIENT_ID
      - name: OIDC_CLIENT_SECRET
        valueFrom:
          secretKeyRef:
            name: outline-oidc-secrets
            key: OIDC_CLIENT_SECRET
    ```
5.  `git commit && git push`. ArgoCD syncs, and Outline is now configured for OIDC.

---
... The document would continue in this exhaustive, structured format for all 10 sections. Due to the immense length, I will provide a high-level summary for the remaining sections, demonstrating the same pattern of SKILL/REFERENCE/EXAMPLES content you can use to build the full document.

---

## 4. Observability Flow (Metrics, Logs, Traces, Alerts)

### Summary

-   **Metrics:** `Service /metrics` -> `Prometheus` (scrapes via `ServiceMonitor` CRDs) -> `Grafana` (queries Prometheus) & `Alertmanager` (receives alerts from Prometheus `PrometheusRule` CRDs). Key alerts include `Traefik5xxRate`, `PostgresHighConnections`, `ZitadelAuthFailureRate`, `NodeCPUHigh`, `MinIOCapacity`.
-   **Logging:** `Pod stdout (JSON)` -> `Promtail DaemonSet` -> `Loki` (stores in MinIO bucket `loki-chunks`) -> `Grafana Explore`. Promtail uses pipeline stages to parse Traefik access logs, K3s audit logs, etc., adding labels like `pod`, `namespace`, `level`.
-   **Alerting:** `Alertmanager` -> `Rocket.Chat Webhook` (for `#alerts-critical`, `#alerts-warning`) & `Postal API` (for email fallback). Routing is based on the `severity` label. An n8n webhook is used for complex alert enrichment (e.g., query a service API before sending the alert). The "Dead Man's Switch" is a `Watchdog` alert from Alertmanager that *must* fire continuously to ensure the pipeline is alive.
-   **Dashboards:** Most dashboards (Node Exporter, PostgreSQL, Traefik, K8s) are imported from Grafana.com and provisioned via Helm `values.yaml`. Custom dashboards correlating logs and metrics are built for key applications like n8n.

---

## 5. Backup & Recovery Flow

### Summary

-   **Velero (K8s Manifests & PVCs):**
    -   **Flow:** Daily schedule -> `velero backup create` -> Captures all K8s objects (Deployments, CRDs, etc.) + uses `local-path-provisioner` snapshots for PVCs -> Stores tarball in `velero-backups` bucket on MinIO.
    -   **Critical Note:** Velero *does not* back up database contents transactionally. It's for cluster state.
    -   **Offsite:** MinIO site replication configured to continuously mirror the `velero-backups` bucket to a Backblaze B2 bucket.
-   **CloudNativePG (PostgreSQL Data):**
    -   **Flow:** Continuous WAL (Write-Ahead Log) streaming -> `cnpg-wal` MinIO bucket. This enables Point-In-Time-Recovery (PITR).
    -   **Base Backups:** A full base backup is taken daily and stored in the `cnpg-backups` MinIO bucket.
    -   **Offsite:** MinIO site replication mirrors `cnpg-wal` and `cnpg-backups` buckets to Backblaze B2.
-   **Full DR Scenario (Cluster Total Loss):**
    1.  Provision new nodes with OpenTofu/Ansible.
    2.  Install K3s.
    3.  Bootstrap core services: Traefik, OpenBao, ESO, CloudNativePG operator, MinIO. Pre-load Cloudflare Origin CA secrets into K8s before Traefik routes go live.
    4.  Configure MinIO to connect to the Backblaze B2 bucket (if local MinIO data is lost).
    5.  Restore PostgreSQL cluster first: Create a new `Cluster` manifest pointing to the backup location in MinIO. CloudNativePG handles the recovery.
    6.  Install Velero and point it to the backup bucket.
    7.  Run `velero restore create --from-backup <backup-name>`. Restore namespaces in dependency order (e.g., `zitadel` before `grafana`).
    8.  Verify all applications are running and data is consistent.
    -   **Estimated RTO (Recovery Time Objective):** 2-4 hours. **RPO (Recovery Point Objective):** < 5 minutes (due to WAL streaming).

---

## 6. CI/CD Flow

### Summary

-   **Code Push (`git push` to app repo):**
    1.  GitHub Webhook -> Triggers Devtron CI Pipeline.
    2.  **CI Steps:** `Clone` -> `Gitleaks Scan` (fail if secrets found) -> `Build Image` -> `Push to harbor.helixstax.net`.
    3.  Harbor's integrated Trivy scanner scans the new image for vulnerabilities. A webhook can be configured to block deployment if CRITICAL vulns are found.
    4.  The final CI step updates the `image.tag` in a `values.yaml` file in the `infra` Git repository and pushes the change.
-   **Config Change (`git push` to `infra` repo):**
    1.  ArgoCD polls the `infra` repo.
    2.  Detects the change (e.g., the new image tag or a config map update).
    3.  Applies the Helm chart or manifest to the cluster (`helm upgrade` effectively). The `syncPolicy` is `automated: { selfHeal: true }` for continuous reconciliation.
-   **Secret Injection:** This flow is central. When a pod starts, its `ExternalSecret` manifest tells the ESO to fetch data from `kv/data/services/myapp` in OpenBao. ESO creates a native Kubernetes `Secret`, which is then mounted into the pod as environment variables or files. This happens at deploy time.

---

## 7. Secret Management Flow

### Summary

-   **SOPS + age (Git-encrypted secrets):**
    -   **Use Case:** For "secret zero" — the secrets needed to bootstrap the cluster *before* OpenBao is running. Examples: `cloudflare-api-token-secret`, initial OpenBao config, ArgoCD admin password.
    -   **Process:** A file like `secrets.sops.yaml` is encrypted with an `age` key. The private `age` key is kept offline and provided to the AI agent or admin securely. ArgoCD uses the `argocd-vault-plugin` which can decrypt SOPS files on the fly before applying manifests.
-   **OpenBao (Runtime Vault):**
    -   **The Source of Truth:** All application secrets, database credentials, API keys, and OIDC client secrets live here.
    -   **Auth:** Pods authenticate via the `kubernetes` auth method. ESO uses a dedicated `AppRole`. Humans use OIDC via Zitadel.
    -   **Engines:** `KV v2` for static secrets, `Database` for dynamic PostgreSQL credentials for apps, `PKI` for internal mTLS certs if needed.
    -   **Setup:** Runs as a `StatefulSet` on the control-plane node (`helix-stax-cp`) using integrated Raft storage. Auto-unseal is configured using a cloud KMS or a local key for simplicity in this small setup, accepting the risk.
-   **External Secrets Operator (The Bridge):**
    -   **Function:** Polls OpenBao and syncs secrets into Kubernetes `Secret` objects.
    -   **Configuration:** A single `ClusterSecretStore` CRD is deployed, configured with the OpenBao address and AppRole credentials for ESO to authenticate. Each application namespace has `ExternalSecret` objects that reference this cluster store.

---

## 8. Network Flow & Security Layers

### Summary

-   **Security Layers (Inbound):**
    1.  **Cloudflare (L7):** WAF, rate limiting, DDoS protection, bot management.
    2.  **Hetzner Firewall (L4):** Only ports 80, 443 are open to the world. Port 6443 (K8s API) and 22 (SSH) are restricted to specific, trusted IP addresses.
    3.  **CrowdSec (L7-ish):** `traefik-bouncer-middleware` blocks IPs based on malicious behavior detected across the cluster (e.g., failed logins, probing) and from the community blocklist.
    4.  **Traefik (L7):** Can apply middleware for rate limiting, IP whitelisting per-route.
    5.  **Kyverno (Admission Control):** Before a pod is created, Kyverno policies check it. This is a powerful internal security boundary.
-   **Internal Network:**
    -   **CNI:** K3s default is Flannel, which provides basic pod-to-pod networking but **does not enforce NetworkPolicy**.
    -   **CRITICAL ACTION:** To enforce `NetworkPolicy` (e.g., "only pods in namespace `monitoring` can talk to the Prometheus pod"), a network policy controller must be installed. For Flannel, you can add one like Calico. A better long-term solution is to migrate the CNI to Cilium, which has this built-in and offers many advanced features.
    -   **DNS:** CoreDNS handles internal service discovery (e.g., `grafana.monitoring.svc.cluster.local`).
-   **Kyverno Policies Enforced:**
    -   `require-labels`: All `Deployments` must have `app` and `version` labels.
    -   `disallow-latest-tag`: Pods cannot use the `:latest` image tag.
    -   `require-resource-limits`: All containers must specify CPU and memory limits.
    -   `restrict-image-registries`: Only allow images from `harbor.helixstax.net`.

---

## 9. Failure Analysis & Blast Radius

### Summary

| Component Failure | Blast Radius | Recovery Procedure / Mitigation |
| :--- | :--- | :--- |
| **`helix-stax-vps` Down** | High | All pods on the worker node are down. If using `local-path-provisioner`, **their data is inaccessible until the node returns.** K3s reschedules stateless pods to the control plane if resources allow. **CRITICAL RISK:** Migrate stateful workloads to replicated storage (e.g., Longhorn) or run replicas on different nodes. |
| **`helix-stax-cp` (CP) Down** | Catastrophic | Entire cluster is down. K8s API is offline, etcd is gone. Recovery requires restoring from an etcd snapshot (K3s auto-snapshots to `/var/lib/rancher/k3s/server/db/snapshots`) and then a Velero restore for PVC data if needed. |
| **PostgreSQL Down** | Massive | Zitadel, Harbor, and all user applications fail. Recovery: CloudNativePG operator will attempt to restart pods. If the primary fails, it can automatically failover to a replica (requires at least 2 PG pods on different nodes). |
| **Zitadel Down** | Massive | No new logins to any service. Existing sessions might survive for a short time. Blast radius is contained if an app can function without active auth. Recovery: Zitadel depends on PostgreSQL, so fix PG first. |
| **Traefik Down** | High | All external access to services is lost. Internal pod-to-pod communication still works. Recovery: ArgoCD self-heal should redeploy it. If not, manual `kubectl apply`. |
| **MinIO Down** | High (Delayed) | Loki stops ingesting logs. Velero backups fail. Harbor cannot serve/store images. PG WAL archiving fails (risking data loss). Not an immediate outage, but critical services degrade quickly. MinIO is a single point of failure in this setup. |
| **OpenBao Sealed** | High | New pods that need secrets will fail to start. Existing pods run until their tokens/secrets expire. Recovery: Unseal OpenBao immediately via its CLI/API. |
| **Cloudflare Down** | High (Public) | All external access via `helixstax.com` and `.net` fails. The cluster itself remains fully operational and can be accessed via IP. |

---

## 10. Bootstrap Order & Day-2 Operations

### Summary

-   **Bootstrap Order (Abbreviated):**
    1.  **IaC:** OpenTofu (Hetzner VPS, Firewall) -> Ansible (OS hardening, K3s install).
    2.  **GitOps:** Manually apply ArgoCD manifest.
    3.  **ArgoCD App of Apps:** Configure ArgoCD to point to the `infra` repo. It will then deploy everything else based on the dependency Tiers defined in Section 2.
    4.  **Manual Steps:**
        -   Bootstrap OpenBao (init, unseal, store unseal keys securely).
        -   Configure `ClusterSecretStore` to talk to OpenBao.
        -   Configure Zitadel with initial admin and OIDC clients for core tools like ArgoCD.
        -   The rest is automated by ArgoCD.

-   **Day-2 Operations (Checklist):**
    -   **K3s Upgrade:** Cordon & drain worker -> `k3s-upgrade.sh` on CP -> `k3s-upgrade.sh` on worker -> Uncordon worker.
    -   **Helm Chart Upgrade:** Create a PR in `infra` repo to bump the chart version in `Chart.yaml` or a value in `values.yaml`. Merge to deploy.
    -   **OIDC Secret Rotation:** 1. Generate new secret in Zitadel. 2. Update the secret in OpenBao. 3. Restart the application deployment for ESO to force a re-sync and mount the new secret.
    -   **PostgreSQL Major Version Upgrade:** Managed by CloudNativePG. A new `Cluster` manifest is created, and the operator handles the creation of a new cluster and streaming replication from the old one, with a final switchover. This is a major, planned operation.

-   **Adding a New Service (Master Checklist):**
    1.  **DNS:** Add record in Cloudflare (`A` or `CNAME`).
    2.  **Identity:** Create OIDC Client in Zitadel.
    3.  **Secrets:** Store OIDC secret in OpenBao.
    4.  **Database:** Create `Database` CRD for CloudNativePG if needed.
    5.  **Helm Chart:** Create/add Helm chart to `infra` repo.
    6.  **Configuration:** In `values.yaml`, add IngressRoute config, point to OIDC secrets, and configure database connection strings.
    7.  **Secrets Sync:** Create an `ExternalSecret` manifest to sync from OpenBao to a K8s `Secret`.
    8.  **Observability:** Create a `ServiceMonitor` and `PrometheusRule` for the new service.
    9.  **ArgoCD:** Create an `Application` manifest for the new service.
    10. **Git Push:** Commit all changes to the `infra` repo. ArgoCD takes over.
