# ADR-004: Flannel WireGuard for East-West Encryption

## TLDR

Enable Flannel's WireGuard backend (`--flannel-backend=wireguard-native`) for transparent node-to-node encryption of all pod traffic, with Cilium as a future upgrade path.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax operates a 2-node K3s cluster on Hetzner Cloud. Pod-to-pod traffic between nodes traverses the public internet (Hetzner does not provide a private network between all VPS regions). Without encryption, east-west cluster traffic is vulnerable to interception. SOC 2 CC6.7 and HIPAA 164.312(e)(1) require encryption of data in transit, including internal service communication.

K3s ships with Flannel as its default CNI. Flannel supports a WireGuard backend that encrypts all inter-node traffic at the kernel level with minimal overhead. The alternative is replacing Flannel entirely with Cilium, which provides WireGuard encryption plus eBPF-based networking and advanced NetworkPolicies -- but at significantly higher operational complexity for a 2-node cluster.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: Flannel + WireGuard | Enable `wireguard-native` backend | Zero additional components, kernel-level performance, K3s native | No L7 NetworkPolicies, limited observability | Satisfies transit encryption requirements |
| **Option B**: Cilium | Replace Flannel with Cilium CNI | eBPF networking, L7 policies, Hubble observability | Complex migration, higher resource usage, overkill for 2 nodes | Exceeds requirements with advanced policies |
| **Option C**: No encryption | Keep default VXLAN backend | Simplest configuration | East-west traffic unencrypted over public internet | Fails SOC 2 CC6.7, HIPAA 164.312(e)(1) |
| **Option D**: IPsec overlay | Manual IPsec tunnels between nodes | Well-established protocol | Manual key management, higher CPU overhead than WireGuard | Satisfies requirements but operationally heavy |

---

## Decision

We will enable Flannel's WireGuard backend on the K3s cluster by setting `--flannel-backend=wireguard-native` in the K3s server configuration. This provides transparent, kernel-level encryption of all pod-to-pod traffic between nodes with no application changes required.

Cilium is designated as the future upgrade path when the cluster grows beyond 2 nodes or when L7 NetworkPolicies and eBPF observability (Hubble) become necessary. The migration path is documented but not scheduled.

K3s server configuration addition:
```yaml
# /etc/rancher/k3s/config.yaml
flannel-backend: wireguard-native
```

---

## Rationale

WireGuard provides strong encryption (ChaCha20-Poly1305) with kernel-level performance and near-zero configuration overhead. Flannel's native WireGuard backend is a single configuration flag in K3s -- no additional components to deploy, monitor, or maintain. For a 2-node cluster, Cilium's advanced capabilities (eBPF dataplane, L7 policies, Hubble) do not justify the migration complexity and resource overhead. The upgrade path to Cilium remains open and does not require re-architecting applications.

---

## Consequences

### Positive

- All inter-node pod traffic encrypted transparently at the kernel level
- Minimal performance overhead (WireGuard is faster than IPsec and userspace encryption)
- Single configuration flag -- no additional components to deploy or maintain
- Satisfies compliance requirements for data-in-transit encryption
- Clean upgrade path to Cilium when cluster scales

### Negative

- No L7 (application-layer) NetworkPolicies -- only L3/L4 filtering via standard Kubernetes NetworkPolicy
- Limited network observability compared to Cilium's Hubble
- WireGuard keys are auto-managed by Flannel -- no manual key rotation control
- Cilium migration will require a maintenance window and pod network reconfiguration

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Enable wireguard-native backend on K3s cluster | Wakeem Williams | 2026-04-06 | TBD |
| Verify inter-node encryption with tcpdump | Wakeem Williams | 2026-04-06 | TBD |
| Add trusted zones for cni0/flannel.1 in firewalld | Wakeem Williams | 2026-04-06 | TBD |
| Document Cilium migration runbook for future scaling | Wakeem Williams | 2026-05-01 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| K3s server/agent config | `flannel-backend` parameter change |
| Flannel | Switches from VXLAN to WireGuard backend |
| firewalld | Must trust cni0 and flannel.1 interfaces |
| NetworkPolicies | Limited to L3/L4 until Cilium migration |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC6.7 | Encryption of data in transit | WireGuard encrypts all inter-node pod traffic |
| ISO 27001 | A.8.24 | Use of cryptography | Kernel-level ChaCha20-Poly1305 encryption |
| NIST CSF 2.0 | PR.DS-2 | Data-in-transit protected | Transparent encryption for east-west traffic |
| HIPAA | 164.312(e)(1) | Transmission security | All internal cluster communication encrypted |
| CIS Controls v8.1 | 3.10 | Encrypt sensitive data in transit | WireGuard backend encrypts CNI overlay |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
