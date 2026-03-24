---
template: bug-report
category: operational
task_type: bug
clickup_list: "04 Service Management"
auto_tags: ["bug", "infrastructure"]
required_fields: ["TLDR", "Steps to Reproduce", "Severity", "Environment"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Bug Report

Use this template for any defect, regression, or unexpected behavior in Helix Stax services.
File in GitHub Issues with label `bug` before starting any fix work.

## TLDR [REQUIRED]

One sentence. What broke, and where. No background yet.

**Example**: The Zitadel login callback returns 500 when the `state` parameter is missing from the OAuth response.

---

## Steps to Reproduce [REQUIRED]

Numbered steps. Be exact. Include URLs, payloads, env vars if relevant.

1. [Numbered step]
2. [Numbered step]
3. [Numbered step]
4. [Numbered step]

**Reproducible in**: [ ] Local  [ ] vCluster preview  [ ] Dev  [ ] Production

**Frequency**: [ ] Always  [ ] Intermittent (~__% of attempts)  [ ] Once

---

## Expected vs Actual

| | Detail |
|---|---|
| **Expected** | |
| **Actual** | |

---

## Environment

| Field | Value |
|-------|-------|
| Service / Component | |
| Version / Image Tag | |
| Cluster | `heart` (CP) / `helix-worker-1` / vCluster |
| Namespace | |
| Ingress / URL | |
| Related PR or Commit | |

---

## Severity

Select one. See definitions below.

- [ ] **SEV-1 — Critical**: Production down or data loss. Requires immediate response.
- [ ] **SEV-2 — High**: Core feature broken; no workaround. Fix within 24 hours.
- [ ] **SEV-3 — Medium**: Feature degraded; workaround exists. Fix in next sprint.
- [ ] **SEV-4 — Low**: Cosmetic or minor inconvenience. Fix when convenient.

---

## Screenshots / Logs

<!-- Attach screenshots, paste relevant log lines, or link to Grafana/Loki query. -->
<!-- For logs: include timestamps and pod name. -->

```
# Paste log output here
```

---

## Component / Service Affected

Check all that apply.

- [ ] Zitadel (auth)
- [ ] Harbor (registry)
- [ ] MinIO (object storage)
- [ ] ArgoCD / Devtron (CI/CD)
- [ ] Traefik (ingress)
- [ ] Kong (API gateway)
- [ ] n8n (automation)
- [ ] Helix Stax website (helixstax.com)
- [ ] PostgreSQL
- [ ] Valkey (cache)
- [ ] Other: _______________

---

## Additional Context [OPTIONAL]

Anything else that helps. Recent deploys, config changes, related issues.

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC7.1 | Vulnerability management — documented issues with clear root cause | Structured bug report with steps, environment, and expected vs actual behavior |
| ISO 27001 | A.12.6.1 | Management of technical vulnerabilities | Captures affected systems, versions, and remediation steps |
| NIST CSF | ID.RA-3 | Risk assessment documented | Severity classification enables risk prioritization |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Severity level is assigned (SEV-1 through SEV-4)
- [ ] Steps to reproduce are clear and repeatable
- [ ] Environment details are complete (service, version, cluster, namespace)
- [ ] Bug report has been reviewed and verified by engineering
- [ ] GitHub issue created with link to this report

---

## Example

**TLDR**: PostgreSQL pod crashes with OOM every morning at 09:00 UTC on helix-worker-1 during CloudNativePG backup.

**Environment**:
| Field | Value |
|-------|-------|
| Service / Component | PostgreSQL (CloudNativePG) |
| Version / Image Tag | postgresql:16.2 |
| Cluster | helix-worker-1 |
| Namespace | database |
| Ingress / URL | N/A (internal service) |

**Severity**: SEV-2 — High

**Root Cause**: Backup job allocates 4Gi memory but pod only has 2Gi limit, causing OOM kill every morning.

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.1 |
