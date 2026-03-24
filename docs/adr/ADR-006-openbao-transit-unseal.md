# ADR-006: OpenBao Transit Unseal Architecture

## TLDR

Deploy a dedicated third OpenBao instance as a "Seal Service" to provide transit auto-unseal for the primary 2-node OpenBao cluster, eliminating manual Shamir unseal on every reboot.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax uses OpenBao as the central secrets manager and KMS. OpenBao runs on a 2-node K3s cluster (heart + helix-worker-1). By default, OpenBao uses Shamir Secret Sharing for seal/unseal -- requiring a quorum of key holders to manually unseal every time a pod restarts or a node reboots.

On a single-operator infrastructure, manual Shamir unseal is operationally untenable. Every K3s node reboot (during rolling patches, kernel updates, or LUKS unlock) triggers an OpenBao unseal ceremony. Cloud-managed KMS (AWS KMS, GCP Cloud KMS) is the typical auto-unseal mechanism, but Hetzner provides no KMS service and introducing AWS KMS creates a cross-cloud dependency that undermines infrastructure sovereignty.

OpenBao's transit seal mechanism allows one OpenBao instance to unseal another using its transit secrets engine. A dedicated "Seal Service" OpenBao instance -- initialized with a simpler unseal process and running independently -- can provide auto-unseal for the primary cluster.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: Transit unseal (dedicated instance) | Third OpenBao as Seal Service | Automatic unseal, no cloud dependency, self-hosted | Additional instance to maintain, single Seal Service is a dependency | Satisfies key management requirements |
| **Option B**: Manual Shamir unseal | Default 3-of-5 key split | Maximum security, no dependencies | Operationally impossible for single operator on every reboot | Satisfies but blocks operations |
| **Option C**: AWS KMS auto-unseal | Use AWS KMS as unseal mechanism | Fully managed, highly available | Cross-cloud dependency, cost, data sovereignty concern | Satisfies but introduces third-party |
| **Option D**: Kubernetes auth unseal | Use K3s service account for unseal | No additional infrastructure | Circular dependency -- K3s secrets need OpenBao, OpenBao needs K3s | Fragile, circular dependency risk |

---

## Decision

We will deploy a dedicated third OpenBao instance as the "Seal Service" for transit auto-unseal of the primary OpenBao cluster.

**Architecture:**
```
Seal Service (standalone OpenBao)
  |
  |-- Transit secrets engine enabled
  |-- Transit key: "autounseal"
  |
  +-- Primary OpenBao Node 1 (heart)
  |     seal "transit" { address = "seal-service:8200" }
  |
  +-- Primary OpenBao Node 2 (helix-worker-1)
        seal "transit" { address = "seal-service:8200" }
```

**Seal Service characteristics:**
- Runs as a standalone pod in K3s (not HA -- single instance)
- Initialized with a single unseal key (operator holds)
- Transit secrets engine enabled with a dedicated `autounseal` key
- Policy restricts access to transit encrypt/decrypt only
- The Seal Service itself uses manual Shamir unseal (single key, entered once after node boot)

**Primary cluster configuration:**
```hcl
seal "transit" {
  address         = "http://openbao-seal-service:8200"
  token           = "<policy-scoped token>"
  disable_renewal = "false"
  key_name        = "autounseal"
  mount_path      = "transit/"
}
```

---

## Rationale

Transit unseal eliminates the need for manual Shamir ceremonies on every primary cluster pod restart while keeping all key material self-hosted. The Seal Service requires a single manual unseal (one key) only when its own pod restarts -- which is infrequent since it runs on the control plane node. This is a dramatic operational improvement over unsealing 2 primary nodes with 3-of-5 key quorum on every maintenance window. AWS KMS would work but introduces cross-cloud dependency and cost for a service that can be self-hosted.

---

## Consequences

### Positive

- Primary OpenBao cluster auto-unseals on pod restart and node reboot
- No cloud provider dependency for key management
- All key material remains within Helix Stax infrastructure
- Single manual unseal (Seal Service) instead of multi-key ceremony
- Reduces maintenance window duration significantly

### Negative

- Seal Service is a single point of failure for auto-unseal (if down, primary nodes cannot auto-unseal)
- Additional OpenBao instance to monitor, backup, and maintain
- Seal Service token must be securely stored and rotated
- If Seal Service is compromised, attacker gains unseal capability (mitigated by network isolation and RBAC)

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Deploy Seal Service OpenBao instance | Wakeem Williams | 2026-04-13 | TBD |
| Configure transit engine and autounseal key | Wakeem Williams | 2026-04-13 | TBD |
| Migrate primary cluster from Shamir to transit seal | Wakeem Williams | 2026-04-20 | TBD |
| Configure monitoring alerts for Seal Service health | Wakeem Williams | 2026-04-20 | TBD |
| Document Seal Service recovery procedure | Wakeem Williams | 2026-04-27 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| OpenBao primary cluster | Seal mechanism changes from Shamir to transit |
| K3s cluster | Additional pod for Seal Service |
| Monitoring (Prometheus) | New target for Seal Service health checks |
| Maintenance runbooks | Simplified unseal procedure |
| Backup (Velero) | Seal Service data must be included in backups |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC6.1 | Logical and physical access controls | Automated unseal with policy-scoped token |
| ISO 27001 | A.8.24 | Use of cryptography | Transit engine provides cryptographic key wrapping |
| NIST CSF 2.0 | PR.AC-7 | Manage identities and credentials | Centralized secrets management with automated lifecycle |
| HIPAA | 164.312(a)(2)(iv) | Encryption and decryption | OpenBao manages encryption keys for all services |
| CIS Controls v8.1 | 3.11 | Encrypt sensitive data at rest | Transit key protects master encryption keys |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
