Here is the comprehensive research document for your AI coding agents, structured as requested.

***

# Zitadel

## SKILL.md Content
Zitadel is our Identity Provider (IdP) and the single source of truth for authentication. All platform services (Grafana, ArgoCD, etc.) delegate login to Zitadel. Staff log in to Zitadel using their Google Workspace accounts.

**Common `zitadel-tools` (ztl) Commands**

```bash
# Login (first-time setup)
ztl login --org-id 'YOUR_ORG_ID' --project-id 'YOUR_PROJECT_ID'

# Create a new OIDC application for a service
ztl create application-oidc \
  --org-id 'YOUR_ORG_ID' \
  --project-id 'YOUR_PROJECT_ID' \
  --name 'grafana' \
  --redirect-uris 'https://grafana.helixstax.net/login/generic_oauth' \
  --response-types CODE \
  --grant-types AUTHORIZATION_CODE \
  --app-type WEB \
  --auth-method-type BASIC \
  --version V2 \
  --output-format json

# Create a machine user for automation (e.g., CI/CD)
ztl create machine-user \
  --org-id 'YOUR_ORG_ID' \
  --name 'devtron-ci-agent' \
  --with-secret \
  --output-format json

# Add a user to a project with a role
# First, get the Project ID and User ID
# Then, grant the role
ztl create user-grant \
  --org-id 'YOUR_ORG_ID' \
  --project-id 'PROJECT_ID' \
  --user-id 'USER_ID' \
  --role-keys 'Admin'
```

**Common API `curl` Patterns (using a Personal Access Token)**

```bash
# Get all projects in the organization
# ZITADEL_ORG_ID and ZITADEL_PAT are environment variables
curl -X POST "https://zitadel.helixstax.net/management/v1/projects/_search" \
  -H "Authorization: Bearer $ZITADEL_PAT" \
  -H "Content-Type: application/json" \
  -d '{"query": {"limit": 100}}'

# Create an OIDC Application (e.g., ArgoCD)
curl -X POST "https://zitadel.helixstax.net/management/v1/projects/{projectId}/apps/oidc" \
  -H "Authorization: Bearer $ZITADEL_PAT" \
  -H "Content-Type: application/json" \
  --data-raw '{
    "name": "argocd",
    "redirectUris": ["https://argocd.helixstax.net/auth/callback"],
    "responseTypes": ["OIDC_RESPONSE_TYPE_CODE"],
    "grantTypes": ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"],
    "appType": "OIDC_APP_TYPE_WEB",
    "authMethodType": "OIDC_AUTH_METHOD_TYPE_BASIC",
    "version": "OIDC_VERSION_1_0"
  }'
```

**OIDC Client Configuration Cheatsheet**

| Service             | Redirect URI(s)                                                  | Grant Types           | Scopes (min)               | Auth Method | Notes                                                              |
|---------------------|------------------------------------------------------------------|-----------------------|----------------------------|-------------|--------------------------------------------------------------------|
| **Grafana**         | `https://grafana.helixstax.net/login/generic_oauth`              | `authorization_code`  | `openid profile email`     | `Basic`     | Map `groups` claim to `Grafana Admin` role.                          |
| **ArgoCD**          | `https://argocd.helixstax.net/auth/callback`                     | `authorization_code`  | `openid profile email groups`| `Basic`     | Enable `Request offline access`. Requires group mapping for RBAC.    |
| **Devtron**         | `https://devtron.helixstax.net/orchestrator/api/v1/user/login`| `authorization_code`  | `openid profile email`     | `Basic`     | Map groups to SuperAdmin role.                                     |
| **Harbor**          | `https://harbor.helixstax.net/c/oidc/callback`                   | `authorization_code`  | `openid profile email groups`| `Basic`     | Set Admin Group Claim. Auto-onboard users.                         |
| **Backstage**       | `https://backstage.helixstax.net/api/auth/zitadel/handler/frame` | `authorization_code`  | `openid profile email`     | `PKCE`      | Use Zitadel auth provider plugin.                                  |
| **Outline**         | `https://docs.helixstax.net/auth/oidc.callback`                  | `authorization_code`  | `openid profile email`     | `Basic`     | Set user info endpoint for JIT provisioning.                       |
| **Rocket.Chat**     | `https://chat.helixstax.net/_oauth/zitadel`                      | `authorization_code`  | `openid profile email`     | N/A         | Custom OAuth2 provider. Map `preferred_username` to username.        |
| **MinIO Console**   | `https://minio.helixstax.net/oauth_callback`                     | `authorization_code`  | `openid profile policies`  | `Basic`     | Use custom `policies` claim from Actions to map to MinIO policies. |
| **Cloudflare Access**| `https://helixstax.cloudflareaccess.com/cdn-cgi/access/callback` | `authorization_code`  | `openid profile email groups`| `Basic`     | Set up as an IdP in Cloudflare Zero Trust.                         |


**Troubleshooting Decision Tree**

1.  **Symptom:** "Invalid Redirect URI" or `redirect_uri_mismatch` error after logging in.
    *   **Cause:** The Redirect URI configured in the service does not exactly match one of the URIs configured in the Zitadel OIDC application.
    *   **Fix:** Copy the exact URI from the error message. In Zitadel UI/API, add it to the application's list of Redirect URIs. Check for trailing slashes, `http` vs `https`, and hostname differences.

2.  **Symptom:** "Invalid Client" or `invalid_client` error.
    *   **Cause:** The Client ID or Client Secret configured in the service is incorrect.
    *   **Fix:** Regenerate the client secret in Zitadel and update it in the service's configuration (via OpenBao/ESO). Verify the Client ID is correct.

3.  **Symptom:** "Access Denied" or user logs in but has no permissions.
    *   **Cause 1:** The user doesn't have a grant to the project in Zitadel.
    *   **Fix 1:** In Zitadel, find the user and grant them the required role(s) for the project associated with the application.
    *   **Cause 2:** The service (e.g., ArgoCD, Grafana) relies on a `groups` claim for RBAC, but the claim is missing or incorrect.
    *   **Fix 2:** Ensure the OIDC client in the service is requesting the `groups` scope. Ensure the ID Token is enabled for the Zitadel application. Use a Zitadel Action to format the `groups` claim if needed.

4.  **Symptom:** Login loop between Cloudflare Access and Zitadel.
    *   **Cause:** Misconfigured cookies or session settings. Cloudflare Access and Zitadel may be overwriting each other's cookies if they use the same domain with different subdomains.
    *   **Fix:** Ensure Cloudflare Access is configured with `https://helixstax.cloudflareaccess.com` and Zitadel is on `https://zitadel.helixstax.net`. Verify cookies are scoped correctly to their respective domains.

---
## reference.md Content
### **Zitadel: Deep Reference**

This document provides exhaustive details on Zitadel's architecture, APIs, and configuration for advanced use cases, performance tuning, and security hardening.

#### **1. CLI & API Reference**

*   **`zitadel-tools` (ztl):** A Go-based CLI for managing Zitadel resources. It's ideal for scripting and CI/CD. It authenticates using a JSON key file generated from a service account or via browser-based login.
    *   **Installation:** `go install github.com/zitadel/zitadel-tools/cmd/ztl@latest`
    *   **Authentication:** `ztl login --org-id <id> --project-id <id>` for interactive. For CI, use a machine user key: `ztl login --key-path ./machine-key.json`.
    *   **Resource Coverage:** Covers most Management API resources: orgs, projects, apps, users (human/machine), grants, roles, IdPs. Some instance-level settings might require the API.

*   **Zitadel APIs:**
    1.  **Management API (`/management/v1/`):** Primary API for managing resources within your organization (projects, apps, users, roles, settings). This is what `ztl` and the OpenTofu provider use. Requires an authenticated user (human or machine) with appropriate grants.
    2.  **Admin API (`/admin/v1/`):** For managing instance-wide settings (branding, security policies, organizations). Requires an instance-level admin user.
    3.  **Auth API (`/auth/v1/`):** Used by end-users for authentication flows (login, registration, password reset). Your applications will interact with its OIDC/SAML endpoints, not typically called directly.

*   **Authentication for API Calls:**
    1.  **Personal Access Tokens (PATs):** Scoped to a human user, easy to generate in the UI. Ideal for development and manual scripting. Limited lifetime. Bearer token auth.
    2.  **Machine User Tokens (Client Credentials):** A machine user is granted roles, has a client ID and secret. Exchange these for a short-lived access token via the `/oauth/v2/token` endpoint with `grant_type=client_credentials`. Best for service-to-service communication where you can manage a client secret.
    3.  **Service Account JWTs:** Create a machine user, generate a private/public key pair, and upload the public key. Your service signs a JWT with the private key and exchanges it for an access token at `/oauth/v2/token` with `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`. Most secure method for CI/CD and K8s workloads as no long-lived secret is stored.

*   **API URL Structure:** All APIs are relative to your Zitadel instance URL.
    *   Base: `https://zitadel.helixstax.net`
    *   OIDC Discovery: `https://zitadel.helixstax.net/.well-known/openid-configuration`
    *   Management API: `https://zitadel.helixstax.net/management/v1/...`
    *   Admin API: `https://zitadel.helixstax.net/admin/v1/...`
    *   Token Endpoint: `https://zitadel.helixstax.net/oauth/v2/token`
    *   JWKS Endpoint: `https://zitadel.helixstax.net/oauth/v2/keys`

*   **API Rate Limiting & Pagination:** Zitadel APIs are rate-limited. Consult the official documentation for current limits. Search/list endpoints use pagination. A typical search query body includes:
    ```json
    {
      "limit": 100,
      "offset": 0,
      "sortingColumn": "creation_date",
      "asc": false
    }
    ```

*   **OpenTofu/Terraform Zitadel Provider:**
    *   **Provider:** `zitadel/zitadel`
    *   **Authentication:** Uses a `ztl`-compatible key file (`json_key_path`) or token (`pat`).
    *   **Available Resources:** `zitadel_org`, `zitadel_project`, `zitadel_project_role`, `zitadel_application_oidc`, `zitadel_machine_user`, `zitadel_user_grant`, `zitadel_action`, and more. It's the preferred method for managing Zitadel resources as code (IaC).

#### **2. Deployment on K3s (Helm + CloudNativePG)**

*   **Architecture:**
    ```
    Cloudflare Edge -> Traefik Ingress (K3s) -> Zitadel Service -> Zitadel Pod -> CloudNativePG Service -> PG Pod
    ```
*   **Helm Chart:**
    *   **Repo:** `https://charts.zitadel.com`
    *   **Name:** `zitadel`
    *   **Version Pinning:** Always pin the chart version for reproducible deployments, e.g., `4.0.0`.
*   **CloudNativePG Integration:**
    *   Zitadel connects via a standard PostgreSQL DSN. CNPG creates a Kubernetes `Service` and `Secret` for the database cluster.
    *   The `Secret` contains the DSN. You use External Secrets Operator to read this secret and create a new one in Zitadel's namespace if they are different.
    *   **DSN Format:** `postgres://<user>:<password>@<cnpg-service-host>:<port>/<database>?sslmode=require`
*   **Secrets & Environment Variables (via ESO):**
    *   `ZITADEL_MASTERKEY`: A long, random string for encrypting data at rest. Critical. Generate once, store in OpenBao.
    *   `zitadel-postgres-user-password`: The DSN password for the database.
    *   ESO pulls these from OpenBao and creates a secret named `zitadel-secret` in the `zitadel` namespace. The Helm chart then mounts this secret.
*   **Traefik IngressRoute TLS:**
    *   **Recommendation: Edge Termination at Cloudflare.** This simplifies certificate management. Cloudflare handles public certs, and traffic from Cloudflare to Traefik can be encrypted with a Cloudflare Origin CA certificate. Traffic from Traefik to Zitadel can be unencrypted within the cluster mesh.
    *   **Alternative: Passthrough.** Traefik `IngressRouteTCP` can pass encrypted traffic directly to Zitadel. This requires managing TLS certificates within the cluster (e.g., with `cert-manager`) and configuring Zitadel to handle TLS termination. More complex, less benefit with Cloudflare in front.
*   **Startup Sequence:**
    1.  Pod starts, reads config (masterkey, DSN).
    2.  Zitadel binary connects to the database.
    3.  `zitadel setup` command runs, which creates the database schema and performs migrations if needed.
    4.  `zitadel start` command runs, starting the main application server.
    5.  The first time an instance is set up, you create the initial admin user and instance configuration via the UI or API.
*   **Resource Requests/Limits:** For a small setup, start with:
    *   **Requests:** `cpu: 250m`, `memory: 512Mi`
    *   **Limits:** `cpu: 1000m`, `memory: 1Gi`
    *   Monitor with Prometheus and adjust as needed. Database performance is more critical.
*   **Health Checks:**
    *   **Readiness:** `GET /debug/ready` - Checks if Zitadel can serve traffic (e.g., db connection is ok).
    *   **Liveness:** `GET /debug/live` - Checks if the process is running.
*   **Upgrade Procedure:**
    1.  Review the Zitadel release notes for breaking changes and database migration info.
    2.  Update the `version` in your Helm release definition (in ArgoCD/Devtron).
    3.  GitOps syncs the new version. Helm performs a rolling update.
    4.  The new Zitadel pods will start. The `setup` init container will automatically run any required database migrations. Monitor pod logs for success.
    5.  CloudNativePG upgrades should be handled separately and carefully, following CNPG documentation.

#### **3. OIDC Client Configuration (Service Details)**

*   **App Types:**
    *   **Web:** For server-side applications (Grafana, ArgoCD). Can securely store a client secret. Uses Authorization Code flow.
    *   **Native:** For mobile or desktop apps. Cannot store a secret. Must use PKCE.
    *   **API:** For APIs that need to accept Zitadel tokens.
*   **Client ID vs Secret:**
    *   `Client ID`: Public identifier for your application.
    *   `Client Secret`: Private password for your application. Used to authenticate the app itself to Zitadel's token endpoint. Rotate periodically.
*   **Redirect URIs:** Must be an exact match, including the protocol, domain, path, and port. No wildcards are allowed for security. A trailing slash matters. `http://localhost...` is often needed for CLI tools like `argocd`.
*   **Grant Types:**
    *   `AUTHORIZATION_CODE`: Standard, most secure for web apps. User logs in, gets a code, app exchanges code+secret for tokens.
    *   `IMPLICIT`: Legacy, less secure. Tokens are returned directly in the URL. Avoid.
    *   `REFRESH_TOKEN`: Allows an app to get a new access token without re-authenticating the user. Critical for long-lived sessions.
*   **PKCE (Proof Key for Code Exchange):** A security extension for public clients (like Native or SPAs) to prevent authorization code interception. Strongly recommended for any client that cannot keep a secret.

#### **4. SAML & OIDC Federation (Google Workspace)**

*   **Scenario A: Google as External IdP in Zitadel (OAuth/OIDC) - RECOMMENDED**
    *   **Why:** This is the best model for Helix Stax. It leverages Google for what it's good at (user authentication via secure login, MFA) while keeping Zitadel as the central, flexible hub for all platform services. Your services only need to know how to speak OIDC to Zitadel, not to every possible external IdP. It simplifies configuration and token management.
    *   **JIT Provisioning:** On first login via Google, Zitadel automatically creates a corresponding "federated" user. This user exists in Zitadel's database but has no password; authentication is always delegated to Google.
    *   **Account Linking:** If a user `user@helixstax.com` already exists in Zitadel (e.g., created manually), they can link their Google account to it on their first federated login.
*   **Scenario B: Zitadel as SP, Google as SAML IdP**
    *   **Why:** This is a more traditional enterprise pattern. It makes Google Workspace the "hub" and Zitadel just another "spoke" application. It's less flexible if you want to add other external IdPs (e.g., GitHub, a client's IdP) later, as you'd have to manage them all in Google Admin instead of centrally in Zitadel.
*   **SCIM (System for Cross-domain Identity Management):**
    *   Google Workspace can act as a SCIM *client* to provision users *into* other applications. Zitadel can act as a SCIM *server*.
    *   You could configure Google Workspace to automatically create/update/delete users in Zitadel. This is more powerful than JIT but also more complex to set up. For a small team, JIT (Scenario A) is sufficient and simpler.

#### **5. User Management & Data Model**

*   **Hierarchy:** `Instance` (the whole Zitadel installation) > `Organization` (your company, Helix Stax) > `Project` (a logical grouping of apps, e.g., "Monitoring Stack") > `Application` (Grafana, ArgoCD) > `Role` (e.g., "Viewer", "Admin").
*   **Grants:** A `User Grant` connects a `User` to a `Project` with one or more `Roles`. This is the core of authorization.
*   **Multi-Org vs Single-Org:** For Helix Stax, a single organization is perfect. You would only use multiple orgs if you were providing Zitadel as a service to your own clients, giving each client their own isolated organization.
*   **Groups:** Zitadel supports user groups. You can grant roles to a group, and any user in that group inherits the grant. This is the preferred way to manage permissions at scale. This group membership can be passed in the OIDC `groups` claim.
*   **Metadata:** Key-value pairs that can be attached to users. Extremely useful for storing extra information (e.g., `employee_id`, `billing_tier`) that can be added to tokens via Actions.

#### **6. Actions v2 (Custom Logic)**

*   **Runtime:** A sandboxed JavaScript (ES6) environment based on `goja`.
*   **APIs:**
    *   `ctx`: Context object with information about the execution flow.
    *   `api`: Allows making external HTTP `fetch` requests and accessing Zitadel's own API.
    *   `console.log`: For debugging output.
*   **Triggers:** Actions can be triggered on various events, but the most common are:
    *   **Pre-Authentication:** Before a user's credentials are checked.
    *   **Post-Authentication:** After successful credential check, before tokens are minted. Ideal for token enrichment.
*   **Limitations:**
    *   Execution timeout (e.g., 1 second).
    *   No persistent state between executions.
    *   External HTTP calls may be restricted to an allow-list for security.

#### **7. Security Hardening Checklist**
1.  **MFA:** Enforce TOTP or Passkeys for all users at the organization or instance level.
2.  **Passwords:** Set a strong password policy (length, complexity).
3.  **External IdPs:** Disable any social logins you don't use.
4.  **Machine Users:** Use JWT Profile (key-based) auth for all CI/CD, not secrets. One machine user per service. Apply least privilege roles.
5.  **Admin Access:** Limit the number of users with instance-level admin roles. Use project-scoped roles for daily work.
6.  **Token Lifetimes:** Set short-lived access tokens (e.g., 15-60 minutes) and longer-lived refresh tokens (e.g., 8-24 hours). Enable refresh token rotation.
7.  **Helm Chart:** Do not run as root (`securityContext.runAsUser`, `securityContext.runAsGroup`).
8.  **Audit Logs:** Forward audit logs to an external SIEM/log aggregation system (Loki) for retention and analysis.

---
## examples.md Content
### **Zitadel: Ready-to-Use Examples for Helix Stax**

#### **1. Helm `values.yaml` for K3s Deployment**

This configuration assumes Traefik is the Ingress Controller and you have CloudNativePG installed.

```yaml
# values-zitadel.yaml
replicaCount: 1

zitadel:
  masterkeySecretName: zitadel-masterkey # Created by External Secrets Operator
  configmapConfig:
    ExternalDomain: "zitadel.helixstax.net"
    ExternalPort: 443
    ExternalSecure: true
    Log:
      Level: "info"
    Database:
      # This secret key is created by External Secrets Operator
      # from the CNPG-generated secret.
      User:
        PasswordSecret:
          Name: "zitadel-db-secret"
          Key: "password"
      # The rest of the DSN is configured here
      Host: "cnpg-cluster-rw.database.svc.cluster.local"
      Port: 5432
      Database: "zitadel"
      User: "zitadel_user"
      SSL:
        Mode: "require"

  # Minimal resource requests for a small setup
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

ingress:
  enabled: true
  className: "traefik"
  # Annotations for Traefik and Cloudflare
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
    # Assuming Cloudflare Origin CA cert is in a secret called 'helixstax-net-tls'
    traefik.ingress.kubernetes.io/router.tls.secret: "helixstax-net-tls"
  hosts:
    - host: zitadel.helixstax.net
      paths:
        - path: /
          pathType: Prefix
```

#### **2. External Secrets Operator Manifests**

These manifests assume OpenBao is set up at `bao.helixstax.net` and a `BaoAuth` method is configured.

```yaml
# external-secret-zitadel.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: zitadel-secrets-sync
  namespace: zitadel
spec:
  secretStoreRef:
    name: openbao-store # Assumes a ClusterSecretStore is defined
    kind: ClusterSecretStore
  target:
    name: zitadel-masterkey
    creationPolicy: Owner
  data:
  - secretKey: masterkey
    remoteRef:
      key: secret/data/zitadel
      property: masterkey
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: zitadel-db-sync
  namespace: zitadel
spec:
  secretStoreRef:
    # This uses the kubernetes secret store to copy the secret from CNPG
    name: k8s-secret-store 
    kind: ClusterSecretStore
  target:
    name: zitadel-db-secret
    template:
      data:
        password: "{{ .password | toString }}"
  data:
  - secretKey: password
    remoteRef:
      # Sourced from the secret created by CloudNativePG in the 'database' namespace
      key: cnpg-cluster-app
      namespace: database # The namespace where CNPG is deployed
      property: password
```

#### **3. Traefik `IngressRoute` CRD**

This is an alternative to using the standard Kubernetes Ingress object if you need more control.

```yaml
# ingressroute-zitadel.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: zitadel-ingress
  namespace: zitadel
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`zitadel.helixstax.net`)
      kind: Rule
      services:
        - name: zitadel # The name of the Zitadel service created by Helm
          port: 8080
  tls:
    secretName: helixstax-net-tls # Your wildcard or specific TLS secret
```

#### **4. Full Script to Provision All OIDC Clients via `ztl`**

Run this after `ztl login`. It automates the creation of all necessary applications.

```bash
#!/bin/bash
set -e

# --- Configuration ---
ZITADEL_ORG_ID="YOUR_ZITADEL_ORG_ID"

# Create a project for the core platform tools
echo "Creating project 'Helix Stax Platform'..."
PLATFORM_PROJECT_JSON=$(ztl create project --org-id "$ZITADEL_ORG_ID" --name "Helix Stax Platform" --output-format json)
PROJECT_ID=$(echo "$PLATFORM_PROJECT_JSON" | jq -r '.id')
echo "Project created with ID: $PROJECT_ID"

# --- OIDC Client Definitions ---
declare -A clients
clients=(
    ["grafana"]="https://grafana.helixstax.net/login/generic_oauth"
    ["argocd"]="https://argocd.helixstax.net/auth/callback"
    ["devtron"]="https://devtron.helixstax.net/orchestrator/api/v1/user/login"
    ["harbor"]="https://harbor.helixstax.net/c/oidc/callback"
    ["backstage"]="https://backstage.helixstax.net/api/auth/zitadel/handler/frame"
    ["outline"]="https://docs.helixstax.net/auth/oidc.callback"
    ["rocketchat"]="https://chat.helixstax.net/_oauth/zitadel"
    ["minio-console"]="https://minio.helixstax.net/oauth_callback"
    ["cloudflare-access"]="https://helixstax.cloudflareaccess.com/cdn-cgi/access/callback"
)

# --- Create Clients ---
for app_name in "${!clients[@]}"; do
    redirect_uri="${clients[$app_name]}"
    echo "Creating OIDC application for $app_name..."

    # Backstage uses PKCE, others use Basic secret
    auth_method="BASIC"
    app_type="WEB"
    if [ "$app_name" == "backstage" ]; then
        auth_method="PKCE"
    fi

    APP_JSON=$(ztl create application-oidc \
      --org-id "$ZITADEL_ORG_ID" \
      --project-id "$PROJECT_ID" \
      --name "$app_name" \
      --redirect-uris "$redirect_uri" \
      --response-types "CODE" \
      --grant-types "AUTHORIZATION_CODE" "REFRESH_TOKEN" \
      --app-type "$app_type" \
      --auth-method-type "$auth_method" \
      --version "V2" \
      --post-logout-redirect-uris "https://zitadel.helixstax.net/ui/login/login" \
      --output-format json)

    CLIENT_ID=$(echo "$APP_JSON" | jq -r '.clientId')
    CLIENT_SECRET=$(echo "$APP_JSON" | jq -r '.clientSecret')

    echo "--- $app_name Client Created ---"
    echo "Client ID: $CLIENT_ID"
    # Only show secret if one was generated (PKCE doesn't have one)
    if [ "$auth_method" == "BASIC" ]; then
        echo "Client Secret: $CLIENT_SECRET"
    fi
    echo "This secret should be stored in OpenBao immediately."
    echo "-------------------------------------"
    echo ""
done

echo "All clients created successfully in project ID $PROJECT_ID."
```

#### **5. Google Workspace Federation Configuration**

**Step 1: In Google Cloud Console (under APIs & Services -> Credentials)**
1.  Click **Create Credentials** -> **OAuth client ID**.
2.  Application type: **Web application**.
3.  Name: `Zitadel-Federation`.
4.  Authorized redirect URIs: Add `https://zitadel.helixstax.net/ui/login/login/externalidp/callback`
5.  Click **Create**.
6.  Copy the **Client ID** and **Client Secret**. Store them securely in OpenBao.

**Step 2: In Zitadel (via API/`curl` or UI)**
1.  Go to your Organization -> Identity Providers.
2.  Click "Add", choose `Google`.
3.  Name: `Google Workspace`
4.  Client ID: Paste the ID from Google.
5.  Client Secret: Paste the secret from Google.
6.  Scopes: ensure `openid`, `email`, `profile` are present.
7.  Check "Auto-Creation" to enable JIT provisioning.
8.  Check "Auto-Update" to keep user info in sync.

**`curl` command to create the Google IdP in Zitadel:**
```bash
# ZITADEL_PAT and GOOGLE_CLIENT_ID/SECRET are environment variables
curl -X POST "https://zitadel.helixstax.net/management/v1/idps" \
  -H "Authorization: Bearer $ZITADEL_PAT" \
  -H "Content-Type: application/json" \
  --data-raw '{
    "name": "Google Workspace",
    "stylingType": "IDP_STYLING_TYPE_GOOGLE",
    "ownerType": "IDP_OWNER_TYPE_ORG",
    "oidcConfig": {
      "clientId": "'"$GOOGLE_CLIENT_ID"'",
      "clientSecret": "'"$GOOGLE_CLIENT_SECRET"'",
      "issuer": "https://accounts.google.com",
      "scopes": ["openid", "profile", "email"],
      "displayNameMapping": "OIDC_MAPPING_FIELD_PREFERRED_USERNAME",
      "usernameMapping": "OIDC_MAPPING_FIELD_EMAIL"
    },
    "isAutoCreation": true,
    "isAutoUpdate": true,
    "isCreationAllowed": true,
    "isLinkingAllowed": true
  }'
```

***

# Google Workspace

## SKILL.md Content
Google Workspace is our business platform for email, documents, calendar, and the identity foundation for staff. It authenticates our team, who then access platform services via Zitadel federation. It also underpins the Google Cloud project used by our AI agents.

**Core Goal:** Manage users and groups programmatically, ensure email deliverability, and provide a secure foundation for Google Cloud services like Gemini.

**User Management Quick Commands (`gcloud` / Admin SDK)**

The Admin SDK is the primary way to automate Workspace. Agents will typically use a Google Client Library or `curl`.

```bash
# Authenticate gcloud with user credentials that have domain-wide delegation
# gcloud auth login
# gcloud config set project helix-stax-gcp-project

# Example: List users in the domain
# Using a Python script with the Admin SDK is more robust.
# A simplified curl example with a service account token:
ACCESS_TOKEN=$(gcloud auth print-access-token) # Or fetch via service account
curl "https://admin.googleapis.com/admin/directory/v1/users?domain=helixstax.com&maxResults=10" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Example: Create a new user (via API POST)
curl -X POST "https://admin.googleapis.com/admin/directory/v1/users" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{
    "primaryEmail": "new.user@helixstax.com",
    "name": {
      "givenName": "New",
      "familyName": "User"
    },
    "password": "REPLACE_WITH_SECURE_PASSWORD",
    "changePasswordAtNextLogin": true
  }'
```

**DNS Records for Email (in Cloudflare)**

| Type  | Name/Host                 | Value                                                                             | Priority | Notes                                 |
|-------|---------------------------|-----------------------------------------------------------------------------------|----------|---------------------------------------|
| `MX`  | `@` (or `helixstax.com`)  | `aspmx.l.google.com.`                                                             | `1`      | Primary Google mail server            |
| `MX`  | `@`                       | `alt1.aspmx.l.google.com.`                                                        | `5`      |                                       |
| `MX`  | `@`                       | `alt2.aspmx.l.google.com.`                                                        | `5`      |                                       |
| `MX`  | `@`                       | `alt3.aspmx.l.google.com.`                                                        | `10`     |                                       |
| `MX`  | `@`                       | `alt4.aspmx.l.google.com.`                                                        | `10`     |                                       |
| `TXT` | `@`                       | `v=spf1 include:_spf.google.com include:spf.postal.helixstax.com ~all`              | N/A      | Merged SPF for Google and Postal      |
| `TXT` | `google._domainkey`       | `v=DKIM1; k=rsa; p=...` (Value from Google Admin Console)                           | N/A      | Google Workspace DKIM key             |
| `TXT` | `_dmarc`                  | `v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@helixstax.com; sp=quarantine;`     | N/A      | Start with `p=none`, then `quarantine`|

**Gemini CLI Authentication for Agents**

1.  **Service Account Method (Preferred for Automation/K8s):**
    *   A service account key (`credentials.json`) is stored in OpenBao.
    *   ESO mounts this file into the agent's pod.
    *   Set the environment variable: `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json`
    *   The Gemini CLI and Google client libraries will automatically use this file.

2.  **User Credential Method (For local development):**
    *   Run `gcloud auth application-default login`.
    *   This stores credentials locally that the Gemini CLI can use. Not suitable for non-interactive agents.

**Troubleshooting Decision Tree**

1.  **Symptom:** Outbound emails from `@helixstax.com` are marked as spam or rejected.
    *   **Cause 1:** SPF record is missing, incorrect, or has too many DNS lookups (>10).
    *   **Fix 1:** Use a tool like MXToolbox to validate the SPF record for `helixstax.com`. Ensure `include:_spf.google.com` is present and the total lookups are under 10. Our merged record is designed to be compliant.
    *   **Cause 2:** DKIM signature is missing or invalid.
    *   **Fix 2:** In Google Admin Console, go to Apps > Google Workspace > Gmail > Authenticate email. Ensure DKIM is ON and the DNS record in Cloudflare matches.
    *   **Cause 3:** DMARC policy is failing.
    *   **Fix 3:** Check DMARC reports (sent to `dmarc-reports@helixstax.com`). Start with `p=none` to monitor, then move to `p=quarantine` and `p=reject` once SPF/DKIM are aligned.

2.  **Symptom:** Gemini CLI / API returns a `Permission Denied` error.
    *   **Cause 1:** The `generativelanguage.googleapis.com` API is not enabled in the Google Cloud project.
    *   **Fix 1:** Run `gcloud services enable generativelanguage.googleapis.com --project=helix-stax-gcp-project`.
    *   **Cause 2:** The service account or user does not have the "AI Platform User" or "Vertex AI User" role.
    *   **Fix 2:** In GCP IAM, grant the service account `roles/aiplatform.user`.
    *   **Cause 3:** Billing is not enabled on the project.
    *   **Fix 3:** Go to the Google Cloud Console and link a valid billing account to the project.

---
## reference.md Content
### **Google Workspace: Deep Reference**

This document provides a detailed reference for administering Google Workspace, focusing on API automation, security hardening, and integration points with the Helix Stax platform.

#### **1. Admin Console & APIs**

*   **Admin Console UI:** For one-off tasks, policy setting (DLP, Context-Aware Access), and viewing high-level reports.
*   **Admin SDK APIs:** The foundation for all automation. Accessed via Google Client Libraries, `gcloud`, or direct REST calls. Requires OAuth 2.0 authentication, typically with a service account using domain-wide delegation.
    *   **Directory API:** Manage users, groups, OUs, devices.
    *   **Reports API:** Access audit logs (admin, login, token) and usage reports.
    *   **Groups Settings API:** Manage group-level settings not available in the Directory API.
*   **Domain-Wide Delegation:** Allows a service account to impersonate users and act on their behalf. This is critical for automation that needs to access user-specific data (e.g., read a user's Gmail, create a Calendar event for them).
    *   **Setup:** In Google Admin Console, go to Security > API controls > Domain-wide Delegation. Add your service account's Client ID and the required OAuth scopes (e.g., `https://www.googleapis.com/auth/admin.directory.user`).

#### **2. DNS Records for `helixstax.com`**

*   **MX (Mail Exchange):** Directs incoming email to Google's servers. The priorities are important for failover.
*   **SPF (Sender Policy Framework):** A TXT record listing all IP addresses/servers authorized to send email on behalf of `helixstax.com`.
    *   **Lookup Limit:** An SPF record cannot result in more than 10 DNS lookups. `include:` statements count as one lookup each. Merging `_spf.google.com` (1 lookup) and Postal's SPF (e.g., `spf.postal.helixstax.com`, 1 lookup) is safe. Avoid long chains of includes.
*   **DKIM (DomainKeys Identified Mail):** Provides a cryptographic signature to verify that an email was sent by and authorized by the owner of that domain. The public key is stored in a TXT record. You will need separate DKIM records for Google Workspace and Postal, using different "selectors" (e.g., `google._domainkey` and `postal._domainkey`). They do not conflict.
*   **DMARC (Domain-based Message Authentication, Reporting, and Conformance):** A policy that tells receiving mail servers what to do if an email fails SPF or DKIM checks.
    *   `p=none`: Monitor only.
    *   `p=quarantine`: Send failures to spam.
    *   `p=reject`: Reject failures outright.
    *   `rua=mailto:...`: Address to send aggregate reports to.
    *   `ruf=mailto:...`: Address to send forensic (failure) reports to.

#### **3. Zitadel + Google Workspace Federation**

*   **Recommended: Google as External IdP (OAuth/OIDC in Zitadel)**
    *   **Flow:** User -> App -> Zitadel -> "Login with Google" -> Google Auth -> Redirect to Zitadel -> Zitadel mints OIDC token -> App consumes token.
    *   **Pros:** Centralized control in Zitadel; all apps speak one protocol (OIDC to Zitadel); easy to add more IdPs later (GitHub, etc.).
    *   **Google Config:** Requires an OAuth Client ID from Google Cloud Console. No configuration in the Google Workspace Admin Console itself is needed for this flow.
*   **Alternative: Zitadel as SP (SAML in Google Workspace)**
    *   **Flow:** User -> App -> Zitadel -> Redirect to Google -> Google Auth -> SAML Assertion posted back to Zitadel -> Zitadel logs user in -> Redirect to App.
    *   **Pros:** Control over app access is centralized in the Google Admin Console. Common in enterprises where Google is the SSO "dashboard".
    *   **Google Config:** Requires setting up a "Custom SAML App" in the Admin Console, providing Zitadel's ACS URL and Entity ID. Requires attribute mapping.

#### **4. Gemini CLI & Google Cloud Setup**

*   **Project Setup:** A single Google Cloud Project (`helix-stax-gcp-project`) should house all APIs and resources for the company's internal tools.
*   **APIs to Enable:**
    *   `generativelanguage.googleapis.com` (for Gemini API)
    *   `iam.googleapis.com`
    *   `admin.googleapis.com` (Admin SDK)
    *   `drive.googleapis.com`
    *   `gmail.googleapis.com`
    *   `calendar-json.googleapis.com`
    *   `workspacesevents.googleapis.com`
    *   `cloudbilling.googleapis.com`
*   **Workload Identity Federation for K3s:**
    *   **Concept:** Allows Kubernetes service accounts to impersonate Google Cloud service accounts without using a JSON key file.
    *   **How it works:** You create a trust relationship between your K3s cluster's OIDC issuer and Google Cloud. A pod, with its K8s service account token, can then request a short-lived Google Cloud access token.
    *   **Benefit:** Far more secure than storing and mounting long-lived JSON keys. This is the production-grade best practice.

#### **5. Drive Organization & Security**

*   **Shared Drives are mandatory for business data.** Data in "My Drive" is owned by an individual user; if that user is deleted, their data is at risk. Data in a Shared Drive is owned by the organization.
*   **Recommended Structure:**
    *   `Company Operations` (Members: `team@helixstax.com`)
    *   `Client-Work` (Members: `team@helixstax.com`)
        *   `Client A` (Sharing restricted to specific team members + client contacts)
        *   `Client B` (Sharing restricted...)
    *   `Templates & SOPs` (Members: `team@helixstax.com`, read-only for some)
    *   `Marketing & Sales` (Members: `team@helixstax.com`)
*   **Service Account Access:** For a service account (like one used by n8n) to access files in a Shared Drive, you must add the service account's email address as a member of that Shared Drive.

#### **6. Security Hardening Checklist**
1.  **Enforce 2FA for all users.** Prioritize Security Keys (FIDO2/WebAuthn).
2.  **Disable "Less Secure App Access".**
3.  **Review and Whitelist Third-Party OAuth Apps.** Regularly audit which apps have access to company data.
4.  **Configure Context-Aware Access.** E.g., block access to Admin Console from non-corporate IP ranges.
5.  **Set up DLP rules** to scan for and prevent accidental sharing of PII/sensitive data in Drive and Gmail.
6.  **Configure Admin Alerts** for critical events (suspicious login, password change, DLP rule match) and route them to `alerts@helixstax.com` (which can be processed by n8n).
7.  **Implement strong password policies** in the Admin Console.
8.  **Use Google Vault** to set data retention policies for legal and compliance reasons.

---
## examples.md Content
### **Google Workspace: Ready-to-Use Examples for Helix Stax**

#### **1. Complete DNS Records for Cloudflare**

Add these records in the Cloudflare DNS dashboard for `helixstax.com`.

```
# Type  Name                 Content                                                         Proxy
# ----------------------------------------------------------------------------------------------------

# --- Google Workspace Mail ---
MX      helixstax.com        aspmx.l.google.com.                                             DNS only (Priority 1)
MX      helixstax.com        alt1.aspmx.l.google.com.                                        DNS only (Priority 5)
MX      helixstax.com        alt2.aspmx.l.google.com.                                        DNS only (Priority 5)
MX      helixstax.com        alt3.aspmx.l.google.com.                                        DNS only (Priority 10)
MX      helixstax.com        alt4.aspmx.l.google.com.                                        DNS only (Priority 10)

# --- Email Authentication ---
# Merged SPF for Google Workspace and Postal (assuming Postal sends from the root)
TXT     helixstax.com        v=spf1 include:_spf.google.com include:spf.postal.helixstax.com ~all

# Google Workspace DKIM - get the 'p=' value from your Admin Console
TXT     google._domainkey    v=DKIM1; k=rsa; p=MIIBIjANBg...[YOUR_KEY_HERE]...DAQAB

# DMARC Policy - starts in monitoring mode, then ramp up to quarantine
TXT     _dmarc               v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@helixstax.com; sp=quarantine; fo=1

# --- Google Domain Verification ---
# Get this value from your Google Admin Console during setup
TXT     helixstax.com        google-site-verification=...[YOUR_CODE_HERE]...
```

#### **2. `gcloud` Script to Set Up GCP Project for Agents**

Run this script after logging in with `gcloud auth login`.

```bash
#!/bin/bash
set -e

PROJECT_ID="helix-stax-gcp-project-$(date +%s)"
BILLING_ACCOUNT="YOUR_BILLING_ACCOUNT_ID" # e.g., 012345-67890A-BCDEFG
SERVICE_ACCOUNT_NAME="helix-stax-agent"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="./helix-stax-agent-credentials.json"

echo "Creating GCP Project: $PROJECT_ID"
gcloud projects create "$PROJECT_ID"

echo "Linking billing account..."
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"

echo "Enabling required APIs..."
gcloud services enable \
    generativelanguage.googleapis.com \
    iam.googleapis.com \
    admin.googleapis.com \
    drive.googleapis.com \
    gmail.googleapis.com \
    calendar-json.googleapis.com \
    workspacesevents.googleapis.com \
    --project="$PROJECT_ID"

echo "Creating service account: $SERVICE_ACCOUNT_NAME"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="Helix Stax AI Agent" \
    --project="$PROJECT_ID"

echo "Granting IAM roles to service account..."
# Role for Gemini API access
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/aiplatform.user"

# Role for other general tasks
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/aiplatform.user"

echo "Creating and downloading service account key..."
gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID"

echo "--- SUCCESS ---"
echo "Project ID: $PROJECT_ID"
echo "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
echo "Key file created at: $KEY_FILE"
echo "IMPORTANT: Securely store this key file in OpenBao now and delete the local copy."
echo "NEXT STEP: Enable Domain-Wide Delegation for this service account in the Google Workspace Admin Console."
```

#### **3. Step-by-Step: Enabling Domain-Wide Delegation**

1.  After running the script above, get the service account's "Unique ID" (which is its Client ID). Run:
    `gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID --format='value(oauth2ClientId)'`
2.  Go to `admin.google.com`.
3.  Navigate to **Security > Access and data control > API controls**.
4.  Under **Domain-wide Delegation**, click **MANAGE DOMAIN-WIDE DELEGATION**.
5.  Click **Add new**.
6.  Paste the **Client ID** from step 1.
7.  In the **OAuth scopes** field, add the required permissions, comma-separated. For wide-ranging automation:
    ```
    https://www.googleapis.com/auth/admin.directory.user,https://www.googleapis.com/auth/admin.directory.group,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/calendar
    ```
8.  Click **Authorize**. The service account can now use its credentials to act on behalf of users in your domain.

#### **4. n8n Workflow Outline: New User Onboarding**

This workflow automates the full onboarding process, triggered manually in n8n.

*   **Trigger:** `Manual Trigger`
    *   `Inputs`: `firstName`, `lastName`, `email`

*   **Node 1: `Google Admin - Create User`**
    *   **Authentication:** OAuth2 using the service account with domain-wide delegation.
    *   **Email:** `{{ $json.email }}`
    *   **First Name:** `{{ $json.firstName }}`
    *   **Last Name:** `{{ $json.lastName }}`
    *   **Password:** (Generate a random, secure password)
    *   **Change Password at Next Login:** `true`

*   **Node 2: `Google Admin - Add User to Group`**
    *   **User Key:** `{{ $json.email }}`
    *   **Group Key:** `team@helixstax.com`

*   **Node 3: `HTTP Request - Create Zitadel User`**
    *   **Method:** `POST`
    *   **URL:** `https://zitadel.helixstax.net/management/v1/users/human`
    *   **Authentication:** `Header Auth` (Bearer Token from Zitadel machine user)
    *   **Body (JSON):**
        ```json
        {
          "userName": "{{ $json.email.split('@')[0] }}",
          "profile": {
            "firstName": "{{ $json.firstName }}",
            "lastName": "{{ $json.lastName }}"
          },
          "email": {
            "email": "{{ $json.email }}",
            "isEmailVerified": true
          }
        }
        ```

*   **Node 4: `Rocket.Chat - Send Message`**
    *   **Channel:** `#general`
    *   **Message:** `Welcome to the team, {{ $json.firstName }}! Your Google Workspace account has been created. Your first login to any platform service (like Grafana or ArgoCD) will be via the 'Login with Google' button.`
