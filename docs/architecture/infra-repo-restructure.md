# Infrastructure Repository Restructure: Service-Per-Folder Architecture

**Author**: Wakeem Williams
**Co-Author**: Cass Whitfield (System Architect)
**Date**: 2026-03-20
**Status**: PROPOSED
**ADR Reference**: Pending (ADR-002)

---

## 1. Executive Summary

The `helix-stax-infrastructure` repository currently organizes files by **technology type** (`docker-compose/`, `terraform/`, `helm/`, `scripts/`). This creates scatter: a single service like Zitadel has its Docker Compose in one directory, its future Helm values in another, its scripts somewhere else, and its docs spread across `docs/runbooks/` and `docs/tutorials/`.

This document proposes a **service-per-folder** restructure where every tool in the stack gets a single directory containing ALL its related artifacts. The structure is designed to work with ArgoCD's ApplicationSet git directory generator, making GitOps discovery automatic.

**Key outcomes**:
- Find everything about a service in one place
- ArgoCD auto-discovers new services from folder structure
- OpenTofu modules and Ansible roles remain centralized (they're reusable, not per-service)
- `docs/` stays untouched (already well-organized)
- `docker-compose/` is archived as legacy (K3s is THE target)

---

## 2. Current State Analysis

### 2.1 Repository Root

```
helix-stax-infrastructure/
  .gitignore
  CHANGELOG.md
  CLAUDE.md
  README.md
  assets/icons/clickup/           # ClickUp space icons (9 SVGs)
  docker-compose/                  # Legacy Docker Compose files
  docs/                            # Documentation (well-organized, do NOT touch)
  helm/                            # EMPTY directory
  scripts/                         # 3 loose operational scripts
  terraform/                       # OpenTofu/Terraform (Hetzner provisioning)
```

### 2.2 docker-compose/ (Legacy -- Transitional)

Per-service subdirectories already exist here, which is good -- it proves the service-per-folder pattern works:

```
docker-compose/
  .env.example
  docker-compose.yml               # Root compose (likely orchestrator)
  authentik/docker-compose.yml
  harbor/harbor.yml
  homepage/docker-compose.yml + config/
  minio/docker-compose.yml
  netbird/docker-compose.yml + .env.example + management.json + turnserver.conf
  nginx/docker-compose.yml + conf.d/ + snippets/ + ssl/
  openbao/docker-compose.yml + config.hcl
  postgres/init/00-create-databases.sql
  redis/redis.conf.template
  vaultwarden/docker-compose.yml
  zitadel/docker-compose.yml
```

**Observation**: Some of these services are deprecated (authentik -> Zitadel, nginx -> Traefik, redis -> Valkey, homepage -> Backstage, netbird -> Cloudflare Zero Trust). They represent the old stack.

### 2.3 terraform/ (OpenTofu)

```
terraform/
  .terraform/                      # Provider cache (gitignored)
  .terraform.lock.hcl              # Lock file (gitignored)
  cloud-init/vps-init.yaml         # Cloud-init templates
  cloud-init/vps-init-v2.yaml
  k3s/install-agent.sh             # K3s install scripts
  k3s/install-server.sh
  k3s/k3s-config.yaml
  modules/hetzner-firewall/        # Reusable module
  modules/hetzner-server/          # Reusable module
  main.tf
  outputs.tf
  providers.tf
  variables.tf
  terraform.tfvars                 # Gitignored (secrets)
  terraform.tfvars.example
  terraform.tfstate*               # Gitignored (should be remote)
```

**Observation**: This is Hetzner provisioning, not per-service IaC. It provisions the VPS nodes that K3s runs on. This is foundational infrastructure, not service-level -- it should stay centralized.

### 2.4 helm/ (Empty)

The directory exists but contains no files. CLAUDE.md says "All Helm values in `helm/` directory" but nothing has been deployed to K3s yet.

### 2.5 scripts/ (Loose)

```
scripts/
  cloudflare-finalize-github-idp.sh
  cloudflare-zero-trust-setup.sh
  firewall-setup.sh
```

Three scripts with no clear ownership. These should live inside the service folders they operate on (cloudflare, k3s/firewall).

### 2.6 docs/ (Well-Organized -- DO NOT RESTRUCTURE)

```
docs/
  adr/                             # Architecture Decision Records
  architecture/                    # Architecture docs (this file lives here)
  compliance-templates/            # Compliance report templates
  content/                         # Marketing content drafts
  gemini-skill-prompts/            # Gemini AI prompts (40 files, just reorganized)
  plans/                           # Sprint/feature plans
  preparation/                     # Research/preparation docs
  review/                          # Review reports
  runbooks/                        # Operational runbooks
  templates/                       # Document templates (Gemini library)
  tutorials/                       # Phase-by-phase tutorials
  WHERE-EVERYTHING-GOES.md         # Master reference
  dns-records.md
  netbird-acls.md
  tech-stack.md
  tools-inventory.md
  gemini-*.md                      # 4 loose Gemini prompts (should be in gemini-skill-prompts/)
```

**One issue**: 4 Gemini prompt files sit at the `docs/` root instead of inside `docs/gemini-skill-prompts/`. These should be moved during cleanup but that is NOT part of this restructure.

### 2.7 What's Missing

- No `services/` or per-service folders for K8s deployments
- No Helm values files anywhere
- No K8s manifests (CRDs, IngressRoutes, NetworkPolicies)
- No Ansible playbooks or roles
- No per-service README, CHANGELOG, or scripts
- No ArgoCD Application manifests
- No cross-cutting concerns directory (namespaces, RBAC, network policies)

---

## 3. Design Principles

1. **Service-per-folder**: Every deployable service gets its own top-level directory under `services/`. One folder = one ArgoCD Application.

2. **Colocation over separation**: Helm values, manifests, scripts, and configs for a service live TOGETHER, not scattered by technology type.

3. **Centralized reusables**: OpenTofu modules (infrastructure provisioning) and Ansible roles (OS-level config) are reusable across services and environments. They stay centralized in `opentofu/` and `ansible/`.

4. **ArgoCD-native layout**: The `services/` directory is designed for ArgoCD's ApplicationSet git directory generator. Adding a new service = adding a folder.

5. **Legacy quarantine**: `docker-compose/` is explicitly marked as legacy/archive. It is NOT the source of truth for any service. K3s is THE target.

6. **Docs are sacred**: `docs/` is already organized. It stays where it is. Per-service docs (README, CHANGELOG) go inside `services/{name}/`, but runbooks, ADRs, and tutorials remain centralized in `docs/`.

7. **Cross-cutting concerns are explicit**: Shared resources (namespaces, RBAC, network policies, storage classes) get their own directory under `platform/`.

8. **Environment parity**: Each service can have `values.yaml` (base), `values-staging.yaml`, and `values-prod.yaml`. ArgoCD selects the right one per environment.

---

## 4. Target Structure

```
helix-stax-infrastructure/
|
|-- .gitignore
|-- CHANGELOG.md
|-- CLAUDE.md
|-- README.md
|
|-- assets/                              # Static assets (icons, images)
|   +-- icons/clickup/                   # ClickUp space icons
|
|-- docs/                                # UNCHANGED -- centralized documentation
|   +-- adr/
|   +-- architecture/
|   +-- compliance-templates/
|   +-- content/
|   +-- gemini-skill-prompts/
|   +-- plans/
|   +-- preparation/
|   +-- review/
|   +-- runbooks/
|   +-- templates/
|   +-- tutorials/
|   +-- dns-records.md
|   +-- tech-stack.md
|   +-- tools-inventory.md
|   +-- WHERE-EVERYTHING-GOES.md
|
|-- opentofu/                            # RENAMED from terraform/
|   +-- environments/
|   |   +-- prod/
|   |       +-- main.tf
|   |       +-- providers.tf
|   |       +-- variables.tf
|   |       +-- outputs.tf
|   |       +-- terraform.tfvars.example
|   +-- modules/
|   |   +-- hetzner-server/
|   |   +-- hetzner-firewall/
|   |   +-- cloudflare-dns/              # Future
|   +-- cloud-init/
|   |   +-- vps-init.yaml
|   |   +-- vps-init-v2.yaml
|   +-- k3s/
|       +-- install-server.sh
|       +-- install-agent.sh
|       +-- k3s-config.yaml
|
|-- ansible/                             # NEW -- OS-level automation
|   +-- inventory/
|   |   +-- hosts.yml
|   +-- playbooks/
|   |   +-- harden.yml
|   |   +-- k3s-install.yml
|   |   +-- k3s-upgrade.yml
|   +-- roles/
|       +-- common/                      # Base OS hardening
|       +-- k3s-server/
|       +-- k3s-agent/
|       +-- crowdsec-agent/              # CrowdSec on host
|
|-- platform/                            # Cross-cutting K8s concerns
|   +-- namespaces/
|   |   +-- namespaces.yaml              # All namespace definitions
|   +-- rbac/
|   |   +-- cluster-roles.yaml
|   |   +-- role-bindings.yaml
|   +-- network-policies/
|   |   +-- default-deny.yaml
|   |   +-- allow-dns.yaml
|   |   +-- allow-ingress.yaml
|   +-- storage-classes/
|   |   +-- local-path.yaml
|   +-- priority-classes/
|   |   +-- priority-classes.yaml
|   +-- resource-quotas/
|       +-- default-quotas.yaml
|
|-- services/                            # THE CORE -- one folder per service
|   |
|   |-- argocd/                          # ArgoCD itself (app-of-apps root)
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   |   +-- values-prod.yaml
|   |   +-- manifests/
|   |   |   +-- app-of-apps.yaml         # Root Application that discovers services/
|   |   |   +-- applicationset.yaml      # Git directory generator
|   |   |   +-- project.yaml             # AppProject definitions
|   |   +-- scripts/
|   |       +-- bootstrap.sh             # Initial ArgoCD install (chicken-and-egg)
|   |
|   |-- traefik/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   |   +-- values-prod.yaml
|   |   +-- manifests/
|   |   |   +-- middleware-security-headers.yaml
|   |   |   +-- middleware-rate-limit.yaml
|   |   |   +-- tls-options.yaml
|   |   +-- scripts/
|   |       +-- test-ingress.sh
|   |
|   |-- cert-manager/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- clusterissuer-letsencrypt.yaml
|   |       +-- clusterissuer-letsencrypt-staging.yaml
|   |
|   |-- cloudflare/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- scripts/
|   |   |   +-- zero-trust-setup.sh      # FROM: scripts/cloudflare-zero-trust-setup.sh
|   |   |   +-- finalize-github-idp.sh   # FROM: scripts/cloudflare-finalize-github-idp.sh
|   |   +-- config/
|   |       +-- warp-config.yaml         # Cloudflare WARP connector config
|   |
|   |-- cloudnativepg/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml              # Operator values
|   |   +-- manifests/
|   |   |   +-- cluster-primary.yaml     # PostgreSQL Cluster CRD
|   |   |   +-- cluster-replica.yaml     # Read replica (future)
|   |   |   +-- scheduled-backup.yaml
|   |   |   +-- pooler.yaml             # PgBouncer pooler
|   |   +-- scripts/
|   |       +-- backup.sh
|   |       +-- restore.sh
|   |       +-- create-database.sh       # FROM: docker-compose/postgres/init/00-create-databases.sql
|   |
|   |-- valkey/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |       +-- valkey.conf              # FROM: docker-compose/redis/redis.conf.template
|   |
|   |-- minio/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   |   +-- values-prod.yaml
|   |   +-- manifests/
|   |   |   +-- ingress.yaml
|   |   +-- scripts/
|   |       +-- create-buckets.sh
|   |       +-- health-check.sh
|   |
|   |-- harbor/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   |   +-- values-prod.yaml
|   |   +-- scripts/
|   |       +-- gc-artifacts.sh          # Garbage collection
|   |
|   |-- zitadel/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   |   +-- values-prod.yaml
|   |   +-- manifests/
|   |   |   +-- ingress.yaml
|   |   +-- config/
|   |   |   +-- oidc-clients.yaml        # OIDC client definitions (non-secret)
|   |   +-- scripts/
|   |       +-- setup-oidc-clients.sh
|   |       +-- backup-config.sh
|   |
|   |-- openbao/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |   |   +-- config.hcl               # FROM: docker-compose/openbao/config.hcl
|   |   +-- manifests/
|   |   |   +-- ingress.yaml
|   |   +-- scripts/
|   |       +-- init-vault.sh
|   |       +-- unseal.sh
|   |       +-- backup.sh
|   |
|   |-- crowdsec/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |       +-- acquis.yaml              # Acquisition config
|   |       +-- profiles.yaml
|   |
|   |-- kyverno/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- policies/
|   |           +-- require-labels.yaml
|   |           +-- disallow-privileged.yaml
|   |           +-- require-resource-limits.yaml
|   |           +-- restrict-image-registries.yaml
|   |
|   |-- neuvector/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |       +-- values.yaml
|   |
|   |-- gitleaks/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- config/
|   |       +-- .gitleaks.toml
|   |
|   |-- sops/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- config/
|   |       +-- .sops.yaml
|   |
|   |-- external-secrets/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- cluster-secret-store.yaml
|   |
|   |-- prometheus/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml              # kube-prometheus-stack
|   |   |   +-- values-prod.yaml
|   |   +-- manifests/
|   |       +-- service-monitors/
|   |       |   +-- traefik.yaml
|   |       |   +-- cloudnativepg.yaml
|   |       +-- rules/
|   |           +-- alerting-rules.yaml
|   |
|   |-- grafana/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |   |   +-- dashboards/
|   |   |       +-- cluster-overview.json
|   |   |       +-- postgresql.json
|   |   |       +-- traefik.json
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- loki/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |       +-- values.yaml
|   |
|   |-- alertmanager/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- config/
|   |       +-- alertmanager.yaml         # Routing, receivers (non-secret parts)
|   |
|   |-- devtron/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- backstage/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |   |   +-- app-config.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- outline/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- rocket-chat/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- postal/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |   |   +-- postal.yml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- n8n/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- velero/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |   |   +-- backup-schedule.yaml
|   |   |   +-- backup-storage-location.yaml
|   |   +-- scripts/
|   |       +-- restore.sh
|   |       +-- verify-backup.sh
|   |
|   |-- ollama/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- pvc-models.yaml
|   |
|   |-- open-webui/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- manifests/
|   |       +-- ingress.yaml
|   |
|   |-- searxng/
|   |   +-- README.md
|   |   +-- CHANGELOG.md
|   |   +-- helm/
|   |   |   +-- values.yaml
|   |   +-- config/
|   |       +-- settings.yml
|   |
|   +-- website/
|       +-- README.md
|       +-- CHANGELOG.md
|       +-- manifests/
|       |   +-- deployment.yaml
|       |   +-- service.yaml
|       |   +-- ingress.yaml
|       +-- scripts/
|           +-- build-deploy.sh
|
|-- archive/                             # Deprecated -- read-only reference
|   +-- docker-compose/                  # MOVED FROM: docker-compose/
|       +-- (entire current docker-compose/ tree)
|
+-- .worktrees/                          # Git worktrees (gitignored)
```

---

## 5. Per-Service Folder Convention

Every service folder follows this template. Not every service needs every subdirectory -- only create what's used.

```
services/{service-name}/
|
|-- README.md                  # REQUIRED. What, why, how to deploy, dependencies
|-- CHANGELOG.md               # REQUIRED. Version history, config changes, incidents
|
|-- helm/                      # Helm chart values (if deployed via Helm)
|   |-- values.yaml            # Base values (shared across environments)
|   |-- values-prod.yaml       # Production overrides
|   +-- values-staging.yaml    # Staging overrides (when applicable)
|
|-- manifests/                 # Raw K8s manifests, CRDs, IngressRoutes
|   |-- ingress.yaml           # IngressRoute or Ingress
|   |-- *.yaml                 # Any raw manifests not in Helm
|   +-- policies/              # Kyverno policies specific to this service
|
|-- config/                    # App-specific configuration (non-secret)
|   +-- *.yaml|*.toml|*.conf  # Config files mounted as ConfigMaps
|
|-- scripts/                   # Operational scripts
|   |-- backup.sh
|   |-- restore.sh
|   |-- health-check.sh
|   +-- migrate.sh
|
+-- kustomization.yaml         # OPTIONAL. Only if using Kustomize overlays
```

### README.md Template

```markdown
# {Service Name}

**Chart**: {helm-repo}/{chart-name}
**Version**: {chart-version}
**Namespace**: {k8s-namespace}
**Depends On**: {list of service dependencies}
**ArgoCD App**: {app name in ArgoCD}

## Overview
{1-2 sentences on what this service does in the Helix Stax stack}

## Deploy
{How to deploy: ArgoCD sync, helm install, or kubectl apply}

## Configuration
{Key config decisions, environment variables, OIDC setup}

## Backup & Restore
{How to back up and restore this service's data}

## Troubleshooting
{Common issues and fixes}
```

### CHANGELOG.md Template

```markdown
# {Service Name} Changelog

## [Unreleased]

## [YYYY-MM-DD] - {version or description}
### Changed
- {What changed and why}
### Added
- {New configs, features}
### Fixed
- {Bug fixes, incidents}
```

---

## 6. Migration Plan

### 6.1 File Migration Map

| # | Current Path | Target Path | Risk | Notes |
|---|-------------|-------------|------|-------|
| 1 | `helm/` (empty) | DELETE | None | Empty directory, no content to move |
| 2 | `scripts/cloudflare-zero-trust-setup.sh` | `services/cloudflare/scripts/zero-trust-setup.sh` | Low | Script reference in runbooks needs updating |
| 3 | `scripts/cloudflare-finalize-github-idp.sh` | `services/cloudflare/scripts/finalize-github-idp.sh` | Low | Same as above |
| 4 | `scripts/firewall-setup.sh` | `opentofu/k3s/firewall-setup.sh` | Low | Host-level firewall, belongs with provisioning |
| 5 | `terraform/` (all TF files) | `opentofu/environments/prod/` | **MEDIUM** | Terraform state references current paths. Must `terraform state` migrate or use `-chdir`. See 6.2. |
| 6 | `terraform/modules/` | `opentofu/modules/` | **MEDIUM** | Module source paths in `main.tf` must update |
| 7 | `terraform/cloud-init/` | `opentofu/cloud-init/` | Low | Referenced by TF templatefile(), path updates needed |
| 8 | `terraform/k3s/` | `opentofu/k3s/` | Low | Referenced by TF, path updates needed |
| 9 | `docker-compose/` (entire tree) | `archive/docker-compose/` | Low | Legacy reference only. Not actively used. |
| 10 | `docker-compose/openbao/config.hcl` | `services/openbao/config/config.hcl` (copy) | None | Copy to new location, original archived |
| 11 | `docker-compose/redis/redis.conf.template` | `services/valkey/config/valkey.conf` (adapt) | Low | Rename redis->valkey, adjust for K8s |
| 12 | `docker-compose/postgres/init/00-create-databases.sql` | `services/cloudnativepg/scripts/create-database.sh` (adapt) | Low | Convert SQL init to K8s-compatible script |

### 6.2 OpenTofu State Migration

The `terraform/` directory contains live state files and provider cache. Migration requires care:

1. **State files** (`terraform.tfstate`, backups) should NOT be in git. They are currently committed (violation of `.gitignore`? check). Migrate to remote state (S3/MinIO backend) BEFORE restructuring.

2. **Provider cache** (`.terraform/`) is gitignored -- no action needed, it regenerates on `tofu init`.

3. **Lock file** (`.terraform.lock.hcl`) is gitignored -- regenerates on `tofu init`.

4. **Migration steps**:
   ```bash
   # 1. Move to remote state FIRST (if not already)
   # 2. Rename directory
   mv terraform/ opentofu/
   # 3. Reorganize into environments/prod/
   mkdir -p opentofu/environments/prod
   mv opentofu/main.tf opentofu/providers.tf opentofu/variables.tf \
      opentofu/outputs.tf opentofu/terraform.tfvars.example \
      opentofu/environments/prod/
   # 4. Update module source paths in main.tf
   #    "../../modules/hetzner-server" instead of "../modules/hetzner-server"
   # 5. Run `tofu init` in new location
   # 6. Run `tofu plan` to verify no changes
   ```

### 6.3 Files That MUST NOT Move

| Path | Reason |
|------|--------|
| `docs/` (entire tree) | Already organized. Recently reorganized `gemini-skill-prompts/`. |
| `docs/gemini-skill-prompts/` | Just restructured. Explicitly flagged as do-not-touch. |
| `CLAUDE.md` | Project root AI config |
| `README.md` | Repo root |
| `CHANGELOG.md` | Repo root |
| `.gitignore` | Repo root |
| `assets/` | Static assets, no change needed |
| `.worktrees/` | Git worktrees, gitignored |

---

## 7. ArgoCD Integration

### 7.1 App-of-Apps Pattern

ArgoCD uses a root "app-of-apps" Application that points to the `services/` directory. Each subfolder becomes an ArgoCD Application automatically.

```
services/argocd/manifests/app-of-apps.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/KeemWilliams/helix-stax-infrastructure.git
    targetRevision: main
    path: services/argocd/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 7.2 ApplicationSet with Git Directory Generator

The preferred approach. A single ApplicationSet automatically discovers all service folders:

```
services/argocd/manifests/applicationset.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: helix-stax-services
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/KeemWilliams/helix-stax-infrastructure.git
        revision: main
        directories:
          - path: services/*
          - path: services/argocd    # Exclude ArgoCD itself (managed separately)
            exclude: true
  template:
    metadata:
      name: '{{path.basename}}'
      namespace: argocd
    spec:
      project: helix-stax
      source:
        repoURL: https://github.com/KeemWilliams/helix-stax-infrastructure.git
        targetRevision: main
        path: '{{path}}/helm'
        helm:
          valueFiles:
            - values.yaml
            - values-prod.yaml       # Override file (ignored if missing)
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

### 7.3 How Helm Values Paths Change

| Before (planned) | After |
|-------------------|-------|
| `helm/traefik/values.yaml` | `services/traefik/helm/values.yaml` |
| `helm/zitadel/values.yaml` | `services/zitadel/helm/values.yaml` |

ArgoCD ApplicationSet automatically uses `{{path}}/helm` as the chart source for each service. Services using raw manifests instead of Helm would use `{{path}}/manifests` -- this requires a second ApplicationSet generator or per-service Application overrides.

### 7.4 Handling Mixed Sources (Helm + Manifests)

Some services need BOTH Helm values AND raw manifests (e.g., Prometheus needs Helm values + custom ServiceMonitors). Two approaches:

**Option A (Recommended): Multi-source Applications**
ArgoCD 2.6+ supports multiple sources per Application. The ApplicationSet can be enhanced:
```yaml
sources:
  - repoURL: https://charts.example.com
    chart: kube-prometheus-stack
    targetRevision: 65.x
    helm:
      valueFiles:
        - $values/services/prometheus/helm/values.yaml
  - repoURL: https://github.com/KeemWilliams/helix-stax-infrastructure.git
    targetRevision: main
    ref: values
    path: services/prometheus/manifests
```

**Option B: Kustomize wrapper**
Use `kustomization.yaml` in each service folder to combine Helm output + raw manifests. More complex but more portable.

### 7.5 AppProject Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: helix-stax
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/KeemWilliams/helix-stax-infrastructure.git
    - https://charts.*.com  # Allow Helm chart repos
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
```

### 7.6 Platform Resources

The `platform/` directory contains cluster-wide resources (namespaces, RBAC, network policies). These are managed by a separate ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-base
  namespace: argocd
spec:
  project: helix-stax
  source:
    repoURL: https://github.com/KeemWilliams/helix-stax-infrastructure.git
    targetRevision: main
    path: platform
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 8. Risks and Mitigations

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| 1 | **OpenTofu state breaks after rename** | HIGH | Migrate to remote state backend (MinIO S3) BEFORE restructuring. Run `tofu plan` after move to confirm zero drift. |
| 2 | **Runbook/tutorial links break** | MEDIUM | `docs/` is NOT moving. Only `scripts/` paths change. Update references in runbooks that mention `scripts/` paths. |
| 3 | **CLAUDE.md references stale paths** | LOW | Update CLAUDE.md conventions section after restructure. One-line changes. |
| 4 | **Worktree divergence** | MEDIUM | The `.worktrees/feature/zero-trust-network/` worktree has its own `docker-compose/`, `terraform/`, `scripts/`. Merge or close the worktree BEFORE restructuring main branch. |
| 5 | **ArgoCD bootstrap chicken-and-egg** | LOW | ArgoCD must be installed manually first (Helm install from CLI), THEN it manages itself via `services/argocd/`. Document this in `services/argocd/README.md`. |
| 6 | **Too many empty folders committed** | LOW | Only create service folders when the service is actually being deployed. Start with the first services in the dependency chain (traefik, cert-manager, cloudnativepg). |
| 7 | **Confusion during transition** | LOW | Clear commit messages. Single PR for the structural move. No functional changes mixed in. |

---

## 9. Implementation Order

The restructure should happen in phases, not all at once. Each phase is a single PR.

### Phase 0: Pre-Requisites
1. Close or merge the `feature/zero-trust-network` worktree
2. Migrate OpenTofu state to remote backend (MinIO or Backblaze B2)
3. Verify `.gitignore` excludes `*.tfstate`, `.terraform/`

### Phase 1: Skeleton + Rename (Single PR)
1. Create `services/` directory with ArgoCD bootstrap folder only
2. Create `platform/` directory with namespace definitions
3. Rename `terraform/` to `opentofu/` and reorganize into `environments/prod/` + `modules/`
4. Move `scripts/*.sh` into `services/cloudflare/scripts/` and `opentofu/k3s/`
5. Move `docker-compose/` to `archive/docker-compose/`
6. Delete empty `helm/` directory
7. Update CLAUDE.md conventions
8. Update `.gitignore` if needed

### Phase 2: First Services (As They Deploy)
Create service folders only when deploying to K3s. Follow the dependency chain:
1. `services/traefik/` -- first ingress
2. `services/cert-manager/` -- TLS
3. `services/cloudnativepg/` -- database
4. `services/valkey/` -- cache
5. `services/minio/` -- object storage

### Phase 3: Identity + Security
1. `services/zitadel/`
2. `services/openbao/`
3. `services/external-secrets/`
4. `services/crowdsec/`
5. `services/kyverno/`

### Phase 4: GitOps + Observability
1. `services/argocd/` -- full ApplicationSet + app-of-apps
2. `services/devtron/`
3. `services/prometheus/`
4. `services/grafana/`
5. `services/loki/`

### Phase 5: Applications
1. `services/n8n/`
2. `services/rocket-chat/`
3. `services/outline/`
4. `services/backstage/`
5. `services/postal/`
6. `services/velero/`
7. `services/website/`

### Phase 6: AI Stack
1. `services/ollama/`
2. `services/open-webui/`
3. `services/searxng/`

### Phase 7: Ansible (When OS Automation is Needed)
1. Create `ansible/` with initial inventory and hardening playbook
2. Port tutorial steps from `docs/tutorials/phase-00-hardening/` into Ansible roles

---

## Appendix A: Design Decision -- Why Not Put OpenTofu Inside services/?

OpenTofu modules provision **infrastructure** (Hetzner VPS, firewalls, DNS records), not Kubernetes workloads. A single `opentofu/environments/prod/main.tf` provisions ALL servers. It does not make sense to split this by service because:

1. A VPS hosts multiple services
2. Firewall rules are cross-cutting (one firewall, many ports)
3. DNS records could be per-service, but Cloudflare DNS is better managed by a single module
4. OpenTofu state is per-environment, not per-service

If future services need their OWN infrastructure (e.g., a dedicated Hetzner server for GPU workloads), add an `opentofu/environments/gpu/` directory.

## Appendix B: Design Decision -- Why Not Put Ansible Inside services/?

Same reasoning: Ansible roles configure the OS, not K8s workloads. A hardening playbook runs on ALL nodes. K3s installation runs on ALL nodes. CrowdSec agent installation runs on ALL nodes. These are cross-cutting OS concerns, not per-service.

Exception: If a service needs host-level setup (e.g., GPU drivers for Ollama), create a role in `ansible/roles/gpu-drivers/` and reference it from a playbook.

## Appendix C: Prometheus + Grafana -- One Stack or Separate?

The `kube-prometheus-stack` Helm chart bundles Prometheus, Grafana, Alertmanager, and node-exporter. Despite this, they get SEPARATE service folders because:

1. Grafana needs its own dashboards, ingress, and config
2. Alertmanager needs its own routing config
3. Service-specific ServiceMonitors live in their respective service folders
4. The Helm chart is installed via the `prometheus/` folder, but Grafana dashboards live in `grafana/config/dashboards/`

If using kube-prometheus-stack as a single install, the Helm values go in `services/prometheus/helm/values.yaml` and Grafana-specific overrides go in `services/grafana/helm/values.yaml` (which gets merged or referenced).

---

**End of document.**
