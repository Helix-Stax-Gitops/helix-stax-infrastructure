<p align="center">
  <img src="docs/assets/architecture-diagram.svg" alt="Helix Stax Infrastructure Architecture" width="820"/>
</p>

# Helix Stax Infrastructure

Production Kubernetes platform for [Helix Stax](https://helixstax.com) — self-hosted, compliance-ready, zero trust. OpenTofu provisions it, Ansible hardens it, Helm deploys everything on K3s.

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes&logoColor=white)
![AlmaLinux](https://img.shields.io/badge/OS-AlmaLinux%209.7-0F4266?logo=almalinux&logoColor=white)
![Hetzner](https://img.shields.io/badge/Cloud-Hetzner-D50C2D?logo=hetzner&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Edge-Cloudflare-F38020?logo=cloudflare&logoColor=white)
![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-5C4EE5?logo=opentofu&logoColor=white)
![License](https://img.shields.io/badge/License-Private-333333)

Helix Stax helps companies find the gaps between their technology and the people using it. This repo is the infrastructure behind it — a self-hosted K8s platform on Hetzner Cloud with zero trust networking, CIS-hardened nodes, and no Docker Compose in production.

> **[View interactive architecture diagram](docs/architecture-viewer/)** (React Flow)

---

## Stack

| Layer | Tools | Purpose |
|-------|-------|---------|
| **Provisioning** | OpenTofu + Hetzner Cloud | VPS creation, DNS, firewall rules |
| **Hardening** | Ansible + dev-sec | CIS Level 1, SELinux enforcing, SSH lockdown |
| **Orchestration** | K3s + Flannel | Lightweight K8s, WireGuard-encrypted CNI |
| **Ingress** | Traefik + Cloudflare | CRDs, CDN, WAF, DDoS, Zero Trust |
| **Identity** | Zitadel | OIDC/SAML SSO for all internal services |
| **Database** | CloudNativePG | HA PostgreSQL with pgvector |
| **Cache** | Valkey | BSD-licensed Redis fork (Linux Foundation) |
| **Secrets** | OpenBao + ESO | Dynamic credentials synced to K8s |
| **Registry** | Harbor | Container registry + vulnerability scanning |
| **Storage** | MinIO | S3-compatible object storage |
| **CI/CD** | Devtron + ArgoCD | Build pipelines + GitOps deployment |
| **Monitoring** | Prometheus + Grafana + Loki | Metrics, dashboards, log aggregation |
| **IDS** | CrowdSec | Crowdsourced threat intel on every node |
| **Backup** | Velero -> MinIO -> Backblaze B2 | Cluster snapshots with offsite copies |
| **AI** | Ollama + Open WebUI + SearXNG | Local LLM inference and search |
| **Automation** | n8n | Workflow engine connecting all services |
| **Chat** | Rocket.Chat | Self-hosted team comms with OIDC |

---

## Security model

Three layers. Each operates independently — compromise one, the other two still hold.

```
 CLOUDFLARE EDGE                 HOST HARDENING                 CLUSTER SECURITY
+-------------------------+     +-------------------------+     +-------------------------+
| WAF + DDoS protection   |     | CIS Level 1 benchmarks  |     | OpenBao dynamic creds   |
| Zero Trust (WARP + JWT) | --> | SELinux enforcing        | --> | ESO syncs to K8s        |
| No open inbound ports   |     | CrowdSec IDS per node   |     | Gitleaks pre-commit     |
| Cloudflare Tunnel only  |     | SSH key-only, hardened   |     | No secrets in git       |
+-------------------------+     +-------------------------+     +-------------------------+
```

All traffic enters through Cloudflare Tunnel. The servers have no public-facing ports. 26 security policy documents in [`docs/policies/`](docs/policies/).

---

## Directory structure

```
helix-stax-infrastructure/
├── opentofu/                 # Hetzner provisioning, Cloudflare DNS
├── ansible/                  # OS hardening, K3s install, CrowdSec
├── helm/                     # Helm value overrides per service
├── scripts/                  # tofu-apply.sh, research helpers
└── docs/
    ├── adr/                  # 14 Architecture Decision Records
    ├── policies/             # 26 security policies
    ├── compliance/           # Hardening evidence, incident reports
    ├── architecture/         # Design docs
    ├── architecture-viewer/  # Interactive React Flow diagram
    ├── runbooks/             # Operational procedures
    └── tutorials/            # Step-by-step walkthroughs
```

---

## Quick start

```bash
# 1. Provision — secrets pulled from Cloudflare vault automatically
./scripts/tofu-apply.sh

# 2. Harden — CIS Level 1, SELinux, SSH lockdown, CrowdSec
cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/harden.yml

# 3. Install K3s
ansible-playbook -i inventory/hosts.yml playbooks/k3s-install.yml

# 4. Deploy services — Helm charts for everything
helm install zitadel ./helm/zitadel -n identity
helm install grafana ./helm/grafana -n monitoring
```

Pipeline: **OpenTofu** (provision) -> **Ansible** (harden + K3s) -> **Helm** (deploy) -> **ArgoCD** (GitOps sync)

---

## Compliance

Built for regulated environments. One control matrix, multiple framework views.

| Framework | Tier | Status |
|-----------|------|--------|
| NIST CSF 2.0 | Now | Mapped |
| CIS Controls v8 + Benchmarks | Now | Applied via Ansible |
| SOC 2 Type II | Now | Controls documented |
| ISO 27001 | Now | Controls documented |
| HIPAA / PCI DSS 4.0 | Per client | Ready (custom fields) |
| FedRAMP / StateRAMP | Future | Planned |

<details>
<summary>Unified Control Matrix details</summary>

~80 controls mapped across frameworks. Per-framework views are filtered on the same matrix — no duplication. HIPAA, PCI, and GDPR added as custom fields per client engagement. Evidence naming: `{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}`.

</details>

---

## Secrets management

No secrets touch git. Pipeline: **Cloudflare Vault** (edge secrets for IaC) -> **OpenBao** (dynamic DB creds, transit encryption) -> **ESO** (syncs to K8s Secrets). Pre-commit gitleaks hooks block secrets from ever reaching the repository.

---

## Architecture decisions

14 ADRs document every major choice with rationale and alternatives considered.

<details>
<summary>ADR index</summary>

| # | Decision |
|---|----------|
| 001 | Zero trust network architecture |
| 002 | CIS Level 1 over STIG |
| 003 | CrowdSec replaces Fail2ban |
| 004 | Flannel WireGuard encryption |
| 005 | LUKS full disk encryption |
| 006 | OpenBao transit unseal |
| 007 | Airflow Kubernetes executor |
| 008 | Dual workflow engine |
| 009 | Container supply chain security |
| 010 | Devtron internal ArgoCD |
| 011 | SOC 2 first compliance order |
| 012 | OpenSCAP + Lynis + AIDE scanning |
| 013 | Immutable evidence archival |
| 014 | Application-layer encryption over LUKS |

Full records in [`docs/adr/`](docs/adr/).

</details>

---

## Contributing

This repo uses the [PACT framework](https://github.com/KeemWilliams) for AI-assisted development — multi-agent orchestration where specialist agents handle preparation, architecture, coding, and testing. Human review required for all merges. All work happens on feature branches.

---

## License

Private repository. All rights reserved. &copy; 2026 Helix Stax LLC.

---

<details>
<summary>SVG diagram improvement notes</summary>

The animated diagram works well. Things that could be better:

1. **Small text**: Labels at 8-9px are hard to read on smaller screens. Bump minimum to 10px.
2. **CrowdSec missing as a node**: Appears in legend only. Add it to Layer 2 since it runs on each host.
3. **Velero not shown**: Backup pipeline (Velero -> MinIO -> Backblaze) should have a connection line.
4. **Node IPs may be stale**: Diagram shows `helix-stax-vps` at `5.78.145.30` — verify after rebuild. README references `heart` and `helix-worker-1` with different IPs.
5. **Mobile scaling**: Remove fixed `width`/`height` attributes, add `preserveAspectRatio="xMidYMid meet"` for responsive scaling.
6. **Accessibility**: Add `@media (prefers-reduced-motion: reduce)` to disable animations.
7. **Origin CA**: Diagram says "TLS Termination" but doesn't clarify Cloudflare Origin CA (not Let's Encrypt).

</details>
