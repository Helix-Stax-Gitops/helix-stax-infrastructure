<p align="center">
  <img src="docs/assets/architecture-diagram.svg" alt="Helix Stax Infrastructure Architecture" width="820"/>
</p>

# Helix Stax Infrastructure

Production K3s platform — HIPAA, SOC 2, and NIST CSF compliance infrastructure on Hetzner Cloud. Zero trust, CIS-hardened, GitOps. OpenTofu + Ansible + Helm. Built by [Helix Stax](https://helixstax.com).

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes&logoColor=white)
![AlmaLinux](https://img.shields.io/badge/OS-AlmaLinux%209.7-0F4266?logo=almalinux&logoColor=white)
![Hetzner](https://img.shields.io/badge/Cloud-Hetzner-D50C2D?logo=hetzner&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Edge-Cloudflare-F38020?logo=cloudflare&logoColor=white)
![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-5C4EE5?logo=opentofu&logoColor=white)
![HIPAA](https://img.shields.io/badge/HIPAA-87.5%25-4F9E80)
![SOC2](https://img.shields.io/badge/SOC%202-Mapped-4F9E80)
![License](https://img.shields.io/badge/License-Private-333333)

Helix Stax helps companies find the gaps between their technology and the people using it. This repo is the infrastructure behind it — a self-hosted K8s platform on Hetzner Cloud with zero trust networking, CIS-hardened nodes, and no Docker Compose in production.

> **[View interactive architecture diagram](docs/architecture-viewer/)** (React Flow)

---

## Stack

| Layer | Tools | Status |
|-------|-------|--------|
| **Provisioning** | OpenTofu + Hetzner Cloud | Deployed |
| **Hardening** | Ansible + dev-sec | Deployed — CIS Level 1, SELinux enforcing |
| **Orchestration** | K3s + Flannel/WireGuard | Deployed — 4-node cluster |
| **Ingress** | Traefik + Cloudflare | Deployed — metrics + ServiceMonitor enabled |
| **Identity** | Zitadel | Deployed — OIDC SSO for Grafana and Devtron |
| **Database** | CloudNativePG | Deployed — PostgreSQL + pgvector, PodMonitor enabled |
| **Cache** | Valkey | Deployed — auth enabled, Prometheus metrics |
| **Secrets** | Cloudflare Secrets Store (edge) / OpenBao + ESO (planned) | Partial |
| **Registry** | Harbor | Pending |
| **Storage** | MinIO | Pending |
| **CI/CD** | Devtron + ArgoCD | Deployed — SSO via Zitadel/Dex |
| **Monitoring** | Prometheus + Grafana + Loki | Deployed — 90-day retention, 35+ dashboards |
| **IDS** | CrowdSec | Deployed — all 4 hosts, K8s deployment planned |
| **Backup** | Velero -> MinIO -> Backblaze B2 | Pending MinIO |
| **AI** | Ollama + Open WebUI + SearXNG | Pending |
| **Automation** | n8n | Pending |
| **Chat** | Rocket.Chat | Pending |

---

## Nodes

Four nodes across two datacenters. All nodes are CIS Level 1 hardened, SELinux enforcing, and running CrowdSec.

| Name | Codename | IP | Specs | Role | Location |
|------|----------|----|-------|------|----------|
| helix-stax-cp | heart | 178.156.233.12 | CPX31 — 4 vCPU, 8GB RAM | Control plane + platform workloads | Ashburn, VA |
| helix-stax-test | edge | 178.156.172.47 | CPX11 — 2 vCPU, 2GB RAM | Database label — decommission candidate | Ashburn, VA |
| helix-stax-vps | vault | 5.78.145.30 | CPX31 — 4 vCPU, 8GB RAM | Forge workloads | Hillsboro, OR |
| helix-stax-ai | forge | 138.201.131.157 | i7-7700, 64GB RAM, 2x480GB SSD RAID 1 | AI inference workloads | Germany |

> `edge` carries the `workload=database` label but is recommended for decommission — 2GB RAM is insufficient for the database workload. Decommission runs via `tofu apply` after workloads are migrated.

---

## Security model

Three layers. Each operates independently — compromise one, the other two still hold.

```
 CLOUDFLARE EDGE                 HOST HARDENING                 CLUSTER SECURITY
+-------------------------+     +-------------------------+     +-------------------------+
| WAF + DDoS protection   |     | CIS Level 1 benchmarks  |     | Zitadel OIDC SSO        |
| Zero Trust (WARP + JWT) | --> | SELinux enforcing        | --> | NetworkPolicies on Dex  |
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
├── k8s/                      # Raw Kubernetes manifests (NetworkPolicies, ServiceMonitors)
├── scripts/                  # Operational scripts
│   ├── tofu-apply.sh         # Provision infrastructure
│   ├── grafana-oidc-setup.sh # Configure Grafana OIDC client in Zitadel + deploy
│   ├── devtron-setup-oidc.sh # Configure Devtron OIDC via Dex
│   ├── grafana-alerting-setup.sh  # Re-apply alerting config after restart
│   └── grafana-dashboard-setup.sh # Re-create dashboard ConfigMaps
└── docs/
    ├── adr/                  # 14 Architecture Decision Records
    ├── policies/             # 26 security policies
    ├── compliance/           # Hardening evidence, incident reports
    ├── architecture/         # Design docs and monitoring research
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

# 5. Configure SSO — run after Zitadel and target service are both up
./scripts/grafana-oidc-setup.sh
./scripts/devtron-setup-oidc.sh
```

Pipeline: **OpenTofu** (provision) -> **Ansible** (harden + K3s) -> **Helm** (deploy) -> **ArgoCD** (GitOps sync)

---

## Monitoring

Prometheus and Grafana are deployed and operational. Key configuration:

| Parameter | Value |
|-----------|-------|
| Prometheus retention | 90 days, 30GB cap |
| Active scrape targets | 31+ (all UP) |
| Grafana dashboards | 35+ across 5 folders |
| SLO recording rules | 31 rules |
| Burn-rate alerts | 14 alerts |

**Dashboard folders:**

| Folder | Contents |
|--------|---------|
| Infrastructure | Node metrics, K3s cluster health, resource utilization |
| Database | CloudNativePG per-instance metrics, replication lag |
| Networking | Traefik request rates, error rates, latency |
| CI-CD | Devtron pipeline metrics, ArgoCD sync status |
| Compliance | NIST CSF, SOC 2, ISO 27001, CIS v8, HIPAA |

After a Grafana pod restart, re-apply configuration with:

```bash
./scripts/grafana-alerting-setup.sh
./scripts/grafana-dashboard-setup.sh
```

---

## Compliance

Built for regulated environments. One control matrix, multiple framework views.

| Framework | Tier | Status |
|-----------|------|--------|
| NIST CSF 2.0 | Now | Mapped |
| CIS Controls v8 + Benchmarks | Now | Applied via Ansible |
| SOC 2 Type II | Now | Controls documented |
| ISO 27001 | Now | Controls documented |
| HIPAA | Now | 87.5% — 16 automated controls via Grafana dashboard |
| PCI DSS 4.0 | Per client | Ready (custom fields) |
| FedRAMP / StateRAMP | Future | Planned |

<details>
<summary>Unified Control Matrix details</summary>

~80 controls mapped across frameworks. Per-framework views are filtered on the same matrix — no duplication. HIPAA, PCI, and GDPR added as custom fields per client engagement. Evidence naming: `{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}`.

The Compliance folder in Grafana provides a unified dashboard (UCM view) covering NIST CSF, SOC 2, ISO 27001, and CIS v8 in a single pane. The HIPAA dashboard tracks 16 automated controls and currently scores 87.5%. A FedRAMP dashboard is in progress.

</details>

---

## Secrets management

No secrets touch git. Pipeline: **Cloudflare Secrets Store** (edge secrets for IaC) -> **OpenBao** (dynamic DB creds, transit encryption — planned) -> **ESO** (syncs to K8s Secrets — planned). Pre-commit gitleaks hooks block secrets from ever reaching the repository.

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
4. **Node count**: Diagram shows 2 nodes — update to reflect 4-node cluster (heart, edge, vault, forge).
5. **Mobile scaling**: Remove fixed `width`/`height` attributes, add `preserveAspectRatio="xMidYMid meet"` for responsive scaling.
6. **Accessibility**: Add `@media (prefers-reduced-motion: reduce)` to disable animations.
7. **Origin CA**: Diagram says "TLS Termination" but doesn't clarify Cloudflare Origin CA (not Let's Encrypt).

</details>
