# Cluster Topology

**Last Updated**: 2026-03-25
**Cluster**: helix-stax (K3s v1.32.3+k3s1)
**CNI**: Flannel (VXLAN)

## Nodes

| Node | Role | IP | Port | Hardware | Location | Status |
|------|------|----|------|----------|----------|--------|
| helix-stax-cp | Control Plane | 178.156.233.12 | 2222 | CPX31 | Hetzner US Ashburn | Active |
| helix-stax-test | Worker (general) | 178.156.172.47 | 2222 | CPX11 | Hetzner US Ashburn | Active — joined cluster 2026-03-25 |
| helix-stax-vps | Worker (database) | 5.78.145.30 | 22 | CPX31 | Hetzner US Hillsboro | Rebuilding — blocked (unreachable) |
| Robot | Worker (AI/GPU) | TBD | TBD | Dedicated | TBD | Pending — not yet provisioned |

## Node Labels

| Node | Labels |
|------|--------|
| helix-stax-cp | control-plane, master (K3s default) |
| helix-stax-test | `node-role=worker`, `workload=general` |
| helix-stax-vps | `node-role=worker`, `workload=database` (pending) |
| Robot | `node-role=worker`, `workload=ai` (planned) |

## Workload Placement

| Node | Intended Workloads |
|------|-------------------|
| helix-stax-cp | K3s control plane, Devtron, Traefik ingress |
| helix-stax-test | General apps: AI services (Ollama, Open WebUI), monitoring, Rocket.Chat, Harbor |
| helix-stax-vps | Database-heavy: CloudNativePG, Valkey, MinIO, n8n |
| Robot | GPU inference workloads (future) |

## Network

```
Internet
    |
Cloudflare (CDN + WAF + DDoS)
    |
Hetzner Cloud Network
    |
helix-stax-cp (178.156.233.12)   <-- K3s API: 6443/tcp
    |                                    Traefik: 80/tcp, 443/tcp
    |-- Flannel VXLAN (UDP 8472) --+
    |-- Kubelet API (TCP 10250) ---+
    |                              |
helix-stax-test (178.156.172.47)  helix-stax-vps (5.78.145.30)
 [general workloads]               [database workloads — rebuilding]
```

### CIDRs

| Network | CIDR |
|---------|------|
| Pod network (Flannel) | 10.42.0.0/16 |
| Service network | 10.43.0.0/16 |

### Firewall Rules (per worker node)

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 8472 | UDP | CP + other workers | Flannel VXLAN (CNI overlay) |
| 10250 | TCP | CP | Kubelet API |
| 2222 | TCP | Admin IP | SSH (post-hardening) |

## OS and Hardening

All nodes run AlmaLinux 9.7. Hardening applied before K3s install:

- SELinux: enforcing (enforced at install time, verified by k3s_agent role)
- SSH: moved to port 2222, key-only auth, max 3 auth tries
- CrowdSec: active (nftables bouncer, `crowdsecurity/linux` + `crowdsecurity/sshd` collections)
- Sysctl: ip_forward, bridge-nf-call-iptables enabled (required for K3s + Flannel)

## Storage

All PVCs use `local-path` storage class (K3s default, host-path volumes). No distributed storage — data is local to the node that runs the workload.

## Related

- [helm-services.md](helm-services.md) — Services deployed on this cluster
- [devtron-config.md](devtron-config.md) — CI/CD layer
- ADR: `docs/adr/` — Infrastructure decisions
