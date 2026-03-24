# Gemini Deep Research: Cilium CNI for K3s — eBPF Networking, Network Policies, and Observability

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

Cilium is a Kubernetes CNI plugin and network security platform built on eBPF — a Linux kernel technology that lets programs run safely inside the kernel without modifying kernel source or loading kernel modules. Cilium uses eBPF to implement networking, load balancing, and security enforcement at the kernel level, which is both faster and more capable than traditional iptables-based approaches.

Key capabilities Cilium provides that Flannel (the K3s default CNI) does not:

- **NetworkPolicy enforcement**: Flannel provides L3 pod-to-pod connectivity but has zero NetworkPolicy enforcement. Any pod can reach any other pod. Cilium enforces L3/L4 NetworkPolicy natively and adds L7 policy (HTTP path filtering, gRPC method filtering) via CiliumNetworkPolicy CRDs.
- **Hubble observability**: Built-in network flow visibility. Every TCP connection, DNS query, and HTTP request between pods is logged and queryable. Integrates with Prometheus and Grafana.
- **kube-proxy replacement**: Cilium can replace kube-proxy entirely using eBPF-based load balancing, reducing latency and improving throughput for service-to-service traffic.
- **mTLS between services**: Cilium can enforce mutual TLS between pods using its service mesh capability (Cilium Service Mesh / WireGuard transparent encryption) without sidecar injection.

For Helix Stax, the decision between Flannel and Cilium comes down to: do we need NetworkPolicy enforcement and Hubble observability before we add workloads, or do we add Flannel now and migrate later? This research should give us everything needed to make that call and, if we choose Cilium, execute the migration without destroying the cluster.

## Our Specific Setup

- **K3s cluster**: helix-stax-cp (178.156.233.12, cpx31, Hetzner ash-dc1) — Control Plane + single worker for now
- **VPS**: helix-stax-vps (5.78.145.30, cpx31, Hetzner hil-dc1) — role TBD, may join as second worker
- **SSH port**: 2222
- **Admin user**: `wakeem`
- **OS**: AlmaLinux 9.7 (RHEL 9-compatible, SELinux enforcing)
- **Current CNI**: Flannel VXLAN (K3s default)
- **K3s version**: Latest stable (v1.29+ or v1.30+)
- **Ingress**: Traefik v3 deployed via Helm (K3s bundled Traefik disabled)
- **Edge**: Cloudflare Tunnel (cloudflared as K8s Deployment)
- **Secrets**: OpenBao + External Secrets Operator
- **Monitoring**: Prometheus + Grafana + Loki (kube-prometheus-stack)
- **IaC**: Ansible for OS + K3s install, Helm for K8s workloads, OpenTofu for Hetzner/Cloudflare
- **CD**: Devtron + ArgoCD
- **Security**: CrowdSec (host-level IDS + Traefik bouncer)
- **Pod CIDR**: 10.42.0.0/16 (K3s default)
- **Service CIDR**: 10.43.0.0/16 (K3s default)

---

## What I Need Researched

---

### CIL-1. Cilium Architecture

Understand the full component stack before deploying:

**Core components:**
- `cilium-agent` (DaemonSet): what it does per node — programs eBPF maps, handles policy enforcement, manages endpoint state
- `cilium-operator` (Deployment): what it does cluster-wide — IPAM management, CRD management, node connectivity
- `cilium-envoy` (DaemonSet, optional): L7 proxy for HTTP/gRPC policy enforcement — when is it needed, when can it be omitted?
- Hubble relay (Deployment): aggregates flow data from all nodes, exposes gRPC API
- Hubble UI (Deployment): web UI for flow visualization
- Hubble Observer (CLI): `hubble observe` command for real-time flow inspection

**eBPF datapath:**
- Where eBPF programs are attached: tc (traffic control) hooks on veth pairs, XDP hooks at NIC level, cgroup hooks for socket-level operations
- eBPF maps: what data lives in eBPF maps (endpoint state, policy rules, NAT tables, conntrack)
- How Cilium handles pod creation: the sequence from pod scheduled → CNI called → veth pair created → eBPF programs attached → endpoint registered
- Kernel interaction: which eBPF program types Cilium uses (BPF_PROG_TYPE_SCHED_CLS, BPF_PROG_TYPE_CGROUP_SKB, etc.) — informational, for SELinux troubleshooting

**IPAM modes:**
- Kubernetes host-scope IPAM (default for K3s): each node gets a CIDR slice from the cluster CIDR, pods get IPs from that slice
- Cluster-scope IPAM: Cilium operator allocates IPs cluster-wide
- Which IPAM mode to use with K3s — and why Kubernetes host-scope aligns with K3s's existing IPAM expectations

---

### CIL-2. Cilium vs Flannel: Objective Comparison for Our Use Case

Provide an honest comparison tuned to a 2-node K3s cluster on Hetzner with AlmaLinux 9.7:

**Flannel:**
- What Flannel provides: L3 overlay networking via VXLAN, pod-to-pod connectivity across nodes
- What Flannel does NOT provide: NetworkPolicy enforcement (Flannel simply ignores NetworkPolicy objects), L7 visibility, kube-proxy replacement, eBPF
- Flannel VXLAN overhead: encapsulation adds ~50 bytes per packet, latency implications for a 2-node setup
- When Flannel is the right choice: truly minimal clusters where NetworkPolicy is not needed and operational simplicity is the top priority
- Flannel + Calico NetworkPolicy: some setups run Flannel for networking + Calico for NetworkPolicy — why this is messy and not recommended

**Cilium:**
- Resource overhead on a cpx31 node (4 vCPU, 8GB RAM): CPU and memory baseline for cilium-agent + cilium-operator + hubble-relay + hubble-ui vs Flannel (which has near-zero overhead)
- Startup time: Cilium agent cold start is slower than Flannel — how much slower, what the implication is for node restarts
- Operational complexity: Cilium has more moving parts, more CRDs, more configuration options — realistic assessment for a one-person ops team
- eBPF features that require newer kernels: which Cilium features need kernel 5.10+ vs 4.19+
- What AlmaLinux 9.7 ships: exact kernel version in AlmaLinux 9.7, confirm it meets Cilium's requirements

**Recommendation:**
- Given our setup (2 nodes, 8GB RAM each, Hetzner, K3s, SELinux enforcing, AlmaLinux 9.7), should we start with Cilium or Flannel?
- If Cilium: what features to enable initially vs defer (e.g., enable NetworkPolicy enforcement now, defer Hubble UI until monitoring namespace exists)
- If Flannel: at what point does the migration to Cilium become justified, and is that migration disruptive?

---

### CIL-3. AlmaLinux 9 Kernel Requirements for Cilium

This is the most common failure point. Document exhaustively:

**Kernel version:**
- Exact kernel version shipped with AlmaLinux 9.7: run `uname -r` — what is the expected output?
- Cilium minimum kernel version by feature:
  - Basic connectivity (no kube-proxy replacement): 4.19.57+
  - kube-proxy replacement: 5.10+
  - WireGuard transparent encryption: 5.6+
  - BPF-based bandwidth manager: 5.1+
  - Socket LB (session affinity): 5.7+
  - L7 policy enforcement (without Envoy): 5.3+
- Does AlmaLinux 9.7's kernel meet all of these? Which features are available vs not?
- AlmaLinux 9 kernel backports: RHEL 9 kernels have backports — does AlmaLinux 9's 5.14.x kernel have the eBPF features that upstream 5.10 introduced?

**SELinux compatibility:**
- Cilium agent runs as a privileged DaemonSet — SELinux `privileged_container` type allows most operations
- eBPF program loading: does SELinux block `bpf()` syscalls from a privileged container on AlmaLinux 9?
- Known AVC denials when running Cilium on RHEL 9 / AlmaLinux 9 under SELinux enforcing mode
- Required SELinux booleans for Cilium (if any)
- The `cilium-selinux` situation: is there a SELinux policy package for Cilium like `k3s-selinux`? Or do we need a custom policy module?
- BPF filesystem mounting: Cilium needs `/sys/fs/bpf` mounted — does SELinux restrict this? How to allow it.
- `CAP_BPF` capability: Cilium requires this — does AlmaLinux 9 SELinux policy allow it in a privileged container?

**cgroup v2:**
- AlmaLinux 9 uses cgroup v2 (unified hierarchy) by default
- Cilium cgroup v2 support: fully supported since Cilium 1.10 — confirm current version support
- Any special Cilium config needed for cgroup v2 on AlmaLinux 9?

---

### CIL-4. Installing Cilium on K3s

Document the exact installation path for K3s:

**Required K3s flags:**
- `--flannel-backend=none`: disable Flannel CNI
- `--disable-network-policy`: disable K3s's built-in network policy controller (Cilium replaces this)
- `--disable=kube-proxy` (optional): disable kube-proxy if using Cilium's kube-proxy replacement
- These flags must be set at first K3s server start — what happens if you add them to an existing running cluster?
- In `config.yaml` format for our setup

**Cilium Helm chart:**
- Repository: `https://helm.cilium.io/`
- Chart name: `cilium/cilium`
- Current stable version (as of research date)
- Installation namespace: `kube-system` (Cilium must be in kube-system)

**Required Helm values for K3s compatibility:**
- `kubeProxyReplacement`: `true` vs `partial` vs `disabled` — which to use and when
- `k8sServiceHost` and `k8sServicePort`: must point to K3s API server (178.156.233.12:6443) when kube-proxy replacement is enabled
- `operator.replicas: 1`: correct for single-control-plane setup (default is 2, which fails on single-node)
- `ipam.mode: "kubernetes"`: use Kubernetes host-scope IPAM to align with K3s's existing CIDR allocation
- `nodeinit.enabled: true`: K3s-specific, ensures BPF filesystem is mounted before Cilium agent starts
- `cni.chainingMode`: must be `none` when Cilium is the only CNI (not chaining with Flannel)
- `securityContext.privileged: true`: required for eBPF program loading
- `bpf.mountPath: "/sys/fs/bpf"`: confirm correct path on AlmaLinux 9
- `hubble.relay.enabled` and `hubble.ui.enabled`: enable Hubble for observability

**Full annotated values.yaml:**
- A complete values.yaml for our specific setup with every relevant field explained
- Which values are K3s-specific vs general Kubernetes
- Which values are AlmaLinux 9 / SELinux specific

---

### CIL-5. Migrating from Flannel to Cilium on a Running K3s Cluster

The hardest part of adopting Cilium is migrating from Flannel without destroying the cluster:

**Is in-place migration possible?**
- The fundamental challenge: Flannel allocates pod IPs from a CIDR. If you remove Flannel and install Cilium, existing pods have IPs from the Flannel CIDR — will Cilium honor these IPs or reallocate?
- Cilium chaining mode with Flannel: is there a migration path that runs both CNIs simultaneously? What is the risk?
- K3s-specific migration: is there a safer approach for K3s than for full Kubernetes (fewer nodes, can drain and restart more easily)?

**Recommended migration procedure:**
- Step-by-step procedure for migrating a running K3s single-node cluster from Flannel to Cilium
- Whether it requires downtime (likely yes for pod networking) — how much?
- Drain sequence: `kubectl drain` all nodes, stop K3s, update config, restart K3s with Cilium, uncordon
- Verification steps after migration: `cilium status`, `cilium connectivity test`, `kubectl get pods -A` should all be Running

**Fresh install approach:**
- If migrating a cluster with no stateful workloads (our situation — fresh rebuild): fresh install is vastly simpler
- On fresh K3s install: set `--flannel-backend=none --disable-network-policy` before any pods are scheduled, then install Cilium via Helm before deploying any workloads
- Why this is the recommended approach for Helix Stax (we are rebuilding from scratch)

**What breaks during migration:**
- Flannel VXLAN tunnel state is lost: inter-node pod traffic stops during migration
- CoreDNS may lose connectivity temporarily
- Any pods with host networking should be unaffected
- Traefik IngressRoutes: what happens to in-flight connections during CNI swap

---

### CIL-6. NetworkPolicy with Cilium

Cilium's primary security value is NetworkPolicy enforcement. Document extensively:

**CiliumNetworkPolicy vs standard NetworkPolicy:**
- Standard Kubernetes NetworkPolicy: L3/L4 only, namespaced, supported by Cilium
- CiliumNetworkPolicy (CRD): L3/L4/L7, can reference Cilium identities, more expressive
- Which to use: prefer standard NetworkPolicy for portability, CiliumNetworkPolicy for L7 features
- Both can coexist on the same cluster

**Default deny:**
- Implementing default-deny-all for a namespace: the exact NetworkPolicy YAML
- How Cilium handles the "no policy" vs "explicit allow" vs "explicit deny" states
- Default deny for ALL namespaces: is there a cluster-wide default deny? Or must it be applied per namespace?
- Kyverno + Cilium: using Kyverno to enforce that every namespace has a default-deny policy (if applicable)
- What breaks immediately after applying default-deny: CoreDNS unreachable, readiness probes fail — the required allow rules to restore functionality

**Required baseline allow rules:**
- CoreDNS allow: pods must be able to reach CoreDNS on 10.43.0.10:53 (UDP and TCP)
- Kubernetes API allow: certain system pods need to reach the API server
- Prometheus allow: kube-prometheus-stack must be able to scrape pods on /metrics endpoints
- Health probes allow: kubelet (hostNetwork) must reach pod health check ports

**Example policies for Helix Stax namespaces:**
- `monitoring` namespace: Prometheus can scrape all namespaces; Grafana can reach Prometheus; Loki can receive logs — policy definitions
- `database` namespace (CloudNativePG): only pods with label `app.kubernetes.io/component: app` in specific namespaces can connect to port 5432
- `n8n` namespace: n8n can reach the database, can make egress HTTP calls (necessary for webhook integrations), cannot be reached except by Traefik
- `ai` namespace: Open WebUI can reach Ollama, Ollama has no external egress needed
- `kube-system` namespace: CoreDNS, Traefik — what policies to apply or whether to leave this namespace policy-free

**L7 policy examples:**
- HTTP path-based policy: allow only GET /metrics on port 9090, deny everything else
- When to use CiliumNetworkPolicy L7 vs Traefik middleware for path filtering
- gRPC method filtering (if relevant for our services)

---

### CIL-7. Hubble Observability

Hubble is Cilium's built-in network observability layer. Document fully:

**Hubble architecture:**
- Hubble agent (embedded in cilium-agent): captures flow events at the eBPF level
- Hubble relay: aggregates flows from all nodes via gRPC, exposes a single endpoint
- Hubble UI: React-based web interface for flow visualization (service dependency maps, real-time flows)
- Hubble CLI (`hubble`): command-line tool for querying flows

**Enabling Hubble:**
- Helm values: `hubble.enabled: true`, `hubble.relay.enabled: true`, `hubble.ui.enabled: true`
- `hubble.metrics.enabled`: what metrics to enable for Prometheus scraping
- Hubble metrics list: `dns`, `drop`, `tcp`, `flow`, `port-distribution`, `icmp`, `http` — which to enable in production

**Hubble CLI usage:**
- `hubble observe`: real-time flow stream
- `hubble observe --namespace n8n --last 100`: recent flows in a namespace
- `hubble observe --verdict DROPPED`: show only dropped flows (critical for debugging NetworkPolicy)
- `hubble observe --http-url /api`: filter by HTTP path
- Port-forward to Hubble relay: `kubectl port-forward -n kube-system svc/hubble-relay 4245:80`

**Hubble UI deployment:**
- Accessing Hubble UI: port-forward or expose via Traefik IngressRoute
- Traefik IngressRoute for Hubble UI: example with `hubble.helixstax.net` (internal, behind Access)
- Hubble UI service name and port in kube-system namespace

**Prometheus metrics from Hubble:**
- Hubble exposes metrics at port 9965 on cilium-agent pods
- ServiceMonitor for kube-prometheus-stack to scrape Hubble metrics
- Grafana dashboards: official Cilium/Hubble Grafana dashboards — how to import them (dashboard IDs or repository)
- Key Hubble metrics for alerting: `hubble_drop_total` (packets dropped by policy) — alert when non-zero

---

### CIL-8. Cilium kube-proxy Replacement

Cilium can replace kube-proxy entirely for service load balancing:

**What kube-proxy does:**
- kube-proxy programs iptables rules to implement Service ClusterIP, NodePort, LoadBalancer routing
- Performance limitations: iptables rules scale O(n) with number of services, lock contention under high traffic

**Cilium's replacement:**
- BPF-based service load balancing: eBPF maps replace iptables rules, O(1) lookup time
- NodePort implementation: Cilium handles NodePort via BPF at the kernel level
- DSR (Direct Server Return): for NodePort, packets can bypass source NAT — when is this beneficial?
- Session affinity: supported via BPF socket-level load balancing

**K3s + kube-proxy replacement:**
- K3s flag: `--disable=kube-proxy` — must be set before kube-proxy is ever started, cannot undo on running cluster
- Cilium Helm values: `kubeProxyReplacement: true`, `k8sServiceHost: 178.156.233.12`, `k8sServicePort: 6443`
- Verification: `cilium status | grep KubeProxyReplacement` — expected output

**Should we enable kube-proxy replacement for Helix Stax?**
- Benefits at our scale (2 nodes, <50 services): marginal performance gain, adds complexity
- Risks: if Cilium agent fails to start, kube-proxy is not there as fallback — pods have no service connectivity
- Recommendation: enable or not? With rationale.

---

### CIL-9. Cilium Service Mesh (mTLS Between Pods)

Cilium can provide transparent mTLS between pods without sidecars:

**How it works:**
- Cilium uses WireGuard at the node level to encrypt all pod-to-pod traffic that crosses node boundaries
- Per-endpoint encryption: traffic between pods on different nodes is encrypted end-to-end
- No sidecar injection: unlike Istio, Cilium encryption is fully transparent to the application

**Enabling WireGuard encryption:**
- Helm value: `encryption.enabled: true`, `encryption.type: wireguard`
- Kernel requirement: WireGuard kernel module on AlmaLinux 9.7 — is it available? `modprobe wireguard` — does AlmaLinux 9.7 ship with WireGuard in-tree?
- Performance: WireGuard adds overhead for cross-node traffic — is it significant on a 1Gbps Hetzner link?

**mTLS vs L7 policy enforcement:**
- WireGuard encryption: encrypts all cross-node traffic, no identity-based mTLS
- Cilium Service Mesh mTLS: uses Envoy proxy + SPIFFE certificates for per-service identity — more complex, more capability
- For Helix Stax: is WireGuard node encryption + Cilium NetworkPolicy sufficient, or do we need SPIFFE-based service identity?

**Recommendation:**
- Start with WireGuard encryption for node-to-node traffic (simple to enable)
- Defer SPIFFE/full service mesh until we have 5+ services that need service-to-service identity verification

---

### CIL-10. Cilium on Hetzner Cloud

Document any Hetzner-specific considerations:

**MTU:**
- Hetzner Cloud network MTU: what is the MTU on Hetzner Cloud servers?
- Cilium VXLAN encapsulation: adds overhead, effective MTU for pods is lower
- Cilium MTU autodetection: does Cilium correctly detect and configure MTU on Hetzner? Any known issues?
- Setting MTU explicitly: Helm value `MTU` — recommended value for Hetzner Cloud

**Hetzner Cloud Controller Manager (HCCM):**
- HCCM manages LoadBalancer services — does Cilium's NodePort/LoadBalancer handling conflict with HCCM?
- Recommended approach: use Cloudflare Tunnel (not HCCM LoadBalancers) for ingress — does this eliminate the Cilium/HCCM conflict?
- If HCCM is not used: any cleanup needed when Cilium handles NodePort?

**Private networks:**
- Hetzner private networks: if helix-stax-vps joins the cluster as a worker node, it may be in a different datacenter (hil-dc1 vs ash-dc1) — no Hetzner private network between them
- Cross-datacenter networking: VXLAN over public internet between nodes — Cilium VXLAN configuration for this
- Encryption requirement: pod-to-pod traffic crossing the public internet between ash and hil should be encrypted — WireGuard solves this

**Known issues:**
- Search Cilium GitHub issues for "Hetzner" — any open or recently resolved issues specific to Hetzner Cloud
- AlmaLinux 9 + Cilium + Hetzner: any specific combinations known to cause problems

---

### CIL-11. Cilium + CrowdSec Integration

CrowdSec runs as a host-level daemon. Document how it interacts with Cilium:

**Layer separation:**
- CrowdSec sits at the host network level: it sees traffic BEFORE it enters the eBPF datapath
- CrowdSec firewall bouncer: adds iptables/nftables rules to block IPs — does this coexist with Cilium's eBPF datapath?
- Potential conflict: Cilium bypasses iptables for most traffic (when kube-proxy replacement is enabled) — do CrowdSec iptables rules still apply?
- Answer needed: if Cilium replaces kube-proxy (bypasses iptables), does CrowdSec's firewall bouncer (which uses iptables/nftables) still block malicious IPs?

**CrowdSec Traefik bouncer:**
- CrowdSec Traefik bouncer runs as a Traefik plugin — this is at the application layer, above Cilium
- This should be unaffected by Cilium CNI choice
- Confirm: Traefik plugin bouncer works regardless of whether Cilium or Flannel is the CNI

**Recommended integration pattern:**
- Keep CrowdSec firewall bouncer using nftables (not iptables) when Cilium kube-proxy replacement is active
- Or: disable CrowdSec firewall bouncer and rely exclusively on the Traefik plugin bouncer (application layer only)
- Cilium + CrowdSec nftables: does nftables-based blocking work when Cilium eBPF is the data plane?

---

### CIL-12. Cilium Cluster Mesh (Future: VPS as Worker)

When helix-stax-vps joins as a second node, we may want cluster mesh capabilities:

**Single cluster, multiple nodes (our immediate use case):**
- Cilium in a 2-node K3s cluster: one control plane (ash-dc1) + one worker (hil-dc1, different datacenter)
- Cilium VXLAN between nodes in different datacenters: configuration, MTU, encryption
- This is NOT Cluster Mesh (that is for separate Kubernetes clusters) — it is just standard multi-node Cilium

**Cluster Mesh (future, if we need it):**
- What Cluster Mesh is: connecting two separate Kubernetes clusters so pods in each can reach pods in the other
- Use case: separate cluster per datacenter with service discovery across clusters
- Prerequisites: each cluster needs Cilium, shared CA for certificates
- When this becomes relevant: if we split into multiple K3s clusters (e.g., one per datacenter)
- Not needed for our current setup — document as future reference only

---

### CIL-13. Monitoring: Cilium Prometheus Metrics and Grafana

**Cilium metrics endpoint:**
- Cilium agent exposes Prometheus metrics on port 9962 (by default)
- Hubble metrics on port 9965
- cilium-operator metrics on port 9963
- ServiceMonitor resources for kube-prometheus-stack to scrape all three

**Helm values for Prometheus integration:**
- `prometheus.enabled: true`
- `hubble.metrics.enabled` list
- `operator.prometheus.enabled: true`

**Grafana dashboards:**
- Official Cilium Grafana dashboards: Grafana.com IDs or GitHub source
- How to import: using `grafana.dashboards` in kube-prometheus-stack values, or manual import
- Dashboard list: Cilium Agent metrics, Hubble L4 flows, Hubble DNS, Hubble HTTP

**Key metrics to alert on:**
- `cilium_drop_count_total`: packets dropped by policy (alert if > 0 unexpectedly)
- `cilium_endpoint_state`: endpoint health (alert if not `ready`)
- `cilium_k8s_client_api_calls_total{return_code!~"2[0-9][0-9]"}`: API errors
- `hubble_drop_total`: Hubble-reported drops

---

### CIL-14. Troubleshooting Cilium

Document the complete troubleshooting toolkit:

**Status commands:**
- `cilium status`: overall health, component status, BPF maps status
- `cilium status --verbose`: detailed status including eBPF feature availability
- `cilium connectivity test`: automated connectivity test between pods — what it tests, how long it takes
- `cilium endpoint list`: all endpoints (pods) known to Cilium, their policy enforcement state
- `cilium map list`: list all BPF maps
- `cilium policy get`: show active policy rules

**Hubble troubleshooting:**
- `hubble observe --verdict DROPPED --last 50`: find recently dropped flows (policy issues)
- `hubble observe -n <namespace>`: flows in a specific namespace
- `hubble observe --pod <pod-name>`: flows for a specific pod (ingress + egress)
- Interpreting Hubble output: what each field means, how to read drop reasons

**eBPF debugging:**
- `cilium bpf lb list`: show BPF load balancer table (service entries)
- `cilium bpf endpoint list`: show BPF endpoint map
- `cilium bpf nat list`: show NAT table
- `cilium bpf policy get <endpoint-id>`: show BPF policy program for a specific endpoint
- `bpftool prog list`: raw bpftool to list all eBPF programs loaded

**Common errors and resolutions:**
- `level=error msg="Failed to start" error="BPF filesystem is not mounted"`: `/sys/fs/bpf` not mounted — exact fix
- `cilium-agent CrashLoopBackOff`: kernel too old, missing eBPF support — how to check kernel capabilities
- `Error: unable to connect to server: http2: client connection lost`: Hubble relay connection issue — restart relay
- Pods stuck in `ContainerCreating` after Cilium install: CNI not configured correctly, check `/etc/cni/net.d/`
- NetworkPolicy not being enforced: `cilium status | grep Policy` — check if policy enforcement is enabled
- AVC denials blocking Cilium on SELinux: `ausearch -m AVC -ts recent | grep cilium` — common patterns and fixes
- `IPAM: IP address exhausted`: pod CIDR too small, how to expand

**Rollback procedure:**
- How to revert from Cilium back to Flannel if Cilium causes issues
- Step-by-step: uninstall Cilium Helm chart, re-enable Flannel in K3s config, restart K3s
- What state survives rollback (running pods may need restart), what does not (NetworkPolicy objects remain but unenforced by Flannel)

---

### Best Practices & Anti-Patterns

- Top 10 best practices for running Cilium on K3s in production on a small cluster
- What configurations look correct but silently fail on AlmaLinux 9.7 with SELinux enforcing
- Performance anti-patterns: when to enable kube-proxy replacement vs when the overhead isn't worth it
- NetworkPolicy anti-patterns: over-permissive policies (no default deny), under-tested policies (breaks readiness probes)
- Hubble anti-patterns: enabling all metrics on a constrained node, storing full flow logs without retention limits
- When to use standard NetworkPolicy vs CiliumNetworkPolicy CRD: the portability trade-off
- Common mistakes when migrating from Flannel: not draining nodes first, not verifying CoreDNS after CNI swap
- What NOT to do on a single-control-plane cluster: `operator.replicas: 2` causes a scheduling failure
- Observability trap: enabling Hubble full flow logging on every pod in production — storage and CPU implications

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| Cilium vs Flannel | NetworkPolicy enforcement needed from day 1 | Cilium | Flannel has zero policy enforcement |
| Cilium vs Flannel | Smallest possible operational footprint | Flannel | Less complexity, fewer failure modes |
| Cilium vs Flannel | AlmaLinux 9.7 kernel meets eBPF requirements | Cilium | All features available |
| Cilium vs Flannel | AlmaLinux 9.7 kernel too old (unlikely) | Flannel | Cilium eBPF features unavailable |
| kube-proxy replacement: yes vs no | 50+ services, high inter-service traffic | Enable | eBPF outperforms iptables at scale |
| kube-proxy replacement: yes vs no | Small cluster, <50 services | Disable initially | Reduces risk, complexity gain not worth it |
| WireGuard encryption: yes vs no | Nodes in different datacenters | Enable | Pod traffic crosses public internet |
| WireGuard encryption: yes vs no | Single datacenter, private network | Optional | Traffic on private LAN, lower risk |
| Hubble UI: enable vs disable | Active debugging and observability | Enable | Flow visibility is primary Cilium value |
| Hubble UI: enable vs disable | Absolute minimum resources | Disable initially | Enable when monitoring stack is deployed |
| Migration timing: fresh vs in-place | Fresh K3s rebuild (our case) | Fresh install | Cleanest, no migration risk |
| Migration timing: fresh vs in-place | Existing cluster with stateful workloads | In-place with downtime | Migration required, follow documented procedure |
| CiliumNetworkPolicy vs NetworkPolicy | Need L7 filtering (HTTP, gRPC) | CiliumNetworkPolicy | Standard NetworkPolicy is L3/L4 only |
| CiliumNetworkPolicy vs NetworkPolicy | Want portability to other CNIs | Standard NetworkPolicy | Cilium enforces both |

### Common Pitfalls

- Installing Cilium without `--flannel-backend=none` in K3s: both CNIs try to configure pod networking simultaneously, causing IP conflicts and random pod failures
- Setting `operator.replicas: 2` on a single-node cluster: second replica is unschedulable, operator enters pending state, Cilium IPAM fails
- Not setting `k8sServiceHost` and `k8sServicePort` when `kubeProxyReplacement: true`: Cilium cannot reach the API server, endpoints not updated, services stop working
- Applying default-deny NetworkPolicy before allowing CoreDNS: all DNS resolution stops, pods timeout trying to reach any service
- Enabling kube-proxy replacement without first disabling kube-proxy in K3s: both manage iptables/BPF service tables, causing routing conflicts
- Using CiliumNetworkPolicy with `fromEndpoints` identity references that don't match actual pod labels: policy silently allows or blocks wrong pods
- Not mounting `/sys/fs/bpf` before Cilium starts: BPF programs cannot be pinned, Cilium agent restarts in a loop
- Forgetting `ipam.mode: "kubernetes"` on K3s: Cilium uses cluster-scope IPAM which conflicts with K3s's built-in node CIDR allocation
- Running `cilium connectivity test` during production traffic: the test creates namespaces and pods that may trigger unintended NetworkPolicy blocks on the test traffic itself
- Assuming SELinux in permissive mode is sufficient for testing: permissive mode logs denials but allows them — switching to enforcing reveals real failures

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content

Core reference that an AI agent needs daily:
- Cilium quick reference: `cilium status`, `cilium endpoint list`, `cilium connectivity test`, `hubble observe`, `cilium bpf lb list`
- K3s install flags required for Cilium: exact flags and config.yaml format
- SELinux checklist for Cilium on AlmaLinux 9.7: what to check, what to allow
- NetworkPolicy quick-write reference: default-deny template, CoreDNS allow template, database allow template
- Hubble CLI cheat sheet: flows by namespace, dropped flows, HTTP flows, DNS flows
- Troubleshooting decision tree: Cilium not ready → check status → check BPF mount → check kernel version → check SELinux
- kube-proxy replacement: is it on? How to check. How to verify services still work.
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content

Deep specifications:
- Complete annotated Helm `values.yaml` for Cilium on K3s with AlmaLinux 9.7 (every relevant field with comment explaining why)
- K3s `config.yaml` showing the required flags for Cilium (flannel-backend: none, disable-network-policy)
- Complete NetworkPolicy examples for every Helix Stax namespace (monitoring, database, n8n, ai, kube-system, ingress)
- CiliumNetworkPolicy examples for L7 use cases (allow only /metrics on port 9090)
- Hubble metrics list: which metrics to enable for Prometheus, what each measures
- ServiceMonitor YAML for scraping cilium-agent, hubble, and cilium-operator
- Grafana dashboard import procedure: dashboard IDs and import method
- Cilium vs Flannel comparison matrix (our specific scenario: 2-node K3s, AlmaLinux 9.7, Hetzner)
- Rollback procedure: step-by-step from Cilium back to Flannel

### ## examples.md Content

Copy-paste-ready examples specific to Helix Stax:
- Real values.yaml for our cluster: helix-stax-cp at 178.156.233.12, K3s API on 6443, our pod/service CIDRs
- K3s config.yaml with Cilium flags for Ansible deployment
- Ansible tasks for fresh K3s + Cilium install: set K3s flags, install K3s (no CNI), install Cilium via Helm, verify
- Default-deny NetworkPolicy for n8n namespace with all required allow rules to make n8n functional
- Default-deny NetworkPolicy for database namespace allowing only app pods on port 5432
- Traefik IngressRoute for Hubble UI (`hubble.helixstax.net`) with Cloudflare Access annotations
- Prometheus scrape config for Cilium metrics (ServiceMonitor resource)
- `hubble observe` command variants for our specific services (n8n flows, database flows, monitoring flows)
- WireGuard encryption Helm values (for when VPS joins as cross-datacenter worker)
- Step-by-step runbook: "Fresh K3s install with Cilium from day 1" (the recommended path for Helix Stax rebuild)
- Step-by-step runbook: "In-place Flannel to Cilium migration with downtime" (for reference)
- CrowdSec compatibility check: nftables bouncer config that coexists with Cilium eBPF dataplane

Use `# Cilium CNI for K3s` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual Helm values files, actual NetworkPolicy YAML, actual Ansible tasks, and actual Hubble CLI commands. Do NOT give theory — give copy-paste-ready configurations for Cilium on K3s running on AlmaLinux 9.7 at Helix Stax. Every config must use our real CIDRs (10.42.0.0/16, 10.43.0.0/16), our real hostnames (helixstax.net), and our real service namespaces.
