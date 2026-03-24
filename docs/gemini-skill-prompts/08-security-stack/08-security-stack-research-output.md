Of course. Here is the comprehensive research document for your security stack, structured for your AI agents and ready to be split into skill files.

# NeuVector

This document provides a comprehensive reference for configuring, troubleshooting, and optimizing NeuVector in the Helix Stax K3s environment.

## SKILL.md Content

### Overview
NeuVector is our runtime container security platform. It provides deep packet inspection (DPI), process-level microsegmentation, and vulnerability scanning for running containers within the K3s cluster. It is the final layer of defense, observing what is actually happening inside the cluster.

### Architecture & K3s Quick Reference
- **Controller**: Manages the cluster, rules, and agents. Deployed as a `Deployment` with 3 replicas for HA.
- **Enforcer**: The agent running as a privileged `DaemonSet` on each node (`178.156.233.12`, `5.78.145.30`). Intercepts network traffic and monitors process/file activity.
- **Manager**: The web UI and API endpoint. Deployed as a `Deployment`.
- **Scanner**: Scans images for vulnerabilities. Deployed as a `Deployment`.
- **Updater**: Downloads updated CVE database definitions. Deployed as a `CronJob`.
- **K3s Socket Path**: NeuVector must be configured to use the K3s containerd socket at `/run/k3s/containerd/containerd.sock`.

### CLI and REST API Quick Reference
**Setup (one-time):**
```bash
# Get the admin password from the secret
ADMIN_PASS=$(kubectl get secret neuvector-secret -n neuvector -o jsonpath='{.data.password}' | base64 -d)

# Get the Manager service ClusterIP
MANAGER_IP=$(kubectl get svc neuvector-service-webui -n neuvector -o jsonpath='{.spec.clusterIP}')
MANAGER_URL="https://127.0.0.1:8443" # Use kubectl port-forward for local access

# Login (stores token in ~/.nv/token)
# (Inside a pod or with port-forwarding to the Manager service)
kubectl port-forward -n neuvector svc/neuvector-service-webui 8443:8443 &
neuvector-cli -s "https://127.0.0.1:8443" -u admin -p "$ADMIN_PASS" --insecure login  # Only for localhost port-forward. Never use against production endpoints.
```

**Common CLI Operations:**
```bash
# Scan a running container
neuvector-cli scan container default my-pod-name my-container-name

# Scan an image from our Harbor registry
neuvector-cli scan registry harbor.helixstax.net/production/my-app:v1.2.3

# Export all security rules to a file for GitOps
neuvector-cli export policy --file neuvector-policies.json

# Import rules from a file (use with caution)
neuvector-cli import policy --file neuvector-policies.json

# List active network connections for a workload
neuvector-cli get connection --workload default:deployment:my-app
```

### Runtime Security Policies
- **Discover Mode**: The default mode. NeuVector learns network connections, processes, and file access. It does not block anything. Use this for the first 24-48 hours of a new application.
- **Monitor Mode**: All learned rules from Discover mode are baselined and locked. Any new, unlearned behavior triggers an alert but is *not blocked*. Use this to validate the learned profile.
- **Protect Mode**: Any behavior that violates the established policy is blocked and alerted. This is the production-ready mode.

**Switching a Group to Protect Mode:**
1.  In the NeuVector UI, go to `Policy > Groups`.
2.  Find the group (e.g., `nv.traefik-proxy.traefik`).
3.  Change the "Mode" dropdown to `Protect`.
4.  A popup will appear showing the Process and Network rules that will be enforced. Review and click "Confirm".

### Troubleshooting Decision Tree
- **Symptom**: Pods cannot connect to each other, getting "Connection Refused" or timeouts.
  - **Cause**: The service group is in `Protect` mode and the network rule allowing the connection is missing.
  - **Fix**: Check `Security Events > Network Violations`. If the denied connection is legitimate, go to `Policy > Groups`, select the source/destination group, and add the required network rule. Switch the group to `Monitor` mode temporarily if causing an outage.

- **Symptom**: Pod fails to start with `CrashLoopBackOff` after being deployed.
  - **Cause**: The Admission Control webhook is blocking the pod due to a policy violation (e.g., critical CVEs).
  - **Fix**: Check NeuVector `Notifications > Admission Control` logs. The reason for denial will be there. Either fix the image vulnerability, adjust the admission control rule, or create a targeted exception.

- **Symptom**: NeuVector Enforcer pods are not running on a node.
  - **Cause**: K3s node is tainted, or a resource issue prevents scheduling. The `containerd` socket path might be wrong in the Helm chart `values.yaml`.
  - **Fix**: Run `kubectl describe pod -n neuvector neuvector-enforcer-pod-xxxxx`. Check `Events`. Verify the `runtime.socket` path in the Helm chart config is correct for K3s: `/run/k3s/containerd/containerd.sock`.

### Integration Points
- **Kyverno**: Kyverno enforces manifest policies (e.g., must use Harbor registry). NeuVector's admission controller enforces image content policies (e.g., no critical CVEs). They work together. NeuVector's webhook should be configured to run after Kyverno's if ordering is critical, but they generally handle separate concerns.
- **Harbor**: NeuVector can connect to `harbor.helixstax.net` to scan images in the registry *before* they are deployed. This is configured under `Assets > Registries`.
- **Zitadel**: NeuVector Manager UI login is integrated with Zitadel via OIDC for SSO.
- **Prometheus**: NeuVector exposes a `/metrics` endpoint. We scrape this with Prometheus for dashboards and alerting on policy violations.

---

## reference.md Content

### A1. Architecture & Deployment on K3s

#### Component Roles
- **Controller**: The brain. Manages policy, state, and coordinates with other components. It's stateful and must be deployed with a PVC. For HA, a `Deployment` with 3 replicas is used.
- **Enforcer**: The agent. A privileged `DaemonSet` that runs on every K3s node. It uses kernel-level hooks (`/proc`) to monitor processes, file activity, and network connections for all containers on the host. Its privileged status is non-negotiable for it to function.
- **Manager**: The UI/API gateway. A stateless `Deployment`. It authenticates users (via local DB or OIDC/SAML) and provides access to the Controller's data.
- **Scanner**: A stateless `Deployment`. It can be scaled independently. It pulls image layers and scans them for vulnerabilities using its CVE database.
- **Updater**: A `CronJob` that periodically fetches the latest CVE database from SUSE/NeuVector and makes it available to the Scanner pods.

#### K3s Specifics
- **Privileged Mode**: The `neuvector` namespace must be exempted from Pod Security Standards. Label the namespace: `pod-security.kubernetes.io/enforce: privileged`. This allows the Enforcer DaemonSet to run as privileged.
- **Containerd Socket**: The K3s containerd socket path is non-standard. This must be specified in the Helm chart `values.yaml`.
  ```yaml
  k3s:
    enabled: true # This sets the correct socket path automatically in recent chart versions
  
  # Or manually:
  crio:
    enabled: false
  containerd:
    enabled: true
    socket: /run/k3s/containerd/containerd.sock
    runtime: /run/k3s/containerd/containerd.sock
  ```
- **CRD-based Configuration**: It is **critical** to use CRDs for configuration (`NeuVectorSecurityRule`, `NeuVectorComplianceProfile`, etc.). Configuration made via the UI is stored in the Controller's internal state and can be lost during major upgrades or disaster recovery. Export UI-generated rules and commit them to git as CRDs.

#### Air-Gapped Deployment
To run in an air-gapped environment using Harbor:
1.  Mirror all NeuVector component images to `harbor.helixstax.net/neuvector/`.
2.  In `values.yaml`, set the `registry` key to `harbor.helixstax.net`.
3.  Disable the Updater `CronJob` (`updater.enabled: false`).
4.  Manually download the CVE database updates, push them to an internal web server, and configure the Scanner to pull from that internal URL.

### A2. NeuVector CLI / REST API

The `neuvector-cli` tool is a wrapper around the REST API.

#### Login and Session Management
A successful login call to the `/v1/auth` endpoint returns a JWT token with a default expiry. The CLI tool caches this token at `~/.nv/token`.
```bash
# Obtain token directly with curl
ADMIN_PASS="..."
MANAGER_IP="..."
TOKEN_DATA=$(curl -k -X POST -H "Content-Type: application/json" \
  -d "{\"password\": {\"username\": \"admin\", \"password\": \"$ADMIN_PASS\"}}" \
  "https://$MANAGER_IP:8443/v1/auth")
TOKEN=$(echo $TOKEN_DATA | jq -r .token.token)

# Use token for subsequent API calls
curl -k -H "X-Auth-Token: $TOKEN" "https://$MANAGER_IP:8443/v1/scan/container/default/pod/container"
```

#### API Endpoints (Common)
- `GET /v1/policy/rule`: List all security rules.
- `POST /v1/policy/rule`: Create a new rule.
- `GET /v1/scan/registry/{registry_name}/images`: List images in a configured registry.
- `POST /v1/scan/registry`: Trigger a scan of a registry image.
- `GET /v1/log/threat`: Get threat/violation logs.
- `GET /v1/log/event`: Get general events.
- `GET /v1/compliance/profile/{name}`: Get compliance report results.

#### Exporting/Importing Policies for GitOps
This is the core of Policy-as-Code with NeuVector.
```bash
# Export the ENTIRE configuration (groups, rules, etc.)
neuvector-cli export config --file neuvector-config-backup.yaml

# Export ONLY policy rules (network, process)
neuvector-cli export policy --file neuvector-policies.json

# Import policy rules (replaces existing rules)
# DANGER: This is a destructive operation.
neuvector-cli import policy --file neuvector-policies.json --replace
```

### A3. Runtime Security Policies

- **Groups**: NeuVector automatically creates groups based on Kubernetes namespaces and deployments (e.g., `nv.traefik.deployment.traefik`). Custom groups can be created using `namespace` and `label` selectors for more granular policy.
- **Process Profile Rules**: NeuVector learns every process that runs in a container. In Monitor/Protect mode, any process not on the allowlist will be flagged/blocked.
  - Example: A container that normally runs `nginx` and `sh` suddenly spawns `nmap`. This would be blocked.
- **File Access Monitoring**: NeuVector can monitor for sensitive file access. Rules can be created to alert or block on read/write access to paths like `/etc/passwd`, `/etc/shadow`, or custom paths like `/app/secrets`.
- **Sidecars**: NeuVector sees sidecar containers (e.g., Linkerd) as separate processes within the same pod networking namespace. It will automatically learn the traffic between the main container and the sidecar (e.g., app -> linkerd-proxy over localhost) and the traffic from the sidecar to the outside. These learned rules must be included in the final policy.

### A4. Deep Packet Inspection (DPI)

- **Supported Protocols**: HTTP, HTTPS (requires certs for MITM), gRPC, Redis, PostgreSQL, MySQL, MongoDB, Kafka, Zookeeper, Couchbase, DNS, SSL/TLS, SSH, and more.
- **L7 Rule Syntax**: Rules are built in the UI. For an HTTP rule, you can specify:
  - `Host`: `helixstax.com`
  - `Path`: `/api/v1/users` (supports regex)
  - `Methods`: `GET`, `POST` (block `DELETE`)
- **Performance Impact**: At a small scale (2 nodes), the performance impact of DPI is negligible. The Enforcer is highly optimized. CPU usage may increase by a few percentage points under heavy load with many L7 rules.
- **DPI vs. Kyverno NetworkPolicy**:
  - **Kyverno `NetworkPolicy`**: Controls L4 traffic (IP/Port) based on pod labels. It can say "Pods with label `app=backend` can connect to pods with label `app=db` on port 5432". It has no visibility into the *content* of the traffic.
  - **NeuVector DPI**: Controls L7 traffic. It can say "Pods with label `app=backend` can send a `SELECT` query to the database, but not a `DROP TABLE` query".
- **Interaction with Traefik**: Traefik terminates TLS from Cloudflare at the edge of the cluster. Traffic from Traefik to backend services is typically plaintext HTTP. NeuVector's Enforcer on the worker node sees this **plaintext** traffic, allowing DPI to work without any complex TLS interception setup.

### A5. Vulnerability Scanning

| Feature | NeuVector Scanner | Trivy (in Harbor) |
| :--- | :--- | :--- |
| **Scope** | Running Containers, Registry Images | Registry Images (at push time) |
| **When** | On-demand, Scheduled, or at Runtime | On push to registry |
| **Authoritative** | **NeuVector is authoritative for runtime.** | **Trivy is authoritative for pre-deploy.** |
| **Coverage** | OS Packages, App Dependencies | OS Packages, App Dependencies |

- **Runtime Scanning**: NeuVector's most powerful feature is scanning a container that is *already running*. This can detect vulnerabilities that were not present when the image was built, or if the CVE database has been updated since the last pre-deploy scan.
- **Admission Control**: NeuVector has a validating admission webhook. A common policy is: "Deny deployment if image has > 0 critical vulnerabilities and > 5 high vulnerabilities". This provides a crucial security gate.
- **Registry Integration**: When NeuVector is configured with Harbor's credentials, the NeuVector UI can browse `harbor.helixstax.net`, trigger scans, and view results directly, centralizing the view of vulnerabilities.

### A6. Compliance Templates

- **Templates**: NeuVector includes pre-built templates for CIS Kubernetes, CIS Docker, NIST 800-190, NIST 800-53, PCI, GDPR, and HIPAA.
- **Running a Scan**: Scans can be triggered from the UI under `Compliance > Scans`. Select the nodes (`helix-stax-cp`, `helix-stax-vps`) and the desired template.
- **Exporting**: Results can be exported as a CSV file. For automated evidence collection, the API endpoint `GET /v1/compliance/profile/{name}` can be used to pull the results in JSON format.
- **UCM Mapping**: The process involves:
  1. Export the NeuVector compliance report (e.g., CIS Kubernetes Benchmark).
  2. For each control in your UCM (e.g., "CIS 1.1 - Ensure API Server logging is enabled"), find the corresponding check in the NeuVector report (e.g., "K8S.5.2.1").
  3. Document the mapping and use the report's pass/fail status as evidence for that control. Combine this with Kyverno `PolicyReport` data for a complete picture.

### A7. NeuVector Admission Control vs. Kyverno

- **Coexistence**: They can and should coexist. Kubernetes supports multiple validating webhooks. Their execution order is not guaranteed unless you have control over the webhook configuration timing.
- **Division of Responsibility**:
  - **Use Kyverno for**: Manifest validation and mutation.
    - "All images must come from `harbor.helixstax.net`."
    - "All deployments must have resource limits."
    - "No `hostPath` mounts."
    - "Add label `team: helix` to all namespaces."
  - **Use NeuVector for**: Image content and runtime-derived policy.
    - "Block images with critical CVEs."
    - "Block images running as root user." (Can also be done by Kyverno, but NeuVector is runtime-aware).
    - "This image is not allowed to be deployed in the `production` namespace" (based on NeuVector group rules).
- **Enforcing Harbor Registry**: Both tools can do this.
  - **Kyverno**: More robust. It validates the `image` field in the manifest *before* the pod is even scheduled. This is the recommended approach.
  - **NeuVector**: Can also do this, but it's more of a secondary check. The image name is part of the admission review data it receives.
- **Conflict Scenarios**: If both Kyverno and NeuVector deny the same pod, the user will receive an error message from whichever webhook responded first. The pod will be rejected. This is not a conflict, but a successful layered defense. The `kubectl describe` on the ReplicaSet will usually show both failure reasons.

### A8. Multi-Cluster and Federation
Even with a single cluster, configuring for federation is a good practice.
- **Primary Cluster**: The cluster where the "master" NeuVector Controller runs. In our case, the K3s cluster (`178.156.233.12`).
- **Remote Cluster**: A secondary cluster that runs its own NeuVector components but is managed by the primary.
- **Setup**:
  1. On the primary cluster, expose the Controller service via a `LoadBalancer` or `Ingress`.
  2. Go to `Settings > Multi-cluster` in the primary UI and generate a join token/YAML.
  3. On the remote cluster, deploy the NeuVector Helm chart with values that configure it as a remote cluster, pointing to the primary's exposed address and using the join token.
- **Policy Sync**: Policies configured on the primary can be automatically synced to all remote clusters, providing centralized management.

### A9. NeuVector + Zitadel Integration

NeuVector supports OIDC for authenticating users to the Manager UI.
- **Protocol**: OIDC is the preferred and supported protocol.
- **Configuration (in NeuVector UI under `Settings > Users & Roles > OIDC`)**:
  1.  Click "Add".
  2.  **Issuer**: `https://zitadel.helixstax.net`
  3.  **Client ID**: The Client ID of the application created in Zitadel for NeuVector.
  4.  **Client Secret**: The corresponding client secret.
  5.  **Scopes**: `openid profile email` are standard. Add `groups` if you want to map roles.
  6.  **Group Mapping**: Enable group claims and map a group from Zitadel (e.g., `neuvector-admins`) to a NeuVector role (e.g., `admin`). This allows for role-based access control managed from Zitadel.

---

## examples.md Content

### K3s Helm `values.yaml` Snippet
This is a partial `values.yaml` for deploying NeuVector via Helm on our K3s cluster.
```yaml
# neuvector-values.yaml
# helm install neuvector -n neuvector --create-namespace -f neuvector-values.yaml neuvector/neuvector-helm

k3s:
  enabled: true # IMPORTANT: This sets the K3s containerd socket path automatically

controller:
  replicas: 3
  pvc:
    enabled: true
    storageClass: "local-path" # Or your preferred StorageClass
    size: 5Gi

manager:
  # Expose Manager via Traefik IngressRoute
  ingress:
    enabled: true
    host: neuvector.helixstax.net
    # tls:
    #   secretName: neuvector-origin-ca-tls
    #   # TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
    path: /
    className: "traefik"

# Connect to our Harbor registry
registry:
  # Used for air-gapped installs and pulling NeuVector images themselves
  name: "harbor.helixstax.net/neuvector" 
  username: "robot$neuvector-pull"
  password: "..."

# Admission Control Webhook Configuration
admissionControl:
  enabled: true
  service:
    type: ClusterIP

# OIDC Integration with Zitadel
oidc:
  enabled: true
  clientID: "your-zitadel-neuvector-client-id"
  clientSecret: "your-zitadel-neuvector-client-secret"
  issuer: "https://zitadel.helixstax.net"  # Internal identity domain
  groupClaim: "groups"
  groupMappings:
    admin:
      - "neuvector-admins" # Group name from Zitadel
    reader:
      - "neuvector-readonly" # Group name from Zitadel
```

### Policy-as-Code: Export and Encrypt Rules
This runbook describes how to export policies, encrypt them with SOPS, and commit to git.
```bash
# 1. Login to NeuVector CLI (see above)
neuvector-cli -s "https://127.0.0.1:8443" ... login

# 2. Export the live policy to a JSON file
neuvector-cli export policy --file neuvector-policies.json

# 3. Encrypt the file using SOPS with age
# Assumes you have a .sops.yaml file configured with age keys
sops --encrypt --in-place neuvector-policies.json

# 4. Commit the encrypted file to your GitOps repository
git add neuvector-policies.json
git commit -m "feat(security): update NeuVector runtime policies"
git push

# 5. ArgoCD can now apply these policies using a tool like helmfile/kustomize
# To decrypt for review:
sops --decrypt neuvector-policies.json > neuvector-policies.decrypted.json
```

### L7 DPI Rule Example (UI steps)
**Goal**: Allow `GET` requests to `/api/health` but block `POST` requests to `/admin` for the `my-app` service.

1.  **Select Group**: In `Policy > Groups`, find the group for `my-app` (e.g., `nv.default.deployment.my-app`).
2.  **Switch to Monitor**: Change the mode to `Monitor`.
3.  **Add Network Rule**:
    - Click the "Add" button in the Network Rules panel.
    - **From**: The group of your ingress controller (e.g., `nv.traefik-proxy.traefik`).
    - **To**: `nv.default.deployment.my-app`.
    - **Ports**: `8080/tcp` (or your app's port).
    - **Application**: Click the dropdown and select `HTTP`.
    - **Add Condition**:
        - `Path` matches `/api/health`, `Methods` matches `GET` -> `Allow`.
        - `Path` matches `/admin`, `Methods` matches `POST` -> `Deny`.
4.  **Save Rule**.
5.  After testing, switch the group to `Protect` mode to enforce the rule.

### Admission Control Rule to Block CVEs
This CRD blocks any pod with more than 0 critical CVEs or 5 high CVEs.
```yaml
apiVersion: "neuvector.com/v1"
kind: "NeuVectorAdmissionRule"
metadata:
  name: "high-severity-cve-block"
  namespace: "neuvector"
spec:
  rules:
    - name: "deny-critical-cves"
      criteria:
        - name: "high_severity_cve_count"
          op: "gt"
          value: "5"
        - name: "critical_severity_cve_count"
          op: "gt"
          value: "0"
      disabled: false
      rule_type: "Deny"
      category: "Vulnerability"
  rule_mode: "Protect"
  name: "default"
  scope: "system"
```
**To apply:** `kubectl apply -f high-severity-cve-block.yaml`

---
# CrowdSec

This document provides a comprehensive reference for configuring, troubleshooting, and optimizing CrowdSec in the Helix Stax K3s environment.

## SKILL.md Content

### Overview
CrowdSec is our network and log-based threat intelligence platform. It reads logs from Traefik, SSH, and K3s audit logs, detects malicious behavior (brute force, scans, exploit attempts), and shares threat intelligence within the community. It blocks attackers at multiple layers: Cloudflare (edge), Traefik (ingress), and the host firewall (SSH, etc.).

### K3s Deployment Quick Reference
- **Architecture**:
    - **LAPI (Local API)**: A `Deployment` in the `crowdsec` namespace. Central brain, stores decisions, serves bouncers. Uses a PVC for its SQLite database.
    - **Agent**: A `DaemonSet` on each node (`178.156.233.12`, `5.78.145.30`). Tails log files and sends events to the LAPI.
- **Log Paths on AlmaLinux 9.7**:
    - **SSH**: `/var/log/secure`
    - **Traefik Access Logs**: Must be configured in Traefik's Helm chart to write to a file on a `hostPath` volume, e.g., `/var/log/traefik/access.log`.
    - **K3s Audit Logs**: Must be enabled in K3s config and written to a `hostPath` volume, e.g., `/var/lib/rancher/k3s/server/logs/audit.log`.

### CLI Reference (`cscli`) - The Essentials
**Setup (exec into LAPI pod):**
```bash
LAPI_POD=$(kubectl get pods -n crowdsec -l app.kubernetes.io/name=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n crowdsec $LAPI_POD -- bash
```

**Common Operations:**
```bash
# See active decisions (bans)
cscli decisions list

# Manually ban an IP
cscli decisions add --ip 1.2.3.4 --reason "manual ban"

# Remove a ban
cscli decisions delete --ip 1.2.3.4

# List all alerts
cscli alerts list

# Install a new collection (ruleset)
cscli collections install crowdsecurity/nginx # Good for general http scanning

# Update all installed items from the hub
cscli hub update
cscli hub upgrade

# Register a new bouncer and get its API key
cscli bouncers add traefik-bouncer-1

# Check if log files are being read
cscli metrics
# Look for non-zero lines processed in the parsers section
```

### Bouncer Strategy
1.  **Cloudflare Bouncer**: The first line of defense. Blocks attackers at Cloudflare's edge before they ever reach our infrastructure.
2.  **Traefik Bouncer**: The second line. A Traefik Middleware that blocks requests at the ingress controller.
3.  **Firewall Bouncer (nftables)**: The third line. Runs on each host, blocks non-HTTP traffic like SSH attacks, and serves as a failsafe if the upper layers fail.

### Troubleshooting Decision Tree
- **Symptom**: Legitimate user is blocked.
  - **Cause**: False positive. Their IP is in the CrowdSec decision list.
  - **Fix**: Identify their IP address. Run `cscli decisions delete --ip <USER_IP>`. To prevent recurrence, investigate the alert (`cscli alerts list -ip <USER_IP>`) and consider whitelisting their IP range or tuning the scenario that triggered the ban.

- **Symptom**: Attacks are not being blocked.
  - **Cause 1**: Bouncer is not connected to the LAPI.
  - **Fix 1**: Check bouncer logs. Run `cscli bouncers list` to see the last pull time. Ensure the LAPI service URL (`http://crowdsec-lapi.crowdsec.svc.cluster.local:8080`) is reachable from the bouncer pod/host and the API key is correct.
  - **Cause 2**: Logs are not being parsed.
  - **Fix 2**: Run `cscli metrics`. Check if the relevant log source shows `lines_processed`. If not, verify the log file path is correctly mounted into the agent pod and the `ConfigMap` for acquisitions is correct. Use `cscli explain --log "log line"` to debug parsing.
  - **Cause 3 (Cloudflare specific)**: CrowdSec is banning the Cloudflare edge IP instead of the real visitor IP.
  - **Fix 3**: Ensure the `crowdsecurity/cloudflare-whitelists` collection is installed and the Traefik log parser is configured to use the `CF-Connecting-IP` header.

### Integration Points
- **Traefik**: We use the `crowdsec-bouncer-traefik-plugin` and configure it via a `Middleware` CRD. It's critical to configure Traefik to output a predictable JSON log format.
- **Cloudflare**: The Cloudflare bouncer uses the Cloudflare API to add malicious IPs to an IP List, which is then used in a WAF rule to block traffic. This is highly effective.
- **Prometheus**: CrowdSec LAPI exposes a `/metrics` endpoint for Prometheus to scrape, allowing us to monitor `cs_active_decisions`, `cs_parser_hits`, etc.
- **n8n / Rocket.Chat**: The HTTP notification plugin can be configured to send a webhook to our n8n instance whenever a new ban decision is made, which then formats and posts a message to the `#security` channel in Rocket.Chat.

---

## reference.md Content

### B1. K3s-Specific Deployment

#### Architecture
For a 2-node K3s cluster, the standard architecture is ideal:
- **LAPI**: 1 `Deployment` with 1 replica in the `crowdsec` namespace. It should use a `PersistentVolumeClaim` to store the SQLite database. For larger setups, an external PostgreSQL database is recommended.
- **Agent**: 1 `DaemonSet` ensuring an agent pod runs on both the control-plane (`178.156.233.12`) and the worker (`5.78.145.30`).

#### Helm Chart Configuration (`crowdsec/crowdsec`)
```yaml
# values.yaml snippet
agent:
  acquisition:
    # This ConfigMap should contain the acq.yaml content
    - configMap:
        name: crowdsec-acquisitions
        # file key in the configmap
        mountKey: acq.yaml
  
  # Mount host log directories into the agent pods
  container:
    volumeMounts:
      - name: varlog
        mountPath: /var/log/host/
      # Add more mounts for specific log locations
      - name: k3s-audit-log
        mountPath: /var/log/k3s/

volumes:
  - name: varlog
    hostPath:
      path: /var/log/
  - name: k3s-audit-log
    hostPath:
      path: /var/lib/rancher/k3s/server/logs/

lapi:
  # LAPI needs to know agent credentials
  # These must match the agent's config
  env:
    - name: "AGENTS_USER"
      valueFrom:
        secretKeyRef:
          name: "crowdsec-lapi-secrets"
          key: "AGENTS_USER"
    - name: "AGENTS_PASSWORD"
      valueFrom:
        secretKeyRef:
          name: "crowdsec-lapi-secrets"
          key: "AGENTS_PASSWORD"
  
  # Use a PVC for the database
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 1Gi
```

#### SELinux on AlmaLinux
SELinux may block the CrowdSec agent from reading host log files.
- **Symptom**: `ausearch -c crowdsec -m avc` shows `denied` messages.
- **Quick Fix (for testing)**: `setenforce 0` on the host node. **DO NOT USE IN PRODUCTION.**
- **Proper Fix**: Generate an SELinux policy module.
  1.  Put SELinux in permissive mode: `setenforce 0`.
  2.  Run CrowdSec and exercise its log reading functions.
  3.  Use `audit2allow` to create a policy from the generated denials:
      ```bash
      grep crowdsec /var/log/audit/audit.log | audit2allow -M crowdsec_local
      semodule -i crowdsec_local.pp
      ```
  4.  Re-enable enforcing mode: `setenforce 1`.

### B2. CLI Reference (`cscli`)

(Exec into LAPI pod: `kubectl exec -it -n crowdsec <lapi-pod> -- bash`)

| Command | Description | Example |
| :--- | :--- | :--- |
| **Decisions** | | |
| `cscli decisions list` | Show all active decisions (bans, captchas). | `cscli decisions list -ip 1.2.3.4` |
| `cscli decisions add` | Manually add a decision. | `cscli decisions add -t ban -i 1.2.3.4 --duration 24h` |
| `cscli decisions delete` | Remove a decision. | `cscli decisions delete --all` or `-i 1.2.3.4` |
| **Alerts** | | |
| `cscli alerts list` | Show all triggered alerts. | `cscli alerts list --since 1h` |
| `cscli alerts inspect` | Show details of a specific alert. | `cscli alerts inspect 12345` |
| **Bouncers** | | |
| `cscli bouncers list` | List all registered bouncers. | `cscli bouncers list -o json` |
| `cscli bouncers add` | Add a new bouncer, returns an API key. | `cscli bouncers add cloudflare-bouncer` |
| `cscli bouncers delete` | Delete a bouncer. | `cscli bouncers delete traefik-bouncer` |
| **Hub** | | |
| `cscli hub update` | Fetch the latest list of items from the hub. | `cscli hub update` |
| `cscli hub upgrade` | Upgrade all installed items to their latest versions. | `cscli hub upgrade` |
| **Collections** | | |
| `cscli collections list` | List available/installed collections. | `cscli collections list -a` |
| `cscli collections install` | Install a collection (parser+scenario). | `cscli collections install crowdsecurity/sshd` |
| `cscli collections remove`| Uninstall a collection. | `cscli collections remove crowdsecurity/sshd` |
| **Metrics** | | |
| `cscli metrics` | Show detailed metrics for all components. | `cscli metrics` |

### B3. Collections for Our Stack
```bash
# Exec into LAPI pod
LAPI_POD=$(kubectl get pods -n crowdsec -l app.kubernetes.io/name=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n crowdsec $LAPI_POD -- bash

# Install the necessary collections
cscli collections install crowdsecurity/linux         # Base linux logs (journald)
cscli collections install crowdsecurity/sshd          # SSH brute-force, etc.
cscli collections install crowdsecurity/traefik       # Traefik log parsing & scenarios
cscli collections install crowdsecurity/http-cve-tests # Detects probes for common CVEs
cscli collections install LePresidente/k8s-audit      # Collection for K8s audit logs
cscli collections install crowdsecurity/cloudflare-whitelists # CRITICAL for our setup

# Update everything
cscli hub update && cscli hub upgrade
```
**To verify a collection is working**: Run `cscli metrics`, find the parser associated with the collection, and check that `hits` and `parsed` are increasing.

### B4. Bouncers Breakdown

#### Cloudflare Bouncer
- **Method**: Runs as a `Deployment` in the cluster. Uses the Cloudflare API to manage an IP List named `crowdsec`. A Cloudflare WAF rule then blocks any request from an IP on that list.
- **Config**: Deployed via Helm chart `crowdsec/crowdsec-cloudflare-bouncer`.
- **Key `values.yaml` settings**:
  ```yaml
  cloudflare:
    token: "YOUR_CLOUDFLARE_API_TOKEN" # Scoped to edit WAF
    zone_id: "YOUR_ZONE_ID_FOR_HELIXSTAX.COM"
    account_id: "YOUR_CLOUDFLARE_ACCOUNT_ID"
  
  crowdsec:
    lapi_url: http://crowdsec-lapi.crowdsec.svc.cluster.local:8080
    api_key: "KEY_FROM_CSCLI_BOUNCERS_ADD"
  ```

#### Traefik Bouncer
- **Method**: Runs as a `Deployment`. Implements the Traefik `forwardAuth` middleware. Traefik asks the bouncer if an incoming request's IP is banned before forwarding to the backend service.
- **Key `values.yaml` settings**:
  ```yaml
  # In crowdsec-traefik-bouncer helm chart
  forwardAuth:
    enabled: true
    # This header MUST be set in your Traefik config
    # to trust the real IP from Cloudflare
    trustedIPs:
      - "172.16.0.0/12" # Cluster internal IPs
      - "10.42.0.0/16" # K3s Pod CIDR
      - "10.43.0.0/16" # K3s Service CIDR
      - "178.156.233.12"
      - "5.78.145.30"
  
  env:
    - name: CROWDSEC_LAPI_URL
      value: "http://crowdsec-lapi.crowdsec.svc.cluster.local:8080"
    - name: CROWDSEC_LAPI_KEY
      value: "KEY_FROM_CSCLI_BOUNCERS_ADD"
    - name: CROWDSEC_BOUNCER_LOG_LEVEL
      value: "info"
  ```
- **Traefik `Middleware` CRD**:
  ```yaml
  apiVersion: traefik.containo.us/v1alpha1
  kind: Middleware
  metadata:
    name: crowdsec-auth
    namespace: default
  spec:
    forwardAuth:
      address: http://crowdsec-traefik-bouncer.crowdsec.svc.cluster.local:8080/api/v1/forwardAuth
      trustForwardHeader: true
      authResponseHeaders:
        - X-Forwarded-User
  ```
- **Apply to `IngressRoute`**:
  ```yaml
  # In IngressRoute spec:
  routes:
    - kind: Rule
      match: Host(`app.helixstax.com`) && PathPrefix(`/`)
      middlewares:
        - name: crowdsec-auth
          namespace: default # MUST match middleware namespace
      services:
        - name: my-app-service
          port: 80
  ```

#### Firewall Bouncer (`nftables`)
- **Method**: Runs as a systemd service directly on the AlmaLinux hosts (`178.156.233.12`, `5.78.145.30`).
- **Installation**:
  ```bash
  # On each host
  sudo dnf install crowdsec-firewall-bouncer-nftables
  ```
- **Configuration (`/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`)**:
  ```yaml
  mode: nftables
  pid_dir: /var/run/crowdsec/
  update_frequency: 10s
  daemonize: true
  log_mode: file
  log_dir: /var/log/
  log_level: info
  api_url: http://<K3S_NODE_IP>:3XXXX # Use NodePort or HostPort for LAPI
  api_key: "KEY_FROM_CSCLI_BOUNCERS_ADD"
  # ...
  ```
  *Note: A `NodePort` or `HostPort` service for the LAPI is required for the host-based bouncer to connect to it.*
- **Verification**: `sudo nft list ruleset | grep crowdsec`

### B5. Cloudflare IP Whitelisting & Parsers

**CRITICAL**: Since all traffic comes from Cloudflare, we must configure CrowdSec to:
1.  **Trust Cloudflare IPs**: Never ban a Cloudflare server.
2.  **Use the Real Visitor IP**: Look at the `CF-Connecting-IP` header.

**Configuration**:
1.  **Install Cloudflare Whitelists**:
    `cscli collections install crowdsecurity/cloudflare-whitelists`
    This collection downloads Cloudflare's official IP ranges and adds them to a whitelist, preventing the firewall bouncer from ever blocking them.

2.  **Configure Log Acquisition for Traefik**:
    In your acquisitions `ConfigMap`, you must tell the `traefik` parser to use the forwarded-for header.
    ```yaml
    # acq.yaml in ConfigMap crowdsec-acquisitions
    ---
    filenames:
      - /var/log/host/traefik/access.log
    labels:
      type: traefik
    use_time_machine: true
    # This tells the parser to get the IP from the header
    # provided by traefik's proxyProtocol or forwardAuth settings
    # Ensure Traefik is configured to populate this!
    source: http
    ```
    In `parsers/s02-enrich/crowdsec-enrich.yaml`, ensure `use_forwarded_for_headers` is true (it is by default).

3.  **Parsers for Our Stack**:
    - **Traefik**: The `crowdsecurity/traefik` collection provides this. It expects a standard log format.
    - **SSH on AlmaLinux**: The `crowdsecurity/sshd` collection looks for `/var/log/auth.log` by default. We need a symlink or a custom acquistion file pointing to `/var/log/secure`.
      ```yaml
      # In acq.yaml
      filenames:
        - /var/log/host/secure # Mapped from /var/log/secure on host
      labels:
        type: syslog
      ```
    - **K3s Audit Logs**: The `LePresidente/k8s-audit` collection is designed for this. K3s audit logs are JSON-formatted and must be enabled with flags like `--audit-log-path`. The parser needs to be configured for this source.

    - **Testing Parsers**: `cscli explain --log "PASTE_LOG_LINE_HERE" --type traefik`

### B7. Metrics, Monitoring & Troubleshooting

- **Prometheus Endpoint**: Enable in the LAPI Helm chart `values.yaml`:
  ```yaml
  lapi:
    prometheus:
      enabled: true
  ```
  The LAPI service will expose metrics on port `6060/tcp` at the `/metrics` path.
- **Key Metrics**:
  - `cs_lapi_decisions_ko_total`, `cs_lapi_decisions_ok_total`: Decision counts.
  - `cs_active_decisions`: Gauge of currently active bans. A good overview metric.
  - `cs_parser_hits_total{source="<file>"}`: How many lines have been successfully parsed from a given source. If this is 0, your acquisition is misconfigured.
  - `cs_lapi_scenario_triggered_total{scenario="<name>"}`: How many times each scenario has been triggered.
- **Grafana Dashboard**: Official dashboard ID is `13123`.
- **Alertmanager Rules**:
  ```yaml
  groups:
  - name: crowdsec.rules
    rules:
    - alert: CrowdSecNewBan
      expr: increase(cs_lapi_decisions_ok_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "CrowdSec has issued a new ban"
        description: "A new ban has been issued by CrowdSec. Check `cscli decisions list` for details."
    - alert: CrowdsecBouncerOffline
      expr: time() - cs_lapi_bouncer_last_pull_timestamp > 300
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "CrowdSec bouncer {{ $labels.bouncer }} is offline"
        description: "Bouncer {{ $labels.bouncer }} has not pulled updates for 5 minutes."
  ```

---

## examples.md Content

### Traefik Helm `values.yaml` for CrowdSec
To make Traefik work with CrowdSec, it needs to:
1.  Output access logs to a file on the host.
2.  Use a `hostPath` volume to make that file available.
3.  Be configured to trust Cloudflare IPs and set the real IP in a header.

```yaml
# traefik-values.yaml
# ... other traefik config ...

# Proxy protocol or forwarded headers config is crucial.
# This tells Traefik to trust incoming headers from Cloudflare.
# Add Cloudflare IP ranges here.
proxyProtocol:
  trustedIPs:
    - "173.245.48.0/20"
    - "103.21.244.0/22"
    # ... all other Cloudflare ranges

accessLogs:
  enabled: true
  filePath: "/var/log/traefik/access.log"
  format: "json"

# Provide a volume for the log file
persistence:
  enabled: true
  name: traefik-logs
  path: /var/log/traefik/
  # The host path where logs will be written
  hostPath: /mnt/traefik-logs

# Add the middleware to all routers by default
entryPoints:
  websecure:
    # ...
    http:
      middlewares:
        - default-crowdsec-auth@kubernetescrd # Apply middleware globally
```

### CrowdSec `acq.yaml` `ConfigMap`
This is the central configuration telling the CrowdSec agent which logs to read.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: crowdsec-acquisitions
  namespace: crowdsec
data:
  acq.yaml: |
    # Traefik JSON logs
    filenames:
      - /var/log/host/traefik/access.log
    labels:
      type: traefik
    
    ---
    # SSH logs on AlmaLinux
    filenames:
      - /var/log/host/secure
    labels:
      type: syslog
    
    ---
    # K3s Audit Logs
    filenames:
      - /var/log/k3s/audit.log
    labels:
      type: k8s-audit

```

### n8n / Rocket.Chat Alerting Runbook
1.  **Generate a webhook URL in n8n**: Create a new workflow with a "Webhook" trigger node.
2.  **Configure CrowdSec HTTP Notification Plugin**:
    Create `crowdsec-notifications.yaml`:
    ```yaml
    # profile.yaml
    name: default_webhook
    filter: "evt.Meta.log_type == 'decision_add'"
    notifications:
      - http_default
    ---
    # http.yaml
    name: http_default
    type: http
    log_level: info
    
    url: <YOUR_N8N_WEBHOOK_URL>
    method: POST
    headers:
      "Content-Type": "application/json"
    
    format: |
      {
        "text": "CrowdSec Ban Alert",
        "attachments": [{
          "title": "New IP Banned: {{.Decision.Value}}",
          "text": "Reason: {{.Decision.Scenario}}\nDuration: {{.Decision.Duration}}\nType: {{.Decision.Type}}",
          "color": "#FF0000"
        }]
      }
    ```
3.  **Deploy as a secret**: `kubectl create secret generic crowdsec-notifications -n crowdsec --from-file=profile.yaml --from-file=http.yaml`
4.  **Mount the secret into the LAPI pod** via the Helm chart.
5.  **Build n8n workflow**: The webhook node will receive the JSON payload defined in `format`. Use a "Rocket.Chat" node to post the formatted message to the `#security` channel.

### Whitelist for Internal Monitoring
Whitelist the Prometheus/Grafana IPs to prevent them from being banned for legitimate scraping/probing.
```bash
# Exec into LAPI pod
# Create a local yaml file that describes a whitelist
cat <<EOF > /etc/crowdsec/parsers/s02-enrich/helistax-whitelist.yaml
name: helixstax/whitelist
description: "Whitelist internal monitoring and infrastructure IPs"
whitelist:
  reason: "Helix Stax internal services"
  ip:
    - "10.42.0.0/16" # K3s Pod CIDR
    - "10.43.0.0/16" # K3s Service CIDR
    - "178.156.233.12"
    - "5.78.145.30"
EOF

# Reload crowdsec to apply
kill -SIGHUP 1
```

---
# Kyverno

This document provides a comprehensive reference for configuring, troubleshooting, and optimizing Kyverno in the Helix Stax K3s environment.

## SKILL.md Content

### Overview
Kyverno is our Kubernetes policy engine. It acts as a dynamic admission controller, intercepting every request to the K8s API server. We use it to validate, mutate, and generate Kubernetes resources to enforce security best practices and organizational standards *before* anything is allowed to run in the cluster. It is the gatekeeper for our K3s environment.

### CLI Reference (`kyverno CLI`) - The Essentials
**Use Case**: CI/CD pipeline validation. Before running `kubectl apply` or `argocd sync`, we test manifests against our policies.

```bash
# Install Kyverno CLI
# curl -L https://git.io/install-kyverno-cli | sh

# Apply policies to a directory of manifests
# This command will exit with a non-zero code if any resource violates a policy.
kyverno apply /path/to/policies/ --resource /path/to/manifests/

# Get detailed results
kyverno apply policies/ --resource manifests/ -o json

# Test policies using a kyverno-test.yaml manifest
# This is for unit testing the policies themselves.
kyverno test /path/to/policy-tests/
```

### Policy Types Quick Reference
- **Validate**: The workhorse. Checks incoming resources against a set of rules. If a rule fails and is in `Enforce` mode, the resource is rejected.
  - *Example*: Block any Pod that doesn't have CPU/memory limits.
- **Mutate**: Modifies incoming resources. It runs *before* validation.
  - *Example*: Automatically add the label `managed-by: helixstax` to all new Namespaces.
- **Generate**: Creates new resources in response to a trigger.
  - *Example*: When a new Namespace is created, automatically generate a `default-deny` NetworkPolicy within it.
- **VerifyImages**: Verifies image signatures (using Cosign) and attestations.
  - *Example*: Ensure all images deployed to the `production` namespace are signed by our CI key and have a clean Trivy scan attestation from Harbor.

### Policy Enforcement Modes
- **`Enforce`**: The default. Violations are blocked, and an error is returned to the user. Use this for critical security policies.
- **`Audit`**: Violations are allowed, but a warning is logged in the Kyverno logs and a `PolicyReport` entry is created. Use this when rolling out new policies to see their impact without breaking things.

### Troubleshooting Decision Tree
- **Symptom**: `kubectl apply -f myapp.yaml` fails with a long admission webhook error mentioning Kyverno.
  - **Cause**: The manifest for `myapp.yaml` violates a `validate` rule that is in `Enforce` mode.
  - **Fix**: Read the error message carefully. It will state exactly which policy was violated and why (e.g., "validation error: Pod my-app-pod: require-resource-limits: cpu and memory limits are required"). Modify your `myapp.yaml` to comply with the policy and re-apply.

- **Symptom**: A resource was created, but it's not what the original YAML defined.
  - **Cause**: A `mutate` policy modified the resource on its way into the cluster.
  - **Fix**: This is usually expected behavior. To check which policy is responsible, inspect the Kyverno logs or review the `ClusterPolicy` resources (`kubectl get cpol -A`).

- **Symptom**: Pods are stuck in `Pending` state, and `kubectl describe pod` shows nothing useful.
  - **Cause**: The Kyverno webhook might be down or misconfigured, and its `failurePolicy` is set to `Fail`. This means if the API server can't reach Kyverno, all resource creation attempts will fail.
  - **Fix**: Check the status of Kyverno pods: `kubectl get pods -n kyverno`. Check the webhook configuration: `kubectl get validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg -o yaml`. Ensure the service and pods are healthy.

### Integration Points
- **Devtron/ArgoCD**: Kyverno CLI is used in a pre-sync/pre-deploy step (`kyverno apply`) to validate manifests. This shifts policy enforcement left, catching errors before they hit the cluster.
- **Harbor/Cosign**: The `verifyImages` policies connect directly to `harbor.helixstax.net` to check for Cosign signatures and attestations, making Harbor the source of truth for image trust.
- **NeuVector**: Kyverno ensures resources are well-formed (e.g., from a trusted registry), while NeuVector ensures they *behave* correctly at runtime. They are complementary layers.
- **Prometheus**: Kyverno exposes extensive metrics scraped by Prometheus, which we use to monitor policy execution latency and violation counts.

---

## reference.md Content

### C1. CLI Reference (`kyverno CLI`)

| Command | Description | Example |
| :--- | :--- | :--- |
| **apply** | Applies policies to resource files without a cluster. The core of CI integration. | `kyverno apply policy.yaml -r resource.yaml` |
| | `--policy-report` | Generates a `PolicyReport` CRD as output. |
| | `--detailed-results` | Shows a table with detailed pass/fail status per rule. |
| | `--exit-code` | Controls the exit code on failure (default is 1). `kyverno apply ... || echo "Policy violation detected!"` |
| **test** | Runs structured unit tests for policies. | `kyverno test ./my-policy-tests/` |
| | Requires a `kyverno-test.yaml` file defining test cases. |
| **validate**| Validates the syntax and schema of policy files themselves. | `kyverno validate policy.yaml` |
| **jp** | A JMESPath query
