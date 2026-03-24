---
title: "ADR-014: Application-Layer Encryption Over LUKS"
status: "Accepted"
date: "2026-03-23"
category: "architecture"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC6.7"]
  - framework: "ISO 27001"
    controls: ["A.8.24"]
  - framework: "NIST CSF"
    controls: ["PR.DS-1"]
  - framework: "HIPAA"
    controls: ["164.312(a)(2)(iv)"]
author: "Wakeem Williams"
co_author: "Cass Whitfield"
---

# ADR-014: Application-Layer Encryption Over LUKS Full-Disk Encryption

## Status
Accepted

## Context
SOC 2 (CC6.7), ISO 27001 (A.8.24), and HIPAA (164.312(a)(2)(iv)) require encryption of data at rest. Two approaches exist:

1. **LUKS full-disk encryption** — encrypts the entire disk at the block level. Every reboot requires manual key injection via dracut-sshd or Hetzner console. A single operator cannot guarantee timely unlock during unplanned reboots.

2. **Application-layer encryption** — each service encrypts its own data. No reboot dependency. Each encryption layer is independently verifiable.

The infrastructure runs on Hetzner Cloud (ISO 27001 certified datacenters). Physical disk theft is mitigated by the provider. The threat model for a cloud VPS is primarily logical access, not physical.

## Options Considered

### A) LUKS Full-Disk Encryption
- Encrypts everything including OS, logs, swap
- Requires dracut-sshd for remote unlock after every reboot
- Single point of failure: if unlock fails, entire server is offline
- Complex: rescue mode operations can corrupt LUKS headers
- Maximum coverage but maximum operational burden

### B) Application-Layer Encryption (Selected)
- K3s `--secrets-encryption` for Kubernetes Secrets
- PostgreSQL TDE via pg_tde extension for database data
- MinIO SSE-KMS via OpenBao for object storage
- Velero + restic encryption for backups to Backblaze B2
- No reboot dependency, no manual intervention
- Each layer independently auditable

### C) No Encryption
- Rejected — fails compliance requirements

## Decision
Use **application-layer encryption** for all sensitive data at rest. Do not implement LUKS full-disk encryption at this time.

## Rationale
1. **Operational burden**: A 1-person team cannot guarantee manual LUKS unlock during unplanned reboots (middle of night, during travel, incident response)
2. **Auditor acceptance**: SOC 2 and HIPAA auditors verify that sensitive data is encrypted — not that the entire OS disk is encrypted. Application-layer encryption satisfies the control.
3. **Provider coverage**: Hetzner Cloud datacenters are ISO 27001 certified. Physical security is their responsibility.
4. **Rescue mode risk**: LUKS headers and dracut-sshd configurations are fragile during rescue operations (proven by 2026-03-23 incident where multiple rescue cycles corrupted server state)
5. **Defense-in-depth**: Application-layer encryption provides more granular control — each service has its own encryption key managed by OpenBao
6. **Future option**: LUKS can be added later if a specific client contract requires it, without disrupting the existing application-layer encryption

## Encryption Stack

| Layer | Tool | What's Encrypted | Key Management |
|-------|------|-----------------|----------------|
| Kubernetes Secrets | K3s `--secrets-encryption` | All K8s Secret objects in etcd/SQLite | K3s internal |
| Database | pg_tde (CloudNativePG) | PostgreSQL data files | OpenBao KMS |
| Object Storage | MinIO SSE-KMS | All objects in MinIO buckets | OpenBao KMS |
| Cache | Valkey | Secured by K3s network encryption (WireGuard) | N/A (in-memory) |
| Backups | Velero + restic | Backup archives before upload to Backblaze B2 | restic encryption key in OpenBao |
| Transit | Flannel WireGuard | All east-west pod traffic | K3s managed |
| Ingress | TLS 1.3 via cert-manager | All external HTTPS traffic | Let's Encrypt |

## Consequences

### Positive
- Zero reboot dependency — servers come back online without manual intervention
- Each encryption layer independently verifiable for auditors
- OpenBao as single KMS simplifies key rotation
- No risk of LUKS header corruption during rescue operations

### Negative
- OS-level files (logs, temp files, swap) are not encrypted at rest
- If an attacker gains root on the host, they can read unencrypted OS files
- Some auditors may ask why full-disk isn't used — respond with this ADR + Hetzner ISO 27001 cert

### Mitigation for Negatives
- Swap disabled (K3s best practice anyway)
- Sensitive logs shipped to encrypted MinIO via Loki (not kept on local disk long-term)
- Temp files cleaned by systemd-tmpfiles
- Host access restricted to SSH key-only + CrowdSec + firewalld

## Revisit Conditions
- Client contract explicitly requires FIPS 140-2 or full-disk encryption
- FedRAMP pursuit (requires FIPS validated encryption modules)
- Team grows beyond 3 people (can afford LUKS unlock rotation)

---

*Author: Wakeem Williams | Co-Author: Cass Whitfield*
*Date: 2026-03-23 | Version: 1.0*
