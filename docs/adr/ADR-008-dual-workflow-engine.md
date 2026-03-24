# ADR-008: Dual Workflow Engine (n8n + Airflow)

## TLDR

Operate two workflow engines with distinct responsibilities: n8n for real-time event-driven integrations and Airflow for scheduled compliance and infrastructure automation.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax has two fundamentally different workflow categories:

1. **Event-driven, real-time**: Webhook-triggered notifications, SaaS integrations (ClickUp, GitHub, Rocket.Chat), instant alert routing, and glue logic between services. These require sub-second response times and visual workflow building for rapid iteration.

2. **Scheduled, audit-grade**: Compliance scanning (OpenSCAP), configuration drift detection (Ansible `--check --diff`), backup verification (Velero restore tests), evidence archival, and secrets rotation. These require immutable task-level logs, retry logic, backfill capability, and auditor-acceptable execution records.

No single workflow engine handles both categories well. n8n excels at event-driven SaaS glue but produces ephemeral execution logs unsuitable for audit evidence. Airflow excels at scheduled DAG orchestration with persistent, queryable task logs but is overweight for simple webhook routing.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: n8n + Airflow (dual) | n8n for events, Airflow for schedules | Best tool for each job, audit-grade logs where needed | Two systems to maintain, integration overhead | Full coverage -- audit logs from Airflow, speed from n8n |
| **Option B**: n8n only | Single engine for everything | Simple, visual workflow builder | Ephemeral logs fail audit, no backfill, weak scheduling | Fails audit evidence requirements |
| **Option C**: Airflow only | Single engine for everything | Audit-grade everything | Massive overhead for simple webhooks, slow iteration | Over-engineers real-time integrations |
| **Option D**: Temporal | Single unified engine | Strong durability guarantees, code-first | High complexity, no visual builder, small community | Capable but operationally heavy |

---

## Decision

We will operate n8n and Airflow as complementary workflow engines with a clear domain boundary:

**n8n responsibilities:**
- Webhook receivers (GitHub, ClickUp, Cloudflare)
- Real-time notifications to Rocket.Chat
- SaaS-to-SaaS glue (ClickUp task creation, GitHub issue sync)
- Alert routing from Prometheus/Alertmanager
- Receiving notifications from Airflow tasks

**Airflow responsibilities:**
- Weekly OpenSCAP compliance scanning
- Daily Ansible drift detection (`--check --diff`)
- Weekly Velero backup verification
- Evidence archival to MinIO with SHA-256 hashing
- Secrets rotation orchestration via OpenBao

**Integration pattern:**
Airflow tasks trigger n8n for notifications via `SimpleHttpOperator`:
```
Airflow DAG task completes
  -> SimpleHttpOperator POST to n8n webhook
    -> n8n routes notification to Rocket.Chat
    -> n8n creates ClickUp task if action needed
```

n8n does NOT trigger Airflow. The boundary is one-directional: Airflow produces results, n8n distributes notifications.

---

## Rationale

The dual-engine approach matches each tool to its strength. Airflow's persistent task logs, retry mechanisms, and backfill capability produce audit-grade evidence that SOC 2 and ISO 27001 auditors accept. n8n's visual workflow builder and webhook-native design allows rapid iteration on notification routing and SaaS integrations without writing Python DAGs. The `SimpleHttpOperator` integration is lightweight and well-tested. A single-engine approach would either sacrifice audit quality (n8n only) or impose unnecessary complexity on simple integrations (Airflow only).

---

## Consequences

### Positive

- Audit-grade execution logs for all compliance tasks (Airflow)
- Sub-second response times for event-driven integrations (n8n)
- Clean separation of concerns -- compliance team works in Airflow, integration work in n8n
- Airflow DAGs are code (version-controlled in git); n8n workflows are visual (faster iteration)
- Each engine can be independently scaled, updated, and maintained

### Negative

- Two workflow systems to deploy, monitor, and maintain on a 2-node cluster
- Team must be proficient in both Airflow (Python DAGs) and n8n (visual builder)
- Integration point (SimpleHttpOperator) is an additional failure surface
- Resource consumption: Airflow scheduler + webserver + n8n = 3 persistent pods minimum
- Risk of scope creep if boundary between engines is not enforced

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Deploy Airflow on K3s (see ADR-007) | Wakeem Williams | 2026-04-27 | TBD |
| Create n8n webhook endpoints for Airflow notifications | Wakeem Williams | 2026-05-04 | TBD |
| Write initial Airflow DAGs (compliance, drift, backup) | Wakeem Williams | 2026-05-04 | TBD |
| Document engine boundary in runbook | Wakeem Williams | 2026-05-04 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| n8n | Receives Airflow notifications via webhook |
| Airflow | Sends completion notifications to n8n |
| Rocket.Chat | Receives routed notifications from n8n |
| ClickUp | Task creation triggered by n8n on Airflow alerts |
| MinIO | Evidence archival destination for Airflow tasks |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC7.2 | System monitoring | Airflow provides scheduled monitoring with audit logs |
| SOC 2 | CC8.1 | Change management | Airflow DAGs version-controlled, execution logged |
| ISO 27001 | A.8.15 | Logging | Airflow task logs provide immutable execution records |
| NIST CSF 2.0 | DE.CM-3 | Personnel activity monitored | Automated scanning reduces reliance on manual checks |
| HIPAA | 164.312(b) | Audit controls | Airflow logs satisfy audit trail requirements |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
