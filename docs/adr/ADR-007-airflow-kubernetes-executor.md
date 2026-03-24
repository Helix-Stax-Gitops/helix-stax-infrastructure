# ADR-007: KubernetesExecutor for Apache Airflow

## TLDR

Deploy Apache Airflow on K3s using the KubernetesExecutor, spawning ephemeral pods per task instead of maintaining persistent Celery workers.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax requires a workflow orchestration engine for scheduled compliance tasks: weekly OpenSCAP scans, daily Ansible drift detection, weekly backup verification, and evidence archival. Apache Airflow is selected for this role (see ADR-008 for dual-engine rationale).

Airflow supports multiple executor backends. The two primary options for Kubernetes deployments are:

1. **CeleryExecutor**: Persistent worker pods consuming tasks from a Redis/RabbitMQ queue. Workers are always running, consuming resources whether tasks are executing or not.
2. **KubernetesExecutor**: Spawns an ephemeral pod for each task. Pod is created on task trigger, executes, and is destroyed. No persistent workers.

On a resource-constrained 2-node K3s cluster, persistent Celery workers represent wasted capacity. Compliance scanning tasks run on fixed schedules (daily/weekly) with significant idle time between runs. Each task may require a different toolset (OpenSCAP, Ansible, Velero CLI) -- the KubernetesExecutor allows each task to use its own container image.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: KubernetesExecutor | Ephemeral pod per task | Zero idle resource usage, per-task container images, clean isolation | Pod startup latency (~10-30s), no warm workers | Satisfies audit requirements with task-level logging |
| **Option B**: CeleryExecutor | Persistent worker pool + message queue | Low task latency, proven at scale | Always-on resource consumption, requires Valkey/RabbitMQ, shared worker environment | Same audit capability |
| **Option C**: LocalExecutor | Tasks run in scheduler process | Simplest setup, no additional components | Single point of failure, no parallelism, no isolation | Weak -- no task-level isolation |

---

## Decision

We will deploy Airflow on K3s using the KubernetesExecutor. Each DAG task spawns a dedicated ephemeral pod with its own container image, executes, and terminates.

**Configuration:**
- Airflow scheduler and webserver deployed as K3s Deployments
- DAGs synced via git-sync sidecar from the infrastructure repo
- Each task specifies its container image via `KubernetesPodOperator` or executor config
- PostgreSQL backend via CloudNativePG (shared Airflow metadata database)
- OIDC authentication with Zitadel for webserver access

**Task container images:**
| Task Type | Container Image |
|-----------|----------------|
| OpenSCAP scanning | Custom image with `openscap-scanner` + `scap-security-guide` |
| Ansible drift detection | Custom image with `ansible-core` + `ansible-lockdown/RHEL9-CIS` |
| Backup verification | Custom image with `velero` CLI + `kubectl` |
| Evidence archival | Custom image with `mc` (MinIO client) + `sha256sum` |

---

## Rationale

The KubernetesExecutor is the natural fit for a resource-constrained cluster with bursty, scheduled workloads. Compliance tasks run on fixed schedules with long idle periods -- paying the resource cost of persistent Celery workers (minimum 2 pods + message queue) for tasks that execute minutes per day is wasteful. Pod startup latency of 10-30 seconds is irrelevant for cron-scheduled compliance scans. Per-task container images provide clean dependency isolation and reproducible execution environments.

---

## Consequences

### Positive

- Zero resource consumption between scheduled tasks
- Each task runs in its own isolated container with dedicated tooling
- No message queue dependency (no Valkey/RabbitMQ for task dispatch)
- Pod-level resource limits prevent any single task from starving the cluster
- Task pods are ephemeral -- no persistent state to manage or secure
- Container images for each task type can be independently versioned and updated

### Negative

- Pod startup latency (10-30s) added to each task execution
- Container images must be pre-built and available in Harbor for each task type
- Debugging failed tasks requires inspecting completed/failed pod logs before cleanup
- KubernetesExecutor is less battle-tested at very high concurrency than CeleryExecutor
- git-sync sidecar adds a small resource footprint to the scheduler pod

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Build task container images (OpenSCAP, Ansible, Velero, MinIO) | Wakeem Williams | 2026-04-27 | TBD |
| Deploy Airflow scheduler + webserver on K3s | Wakeem Williams | 2026-04-27 | TBD |
| Configure git-sync sidecar for DAG repository | Wakeem Williams | 2026-04-27 | TBD |
| Create OIDC client in Zitadel for Airflow webserver | Wakeem Williams | 2026-05-04 | TBD |
| Write initial compliance DAGs (scan, drift, backup) | Wakeem Williams | 2026-05-04 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| K3s cluster | Airflow scheduler/webserver pods + ephemeral task pods |
| CloudNativePG | Airflow metadata database added |
| Harbor | Task container images stored and scanned |
| Zitadel | OIDC client for Airflow web authentication |
| Infrastructure repo | DAGs directory added for git-sync |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC7.1 | Detection and monitoring activities | Airflow orchestrates compliance scanning tasks |
| ISO 27001 | A.8.8 | Management of technical vulnerabilities | Scheduled vulnerability and drift detection |
| NIST CSF 2.0 | DE.CM-8 | Vulnerability scans performed | Airflow DAGs automate weekly OpenSCAP scans |
| HIPAA | 164.308(a)(8) | Evaluation | Automated periodic security assessments |
| CIS Controls v8.1 | 4.1 | Establish and maintain secure configuration | Drift detection verifies configuration baseline |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
