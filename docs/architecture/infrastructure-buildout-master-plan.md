---
title: Infrastructure Buildout Master Plan
author: Wakeem Williams
co_author: Quinn Mercer
date: 2026-03-23
status: Active
version: "1.0"
compliance_frameworks:
  - SOC 2 Type I (Month 3)
  - SOC 2 Type II (Month 9)
  - ISO 27001:2022 (Month 12+)
  - HIPAA (per client demand)
references:
  - docs/adr/ADR-002 through ADR-013
  - docs/architecture/defense-in-depth-architecture.md
  - docs/architecture/secrets-lifecycle-architecture.md
  - docs/architecture/compliance-scanning-architecture.md
  - docs/architecture/dual-workflow-architecture.md
---

# Infrastructure Buildout Master Plan

## 1. Executive Summary

This document defines the 5-phase infrastructure buildout for Helix Stax, transforming two hardened AlmaLinux 9.7 servers into a production-grade, SOC 2-auditable K3s platform. The plan spans approximately 10 weeks of effort across Phases 2-5 (Phase 1 is complete), culminating in SOC 2 Type I readiness.

### Current State

- **Phase 1 (Host Hardening)**: COMPLETE
- **Servers**: helix-stax-cp (178.156.233.12), helix-stax-vps (5.78.145.30) -- both AlmaLinux 9.7
- **Hardening applied**: CIS L1 baseline, SELinux enforcing, firewalld, SSH on port 2222, fail2ban, auditd, automatic security updates, wakeem user
- **3 gaps remaining**: GRUB bootloader password, ASLR verification, cron authorization
- **K3s**: NOT installed yet -- clean slate

---

## 2. Locked Decisions Summary

| # | Decision | ADR | Rationale |
|---|----------|-----|-----------|
| 1 | CIS L1 baseline (not full STIG) | ADR-002 | STIG causes config oscillation with K3s; CIS L1 + selective L2 covers SOC 2/ISO 27001 |
| 2 | CrowdSec replaces fail2ban | ADR-003 | Go-based, global threat intel, dual-tier (host + K3s DaemonSet) |
| 3 | Flannel with WireGuard backend | ADR-004 | East-west encryption; Cilium as future upgrade path |
| 4 | LUKS FDE with dracut-sshd | ADR-005 | Remote unlock via SSH on Hetzner; no cloud KMS dependency |
| 5 | OpenBao transit unseal architecture | ADR-006 | Dedicated transit node for auto-unseal on 2-node cluster |
| 6 | KubernetesExecutor for Airflow | ADR-007 | Ephemeral pods, no Celery workers, resource-efficient |
| 7 | Dual workflow engine (n8n + Airflow) | ADR-008 | n8n for real-time webhooks; Airflow for scheduled compliance |
| 8 | Container supply chain (Harbor > Cosign > Kyverno > NeuVector) | ADR-009 | Full chain: scan > sign > verify > runtime |
| 9 | Devtron internal ArgoCD (no standalone) | ADR-010 | Single CI/CD tool; GitOps mode mandatory |
| 10 | SOC 2 first compliance pursuit | ADR-011 | Type I Month 3, Type II Month 9, ISO 27001 Month 12+ |
| 11 | OpenSCAP + Lynis + AIDE scanning | ADR-012 | Automated evidence; weekly full audit, daily drift |
| 12 | Immutable evidence archival (MinIO Object Lock) | ADR-013 | SHA-256 hashed; compliance mode; 7yr HIPAA retention |

---

## 3. Phased Timeline

### Overview

```
Week  1  2  3  4  5  6  7  8  9  10  11  12  13
      |--Phase 2--|--Phase 3---------|--P4--|--Phase 5---------|
      K3s Foundation  Data+ID+Secrets  Pipeline  Compliance+SOC2
      CTGA 500        CTGA 600         CTGA 700  CTGA 900
```

### Phase 2: K3s Foundation (Weeks 1-2)

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Fix 3 CIS gaps (GRUB, ASLR, cron) | 2h | None | DevOps |
| Replace fail2ban with CrowdSec (host) | 4h | None | DevOps |
| Install LUKS + dracut-sshd | 4h | None | DevOps |
| Install K3s on CP (hardened flags) | 4h | CIS gaps fixed | DevOps |
| Join worker to cluster | 2h | K3s on CP | DevOps |
| Configure Flannel WireGuard | 2h | K3s cluster | DevOps |
| Deploy cert-manager | 2h | K3s cluster | DevOps |
| Deploy Traefik ingress | 2h | cert-manager | DevOps |
| Install OpenSCAP + tailoring file | 3h | K3s cluster | Security |
| Install Lynis | 1h | None | DevOps |
| Install AIDE + K3s exclusions | 2h | K3s cluster | Security |
| Run kube-bench CIS K8s Benchmark | 2h | K3s cluster | Security |
| Fix K3s PKI permissions | 1h | kube-bench results | DevOps |
| Verify K3s audit logging | 1h | K3s cluster | Security |

**Entry criteria**: Phase 1 complete (verified)
**Exit criteria**: K3s cluster operational, all scanning tools installed, kube-bench passing
**CTGA progression**: 300 -> 500

### Phase 3: Data + Identity + Secrets (Weeks 3-5)

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Deploy CloudNativePG | 4h | cert-manager, K3s | Database |
| Deploy Valkey | 2h | K3s | Backend |
| Deploy MinIO + SSE-KMS | 4h | K3s | DevOps |
| Deploy Harbor + Trivy | 4h | PostgreSQL | DevOps |
| Deploy OpenBao (HA mode) | 8h | PostgreSQL | Security |
| Configure transit unseal node | 4h | OpenBao | Security |
| Configure ESO | 4h | OpenBao | DevOps |
| Deploy Zitadel | 4h | PostgreSQL | Backend |
| Configure OIDC clients | 4h | Zitadel | Backend |
| Default-deny NetworkPolicies | 4h | All namespaces | Security |

**Entry criteria**: Phase 2 complete, K3s cluster healthy
**Exit criteria**: All data services running, OIDC integrated, secrets centralized in OpenBao
**CTGA progression**: 500 -> 600

### Phase 4: Container Pipeline + Runtime Security (Weeks 6-7)

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Deploy Devtron (internal ArgoCD) | 4h | Harbor, Zitadel OIDC | DevOps |
| Configure CI pipeline (Gitleaks > Kaniko > Trivy > Syft > Cosign) | 8h | Devtron, Harbor | DevOps |
| Deploy Kyverno + image verification | 4h | Cosign keys in OpenBao | Security |
| Deploy NeuVector | 4h | K3s | Security |
| Configure CrowdSec K3s DaemonSet | 4h | Traefik | Security |
| Generate Cosign keypair in OpenBao transit | 2h | OpenBao | Security |

**Entry criteria**: Phase 3 complete, Harbor and OpenBao operational
**Exit criteria**: Full container supply chain operational, runtime protection active
**CTGA progression**: 600 -> 700

### Phase 5: Continuous Compliance + SOC 2 Readiness (Weeks 8-10)

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Deploy Prometheus + Grafana + Loki + Alertmanager | 8h | K3s | DevOps |
| Deploy Apache Airflow (KubernetesExecutor) | 6h | PostgreSQL, K3s | DevOps |
| Create compliance scanning DAG | 4h | Airflow, OpenSCAP | DevOps |
| Create drift detection DAG | 4h | Airflow, Ansible | DevOps |
| Create backup verification DAG | 4h | Airflow, Velero | DevOps |
| Deploy n8n | 4h | PostgreSQL | DevOps |
| Configure Airflow > n8n webhooks | 2h | Airflow, n8n | DevOps |
| Deploy Velero + Backblaze B2 | 4h | MinIO | DevOps |
| Configure MinIO S3 Object Lock | 2h | MinIO | Security |
| Deploy Rocket.Chat | 4h | PostgreSQL, Zitadel | DevOps |
| Deploy Backstage | 4h | K3s | DevOps |
| Deploy Outline | 4h | PostgreSQL, MinIO | DevOps |
| Create compliance Grafana dashboards | 8h | Prometheus, Grafana | DevOps |
| Write 8 operational runbooks | 16h | All services | Scribe |
| Engage SOC 2 Type I auditor | -- | All controls operational | PM |

**Entry criteria**: Phase 4 complete, all security controls operational
**Exit criteria**: All observability and compliance tooling deployed, evidence pipeline operational
**CTGA progression**: 700 -> 900

---

## 4. Dependency Chain

```
Phase 2: K3s Foundation
  +--> K3s install (--protect-kernel-defaults, --secrets-encryption)
  |     +--> Flannel WireGuard backend
  |     +--> cert-manager
  |     |     +--> Traefik ingress
  |     +--> OpenSCAP + Lynis + AIDE
  |
Phase 3: Data + Identity + Secrets
  +--> CloudNativePG <-- cert-manager
  |     +--> Harbor <-- PostgreSQL
  |     +--> Zitadel <-- PostgreSQL
  |     |     +--> OIDC client configuration
  |     +--> OpenBao <-- PostgreSQL
  |     |     +--> Transit unseal node
  |     |     +--> ESO (External Secrets Operator)
  |     +--> MinIO (standalone)
  |     +--> Valkey (standalone)
  |
Phase 4: CI/CD + Security Pipeline
  +--> Devtron <-- Harbor, Zitadel OIDC
  |     +--> ArgoCD (internal to Devtron)
  +--> Kyverno <-- Cosign keys in OpenBao
  +--> NeuVector (standalone)
  +--> CrowdSec K3s DaemonSet <-- Traefik
  +--> Cosign <-- OpenBao transit engine
  |
Phase 5: Observability + Compliance Automation
  +--> Prometheus + Grafana + Loki + Alertmanager
  +--> Airflow (KubernetesExecutor) <-- PostgreSQL
  |     +--> Compliance scanning DAGs
  |     +--> Drift detection DAGs
  |     +--> Backup verification DAGs
  +--> n8n <-- PostgreSQL
  |     +--> Airflow SimpleHttpOperator --> n8n webhook
  +--> Velero <-- MinIO --> Backblaze B2
  +--> Rocket.Chat <-- PostgreSQL, Zitadel
  +--> Backstage
  +--> Outline <-- PostgreSQL, MinIO
```

---

## 5. SOC 2 Audit Timeline Overlay

```
Month  1         2         3         4-9           9         12+
       |---------|---------|---------|-------------|---------|--------->
       Phase 2-3  Phase 4   Phase 5   Observation   Audit     ISO
       Build      Secure    Evidence  Window        Report    27001
       Controls   Pipeline  Pipeline  (Type II)     Due

Key Milestones:
  Month 3:  SOC 2 Type I  -- Point-in-time design assessment
  Month 9:  SOC 2 Type II -- 6-month operational effectiveness
  Month 12: ISO 27001     -- 80% control overlap with SOC 2
  On-demand: HIPAA/NIST 800-171 -- Infrastructure inherently compliant
```

| Month | Milestone | Evidence Required |
|-------|-----------|-------------------|
| 1 | Controls designed and deployed | Architecture docs, ADRs, config-as-code |
| 2 | Security pipeline operational | Harbor scan logs, Kyverno policies, NeuVector profiles |
| 3 | **SOC 2 Type I audit** | All control evidence, OpenSCAP reports, policy docs |
| 4-8 | Observation window begins | Continuous scanning, automated evidence collection |
| 9 | **SOC 2 Type II audit** | 6 months of immutable evidence in MinIO |
| 12+ | **ISO 27001 certification** | ISMS documentation, risk register, management review |

---

## 6. CTGA Score Progression

The CTGA (Controls, Technology, Growth, Adoption) Framework measures infrastructure maturity on a 100-900 scale.

| Phase | CTGA Score | Controls | Technology | Growth | Adoption |
|-------|-----------|----------|-----------|--------|----------|
| Pre-Phase 1 | 300 | Default OS | Manual installs | None | Ad-hoc |
| Phase 1 (DONE) | 400 | CIS L1, SELinux, firewall | SSH hardened, auto-updates | -- | -- |
| Phase 2 | 500 | Automated scanning, FIM | K3s, WireGuard, cert-manager | -- | -- |
| Phase 3 | 600 | Secrets managed, OIDC | Full data stack, OpenBao | -- | -- |
| Phase 4 | 700 | Supply chain verified | CI/CD pipeline, runtime security | -- | -- |
| Phase 5 | 900 | SOC 2 Type I passing | Full observability, compliance automation | Audit-ready | GitOps mandatory |

```
CTGA Score Progression:

  900 |                                              ****
  800 |                                         ****
  700 |                                    ****
  600 |                           ****
  500 |                  ****
  400 |         ****
  300 | ****
      +------+------+------+------+------+------+------+------+
      Pre    Ph1    Ph2    Ph3    Ph4    Ph5    SOC2   ISO
```

---

## 7. Team Assignments Per Phase

| Phase | Primary Agent | Supporting Agents |
|-------|---------------|-------------------|
| 2 | Kit (DevOps) | Ezra (Security), Cass (Architect) |
| 3 | Kit (DevOps) | Soren (Database), Dax (Backend), Ezra (Security) |
| 4 | Kit (DevOps) | Ezra (Security) |
| 5 | Kit (DevOps) | Nix (n8n), Quinn (Scribe), Sable (PM) |

---

## 8. Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| LUKS remote unlock fails on reboot | Medium | High | Test dracut-sshd on staging first; document manual unlock |
| K3s hardening flags break workloads | Medium | Medium | Test with kube-bench; maintain exception list |
| OpenBao transit unseal single point of failure | Low | High | Monitor unseal node; document manual Shamir recovery |
| NeuVector false positives block workloads | Medium | Medium | Start in Discover mode; tune before Protect mode |
| SOC 2 auditor rejects open-source evidence | Low | High | Use OpenSCAP ARF/XCCDF output (universally accepted) |

---

## 9. Related Documents

| Document | Purpose |
|----------|---------|
| [defense-in-depth-architecture.md](defense-in-depth-architecture.md) | 10-layer security model |
| [secrets-lifecycle-architecture.md](secrets-lifecycle-architecture.md) | OpenBao rotation pipeline |
| [compliance-scanning-architecture.md](compliance-scanning-architecture.md) | Automated scanning stack |
| [dual-workflow-architecture.md](dual-workflow-architecture.md) | n8n + Airflow split |
| [secrets-management.md](secrets-management.md) | Three-store secrets model |
