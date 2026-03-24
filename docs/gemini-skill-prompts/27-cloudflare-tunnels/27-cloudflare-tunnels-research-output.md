# Cloudflare Tunnels & Zero Trust Access

### ## SKILL.md Content

This is a quick-reference guide for an AI agent to manage Cloudflare Tunnels and Access for Helix Stax.

#### **Cloudflared CLI Quick Reference**

```bash
# Authenticate the cloudflared daemon
cloudflared tunnel login

# Create a new named tunnel
# The output contains the Tunnel UUID and the path to the credentials file
cloudflared tunnel create <TUNNEL_NAME> # e.g., cloudflared tunnel create helix-k3s-main

# List tunnels
cloudflared tunnel list

# Delete a tunnel (requires UUID or name)
cloudflared tunnel delete <TUNNEL_NAME_OR_UUID>

# Get a token to run a new connector for an existing tunnel
# This token is what's used in Kubernetes secrets, NOT the tunnel secret itself
cloudflared tunnel token <TUNNEL_NAME_OR_UUID>

# Run a tunnel from the command line (for testing, not for production K3s)
cloudflared tunnel --config /path/to/config.yaml run <TUNNEL_NAME_OR_UUID>

# Create a DNS CNAME record for a tunnel
# Recommended to manage this via OpenTofu instead
cloudflared tunnel route dns <TUNNEL_NAME_OR_UUID> <hostname> # e.g., cloudflared tunnel route dns helix-k3s-main grafana.helixstax.net

# Get info and connector status for a tunnel
cloudflared tunnel info <TUNNEL_NAME_OR_UUID>

# SSH client command (use in ~/.ssh/config ProxyCommand)
# This command is run by your local 'ssh' client
cloudflared access ssh --hostname <hostname>
```

#### **Tunnel Health & Verification**

1.  **Check Connector Status:**
    ```bash
    # Get tunnel info, including connector IDs and statuses
    cloudflared tunnel info helix-k3s-main
    # Look for "Connections" and ensure they are to the correct Cloudflare datacenters.

    # Check the logs of the cloudflared pods in Kubernetes
    kubectl logs -n cloudflare -l app.kubernetes.io/name=cloudflared
    # Look for "Connection a-b-c-d registered" messages. Look for errors.
    ```

2.  **Verify DNS:**
    ```bash
    # Check that the CNAME record points to the tunnel URL.
    # Replace <TUNNEL_UUID> with the actual UUID from `cloudflared tunnel info`
    dig grafana.helixstax.net @1.1.1.1
    # Expected output:
    # grafana.helixstax.net.  300  IN  CNAME  <TUNNEL_UUID>.cfargotunnel.com.
    # <TUNNEL_UUID>.cfargotunnel.com. 300 IN A ...
    ```

3.  **Check Metrics Endpoint:**
    ```bash
    # Port-forward to a cloudflared pod to check metrics
    kubectl port-forward -n cloudflare svc/cloudflared 2000:2000
    # In another terminal:
    curl localhost:2000/metrics
    # Look for cloudflared_tunnel_active_streams > 0 during traffic.
    ```

#### **Traefik + Tunnel Integration Pattern**

This is the standard routing pattern for Helix Stax.

1.  **Cloudflare DNS:** `grafana.helixstax.net` -> CNAME -> `<tunnel-uuid>.cfargotunnel.com` (Proxied)
2.  **Cloudflare Tunnel Ingress (`config.yaml`):** `hostname: grafana.helixstax.net` -> `service: http://traefik.kube-system.svc:80`
3.  **Traefik IngressRoute (K8s):** `match: Host('grafana.helixstax.net')` -> `service: grafana.monitoring` Port `3000`

#### **Access Troubleshooting Flow**

1.  **User sees Cloudflare "Access Denied" page (Error 403):**
    *   **Check User Identity:** In Cloudflare Zero Trust Dashboard -> Logs -> Access, find the denied request. Does the `User Email` match who you expect?
    *   **Check Policy:** Go to Access -> Applications. Find the application for the hostname. Check its Policies.
    *   **Check Group Membership:** If the policy uses a Group (e.g., `helix-admins`), go to Access -> Groups. Verify the user's email (`wakeem@helixstax.com`) is in the `Include` rule for that group.
    *   **Check OIDC Claims:** If the policy uses OIDC claims from Zitadel (e.g., a specific role), check the Access log entry details to see what claims Cloudflare received from Zitadel. Ensure they match the policy rule.
    *   **Check Session:** Ask the user to go to `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/logout` (get team name from Zero Trust dashboard URL) and try logging in again.

2.  **User sees a non-Cloudflare error (e.g., 404, 502):**
    *   The request passed Access but failed at the origin.
    *   **Check Traefik Logs:** `kubectl logs -n kube-system -l app.kubernetes.io/name=traefik`
    *   **Check Traefik Dashboard:** Is the IngressRoute for the hostname active and pointing to the correct service?
    *   **Check `cloudflared` Logs:** `kubectl logs -n cloudflare -l app.kubernetes.io/name=cloudflared`. Look for "Unable to reach origin" errors. This indicates a problem between `cloudflared` and Traefik.
    *   **Check Backend Service:** Is the destination pod (e.g., `grafana`) running? Are its logs clean? `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`

#### **Configuration Snippets**

*   **`cloudflared` Deployment Flags (in `values.yaml` or args):**
    ```yaml
    # Helm values.yaml
    args:
      - tunnel
      - --no-autoupdate
      - --protocol
      - quic
      - --config
      - /etc/cloudflared/config/config.yaml
      - run
    ```

*   **Service Token Headers (Case-Insensitive, but this is best practice):**
    ```
    CF-Access-Client-Id: <your-client-id>
    CF-Access-Client-Secret: <your-client-secret>
    ```

### ## reference.md Content

This section contains the deep specifications for configuring Cloudflare Tunnel and Access at Helix Stax.

#### **Full `config.yaml` for `cloudflared` Tunnel**

This config file should be stored in a Kubernetes ConfigMap and mounted into the `cloudflared` pods. All services route through Traefik.

```yaml
# This is the primary tunnel ID. It is NOT a secret.
tunnel: helix-k3s-main
# The tunnel credentials file will be mounted from a Kubernetes Secret.
credentials-file: /etc/cloudflared/creds/credentials.json

# Expose a metrics server on port 2000 for Prometheus scraping
metrics: 0.0.0.0:2000

# The `ingress` section maps public hostnames to internal services.
# Our pattern is to route ALL traffic to the Traefik service on its HTTP port (80).
# Traefik's IngressRoute resources will then handle the final hop based on the Host header.
ingress:
  # Internal Platform Services
  - hostname: traefik.helixstax.net
    service: http://traefik.kube-system.svc:9000
    # Note: Traefik dashboard is an exception, routed directly as it's a Traefik service itself.
  - hostname: grafana.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: n8n.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: argocd.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: devtron.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: harbor.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: zitadel.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: outline.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: chat.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: minio.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: ai.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80
  - hostname: backstage.helixstax.net
    service: http://traefik-proxy.kube-system.svc:80

  # SSH Access for the control plane node
  # This makes 'ssh -p 2222 wakeem@helix-stax-cp.helixstax.net' work via tunnel
  - hostname: helix-stax-cp.helixstax.net
    service: ssh://178.156.233.12:2222
    originRequest:
      # Required for TCP connections
      noTLSVerify: true

  # This is the most important rule. It MUST be last.
  # It prevents the tunnel from trying to route unknown hostnames and provides a clean 404.
  - service: http_status:404
```
*Note: I've created a `traefik-proxy` service on port 80 that points to the main Traefik pods. This is a clean way to expose the HTTP entrypoint.*

#### **Helm `values.yaml` for `cloudflare/cloudflared`**

This file configures the official Helm chart for our K3s deployment.

```yaml
# values.yaml for cloudflare/cloudflared Helm chart
# Repository: https://cloudflare.github.io/helm-charts
# Chart: cloudflared
# Version: (use latest)

# We are using an existing secret for the tunnel token, not creating one.
# The secret 'cloudflare-tunnel-token' is created by ESO from OpenBao.
cloudflare:
  # The secret must contain a key 'credentials.json' with the content of the tunnel credentials file.
  existingSecret: cloudflare-tunnel-token
  # The tunnel name must match the one in config.yaml
  tunnelName: helix-k3s-main
  # Specify the protocol explicitely. QUIC is preferred.
  protocol: quic

# We want 2 replicas for High Availability
replicaCount: 2

# Mount the config.yaml from a ConfigMap
# The ConfigMap 'cloudflare-tunnel-config' should be created with the file above.
configmap:
  create: true
  name: cloudflare-tunnel-config
  # This is the key in the ConfigMap that holds the config file content
  data:
    config.yaml: |
      tunnel: helix-k3s-main
      credentials-file: /etc/cloudflared/creds/credentials.json
      metrics: 0.0.0.0:2000
      ingress:
        - hostname: traefik.helixstax.net
          service: http://traefik-dashboard.kube-system.svc:9000
        - hostname: grafana.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: n8n.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: argocd.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: devtron.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: harbor.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: zitadel.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: outline.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: chat.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: minio.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: ai.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: backstage.helixstax.net
          service: http://traefik-proxy.kube-system.svc:80
        - hostname: helix-stax-cp.helixstax.net
          service: ssh://178.156.233.12:2222
          originRequest:
            noTLSVerify: true
        - service: http_status:404

# Spread replicas across nodes for HA
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - cloudflared
        topologyKey: "kubernetes.io/hostname"

# Resource limits appropriate for a cpx31 node
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

# The chart includes liveness and readiness probes on /ready by default.
# It checks if the connector is connected to the Cloudflare edge.
# We will enable the metrics service for Prometheus.
service:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: metrics
    port: 2000
    targetPort: 2000

# We don't need any special RBAC.
rbac:
  create: true
serviceAccount:
  create: true
```

#### **OpenTofu Resource Definitions**

```hcl
# provider.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  # CLOUDFLARE_API_TOKEN environment variable is used here.
  # Permissions needed: Zone:DNS:Edit, Account:Cloudflare Tunnel:Edit, Account:Access: Apps and Policies:Edit, Account:Zero Trust:Read
}

# --- main.tf ---

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare Account ID"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for helixstax.net"
}

# 1. Create the Tunnel
resource "cloudflare_tunnel" "k3s_main" {
  account_id = var.cloudflare_account_id
  name       = "helix-k3s-main"
  # The secret is a 32-byte, base64-encoded string. Terraform generates this.
  # This secret is used to generate the credentials.json file.
  secret = "<REPLACE_WITH_SENSITIVE_BASE64_SECRET>" # Store this in OpenBao/Vault, not in git
}

# This output is the credentials.json content needed for the K8s secret.
output "tunnel_credentials_json" {
  value = jsonencode({
    "AccountTag"   = cloudflare_tunnel.k3s_main.account_id
    "TunnelID"     = cloudflare_tunnel.k3s_main.id
    "TunnelSecret" = base64decode(cloudflare_tunnel.k3s_main.secret)
  })
  sensitive = true
}

# 2. Configure the Tunnel Ingress Rules
# Note: Instead of this resource, we use a config.yaml in a ConfigMap for better GitOps flow.
# `cloudflare_tunnel_config` is an alternative if you prefer managing it via TF.

# 3. Create DNS CNAME records for each service
locals {
  services = [
    "traefik", "grafana", "n8n", "argocd", "devtron", "harbor",
    "zitadel", "outline", "chat", "minio", "ai", "backstage", "helix-stax-cp"
  ]
}

resource "cloudflare_record" "tunnel_cnames" {
  for_each = toset(local.services)
  zone_id  = var.cloudflare_zone_id
  name     = each.key # e.g., "grafana"
  value    = "${cloudflare_tunnel.k3s_main.id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true # Must be proxied (orange cloud) for Access to work
  ttl      = 1       # 1 = Auto
}

# 4. Define Access Groups
resource "cloudflare_access_group" "helix_admins" {
  account_id = var.cloudflare_account_id
  name       = "Helix Stax Admins"
  include {
    email = ["wakeem@helixstax.com"]
  }
}

resource "cloudflare_access_group" "helix_team" {
  account_id = var.cloudflare_account_id
  name       = "Helix Stax Team"
  include {
    email_domain = ["helixstax.com"]
  }
}

resource "cloudflare_access_group" "machines" {
  account_id = var.cloudflare_account_id
  name       = "Machine Users (Service Tokens)"
  # This group will be used in policies to match requests with service tokens.
  # The rule is empty, as it's the presence of a valid service token in the policy that matters.
}

# 5. Define Access Applications (one per service)
resource "cloudflare_access_application" "grafana" {
  zone_id                   = var.cloudflare_zone_id
  name                      = "Grafana"
  domain                    = "grafana.helixstax.net"
  type                      = "self_hosted"
  session_duration          = "8h"
  auto_redirect_to_identity = true
  allowed_idps              = [ "<ZITADEL_IDP_UUID>" ] # Get from CF Dashboard after setting up IdP
}

# ... Repeat `cloudflare_access_application` for all 12 services ...
# Example for a service accessible by the whole team:
resource "cloudflare_access_application" "harbor" {
  zone_id                   = var.cloudflare_zone_id
  name                      = "Harbor"
  domain                    = "harbor.helixstax.net"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [ "<ZITADEL_IDP_UUID>" ]
}

# SSH Application for helix-stax-cp
resource "cloudflare_access_application" "ssh_cp_node" {
  zone_id          = var.cloudflare_zone_id
  name             = "SSH: helix-stax-cp"
  domain           = "helix-stax-cp.helixstax.net"
  type             = "ssh"
  session_duration = "1h"
  # Enable browser rendering for in-dashboard SSH access
  enable_browser_rendering = true
}

# 6. Define Access Policies (one "Allow" per application)
resource "cloudflare_access_policy" "grafana_allow_admins" {
  application_id = cloudflare_access_application.grafana.id
  zone_id        = var.cloudflare_zone_id
  name           = "Allow Admins"
  decision       = "allow"
  precedence     = 1
  include {
    group = [cloudflare_access_group.helix_admins.id]
  }
}

resource "cloudflare_access_policy" "harbor_allow_team_and_machines" {
  application_id = cloudflare_access_application.harbor.id
  zone_id        = var.cloudflare_zone_id
  name           = "Allow Team and Machines"
  decision       = "allow"
  precedence     = 1
  # This demonstrates OR logic between rules
  include {
    group = [cloudflare_access_group.helix_team.id]
  }
  include {
    # This matches any valid service token associated with this application
    service_token = [cloudflare_access_service_token.harbor_ci_cd.id]
  }
}

resource "cloudflare_access_policy" "ssh_cp_node_allow_admins" {
  application_id = cloudflare_access_application.ssh_cp_node.id
  zone_id        = var.cloudflare_zone_id
  name           = "Allow Admins via SSH"
  decision       = "allow"
  precedence     = 1
  include {
    group = [cloudflare_access_group.helix_admins.id]
  }
}

# 7. Define Service Tokens
resource "cloudflare_access_service_token" "harbor_ci_cd" {
  account_id = var.cloudflare_account_id
  name       = "Harbor CI/CD Token"
  # Set duration to 1 year (8760h)
  duration = "8760h"
}

output "harbor_ci_cd_service_token_client_id" {
  value = cloudflare_access_service_token.harbor_ci_cd.client_id
  sensitive = true
}
output "harbor_ci_cd_service_token_client_secret" {
  value = cloudflare_access_service_token.harbor_ci_cd.client_secret
  sensitive = true
}
```

#### **OIDC Integration with Zitadel**

**In Zitadel:**

1.  Go to your Project -> Applications -> New Application.
2.  Choose **Web** application type. Continue.
3.  **Name:** `Cloudflare Access`
4.  **Authentication Method:** `Code Flow`
5.  **Post Logout URIs:** Can be your main company site, e.g., `https://helixstax.com`
6.  **Redirect URIs:** Get this from your Cloudflare Zero Trust dashboard. Go to Settings -> Authentication -> Login Methods -> Add new -> OIDC. It will show you the callback URL. It looks like: `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback`
7.  Save the application.
8.  On the application detail page, you will find:
    *   **Client ID**
    *   **Client Secret** (Click the "eye" icon to view and copy)
9.  Ensure **Token Endpoint Authentication Method** is `BASIC` (Client Secret sent in header).
10. Ensure **PKCE** is enabled (it's the default and required).

**In Cloudflare Zero Trust:**

1.  Go to Settings -> Authentication -> Login Methods -> Add new.
2.  Select **Open ID Connect (OIDC)**.
3.  **Name:** `Zitadel`
4.  **App ID (Client ID):** Paste the Client ID from Zitadel.
5.  **Client Secret:** Paste the Client Secret from Zitadel.
6.  **Authorization endpoint:** `https://zitadel.helixstax.net/oauth/v2/authorize`
7.  **Token endpoint:** `https://zitadel.helixstax.net/oauth/v2/token`
8.  **JWKS URL:** `https://zitadel.helixstax.net/oauth/v2/keys`
9.  **Scopes:** Add `openid`, `email`, `profile`. To use Zitadel roles in Access policies, add `urn:zitadel:iam:org:project:roles`.
10. **OIDC Claims:** To use roles, add a claim named `roles` and ensure it maps correctly from the token.

#### **Prometheus Scrape Config for `cloudflared`**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cloudflare-tunnel'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Scrape pods with the annotation prometheus.io/scrape=true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod
```

And add annotations to the `cloudflared` pods (via Helm `values.yaml`):

```yaml
# In values.yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "2000"
  prometheus.io/path: "/metrics"
```

### ## examples.md Content

This section provides copy-paste-ready, Helix Stax-specific examples.

#### **OpenTofu Module: `modules/cloudflare-tunnel/`**

**`modules/cloudflare-tunnel/main.tf`**

```hcl
# This module encapsulates the creation of a tunnel, its DNS records,
# and all associated Access Applications and Policies for Helix Stax.

variable "cloudflare_account_id" { type = string }
variable "cloudflare_zone_id" { type = string }
variable "zitadel_idp_uuid" { type = string }
variable "tunnel_secret_b64" { type = string; sensitive = true }

resource "cloudflare_tunnel" "main" {
  account_id = var.cloudflare_account_id
  name       = "helix-k3s-main"
  secret     = var.tunnel_secret_b64
}

output "tunnel_id" {
  value = cloudflare_tunnel.main.id
}

output "tunnel_credentials_json" {
  value = jsonencode({
    "AccountTag"   = cloudflare_tunnel.main.account_id
    "TunnelID"     = cloudflare_tunnel.main.id
    "TunnelSecret" = base64decode(cloudflare_tunnel.main.secret)
  })
  sensitive = true
}

# --- GROUPS ---
resource "cloudflare_access_group" "admins" {
  account_id = var.cloudflare_account_id
  name       = "Helix Stax Admins"
  include { email = ["wakeem@helixstax.com"] }
}
resource "cloudflare_access_group" "team" {
  account_id = var.cloudflare_account_id
  name       = "Helix Stax Team"
  include { email_domain = ["helixstax.com"] }
}

# --- SERVICE TOKENS ---
resource "cloudflare_access_service_token" "cicd_generic" {
  account_id = var.cloudflare_account_id
  name       = "Generic CI/CD Service Token"
  duration   = "8760h"
}

output "cicd_service_token_client_id" { value = cloudflare_access_service_token.cicd_generic.client_id; sensitive = true }
output "cicd_service_token_client_secret" { value = cloudflare_access_service_token.cicd_generic.client_secret; sensitive = true }


# --- DYNAMIC DNS, APPS, POLICIES ---
locals {
  # Service map: hostname => [ internal_service, access_group_resource, session_duration ]
  # access_group_resource is a pointer to the TF resource for the group
  services = {
    grafana     = [cloudflare_access_group.admins, "8h"]
    n8n         = [cloudflare_access_group.admins, "8h"]
    argocd      = [cloudflare_access_group.admins, "8h"]
    devtron     = [cloudflare_access_group.admins, "8h"]
    minio       = [cloudflare_access_group.admins, "8h"]
    zitadel     = [cloudflare_access_group.admins, "1h"]
    harbor      = [cloudflare_access_group.team, "24h"]
    outline     = [cloudflare_access_group.team, "24h"]
    chat        = [cloudflare_access_group.team, "720h"] # 30 days
    ai          = [cloudflare_access_group.team, "24h"]
    backstage   = [cloudflare_access_group.team, "24h"]
    traefik     = [cloudflare_access_group.admins, "8h"]
  }
}

resource "cloudflare_record" "service_cnames" {
  for_each = local.services
  zone_id  = var.cloudflare_zone_id
  name     = each.key
  value    = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
  ttl      = 1
}

resource "cloudflare_access_application" "apps" {
  for_each                  = local.services
  zone_id                   = var.cloudflare_zone_id
  name                      = "Platform: ${title(each.key)}"
  domain                    = "${each.key}.helixstax.net"
  type                      = "self_hosted"
  session_duration          = each.value[1]
  auto_redirect_to_identity = true
  allowed_idps              = [var.zitadel_idp_uuid]
}

resource "cloudflare_access_policy" "policies" {
  for_each       = cloudflare_access_application.apps
  application_id = each.value.id
  zone_id        = var.cloudflare_zone_id
  name           = "Allow ${local.services[each.key][0].name}"
  decision       = "allow"
  precedence     = 1

  include {
    group = [local.services[each.key][0].id]
  }

  # Add service token access for Harbor
  dynamic "include" {
    for_each = each.key == "harbor" ? [1] : []
    content {
      service_token = [cloudflare_access_service_token.cicd_generic.id]
    }
  }
}
```

#### **Traefik IngressRoute Examples**

These live in your K8s manifests repository, managed by ArgoCD.

```yaml
# grafana-ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - web # The HTTP entrypoint used by cloudflared
  routes:
    - match: Host(`grafana.helixstax.net`)
      kind: Rule
      services:
        - name: grafana
          port: 3000
---
# argocd-ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`argocd.helixstax.net`)
      kind: Rule
      services:
        - name: argocd-server
          port: 443
          scheme: https # ArgoCD server serves HTTPS by default
      middlewares:
        # We need this middleware to tell Traefik to trust the self-signed cert from ArgoCD
        - name: argocd-insecureskipverify
          namespace: argocd
---
# argocd-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: argocd-insecureskipverify
  namespace: argocd
spec:
  serversTransport:
    insecureSkipVerify: true # Only because Argo serves its own cert internally
```

#### **ESO `ExternalSecret` for Tunnel Token**

```yaml
# cloudflare-tunnel-token-eso.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-tunnel-token
  namespace: cloudflare
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: openbao # Assuming the SecretStore is named 'openbao'
    kind: SecretStore
  target:
    name: cloudflare-tunnel-token
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        # The key in the K8s Secret must be 'credentials.json'
        credentials.json: "{{ .tunnel_creds | fromJson | toString }}"
  data:
  - secretKey: tunnel_creds
    remoteRef:
      # This is the path in OpenBao where the TF output was stored
      key: "secret/data/cloudflare"
      property: "tunnel_credentials_json"
```

#### **n8n HTTP Request Node with Service Token**

To call an Access-protected service (e.g., an API endpoint in your `ai.helixstax.net` app) from n8n:

1.  Create a "Credentials" -> "Header Auth" credential in n8n.
2.  **Name:** `Cloudflare Access Service Token`
3.  **Header Name:** `CF-Access-Client-Id`
4.  **Header Value:** Paste the Client ID from the OpenTofu output.
5.  Click "Add Header".
6.  **Header Name:** `CF-Access-Client-Secret`
7.  **Header Value:** Paste the Client Secret.
8.  Save.
9.  In an HTTP Request node, select this credential from the "Authentication" dropdown.

#### **`~/.ssh/config` for Cloudflare Access SSH**

```ini
# ~/.ssh/config

# Rule for connecting to helix-stax-cp node via Cloudflare Tunnel
Host helix-stax-cp.helixstax.net
  HostName helix-stax-cp.helixstax.net
  User wakeem
  Port 2222
  # This command proxies the SSH connection through cloudflared
  ProxyCommand cloudflared access ssh --hostname %h

# Example command:
# > ssh helix-stax-cp.helixstax.net
# This will trigger a browser login, and upon success, connect to port 2222.
```

#### **Migration Runbook**

**Goal:** Migrate all services from direct access to Cloudflare Tunnel + Access.

**Pre-requisites:**
1.  OpenTofu code for all Cloudflare resources is written and validated.
2.  Helm chart `values.yaml` for `cloudflared` is ready.
3.  `ExternalSecret` manifest for tunnel token is ready.
4.  Traefik `IngressRoute` manifests for all services are ready.
5.  Zitadel is configured as an OIDC provider in Cloudflare.

**Sequence:**
1.  **[Infra]** `tofu apply` the Cloudflare resources (`cloudflare_tunnel`, groups, etc.). This creates the tunnel entity but doesn't run it.
2.  **[Secrets]** Capture the `tunnel_credentials_json` output and store it in OpenBao at `secret/data/cloudflare`.
3.  **[K8s]** Deploy the `ExternalSecret` manifest to the `cloudflare` namespace. Verify the `cloudflare-tunnel-token` Kubernetes Secret is created successfully (`kubectl get secret -n cloudflare cloudflare-tunnel-token`).
4.  **[K8s]** Deploy the Traefik `IngressRoute` manifests for all services. Verify they are loaded in the Traefik dashboard.
5.  **[K8s]** Deploy the `cloudflared` Helm chart into the `cloudflare` namespace.
6.  **[Validation]** Check `cloudflared` pod logs. You should see it connect successfully to the Cloudflare edge. Check `cloudflared tunnel info helix-k3s-main`.
7.  **[DNS & Access]** `tofu apply` the `cloudflare_record`, `cloudflare_access_application`, and `cloudflare_access_policy` resources. This flips the switch.
8.  **[Testing]** Go to `https://grafana.helixstax.net`. You should be redirected to Zitadel for login. After logging in as `wakeem@helixstax.com`, you should see Grafana. Test a few other admin services. Test a `helix-team` service like `harbor.helixstax.net`.
9.  **[SSH Test]** Configure your `~/.ssh/config` as above. Run `ssh helix-stax-cp.helixstax.net`. Authenticate in the browser. You should get a shell on the server.
10. **[Firewall Lockdown]** Once all services are confirmed working via the tunnel, update the `firewalld` rules on `helix-stax-cp` (178.156.233.12).
    *   **Current State:** Likely allows port 2222 from `0.0.0.0/0`.
    *   **Final State:** Block all inbound traffic except for required Hetzner management ports. Port 2222 will no longer be needed from the public internet. Access is only via the tunnel.
    ```bash
    # Example firewall lockdown
    firewall-cmd --permanent --remove-service=ssh # If using the standard service
    firewall-cmd --permanent --remove-port=2222/tcp
    firewall-cmd --reload
    # Verify: trying to ssh directly to 178.156.233.12:2222 should now time out.
    # Verify: ssh via the tunnel (ssh helix-stax-cp.helixstax.net) should still work.
    ```
11. **[Monitoring]** Configure Prometheus to scrape the `cloudflared` metrics endpoint. Set up alerts for tunnel disconnects.

**Rollback Plan:**
*   **If tunnel access fails:** `tofu destroy` the `cloudflare_record` resources to remove the CNAMEs. This will make the hostnames unreachable, but not break anything else.
*   **For emergency access:** Re-add the public firewalld rule: `firewall-cmd --permanent --add-port=2222/tcp; firewall-cmd --reload`.
*   **If `cloudflared` pods are failing:** `helm uninstall cloudflared -n cloudflare`. This takes the connectors offline without deleting the tunnel entity in Cloudflare.
