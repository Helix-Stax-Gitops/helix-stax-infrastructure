Of course. This is a perfect use case for a detailed, structured research document. AI agents thrive on precise, unambiguous, and comprehensive information. Here is the deep research on the Devtron CI/CD Platform, tailored specifically for Helix Stax's environment.

***

### ## SKILL.md Content

```markdown
# SKILL: Devtron on K3s Quick Reference

## 1. CLI Commands (kubectl & devtron-cli)

### Installation & Management (Helm)
# Add Devtron Helm repo
helm repo add devtron https://helm.devtron.ai

# Generate a values file for your K3s setup (see examples.md for the full file)
helm show values devtron/devtron > values.yaml

# Install Devtron
helm install devtron devtron/devtron -n devtroncd --create-namespace -f values.yaml

# Upgrade Devtron
helm upgrade devtron devtron/devtron -n devtroncd -f values.yaml

# Uninstall Devtron
helm uninstall devtron -n devtroncd
kubectl delete pvc -n devtroncd -l release=devtron

### Post-Install
# Get initial admin password
kubectl -n devtroncd get secret devtron-secret -o jsonpath='{.data.ACD_PASSWORD}' | base64 -d

# Port-forward to access dashboard if tunnel isn't ready
kubectl -n devtroncd port-forward service/devtron-service 8080:80

### Devtron CLI (devtron-cli)
# Installation
curl -O https://github.com/devtron-labs/devtron-cli/releases/latest/download/devtron-cli-linux-amd64.tar.gz
tar -xvf devtron-cli-linux-amd64.tar.gz
sudo mv devtron-cli /usr/local/bin/

# Configuration (first-time use)
devtron-cli config set-server https://devtron.helixstax.net
# Generate a token from Devtron UI: User Icon -> API Tokens -> Generate Token
devtron-cli config set-token <YOUR_GENERATED_TOKEN>

# Basic CLI Usage
devtron-cli app list
devtron-cli app get --name <app-name>
devtron-cli trigger --app-id <app-id> --pipeline-id <pipeline-id> --cd-stage <stage-name>
devtron-cli git-account list

## 2. Common Configuration Patterns

### External PostgreSQL (CloudNativePG)
- Your `values.yaml` must disable the built-in PostgreSQL.
- Create a Kubernetes secret manually with the connection details from CloudNativePG.
- Point Devtron's `configs.externalSecret` to this secret.
- **Secret Keys:** `PG_ADDR`, `PG_DATABASE`, `PG_USER`, `PG_PASSWORD`.

### OIDC SSO with Zitadel
- **Zitadel App Redirect URI:** `https://devtron.helixstax.net/orchestrator/api/v1/user/callback`
- **Devtron Config:**
  - URL/Mount Path: `/`
  - Scopes: `openid profile email`
  - Get Client ID/Secret and Issuer URL from Zitadel.

### Cloudflare Tunnel for Ingress
- Devtron's Helm `ingress.enabled` should be `false`.
- The Tunnel points directly to the Kubernetes Service: `devtron-service.devtroncd.svc.cluster.local`.
- For applications deployed BY Devtron, you need an `IngressRoute` or `Ingress` object. Devtron's Helm chart templates can create these.

### CI Pipeline for Kaniko (K3s)
- No Docker daemon needed.
- In Build Pipeline > Pre-build stage, select "Custom script".
- In Build stage:
  - Docker build configuration:
    - Use "Build on platform" with Kaniko.
    - Set Dockerfile Path: `./Dockerfile`
    - Target platform: `linux/amd64`
- Enable "Scan for vulnerabilities". Use `Grype`.

## 3. API Integration (n8n, Scripts)

### API Token
- Generate from Devtron UI: Top-right user icon > API Tokens > Generate new token.
- Tokens do not expire by default. Set an expiration for better security.

### API Request Structure
- **Base URL:** `https://devtron.helixstax.net/orchestrator`
- **Header:** `token: <YOUR_GENERATED_TOKEN>`
- **Example: Trigger a CI Pipeline**
  - **Endpoint:** `POST /app/ci-pipeline/trigger`
  - **Body (JSON):**
    ```json
    {
      "pipelineId": 123,
      "appId": 45,
      "ciPipelineMaterial": [
        {
          "id": 67,
          "gitMaterialId": 8,
          "type": "SOURCE_TYPE_BRANCH_FIXED",
          "value": "main",
          "lastFetchTime": ""
        }
      ],
      "invalidationCache": false
    }
    ```
    (IDs can be found in the UI URL or via `GET` API calls).

## 4. Troubleshooting Checklist

1.  **Pods Not Starting (devtroncd namespace):**
    - `kubectl get pods -n devtroncd -o wide`
    - `kubectl describe pod <pod-name> -n devtroncd`
    - Check for `OOMKilled` (increase resource limits), `ImagePullBackOff` (registry issue), `CrashLoopBackOff` (config/DB issue).
    - `kubectl logs <pod-name> -n devtroncd`

2.  **Database Connection Failed:**
    - Double-check the secret holding the PG credentials. Ensure keys match (`PG_ADDR`, `PG_USER`, etc.).
    - `kubectl exec -it <any-devtron-pod> -n devtroncd -- /bin/sh` and try to `ping` or `nc` the PostgreSQL service host and port.

3.  **UI 5xx Errors / Login Issues:**
    - Check logs of `devtron-service` pod.
    - OIDC Issues: Verify the callback URL in Zitadel is exactly correct. Check for clock skew between servers.
    - Check logs of `casbin` pod for permission issues.

4.  **CI Build Failures:**
    - **Kaniko:** "error checking push permissions": Verify the container registry credentials in `Global Configurations -> Container Registries`.
    - **Kaniko:** "Dockerfile not found": Check the "Dockerfile Path" setting and ensure it's relative to the git repository root.
    - **Resource limits:** Builds can be memory-intensive. Check if the CI runner pod is being OOMKilled.

5.  **Cloudflare Tunnel Issues (502/503):**
    - Ensure the `cloudflared` pod/deployment is running.
    - Verify the Service name and namespace in the tunnel configuration are correct: `service: https://devtron-service.devtroncd.svc.cluster.local:80`. Note `https` in the service URL, as Cloudflare recommends it for service-to-service encryption within the cluster.
```

### ## reference.md Content

```markdown
# Deep Research: Devtron Full Configuration Guide for Helix Stax

This document provides a comprehensive guide for installing, configuring, and operating the Devtron CI/CD platform on the Helix Stax K3s cluster. It is designed to be a definitive reference for AI agents and human operators.

---

## 1. Installation on K3s

### 1.1. Prerequisites

- **Cluster:** K3s v1.32.3+ on AlmaLinux 9.7.
- **Database:** An existing PostgreSQL database managed by CloudNativePG. Devtron requires PostgreSQL 11+. CloudNativePG will meet this.
- **Resources:**
  - **Minimal (CI/CD only):** ~2 vCPU, ~6 GB RAM.
  - **Full (CI/CD + Security):** ~3-4 vCPU, ~8 GB RAM.
  - Your 4vCPU/8GB server is sufficient for a minimal installation alongside your existing monitoring stack, but resource management will be critical. Set requests and limits aggressively.
- **K3s Specifics:**
  - **Container Runtime:** K3s uses `containerd`. This is fully supported by Devtron's default CI builder, Kaniko, which does not require a Docker daemon.
  - **SELinux:** AlmaLinux 9.7 has SELinux in `enforcing` mode. Modern CSI drivers (like the one used by K3s for Longhorn/local-path-provisioner) handle SELinux contexts correctly for PVCs. This is generally not an issue for Devtron's components (like MinIO for caching/logs) but is a point to check if PVCs fail to mount.

### 1.2. Helm Installation Process

The installation uses the official Devtron Helm chart with a custom `values.yaml` file to integrate with your stack.

**Step 1: Add Devtron Helm Repository**

```bash
helm repo add devtron https://helm.devtron.ai
helm repo update
```

**Step 2: Prepare External Database Secret**

Devtron needs to connect to the PostgreSQL instance managed by CloudNativePG. CloudNativePG creates a secret for this purpose. Find the secret and then create a new one in the `devtroncd` namespace with the correct keys Devtron expects.

1.  Assume CloudNativePG created a secret named `cnpg-cluster-pg-superuser` in the `postgres` namespace.
2.  Inspect the secret to find the keys (e.g., `host`, `port`, `dbname`, `user`, `password`).
3.  Create a new secret named `devtron-external-pg-secret` in the `devtroncd` namespace, mapping the values to the keys Devtron expects.

```bash
# Create the target namespace first
kubectl create namespace devtroncd

# Create the secret for Devtron. Replace values accordingly.
# The host should be the service name created by CloudNativePG.
# e.g., cnpg-cluster-pg-rw.postgres.svc.cluster.local
kubectl create secret generic devtron-external-pg-secret -n devtroncd \
  --from-literal=PG_ADDR='<cnpg-service-host>:<cnpg-service-port>' \
  --from-literal=PG_DATABASE='devtron' \
  --from-literal=PG_USER='<db-user>' \
  --from-literal=PG_PASSWORD='<db-password>'
```

**Step 3: Create `values.yaml`**

Create a `values.yaml` file. A complete, annotated example is in `examples.md`. This file tells Devtron:
- To use your external PostgreSQL.
- To **not** create a standard Kubernetes Ingress object.
- To install a minimal set of components to conserve resources.
- To set resource requests/limits for key components.

**Step 4: Install Devtron**

```bash
helm install devtron devtron/devtron \
  -n devtroncd \
  --create-namespace \
  -f values.yaml
```

### 1.3. Post-Installation

**1. Verify Pods:**
Check that all pods in the `devtroncd` namespace are running or completed.
```bash
kubectl get pods -n devtroncd -w
```
It can take 5-10 minutes for all components to initialize.

**2. Retrieve Admin Password:**
The initial administrator password is automatically generated and stored in a secret.
```bash
kubectl -n devtroncd get secret devtron-secret -o jsonpath='{.data.ACD_PASSWORD}' | base64 -d
```
The username is `admin`.

**3. Initial Login:**
Access Devtron at `https://devtron.helixstax.net`. Log in with `admin` and the retrieved password. You will be prompted to change the password on first login.

---

## 2. Global Configurations

Navigate to `Global Configurations` from the left-hand menu after logging in as an administrator.

### 2.1. Host URL
- **Path:** `Global Configurations -> Host URL`
- **Action:** Set the URL to `https://devtron.helixstax.net`.
- **Why:** Devtron uses this URL to generate webhooks for Git providers, create callback URLs for OIDC, and form other external links. This must be the public-facing URL.

### 2.2. User Management / SSO (Zitadel)
- **Path:** `Global Configurations -> User Management & SSO -> Add SSO Login`
- **Goal:** Integrate with `zitadel.helixstax.net`.

**In Zitadel:**
1.  Navigate to your Project.
2.  Add a new Application.
3.  Select **OIDC**.
4.  **Redirect URI:** Enter `https://devtron.helixstax.net/orchestrator/api/v1/user/callback`. This is critical.
5.  Save the application. Note the **Client ID**, **Client Secret**, and the **Issuer URL** from the OIDC configuration page.

**In Devtron:**
1.  Fill out the "Add SSO Login" form.
2.  **Name:** `Zitadel`
3.  **URL/Mount Path:** `/` (for the standard issuer URL)
4.  **Scopes:** `openid profile email`
5.  **Issuer:** Paste the Issuer URL from Zitadel (e.g., `https://zitadel.helixstax.net`).
6.  **Client ID:** Paste the Client ID from Zitadel.
7.  **Client Secret:** Paste the Client Secret from Zitadel.
8.  Save. The Zitadel login button will now appear on the Devtron login page.

### 2.3. Git Accounts
- **Path:** `Global Configurations -> Git Accounts`
- **Goal:** Connect to your GitHub account (`KeemWilliams`). Using a GitHub App is more secure and flexible than a Personal Access Token (PAT).

**Step 1: Create a GitHub App**
1. Go to GitHub -> Settings -> Developer settings -> GitHub Apps -> New GitHub App.
2. **GitHub App name:** `HelixStax-Devtron-Integration`
3. **Homepage URL:** `https://devtron.helixstax.net`
4. **Webhook:**
   - Check "Active".
   - **Webhook URL:** `https://devtron.helixstax.net/orchestrator/webhook/git/github`
5. **Permissions:** Grant the following repository permissions:
   - `Administration`: Read-only
   - `Contents`: Read-only
   - `Metadata`: Read-only
   - `Pull requests`: Read & write (for PR status updates)
   - `Commit statuses`: Read & write
6. **Subscribe to events:**
   - `Push`
   - `Pull request`
7. **Where can this GitHub App be installed?** "Any account".
8. Create the app. On the next page, generate a **Client Secret**. Note it down. Also note the **App ID** and **Client ID**.

**Step 2: Connect in Devtron**
1. In Devtron `Git Accounts`, click `Add Git Account`.
2. **Provider:** `GitHub`
3. **Authentication Type:** `GitHub App`
4. Fill in the `App ID`, `Client ID`, `Client Secret`, and `Webhook URL` from the previous step.
5. Save. You will be redirected to GitHub to authorize the app and install it on your desired repositories.

### 2.4. Container/OCI Registry
- **Path:** `Global Configurations -> Container Registries -> Add Registry`
- **Recommendation:** Use GitHub Container Registry (GHCR) as a starting point.
- **URL:** `ghcr.io`
- **Username:** Your GitHub username (`KeemWilliams`).
- **Token:**
  1. Go to GitHub -> Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens.
  2. Generate a new token with `write:packages` and `read:packages` permissions.
- **Registry Type:** `OCI Compliant Registry`.
- Save and set it as the default registry.

### 2.5. Cluster & Environment
- **Path:** `Global Configurations -> Clusters & Environments`
- **Cluster:** Devtron automatically discovers the local K3s cluster and adds it as `default_cluster`. You can edit it to give it a more descriptive name, like `helix-stax-k3s-hetzner`.
- **Environments:** Environments are logical wrappers around namespaces in a cluster.
  - Click `Add Environment`.
  - **Name:** `development`
  - **Cluster:** `helix-stax-k3s-hetzner`
  - **Namespace:** `dev-apps` (Devtron will create it if it doesn't exist).
  - Repeat for `staging` and `production` environments, mapping them to different namespaces (`staging-apps`, `prod-apps`).

### 2.6. Other Global Configurations
- **GitOps:** Already configured by default to use the bundled ArgoCD. No action needed initially.
- **Chart Repositories:** Add public Helm repos you use often (e.g., `bitnami`, `prometheus-community`).
- **Projects:** Structure your work. A good model for consulting is one Devtron Project per client or per internal service suite (e.g., "Client-A-Web", "Internal-Tooling").
- **Notifications:** Add a webhook URL for Rocket.Chat or Alertmanager to receive pipeline status updates.
- **External Links:** Useful for creating shortcuts in the Devtron UI to your Grafana, Zitadel, etc.
- **Catalog Framework, Scoped Variables, Tags:** Advanced features for standardizing apps and managing configuration at scale. Explore these as your application portfolio grows.

---

## 3. Bundled ArgoCD

- **How it Differs:** Devtron uses ArgoCD as its GitOps engine but provides a simplified, opinionated UI on top. Devtron creates ArgoCD `Application` custom resources on your behalf. You can't directly edit these `Application` resources from the Devtron UI, but you can always view them in the ArgoCD UI.
- **Can it manage infra apps?** Yes. Use the "Create Application from Helm Chart" flow. Point Devtron to an existing Helm release (like your monitoring stack). ArgoCD will detect the existing resources and take ownership. **Caution:** It's safer to let Devtron deploy a fresh instance into a new namespace to avoid state conflicts.
- **Devtron UI vs. ArgoCD UI:**
  - **Devtron UI:** For application lifecycle management (creating apps, configuring pipelines, triggering deployments).
  - **ArgoCD UI:** For deep GitOps debugging. Access it via the "Application Details" screen in Devtron. It's excellent for visualizing sync status, diffing live manifest vs. Git, and understanding resource health.
- **Sync Policies:** These are managed in the "Deployment Template" section of a Devtron app. You can enable `auto-sync` (ArgoCD automatically applies changes from Git) and `self-heal` (ArgoCD automatically reverts manual changes made to the cluster).

---

## 4. CI Pipeline Configuration

When you create an application in Devtron, you define its CI/CD pipelines.

1.  **Source Code:** Point to your GitHub App and the repository containing the application code.
2.  **Build Configuration:**
    - **Builder:** Kaniko is the default and a perfect fit for K3s.
    - **Dockerfile Path:** Specify the path to your Dockerfile, e.g., `./Dockerfile`.
    - **Build Cache:** Enable "Enable build cache" to speed up subsequent builds. Devtron will use a PVC to store layers.
    - **Target Platform:** `linux/amd64`.
3.  **Secrets & Environment Variables:**
    - You can inject environment variables directly into the build process.
    - For secrets (like private NPM tokens), use the "Secrets" management feature. Create secrets at the global or application level and mount them into the build pod.
4.  **Security Scanning:**
    - The bundled Trivy version had a past vulnerability; however, Devtron now supports multiple scanners. `Grype` is a solid, open-source alternative.
    - In the CI pipeline editor, add a "Scan for vulnerabilities" post-build stage. You can configure it to block deployments if vulnerabilities of a certain severity are found.
5.  **Triggers:**
    - **Webhook:** In the CI pipeline, set "Trigger automatically on code change". This configures the GitHub webhook.
    - **Manual:** Trigger any pipeline from the Devtron UI.
    - **Scheduled:** Configure a cron-based schedule for nightly builds or other regular jobs.

---

## 5. CD Pipeline Configuration

1.  **Deployment Strategy:**
    - **Rolling (Default):** The standard Kubernetes deployment strategy. New pods replace old ones sequentially.
    - **Blue-Green:** Deploys the new version alongside the old one. Once the new version is confirmed healthy, traffic is switched over instantly. This requires double the resources during deployment.
    - **Canary:** Routes a small percentage of traffic to the new version. If it performs well, traffic is gradually increased. More complex but safest for mission-critical apps.
2.  **Pre/Post Deployment Stages:**
    - Run custom scripts or trigger other jobs before or after a deployment. Useful for database migrations (pre-deploy) or smoke tests (post-deploy).
3.  **Approval Gates:**
    - In the CD pipeline editor, you can insert an "Approval" node. The pipeline will pause at this point until a user with the required permissions manually approves it in the UI. Essential for production deployments.
4.  **Rollback:**
    - ArgoCD's history and rollback feature is exposed in the Devtron UI. You can view previous successful deployments (syncs) and click to redeploy an older, stable version.
5.  **Helm Chart vs. Raw Manifests:**
    - **Helm:** The recommended approach. Devtron provides a default Helm chart that you can customize. You can manage `values.yaml` directly within the Devtron UI, and it will be versioned in Git.
    - **Raw Manifests:** For simple apps, you can use raw Kubernetes manifest files instead of a Helm chart.

---

## 6. Application Integration with Your Stack

- **Managing alongside manual Helm installs:** Devtron/ArgoCD can "adopt" existing resources. If you have an app installed manually with Helm, you can create a Devtron application pointing to the same chart and namespace. ArgoCD will see the resources, mark them as `InSync`, and take over management. **Best Practice:** For critical services like monitoring, it's safer to uninstall the manual version and reinstall it *through* Devtron to ensure the GitOps state is the single source of truth.
- **Devtron + Cloudflare Tunnel + Traefik:**
  - **Devtron Itself:** The Tunnel points directly to the `devtron-service`.
  - **Your Applications:** When Devtron deploys an application (e.g., `my-app` in namespace `dev-apps`), it creates a Service (`my-app-service`). You need an `IngressRoute` to expose this service internally to Traefik. Then, your Cloudflare Tunnel can be configured to point a public hostname to the Traefik service.
  - **Simplified Flow:** You can also have the Cloudflare Tunnel point *directly* to your application's service, bypassing Traefik for that app if you don't need Traefik's advanced middleware.
  - **In Devtron's Chart:** You can add the `IngressRoute` manifest to the Devtron-managed Helm chart for your application, so it gets created automatically on deployment.
- **Resource Sharing (Grafana):** Your standalone Grafana is for infrastructure monitoring. Devtron's bundled Grafana is for application-specific metrics (CPU/Mem usage per app, deployment frequency, etc.). It's best to keep them separate. The Devtron Grafana is scoped and managed as part of the Devtron platform itself. You can link to your main Grafana using Devtron's "External Links" feature.

---

## 7. API and Automation

- **REST API:** Devtron has a rich REST API for automation. The API is served from the `/orchestrator` path.
  - **Authentication:** Generate a token from the UI (`User Profile -> API Tokens`). Include it in requests as a header: `token: <YOUR_TOKEN>`.
  - **Key Endpoints:**
    - `GET /orchestrator/app/list`: List all applications.
    - `POST /orchestrator/app/ci-pipeline/trigger`: Trigger a CI build.
    - `POST /orchestrator/app/cd-pipeline/trigger`: Trigger a CD deployment.
- **CLI Tool (`devtron-cli`):** A command-line wrapper around the REST API. Ideal for scripting.
  - **Installation:** Download from the GitHub releases page.
  - **Configuration:** `devtron-cli config set-server https://devtron.helixstax.net` and `devtron-cli config set-token <YOUR_TOKEN>`.
- **n8n Integration:** Use n8n's "HTTP Request" node to call the Devtron API.
  - **URL:** e.g., `https://devtron.helixstax.net/orchestrator/app/cd-pipeline/trigger`
  - **Authentication:** `Header Auth`.
  - **Name:** `token`
  - **Value:** Your Devtron API token.
  - **Body:** The JSON payload required by the endpoint.

---

## 8. Troubleshooting

- **Common K3s Installation Failures:**
  - **Problem:** Pods in `CrashLoopBackOff`, especially `devtron-service` or `dashboard`.
  - **Cause:** Often a database connection issue.
  - **Solution:** `kubectl logs <pod-name> -n devtroncd`. Double-check the `devtron-external-pg-secret` for typos in the host, user, or password. Ensure the DB is reachable from within the cluster.
- **PostgreSQL Issues:**
  - **Problem:** Devtron reports migration errors on startup.
  - **Cause:** Incorrect permissions for the database user, or an unsupported PostgreSQL version.
  - **Solution:** Ensure the user specified in the secret has `CREATE`, `CONNECT`, and `TEMPORARY` privileges on the `devtron` database.
- **Resource Exhaustion (4vCPU/8GB Server):**
  - **Problem:** Pods are `OOMKilled` or the Kubernetes scheduler fails to place them (`Insufficient memory`).
  - **Solution:**
    1.  Use the minimal installation profile in `values.yaml` (see `examples.md`).
    2.  Set aggressive resource `requests` and `limits` for Devtron components and your monitoring stack.
    3.  Monitor pod resource usage with `kubectl top pods -A`.
    4.  Disable non-essential features like Clair if you're using Grype.
    5.  The `builder-N` pods that run CI jobs can be resource-intensive. Consider setting a `resourceQuota` on the namespace where CI jobs run.

---

## 9. Best Practices for Small Teams

1.  **Start Minimal:** Use the minimal install profile. Enable extra features (security, advanced deployment strategies) only when you have a clear need for them.
2.  **GitOps Everything:** Store your application configurations (Helm values) in Git. Devtron does this by default. Consider storing your Devtron `values.yaml` in Git as well for disaster recovery.
3.  **Standardize with Projects:** Use Devtron Projects to group related applications. This helps organize secrets, permissions, and environments.
4.  **Embrace Environments:** Even on a single cluster, use different namespaces for `dev`, `staging`, and `prod` environments. This provides crucial isolation.
5.  **Use a Git Flow:** Adopt a simple Git branching model like GitFlow or Trunk-Based Development. Trigger `dev` deployments from a `develop` branch and `prod` deployments from `main` or tags.
6.  **Pipeline Templates:** Once you have a working CI/CD pipeline for one Node.js app, save it or document it as your team's template to speed up onboarding new services.
7.  **Resource Optimization:**
    - Use build caching.
    - Set resource requests/limits on all workloads.
    - Clean up old container images from your registry (GHCR has retention policies).
```

### ## examples.md Content

```markdown
# EXAMPLES: Devtron Configuration for Helix Stax

This file contains copy-paste-ready configuration examples for setting up Devtron in the specified K3s environment.

## 1. Helm `values.yaml` for K3s Installation

This `values.yaml` is tailored for a resource-constrained K3s cluster with external PostgreSQL and no standard Ingress.

```yaml
# values.yaml for Devtron on Helix Stax K3s
#
# USAGE: helm install devtron devtron/devtron -n devtroncd --create-namespace -f values.yaml
#
installer:
  # Minimal installation profile to conserve resources
  modules:
    - cicd
    - argo-cd
    # - security-clair (disabled to save ram)
    # - external-secrets-operator (disabled, not needed initially)

# --- Database Configuration ---
# We are using an external PostgreSQL managed by CloudNativePG
postgresql:
  installed: false

# --- Core Devtron Configuration ---
configs:
  # Point Devtron to a Kubernetes secret containing the external DB credentials
  # This secret MUST be created manually before installing Devtron.
  # See reference.md for instructions on creating this secret.
  externalSecret:
    enabled: true
    secretName: "devtron-external-pg-secret"

# --- Ingress Configuration ---
# We are using Cloudflare Tunnel, so we don't need a Kubernetes Ingress object for Devtron itself.
# The tunnel will point directly to the devtron-service.
ingress:
  enabled: false

# --- Bundled ArgoCD Configuration ---
argo-cd:
  # Install ArgoCD as part of Devtron
  install: true
  # Set resource limits to prevent it from consuming too many resources
  server:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  repoServer:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  applicationSet:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi

# --- CI/CD Component Configuration ---
cicd:
  # Set resource limits for the buildkit daemon (used for faster builds)
  buildkit:
    enabled: true # Recommended over Kaniko for performance
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: "1"
        memory: "1Gi"

# --- MinIO for Logs/Cache ---
# Devtron uses MinIO for caching CI logs and artifacts.
minio:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## 2. Cloudflare Tunnel Configuration (`config.yaml`)

This snippet is for your `cloudflared` deployment configuration, pointing the public hostname to the internal Devtron service.

```yaml
# ingress-rules for cloudflared config.yaml
ingress:
  # Route traffic for devtron.helixstax.net
  - hostname: devtron.helixstax.net
    service: https://devtron-service.devtroncd.svc.cluster.local:80
    # Using 'https' is recommended for in-cluster mTLS if you have a service mesh or linkerd.
    # If not, 'http' works fine as well. The port is the service port (80).
    originRequest:
      noTLSVerify: true # Required if the service uses a self-signed cert, common in-cluster.

  # --- Example for an application deployed BY Devtron ---
  # Assuming your app "my-api" is in the "dev-apps" namespace
  # and you pointed the tunnel at Traefik.
  - hostname: my-api.helixstax.net
    service: http://traefik.traefik.svc.cluster.local:80 # Point to Traefik service

  # Catch-all rule to terminate other requests
  - service: http_status:404
```

## 3. Zitadel OIDC Configuration (Devtron YAML Representation)

This is a YAML representation of the OIDC configuration you would enter in the Devtron UI. Useful for documentation and automation.

```yaml
# This is a representation of the data saved by Devtron, not a direct config file.
# Path: Global Configurations -> User Management & SSO -> Zitadel
ssoConfig:
  name: "Zitadel"
  active: true
  config:
    # URL/Mount Path from Devtron UI
    id: "dex.local" # Internal ID, Devtron might assign this
    name: "Zitadel"
    type: "oidc"
    config:
      # Issuer URL from Zitadel
      issuer: https://zitadel.helixstax.net
      # Client ID from Zitadel
      clientID: "123456789012345678@helixstax"
      # Client Secret from Zitadel
      clientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      # Redirect URI you configured in Zitadel
      redirectURI: https://devtron.helixstax.net/orchestrator/api/v1/user/callback
      # Scopes to request
      scopes:
        - openid
        - profile
        - email
```

## 4. Example CI Pipeline for a Node.js App

This is a conceptual layout of a CI pipeline as configured in the Devtron UI.

**Pipeline Stage: Pre-build**
- **Type:** Pre-build Stage
- **Scripts:** `npm install`

**Pipeline Stage: Build**
- **Type:** Build Stage
- **Source:**
  - `main` branch
- **Container Registry:** `ghcr.io/keemwilliams/my-node-app`
- **Build Configuration:**
  - **Builder:** Build on platform (Buildkit/Kaniko)
  - **Dockerfile Path:** `./Dockerfile`
  - **Target Platform:** `linux/amd64`
  - **Cache:** Enabled

**Pipeline Stage: Post-build**
- **Type:** Post-build Stage
- **Task 1: Security Scan**
  - **Tool:** `Grype`
  - **Severity:** Block if `Critical` severity vulnerabilities are found.
- **Task 2: Image Promotion (optional)**
  - Promote image to another registry or tag.

## 5. Traefik `IngressRoute` for an Application

When Devtron deploys your application (`my-node-app`) into the `dev-apps` namespace, it will create a service (e.g., `my-node-app-service`). To expose this application via Traefik, you need to create an `IngressRoute`. You can add this YAML to your application's Helm chart within Devtron.

```yaml
# templates/ingressroute.yaml in your app's Helm chart
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .Release.Name }}-ingressroute
  namespace: {{ .Release.Namespace }}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-node-app.helixstax.net`)
      kind: Rule
      services:
        - name: {{ .Values.service.name | default .Release.Name }}
          port: {{ .Values.service.port | default 80 }}
  tls:
    # Traefik can handle TLS using cert-manager or a default cert
    # But since Cloudflare provides TLS, this part is often simplified or omitted
    # if you only use Traefik for internal routing to the tunnel.
    secretName: my-node-app-tls # Or handled by a wildcard cert
```
```
