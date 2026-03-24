---
title: Defense-in-Depth Architecture
author: Wakeem Williams
co_author: Quinn Mercer
date: 2026-03-23
status: Active
version: "1.0"
compliance_frameworks:
  - NIST CSF 2.0
  - CIS Controls v8.1
  - SOC 2 (TSC CC6, CC7)
  - ISO 27001:2022 (A.8)
references:
  - ADR-002 (CIS L1 over STIG)
  - ADR-003 (CrowdSec replaces fail2ban)
  - ADR-004 (Flannel WireGuard)
  - ADR-009 (Container supply chain)
  - ADR-012 (Scanning stack)
---

# Defense-in-Depth Architecture

## 1. Overview

Helix Stax employs a 10-layer defense-in-depth model spanning from the physical datacenter through to application data. Each layer implements independent controls so that a breach at any single layer does not compromise the system. This architecture is designed for a 2-node K3s cluster on Hetzner Cloud running AlmaLinux 9.7, targeting SOC 2 Type II, ISO 27001, and HIPAA compliance.

---

## 2. Ten-Layer Security Model

| Layer | Domain | Controls | Monitoring | Priority | Gaps |
|-------|--------|----------|------------|----------|------|
| 0 | Physical/Cloud (Hetzner) | Datacenter physical security, ISO 27001 certified DCs | Hetzner API audit logs via n8n | P0 | No provider KMS for auto-unseal |
| 1 | Network Edge (Cloudflare) | WAF, Bot Fight Mode, DDoS protection, Zero Trust Access | Logpush to Loki/MinIO | P0 | Origin Pull auth needed |
| 2 | Host OS (AlmaLinux 9) | CIS L1, SELinux enforcing, LUKS FDE, firewalld, auditd | auditd -> Loki, AIDE -> Airflow/n8n | P0 | Replace fail2ban with CrowdSec |
| 3 | Container Runtime | containerd hardened config, seccomp default profiles, rootless where possible | Journal -> Loki | P1 | AppArmor conflicts; SELinux sufficient on RHEL |
| 4 | Orchestration (K3s) | API hardened, secrets encryption at rest, RBAC, audit logging | K3s audit -> Loki | P0 | Manual PKI permission fix needed |
| 5 | Network (Flannel) | WireGuard encryption (east-west), default-deny NetworkPolicy | NeuVector packet capture | P1 | Trusted zones for cni0/flannel.1 in firewalld |
| 6 | Admission (Kyverno) | Cosign image verification, Pod Security Standards enforcement | Policy violations -> Prometheus | P2 | Helm chart privileged exceptions |
| 7 | Runtime (NeuVector) | Process monitoring, L7 microsegmentation, zero-drift mode | SYSLOG -> Loki, CVE -> Rocket.Chat | P2 | Needs tuning in Discover before Protect |
| 8 | Application (Zitadel) | OIDC/OAuth2, Traefik TLS 1.3 termination, session management | Auth audit trails -> Loki | P1 | M2M short-lived tokens needed |
| 9 | Data (PG + MinIO) | TDE via LUKS, SSE-KMS via OpenBao, encrypted backups (Velero) | OpenBao logs, Velero webhooks | P0 | Backup restore testing needed |

---

## 3. Layer Details

### Layer 0: Physical/Cloud (Hetzner)

Hetzner operates ISO 27001-certified datacenters. Physical security is inherited from the provider.

**Controls**:
- Hetzner Robot API restricted to IP allowlist
- API actions logged and forwarded via n8n to audit trail
- No provider KMS available -- OpenBao transit unseal used instead (see ADR-006)

**Compliance mapping**: SOC 2 CC6.4 (Physical Access), ISO 27001 A.7 (Physical Security)

### Layer 1: Network Edge (Cloudflare)

All public traffic passes through Cloudflare before reaching the origin servers.

**Controls**:
- WAF managed ruleset + custom rules
- Bot Fight Mode (managed challenge for automated traffic)
- DDoS protection (automatic, always-on)
- Zero Trust Access for internal admin panels
- Authenticated origin pulls (TLS client cert)

**Monitoring**: Cloudflare Logpush -> Loki (HTTP logs, firewall events, WAF blocks)

**Compliance mapping**: SOC 2 CC6.6 (Boundary Protection), NIST CSF PR.AC-5

### Layer 2: Host OS (AlmaLinux 9.7)

The foundational hardening layer. Both nodes follow identical configurations managed by Ansible.

**Controls**:
- CIS Benchmark Level 1 - Server baseline (ADR-002)
- Selective Level 2 adoptions: IPv6 disabled, auditd immutable (-e 2), obscure protocols blacklisted
- SELinux in enforcing mode
- LUKS full-disk encryption with dracut-sshd remote unlock (ADR-005)
- firewalld with default drop policy
- auditd with comprehensive syscall rules
- CrowdSec host agent replacing fail2ban (ADR-003)
- Automatic security updates via dnf-automatic

**K3s exceptions** (documented in OpenSCAP tailoring file):
- net.ipv4.ip_forward=1 (required for pod networking)
- net.bridge.bridge-nf-call-iptables=1 (required for CNI)
- br_netfilter and overlay kernel modules loaded
- firewalld permits K3s-managed forward chains

**Monitoring**: auditd -> Loki, AIDE -> Airflow daily FIM checks

**Compliance mapping**: CIS Controls v8.1 4.1, SOC 2 CC6.3, ISO 27001 A.8.8, NIST CSF PR.IP-1

### Layer 3: Container Runtime

containerd is the K3s default runtime, hardened at the host level.

**Controls**:
- Default seccomp profile applied to all pods
- Rootless containers where application permits
- Read-only root filesystem enforced via Pod Security Standards
- No privileged containers (exceptions documented per-namespace)

**Monitoring**: containerd logs -> journald -> Loki

**Compliance mapping**: CIS Controls v8.1 4.8, NIST CSF PR.IP-1

### Layer 4: Orchestration (K3s)

K3s is deployed with hardened flags from day one.

**Controls**:
- `--protect-kernel-defaults=true`
- `--secrets-encryption` (encryption at rest for etcd secrets)
- `--kube-apiserver-arg='anonymous-auth=false'`
- `--kube-apiserver-arg='audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log'`
- RBAC with least-privilege service accounts
- PKI certificates: `chmod 600 /var/lib/rancher/k3s/server/tls/*.crt`
- kube-bench CIS Kubernetes Benchmark validation

**Monitoring**: K3s audit log -> Loki, API server metrics -> Prometheus

**Compliance mapping**: CIS Kubernetes Benchmark, SOC 2 CC6.1, ISO 27001 A.5.15

### Layer 5: Network (Flannel + WireGuard)

East-west traffic is encrypted at the CNI level.

**Controls**:
- Flannel WireGuard backend for node-to-node encryption (ADR-004)
- Default-deny NetworkPolicy per namespace
- Trusted firewalld zones for cni0 and flannel.1 interfaces
- Future: Cilium upgrade for native WireGuard + enhanced NetworkPolicies

**Monitoring**: NeuVector network packet capture, NetworkPolicy violations -> Prometheus

**Compliance mapping**: SOC 2 CC6.6, ISO 27001 A.8.20, NIST CSF PR.AC-5

### Layer 6: Admission Control (Kyverno)

All container images must be signed and verified before admission.

**Controls**:
- Cosign image signature verification (ADR-009)
- Pod Security Standards (Restricted profile by default)
- Resource quota enforcement per namespace
- Image pull policy: Always (no cached unverified images)

**Monitoring**: Kyverno policy violations -> Prometheus -> Alertmanager

**Compliance mapping**: CIS Controls v8.1 2.5, NIST CSF PR.IP-1

### Layer 7: Runtime Protection (NeuVector)

Behavioral monitoring and microsegmentation at runtime.

**Controls**:
- Process whitelisting per container profile
- L7 microsegmentation (application-aware firewalling)
- Zero-drift mode (blocks any deviation from learned profile)
- CVE scanning of running containers

**Deployment strategy**:
1. **Discover mode** (2 weeks): Learn normal behavior profiles
2. **Monitor mode** (2 weeks): Alert on violations without blocking
3. **Protect mode**: Enforce learned profiles

**Monitoring**: SYSLOG -> Loki, CVE alerts -> Rocket.Chat

**Compliance mapping**: SOC 2 CC7.2, ISO 27001 A.8.16, NIST CSF DE.CM-7

### Layer 8: Application (Zitadel)

Centralized identity and access management.

**Controls**:
- OIDC/OAuth2 for all internal services
- TLS 1.3 termination at Traefik
- Session management with configurable timeouts
- MFA enforcement for admin accounts
- Machine-to-machine (M2M) short-lived tokens (planned)

**Monitoring**: Zitadel audit trail -> Loki

**Compliance mapping**: SOC 2 CC6.1, ISO 27001 A.5.15-A.5.18, NIST CSF PR.AC-1

### Layer 9: Data (PostgreSQL + MinIO)

Data protection at rest and in transit.

**Controls**:
- PostgreSQL: LUKS-backed PersistentVolumes, sslmode=verify-full, CloudNativePG operator
- MinIO: SSE-KMS via OpenBao transit engine, S3 Object Lock for evidence (ADR-013)
- Valkey: Protected by underlying LUKS; in-transit encryption via TLS
- Backups: Velero -> MinIO -> Backblaze B2 (encrypted, versioned)

**Monitoring**: OpenBao audit logs, Velero backup webhook notifications

**Compliance mapping**: SOC 2 CC6.7, ISO 27001 A.8.24, NIST CSF PR.DS-1, HIPAA 164.312(a)(2)(iv)

---

## 4. CrowdSec Dual-Tier Architecture

CrowdSec replaces fail2ban with a dual-tier deployment covering both host and K3s layers (ADR-003).

```
                     +------------------------+
                     |  CrowdSec Central API  |
                     | (Global Threat Intel)  |
                     +------------------------+
                            |          |
               +------------+          +------------+
               |                                    |
   +-----------v-----------+          +-------------v-----------+
   |  Tier 1: Host Agent   |          |  Tier 2: K3s DaemonSet  |
   |  (per node)           |          |  (per node)             |
   +------------------------+         +-------------------------+
   | Monitors:              |         | Monitors:               |
   |  - sshd logs           |         |  - Traefik access logs  |
   |  - firewalld logs      |         |  - K3s API audit logs   |
   |  - systemd journal     |         |  - Application logs     |
   +------------------------+         +-------------------------+
   | Actions:               |         | Actions:                |
   |  - firewalld ban       |         |  - Traefik bouncer      |
   |  - nftables drop       |         |    (HTTP 403/captcha)   |
   +------------------------+         +-------------------------+
               |                                    |
               +------------+          +------------+
                            |          |
                     +------v----------v-----+
                     |  Shared Blocklist DB   |
                     |  (local + global)      |
                     +------------------------+
```

**Key advantages over fail2ban**:
- Written in Go (lower resource consumption than Python-based fail2ban)
- Global threat intelligence sharing (crowd-sourced IP reputation)
- Native Traefik bouncer integration for K3s
- Scenarios are YAML-defined and version-controlled
- Dual-tier ensures coverage at both host and orchestrator level

---

## 5. Container Supply Chain Pipeline

Every container image follows a verified path from build to runtime (ADR-009).

```
+------------------+     +------------------+     +------------------+
|  1. BUILD        |     |  2. SCAN         |     |  3. SIGN         |
|  Kaniko          | --> |  Harbor/Trivy    | --> |  Cosign          |
|  (rootless)      |     |  + Syft (SBOM)   |     |  (key in OpenBao)|
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
+------------------+     +------------------+     +------------------+
|  6. MONITOR      |     |  5. DEPLOY       |     |  4. VERIFY       |
|  NeuVector       | <-- |  ArgoCD (GitOps) | <-- |  Kyverno         |
|  (zero-drift)    |     |  via Devtron     |     |  (ClusterPolicy) |
+------------------+     +------------------+     +------------------+

Evidence at each stage:
  1. BUILD:   Kaniko build logs in Devtron
  2. SCAN:    Trivy CVE report + Syft SBOM (CycloneDX)
  3. SIGN:    Cosign signature (OCI artifact in Harbor)
  4. VERIFY:  Kyverno admission decision log
  5. DEPLOY:  ArgoCD sync event + Git commit SHA
  6. MONITOR: NeuVector process/network profile
```

**Pipeline rules**:
- Images with Critical/High CVEs are blocked from Harbor push
- Unsigned images are rejected by Kyverno at admission
- NeuVector alerts on any process not in the learned profile
- All evidence is hashed and archived to MinIO (Object Lock)

---

## 6. Cross-Layer Control Mapping

| CIS Controls v8.1 | SOC 2 (TSC) | ISO 27001:2022 | NIST CSF 2.0 | HIPAA | Layers |
|---|---|---|---|---|---|
| 4.1 Secure Config | CC6.3 | A.8.8 | PR.IP-1 | 164.308(a)(1)(ii)(A) | 2, 3, 4 |
| 3.3 Data Access Control | CC6.1 | A.5.15 | PR.AC-4 | 164.312(a)(1) | 4, 8 |
| 8.1 Audit Log Process | CC7.2 | A.8.15 | DE.CM-3 | 164.312(b) | 0-9 |
| 3.11 Encrypt at Rest | CC6.7 | A.8.24 | PR.DS-1 | 164.312(a)(2)(iv) | 2, 9 |
| 2.5 Software Allow-listing | CC6.8 | A.8.19 | PR.IP-1 | -- | 6, 7 |
| 13.1 Network Monitoring | CC7.2 | A.8.16 | DE.CM-1 | 164.312(b) | 1, 5, 7 |

---

## 7. Gap Remediation Priority

| Gap | Layer | Priority | Phase | Remediation |
|-----|-------|----------|-------|-------------|
| fail2ban -> CrowdSec migration | 2 | P0 | 2 | Install CrowdSec host agent, remove fail2ban |
| Origin Pull auth for Cloudflare | 1 | P0 | 2 | Configure authenticated origin pulls (TLS client cert) |
| K3s PKI permissions | 4 | P0 | 2 | chmod 600 on TLS certs after K3s install |
| GRUB bootloader password | 2 | P0 | 2 | Configure grub2-setpassword |
| ASLR verification | 2 | P0 | 2 | Verify kernel.randomize_va_space=2 |
| Cron authorization | 2 | P0 | 2 | Create /etc/cron.allow, delete /etc/cron.deny |
| M2M short-lived tokens | 8 | P1 | 3 | Configure Zitadel M2M with 5min token lifetime |
| Firewalld trusted zones for CNI | 5 | P1 | 2 | Add cni0/flannel.1 to trusted zone |
| NeuVector tuning before Protect | 7 | P2 | 4 | 2-week Discover + 2-week Monitor before enforcement |
| Helm privileged exceptions | 6 | P2 | 4 | Document exceptions in Kyverno policy annotations |
| Backup restore testing | 9 | P2 | 5 | Quarterly Velero restore to K3d test cluster |

---

## 8. Related Documents

| Document | Relevance |
|----------|-----------|
| [infrastructure-buildout-master-plan.md](infrastructure-buildout-master-plan.md) | Phase timeline and dependencies |
| [secrets-lifecycle-architecture.md](secrets-lifecycle-architecture.md) | OpenBao as central KMS for Layers 4, 6, 9 |
| [compliance-scanning-architecture.md](compliance-scanning-architecture.md) | Automated verification for Layers 2, 4 |
| [dual-workflow-architecture.md](dual-workflow-architecture.md) | Airflow DAGs for drift detection |
