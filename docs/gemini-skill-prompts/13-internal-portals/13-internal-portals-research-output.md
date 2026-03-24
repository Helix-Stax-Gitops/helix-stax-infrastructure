Of course. This is an excellent use case for Gemini's deep research capabilities. Here is the comprehensive reference documentation for Backstage and Outline, tailored to the Helix Stax infrastructure and formatted for division into `SKILL.md`, `reference.md`, and `examples.md` files.

---

# Backstage

## ## SKILL.md Content

### Overview

Backstage is our internal developer portal and service catalog. It provides a single pane of glass for all Helix Stax services, APIs, documentation, and infrastructure, replacing ad-hoc wikis. We use it to scaffold new services, track ownership, and surface real-time status from Kubernetes, ArgoCD, and Grafana.

### CLI Reference (`backstage-cli`)

#### **Core Commands**

*   **Scaffold a new app:** `npx @backstage/create-app@latest`
*   **Create a new plugin:** `yarn backstage-cli new --select plugin`
*   **Run development server:** `yarn dev` (Starts frontend on `3000`, backend on `7007`)
*   **Build app for production:** `yarn build`
*   **Build backend only:** `yarn build:backend`
*   **Build a specific package:** `yarn backstage-cli package build`
*   **Lint code:** `yarn backstage-cli package lint`
*   **Run tests:** `yarn backstage-cli package test`
*   **Bump Backstage versions:** `yarn backstage-cli versions:bump`

#### **Plugin Management**

*   **Add Plugin:**
    1.  `yarn add @backstage/plugin-<name> -W` (Adds to root)
    2.  `cd packages/app && yarn add @backstage/plugin-<name>` (Adds to frontend)
    3.  Import and add the plugin to `packages/app/src/App.tsx`.
*   **Add Backend Plugin:**
    1.  `cd packages/backend && yarn add @backstage/plugin-<name>-backend`
    2.  Import and register the plugin in `packages/backend/src/index.ts`.

### Deployment on K3s

#### **Dockerfile for Custom Image**

Use a multi-stage Dockerfile to build a production image with all plugins included.

```dockerfile
# Stage 1: Build frontend and backend
FROM node:18-bookworm-slim AS build
WORKDIR /app
COPY yarn.lock package.json ./
RUN yarn install --frozen-lockfile
COPY . .
RUN yarn build

# Stage 2: Build backend only for a smaller image
FROM node:18-bookworm-slim AS backend-build
WORKDIR /app
COPY yarn.lock package.json ./
RUN yarn install --frozen-lockfile --production --ignore-scripts
COPY --from=build /app/packages/backend/dist ./packages/backend/dist
COPY --from=build /app/app-config.yaml ./
COPY --from=build /app/app-config.production.yaml ./

# Stage 3: Production image
FROM node:18-bookworm-slim
WORKDIR /app
COPY --from=backend-build /app .
ENV NODE_ENV=production
CMD ["node", "packages/backend", "--config", "app-config.production.yaml"]
```

#### **Environment Variable Injection**

Inject secrets and dynamic configs via environment variables in your Kubernetes Deployment. Backstage reads them using the `${VAR_NAME}` syntax in `app-config.yaml`.

**Example `app-config.production.yaml` snippet:**

```yaml
auth:
  providers:
    oidc:
      clientId: backstage
      clientSecret: '${AUTH_OIDC_CLIENT_SECRET}' # Injected from K8s Secret
```

**Kubernetes Deployment `envFrom`:**

```yaml
# In Deployment spec.template.spec.containers[]
envFrom:
- secretRef:
    name: backstage-oidc-secrets
```

### Catalog: `catalog-info.yaml`

A YAML file in a component's repository that describes it to Backstage.

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: billing-service
  description: Handles billing and invoicing.
  annotations:
    # --- Link to source code ---
    github.com/project-slug: 'HelixStax/billing-service'
    # --- Link to documentation ---
    backstage.io/techdocs-ref: dir:.
    # --- Link to Kubernetes resources ---
    backstage.io/kubernetes-label-selector: 'app.kubernetes.io/name=billing-service'
    # --- Link to ArgoCD Application ---
    argocd/app-name: 'billing-service'
    # --- Link to Grafana dashboards ---
    grafana.com/dashboard-selector: '"tags": ["billing-service"]'
spec:
  type: service
  lifecycle: production
  owner: group:default/sre-team
  system: core-platform
  providesApis:
    - billing-api
  dependsOn:
    - resource:default/helixstax-prod-db
```

### OIDC with Zitadel

Configure the OIDC provider in `app-config.production.yaml`.

```yaml
auth:
  environment: production
  providers:
    oidc:
      provider: oidc
      title: 'Zitadel SSO'
      clientId: backstage
      clientSecret: '${AUTH_OIDC_CLIENT_SECRET}'
      metadataUrl: https://auth.helixstax.net/.well-known/openid-configuration
      scope: 'openid profile email offline_access urn:zitadel:iam:org:project:roles'
      # Token refresh is enabled by default
      signIn:
        resolver: &signInResolver
          catalyst.zitadel.signInResolver
      resolvers:
        - name: catalyst.zitadel
          resolver:
            signIn:
              resolver:
                # Maps Zitadel claims to Backstage user profile
                id:
                  - claims.sub
                email:
                  - claims.email
                picture:
                  - claims.picture
                displayName:
                  - claims.name
                # Maps Zitadel roles to Backstage group membership
                ownership:
                  - claims['urn:zitadel:iam:org:project:roles'].map(
                    (role) => `group:default/${role}`,
                  )
```

### Troubleshooting Quick-Fire

*   **Plugin fails to load:** Check for version mismatches with `yarn backstage-cli versions:check`. Ensure the plugin is registered in both `packages/app/src/App.tsx` (frontend) and `packages/backend/src/index.ts` (backend), if applicable.
*   **OIDC Login Loop:** Verify the "Redirect URIs" in your Zitadel application match `https://backstage.helixstax.net/auth/oidc/handler/frame`. Ensure the `clientSecret` is correct.
*   **Kubernetes plugin shows nothing:**
    1.  Check K3s RBAC: Does the Backstage `ServiceAccount` have a `ClusterRoleBinding` to view Deployments, Pods?
    2.  Check label selector in `catalog-info.yaml`: Does `app.kubernetes.io/name=my-app` actually exist on your K8s resources?
    3.  Check `app-config`: Is the cluster `url` and `serviceAccountToken` configured correctly?
*   **TechDocs not rendering:**
    1.  Check MinIO credentials and bucket policy. Backstage backend needs `s3:GetObject` on the docs bucket.
    2.  Check the `backstage.io/techdocs-ref` annotation. `dir:.` means `mkdocs.yml` is in the root.
    3.  Check Backstage backend logs for S3 connection errors.

## ## reference.md Content

### A1. CLI Reference (`backstage-cli`)

#### **Full Command List & Options**

*   `backstage-cli new`
    *   `--select <item>`: Pre-select the item to create (e.g., `plugin`, `app`, `node-library`).
    *   `--scope <scope>`: NPM scope for the new package (e.g., `@helixstax`).
*   `backstage-cli create-plugin`: (Legacy) Use `backstage-cli new --select plugin`.
*   `backstage-cli build`: Builds the entire monorepo. Slower, used for CI validation.
*   `backstage-cli start`: Starts backend only. Useful for backend-only plugin development.
*   `backstage-cli package build`: Builds a single package in the `packages/` or `plugins/` directory. Faster than a full build. **Crucial for multi-stage Dockerfiles.**
*   `backstage-cli app build`: Equivalent to `yarn build`, builds the app package.
*   `backstage-cli package lint`: Lints a single package.
    *   `--fix`: Attempts to auto-fix linting issues.
*   `backstage-cli package test`: Runs tests for a single package.
    *   `--watch`: Runs tests in watch mode.
*   `backstage-cli versions:bump`: Bumps all `@backstage/*` dependencies to the latest version and attempts to apply migrations. Run this after backing up your repo.
*   `backstage-cli versions:check`: Checks for version misalignments in the repo.

### A2. Deployment on K3s

#### **Helm Chart vs. Custom Manifests**

*   **Official Helm Chart (`backstage/backstage`):**
    *   **Pros:** Managed upstream, handles complex resource creation, easier to manage upgrades. Good for standard deployments.
    *   **Cons:** Can be opaque. Customizing non-standard things (like injecting a very specific sidecar) can be difficult.
    *   **Our approach:** Use the official Helm chart but provide a comprehensive `values.yaml` file via ArgoCD to customize it for Helix Stax. This is the best balance of maintainability and customization for our scale.
*   **Custom Manifests (Deployment, Service, etc.):**
    *   **Pros:** Full, granular control. Clear to anyone who reads `kubectl`.
    *   **Cons:** You are responsible for every detail. Upgrades require manually checking for new required resources. More fragile.

#### **Resource Requests/Limits**

For a small team (<20 engineers), these are realistic starting points. Monitor with Grafana and adjust.

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2048Mi
```
*Note: TechDocs builds can be memory intensive. If using `local` builds, increase memory limits.*

#### **Health Checks**

Backstage has a built-in health checker.

*   **Endpoint:** `/healthcheck`
*   **Liveness Probe:**
    ```yaml
    livenessProbe:
      httpGet:
        path: /healthcheck
        port: 7007
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 5
    ```
*   **Readiness Probe:**
    ```yaml
    readinessProbe:
      httpGet:
        path: /healthcheck
        port: 7007
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
    ```

### A3. Catalog: Defining Components

#### **Entity Kinds**
*   **`Component`**: A piece of software. (e.g., service, website, library).
*   **`API`**: An API exposed by a Component. (e.g., OpenAPI, GraphQL).
*   **`System`**: A collection of Components and Resources that form a larger whole. (e.g., "Payment System").
*   **`Domain`**: A business area or knowledge domain. (e.g., "Finance", "Infrastructure").
*   **`Resource`**: Infrastructure a Component needs. (e.g., S3 bucket, CloudNativePG cluster).
*   **`Location`**: A pointer to where more entity definitions can be found.
*   **`Group`**: A team or group of users.
*   **`User`**: An individual developer or user.

#### **`spec.type` for `Component`**
*   `service`: A backend service.
*   `website`: A user-facing website.
*   `library`: A shared library or package.
*   `documentation`: A standalone documentation project.
*   `other`: Anything else.

#### **`spec.lifecycle`**
*   `production`: In active use.
*   `experimental`: Under development, not for production use.
*   `deprecated`: Will be removed in the future.

#### **Relations**
*   `dependsOn`: Component/Resource -> Component/Resource (e.g., a service depends on a database resource).
*   `providesApi`: Component -> API (e.g., `user-service` provides `user-api`).
*   `consumesApi`: Component -> API (e.g., `frontend-app` consumes `user-api`).
*   `partOf`: Component/API/Resource -> System/Domain (e.g., `billing-service` is `partOf` the `payments-system`).
*   `hasPart`: System/Domain -> Component/API/Resource (Inverse of `partOf`).

### A4. Software Templates

#### **Template Parameter Schema**
Each parameter in the `spec.parameters` list is a JSON Schema object.

*   `title`: The form field label.
*   `description`: Help text for the field.
*   `type`: `string`, `number`, `boolean`, `object`, `array`.
*   `ui:field`: Custom UI component (e.g., `OwnerPicker`, `RepoUrlPicker`).
*   `ui:options`: Options for the UI field.
*   `properties` / `items`: For `object` and `array` types.

#### **Built-in Step Actions**

*   `fetch:template`: Fetches skeleton code from a repo.
*   `fetch:plain`: Fetches a single file.
*   `publish:github`: Creates a new GitHub repository and pushes the scaffolded code.
*   `catalog:register`: Registers the `catalog-info.yaml` of the new component.
*   `debug:log`: Prints a message to the scaffolder logs.

#### **Custom Actions**

1.  **Create Action:** In `packages/backend/src/plugins/scaffolder.ts`, create a function that follows the `createScaffolderAction` signature.
2.  **Logic:** The action receives `ctx` (context) containing parameters, workspace path, logger, etc.
3.  **Register:** In the same file, add your custom action to the `createRouter` call: `const actions = [...builtInActions, myCustomAction()];`

### A6. Plugins: Configuration Deep Dive

#### **Security Token Handling**

**NEVER** commit tokens to `app-config.yaml`.
**Pattern:**
1.  Store token in Kubernetes Secret (e.g., from OpenBao/Vault).
2.  Mount as an environment variable in the Backstage Deployment.
3.  Reference it in `app-config.production.yaml` with `${VAR_NAME}`.

```yaml
# Kubernetes Deployment
env:
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: backstage-secrets
        key: github-token
```
```yaml
# app-config.production.yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

### A8. Permissions Framework

The permissions framework enables fine-grained access control.

*   **Policy Decision Point:** A function that evaluates a permission request and returns `ALLOW`, `DENY`, or `CONDITIONAL`.
*   **Conditional Rules:** These are attached to a `CONDITIONAL` decision and evaluated on the resource itself. For example, a `isOwner` rule checks if the user is in the entity's `spec.owner` field.

**Example Policy (`packages/backend/src/plugins/permission.ts`):**

```typescript
import { BackstageIdentityResponse } from '@backstage/plugin-auth-node';
import {
  PermissionPolicy,
  PolicyDecision,
  isPermission,
} from '@backstage/plugin-permission-common';
import {
  catalogEntityDeletePermission,
} from '@backstage/plugin-catalog-common/alpha';

export class HelixStaxPermissionPolicy implements PermissionPolicy {
  async handle(
    request: PermissionCondition | Permission,
    user?: BackstageIdentityResponse,
  ): Promise<PolicyDecision> {

    // Admins can do anything
    if (user?.identity.ownershipEntityRefs.includes('group:default/administrators')) {
      return { result: 'ALLOW' };
    }

    // Deny deleting catalog entities by default
    if (isPermission(request, catalogEntityDeletePermission)) {
      return { result: 'DENY' };
    }

    // Allow all other actions for any logged-in user
    if (user) {
        return { result: 'ALLOW' };
    }

    // Deny by default for anonymous users
    return { result: 'DENY' };
  }
}
```

### A9. API Reference

#### **Authentication**
Use Service-to-Service auth tokens. Generate a token:
`npx backstage-cli backend-auth-token --subject 'system:my-automation-agent'`

Use it in requests: `Authorization: Bearer <token>`

#### **Catalog API**
*   `GET /api/catalog/entities?filter=kind=component,spec.type=service`
*   `GET /api/catalog/entities/by-name/component/default/my-component`
*   `POST /api/catalog/locations` (Body: `{ "type": "url", "target": "https://github.com/org/repo/blob/main/catalog-info.yaml" }`)
*   `DELETE /api/catalog/entities/by-uid/<uid>`
*   `DELETE /api/catalog/locations/<id>`

#### **Scaffolder API**
*   `GET /api/scaffolder/v2/actions`: List available actions.
*   `GET /api/scaffolder/v2/tasks/<taskId>`: Get status of a task.
*   `POST /api/scaffolder/v2/tasks` (Body: `{ "templateRef": "template:default/my-template", "values": { "name": "new-service", "owner": "group:default/my-team" } }`)

## ## examples.md Content

### K3s: ArgoCD Application Manifest

This manifest deploys Backstage. It assumes CloudNativePG and any secret providers (like External Secrets Operator for OpenBao) are already running, enforced by `sync-wave`.

`backstage-application.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backstage
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/HelixStax/infra-gitops.git' # Your GitOps repo
    path: 'apps/backstage'
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: backstage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    managedNamespaceMetadata:
      labels:
        # For Velero backup
        velero.io/backup-container: "true"
        # For network policies
        name: backstage
```

### K3s: Traefik IngressRoute

`backstage-ingressroute.yaml`:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backstage
  namespace: backstage
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`backstage.helixstax.net`)
      kind: Rule
      services:
        - name: backstage
          port: 7007
  tls:
    secretName: backstage-origin-ca-tls  # Cloudflare Origin CA cert — no ACME/cert-manager
```

### K3s: `app-config.production.yaml` via ConfigMap

This is the central configuration file, mounted into the Backstage pod.

`backstage-configmap.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backstage-config
  namespace: backstage
data:
  app-config.production.yaml: |
    app:
      title: Helix Stax Portal
      baseUrl: https://backstage.helixstax.net
    organization:
      name: Helix Stax
    backend:
      baseUrl: https://backstage.helixstax.net
      listen:
        port: 7007
      cors:
        origin: https://backstage.helixstax.net
        methods: [GET, POST, PUT, DELETE]
        credentials: true
      database:
        client: pg
        connection:
          host: '${POSTGRES_HOST}' # e.g., 'cnpg-cluster-rw.postgres.svc.cluster.local'
          port: 5432
          user: '${POSTGRES_USER}'
          password: '${POSTGRES_PASSWORD}'
          database: 'backstage'
          ssl: require
      reading:
        allow:
          - host: 'github.com'
    
    # --- AUTHENTICATION w/ ZITADEL ---
    auth:
      environment: production
      providers:
        oidc:
          provider: oidc
          title: 'Zitadel SSO'
          clientId: 'your-zitadel-backstage-client-id'
          clientSecret: '${AUTH_OIDC_CLIENT_SECRET}'
          metadataUrl: https://auth.helixstax.net/.well-known/openid-configuration
          scope: 'openid profile email offline_access urn:zitadel:iam:org:project:roles'
          # Sign-in resolver defined below
          signIn:
            resolver: &signInResolver
              catalyst.zitadel.signInResolver
          resolvers:
            - name: catalyst.zitadel
              resolver:
                signIn:
                  resolver:
                    id: [claims.sub]
                    email: [claims.email]
                    picture: [claims.picture]
                    displayName: [claims.name]
                    ownership:
                      - claims['urn:zitadel:iam:org:project:roles'].map((role) => `group:default/${role}`)

    # --- CATALOG ---
    catalog:
      rules:
        - allow: [Component, API, System, Domain, Resource, Location, Group, User]
      locations:
        # Auto-discover all catalog-info.yaml files in our GitHub org
        - type: github-org
          target: https://github.com/HelixStax
          rules:
            - allow: [Component] # Only ingest Components from this rule

    # --- TECHDOCS w/ MINIO ---
    techdocs:
      builder: 'local'
      generator:
        runIn: 'docker'
      publisher:
        type: 'awsS3'
        awsS3:
          region: 'us-east-1' # Required for MinIO, can be anything
          bucketName: 'backstage-techdocs'
          endpoint: 'http://minio.minio.svc.cluster.local:9000' # K8s internal service DNS
          s3ForcePathStyle: true
          credentials:
            accessKeyId: '${MINIO_ACCESS_KEY_ID}'
            secretAccessKey: '${MINIO_SECRET_ACCESS_KEY}'

    # --- KUBERNETES PLUGIN ---
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: 'https://kubernetes.default.svc' # In-cluster API endpoint — avoids external IP + cert issues
              name: 'helix-k3s-prod'
              authProvider: 'serviceAccount'
              skipTLSVerify: false # Use in-cluster service account — TLS is trusted internally
              serviceAccountToken: '${K8S_SA_TOKEN}'

    # --- ARGOCD PLUGIN ---
    argocd:
      appLocatorMethods:
        - type: 'config'
          instances:
            - name: 'main'
              url: 'https://argocd.helixstax.net'
              token: '${ARGOCD_TOKEN}'

    # --- GRAFANA PLUGIN ---
    grafana:
      domain: https://grafana.helixstax.net
      # If using Grafana auth proxy
      # proxyPath: /api/grafana

    # --- GITHUB ACTIONS PLUGIN ---
    github:
      integrations:
        - host: github.com
          token: ${GITHUB_TOKEN}
```

### Complete `catalog-info.yaml` Example for a K3s Service

This example shows a backend service deployed via ArgoCD on our K3s cluster, with docs in TechDocs.

`billing-service/catalog-info.yaml`:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: billing-service
  description: Handles all client billing and invoicing.
  tags:
    - java
    - spring-boot
    - payments
  annotations:
    # --- Source Code & CI/CD ---
    github.com/project-slug: 'HelixStax/billing-service'
    backstage.io/source-location: 'url:https://github.com/HelixStax/billing-service'
    
    # --- Documentation ---
    backstage.io/techdocs-ref: dir:.

    # --- Kubernetes -> Find K8s objects with this label ---
    backstage.io/kubernetes-label-selector: 'app.kubernetes.io/name=billing-service'
    backstage.io/kubernetes-namespace: 'payments'

    # --- ArgoCD -> Find ArgoCD app with this name ---
    argocd/app-name: 'billing-service'

    # --- Grafana -> Find dashboards tagged with "billing-service" ---
    grafana.com/dashboard-selector: '"tags": ["billing-service"]'

    # --- Harbor -> Find image in Harbor registry ---
    # (Using a generic annotation, as no official Harbor plugin is dominant yet)
    'container.image/repo': 'harbor.helixstax.net/production/billing-service'

spec:
  type: service
  lifecycle: production
  owner: group:default/sre-team # Corresponds to a Zitadel role
  system: payments-platform
  providesApis:
    - billing-api
  dependsOn:
    - resource:default/payments-db # Link to a Resource entity for our CloudNativePG cluster
    - api:default/stripe-api # Consumes an external API
```

### API Call Examples (`curl`)

```bash
# Generate a token (run this once)
BACKSTAGE_TOKEN=$(npx backstage-cli backend-auth-token --subject 'system:devops-agent')

# Query for all production services
curl -H "Authorization: Bearer $BACKSTAGE_TOKEN" \
  'https://backstage.helixstax.net/api/catalog/entities?filter=kind=component,spec.type=service,spec.lifecycle=production'

# Trigger a scaffolder template
curl -X POST \
  -H "Authorization: Bearer $BACKSTAGE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "templateRef": "template:default/spring-boot-template",
    "values": {
      "component_id": "new-promo-service",
      "description": "A new service for promotions",
      "owner": "group:default/marketing-tech"
    }
  }' \
  'https://backstage.helixstax.net/api/scaffolder/v2/tasks'
```
---

# Outline

## ## SKILL.md Content

### Overview

Outline is our self-hosted knowledge base and wiki. We use it for internal documentation (runbooks, SOPs, architecture notes) and for creating client-facing portals with shared documentation and deliverables. Its clean API is essential for our n8n automation workflows.

### Deployment on K3s

#### **Core Dependencies**

Outline is stateful and requires:
1.  **PostgreSQL Database:** Provided by CloudNativePG.
2.  **Redis Cache:** Provided by Valkey.
3.  **S3 Object Storage:** Provided by MinIO.

#### **Key Environment Variables**

These are injected into the Outline Deployment from Kubernetes Secrets.

*   `SECRET_KEY`, `UTILS_SECRET`: Generate with `openssl rand -hex 32`.
*   `URL`: `https://wiki.helixstax.net`
*   `DATABASE_URL`: `postgres://<user>:<password>@<host>:<port>/<db>?sslmode=require`
*   `REDIS_URL`: `redis://:<password>@<host>:<port>/0`
*   `AWS_ACCESS_KEY_ID`: `${MINIO_ACCESS_KEY_ID}`
*   `AWS_SECRET_ACCESS_KEY`: `${MINIO_SECRET_ACCESS_KEY}`
*   `AWS_S3_UPLOAD_BUCKET_NAME`: `outline-uploads`
*   `AWS_S3_UPLOAD_BUCKET_URL`: `http://minio.minio.svc.cluster.local:9000`
*   `AWS_REGION`: `us-east-1` (placeholder for MinIO)
*   `AWS_S3_FORCE_PATH_STYLE`: `true` (**CRITICAL for MinIO**)

#### **Database Migrations**

Outline runs database migrations automatically on startup. Ensure the Pod has a `restartPolicy: Always`.

#### **ArgoCD Sync Waves**

Ensure dependencies are ready before Outline starts.
*   CloudNativePG Cluster: `sync-wave: "0"`
*   Valkey: `sync-wave: "1"`
*   MinIO: `sync-wave: "1"`
*   Outline Deployment: `sync-wave: "2"`

### OIDC with Zitadel

Configure via environment variables.

*   `OIDC_CLIENT_ID`: `your-zitadel-outline-client-id`
*   `OIDC_CLIENT_SECRET`: `${OIDC_CLIENT_SECRET}`
*   `OIDC_AUTH_URI`: `https://auth.helixstax.net/oauth/v2/authorize`
*   `OIDC_TOKEN_URI`: `https://auth.helixstax.net/oauth/v2/token`
*   `OIDC_USERINFO_URI`: `https://auth.helixstax.net/oidc/v1/userinfo`
*   `OIDC_DISPLAY_NAME`: `Zitadel SSO`
*   `OIDC_SCOPES`: `openid email profile`
*   `ALLOWED_DOMAINS`: `helixstax.com` (Restricts sign-ups to our domain)

**Zitadel Client Redirect URI:** `https://wiki.helixstax.net/auth/oidc.callback`

### REST API Reference

*   **Authentication:** `Authorization: Bearer <API_KEY>` (Generate API keys in user settings)
*   **List Documents:** `GET /api/documents.list?collectionId=<id>`
*   **Create Document:** `POST /api/documents.create`
    *   Body: `{ "collectionId": "...", "title": "...", "text": "...", "parentDocumentId": "..." }`
*   **Update Document:** `POST /api/documents.update`
    *   Body: `{ "id": "...", "title": "...", "text": "..." }`
*   **Search Documents:** `POST /api/documents.search`
    *   Body: `{ "query": "incident report" }`

### n8n Integration

1.  **In Outline:** Go to Settings -> Integrations -> Webhooks. Add a new webhook pointing to your n8n webhook URL.
2.  **In n8n:** Use the "Webhook" trigger node.
3.  **To call Outline API:** Use the "HTTP Request" node.
    *   **Authentication:** `Generic Credential Type` -> `Header Auth`
    *   **Name:** `Authorization`
    *   **Value:** `Bearer <your_outline_api_key>`

#### **Auto-Documentation Workflow Example**

`GitHub Webhook (push to main) -> n8n Workflow -> Read catalog-info.yaml -> Outline API (documents.create or documents.update)`

### Troubleshooting Quick-Fire

*   **File Uploads Fail (5xx error):**
    1.  Check `AWS_S3_FORCE_PATH_STYLE` is `true`.
    2.  Check MinIO bucket exists (`outline-uploads`) and is accessible from the Outline pod (`kubectl exec -it <pod> -- nc -zv minio.minio.svc 9000`).
    3.  Verify MinIO credentials are correct.
*   **OIDC Login Fails ("Could not sign in"):**
    1.  Verify Redirect URI in Zitadel is `https://wiki.helixstax.net/auth/oidc.callback`.
    2.  Check Outline logs for OIDC errors.
    3.  Ensure `URL` env var is `https://wiki.helixstax.net`.
*   **Stuck in Redirect Loop:** The `URL` env var must match the public-facing URL exactly, including `https://`. Traefik might be stripping headers; ensure it's passing `X-Forwarded-Proto`.
*   **Database connection fails on startup:** Check the `DATABASE_URL` format. Ensure CloudNativePG's service is reachable and the user/password from the CNPG-generated secret are correct. Ensure `sslmode=require` is present.

## ## reference.md Content

### B1. REST API Reference

*   **Authentication:** Generate API tokens under `Settings > API Keys`. A token inherits the permissions of the user who created it.
*   **Base URL:** `https://wiki.helixstax.net`

#### **Key Endpoints**

*   **Collections**
    *   `collections.list`: `POST /api/collections.list`
    *   `collections.create`: `POST /api/collections.create` (Body: `{ "name": "New Collection", "description": "...", "color": "#123456", "private": false }`)
    *   `collections.delete`: `POST /api/collections.delete` (Body: `{ "id": "..." }`)
*   **Documents**
    *   `documents.list`: `POST /api/documents.list` (Supports `collectionId`, `parentDocumentId`, `sort`, `direction`)
    *   `documents.info`: `POST /api/documents.info` (Body: `{ "id": "..." }`)
    *   `documents.create`: `POST /api/documents.create`
    *   `documents.update`: `POST /api/documents.update`
    *   `documents.delete`: `POST /api/documents.delete`
    *   `documents.search`: `POST /api/documents.search`
*   **Attachments**
    *   `attachments.create`: `POST /api/attachments.create` (Multipart form data, Body: `{ "name": "file.png", "documentId": "...", "file": <data> }`)
*   **Webhook Payload Schema**
    ```json
    {
      "event": "documents.update",
      "data": {
        "id": "doc-uuid",
        "title": "Document Title",
        "url": "/doc/document-title-slug-doc-uuid",
        "collectionId": "collection-uuid",
        "actorId": "user-uuid"
      }
    }
    ```
    The header `x-outline-signature` contains an `HMAC_SHA256` signature of the raw request body, using your `UTILS_SECRET` as the key.

### B2. Deployment on K3s

#### **Complete Environment Variable List**

*   `NODE_ENV`: `production`
*   `PORT`: `8080` (or as desired)
*   `URL`: `https://wiki.helixstax.net`
*   `SECRET_KEY`, `UTILS_SECRET`: (Required) `openssl rand -hex 32`
*   `DATABASE_URL`: (Required) `postgres://user:pass@host:port/dbname?sslmode=require`
*   `REDIS_URL`: (Required) `redis://:pass@host:port/0`
*   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: (Required for file storage)
*   `AWS_S3_UPLOAD_BUCKET_NAME`: (Required) e.g., `outline-uploads`
*   `AWS_S3_UPLOAD_BUCKET_URL`: (Required for MinIO) e.g., `http://minio.minio.svc:9000`
*   `AWS_REGION`: (Required for MinIO) `us-east-1`
*   `AWS_S3_FORCE_PATH_STYLE`: (Required for MinIO) `true`
*   All `OIDC_*` variables (see below).
*   `ALLOWED_DOMAINS`: e.g., `helixstax.com, client-domain.com`

#### **Persistent Storage**
Outline itself is stateless. The container can be replaced without data loss. **No PVC is required for the Outline deployment itself.** State is held in:
1.  **PostgreSQL (CloudNativePG):** The source of truth for all text content, users, permissions. This has its own PVCs managed by the operator.
2.  **MinIO:** Stores all file uploads (images, attachments). This has its own PVCs.

### B3. OIDC with Zitadel

#### **Admin Bootstrap**
The first user to sign in from an `ALLOWED_DOMAINS` via OIDC is automatically promoted to an admin. To provision a specific admin, you must use the `user.promote` API endpoint after they have signed in once.

#### **Disabling Other Auth**
When OIDC is configured, password and other auth methods are automatically disabled. The login screen will redirect to the OIDC provider.

### B5. Permissions: Teams, Groups, and Document Access

*   **Roles:**
    *   `Admin`: Workspace-level god mode. Can manage settings, users, billing.
    *   `Member`: Default role. Can create/edit documents in collections they have access to.
    *   `Viewer`: Read-only access to collections they are a part of.
    *   `Guest`: A user who is not a `Member`. Typically invited to view specific documents or collections.
*   **Group Mapping:** Outline does **not** support automatic group sync from OIDC claims. Groups must be created in Outline manually. You can then use the API to add users to groups based on their OIDC identity as part of a user provisioning workflow (e.g., via n8n).

### B9. Backup and Recovery

*   **Database (CloudNativePG):** Relies entirely on the CloudNativePG operator's backup configuration. Ensure backups are scheduled and stored off-site (e.g., in a separate S3 bucket).
*   **File Attachments (MinIO):**
    *   **Velero:** The recommended K8s-native approach. Annotate the MinIO namespace and its PVCs for backup.
    *   **Manual `mc mirror`:** A cron job running `mc mirror` can sync the `outline-uploads` bucket to another S3-compatible service like Backblaze B2. `mc mirror --overwrite minio/outline-uploads b2/helixstax-outline-backup`
*   **Restore Procedure:**
    1.  Restore the CloudNativePG cluster from backup to a specific point in time.
    2.  Restore the MinIO bucket/PVC from the corresponding backup time.
    3.  Restart the Outline deployment. It will connect to the restored database and file store.

## ## examples.md Content

### K3s: Full Kubernetes Manifest Stack

These manifests deploy Outline and its dependencies within the `docs` namespace.

`outline-manifests.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: docs
---
# This Secret should be populated by your secrets manager, e.g., OpenBao + ESO
apiVersion: v1
kind: Secret
metadata:
  name: outline-secrets
  namespace: docs
type: Opaque
stringData:
  # Generate with 'openssl rand -hex 32'
  SECRET_KEY: "..."
  UTILS_SECRET: "..."
  # From Zitadel
  OIDC_CLIENT_SECRET: "..."
  # From CloudNativePG-generated secret
  POSTGRES_USER: "outline"
  POSTGRES_PASSWORD: "..."
  # From Valkey secret
  VALKEY_PASSWORD: "..."
  # From MinIO secret
  MINIO_ACCESS_KEY_ID: "..."
  MINIO_SECRET_ACCESS_KEY: "..."
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: outline
  namespace: docs
  annotations:
    # ArgoCD Sync Wave: Deploy this last
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: outline
  template:
    metadata:
      labels:
        app: outline
    spec:
      containers:
        - name: outline
          image: outlinewiki/outline:0.78.0 # Pinned version — do not use :latest in production
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: NODE_ENV
              value: "production"
            - name: URL
              value: "https://wiki.helixstax.net"
            - name: PORT
              value: "8080"
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: outline-secrets
                  key: SECRET_KEY
            - name: UTILS_SECRET
              valueFrom:
                secretKeyRef:
                  name: outline-secrets
                  key: UTILS_SECRET
            # --- Database (CloudNativePG) ---
            - name: DATABASE_URL
              value: "postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@cnpg-cluster-rw.postgres.svc:5432/outline?sslmode=require"
            - name: POSTGRES_USER
              valueFrom: { secretKeyRef: { name: outline-secrets, key: POSTGRES_USER } }
            - name: POSTGRES_PASSWORD
              valueFrom: { secretKeyRef: { name: outline-secrets, key: POSTGRES_PASSWORD } }
            # --- Cache (Valkey) ---
            - name: REDIS_URL
              value: "redis://:$(VALKEY_PASSWORD)@valkey-master.valkey.svc:6379/0"
            - name: VALKEY_PASSWORD
              valueFrom: { secretKeyRef: { name: outline-secrets, key: VALKEY_PASSWORD } }
            # --- Storage (MinIO) ---
            - name: AWS_ACCESS_KEY_ID
              valueFrom: { secretKeyRef: { name: outline-secrets, key: MINIO_ACCESS_KEY_ID } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: outline-secrets, key: MINIO_SECRET_ACCESS_KEY } }
            - name: AWS_S3_UPLOAD_BUCKET_NAME
              value: "outline-uploads"
            - name: AWS_S3_UPLOAD_BUCKET_URL
              value: "http://minio.minio.svc.cluster.local:9000"
            - name: AWS_REGION
              value: "us-east-1"
            - name: AWS_S3_FORCE_PATH_STYLE
              value: "true"
            # --- SSO (Zitadel) ---
            - name: OIDC_CLIENT_ID
              value: "your-zitadel-outline-client-id" # Your client ID from Zitadel
            - name: OIDC_CLIENT_SECRET
              valueFrom: { secretKeyRef: { name: outline-secrets, key: OIDC_CLIENT_SECRET } }
            - name: OIDC_AUTH_URI
              value: "https://auth.helixstax.net/oauth/v2/authorize"
            - name: OIDC_TOKEN_URI
              value: "https://auth.helixstax.net/oauth/v2/token"
            - name: OIDC_USERINFO_URI
              value: "https://auth.helixstax.net/oidc/v1/userinfo"
            - name: OIDC_DISPLAY_NAME
              value: "Zitadel SSO"
            - name: OIDC_SCOPES
              value: "openid email profile"
            - name: ALLOWED_DOMAINS
              value: "helixstax.com"
          readinessProbe:
            httpGet: { path: /api/health, port: http }
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /api/health, port: http }
            initialDelaySeconds: 60
            periodSeconds: 20
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 1024Mi
---
apiVersion: v1
kind: Service
metadata:
  name: outline
  namespace: docs
spec:
  selector:
    app: outline
  ports:
    - name: http
      port: 80
      targetPort: 8080
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: outline
  namespace: docs
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`wiki.helixstax.net`)
      kind: Rule
      services:
        - name: outline
          port: 80
  tls:
    secretName: outline-origin-ca-tls  # Cloudflare Origin CA cert — no ACME/cert-manager
```

### ArgoCD Application Manifest for Outline

This manifest ensures dependencies are deployed in the correct order using sync waves.

`outline-application.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: outline
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/HelixStax/infra-gitops.git'
    path: 'apps/outline'
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: docs # Target namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    managedNamespaceMetadata:
      labels:
        # For network policies
        name: docs
```
*Note: The individual manifests inside `apps/outline/` should have the `argocd.argoproj.io/sync-wave` annotations.*
*   CNPG Cluster: `sync-wave: "0"`
*   Valkey StatefulSet: `sync-wave: "1"`
*   Outline Deployment: `sync-wave: "2"`

### n8n Workflow: Sync Runbook from GitHub to Outline

This workflow triggers on a push to a `runbooks/` directory in a GitHub repo, finds the corresponding document in Outline, and updates it.

1.  **Trigger:** `GitHub` Trigger
    *   `Trigger on`: `Push`
    *   `Repository`: Your repo with runbooks
    *   `Branch`: `main`
2.  **Filter (Node): `IF`**
    *   Condition: `{{ $json.body.commits[0].modified }}` `contains` `runbooks/`
    *   Only proceed if a file in the `runbooks/` path was modified.
3.  **Get File Content (Node): `HTTP Request`**
    *   `URL`: `{{ $json.body.head_commit.url }}` (from GitHub trigger, needs to be parsed to get raw file URL)
    *   `Authentication`: GitHub API token
    *   *Logic: This step is complex. You need to parse the commit payload to get the path of the modified `.md` file and then construct a GitHub API call to get its content.*
4.  **Search for Document (Node): `HTTP Request`**
    *   `Method`: `POST`
    *   `URL`: `https://wiki.helixstax.net/api/documents.search`
    *   `Authentication`: Header Auth (Outline API Bearer Token)
    *   `Body`: `{ "query": "{{ $json.filename_from_step_3 }}", "collectionId": "your_runbooks_collection_id" }`
5.  **Create or Update (Node): `IF`**
    *   Condition: `{{ $json.body.data.length > 0 }}` (Check if search found a document)
    *   TRUE Path -> Go to Step 6 (Update)
    *   FALSE Path -> Go to Step 7 (Create)
6.  **Update Document (Node): `HTTP Request` (TRUE Path)**
    *   `Method`: `POST`
    *   `URL`: `https://wiki.helixstax.net/api/documents.update`
    *   `Authentication`: Header Auth
    *   `Body`: `{ "id": "{{ $json.body.data[0].id }}", "text": "{{ $json.content_from_step_3 }}" }`
7.  **Create Document (Node): `HTTP Request` (FALSE Path)**
    *   `Method`: `POST`
    *   `URL`: `https://wiki.helixstax.net/api/documents.create`
    *   `Authentication`: Header Auth
    *   `Body`: `{ "collectionId": "your_runbooks_collection_id", "title": "{{ $json.filename_from_step_3 }}", "text": "{{ $json.content_from_step_3 }}" }`
