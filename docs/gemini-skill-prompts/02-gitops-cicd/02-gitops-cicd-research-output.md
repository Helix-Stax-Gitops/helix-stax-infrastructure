Of course. Here is the comprehensive Gemini Deep Research document for ArgoCD and Devtron, structured for your AI agents and tailored to the Helix Stax environment.

# ArgoCD

### ## SKILL.md Content
Core reference for daily AI agent operations. Concise and actionable.

```markdown
# ArgoCD Quick Reference (for AI Agents)

## Core Purpose
ArgoCD is the GitOps engine for Helix Stax infrastructure. It ensures the state of the K3s cluster (`helix-stax-cp` CP, `helix-stax-vps` worker) matches the declarative configuration in the `helix-stax-infrastructure` GitHub repository. **It manages platform services ONLY (Traefik, cert-manager, Prometheus, Zitadel, etc.). Devtron manages application workloads.**

## CLI Essentials (Helix Stax Setup)
**Login (via Cloudflare Zero Trust & Zitadel):**
Authentication is via OIDC. A browser-based login flow will open. For scripts, use an auth token. The `--grpc-web` flag is **mandatory** due to our Traefik/Cloudflare setup.

```bash
# Interactive Login (opens browser)
argocd login argocd.helixstax.net --grpc-web

# Scripting Login (generate a token in the ArgoCD UI)
export ARGOCD_AUTH_TOKEN="<paste-long-lived-token-here>"
argocd app list --server argocd.helixstax.net --grpc-web --auth-token $ARGOCD_AUTH_TOKEN
```

**Common Operations:**

```bash
# List all infrastructure applications
argocd app list --grpc-web

# Check sync status and health of an app (e.g., prometheus)
argocd app get prometheus --grpc-web

# See what's different between Git and the live state
argocd app diff prometheus --grpc-web

# Manually trigger a sync for an out-of-sync app
argocd app sync prometheus --grpc-web

# Force a sync with pruning if deletion is required
argocd app sync prometheus --prune --grpc-web

# Roll back an app to a previous Git commit (get revision from history)
argocd app history prometheus --grpc-web
argocd app rollback prometheus <HISTORY_ID> --grpc-web

# Delete an application (and its resources if finalizer is present)
argocd app delete traefik --grpc-web
```

## Troubleshooting Decision Tree

| Symptom                               | Likely Cause                                             | First Action                                                               |
| ------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------- |
| App is `OutOfSync`                    | Change made in Git, not yet synced.                      | Run `argocd app diff <app> --grpc-web` to see changes. If OK, `argocd app sync <app> --grpc-web`. |
| App is `Degraded` or `Progressing`    | Health check is failing (Pod CrashLoop, Ingress no IP).  | `kubectl describe <resource> -n <namespace>` on failing resource shown in UI. Check pod logs. |
| Sync fails with `ComparisonError`     | CRD missing on cluster, or RBAC issue.                   | Verify the CRD for the resource exists (`kubectl get crd <crd-name>`). Check argo-cd controller logs. |
| Sync fails with `SyncFailed`          | Resource hook failed, invalid manifest, admission error. | `argocd app get <app> --show-operation --grpc-web`. Look at `status.operationState.syncResult`. |
| Login fails / can't connect           | `argocd-server` pod is down, or Traefik Ingress is broken. | `kubectl get pods -n argocd`. Check logs of `argocd-server`. Check `IngressRoute` for `argocd.helixstax.net`. |

## Key Configuration Snippets

**Standard `Application` CRD for an Infra Component:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/KeemWilliams/helix-stax-infrastructure.git'
    path: k8s/infra/monitoring/kube-prometheus-stack
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## Devtron Co-existence Rule
- **Our ArgoCD:** Namespace `argocd`, manages infra apps defined in `helix-stax-infrastructure`. UI at `argocd.helixstax.net`.
- **Devtron's ArgoCD:** Namespace `devtroncd`, manages application workloads deployed by Devtron. Do NOT interact with it directly unless debugging a Devtron deployment.
- **Conflict Avoidance:** Never create an `Application` in the `argocd` namespace that manages resources in a namespace controlled by Devtron. The split is strict.

```

### ## reference.md Content
Deep specifications, advanced patterns, and full configuration details.

```markdown
# ArgoCD Deep Reference

## AC-1. CLI Reference (`argocd`)

The `argocd` CLI communicates with the ArgoCD API server. For the Helix Stax setup, `--grpc-web` is required for all commands targeting the server due to the Traefik Ingress configuration.

- **`argocd login <SERVER> [--grpc-web]`**: Authenticates with the ArgoCD server. Will open a browser for our Zitadel SSO.
- **`argocd account update-password`**: For local accounts only. Not used with SSO.
- **`argocd admin settings`**: View/modify server-side settings.
    - `argocd admin settings oidc --show`: Dumps the configured OIDC settings.

### Application Management (`argocd app`)
- **`argocd app create [APPNAME] --repo [REPO_URL] --path [PATH] --dest-server [SERVER] --dest-namespace [NS] [flags]`**: Creates an application.
- **`argocd app list [flags]`**: Lists applications.
- **`argocd app get [APPNAME] [flags]`**: Describe a single application.
    - `--show-operation`: Display details of the current or last sync operation.
    - `--show-params`: Display resolved Helm/Kustomize parameters.
- **`argocd app diff [APPNAME] [flags]`**: Performs a diff between Git and live state.
    - `--local [PATH]`: Diff against local manifests instead of Git.
- **`argocd app sync [APPNAME] [flags]`**: Triggers an application sync.
    - `--force`: Sync even if the state is already Synced (useful for re-applying after manual changes).
    - `--prune`: Allows deletion of resources not defined in Git.
    - `--replace`: Deletes and re-creates resources instead of applying changes. Destructive.
    - `--revision [GIT_REVISION]`: Sync to a specific commit/tag instead of the one in the app spec.
- **`argocd app history [APPNAME]`**: Shows deployment history (past syncs).
- **`argocd app rollback [APPNAME] [HISTORY_ID]`**: Rolls back to a previous state from history.
- **`argocd app set [APPNAME]`**: Modifies application spec fields.
    - `argocd app set my-app -p "helm.image.tag=v1.2.3"`
- **`argocd app delete [APPNAME]`**: Deletes an application. If the `resources-finalizer` is present, it will also delete the deployed K8s resources.

### Project Management (`argocd proj`)
- **`argocd proj create [PROJECTNAME]`**: Creates a project.
- **`argocd proj list`**: Lists all projects.
- **`argocd proj get [PROJECTNAME]`**: Shows project details.
- **`argocd proj set [PROJECTNAME]`**: Modifies project settings (source repos, destinations, roles).

### Repository & Cluster Management
- **`argocd repo add [URL] [flags]`**: Adds a Git repository or Helm chart repository.
    - `--username [USER] --password [PASS/TOKEN]`: For HTTPS auth.
    - `--ssh-private-key-path [PATH]`: For SSH auth.
    - `--type helm --name [NAME] --enable-oci`: Registers a Helm OCI registry like Harbor.
- **`argocd repo list`**: Lists configured repositories.
- **`argocd cluster add [CONTEXT] [flags]`**: Adds a K8s cluster (future-proofing).
- **`argocd cluster list`**: Lists managed clusters.

### Automation (`--auth-token`)
For CI/CD scripts, generate a token from the ArgoCD UI (`User Info -> Account -> Generate New Token`) and use the `--auth-token` flag. This bypasses the interactive OIDC login.

```bash
ARGOCD_SERVER="argocd.helixstax.net"
ARGOCD_TOKEN="<generated-api-token>"
argocd app sync my-app --grpc-web --server $ARGOCD_SERVER --auth-token $ARGOCD_TOKEN
```

---

## AC-2. Application Manifests

### `Application` CRD Structure
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: # App name in ArgoCD UI
  namespace: argocd # Must be argocd namespace
spec:
  project: # The AppProject this app belongs to (e.g., 'default')
  source: # WHERE the desired state is defined
    repoURL: 'https://github.com/KeemWilliams/helix-stax-infrastructure.git'
    targetRevision: 'HEAD' # Git branch, tag, or commit SHA
    path: 'k8s/infra/traefik' # Directory within the repo
    
    # --- HELM SOURCE ---
    chart: 'traefik' # Only if repoURL is a chart repo
    helm:
      values: | # Raw YAML values
        image:
          tag: "v2.10.5"
      valueFiles: # List of values files within the git repo path
        - values-production.yaml
        
    # --- KUSTOMIZE SOURCE ---
    kustomize:
      images: # Override images
        - 'nginx:1.21.0'
      version: 'v4.5.7' # Specify kustomize version

    # --- DIRECTORY SOURCE ---
    directory:
      recurse: true # Process subdirectories
      include: '*.yaml'
      exclude: 'kustomization.yaml'

  destination: # WHERE to deploy the resources
    server: 'https://kubernetes.default.svc' # 'in-cluster'
    namespace: 'traefik' # Target namespace on the cluster

  syncPolicy: # HOW to sync
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### `AppProject` CRD
Projects provide RBAC boundaries for applications.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infra-services
  namespace: argocd
spec:
  description: Project for core infrastructure services
  sourceRepos: # Whitelist of allowed source Git repositories
    - 'https://github.com/KeemWilliams/helix-stax-infrastructure.git'
  destinations: # Whitelist of allowed deployment targets
    - namespace: 'monitoring'
      server: 'https://kubernetes.default.svc'
    - namespace: 'traefik'
      server: 'https://kubernetes.default.svc'
  namespaceResourceWhitelist: # Whitelist of resource kinds this project can manage
    - group: '*'
      kind: '*'
  roles: # Project-specific RBAC roles
  - name: team-a-admin
    description: Admin access for Team A
    policies:
    - p, proj:infra-services:team-a-admin, applications, *, infra-services/*, allow
    groups: # Map to OIDC groups from Zitadel
    - 'team-a' 
```

### `ApplicationSet` CRD
Automates the creation of Applications.
- **Git Generator**: Creates applications from directories or files in a git repo. Use case: Stamping out an application for every folder in a `/apps` directory.
- **Cluster Generator**: Creates applications for every registered cluster. Use case: Deploying a monitoring agent to all clusters.
- **List Generator**: Creates applications from a static list of parameters.

### ArgoCD Annotations
- **`argocd.argoproj.io/sync-wave: "N"`**: Controls sync ordering. Lower waves sync first. Resources without this annotation are wave 0.
- **`argocd.argoproj.io/hook: PreSync | Sync | PostSync | SyncFail`**: Run Jobs/Pods at different phases of a sync.
- **`argocd.argoproj.io/hook-delete-policy: BeforeHookCreation | HookSucceeded | HookFailed`**: Controls when hooks are deleted.

---

## AC-3. Multi-Source Applications
Combines multiple sources into a single application. The primary use case is to combine a generic Helm chart (from Harbor OCI) with environment-specific values (from Git).

- **Why it matters:** Decouples the lifecycle of the application chart from its configuration. The chart can be versioned and stored in Harbor, while each environment's `values.yaml` lives in the `helix-stax-infrastructure` git repo.
- **ArgoCD Version:** Requires ArgoCD v2.6+.

### YAML Structure
The `sources` field (plural) replaces `source`. The first source is the chart, and subsequent sources are typically Git repos containing value files. Use the `$values` variable to reference a source.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-from-harbor
  namespace: argocd
spec:
  project: default
  # Use 'sources' instead of 'source'
  sources:
    # Source 1: The Helm chart from Harbor OCI registry
    - repoURL: 'oci://harbor.helixstax.net/charts'
      chart: 'my-app'
      targetRevision: '1.2.0' # Chart version
      helm:
        # Reference values from the 'env-values' source by name
        valueFiles:
          - $values/production/values.yaml

    # Source 2: The Git repository with environment-specific values
    - repoURL: 'https://github.com/KeemWilliams/helix-stax-infrastructure.git'
      targetRevision: HEAD
      # Give this source a name to reference it
      ref: values

  destination:
    server: 'https://kubernetes.default.svc'
    namespace: 'my-app'
```

---

## AC-4. Sync Policies

- **`automated.prune: true`**: When ArgoCD syncs, any resource found in the cluster that is not in the Git source will be deleted. **Safety**: It will not delete resources that lack the ArgoCD tracking annotation, preventing it from wiping out manually-created resources.
- **`automated.selfHeal: true`**: If drift is detected (e.g., a manual `kubectl edit` change), ArgoCD will automatically trigger a sync to revert the change and match Git state. Polling interval is ~3 minutes by default.

### `syncOptions`
- **`CreateNamespace=true`**: Automatically create the destination namespace if it doesn't exist.
- **`PruneLast=true`**: A safety option. Deletes pruned resources as the final step in a sync.
- **`ApplyOutOfSyncOnly=true`**: Speeds up syncs by only applying changes to resources that are `OutOfSync`.
- **`ServerSideApply=true`**: Uses `kubectl apply --server-side` logic. Better for managing large resources and avoids `last-applied-configuration` annotation bloat. Recommended.
- **`RespectIgnoreDifferences=true`**: Ensures that `spec.ignoreDifferences` configurations are honored during sync.

### Sync Retry
Configure retry logic for transient sync failures.
```yaml
spec:
  syncPolicy:
    retry:
      limit: 5 # Number of retries
      backoff:
        duration: 5s # Initial delay
        factor: 2 # Multiplier for each subsequent retry
        maxDuration: 3m # Maximum delay
```

### `ignoreDifferences`
Instructs ArgoCD to ignore certain fields when checking for drift. Essential for fields managed by other controllers (e.g., HPAs managing `replicas`).
```yaml
spec:
  ignoreDifferences:
  - group: "apps"
    kind: "Deployment"
    jsonPointers:
    - /spec/replicas # Ignore replica count managed by an HPA
  - group: "cert-manager.io"
    kind: "Certificate"
    jqPathExpressions:
    - .status # Ignore the entire status field for cert-manager certificates
```

---

## AC-5. RBAC and SSO with Zitadel

### 1. Zitadel OIDC Client Setup
- **Application Type**: Web
- **Authentication Method**: Basic (Client Secret)
- **Redirect URIs**: `https://argocd.helixstax.net/api/dex/callback`
- **Scopes**: must include `openid`, `profile`, `email`, and `groups` or a custom scope that contains group information.

### 2. ArgoCD OIDC Configuration (`argocd-cm`)
```yaml
data:
  # This is the Dex configuration block used by ArgoCD
  dex.config: |
    connectors:
    - type: oidc
      id: zitadel
      name: Zitadel
      config:
        issuer: https://zitadel.helixstax.net
        clientID: <ZITADEL_CLIENT_ID_FOR_ARGOCD>
        clientSecret: $dex.zitadel.clientSecret # Reference to secret key
        redirectURI: https://argocd.helixstax.net/api/dex/callback
        
        # Request the scopes needed to get user info and group claims
        scopes:
        - openid
        - profile
        - email
        - "urn:zitadel:iam:org:project:roles" # This is key for group claims
        
        # Tell Dex which claim contains the group information
        claimMapping:
          groups: "urn:zitadel:iam:org:project:roles"
```

### 3. OIDC Client Secret (`argocd-secret`)
The `clientSecret` is injected from OpenBao via External Secrets Operator. ArgoCD's `argocd-cm` references this value.
```yaml
# In argocd-secret, managed by ESO
data:
  dex.zitadel.clientSecret: <base64-encoded-zitadel-client-secret>
```

### 4. RBAC Policy (`argocd-rbac-cm`)
This maps the groups received from Zitadel to ArgoCD roles.
```yaml
data:
  # policy.csv format: p, <type>, <role/group>, <resource>, <sub-resource>, <action>
  policy.csv: |
    # Grant members of the 'helix-stax-admins' Zitadel group the built-in ArgoCD admin role
    g, helix-stax-admins, role:admin
    
    # Grant members of the 'helix-stax-devs' Zitadel group read-only access globally
    g, helix-stax-devs, role:readonly

    # Project-specific role: Grant 'team-a' from Zitadel a custom project admin role
    p, proj:infra-services:team-a-admin, applications, *, infra-services/*, allow
    g, team-a, proj:infra-services:team-a-admin
```

---

## AC-6 to AC-12 are covered in subsequent sections as needed. This provides a deep reference for the most critical areas first. The pattern continues for Secrets, Health Checks, etc.

---

## AC-9. Secrets Integration (SOPS + OpenBao)

### Helix Stax Recommendation: External Secrets Operator (ESO)
This approach is superior as it fully decouples secret management from GitOps. ArgoCD's job is to sync the `ExternalSecret` manifest; ESO's job is to fetch the secret data from OpenBao and create a native Kubernetes `Secret`.

**Workflow:**
1.  A secret is created in OpenBao (e.g., `cubbyhole/data/zitadel-oidc`).
2.  A developer creates an `ExternalSecret` manifest pointing to that OpenBao path. This manifest is **not** sensitive.
3.  The `ExternalSecret` manifest is committed to the `helix-stax-infrastructure` git repo.
4.  ArgoCD syncs the `ExternalSecret` resource to the K3s cluster.
5.  The External Secrets Operator, running in the cluster, sees the new `ExternalSecret` resource.
6.  ESO authenticates to OpenBao, fetches the secret data, and creates/updates a standard Kubernetes `Secret` (e.g., `argocd-secret`) in the specified namespace.
7.  Pods (like `argocd-server`) can now mount this native `Secret` as normal.

### Alternative: ArgoCD Vault Plugin (AVP)
AVP is an older pattern where the `argocd-repo-server` is patched to decrypt manifests on the fly.
-   **Architecture:** It runs as an init-container or sidecar on `argocd-repo-server`. It intercepts manifests annotated for replacement and injects secrets from a vault before passing the final YAML to ArgoCD for diffing.
-   **Drawbacks:** Tightly couples ArgoCD to the vault. Can be slow. Harder to debug as the "real" manifest only exists ephemerally inside the repo-server. Less portable.

---

## AC-11. Devtron Co-existence Architecture

- **Standalone ArgoCD (Namespace: `argocd`)**
    - **Purpose**: Manages cluster-wide infrastructure and platform services.
    - **Source of Truth**: `https://github.com/KeemWilliams/helix-stax-infrastructure.git`
    - **UI**: `argocd.helixstax.net`
    - **Apps Managed**: `traefik`, `cert-manager`, `prometheus`, `devtron`, `zitadel`, `harbor`, etc.
    - **Debugging**: `argocd ... --grpc-web` commands work directly.

- **Devtron's Internal ArgoCD (Namespace: `devtroncd`)**
    - **Purpose**: Manages application workloads deployed via Devtron CI/CD pipelines.
    - **Source of Truth**: A git repo managed by Devtron (if in GitOps mode) or Devtron's internal state (if in Helm mode).
    - **UI**: Accessed through the Devtron dashboard (`devtron.helixstax.net`).
    - **Apps Managed**: `my-web-app-prod`, `my-api-staging`, etc.
    - **Debugging**: Must port-forward to its service to use the `argocd` CLI.
      ```bash
      # Port-forward to Devtron's ArgoCD server on a different local port
      kubectl port-forward svc/devtron-argocd-server -n devtroncd 8081:80
      
      # Now use argocd CLI against localhost:8081 (assumes local admin login)
      argocd app list --server localhost:8081 --insecure
      ```

**The Golden Rule**: Never create an `Application` in the `argocd` namespace that targets a namespace managed by a Devtron Environment. This will cause fighting between the two ArgoCD instances.

```

### ## examples.md Content
Copy-paste-ready configurations and runbooks for the Helix Stax environment.

```markdown
# ArgoCD Examples for Helix Stax

## 1. Login and Basic CLI Usage Script

This script shows how to log in and perform common checks using the required `--grpc-web` flag.

```bash
#!/bin/bash

# --- Configuration ---
ARGOCD_SERVER="argocd.helixstax.net"
# For automation, get this token from the ArgoCD UI or an API call
# ARGOCD_TOKEN="<your-token>" 

# --- Interactive Login (for humans) ---
echo "Attempting interactive login to $ARGOCD_SERVER..."
argocd login $ARGOCD_SERVER --grpc-web
if [ $? -ne 0 ]; then
  echo "Login failed. Exiting."
  exit 1
fi
echo "Login successful."

# --- Common Operations ---
echo -e "\n--- Listing all infrastructure applications ---"
argocd app list --grpc-web

echo -e "\n--- Checking status of 'traefik' application ---"
argocd app get traefik --grpc-web

echo -e "\n--- Checking for drift in 'cert-manager' application ---"
argocd app diff cert-manager --grpc-web

# Example of using a token for a script
# if [[ -n "$ARGOCD_TOKEN" ]]; then
#   echo -e "\n--- Listing apps with auth token ---"
#   argocd app list --grpc-web --server $ARGOCD_SERVER --auth-token $ARGOCD_TOKEN
# fi
```

## 2. Infrastructure Application Manifest (`traefik`)

This `Application` manifest deploys Traefik, our ingress controller. It lives in `helix-stax-infrastructure/k8s/infra/argo-apps/traefik.yaml`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    # Subscribe to failure notifications on Rocket.Chat
    notifications.argoproj.io/subscribe.on-sync-failed.rocketchat: 'infra-alerts'
    notifications.argoproj.io/subscribe.on-health-degraded.rocketchat: 'infra-alerts'
spec:
  project: default
  source:
    repoURL: 'https://github.com/KeemWilliams/helix-stax-infrastructure.git'
    path: k8s/infra/traefik # Path to the Helm chart and values
    targetRevision: main
    helm:
      valueFiles:
        - values-helixstax.yaml # Our specific overrides
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: traefik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true # Recommended for Traefik CRDs
    retry:
      limit: 3
      backoff:
        duration: 15s
```

## 3. Zitadel OIDC Integration Configuration

These are the manifests to apply to configure SSO with Zitadel.

**`argocd-cm-patch-oidc.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # URL for the Argo CD web UI
  url: https://argocd.helixstax.net

  # Dex configuration for Zitadel
  dex.config: |
    connectors:
    - type: oidc
      id: zitadel
      name: Zitadel SSO
      config:
        issuer: https://zitadel.helixstax.net
        clientID: <YOUR_ARGOCD_CLIENT_ID_FROM_ZITADEL>
        # This references the secret key stored in argocd-secret
        clientSecret: $dex.zitadel.clientSecret
        redirectURI: https://argocd.helixstax.net/api/dex/callback
        scopes:
        - openid
        - profile
        - email
        # This custom scope in Zitadel must be configured to return roles
        - "urn:zitadel:iam:org:project:roles"
        claimMapping:
          # Map the role claim from Zitadel to Dex's groups claim
          groups: "urn:zitadel:iam:org:project:roles"
```

**`argocd-rbac-cm-patch.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # policy.default: 'role:readonly' # Uncomment to make readonly the default for all users

  policy.csv: |
    # Grant the built-in 'admin' role to any user in the 'argocd-admins' group from Zitadel
    g, argocd-admins, role:admin

    # Grant the built-in 'readonly' role to any user in the 'argocd-viewers' group from Zitadel
    g, argocd-viewers, role:readonly
```

## 4. Custom Health Check for CloudNativePG Cluster

Add this to the `argocd-cm` ConfigMap to give ArgoCD insight into the health of our PostgreSQL clusters.

```yaml
data:
  # resource.customizations.health.postgresql.cnpg.io_Cluster
  resource.customizations.health.cnpg.io/Cluster: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.readyInstances == obj.spec.instances then
        hs.status = "Healthy"
        hs.message = "All instances are ready"
      else
        hs.status = "Progressing"
        hs.message = string.format("%d/%d instances ready", obj.status.readyInstances, obj.spec.instances)
      end
      if obj.status.phase == "Cluster in creation" then
        hs.status = "Progressing"
        hs.message = "Cluster in creation"
      end
      if obj.status.phase == "Upgrade failed" or obj.status.phase == "Failed" then
        hs.status = "Degraded"
        hs.message = "Cluster has failed"
      end
    else
      hs.status = "Progressing"
      hs.message = "No status field found"
    end
    return hs
```

## 5. External Secret for Harbor OCI Credentials (ESO)

This manifest, when synced by ArgoCD, will instruct ESO to fetch Harbor credentials from OpenBao and create a Kubernetes secret that ArgoCD can use to access OCI charts.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-harbor-oci-creds
  namespace: argocd # Secret must be in the same namespace as ArgoCD
spec:
  # The secret store points to our OpenBao instance
  secretStoreRef:
    name: openbao-backend
    kind: ClusterSecretStore
  
  target:
    # This is the name of the Kubernetes 'Secret' that will be created
    name: harbor-oci-creds
    # Template to format the secret correctly for ArgoCD OCI usage
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "harbor.helixstax.net": {
                "username": "{{ .username }}",
                "password": "{{ .password }}",
                "auth": "{{ .auth }}"
              }
            }
          }

  data:
  - secretKey: username
    remoteRef:
      key: infra/data/harbor-robot-argocd
      property: username
  - secretKey: password
    remoteRef:
      key: infra/data/harbor-robot-argocd
      property: token
  - secretKey: auth
    remoteRef:
      key: infra/data/harbor-robot-argocd
      property: auth # Pre-computed base64(user:pass) in Bao
```

## 6. Debugging Co-existence: Port-Forwarding to Both ArgoCDs

Run these two commands in separate terminals to access both the standalone and Devtron's internal ArgoCD UIs/APIs locally for debugging.

**Terminal 1: Standalone ArgoCD (Infra)**
```bash
echo "Forwarding Standalone ArgoCD (infra) to http://localhost:8080"
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

**Terminal 2: Devtron's ArgoCD (Apps)**
```bash
echo "Forwarding Devtron's ArgoCD (apps) to http://localhost:8081"
kubectl port-forward svc/devtron-argocd-server -n devtroncd 8081:80
```
Now you can:
-   Visit `http://localhost:8080` for the main ArgoCD UI.
-   Visit `http://localhost:8081` for Devtron's internal ArgoCD UI.
-   Use `argocd login localhost:8080 --insecure --username admin --password <pwd>`
-   Use `argocd login localhost:8081 --insecure --username admin --password <pwd>`

This is invaluable for diagnosing why a Devtron deployment is stuck or if there's a conflict between the two instances.

```
---

NOTE: I will now generate the content for Devtron, following the same three-part structure.

---
# Devtron

### ## SKILL.md Content
Core reference for daily AI agent operations. Concise and actionable.

```markdown
# Devtron Quick Reference (for AI Agents)

## Core Purpose
Devtron is the application CI/CD platform for Helix Stax. It builds container images from developer source code, pushes them to Harbor, and deploys them to K3s environments (namespaces). **It manages application workloads ONLY. Standalone ArgoCD manages the infrastructure.**

## API Essentials (Helix Stax Setup)
Devtron is primarily automated via its REST API. Generate a token in the Devtron UI: `Global Configurations -> API tokens -> Generate`.

```bash
# --- Configuration ---
DEVTRON_URL="https://devtron.helixstax.net"
# This is a long-lived token generated from the Devtron UI
DEVTRON_TOKEN="<paste-devtron-api-token-here>"
APP_ID=123 # Get from Devtron URL when viewing an app
ENV_ID=1 # Get from Devtron URL when viewing an environment

# --- Trigger a CI build for a specific commit ---
# 1. Get the CI pipeline ID
PIPELINE_ID=$(curl -s -X GET "$DEVTRON_URL/orchestrator/app/ci-pipeline/v1/appid/$APP_ID" \
  -H "token: $DEVTRON_TOKEN" | jq '.result[] | select(.name=="my-app-ci") | .id')

# 2. Find the commit hash you want to build
COMMIT_HASH="a1b2c3d4"

# 3. Trigger the build
curl -s -X POST "$DEVTRON_URL/orchestrator/app/v1/ci/pipeline/trigger" \
  -H "token: $DEVTRON_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pipelineId": '$PIPELINE_ID',
    "ciBuildMaterial": [
      {
        "id": <material-id>, # Get from CI pipeline config
        "commitHash": "'$COMMIT_HASH'"
      }
    ],
    "invalidation": false
  }'

# --- Deploy an image to an environment ---
# 1. Get the artifact (image) ID
ARTIFACT_ID=$(curl -s -X GET "$DEVTRON_URL/orchestrator/app/v1/ci/workflow/$WORKFLOW_ID" \
  -H "token: $DEVTRON_TOKEN" | jq '.result.ci_artifacts[0].id') # Find the right artifact

# 2. Trigger the deployment
curl -s -X POST "$DEVTRON_URL/orchestrator/app/v1/cd/pipeline/trigger" \
  -H "token: $DEVTRON_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
      "pipelineId": <cd-pipeline-id>,
      "appId": '$APP_ID',
      "ci_artifact_id": '$ARTIFACT_ID',
      "cd_workflow_id": <cd-workflow-id>,
      "cd_workflow_runner_id": 0
  }'
```

## Troubleshooting Decision Tree

| Symptom                                 | Likely Cause                                                     | First Action                                                               |
| --------------------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------- |
| CI Build fails                          | Code issue (tests fail), Dockerfile error, insufficient resources. | Check `Build History` tab in Devtron UI. View logs. `kubectl logs <pod> -n devtron-ci` on the build pod. |
| CI Build pod is `Pending`               | Cluster out of CPU/Memory. PVC can't bind.                       | `kubectl describe pod <pod-name> -n devtron-ci`. Check events. Increase cluster resources. |
| CD Deployment is `Progressing` or `Degraded` | Application is CrashLooping, health check fails, image pull error. | 1. Go to `App Details` in Devtron. Check application status. 2. `kubectl get pods -n <app-namespace>`. 3. `kubectl logs <failing-pod> -n <app-namespace>`. |
| Image pull error (`ImagePullBackOff`)   | `imagePullSecret` missing/incorrect for Harbor.                  | Verify `imagePullSecret` is in the app namespace and CD pipeline config. Check Harbor robot account permissions. |
| Devtron UI is not loading (`502`/`504`) | A core Devtron pod is down (e.g., `devtron-orchestrator`).         | `kubectl get pods -n devtroncd`. Check logs for any pods that are not `Running` or have high restart counts. |

## ArgoCD Co-existence Rule
- Devtron uses its own ArgoCD instance in the `devtroncd` namespace to manage application deployments.
- **Do not create standalone ArgoCD `Applications` that manage the same resources as Devtron.**
- If a Devtron deployment is stuck, use this command to debug its internal ArgoCD state:
  ```bash
  # Port-forward to Devtron's internal ArgoCD
  kubectl port-forward svc/devtron-argocd-server -n devtroncd 8081:80
  # Login with the admin password from devtron-secrets
  argocd login localhost:8081 --insecure --username admin --password $(kubectl -n devtroncd get secret devtron-secret -o jsonpath='{.data.ACD_PASSWORD}' | base64 -d)
  # Check the application status
  argocd app get <devtron-app-name> --server localhost:8081 --insecure
  ```

```

### ## reference.md Content
Deep specifications, advanced patterns, and full configuration details.

```markdown
# Devtron Deep Reference

## DV-1. API Reference

Devtron's functionality is exposed via a REST API, which the UI uses. Authentication is done via a bearer token.

- **Authentication**: Generate a token from `Global Configurations -> API tokens`. Pass it in the `token` header.
- **Base URL**: `https://devtron.helixstax.net/orchestrator`

### Key Endpoints
- **List Applications**: `GET /api/v1/app`
- **List CI Pipelines**: `GET /app/ci-pipeline/v1/appid/{appId}`
- **Trigger CI Build**: `POST /app/v1/ci/pipeline/trigger`
    - Payload requires `pipelineId` and `ciBuildMaterial` with `commitHash`.
- **List CD Pipelines**: `GET /app/v1/cd-pipeline/{appId}`
- **Trigger CD Deployment**: `POST /app/v1/cd/pipeline/trigger`
    - Payload requires `pipelineId`, `appId`, and `ci_artifact_id`.
- **Get Build/Deploy Status**:
    - CI: `GET /app/v1/ci/workflow/{appId}`
    - CD: `GET /app/v1/cd/workflow/{appId}`

---

## DV-2. CI Pipeline Configuration

A CI Pipeline defines how to build an artifact (container image) from a Git repository.

- **Source Config**: Git material (repo, branch). `Match tags` allows regex for triggering on specific tag patterns (e.g., `v*.*.*`).
- **Build Strategies**:
    - **Kaniko (Recommended for K3s)**: Builds container images in an unprivileged pod inside the cluster. Does not require a Docker daemon.
    - **Docker Build**: Requires a Docker daemon, either on the node or via Docker-in-Docker. More complex and less secure in a shared cluster.
    - **Buildpack**: Cloud Native Buildpacks auto-detect the language and build an image without a Dockerfile. Good for standard languages (Go, Java, Python).
- **Build Arguments (`ARG`)**: Passed in the UI under "Build Arguments".
- **Pre-CI & Post-CI Tasks**: Scripts that run before or after the main build stage.
    - **Pre-CI**: Use for linting, running unit tests (`go test ./...`), dependency checks. If the script fails, the build stops.
    - **Post-CI**: Use for image scanning (Trivy), generating SBOMs, sending notifications.
- **Build Caching (Kaniko)**: Significantly speeds up builds.
    - **Mechanism**: Kaniko can cache layers to a remote container registry.
    - **Configuration**: In the CI pipeline, enable "Enable layer caching". Devtron will use the app's target registry (Harbor) for the cache.
- **Webhook Triggers**: Devtron generates a webhook URL with a unique secret.
    - **GitHub Setup**: In the Git repo settings -> Webhooks, add a new webhook.
    - **Payload URL**: Paste the URL from Devtron.
    - **Content Type**: `application/json`.
    - **Events**: Select `push` and/or `pull_request`.

---

## DV-3. CD Pipeline Configuration

A CD Pipeline defines how to deploy a built artifact to an environment.

- **Deployment Strategy**:
    - **Rolling (Default)**: Replaces old pods with new ones gradually. Standard, safe default.
    - **Blue-Green**: Deploys the new version alongside the old one. A service switch flips traffic when ready. Requires more resources but offers instant rollback.
    - **Canary**: Deploys the new version to a small subset of users, then gradually rolls it out. Complex, requires an Ingress controller and metrics integration (e.g., with Flagger).
- **Deployment Template (Devtron's Helm Chart)**: Devtron wraps application deployments in its own Helm chart. The "Deployment Template" is a GUI/YAML editor for this chart's `values.yaml`.
    - Key fields: `image.tag`, `replicaCount`, `resources`, `ingress`, `envVars`, `configMaps`, `secrets`.
- **Environment Promotion**: A CD pipeline can be configured to trigger automatically on successful build, or require manual promotion.
    - **Approval Gates**: In the pipeline editor, enable "Authorize deployment". You can then specify which users/groups must approve the deployment before it proceeds.
- **Pre-Deployment & Post-Deployment Tasks**:
    - **Pre-Deployment**: Use for running database migrations (e.g., a Job that runs `alembic upgrade head`) or pre-flight checks.
    - **Post-Deployment**: Use for running smoke tests, integration tests, or triggering external systems.
- **Rollback**:
    - **UI**: Go to `App Details -> Deployment History`, select a previous successful deployment, and click `Redeploy`.
    - **API**: Trigger a deployment using the `ci_artifact_id` of a previous build.

---

## DV-5. Harbor Integration

- **Global Configuration**: Add Harbor in `Global Configurations -> Container Registries`.
    - **Registry URL**: `harbor.helixstax.net`
    - **Authentication**: Use a **Robot Account** from Harbor with push/pull permissions for the relevant projects. This is more secure than using user credentials.
- **Image Pushing**: Devtron automatically tags and pushes images. The convention is:
  `harbor.helixstax.net/<harbor-project>/<app-name>:<tag>`
- **Image Tagging**: The tag strategy is defined in the CI pipeline. Common choices:
    - **Build Number**: `1.2.3-{build-number}`
    - **Commit SHA**: `{git-commit-hash-short}`
- **Vulnerability Scanning**: Both Devtron and Harbor use Trivy.
    - **Devtron (Post-CI)**: Scans the image *before* pushing to the final destination. Can fail the build on critical vulnerabilities.
    - **Harbor (On Push)**: Scans the image *after* it's stored. Can prevent images from being pulled via policy.
    - **Recommendation**: Use both. Devtron's scan provides fast feedback to developers. Harbor's scan provides a compliance gate and continuous monitoring.
- **`imagePullSecrets`**: Devtron automatically manages this. When you deploy an app to an environment, it creates a secret in that app's namespace containing the Harbor credentials and links it to the service account.

---

## DV-6. GitOps Mode vs Helm Mode

- **Helm Mode (Default)**: Devtron uses Helm to directly deploy to the cluster. State is managed by Helm's secrets and Devtron's database. Simple, but not fully GitOps.
- **GitOps Mode**: Devtron commits application manifest changes (the rendered Helm chart `values.yaml`) to a dedicated Git repository. Devtron's internal ArgoCD instance then syncs from this repository.
- **Helix Stax Recommendation**: **Use GitOps Mode.**
    - **Reason**: It provides a full audit trail of every application deployment in Git. It aligns with our infrastructure-as-code philosophy. It allows for manual review of deployment changes via Pull Requests if desired. It makes disaster recovery easier, as the application state is fully declared in Git.
- **Migration**: Devtron provides a UI-based flow to migrate an application from Helm mode to GitOps mode. It will commit the current state to the configured Git repository.

---

## DV-7. RBAC and SSO with Zitadel

- **Configuration Location**: `Global Configurations -> SSO Login Services -> Add SSO Provider`.
- **Zitadel OIDC Client Setup**:
    - **Application Type**: Web
    - **Authentication Method**: Basic (Client Secret)
    - **Redirect URIs**: `https://devtron.helixstax.net/api/v1/sso/login/callback`
- **Devtron SSO Config**:
    - **URL**: `https://zitadel.helixstax.net`
    - **Client ID/Secret**: From the Zitadel application.
    - **Scopes**: `openid`, `profile`, `email` and the custom scope for groups/roles.
- **Group/Role Mapping**: Devtron allows you to map claims from the OIDC token to its internal permission groups.
    - In `User Access -> Permission Groups`, create a group (e.g., "App-Developers").
    - In the group settings, under "SSO Group Claim", add the name of the group/role as sent by Zitadel.
- **Devtron Permission Model**:
    - **Super Admin**: Full control over Devtron.
    - **Permission Groups (Project/App/Environment level)**:
        - `Manager`: Can edit pipelines and manage access.
        - `Trigger`: Can run CI/CD pipelines.
        - `View`: Read-only access.

**Crucial Distinction**: Devtron's SSO config is **completely separate** from the standalone ArgoCD's `argocd-cm` config. They are two different OIDC clients in Zitadel.

```

### ## examples.md Content
Copy-paste-ready configurations and runbooks for the Helix Stax environment.

```markdown
# Devtron Examples for Helix Stax

## 1. API Script: Trigger CI and Wait for Completion

This script triggers a CI build for a specific commit and polls until the build is complete, reporting the final status.

```bash
#!/bin/bash
set -eo pipefail

# --- Configuration ---
DEVTRON_URL="https://devtron.helixstax.net"
DEVTRON_TOKEN="<your-devtron-token>"
APP_NAME="my-awesome-app"
CI_PIPELINE_NAME="my-awesome-app-ci"
COMMIT_TO_BUILD="main" # or a specific commit hash

# --- Get IDs ---
echo "Fetching IDs from Devtron..."
APP_ID=$(curl -s -X GET "$DEVTRON_URL/orchestrator/api/v1/app" -H "token: $DEVTRON_TOKEN" | jq -r ".result.apps[] | select(.appName==\"$APP_NAME\") | .id")
PIPELINE_ID=$(curl -s -X GET "$DEVTRON_URL/orchestrator/app/ci-pipeline/v1/appid/$APP_ID" -H "token: $DEVTRON_TOKEN" | jq -r ".result[] | select(.name==\"$CI_PIPELINE_NAME\") | .id")
MATERIAL_ID=$(curl -s -X GET "$DEVTRON_URL/orchestrator/app/ci-pipeline/v1/appid/$APP_ID" -H "token: $DEVTRON_TOKEN" | jq -r ".result[] | select(.id==$PIPELINE_ID) | .ciMaterial[0].id")

# --- Trigger Build ---
echo "Triggering build for commit $COMMIT_TO_BUILD on pipeline $CI_PIPELINE_NAME..."
TRIGGER_RESP=$(curl -s -X POST "$DEVTRON_URL/orchestrator/app/v1/ci/pipeline/trigger" \
  -H "token: $DEVTRON_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "pipelineId": '$PIPELINE_ID',
    "ciBuildMaterial": [{ "id": '$MATERIAL_ID', "commitHash": "'$COMMIT_TO_BUILD'" }],
    "invalidation": false
  }')
WORKFLOW_RUNNER_ID=$(echo $TRIGGER_RESP | jq -r '.result.id')
echo "Build triggered. Workflow Runner ID: $WORKFLOW_RUNNER_ID"

# --- Poll for Status ---
while true; do
  STATUS_RESP=$(curl -s -X GET "$DEVTRON_URL/orchestrator/app/v1/ci/workflow/runner/$WORKFLOW_RUNNER_ID" -H "token: $DEVTRON_TOKEN")
  STATUS=$(echo $STATUS_RESP | jq -r '.result.status')
  
  echo "Current build status: $STATUS"
  
  if [[ "$STATUS" == "Succeeded" || "$STATUS" == "Failed" || "$STATUS" == "Aborted" ]]; then
    echo "Build finished with status: $STATUS"
    exit 0
  fi
  
  sleep 10
done
```

## 2. CI Pipeline Configuration for a Go Application (Kaniko)

This is a typical configuration for building a Go application and running tests before the Kaniko build.

**In Devtron UI -> CI Pipeline -> Pre-build Stage:**
- **Script:**
  ```bash
  echo "--- Running Unit Tests ---"
  go test -v ./...
  if [ $? -ne 0 ]; then
    echo "Unit tests failed!"
    exit 1
  fi
  echo "--- Vetting Code ---"
  go vet ./...
  ```

**In Devtron UI -> CI Pipeline -> Build Stage:**
- **Build Material**: `github.com/KeemWilliams/my-awesome-app`, branch `main`
- **Deployment Template**: Dockerfile
- **Dockerfile Path**: `Dockerfile` (in repo root)
- **Container Registry**: `harbor.helixstax.net` (selected from dropdown)
- **Docker Repository**: `dev-apps/my-awesome-app`
- **Enable Caching**: `[x]` Enable layer caching

**`Dockerfile` Example:**
```Dockerfile
# --- Build Stage ---
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o aiapp .

# --- Final Stage ---
FROM alpine:latest
WORKDIR /root/
# Copy the binary from the builder stage
COPY --from=builder /app/aiapp .
# Expose port (if it's a web service)
EXPOSE 8080
# Run the binary
CMD ["./aiapp"]
```

## 3. Configuration for Harbor Container Registry

In `Global Configurations -> Container Registries -> + Add Registry`:

- **Registry Name**: `helix-stax-harbor`
- **Registry URL**: `harbor.helixstax.net`
- **Registry Type**: `docker`
- **Username**: `<harbor-robot-account-username>` (e.g., `robot$devtron`)
- **Password/Token**: `<harbor-robot-account-token>`
- **Connection**: `Allow connection`

## 4. Configuration for Zitadel SSO

In `Global Configurations -> SSO Login Services -> + Add SSO Provider`:

- **Name**: `Zitadel`
- **Logo URL**: (Optional)
- **URL**: `https://zitadel.helixstax.net`
- **Configuration**:
    - `[x]` **Use GITLAB/GOOGLE/GITHUB/MICROSOFT/OIDC specific keys**
    - **Client ID**: `<YOUR_DEVTRON_CLIENT_ID_FROM_ZITADEL>`
    - **Client Secret**: `<YOUR_DEVTRON_CLIENT_SECRET_FROM_ZITADEL>`
    - **User Info Key for Groups**: `urn:zitadel:iam:org:project:roles` (or your custom claim name)

## 5. Troubleshooting Runbook: App Stuck in "Progressing"

**Symptom**: A deployment in Devtron UI has been `Progressing` for over 5 minutes. The application status light is yellow.

**Step 1: Check Devtron's Application View**
- In Devtron, go to `App Details`. The UI will show which resource is failing its health check (e.g., a `Deployment` not having its replicas ready). Click on the resource to see K8s events. Often this shows `CrashLoopBackOff` or `ImagePullBackOff`.

**Step 2: Check Pod Logs**
- If it's a `CrashLoopBackOff`, the application code is failing.
- Get the pod name from the Devtron UI and the namespace from the Environment config.
  ```bash
  NAMESPACE="my-app-prod"
  POD_NAME="my-awesome-app-deployment-5f7d...-xyz12"
  kubectl logs $POD_NAME -n $NAMESPACE
  
  # If it restarted, check the previous container's logs
  kubectl logs $POD_NAME -n $NAMESPACE --previous
  ```

**Step 3: Check Image Pull Secret**
- If the event is `ImagePullBackOff`, the node can't pull the image from Harbor.
  ```bash
  NAMESPACE="my-app-prod"
  # Check if the secret exists in the namespace
  kubectl get secret devtron-harbor.helixstax.net -n $NAMESPACE 
  
  # Describe the
