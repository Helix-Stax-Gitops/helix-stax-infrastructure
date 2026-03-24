---
template: ops-workspace-readme
category: operational
task_type: documentation
clickup_list: 06 Process Library > Reference Documentation
auto_tags: [readme, documentation, reference, project-onboarding]
required_fields: [Purpose, Quick Start, Structure, Key Contacts, Status]
classification: internal
compliance_frameworks: [general]
review_cycle: quarterly
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Workspace/Project README

Use this template for any significant workspace, project repository, or initiative. File at the root of the directory (e.g., `README.md` in a git repo) or in ClickUp as a wiki. This is the entry point for anyone new to the workspace.

## TLDR

A comprehensive README that answers "What is this workspace/project for?" and "How do I get started?" This is the first doc a new team member or contractor reads. Should be scannable in 5 minutes and actionable (not just informational).

---

## Section 1: At a Glance

### What Is This?

**[REQUIRED]** 1–2 sentences. What is this workspace, project, or initiative?

Example: "The Helix Stax Infrastructure repo contains all Kubernetes manifests, Helm charts, Ansible playbooks, and OpenTofu modules for the production K3s cluster running on Hetzner Cloud. This is the source of truth for all infrastructure code."

### Quick Links

| Link | Purpose |
|------|---------|
| [ClickUp Workspace](link) | Project tasks and issues |
| [GitHub Repository](link) | Infrastructure code |
| [Grafana Dashboards](link) | Monitoring and metrics |
| [Runbooks](link) | Operational procedures |
| [Slack/Rocket.Chat Channel](link) | Team communication |

### Current Status

**[REQUIRED]** Is this project active, archived, or in what phase?

- **Status**: [ ] Active  [ ] In Development  [ ] Archived  [ ] On Hold
- **Last Updated**: [DATE]
- **Maintainer**: [Name] ([email])
- **Critical Issues**: [Any blocker preventing progress?]

---

## Section 2: Purpose & Scope

### Mission

**[REQUIRED]** Why does this workspace/project exist? What problem does it solve?

Example: "The Helix Stax Infrastructure project standardizes, automates, and documents our complete cloud infrastructure. It enables repeatable, auditable deployments while maintaining SOC 2 and ISO 27001 compliance."

### Scope

**[REQUIRED]** What is IN scope? What is OUT of scope?

**In Scope:**
- [e.g., K3s cluster provisioning and configuration]
- [e.g., All services running on K3s (Zitadel, ArgoCD, Prometheus, etc.)]
- [e.g., Infrastructure-as-code (OpenTofu, Helm, Ansible)]

**Out of Scope:**
- [e.g., Application code (lives in separate repos)]
- [e.g., Backup/disaster recovery procedures (see separate runbook)]

### Success Criteria

**[OPTIONAL]** How do you know this project is successful?

- [e.g., All services pass 99.5% uptime SLA]
- [e.g., Infrastructure code is peer-reviewed before merge]
- [e.g., New infrastructure setup takes < 1 hour from code to production]

---

## Section 3: Getting Started (Quick Start)

### Prerequisites

**[REQUIRED]** What do you need before you can work in this workspace?

- [e.g., kubectl installed and configured]
- [e.g., OpenTofu 1.6+ installed]
- [e.g., Helm 3.x installed]
- [e.g., Access to Hetzner Cloud account]
- [e.g., Access to GitHub repository (write access for maintainers)]

### Initial Setup (First Time)

**[REQUIRED]** How to get the workspace running locally or on your system.

```bash
# Clone the repository
git clone https://github.com/KeemWilliams/helix-stax-infrastructure.git
cd helix-stax-infrastructure

# Install dependencies
./scripts/setup.sh

# Configure kubectl
kubectl config use-context heart  # Switch to production cluster

# Or use vCluster for isolated testing
vcluster create my-test-cluster
```

### Verify Setup

**[REQUIRED]** How to confirm you're ready to go.

```bash
# Check Kubernetes connection
kubectl get nodes

# Check Helm charts are deployed
helm list -A

# View infrastructure status
kubectl get all --all-namespaces
```

### First Task

**[REQUIRED]** A simple, non-risky task for new contributors.

Example: "If everything is working, try deploying a test pod:
```bash
kubectl run test-pod --image=alpine --rm -it -- sh
```
Type `exit` to clean up."

---

## Section 4: Directory Structure

**[REQUIRED]** Map of the workspace. What goes where?

```
helix-stax-infrastructure/
├── README.md                          # This file
├── .gitignore
├── terraform/                         # OpenTofu (IaC provisioning)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── hetzner/                   # Hetzner Cloud VPS provisioning
│       ├── networking/
│       └── security/
├── helm/                              # Kubernetes Helm charts & values
│   ├── values-production.yaml
│   ├── values-staging.yaml
│   ├── charts/
│   │   ├── zitadel/
│   │   ├── prometheus/
│   │   ├── argocd/
│   │   └── [other services]
│   └── kustomization.yaml
├── ansible/                           # OS-level configuration & hardening
│   ├── playbooks/
│   │   ├── k3s-setup.yaml
│   │   ├── hardening.yaml
│   │   └── security-patching.yaml
│   ├── roles/
│   │   ├── common/
│   │   ├── k3s/
│   │   └── monitoring/
│   └── inventory.ini
├── docs/                              # Documentation
│   ├── README.md                      # Main architecture overview
│   ├── getting-started.md
│   ├── adr/                           # Architecture Decision Records
│   │   ├── 001-k3s-over-docker.md
│   │   └── ...
│   ├── runbooks/                      # Operational procedures
│   │   ├── incident-response.md
│   │   ├── backup-recovery.md
│   │   └── ...
│   ├── tutorials/                     # Phase-by-phase setup guides
│   │   ├── phase-1-provision.md
│   │   ├── phase-2-k3s-install.md
│   │   └── ...
│   └── templates/                     # Document templates
│       ├── bug-report.md
│       ├── proposal.md
│       └── ...
├── scripts/                           # Utility scripts
│   ├── setup.sh                       # Initial setup
│   ├── backup.sh                      # Backup procedures
│   ├── deploy.sh                      # Deployment helpers
│   └── monitoring/                    # Monitoring setup
│       └── prometheus-alerts.yaml
├── .github/
│   └── workflows/                     # CI/CD pipelines (GitHub Actions)
│       ├── validate-terraform.yaml
│       ├── helm-dry-run.yaml
│       └── ...
└── .gitignore                         # Don't commit: secrets, local configs, etc.
```

---

## Section 5: Key Workflows

### Common Tasks

**[REQUIRED]** How to do the most frequent operations.

#### Deploy a new service

```bash
# 1. Create Helm values for your service
cp helm/charts/[template]/values.yaml helm/values-[myservice].yaml
# Edit the file to configure your service

# 2. Add to kustomization.yaml or ArgoCD
# (Or use helm directly)
helm install [myservice] ./helm/charts/[template] -f helm/values-[myservice].yaml

# 3. Verify
kubectl get pods -l app=[myservice]
kubectl logs -l app=[myservice]
```

#### Apply infrastructure changes

```bash
# 1. Make changes to OpenTofu files
vi terraform/main.tf

# 2. Validate & plan
cd terraform/
tofu init
tofu plan -out=tfplan

# 3. Review the plan
# IMPORTANT: Never skip this! Verify what will change.
cat tfplan

# 4. Apply
tofu apply tfplan

# 5. Commit to git
git add terraform/
git commit -m "chore: [describe change]"
git push origin main
```

#### Patch or upgrade services

See `docs/runbooks/security-patching.md` for step-by-step procedures.

### Regular Maintenance

| Task | Frequency | Owner | Procedure |
|------|-----------|-------|-----------|
| Security patches | Monthly | DevOps | `docs/runbooks/security-patching.md` |
| Backup verification | Weekly | SRE | `docs/runbooks/backup-recovery.md` |
| Disk space review | Monthly | SRE | `kubectl top nodes; kubectl top pods` |
| Certificate rotation | Before expiration | DevOps | cert-manager handles automatically |
| Dependency updates | Quarterly | Architecture | Review `docs/adr/` before updating |

---

## Section 6: Code Standards & Conventions

**[REQUIRED]** How to write code/config that fits this project.

### Git Workflow

- **Branch strategy**: `git flow` (feature branches off `develop`, merge to `main` via PR)
- **Branch naming**: `feature/[feature-name]`, `bugfix/[bug-id]`, `hotfix/[issue]`
- **Commit messages**: Conventional Commits format
  ```
  type(scope): description

  type = feat|fix|docs|style|refactor|chore|perf|test
  scope = [terraform|helm|ansible|docs]

  Example:
  feat(helm): add prometheus-operator chart for K8s monitoring

  Adds Prometheus Operator CRDs and custom dashboards per SOC 2 requirement CC7.2.
  Refs #123
  ```
- **PR process**: Every change requires peer review (minimum 1 approval before merge)

### OpenTofu Standards

- [ ] Variables documented with descriptions
- [ ] Outputs for all public-facing resources
- [ ] State file never committed to git (use remote state in Hetzner or S3)
- [ ] Sensitive values marked with `sensitive = true`
- [ ] All resources tagged: `Environment`, `Owner`, `CostCenter`

### Helm Chart Standards

- [ ] `Chart.yaml` has `appVersion` and `chart version`
- [ ] `values.yaml` is well-commented (every config option explained)
- [ ] Templates follow Kubernetes naming conventions
- [ ] All charts pass `helm lint`
- [ ] Test deployment on staging before production

### Ansible Standards

- [ ] Playbooks are idempotent (safe to run multiple times)
- [ ] All variables defined in `defaults/` or `vars/`
- [ ] Tasks include `name:` fields (for readability in logs)
- [ ] Sensitive data uses Ansible Vault, not plain text

---

## Section 7: Troubleshooting & Getting Help

### Common Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| Cluster unreachable | `Unable to connect to the server` | Check `kubectl config current-context`; ensure VPN or SSH tunnel is active |
| Service not deploying | Pod in `Pending` state | Check `kubectl describe pod [pod-name]` for resource requests vs node capacity |
| Ingress not working | 503 Service Unavailable | Check Traefik: `kubectl get ingress`; verify backend service is running |

### Getting Help

**[REQUIRED]** How to escalate if you're stuck.

- **Slack/Rocket.Chat**: Post in `#infra-support` channel (expect response within 4 hours)
- **On-Call**: For production incidents, page the on-call engineer via [PagerDuty/Opsgenie link]
- **ClickUp**: Create a task in 02 Platform > Platform Engineering with `[BLOCKER]` tag
- **Email**: For urgent issues outside business hours: [Email addresses]

### Runbooks

For operational procedures, see `docs/runbooks/`:
- `incident-response.md` — How to triage and respond to infrastructure incidents
- `backup-recovery.md` — How to test and restore from backups
- `scaling.md` — How to add capacity (nodes, storage, etc.)
- `security-patching.md` — How to apply security patches
- `disaster-recovery.md` — How to recover from cluster failure

---

## Section 8: Key Contacts & Ownership

| Role | Name | Email | Slack/Rocket.Chat |
|------|------|-------|------------------|
| **Project Owner** | [Name] | [email] | @[username] |
| **Infrastructure Architect** | [Name] | [email] | @[username] |
| **DevOps Lead** | [Name] | [email] | @[username] |
| **Security/Compliance** | [Name] | [email] | @[username] |
| **On-Call Engineer** | [Rotates] | See PagerDuty | [PagerDuty schedule] |

---

## Section 9: Architecture Overview

**[OPTIONAL but RECOMMENDED]** High-level diagram or description of how everything fits together.

```
Internet
    ↓
Cloudflare (CDN, WAF, Zero Trust)
    ↓
Hetzner Cloud (2 VMs: heart + helix-worker-1)
    ↓
K3s Cluster
    ├── Traefik (ingress)
    ├── Zitadel (identity)
    ├── PostgreSQL (database)
    ├── Valkey (cache)
    ├── MinIO (storage)
    ├── Harbor (container registry)
    ├── Prometheus + Grafana (monitoring)
    ├── ArgoCD (GitOps deployment)
    └── [Other services...]
```

For full architecture details, see `docs/architecture.md`.

---

## Section 10: Contributing

### How to Contribute

1. **Clone** the repository
2. **Create a feature branch** (`git checkout -b feature/my-feature`)
3. **Make changes** following code standards (Section 6)
4. **Test locally** (run `helm lint`, `tofu plan`, verify on staging cluster)
5. **Push to GitHub** (`git push origin feature/my-feature`)
6. **Open a Pull Request** (describe what changed and why)
7. **Address review feedback** (iterate until approved)
8. **Merge** (maintainer will merge once approved)

### Peer Review Checklist

Before approving a PR, verify:
- [ ] Code follows project standards (Section 6)
- [ ] Changes are tested (locally or on staging)
- [ ] Commit messages are clear
- [ ] No secrets committed (scan with `git-secrets` or similar)
- [ ] Documentation updated if applicable

---

## Section 11: License & Legal

**[REQUIRED]** What license is this code under? Can people use it?

- **License**: [MIT, Apache 2.0, Proprietary, etc.]
- **Copyright**: [Year] Helix Stax, Inc. All rights reserved.
- **Usage**: [Open source? Proprietary? Commercial license required?]

See `LICENSE.md` for full text.

---

## Section 12: Changelog & Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | [DATE] | Initial README | [Name] |
| 1.1 | [DATE] | Added troubleshooting section | [Name] |

---

## Section 13: Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/architecture.md` | Detailed technical architecture |
| `docs/adr/` | Architecture Decision Records |
| `docs/runbooks/` | Operational procedures |
| `docs/tutorials/` | Phase-by-phase setup guides |
| `docs/compliance/` | SOC 2 / ISO 27001 alignment |

---

## Quick Ref: Most Important Commands

```bash
# View cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# View logs
kubectl logs -n [namespace] [pod-name]
kubectl logs -n [namespace] -l app=[app-name]

# Access a pod's shell
kubectl exec -it -n [namespace] [pod-name] -- /bin/sh

# Scale a deployment
kubectl scale deployment -n [namespace] [deployment-name] --replicas=3

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# View Grafana dashboards
# Open https://grafana.helixstax.net (if you have access)

# Check OpenTofu state
cd terraform/
tofu state list
tofu state show aws_instance.example
```

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| General | Documentation | Maintain documented procedures | This README documents all key workflows |
| SOC 2 | CC6.2 (Privileged Access) | Control access via documented procedures | Contains access procedures and code review requirements |

---

## Definition of Done

- [ ] Purpose and scope are clear (anyone can skim and understand in 5 min)
- [ ] Quick Start section gets a new person to "hello world" in <30 min
- [ ] Directory structure is documented
- [ ] Key contacts and ownership are clear
- [ ] Code standards and PR process are documented
- [ ] Troubleshooting and escalation paths are clear
- [ ] README is up-to-date (review quarterly)
- [ ] README is filed in git repo or ClickUp wiki

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.0 |
