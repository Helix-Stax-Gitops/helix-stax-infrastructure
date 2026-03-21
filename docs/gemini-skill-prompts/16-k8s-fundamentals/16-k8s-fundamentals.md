# Gemini Deep Research: K8s Fundamentals (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into three separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These are the foundational layer. Every other tool in the Helix Stax stack runs on top of this layer. An AI agent cannot configure NeuVector, deploy Zitadel, or debug ESO without understanding all three:

- **K3s**: The Kubernetes distribution we run. Lightweight, single-binary, ships with Traefik, Flannel, local-path-provisioner, and ServiceLB built in. Runs on AlmaLinux 9.7 on Hetzner Cloud.
- **kubectl**: The CLI for everything. Reading state, debugging pods, applying manifests, managing rollouts, running one-off commands inside containers — all through `kubectl`.
- **YAML / Kubernetes Manifests**: The language of Kubernetes. Every resource — Deployments, Services, IngressRoutes, ConfigMaps, Secrets, NetworkPolicies — is defined in YAML. Understanding manifest structure is non-negotiable.

How they connect: K3s runs the cluster and exposes the Kubernetes API → kubectl talks to that API → manifests define what resources the API manages.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud
  - `heart` (178.156.233.12): Control plane node
  - `helix-worker-1` (138.201.131.157): Worker node
- **K3s version**: Latest stable (track quarterly)
- **CNI**: Flannel (built into K3s, evaluating Cilium)
- **Ingress**: Traefik (built into K3s, upgraded via Helm)
- **Storage**: local-path-provisioner (built in) + Longhorn (planned)
- **Registry mirror**: Harbor at harbor.helixstax.net configured in K3s `registries.yaml`
- **TLS**: cert-manager (Let's Encrypt for public, OpenBao PKI for internal)
- **GitOps**: ArgoCD applies all manifests
- **Secrets**: External Secrets Operator (no raw K8s Secrets in git)
- **Policy**: Kyverno (admission control)
- **Domains**: helixstax.com (public), helixstax.net (internal)
- **Conventions**: All IngressRoutes use Traefik CRDs (NOT standard Kubernetes Ingress)

---

## What I Need Researched

### SECTION A: K3s

#### A1. K3s Architecture
- How K3s differs from kubeadm/RKE/kind: single binary, embedded components, lightweight footprint
- Embedded components and their K3s equivalents: kube-proxy (replaced by kube-router or iptables mode), CoreDNS, Traefik, Flannel, local-path-provisioner, ServiceLB (Klipper)
- Server (control plane) vs Agent (worker) roles in K3s
- K3s datastore options: embedded SQLite (single server), embedded etcd (HA), external PostgreSQL/MySQL
- Our setup: embedded etcd for HA readiness even with 2 nodes
- How the K3s API server binds: which ports are open (6443), what each does
- K3s token: what it is, where it's stored, how workers join using it

#### A2. Installation and Initial Configuration
- Installing K3s server (control plane): `curl -sfL https://get.k3s.io | sh -s - server` with flags
- Key server flags we use: `--cluster-init` (embedded etcd), `--tls-san` (public IPs + domain), `--disable traefik` (if managing Traefik ourselves via Helm), `--flannel-backend`, `--write-kubeconfig-mode`
- Installing K3s agent (worker): join command with server URL and token
- kubeconfig location: `/etc/rancher/k3s/k3s.yaml` — how to copy and merge with local kubeconfig
- K3s systemd service: `k3s.service` and `k3s-agent.service` — start, stop, restart, logs
- K3s uninstall scripts: `/usr/local/bin/k3s-uninstall.sh` and `k3s-agent-uninstall.sh`

#### A3. K3s-Specific Features and Differences from Standard K8s

##### registries.yaml (Harbor Mirror)
- Location: `/etc/rancher/k3s/registries.yaml`
- How to configure Harbor as a pull-through cache/mirror for Docker Hub and other registries
- Full registries.yaml example for Harbor at harbor.helixstax.net with authentication
- How K3s applies registries.yaml changes (requires K3s restart)
- Verifying mirror is working: pulling an image and checking containerd cache

##### Traefik in K3s
- K3s ships Traefik v2 by default — how to disable it and deploy our own Helm-managed Traefik
- Why we manage Traefik ourselves (version control, custom values, IngressRoute CRDs)
- Helm upgrade Traefik inside K3s without breaking existing IngressRoutes

##### local-path-provisioner
- What it does: dynamically provisions HostPath PVs on the node where the pod runs
- Default StorageClass name: `local-path`
- Limitations: no cross-node replication, data lost if node fails
- When to use local-path vs Longhorn vs CloudNativePG-managed storage
- Changing the storage path (default `/var/lib/rancher/k3s/storage/`)

##### ServiceLB (Klipper)
- What ServiceLB does: implements LoadBalancer Services on bare metal using host ports
- How it assigns external IPs (uses node IPs)
- Interaction with Cloudflare: traffic flow from Cloudflare → K3s node IP → Traefik ServiceLB → pod
- When ServiceLB conflicts with MetalLB or other LoadBalancer implementations

#### A4. Node Management
- Listing nodes: `kubectl get nodes -o wide`
- Node labels and taints: adding labels for workload placement, tainting control plane to prevent workloads
- Cordoning and draining: `kubectl cordon`, `kubectl drain --ignore-daemonsets --delete-emptydir-data`
- Node conditions: Ready, MemoryPressure, DiskPressure, PIDPressure — what each means
- Checking node resource usage: `kubectl top nodes`

#### A5. K3s Upgrades
- system-upgrade-controller: what it is, how to deploy it, how to define upgrade Plans
- Upgrade Plan CRD: specifying K3s version, node selectors, cordon behavior
- Manual upgrade procedure: upgrade server first, then agents — order matters
- Upgrade a 2-node cluster safely: minimize downtime, handle etcd re-election
- Checking current K3s version: `k3s --version`, `kubectl version`
- Rollback: K3s doesn't have built-in rollback — how to pin a version and downgrade manually

#### A6. K3s Backup and Restore
- Embedded etcd snapshot: `k3s etcd-snapshot save`, default location, schedule via cron or systemd timer
- Restoring from snapshot: `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>`
- Velero vs etcd snapshot: which covers what (etcd = K8s objects, Velero = PVCs + objects)
- Storing etcd snapshots: copying to MinIO, Backblaze B2
- What an etcd restore recovers vs what it doesn't (PVC data not included)

#### A7. K3s Networking
- Flannel: how it works (VXLAN by default in K3s), pod CIDR, service CIDR
- CoreDNS: service discovery inside the cluster, `.cluster.local` domain
- K3s firewall requirements: ports to open on AlmaLinux (6443, 8472 for Flannel VXLAN, 51820 for WireGuard if used)
- How pod-to-pod traffic flows across our 2 nodes (Flannel VXLAN tunnel)
- SELinux considerations on AlmaLinux 9.7 with K3s

#### A8. K3s Troubleshooting
- K3s service logs: `journalctl -u k3s -f`, `journalctl -u k3s-agent -f`
- containerd debugging: `k3s crictl ps`, `k3s crictl logs <container-id>`, `k3s crictl inspect`
- etcd health check: `k3s etcd-snapshot ls`, `ETCDCTL_API=3 etcdctl endpoint health`
- Common K3s issues: node NotReady after reboot, Flannel VXLAN port blocked, containerd socket not found
- Recovering a crashed control plane: etcd quorum loss on single server

---

### SECTION B: kubectl

#### B1. Configuration and Context Management
- kubeconfig file: location (`~/.kube/config`), structure (clusters, users, contexts)
- Merging multiple kubeconfigs: `KUBECONFIG=~/.kube/config:~/.kube/helix-stax.yaml kubectl config view --merge --flatten`
- Switching contexts: `kubectl config use-context`, `kubectl config get-contexts`
- Setting a default namespace: `kubectl config set-context --current --namespace=<ns>`
- kubeconfig for CI/CD: creating a restricted ServiceAccount token for Devtron/ArgoCD

#### B2. Resource Inspection Commands
- `kubectl get <resource>`: flags (`-o wide`, `-o yaml`, `-o json`, `-o jsonpath`, `-o custom-columns`, `-A` for all namespaces, `-n <ns>`, `-l <label-selector>`, `--field-selector`, `--watch`)
- `kubectl describe <resource>`: events section is critical — always check it
- `kubectl explain <resource>`: in-cluster API documentation for any resource kind
- `kubectl api-resources`: listing all available resource types and their short names
- `kubectl api-versions`: listing all API groups and versions
- Common short names: `po` (pods), `svc` (services), `deploy` (deployments), `ns` (namespaces), `cm` (configmaps), `secret`, `pvc`, `pv`, `ing` (ingress), `ep` (endpoints), `rs` (replicaset), `ds` (daemonset), `sts` (statefulset), `crd`

#### B3. Log and Debugging Commands
- `kubectl logs <pod> [-c <container>] [-f] [--previous] [--tail=100] [--since=1h]`
- `kubectl exec -it <pod> -- /bin/sh` (or bash): dropping into a container
- `kubectl exec <pod> -- <command>`: running commands without interactive shell
- `kubectl port-forward <pod|svc|deploy> <local>:<remote>`: exposing services locally for debugging
- `kubectl cp <pod>:/path /local/path`: copying files in and out of containers
- `kubectl debug <pod> --image=busybox --target=<container>`: ephemeral debug containers (K8s 1.23+)
- `kubectl top pods [-n <ns>] [--containers]`: per-pod and per-container CPU/memory
- `kubectl top nodes`: per-node resource usage

#### B4. Apply, Create, Delete, Patch
- `kubectl apply -f <file|dir>`: declarative apply — creates or updates
- `kubectl apply -f <dir> -R`: recursive apply for a directory tree
- `kubectl apply --dry-run=client -f <file>`: validate without applying
- `kubectl apply --dry-run=server -f <file>`: server-side dry run (runs admission webhooks)
- `kubectl diff -f <file>`: show what would change before applying
- `kubectl create vs kubectl apply`: imperative vs declarative — always prefer apply in GitOps
- `kubectl delete <resource> <name> [-n <ns>] [--grace-period=0 --force]`: deletion, force-delete stuck pods
- `kubectl patch <resource> <name> --patch '{"spec":{"replicas":3}}'`: inline patching
- Strategic merge patch vs JSON merge patch vs JSON patch: when to use each
- `kubectl replace -f <file>`: replace entire resource — use with caution (vs apply)
- `kubectl edit <resource> <name>`: in-editor live editing (avoid in GitOps, but useful for debugging)

#### B5. Rollout Management
- `kubectl rollout status deployment/<name>`: watch until rollout complete
- `kubectl rollout history deployment/<name> [--revision=N]`: view rollout history
- `kubectl rollout undo deployment/<name> [--to-revision=N]`: rollback
- `kubectl rollout restart deployment/<name>`: trigger rolling restart (forces new pods, picks up Secret changes)
- `kubectl rollout pause/resume deployment/<name>`: controlled rollout management
- Same commands work for DaemonSet and StatefulSet

#### B6. RBAC and Access Control
- `kubectl auth can-i <verb> <resource> [--namespace=<ns>] [--as=<user>]`: checking permissions
- `kubectl auth can-i --list --namespace=<ns>`: list all permitted actions
- `kubectl get rolebindings,clusterrolebindings -A`: listing all role bindings
- Creating ServiceAccounts, Roles, RoleBindings, ClusterRoles, ClusterRoleBindings imperatively (for debugging) vs declaratively (for production)

#### B7. Output Formatting and Scripting
- JSONPath: `kubectl get pod <name> -o jsonpath='{.status.podIP}'`
- JSONPath array iteration: `kubectl get pods -o jsonpath='{.items[*].metadata.name}'`
- Custom columns: `kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP`
- Combined with jq: `kubectl get pods -o json | jq '.items[].metadata.name'`
- Labels as columns: `kubectl get pods --label-columns=app,version`
- Sorting: `kubectl get pods --sort-by=.metadata.creationTimestamp`

#### B8. Useful kubectl Plugins (krew)
- `kubectl krew install`: plugin manager setup
- Recommended plugins: `ctx` (context switching), `ns` (namespace switching), `neat` (clean YAML output), `tail` (multi-pod log tail), `stern` (same), `tree` (resource ownership tree), `who-can` (RBAC audit), `resource-capacity` (node capacity), `images` (list all images in cluster)

---

### SECTION C: YAML / Kubernetes Manifests

#### C1. Core Workload Resources

##### Deployment
- Full annotated Deployment YAML: apiVersion, kind, metadata, spec (replicas, selector, strategy, template)
- Pod template spec: containers (name, image, ports, env, envFrom, resources, livenessProbe, readinessProbe, startupProbe, volumeMounts, securityContext), volumes, nodeSelector, affinity, tolerations, topologySpreadConstraints, serviceAccountName, terminationGracePeriodSeconds
- Rolling update strategy: maxSurge, maxUnavailable — recommended values for our services
- Deployment vs ReplicaSet: never create RS directly

##### StatefulSet
- When to use StatefulSet vs Deployment: stable network identity, ordered deployment, PVC per replica
- StatefulSet YAML: volumeClaimTemplates, podManagementPolicy, serviceName (headless Service required)
- Headless Service: `clusterIP: None` — why StatefulSets need it
- Ordered vs parallel pod management: when to use each
- Services that should be StatefulSets in our stack: OpenBao, Zitadel (if not using CNPG HA), Rocket.Chat

##### DaemonSet
- When to use DaemonSet: one pod per node (NeuVector Enforcer, CrowdSec, Flannel, log shippers)
- DaemonSet YAML: same as Deployment pod template, minus replicas
- Tolerations for control plane nodes: how to run DaemonSets on all nodes including control plane
- Update strategy: RollingUpdate vs OnDelete for DaemonSets

#### C2. Networking Resources

##### Service
- ClusterIP: internal-only, no external access
- NodePort: external access via node IP:port — we avoid this (Kyverno blocks it)
- LoadBalancer: external access via ServiceLB (Klipper) on K3s
- ExternalName: DNS alias to external service
- Headless (ClusterIP: None): for StatefulSets and direct pod DNS
- Service ports: targetPort vs port, named ports
- Selector: how Services find pods, selector-less Services for external endpoints

##### Ingress vs Traefik IngressRoute
- Standard Kubernetes Ingress: `networking.k8s.io/v1` — what it is, why we DON'T use it
- Traefik IngressRoute CRD: `traefik.io/v1alpha1` — what we DO use
- Full IngressRoute YAML: entryPoints, routes (match, services, middlewares), TLS
- Traefik Middleware CRD: headers, stripPrefix, redirectScheme, basicAuth, forwardAuth
- Match syntax: `Host()`, `PathPrefix()`, `Method()`, `Headers()`
- TLS in IngressRoute: cert-manager Certificate vs Let's Encrypt ACME challenge via Traefik
- IngressRouteTCP and IngressRouteUDP: for non-HTTP traffic (PostgreSQL, Redis/Valkey)

##### NetworkPolicy
- What NetworkPolicy does: L3/L4 ingress/egress rules per pod selector
- Default deny all: the baseline policy every namespace should have
- Full NetworkPolicy YAML for a typical service: allow from specific namespaces/pods only
- Flannel and NetworkPolicy: Flannel does NOT enforce NetworkPolicy — need a CNI plugin that does (Calico, Cilium). How do we handle this? (NeuVector as the enforcement layer)
- When to use NetworkPolicy vs NeuVector network rules vs Kyverno

#### C3. Configuration Resources

##### ConfigMap
- ConfigMap: storing non-sensitive config as key-value or file content
- Consuming ConfigMap: `envFrom` (all keys as env vars), `env.valueFrom.configMapKeyRef` (single key), `volume` (mount as files)
- ConfigMap size limit: 1MB — what to do if exceeded
- Immutable ConfigMaps: preventing accidental updates

##### Secret
- Kubernetes Secret types: Opaque (generic), kubernetes.io/tls, kubernetes.io/dockerconfigjson
- NEVER store raw Secrets in git — ESO creates them from OpenBao
- Secret consumption: same patterns as ConfigMap (envFrom, env.valueFrom.secretKeyRef, volume mount)
- Secret data: base64 encoded (NOT encrypted) — `stringData` field for plaintext input
- `kubectl create secret generic` for bootstrap scenarios
- `imagePullSecret`: how to configure Harbor credentials for pulling private images

#### C4. Storage Resources

##### PersistentVolume and PersistentVolumeClaim
- PV vs PVC: PV is the resource, PVC is the claim — developers use PVC, admins provision PV (or use StorageClass)
- StorageClass: dynamic provisioning — `local-path` (default K3s), future Longhorn
- PVC YAML: accessModes (ReadWriteOnce, ReadWriteMany, ReadOnlyMany), storage request, storageClassName
- Access modes on K3s local-path: only ReadWriteOnce supported
- PVC binding: `kubectl get pvc` status field (Bound vs Pending)
- PV reclaim policies: Retain, Delete, Recycle — use Retain for important data
- `kubectl get pv` — checking PV status, capacity, bound claim
- Expanding PVCs: if StorageClass allows volume expansion
- Stuck PVC deletion: finalizers, how to force-delete

#### C5. Namespace Conventions

##### Namespace Design for Helix Stax
- Namespace list and purpose: `kube-system`, `kube-public`, `traefik`, `cert-manager`, `monitoring`, `identity` (Zitadel), `database` (CNPG), `harbor`, `minio`, `openbao`, `external-secrets`, `argocd`, `devtron-cd`, `crowdsec`, `neuvector`, `kyverno`, `velero`, `n8n`, `rocketchat`, `outline`, `backstage`
- Namespace-level defaults: default resource quotas, default LimitRanges, default NetworkPolicies
- Why namespace isolation matters: Kyverno policies can be namespace-scoped, RBAC is namespace-scoped

#### C6. Label and Annotation Standards

##### Labels (Our Conventions)
- Required labels on all pods: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`, `environment` (prod/dev/staging)
- Label selector patterns: Deployment selector vs Service selector — must match exactly
- `kubectl label` and `kubectl annotate`: adding/removing labels imperatively

##### Annotations (Our Conventions)
- `kubectl.kubernetes.io/last-applied-configuration`: added by `kubectl apply` — don't edit manually
- `argocd.argoproj.io/sync-wave`: controlling ArgoCD sync order
- `reloader.stakater.com/auto: "true"`: triggering pod restart on ConfigMap/Secret change
- cert-manager annotations on Ingress/IngressRoute (if using ACME)
- Kyverno policy exception annotations

#### C7. Resource Management

##### Resource Requests and Limits
- requests vs limits: scheduling (requests) vs throttling/OOM kill (limits)
- CPU: `100m` = 0.1 core — requests should be conservative, limits reasonable
- Memory: OOMKilled when pod exceeds limit — set limits with buffer
- LimitRange: namespace-level defaults and max/min bounds
- ResourceQuota: namespace-level total limits (CPU, memory, pod count, PVC count)
- VPA (Vertical Pod Autoscaler): worth deploying for right-sizing? (optional for our scale)
- HPA (Horizontal Pod Autoscaler): CPU/memory-based scaling — which of our services should use it?

#### C8. Advanced Manifest Patterns

##### Kustomize
- What Kustomize does: patching base manifests with overlays (no template language)
- `kustomization.yaml`: resources, patches, namePrefix/nameSuffix, commonLabels, secretGenerator, configMapGenerator
- Overlay structure: `base/` + `overlays/prod/`, `overlays/dev/`
- Strategic merge patch vs JSON patch in Kustomize
- `kubectl apply -k <dir>`: applying a Kustomize directory
- ArgoCD + Kustomize: ArgoCD natively supports Kustomize directories

##### Strategic Merge Patch
- What it is: merge patches that understand K8s list structures (containers by name, etc.)
- When to use: `kubectl patch`, Kustomize patches, ArgoCD sync patches
- JSON merge patch vs strategic merge patch: arrays get replaced in JSON merge, merged by key in strategic
- JSON Patch (RFC 6902): `op`, `path`, `value` — surgical operations

##### Pod Security Context
- `securityContext` at pod level: `runAsNonRoot`, `runAsUser`, `runAsGroup`, `fsGroup`, `seccompProfile`, `sysctls`
- `securityContext` at container level: `allowPrivilegeEscalation`, `readOnlyRootFilesystem`, `capabilities` (drop ALL, add specific)
- Kyverno policies that enforce security context standards
- Privileged containers: when legitimately needed (NeuVector Enforcer, CrowdSec), how to document the exception

#### C9. Debugging Manifest Problems
- `kubectl apply --dry-run=server`: catches admission webhook failures before applying
- `kubectl diff -f <file>`: exact diff between current and desired state
- Common YAML errors: indentation, tab vs space, missing `---` separator, wrong apiVersion
- `kubectl explain <resource>.<field>`: checking valid field names and types
- `kubectl get events -n <ns> --sort-by=.lastTimestamp`: namespace events, most important for debugging CrashLoopBackOff, ImagePullBackOff, Pending pods
- `kubectl describe pod <name>`: events section shows scheduling failures, image pull errors, probe failures
- Common pod failure states: CrashLoopBackOff (app crashing), ImagePullBackOff (registry issue), Pending (no node can schedule it), OOMKilled (exceeded memory limit), Evicted (node pressure)

---

## Required Output Format

Structure your response with these EXACT top-level headers (using `#`) so it can be split into three separate skill files. Each section must be self-contained — do not assume the reader has read the other sections.

```markdown
# K3s

## Overview
[What K3s is and how it differs from standard Kubernetes, why Helix Stax uses it]

## Architecture
[Server vs agent, embedded components, datastore options, token]

## Installation and Configuration
[Server install flags, agent join, kubeconfig, systemd service]

## K3s-Specific Features
### registries.yaml (Harbor Mirror)
[Full example, how to configure, when changes apply]
### Traefik in K3s
[Built-in Traefik vs Helm-managed, why we manage our own]
### local-path-provisioner
[What it does, limitations, when to use]
### ServiceLB (Klipper)
[How it works, external IP assignment, interaction with Cloudflare]

## Node Management
[Labels, taints, cordon/drain, conditions, top]

## Upgrades
[system-upgrade-controller, upgrade Plan CRD, 2-node upgrade procedure, rollback]

## Backup and Restore
[etcd snapshot commands, schedule, MinIO storage, restore procedure]

## Networking
[Flannel VXLAN, CoreDNS, firewall ports, pod-to-pod traffic, SELinux on AlmaLinux]

## Troubleshooting
[K3s logs, crictl commands, etcd health, common failures]

## Gotchas
[K3s-vs-standard-K8s differences, SELinux, containerd vs Docker, embedded Traefik conflicts]

---

# kubectl

## Overview
[What kubectl is and why every agent must know it cold]

## Configuration and Context Management
[kubeconfig, merging, context switching, default namespace, CI token]

## Resource Inspection
[get flags, describe, explain, api-resources, short names]

## Logs and Debugging
[logs flags, exec, port-forward, cp, debug ephemeral containers, top]

## Apply, Create, Delete, Patch
[apply vs create, dry-run, diff, delete flags, patch types, edit, replace]

## Rollout Management
[status, history, undo, restart, pause/resume — Deployment, StatefulSet, DaemonSet]

## RBAC and Access Control
[auth can-i, listing bindings, ServiceAccount tokens for CI]

## Output Formatting and Scripting
[JSONPath, custom-columns, jq combos, label columns, sorting]

## Useful Plugins (krew)
[Plugin list with use cases]

## Troubleshooting Patterns
[Command sequences for common problems: pod not starting, service not reachable, image pull fail]

---

# Kubernetes Manifests (YAML)

## Overview
[Why manifest fluency is foundational — every tool in the stack is configured via manifests]

## Workload Resources
### Deployment
[Full annotated YAML, rolling update strategy, all pod spec fields]
### StatefulSet
[When to use, volumeClaimTemplates, headless Service, which Helix Stax services use it]
### DaemonSet
[When to use, control plane toleration, update strategy]

## Networking Resources
### Service (ClusterIP, NodePort, LoadBalancer, Headless)
[Full examples, selector patterns, port naming]
### Traefik IngressRoute (Our Standard)
[Full IngressRoute YAML, Middleware CRD, TLS config, match syntax]
### NetworkPolicy
[Default deny all, allow-from-namespace pattern, Flannel limitation, NeuVector as enforcement]

## Configuration Resources
### ConfigMap
[YAML, consumption patterns, size limit, immutable]
### Secret
[Types, NEVER in git, consumption patterns, imagePullSecret]

## Storage Resources
### PV, PVC, StorageClass
[Full PVC YAML, local-path vs Longhorn, access modes, reclaim policy, stuck deletion]

## Namespace Conventions
[Our namespace list, purpose of each, namespace-level defaults]

## Label and Annotation Standards
[Required labels, selector patterns, our annotation conventions]

## Resource Management
[requests vs limits, LimitRange, ResourceQuota, HPA, VPA]

## Advanced Patterns
### Kustomize
[kustomization.yaml, overlay structure, ArgoCD + Kustomize]
### Patch Types
[Strategic merge, JSON merge, JSON Patch — when to use each]
### Pod Security Context
[Pod-level and container-level, capabilities, Kyverno enforcement]

## Debugging Manifests
[dry-run server, diff, common YAML errors, explain, events, pod failure states]
```

Be thorough, opinionated, and practical. Include actual YAML manifests (full, annotated, copy-paste ready), actual kubectl commands with flags, actual K3s install commands with our specific flags, actual registries.yaml for Harbor, actual IngressRoute YAML for Traefik. Do NOT give me theory — give me what an AI agent needs to operate a 2-node K3s cluster on AlmaLinux 9.7 at Hetzner Cloud without hallucinating. Flag every place where K3s differs from standard Kubernetes.
