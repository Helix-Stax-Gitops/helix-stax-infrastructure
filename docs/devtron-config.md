# Devtron Configuration

**Last Updated**: 2026-03-25
**Version**: Devtron Operator 0.23.2 (with CICD module)
**Namespace**: `devtroncd`
**URL**: `devtron.helixstax.net` (via Traefik IngressRoute)

## Global Config State

| Component | Status | Notes |
|-----------|--------|-------|
| Chart repositories | Configured | See table below |
| Environments | Configured | production, staging |
| Git account | Configured | GitHub — helix-stax-infra repo |
| helix-platform project | Created | Active project for all platform services |
| CICD module | Enabled | Devtron's built-in CI + ArgoCD-backed CD |
| ArgoCD (standalone) | Disabled | `argo-cd.enabled: false` in values.yaml — Devtron manages its own ArgoCD |

## Chart Repositories

| Name | URL | Used For |
|------|-----|----------|
| bitnami | https://charts.bitnami.com/bitnami | Valkey |
| devtron | https://helm.devtron.ai | Devtron operator self-update |
| harbor | https://helm.goharbor.io | Harbor registry |
| jetstack | https://charts.jetstack.io | cert-manager (if needed) |
| minio | https://charts.min.io/ | MinIO object storage |
| ollama-helm | https://otwld.github.io/ollama-helm/ | Ollama LLM server |
| open-webui | https://helm.openwebui.com | Open WebUI |
| prometheus-community | https://prometheus-community.github.io/helm-charts | Prometheus stack, Loki, Promtail |
| rocketchat | https://rocketchat.github.io/helm-charts | Rocket.Chat |
| vmware-tanzu | https://vmware-tanzu.github.io/helm-charts | Velero backup |
| zitadel | https://charts.zitadel.com | Zitadel identity |

## Environments

| Name | Namespace | Cluster |
|------|-----------|---------|
| production | production | default (helix-stax-cp) |
| staging | staging | default (helix-stax-cp) |

## helix-platform Project

All platform infrastructure services are grouped under the `helix-platform` project in Devtron. This is the primary project for deploying and managing all Helm-based services.

Services within helix-platform:
- cloudnativepg (database)
- zitadel (identity)
- valkey (cache)
- minio (storage)
- harbor (registry)
- devtron (CI/CD — self-managed)
- rocketchat (comms)
- ollama (AI inference)
- open-webui (AI frontend)
- velero (backup)
- prometheus-stack (monitoring)

## Database Backend

Devtron uses an external PostgreSQL cluster (CloudNativePG `helix-pg`) rather than a bundled database.

| Parameter | Value |
|-----------|-------|
| Host | `helix-pg-rw.database.svc.cluster.local` |
| Port | 5432 |
| Database | `orchestrator` |
| User | `postgres` (superuser — Devtron migrations require this) |

Devtron also uses these databases (all must exist before install):
`orchestrator`, `lens`, `git_sensor`, `casbin`, `clairv4`

The PG password is sourced at install time from the CNPG-managed secret:
```bash
kubectl -n database get secret helix-pg-app -o jsonpath='{.data.password}' | base64 -d
```

## Deploying a Service via Devtron

### Prerequisites

1. Helm chart repository added under Global Config > Chart Repositories
2. Environment created under Global Config > Clusters & Environments
3. Git account connected under Global Config > Git Accounts
4. Service-specific secrets created in the target namespace (see [helm-services.md](helm-services.md))

### Deployment Steps

1. Open Devtron > Charts > Chart Store
2. Search for the chart name (e.g., `zitadel`)
3. Click Deploy, select chart version, select environment
4. Paste values from `helm/{service}/values.yaml`
5. Click Deploy — Devtron triggers an ArgoCD sync
6. Monitor: Applications > helix-platform > the deployed app
7. Verify: check pod status in the target namespace

### Checking Deployment Status

```bash
# From the CP node
kubectl get pods -n <namespace>
kubectl get pods -A  # all namespaces
```

Or via Devtron UI: Applications > helix-platform > select app > Pod section.

## Service Deployment Order

Deploy in this order. Dependencies must be Running before dependents start.

```
1. cloudnativepg (CNPG operator)    — no dependencies
   └── 1a. helix-pg cluster         — CNPG operator must be ready
2. valkey                            — no dependencies
3. minio                             — no dependencies
4. harbor                            — no dependencies (uses internal PG + Redis)
5. zitadel                           — requires helix-pg cluster (step 1a)
6. devtron                           — requires helix-pg cluster (step 1a)
7. rocketchat                        — requires zitadel (for OIDC, configurable post-deploy)
8. ollama                            — no strict dependencies
9. open-webui                        — requires ollama (step 8)
10. velero                           — requires minio (step 3)
11. prometheus-stack                 — no strict dependencies (scrape targets configure after)
```

## Related

- [helm-services.md](helm-services.md) — Detailed values, secrets, and dependencies per service
- [cluster-topology.md](cluster-topology.md) — Node layout and network
- `helm/devtron/values.yaml` — Devtron Helm values
