# ADR-010: Devtron with Internal ArgoCD

## TLDR

Use Devtron's built-in ArgoCD for GitOps deployment. No standalone ArgoCD instance. GitOps mode is mandatory for all deployments.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax uses Devtron as its CI/CD platform on K3s. Devtron ships with an integrated ArgoCD instance that handles GitOps synchronization. Early architecture plans included deploying a separate standalone ArgoCD instance alongside Devtron, but this creates redundancy: two ArgoCD instances watching the same Git repositories, competing for sync operations, and consuming duplicate resources on an already constrained 2-node cluster.

The CI/CD pipeline must follow GitOps principles: Devtron CI builds images and commits updated manifests to Git, then ArgoCD syncs the desired state from Git to the cluster. Admission enforcement (image signing verification) must happen at the Kubernetes API server level via Kyverno, not at the ArgoCD sync level -- ArgoCD should sync whatever is in Git, and the API server should reject unauthorized images.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: Devtron + internal ArgoCD | Use Devtron's built-in ArgoCD only | Single control plane, no redundancy, lower resource usage | Locked to Devtron's ArgoCD version | Satisfies GitOps requirements |
| **Option B**: Devtron + standalone ArgoCD | Separate ArgoCD alongside Devtron | Independent ArgoCD upgrades, more flexibility | Duplicate sync engines, resource waste, sync conflicts | Same compliance, more complexity |
| **Option C**: Standalone ArgoCD only | Drop Devtron, use ArgoCD + separate CI | Maximum ArgoCD flexibility | Lose Devtron's UI, app management, and CI integration | Same compliance, lose developer experience |
| **Option D**: Flux CD | Replace ArgoCD entirely with Flux | Lighter weight, no UI overhead | Different tooling, lose Devtron integration | Same compliance, different ecosystem |

---

## Decision

We will use Devtron's internal ArgoCD as the sole GitOps deployment engine. No standalone ArgoCD instance will be deployed.

**Pipeline flow:**
```
Developer pushes code
  -> Devtron CI pipeline triggers
    -> Build container image
    -> Push to Harbor (Trivy scan)
    -> Sign with Cosign (ADR-009)
    -> Commit updated manifests to Git
      -> Internal ArgoCD detects Git change
        -> ArgoCD syncs manifests to K3s
          -> Kyverno validates image signature at admission
            -> Pod created (or rejected if unsigned)
```

**Key constraints:**
- GitOps mode is mandatory -- no direct `kubectl apply` or Devtron "deploy" bypassing Git
- Kyverno admission enforcement happens at the K3s API server, not at ArgoCD sync time
- ArgoCD sync policy: auto-sync enabled with self-heal for drift correction
- Manual sync required for production namespaces (auto-sync for staging only)

---

## Rationale

Running two ArgoCD instances on a 2-node cluster is wasteful and introduces sync conflicts. Devtron's internal ArgoCD provides full GitOps functionality -- application definitions, sync policies, health checks, and drift detection -- without the overhead of a separate installation. Admission enforcement at the Kyverno level (not ArgoCD) ensures that the policy applies to all pod creation paths, not just ArgoCD-managed deployments. This prevents bypass via `kubectl` or other tooling.

---

## Consequences

### Positive

- Single GitOps control plane -- no sync conflicts between competing ArgoCD instances
- Lower resource consumption on the 2-node cluster
- Devtron UI provides unified CI+CD visibility
- Kyverno at API admission ensures policy enforcement regardless of deployment method
- Auto-sync with self-heal corrects configuration drift automatically

### Negative

- Locked to Devtron's bundled ArgoCD version for upgrades
- If Devtron is removed in the future, ArgoCD configuration must be migrated
- Devtron's internal ArgoCD may lag behind upstream ArgoCD releases
- No standalone ArgoCD UI -- must use Devtron's interface for CD operations

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Verify Devtron internal ArgoCD is operational | Wakeem Williams | 2026-04-06 | TBD |
| Configure GitOps mode as mandatory for all apps | Wakeem Williams | 2026-04-06 | TBD |
| Set auto-sync policies per namespace | Wakeem Williams | 2026-04-13 | TBD |
| Remove any standalone ArgoCD Helm releases if present | Wakeem Williams | 2026-04-06 | TBD |
| Document GitOps deployment workflow in runbook | Wakeem Williams | 2026-04-13 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| Devtron | Primary CI/CD platform, internal ArgoCD manages CD |
| ArgoCD (standalone) | Removed -- replaced by Devtron internal ArgoCD |
| Kyverno | Admission webhook validates all pod creation |
| Harbor | Image registry for CI artifacts |
| Infrastructure Git repo | Source of truth for all Kubernetes manifests |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC8.1 | Change management | GitOps ensures all changes go through Git with audit trail |
| ISO 27001 | A.12.1.2 | Change management | Git history provides complete change record |
| NIST CSF 2.0 | PR.IP-3 | Configuration change control | ArgoCD auto-sync detects and corrects drift |
| HIPAA | 164.312(c)(2) | Integrity mechanisms | Git-based deployment with Kyverno enforcement |
| CIS Controls v8.1 | 4.1 | Secure configuration process | GitOps prevents manual configuration changes |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
