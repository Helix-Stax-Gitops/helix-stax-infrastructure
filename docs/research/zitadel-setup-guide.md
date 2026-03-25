# Zitadel Setup Guide — Helix Stax

**Version**: Zitadel v2.x / Chart zitadel/zitadel
**Cluster**: K3s on AlmaLinux 9.7
**Database**: CloudNativePG (helix-pg-rw.database.svc.cluster.local)
**Domain**: zitadel.helixstax.net
**Namespace**: identity

---

## 1. Pre-Deploy Checklist

### 1.1 PostgreSQL Database and Users

Zitadel requires two Postgres users: an **admin** user (for schema migrations) and an **app** user (for runtime). Both must be created before the Helm install runs.

Connect to the CNPG cluster:

```bash
kubectl exec -it -n database helix-pg-1 -- psql -U postgres
```

Run in psql:

```sql
-- Create the app user
CREATE USER zitadel_user WITH PASSWORD 'CHANGEME_APP_PASSWORD';

-- Create the admin user (used only during init/migrations)
CREATE USER zitadel_admin WITH PASSWORD 'CHANGEME_ADMIN_PASSWORD' CREATEROLE;

-- Create the database
CREATE DATABASE zitadel OWNER zitadel_admin;

-- Grant app user access
GRANT CONNECT ON DATABASE zitadel TO zitadel_user;
GRANT ALL PRIVILEGES ON DATABASE zitadel TO zitadel_admin;

-- Required for Zitadel's init job to create schema
ALTER USER zitadel_admin CREATEDB;
```

> Note: The init job connects to the `postgres` maintenance database first to verify connectivity, then creates schemas in the `zitadel` database. The admin user needs CREATEDB and CREATEROLE permissions.

### 1.2 Generate and Store the Master Key

The master key encrypts signing keys and sensitive data at rest. It **cannot be changed** after first init without losing all encrypted data.

```bash
# Generate a 32-character key
MASTERKEY=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)

kubectl create secret generic zitadel-masterkey \
  -n identity \
  --from-literal=masterkey="${MASTERKEY}"

# Save the key somewhere safe (OpenBao or a local encrypted file)
echo "MASTERKEY: ${MASTERKEY}"
```

### 1.3 Create Database Credentials Secret

```bash
kubectl create secret generic zitadel-db-secret \
  -n identity \
  --from-literal=user-password="CHANGEME_APP_PASSWORD" \
  --from-literal=admin-password="CHANGEME_ADMIN_PASSWORD"
```

These map to the `secretVars` already defined in `helm/zitadel/values.yaml`.

### 1.4 Create the Traefik IngressRoute

Zitadel uses HTTP/2 (gRPC) internally. The IngressRoute must pass through the connection correctly. TLS is terminated at Cloudflare/Traefik, not at Zitadel (already set in values: `TLS.Enabled: false`).

```yaml
# helm/zitadel/ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: zitadel
  namespace: identity
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`zitadel.helixstax.net`)
      kind: Rule
      services:
        - name: zitadel
          port: 8080
          scheme: h2c   # Required: Zitadel speaks HTTP/2 cleartext internally
  tls:
    secretName: cloudflare-origin-tls  # Cloudflare Origin CA cert
```

Apply it:

```bash
kubectl apply -f helm/zitadel/ingressroute.yaml
```

### 1.5 Cloudflare DNS

Add an A record pointing `zitadel.helixstax.net` to the cluster's ingress IP (Traefik LoadBalancer IP). Set proxy status to DNS-only (gray cloud) initially for testing; enable proxying once verified.

```bash
# Get Traefik external IP
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 1.6 Helm Install

```bash
helm repo add zitadel https://charts.zitadel.com
helm repo update

helm install zitadel zitadel/zitadel \
  -n identity \
  --create-namespace \
  -f helm/zitadel/values.yaml \
  --wait --timeout 10m
```

Watch the init jobs complete before proceeding:

```bash
kubectl get pods -n identity --watch
# Expect: zitadel-init-* Completed, zitadel-setup-* Completed, then zitadel-* Running
```

---

## 2. Post-Deploy Configuration

### 2.1 First Admin Login

The Helm init job creates the first admin user using credentials configured in `values.yaml` under `zitadel.configmapConfig.FirstInstance`. If not set, a temporary password is printed in the `zitadel-setup` job logs:

```bash
kubectl logs -n identity job/zitadel-setup | grep -i password
```

Navigate to `https://zitadel.helixstax.net/ui/console` and log in.

On first login, you will be prompted to change the password. Set a strong password and store it in OpenBao.

### 2.2 Organization Creation

Zitadel uses organizations to namespace users and applications. Create the primary org for Helix Stax internal users.

In Console: **Organization > New Organization**

| Field | Value |
|-------|-------|
| Name | Helix Stax |
| Domain | helixstax.com |

Verify the domain: go to **Organization > Domains**, add `helixstax.com`, follow the DNS TXT verification steps.

### 2.3 Project Creation

Projects group OIDC/SAML applications and their role assignments.

In Console: **Projects > New Project**

| Field | Value |
|-------|-------|
| Name | helix-platform |
| Check token type | JWT (recommended for K8s services) |

All OIDC clients below will be created inside this project.

---

## 3. OIDC Clients

For each client: navigate to **Projects > helix-platform > Applications > New Application**.

Use **Web** type with **Code + PKCE** flow for all browser-based services. Use **API** type for machine-to-machine calls.

Zitadel OIDC endpoints (substitute your domain):

| Endpoint | URL |
|----------|-----|
| Authorization | `https://zitadel.helixstax.net/oauth/v2/authorize` |
| Token | `https://zitadel.helixstax.net/oauth/v2/token` |
| Userinfo | `https://zitadel.helixstax.net/oidc/v1/userinfo` |
| JWKS | `https://zitadel.helixstax.net/oauth/v2/keys` |
| Discovery | `https://zitadel.helixstax.net/.well-known/openid-configuration` |

---

### 3.1 Grafana

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | grafana |
| Redirect URIs | `https://grafana.helixstax.net/login/generic_oauth` |
| Post-logout redirect | `https://grafana.helixstax.net` |
| Scopes | `openid email profile offline_access roles` |

Grafana Helm values (`kube-prometheus-stack` or standalone):

```yaml
grafana.ini:
  auth.generic_oauth:
    enabled: true
    allow_sign_up: true
    name: Zitadel
    client_id: "<GRAFANA_CLIENT_ID>"
    client_secret: "<GRAFANA_CLIENT_SECRET>"
    scopes: "openid email profile offline_access roles"
    auth_url: "https://zitadel.helixstax.net/oauth/v2/authorize"
    token_url: "https://zitadel.helixstax.net/oauth/v2/token"
    api_url: "https://zitadel.helixstax.net/oidc/v1/userinfo"
    use_pkce: true
    use_refresh_token: true
    login_attribute_path: preferred_username
    email_attribute_path: email
    role_attribute_path: >
      contains(groups[*], 'grafana-admin') && 'GrafanaAdmin' ||
      contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'
```

> The role mapping relies on a Zitadel Action that adds a `groups` claim to the token. See Section 5 for the role/group setup.

---

### 3.2 Devtron

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | devtron |
| Redirect URIs | `https://devtron.helixstax.net/orchestrator/api/dex/callback` |
| Post-logout redirect | `https://devtron.helixstax.net` |
| Scopes | `openid email profile groups` |

Devtron uses Dex as its auth proxy. Configure Dex in the Devtron Helm values:

```yaml
# In devtron values.yaml under configs.dex
connectors:
  - type: oidc
    id: zitadel
    name: Zitadel
    config:
      issuer: https://zitadel.helixstax.net
      clientID: <DEVTRON_CLIENT_ID>
      clientSecret: <DEVTRON_CLIENT_SECRET>
      redirectURI: https://devtron.helixstax.net/orchestrator/api/dex/callback
      scopes:
        - openid
        - email
        - profile
        - groups
      getUserInfo: true
```

---

### 3.3 Rocket.Chat

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | rocketchat |
| Redirect URIs | `https://chat.helixstax.net/_oauth/oidc` |
| Post-logout redirect | `https://chat.helixstax.net` |
| Scopes | `openid email profile` |

In Rocket.Chat Admin: **Administration > OAuth > Add Custom OAuth**

| Field | Value |
|-------|-------|
| URL | `https://zitadel.helixstax.net` |
| Token path | `/oauth/v2/token` |
| Token sent via | Header |
| Identity path | `/oidc/v1/userinfo` |
| Authorize path | `/oauth/v2/authorize` |
| Scope | `openid email profile` |
| ID | `<ROCKETCHAT_CLIENT_ID>` |
| Secret | `<ROCKETCHAT_CLIENT_SECRET>` |
| Login style | Redirect |
| Username field | `preferred_username` |
| Email field | `email` |
| Name field | `name` |

---

### 3.4 Harbor

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | harbor |
| Redirect URIs | `https://registry.helixstax.net/c/oidc/callback` |
| Post-logout redirect | `https://registry.helixstax.net` |
| Scopes | `openid email profile` |

In Harbor Admin: **Administration > Configuration > Authentication**

| Field | Value |
|-------|-------|
| Auth mode | OIDC |
| OIDC Provider Name | Zitadel |
| OIDC Endpoint | `https://zitadel.helixstax.net` |
| OIDC Client ID | `<HARBOR_CLIENT_ID>` |
| OIDC Client Secret | `<HARBOR_CLIENT_SECRET>` |
| Group claim name | `groups` |
| OIDC Scope | `openid,email,profile` |
| Verify Certificate | true |
| Automatic onboarding | true |
| Username claim | `preferred_username` |

---

### 3.5 Open WebUI

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | open-webui |
| Redirect URIs | `https://ai.helixstax.net/oauth/oidc/callback` |
| Post-logout redirect | `https://ai.helixstax.net` |
| Scopes | `openid email profile` |

Open WebUI environment variables:

```env
ENABLE_OAUTH_SIGNUP=true
OAUTH_PROVIDER_NAME=Zitadel
OPENID_PROVIDER_URL=https://zitadel.helixstax.net/.well-known/openid-configuration
OAUTH_CLIENT_ID=<OPENWEBUI_CLIENT_ID>
OAUTH_CLIENT_SECRET=<OPENWEBUI_CLIENT_SECRET>
OAUTH_SCOPES=openid email profile
```

---

### 3.6 n8n

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | n8n |
| Redirect URIs | `https://n8n.helixstax.net/rest/sso/oidc/callback` |
| Post-logout redirect | `https://n8n.helixstax.net` |
| Scopes | `openid email profile` |

n8n environment variables (requires n8n Enterprise or n8n v1.x with OIDC feature flag):

```env
N8N_SSO_OIDC_ENABLED=true
N8N_SSO_OIDC_CLIENT_ID=<N8N_CLIENT_ID>
N8N_SSO_OIDC_CLIENT_SECRET=<N8N_CLIENT_SECRET>
N8N_SSO_OIDC_ISSUER_URL=https://zitadel.helixstax.net
N8N_SSO_OIDC_REDIRECT_URL=https://n8n.helixstax.net/rest/sso/oidc/callback
```

In n8n UI: **Settings > SSO** — paste the issuer URL and credentials.

---

### 3.7 MinIO

**Client type**: Web (Code + PKCE)

| Setting | Value |
|---------|-------|
| Name | minio |
| Redirect URIs | `https://minio.helixstax.net/oauth_callback` |
| Post-logout redirect | `https://minio.helixstax.net` |
| Scopes | `openid email profile` |

MinIO environment variables:

```env
MINIO_IDENTITY_OPENID_CONFIG_URL=https://zitadel.helixstax.net/.well-known/openid-configuration
MINIO_IDENTITY_OPENID_CLIENT_ID=<MINIO_CLIENT_ID>
MINIO_IDENTITY_OPENID_CLIENT_SECRET=<MINIO_CLIENT_SECRET>
MINIO_IDENTITY_OPENID_CLAIM_NAME=policy
MINIO_IDENTITY_OPENID_REDIRECT_URI=https://minio.helixstax.net/oauth_callback
MINIO_IDENTITY_OPENID_SCOPES=openid,email,profile
```

MinIO maps the `policy` claim to bucket policies. Add a Zitadel Action to inject `policy: readwrite` or `policy: consoleAdmin` into the token for the appropriate users/groups.

---

## 4. Google Workspace SAML Federation

This configures Zitadel as the SAML IdP so staff log in to Google Workspace using Zitadel credentials, **or** configures Google as an upstream IdP so staff authenticate to Zitadel using their `@helixstax.com` Google accounts.

For Helix Stax the recommended approach is **Google as upstream IdP in Zitadel** — staff use their Google accounts to authenticate into Zitadel, which then issues tokens to all platform services. This is simpler and avoids managing Zitadel user passwords for staff.

### 4.1 Option A — Google as Identity Provider in Zitadel (Recommended)

In the Google Cloud Console (console.cloud.google.com):

1. Create an OAuth 2.0 Client ID under **APIs & Services > Credentials**
2. Application type: **Web application**
3. Authorized redirect URI: `https://zitadel.helixstax.net/idps/google/callback`
4. Note the Client ID and Client Secret

In Zitadel Console: **Organization > Identity Providers > Google**

| Field | Value |
|-------|-------|
| Name | Google Workspace |
| Client ID | `<GOOGLE_OAUTH_CLIENT_ID>` |
| Client Secret | `<GOOGLE_OAUTH_CLIENT_SECRET>` |
| Scopes | `openid email profile` |
| Hosted domain | `helixstax.com` (restricts login to @helixstax.com only) |

After saving, go to **Organization > Login Policy** and enable the Google IdP. Users will see a "Continue with Google" button on the Zitadel login page.

**Auto-creation**: Enable "Auto Register" in the IdP settings so users are created in Zitadel on first Google login. Assign them to the appropriate Zitadel role/group automatically via an Action.

### 4.2 Option B — Zitadel as SAML IdP for Google Workspace

Use this if you want Google services (Gmail, Drive, Calendar) to require Zitadel authentication before access.

**Step 1 — Download Zitadel's SAML certificate**

```bash
curl -o zitadel-idp.crt https://zitadel.helixstax.net/saml/v2/certificate
```

**Step 2 — Add SAML profile in Google Admin**

Navigate to **Google Admin > Security > Authentication > SSO with third-party IdP > Add SAML profile**.

| Google Field | Value |
|-------------|-------|
| SSO profile name | Zitadel SSO |
| IDP entity ID | `https://zitadel.helixstax.net/saml/v2/metadata` |
| Sign-in page URL | `https://zitadel.helixstax.net/saml/v2/SSO` |
| Sign-out page URL | `https://zitadel.helixstax.net/saml/v2/SLO` |
| Verification certificate | Upload `zitadel-idp.crt` |

**Step 3 — Get Google SP details**

After saving the profile, open it and copy the **Entity ID** and **ACS URL** from the "SP details" section.

**Step 4 — Create SAML app in Zitadel**

In Zitadel Console: **Projects > helix-platform > Applications > New Application > SAML**

Upload or provide the Google SP metadata URL, or paste an XML:

```xml
<?xml version="1.0"?>
<md:EntityDescriptor
  xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
  entityID="https://accounts.google.com/samlrp/metadata?rpid=<YOUR_RPID>">
  <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <md:AssertionConsumerService
      Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
      Location="https://accounts.google.com/samlrp/acs?rpid=<YOUR_RPID>"
      index="0"/>
  </md:SPSSODescriptor>
</md:EntityDescriptor>
```

**Step 5 — Assign and test**

In Google Admin, assign the SSO profile to your organizational unit. Test in an incognito window with a non-admin account (`admin@helixstax.com` is excluded from SSO by Google by design).

---

## 5. RBAC Design

### 5.1 Role Definitions

Create these roles inside **Projects > helix-platform > Roles**:

| Role Key | Display Name | Description |
|----------|-------------|-------------|
| `platform-admin` | Platform Admin | Full access to all platform services |
| `platform-engineer` | Engineer | Read/write to dev services; no production destructive ops |
| `client-viewer` | Client Viewer | Read-only access to client-facing dashboards |

### 5.2 Groups for Service Mapping

Create user groups in **Organization > Groups** and assign roles:

| Group | Zitadel Role | Grafana | Devtron | Harbor | MinIO |
|-------|-------------|---------|---------|--------|-------|
| `platform-admins` | `platform-admin` | GrafanaAdmin | Admin | Admin | consoleAdmin |
| `engineers` | `platform-engineer` | Editor | DevOps | Developer | readwrite |
| `client-viewers` | `client-viewer` | Viewer | — | — | readonly |

### 5.3 Adding Groups Claim to Tokens

By default, Zitadel does not include group membership in OIDC tokens. Add a Zitadel Action to inject the `groups` claim.

In Console: **Actions > New Action**

```javascript
// Action: add_groups_claim
// Trigger: Pre UserInfo, Pre AccessToken

function addGroupsClaim(ctx, api) {
  if (ctx.v1.user.grants == undefined || ctx.v1.user.grants.count == 0) {
    return;
  }

  let groups = [];
  ctx.v1.user.grants.grants.forEach(grant => {
    grant.roles.forEach(role => {
      groups.push(role);
    });
  });

  api.v1.claims.setClaim('groups', groups);
}
```

After creating the action, go to **Actions > Flows > Complement Token** and add the action to both "Pre Userinfo Creation" and "Pre Access Token Creation" triggers.

### 5.4 Multi-Tenant Client Isolation

For client work (consulting engagements):

1. Create a separate **Zitadel Organization** per client (e.g., `acme-corp`)
2. Create a `client-viewer` user in that organization
3. Grant that user the `client-viewer` role on the `helix-platform` project
4. Client users only see Grafana dashboards tagged for their organization

This isolates client credentials from internal users. Clients never have access to Devtron, Harbor, or MinIO.

---

## 6. Security Hardening

### 6.1 MFA Enforcement

In Console: **Organization > Login Policy**

| Setting | Value |
|---------|-------|
| Multi-factor | Required (not optional) |
| Second factors | TOTP, U2F/Passkey |
| Passwordless | Allow (Passkey recommended for engineers) |
| Force MFA | Enable for all users |

For client-viewer accounts, MFA can be set to "Allowed" rather than "Required" to reduce friction, but must be documented in your compliance controls.

### 6.2 Session Timeouts

In Console: **Instance Settings > Login Policy** (affects all organizations):

| Setting | Recommended Value |
|---------|------------------|
| Multi-factor init lifetime | 12h |
| Second factor check lifetime | 12h |
| External user verify lifetime | 5m |
| Password check lifetime | 240h (10 days) |
| Token validity | 12h (access), 24h (refresh) |

For Grafana specifically, set `token_url` with `use_refresh_token: true` so sessions are maintained without forcing re-auth every 12 hours.

### 6.3 Brute Force Protection

Zitadel has lockout policies built-in. In Console: **Organization > Password Complexity + Lockout Policy**:

| Setting | Value |
|---------|-------|
| Max password attempts | 5 |
| Lockout enabled | true |
| Show lockout failure | false (don't confirm username exists) |

### 6.4 Token Lifetimes

In Console: **Instance Settings > Token Lifetimes** (or per-application in app settings):

| Token Type | Recommended Lifetime |
|-----------|---------------------|
| Access token | 12 hours |
| Refresh token | 7 days |
| ID token | 12 hours |
| Authorization code | 5 minutes |

For machine-to-machine (API clients), use shorter-lived access tokens (1h) with client credentials flow — no refresh token needed.

### 6.5 Additional Hardening

- **Restrict origins**: Set allowed origins per application to prevent token leakage via redirect
- **CORS**: Configured per application in Zitadel; only allow your service domains
- **Audit logs**: Zitadel writes audit events to its PostgreSQL database; query `eventstore.events` table or export to Loki via n8n
- **Admin accounts**: Create a dedicated service account for automation (n8n, Terraform) — do not use the first admin account for automated tasks
- **Rotate secrets**: Zitadel client secrets can be rotated without downtime; add new key, update K8s secret, then remove old key

---

## 7. Quick Reference — Credential Secrets Checklist

Before going live, verify all these K8s secrets exist in the `identity` namespace and all other namespaces as appropriate:

| Secret Name | Namespace | Keys |
|-------------|-----------|------|
| `zitadel-masterkey` | identity | `masterkey` |
| `zitadel-db-secret` | identity | `user-password`, `admin-password` |
| `grafana-zitadel-oauth` | monitoring | `client-id`, `client-secret` |
| `devtron-zitadel-oauth` | devtroncd | `client-id`, `client-secret` |
| `rocketchat-zitadel-oauth` | rocketchat | `client-id`, `client-secret` |
| `harbor-zitadel-oauth` | harbor | `client-id`, `client-secret` |
| `openwebui-zitadel-oauth` | ai | `client-id`, `client-secret` |
| `n8n-zitadel-oauth` | n8n | `client-id`, `client-secret` |
| `minio-zitadel-oauth` | storage | `client-id`, `client-secret` |

Store all secrets in OpenBao and sync to K8s via External Secrets Operator.

---

## Sources

- [Deploy ZITADEL on Kubernetes](https://zitadel.com/docs/self-hosting/deploy/kubernetes)
- [Zitadel Helm Charts Repository](https://github.com/zitadel/zitadel-charts)
- [Google Workspace SSO with ZITADEL](https://zitadel.com/docs/guides/integrate/services/google-workspace)
- [Configure Google as Identity Provider in ZITADEL](https://zitadel.com/docs/guides/integrate/identity-providers/google)
- [Integrating Zitadel as OIDC Provider in Grafana](https://schoenwald.aero/posts/2025-02-12_integrating_zitadel_as_an_oidc_provider_in_grafana/)
- [Grafana + Zitadel Community Forum Config](https://community.grafana.com/t/zitadel-grafana-generic-oauth-configuration/102667)
- [n8n OIDC Setup](https://docs.n8n.io/user-management/oidc/setup/)
- [Harbor OIDC Issue Reference](https://github.com/goharbor/harbor/issues/22029)
- [OIDC Authorization Code Flow + PKCE](https://zitadel.com/docs/guides/integrate/login/oidc/login-users)
