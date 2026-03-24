Of course. This is an excellent prompt, and building a comprehensive, opinionated reference document is the correct way to enable AI agents and ensure operational consistency.

Here is the Gemini Deep Research report for Cloudflare, Traefik, and Helm, structured exactly as you requested for your AI agents at Helix Stax.

***

# Cloudflare

## SKILL.md Content
**Cloudflare: Your Edge Firewall and CDN**

Cloudflare is the first point of contact for all traffic to `helixstax.com` and `helixstax.net`. It provides DNS, DDoS/WAF protection, CDN caching, and Zero Trust access control before traffic ever reaches our K3s cluster.

**CLI Reference (wrangler)**

```bash
# Authenticate wrangler (run once)
npx wrangler login

# Find your Account ID and Zone ID
npx wrangler whoami
# Or grep from dashboard URL: https://dash.cloudflare.com/[ACCOUNT_ID]/[DOMAIN]/...
# Zone ID is on the domain's overview page.

# DNS: List all records for a domain
npx wrangler dns records list helixstax.com

# DNS: Create an A record for the cluster control plane
npx wrangler dns records create helixstax.com --type=A --name='k3s' --content='178.156.233.12' --proxied

# DNS: Delete a record by ID (get ID from list command)
npx wrangler dns records delete helixstax.com --record-id='...'

# Tunnel: List tunnels
npx wrangler tunnel list

# Tunnel: Get status of a specific tunnel
npx wrangler tunnel info <TUNNEL_NAME_OR_ID>
```

**Configuration Patterns**

*   **DNS:** All public services on `helixstax.com` must have the proxy status enabled (orange cloud). Internal services on `helixstax.net` also use the proxy for Cloudflare Access integration. Use a CNAME record for `*.helixstax.net` pointing to the tunnel hostname.
*   **TLS Mode:** Must be **Full (Strict)**. Traefik is configured to present a valid Cloudflare Origin CA certificate. Anything else is a misconfiguration and insecure.
*   **Real IP:** Traefik is configured to trust the `CF-Connecting-IP` header. This is enabled via `proxyProtocol` and `trustedIPs` in Traefik's HelmChartConfig.
*   **Zero Trust (Internal Services):**
    1.  Service DNS record (`service.helixstax.net`) is a CNAME pointing to the Cloudflare Tunnel hostname.
    2.  Cloudflare Access Application is created for `service.helixstax.net`.
    3.  Access policy is configured to use Zitadel as the OIDC IdP, requiring a valid login.

**Troubleshooting Decision Tree**

*   **Symptom:** **Error 525/526 (SSL Handshake Failed)**
    *   **Cause 1:** Cloudflare TLS mode is `Full (Strict)` but Traefik is not presenting the Origin CA cert.
    *   **Fix:** Ensure the `IngressRoute`'s `tls.secretName` points to the Kubernetes secret containing the Cloudflare Origin CA cert.
    *   **Cause 2:** The K8s secret is corrupt, expired, or doesn't match the domain.
    *   **Fix:** Re-create the Cloudflare Origin CA certificate and update the K8s secret.
*   **Symptom:** **Error 521 (Web Server is Down) / 522 (Connection Timed Out)**
    *   **Cause 1:** Hetzner Cloud Firewall is blocking Cloudflare's IP ranges.
    *   **Fix:** Ensure Hetzner Firewall allows traffic on ports 80/443 from all IPs listed at [https://www.cloudflare.com/ips/](https://www.cloudflare.com/ips/).
    *   **Cause 2:** The Traefik service in K3s is not running or its external IP (`178.156.233.12`) is wrong.
    *   **Fix:** `kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik` and `kubectl get svc -n kube-system traefik`.
*   **Symptom:** **Infinite Login Redirect Loop with Zitadel**
    *   **Cause:** Cloudflare Access is not configured correctly to handle the OIDC callback from Zitadel.
    *   **Fix:** In the Cloudflare Access Application, ensure the `aud` tag matches the Client ID in Zitadel, and the OIDC `Auth URL`, `Token URL`, and `Client Secret` are correct.
*   **Symptom:** **WebSockets not working**
    *   **Cause:** Cloudflare's proxy has a default 100s timeout. WebSockets are not enabled on the zone.
    *   **Fix:** In Cloudflare Dashboard -> Network, enable "WebSockets". Traefik handles the upgrade headers automatically.

---
## reference.md Content
**Cloudflare: Deep Reference**

### CF-1. CLI Reference (wrangler)

`wrangler` is the command-line tool for managing Cloudflare resources. It requires `Node.js`.

```bash
# Install wrangler globally (or use npx)
npm install -g wrangler

# Login
wrangler login

# Get Account ID
wrangler whoami
```

**DNS (`wrangler dns`)**
Requires `--zone-id` or domain name.

*   `wrangler dns records list <ZONE>`: List all DNS records.
*   `wrangler dns records create <ZONE> --type <A|AAAA|CNAME|...> --name <NAME> --content <CONTENT> [--ttl <TTL>] [--proxied]`: Create a record. `name` is the subdomain. `@` for root.
*   `wrangler dns records delete <ZONE> --record-id <ID>`: Delete a record.
*   `wrangler dns records import <ZONE> --file <FILENAME>`: Bulk import records from a BIND file.
*   `wrangler dns records export <ZONE>`: Export records in BIND format.

**Tunnel (`wrangler tunnel`)**
Manages `cloudflared` tunnels for Zero Trust access.

*   `wrangler tunnel list`: List all tunnels in the account.
*   `wrangler tunnel create <NAME>`: Create a new tunnel. Generates credentials.
*   `wrangler tunnel token <NAME>`: Get the token for an existing tunnel.
*   `wrangler tunnel route dns <TUNNEL_NAME_OR_ID> <HOSTNAME>`: Create a DNS record pointing to the tunnel. (e.g., `wrangler tunnel route dns my-tunnel grafana.helixstax.net`)
*   `wrangler tunnel delete <NAME>`: Delete a tunnel.

**WAF, Access, etc.**
Wrangler's support for WAF and Access policies is limited. Automation for these is best handled via the Cloudflare API v4 using tools like Terraform/OpenTofu or direct API calls.

### CF-2. DNS Management Patterns

*   **Split DNS:** Not a true split DNS. We use two public zones (`helixstax.com`, `helixstax.net`) both managed by Cloudflare. `helixstax.com` points to the public IP of the cluster (`178.156.233.12`). `helixstax.net` records point to a Cloudflare Tunnel for Zero Trust access.
*   **Wildcard DNS:** A proxied CNAME record `*.helixstax.com` pointing to `k3s.helixstax.com` (`178.156.233.12`) simplifies IngressRoute creation.
*   **Email Records (Google Workspace + Postal):**
    *   **SPF:** `v=spf1 include:_spf.google.com include:postal.helixstax.com ~all`
    *   **DKIM:** Multiple DKIM records. One for Google (`google._domainkey`), one for Postal (`postal._domainkey`). Values are provided by the respective services.
    *   **DMARC:** `v=DMARC1; p=reject; rua=mailto:dmarc-reports@helixstax.com;` (Start with `p=none`, then `p=quarantine`, then `p=reject`).
*   **DNSSEC:** Enable with one click in the Cloudflare Dashboard under "DNS" -> "Settings". Cloudflare handles all key rotation and management. No gotchas for our setup.

### CF-3. Zero Trust Configuration

**Architecture:**
```
User -> Browser -> zitadel.helixstax.net -> Cloudflare Access -> Cloudflare Edge -> Cloudflare Tunnel (cloudflared) -> K3s Cluster -> Internal Service (e.g., Grafana)
```
1.  **Zitadel as OIDC IdP:** In Cloudflare Zero Trust Dashboard -> Settings -> Authentication -> Login Methods, add a new provider for OIDC. Use the discovery URL, Client ID, and Client Secret from your Zitadel Project application.
2.  **Cloudflare Tunnel:** A `cloudflared` deployment runs in the cluster, creating a persistent outbound connection to Cloudflare's edge. No inbound ports need to be opened.
3.  **Cloudflare Access Application:** For each service (e.g., `grafana.helixstax.net`), create an Application in Zero Trust.
    *   Set the subdomain and domain.
    *   Define a policy: `Include: Authenticated by [Zitadel OIDC Provider]`. You can add more granular rules (e.g., group membership).
    *   Under `Settings`, add the application `aud` tag from Zitadel to the `Application Audience (AUD)` field.

### CF-6. Cloudflare + Traefik Integration

*   **Real IP Forwarding:** Cloudflare adds the `CF-Connecting-IP` header. Traefik *must* be configured to trust this header *only* when the request comes from a legitimate Cloudflare IP.
    *   Traefik's `HelmChartConfig` should have `providers.kubernetesCRD.ingressClass=traefik-external` and `entryPoints.websecure.forwardedHeaders.trustedIPs` populated with Cloudflare's IP ranges. A cronjob should update this list periodically.
*   **TLS Modes:**
    *   **`Off`**: Insecure. Never use.
    *   **`Flexible`**: Insecure. Never use.
    *   **`Full`**: Encrypts Cloudflare -> Traefik, but doesn't verify the certificate. Risky.
    *   **`Full (Strict)`**: **This is the required mode.** Encrypts and verifies the certificate presented by Traefik. Our Cloudflare Origin CA certificate satisfies this requirement.
*   **Avoiding Double Proxying:** The only proxy is Cloudflare. `proxy.helixstax.com` (for example) is an A-record pointing to the cluster IP. Traffic hits Cloudflare, then the cluster. There is no second proxy. Cloudflare Tunnel is also a single proxy layer.

### CF-8. Troubleshooting Common Cloudflare Errors

*   **520 Web Server Returned an Unknown Error:** Catch-all. Origin (Traefik) sent an invalid or empty response. Check Traefik logs and the upstream application logs.
*   **521 Web Server is Down:** Cloudflare could not establish a TCP connection to the origin IP (`178.156.233.12`). This is almost always a firewall issue (cluster-side or Hetzner) or a routing problem.
*   **522 Connection Timed Out:** TCP connection was established, but the origin did not respond to the HTTP request in time. Traefik is up, but maybe overloaded, or the backend service is hanging.
*   **523 Origin is Unreachable:** Another routing issue. Cloudflare can't find a path to your server. Double-check the A record IP.
*   **524 A Timeout Occurred:** The origin took too long to send a complete HTTP response (default 100s). For long-running jobs, bypass Cloudflare or use a different mechanism.
*   **525 SSL Handshake Failed:** TLS mismatch. Cloudflare (`Full (Strict)`) tried to connect to Traefik, but Traefik did not present a trusted certificate. Ensure the Origin CA cert is correctly configured in the `IngressRoute`.
*   **526 Invalid SSL Certificate:** TLS mismatch. Cloudflare (`Full`) tried to connect, but the certificate presented by Traefik was invalid (e.g., self-signed, expired). `Full (Strict)` would catch this as a 525.

---
## examples.md Content
**Cloudflare: Helix Stax Examples**

**DNS Record Creation (wrangler)**

```bash
# Set environment variables for convenience
export CF_ACCOUNT_ID="your_cloudflare_account_id"
export CF_ZONE_ID_COM="zone_id_for_helixstax.com"
export CF_ZONE_ID_NET="zone_id_for_helixstax.net"

# Create the main A record for the K3s control plane
npx wrangler dns records create helixstax.com --name="k3s-cp1" --type=A --content="178.156.233.12" --proxied

# Create a wildcard CNAME pointing to the control plane for easy service exposure
npx wrangler dns records create helixstax.com --name="*" --type=CNAME --content="k3s-cp1.helixstax.com" --proxied

# Create a record for an internal service to be exposed via Cloudflare Tunnel
# First, get the tunnel CNAME from the Tunnel dashboard (e.g., <UUID>.cfargotunnel.com)
# Then create a CNAME record for it.
npx wrangler dns records create helixstax.net --name="grafana" --type=CNAME --content="<UUID>.cfargotunnel.com" --proxied
npx wrangler dns records create helixstax.net --name="argocd" --type=CNAME --content="<UUID>.cfargotunnel.com" --proxied
```

**Zero Trust Application for Grafana (`grafana.helixstax.net`)**

1.  **In Zitadel:** Create a new Application. Set Application Type to `Web`, Auth Method to `OIDC`. Set Redirect URIs to `https://grafana.helixstax.net/oauth2/callback`. Note the Client ID and generate a Client Secret.
2.  **In Cloudflare Zero Trust:**
    *   Navigate to `Access -> Applications -> Add an application`.
    *   Choose `Self-hosted`.
    *   Application name: `Grafana`.
    *   Session Duration: `24 hours`.
    *   Application domain: `grafana.helixstax.net`.
    *   Identity providers: Check the box for your `Zitadel OIDC` provider.
    *   **Important:** Under "Additional settings", find "Application Audience (AUD)" and paste the Client ID from Zitadel.
3.  **Create an Access Policy for the Application:**
    *   Policy name: `Allow Authenticated Users`.
    *   Action: `Allow`.
    *   Rule: `Include` selector, choose `Login Method`, and select `Zitadel OIDC`.

**Cloudflare Origin CA Certificate Generation and K8s Secret Creation**

1.  **In Cloudflare Dashboard:**
    *   Go to `SSL/TLS -> Origin Server -> Create Certificate`.
    *   Select `Generate private key and CSR with Cloudflare`.
    *   Hostnames: `helixstax.com`, `*.helixstax.com`, `helixstax.net`, `*.helixstax.net`.
    *   Certificate Validity: `15 years`.
    *   Click `Create`.
    *   Copy the `Origin Certificate` (PEM) and `Private Key` (PEM). Save them as `origin.pem` and `privkey.pem`. **You will not see the private key again.**
2.  **In your local terminal (with kubectl access):**
    ```bash
    # Create the Kubernetes TLS secret from the saved files
    kubectl create secret tls cloudflare-origin-ca-wildcard-tls \
      --cert=origin.pem \
      --key=privkey.pem \
      -n kube-system # Or any namespace Traefik can access
    ```
    This `cloudflare-origin-ca-wildcard-tls` secret in `kube-system` is now the single source of truth for Cloudflare-to-Traefik TLS. All `IngressRoute` resources will reference it.

***

# Traefik

## SKILL.md Content
**Traefik: Your In-Cluster Reverse Proxy**

Traefik runs inside K3s and is configured via the `HelmChartConfig` CRD. It receives traffic from Cloudflare, routes it to internal services using `IngressRoute` CRDs, and applies `Middleware` for auth, rate limiting, etc. We use CRDs exclusively.

**Core Concepts**

*   **HelmChartConfig:** The *only* way to configure K3s's bundled Traefik. Located in `kube-system` namespace. Edit this to change Traefik's startup config (entrypoints, logs, metrics).
*   **IngressRoute:** Defines a route from the public internet to a Kubernetes service. Matches a `Host()` and `Path()` and applies middleware.
*   **Middleware:** Reusable components that modify requests. `forwardAuth` is the most important for us.

**Common `IngressRoute` for Protected Service (e.g., Grafana)**

```yaml
# grafana-ingress-route.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana-ingress
  namespace: monitoring # Namespace where grafana service lives
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`grafana.helixstax.net`)
      services:
        - name: grafana-svc # The name of the Grafana K8s Service
          port: 3000
      middlewares:
        - name: zitadel-forward-auth
          namespace: traefik-middlewares # Central namespace for shared middleware
  tls:
    secretName: cloudflare-origin-ca-wildcard-tls # THE Cloudflare Origin cert
    namespace: kube-system # Namespace where the secret lives
```

**Key Middleware: Zitadel `forwardAuth`**

```yaml
# zitadel-forwardauth-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: zitadel-forward-auth
  namespace: traefik-middlewares # A dedicated namespace for these
spec:
  forwardAuth:
    # Note: Zitadel does not provide a native ForwardAuth endpoint. Use oauth2-proxy or Traefik's OIDC middleware with Zitadel's OIDC discovery endpoint (/.well-known/openid-configuration) instead.
    address: http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/auth
    trustForwardHeader: true
    authResponseHeaders:
      - X-Auth-Request-User
      - X-Auth-Request-Email
```

**Troubleshooting Decision Tree**

*   **Symptom:** **404 Not Found**
    *   **Cause 1:** `IngressRoute` not created or in the wrong namespace.
    *   **Fix:** `kubectl get ingressroute -A`. Ensure it's in the same namespace as the service it's routing to. Check Traefik logs for "router has been added".
    *   **Cause 2:** `Host()` or `PathPrefix()` rule doesn't match the request.
    *   **Fix:** Check Traefik Dashboard (`traefik.helixstax.net`) to see the active rule. Compare with the URL in your browser.
*   **Symptom:** **502 Bad Gateway**
    *   **Cause:** Traefik can route to the K8s service, but the pods behind it are unhealthy or rejecting the connection.
    *   **Fix:** `kubectl describe service <svc-name> -n <ns>`. `kubectl describe pod <pod-name> -n <ns>`. Check Pod logs.
*   **Symptom:** **Certificate Error in Browser** (after passing Cloudflare)
    *   **Cause:** The `tls.secretName` in the `IngressRoute` is wrong, missing, or points to a non-existent/invalid secret.
    *   **Fix:** Ensure `secretName: cloudflare-origin-ca-wildcard-tls` and `namespace: kube-system` are present and correct in the `IngressRoute`.
*   **Symptom:** **Config change in `HelmChartConfig` not applying**
    *   **Cause:** The K3s controller for Helm charts hasn't reconciled yet, or the YAML is invalid.
    *   **Fix:** Wait 60 seconds. Then check the `k3s` agent/server logs. To force a reconcile, you can `kubectl rollout restart deployment/traefik -n kube-system`.

---
## reference.md Content
**Traefik: Deep Reference**

### TR-1. IngressRoute CRD Reference

**`IngressRoute`** (`apiVersion: traefik.io/v1alpha1`)

*   **`metadata.name`**: (string) The name of the IngressRoute.
*   **`metadata.namespace`**: (string) The namespace of the IngressRoute.
*   **`spec.entryPoints`**: `[]string` - The names of Traefik entrypoints to use. For us: `["websecure"]`.
*   **`spec.routes`**: `[]Route` - A list of routing rules.
    *   **`kind`**: Must be `Rule`.
    *   **`match`**: (string) The rule to match requests.
        *   `Host(`domain.com`)`: Matches by hostname.
        *   `Path(`/path`)`: Matches exact path.
        *   `PathPrefix(`/path/`)`: Matches any path starting with this prefix.
        *   `Headers(`key`, `value`)`: Matches on header values.
        *   `Method(`GET`)`: Matches the HTTP method.
        *   Combine with `&&` (AND) and `||` (OR). `Host(...) && PathPrefix(...)`.
    *   **`priority`**: (int) Higher number = higher priority. Used to resolve conflicts if multiple rules match a request.
    *   **`services`**: `[]Service` - Backend services to route to.
        *   **`name`**: (string) Kubernetes Service name.
        *   **`namespace`**: (string) Kubernetes Service namespace.
        *   **`port`**: (int | string) Kubernetes Service port.
        *   **`scheme`**: (string) `http` or `https` (for backend communication).
        *   **`healthCheck`**, **`passHostHeader`**, etc.
    *   **`middlewares`**: `[]MiddlewareRef` - A list of middlewares to apply.
        *   **`name`**: (string) Middleware name.
        *   **`namespace`**: (string) Middleware namespace.
*   **`spec.tls`**: `TLS` - TLS configuration for this route.
    *   **`secretName`**: (string) The name of the Kubernetes `Secret` of type `kubernetes.io/tls`. For us: `cloudflare-origin-ca-wildcard-tls`.
    *   **`namespace`**: (string) Namespace of the secret. For us: `kube-system`.
    *   **`options`**: `TLSOptionRef` - Reference to a `TLSOption` CRD for advanced settings.
    *   **`domains`**: `[]string` - Optional list of domains covered by this route.

### TR-2. Middleware Configuration

`Middleware` (`apiVersion: traefik.io/v1alpha1`) is a namespaced resource.

*   **`forwardAuth`**: Delegates authentication to another service.
    *   **`address`**: (string) The URL of the auth service. (e.g., `http://zitadel.zitadel.svc.cluster.local:8080/oauth/v2/authinfo`).
    *   **`trustForwardHeader`**: (bool) `true`. Essential for running behind a proxy like Cloudflare.
    *   **`authResponseHeaders`**: `[]string` - Headers to copy from the auth server's response to the upstream application's request. (e.g., `X-Auth-Request-User`).
    *   **`authRequestHeaders`**: `[]string` - Headers to copy from the original request to the auth request. (e.g., `X-Forwarded-Host`, `X-Forwarded-Proto`).
*   **`headers`**: Modifies HTTP headers.
    *   **`customRequestHeaders` / `customResponseHeaders`**: `map[string]string` - Add or overwrite headers.
    *   **`sslRedirect`**: (bool) `true` (usually handled by entrypoint redirect instead).
    *   **`stsSeconds`**: (int) for HSTS. `31536000`.
    *   **`contentTypeNosniff`**: (bool) `true`.
    *   **`frameDeny`**: (bool) `true` (for `X-Frame-Options: DENY`).
*   **`rateLimit`**: Limits request rates.
    *   **`average`**: (int) Max average requests/sec.
    *   **`burst`**: (int) Max requests allowed in a burst.
    *   **`period`**: (string) e.g., `1s`, `1m`.
*   **Chaining Order:** Middlewares are applied in the order they are listed in the `IngressRoute`'s `middlewares` array.

### TR-7. K3s-Specific Configuration

The **only correct** way to configure the bundled Traefik is via a `HelmChartConfig` resource in the `kube-system` namespace.

**`api-version: helm.k3s.io/v1` kind: `HelmChartConfig`**

*   `metadata.name`: Must match the name of the bundled chart (`traefik`).
*   `metadata.namespace`: `kube-system`.
*   `spec.valuesContent`: A multi-line string containing `values.yaml` content that gets merged into the chart's defaults.

**Key values to override in `valuesContent`:**
*   `accessLog.enabled`: true
*   `accessLog.format`: json
*   `metrics.prometheus.enabled`: true
*   `providers.kubernetesCRD.allowCrossNamespace`: true (allows middleware in one namespace to be used by an IngressRoute in another)
*   `entryPoints.web.redirectTo.target`: `websecure` (for HTTP -> HTTPS redirect)
*   `entryPoints.websecure.forwardedHeaders.trustedIPs`: Cloudflare IPs.
*   `entryPoints.websecure.proxyProtocol.trustedIPs`: Cloudflare IPs.

**Disabling Bundled Traefik:**
You can pass `--disable=traefik` to the K3s server install command. This is **not recommended** for our setup. `HelmChartConfig` is sufficient and keeps things managed by K3s. Disabling means you are now 100% responsible for installing, upgrading, and managing Traefik yourself.

---
## examples.md Content
**Traefik: Helix Stax Examples**

**Authoritative `HelmChartConfig` for K3s-bundled Traefik**

This is the manifest to apply in the `kube-system` namespace (`/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`) to correctly configure Traefik for the Helix Stax stack.

```yaml
# /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
apiVersion: helm.k3s.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    # -- Enable the dashboard
    dashboard:
      enabled: true
      # Do NOT expose it insecurely here; we will create a secure IngressRoute
      ingressRoute: false

    # -- Enable Prometheus metrics
    metrics:
      prometheus:
        enabled: true
        # Define the entrypoint for scraping.
        entryPoint: metrics

    # -- Enable access logs in JSON format for Loki
    # Note: The correct Helm values path may be `logs.access.enabled` depending on Traefik chart version
    accessLogs:
      general:
        enabled: true
        format: json

    # -- Configure entrypoints
    entryPoints:
      web:
        # HTTP
        address: ":80"
        # Redirect all HTTP to HTTPS
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        # HTTPS
        address: ":443"
        # Trust headers from Cloudflare
        forwardedHeaders:
          # Cloudflare's IPs MUST be populated here. Create a script to keep this updated.
          # See: https://www.cloudflare.com/ips/
          # This is a sample, not the full list.
          trustedIPs:
            - "173.245.48.0/20"
            - "103.21.244.0/22"
            - "103.22.200.0/22"
            # ... and many more
        # Also enable PROXY protocol, which is more secure for getting Real IP
        proxyProtocol:
          trustedIPs:
            - "173.245.48.0/20"
            - "103.21.244.0/22"
            # ... and many more

    # -- Allow CRDs from different namespaces to reference each other
    providers:
      kubernetesCRD:
        allowCrossNamespace: true

    # -- Set default log level
    log:
      general:
        level: INFO # Set to DEBUG for troubleshooting

    # -- Add additional arguments if needed
    additionalArguments:
      # - "--serverstransport.insecureskipverify=false" # Never enable in production
```

**IngressRoute for ArgoCD UI (`argocd.helixstax.net`)**

```yaml
# argocd-ingress-route.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server-ingress
  namespace: argocd # ArgoCD is in the 'argocd' namespace
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      # Note: ArgoCD also requires a PathPrefix route for gRPC-Web
      match: Host(`argocd.helixstax.net`)
      services:
        - name: argocd-server # The name of the ArgoCD server K8s Service
          port: 80 # Or 443 if the service expects TLS
      middlewares:
        - name: zitadel-forward-auth
          namespace: traefik-middlewares
  tls:
    secretName: cloudflare-origin-ca-wildcard-tls
    namespace: kube-system
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-grpc-ingress
  namespace: argocd
spec:
  entryPoints:
  - websecure
  routes:
  - kind: Rule
    match: Host(`argocd.helixstax.net`) && Headers(`Content-Type`, `application/grpc`)
    services:
    - name: argocd-server
      port: 80 # Or 443
      scheme: h2c # Important: tell Traefik the backend is gRPC
    middlewares:
    - name: zitadel-forward-auth # This may need careful handling with gRPC
      namespace: traefik-middlewares
  tls:
    secretName: cloudflare-origin-ca-wildcard-tls
    namespace: kube-system
```

**Security Headers Middleware**

Create this once in `traefik-middlewares` namespace and apply to all public-facing services.

```yaml
# security-headers-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: traefik-middlewares
spec:
  headers:
    frameDeny: true
    contentTypeNosniff: true
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    customFrameOptionsValue: "SAMEORIGIN"
    contentSecurityPolicy: "frame-ancestors 'self'"
```

How to use it:

```yaml
# In an IngressRoute's spec.routes entry
middlewares:
  - name: security-headers
    namespace: traefik-middlewares
  - name: zitadel-forward-auth
    namespace: traefik-middlewares
```

***

# Helm

## SKILL.md Content
**Helm: Your Kubernetes Package Manager**

Helm deploys and manages all applications in our cluster, from Traefik to Grafana. ArgoCD is the GitOps engine that consumes our Helm charts and values from a Git repository to enforce cluster state. We use Helm 3.

**CLI Reference (Day-to-day)**

```bash
# Preview what changes a 'helm upgrade' would make
# helm-diff plugin is required: 'helm plugin install https://github.com/databus23/helm-diff'
helm diff upgrade --install grafana prometheus-community/kube-prometheus-stack -f values.yaml -n monitoring

# Install or upgrade a chart (ArgoCD does this, but you can do it manually)
helm upgrade --install grafana prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version 50.0.0 \
  -f helm/kube-prometheus-stack/values-prod.yaml

# Check the status of a deployed release
helm list -n monitoring

# Get the user-supplied values for a release
helm get values grafana -n monitoring

# See the revision history of a release
helm history grafana -n monitoring

# Roll back to a previous version if something breaks
helm rollback grafana 1 -n monitoring --dry-run
helm rollback grafana 1 -n monitoring
```

**Configuration Patterns**

*   **GitOps Workflow:** All chart deployments are defined as ArgoCD `Application` manifests. NEVER run `helm install/upgrade` directly on the production cluster. Changes are made via Git commit to the `helm/` directory, which triggers an ArgoCD sync.
*   **Values Management:**
    *   Base `values.yaml` comes from the chart (`helm show values ...`).
    *   Our overrides are in `helm/<chart-name>/values-prod.yaml`.
    *   **NO SECRETS IN VALUES.** Values should reference K8s secrets created by External Secrets Operator (ESO). E.g., `existingSecret: "postgresql-auth"`.
*   **K3s Bundled Charts:** We do not manage Traefik with Helm directly. We use the `HelmChartConfig` CRD to inject values into the K3s-managed Helm release.
*   **Dependencies:** Chart dependencies are managed via `Chart.yaml` and `helm dependency build`. We prefer deploying dependencies as separate ArgoCD Applications with sync waves for better lifecycle control.

**Troubleshooting Decision Tree**

*   **Symptom:** ArgoCD sync fails with "rendered manifest already exists".
    *   **Cause:** You (or something else) created a resource outside of GitOps that Helm is now trying to manage.
    *   **Fix:** Add the annotation `argocd.argoproj.io/sync-options: Prune=false` temporarily, or delete the conflicting manual resource. Best fix: find the conflicting resource, import it into Terraform/GitOps, and try again.
*   **Symptom:** `helm template` works but `helm install --dry-run` fails.
    *   **Cause:** `helm install --dry-run` validates against the Kubernetes API server. `template` does not. You are likely trying to create a resource that is invalid for your K8s version or uses a CRD that isn't installed.
    *   **Fix:** Check that all required CRDs are installed first (e.g., using a `sync-wave: "-1"` in ArgoCD).
*   **Symptom:** Pod fails to start after `helm upgrade`, complains about missing secret.
    *   **Cause:** The chart depends on a secret from ESO. Your Helm deployment/ArgoCD sync ran before ESO had time to pull the secret from OpenBao and create the K8s `Secret`.
    *   **Fix:** Use ArgoCD sync waves. ESO should be in an early wave (`-2`), your application chart in a later wave (`0`).

---
## reference.md Content
**Helm: Deep Reference**

### HE-1. Helm CLI Reference

*   `helm install [NAME] [CHART]`: Deploy a chart.
    *   `--values, -f [FILE]`: Specify a values file. Can be used multiple times.
    *   `--set [KEY=VALUE]`: Override a single value.
    *   `--version [VERSION]`: Specify an exact chart version.
    *   `--namespace, -n [NS]`: Specify the namespace.
    *   `--create-namespace`: Create the namespace if it doesn't exist.
    *   `--dry-run`: Simulate an install.
    *   `--atomic`: If the install fails, roll back to the previous state.
    *   `--wait`: Wait until all pods/services are ready before marking release as successful.
*   `helm upgrade [RELEASE] [CHART]`: Upgrade a release. Flags are similar to install.
    *   `--install`: If the release does not exist, run an install.
    *   `--reuse-values`: Reuse the last-release's values.
*   `helm rollback [RELEASE] [REVISION]`: Roll back to a specific revision.
*   `helm template [NAME] [CHART]`: Render templates locally.
*   `helm diff upgrade [RELEASE] [CHART]`: (Plugin) Shows a diff of what `upgrade` would change. Invaluable.
*   `helm get all [RELEASE]`: Show all information about a release.
*   `helm repo add [NAME] [URL]`: Add a chart repository.
*   `helm repo update`: Update information of available charts from repos.
*   `helm search repo [KEYWORD]`: Search for charts in your added repos.
*   `helm push [CHART_PACKAGE] [OCI_REPO]`: Push a chart to an OCI registry like Harbor.
*   `helm registry login [OCI_REPO]`: Login to an OCI registry.

### HE-2. Chart Development

*   **`Chart.yaml`**:
    *   `apiVersion`: `v2` (for Helm 3 charts).
    *   `name`: Chart name.
    *   `version`: Chart's semantic version.
    *   `appVersion`: The version of the application the chart deploys.
    *   `dependencies`: `[]Dependency` - A list of subcharts.
        *   `name`: subchart name.
        *   `version`: subchart version.
        *   `repository`: URL to the chart repo (can be `oci://`).
        *   `condition`: A values path that must be true for this dependency to be enabled (e.g., `my-subchart.enabled`).
*   **Template Functions**:
    *   **`{{ .Values.path.to.value }}`**: Accessing values.
    *   **`{{ include "mychart.helpers.templateName" . }}`**: Renders a named template from `_helpers.tpl`.
    *   **`{{- ... -}}`**: The hyphen trims whitespace.
    *   **`nindent <N>`**: Indents a block of text by N spaces.
    *   **`toYaml`**: Converts a map/dict to a YAML string.
    *   **Pattern for injecting multi-line YAML:**
        ```yaml
        data:
          config.yaml: |
            {{- .Values.myConfig | toYaml | nindent 12 }}
        ```
*   **Hooks**: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, etc. defined as regular K8s manifests with a `helm.sh/hook` annotation. **Note:** ArgoCD's default sync behavior does not run Helm hooks. It requires special configuration (sync hooks or `helm` type application). We prefer ArgoCD sync waves for ordering.

### HE-5. K3s-Specific Helm Patterns

*   **`HelmChart` CRD (`helm.k3s.io/v1`):** A CRD used by K3s to manage a Helm release. K3s creates one for each of its bundled components (Traefik, CoreDNS, etc.). You can also create your own and drop them in `/var/lib/rancher/k3s/server/manifests/` for auto-deployment.
    *   `spec.chart`: e.g., `traefik`.
    *   `spec.repo`: e.g., `https://traefik.github.io/charts`.
    *   `spec.targetNamespace`: e.g., `kube-system`.
    *   `spec.valuesContent`: String containing `values.yaml` content.
*   **`HelmChartConfig` CRD (`helm.k3s.io/v1`):** A CRD *specifically* for overriding values of a K3s-managed `HelmChart`. It is a simpler, targeted CRD that only contains `spec.valuesContent`. K3s merges these values on top of the base `HelmChart` values. **This is our method for configuring Traefik.**

### HE-6. ArgoCD Integration

ArgoCD is the "helm CLI" for our GitOps workflow.

*   **ArgoCD `Application` Manifest:**
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: grafana
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: 'https://github.com/helix-stax/infra.git'
        targetRevision: HEAD
        path: helm/kube-prometheus-stack
        helm:
          valueFiles:
            - values-prod.yaml
          version: 'v3'
          releaseName: grafana
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: monitoring
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
    ```
*   **Sync Waves:** Control installation order. Lower numbers go first.
    ```yaml
    metadata:
      annotations:
        argocd.argoproj.io/sync-wave: "-5" # Install CRDs first
    # Example order for our stack:
    # -5: CRD charts (cert-manager, CloudNativePG, Traefik CRDs if separate)
    # -2: Core infra (ESO, Traefik, cert-manager)
    #  0: (Default) Most applications
    # +2: Apps that depend on others (e.g., a webapp that needs a DB from CNPG)
    ```
*   **App of Apps Pattern:** The root of our GitOps. A single ArgoCD `Application` deploys a Helm chart that contains templates for all other ArgoCD `Application` manifests. This bootstraps the entire cluster.

---
## examples.md Content
**Helm: Helix Stax Examples**

**Adding Our Upstream Repositories**

Run these commands on a local machine to interact with the charts. ArgoCD will have these repositories configured in its settings.

```bash
# Add main repos we use
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo add traefik https://traefik.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts
helm repo add crowdsec https://crowdsec-charts.storage.googleapis.com/
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts # For Velero

# Update all repos
helm repo update
```

**OCI Login for Harbor**

```bash
# Get credentials from Harbor UI
helm registry login harbor.helixstax.com --user myuser --password-stdin <<< "MySuperSecretPassword"
```

**ArgoCD Application for `cloudnative-pg` with Sync Wave**

This should be one of the first things deployed by the "App of Apps".

```yaml
# apps/cnpg.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudnative-pg
  namespace: argocd
  annotations:
    # Install this very early, as many other services need it
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: 'https://cloudnative-pg.github.io/charts' # Public chart repo
    chart: 'cloudnative-pg'
    targetRevision: '2024.3' # Pin to a specific version
    helm:
      releaseName: cnpg
      # We provide overrides from OUR git repo
      # This requires multi-source application feature in ArgoCD 2.6+
      # For older versions, values would need to be inlined or in the same repo
      # For now, let's assume we inline for simplicity:
      values: |
        # Example value overrides
        monitoring:
          enabled: true
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: cnpg-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**`values-prod.yaml` for a Service Referencing ESO Secrets**

This example is for a hypothetical application chart (`my-app`) that needs a database connection. The `cloudnative-pg` `Cluster` has created a secret named `my-app-db-credentials`.

```yaml
# helm/my-app/values-prod.yaml

# Do not use the chart's built-in PostgreSQL
postgresql:
  enabled: false

# Configure the app to use the external database
appConfig:
  database:
    host: "pg-cluster-rw.database.svc.cluster.local" # CNPG service name
    port: 5432
    name: "myappdb"
    # *** THIS IS THE CRITICAL PATTERN ***
    # We reference an existing secret, not raw values.
    # The chart must support `existingSecret` or a similar pattern.
    username: "app_user" # This can be public
    # The chart's template would use envFrom: secretRef: existingSecret
    existingSecret: "my-app-db-credentials"

# If the chart doesn't support existingSecret, you have to map keys manually:
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-app-db-credentials # Secret created by CNPG/ESO
        key: password # Key within that secret
```
