---
title: "Backup & Restore Evidence Template"
policy_id: POL-023
category: procedure
classification: INTERNAL
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: SOC 2
    controls: ["CC7.5", "CC A1.2"]
  - framework: ISO 27001
    controls: ["A.8.13"]
  - framework: HIPAA
    controls: ["164.308(a)(7)", "164.310(d)(2)(iv)"]
---

# Backup & Restore Evidence Template

## TLDR

Establishes the evidence-gathering framework for data integrity and system recovery. Covers daily backup success logs, quarterly restore test procedures, automated monitoring via Airflow/Prometheus, and Velero command references. Required by SOC 2, ISO 27001, and HIPAA. Approved by CEO.

---

## Purpose

This document establishes the evidence-gathering framework for data integrity and system recovery, ensuring Helix Stax can demonstrate backup reliability and restore capability to auditors.

## Scope

- All backup operations (K3s, PostgreSQL, MinIO, Backblaze B2)
- All restore testing activities
- All Velero-managed backup and restore operations

---

## Procedure Steps

### 1. Daily Backup Success Log (Automated)

Data is typically aggregated via Prometheus into a monthly compliance report.

| Date | Backup Name/Scope | Duration | Size | Destination | Status | Error Code/Log Link | Auditor Initial |
|------|-------------------|----------|------|-------------|--------|--------------------|-----------------|
| YYYY-MM-DD | k8s-cluster-daily | 12m 4s | 45GB | MinIO -> B2 | SUCCESS | N/A | [System] |
| YYYY-MM-DD | postgres-app-db | 5m 12s | 1.2GB | MinIO -> B2 | FAILED | ERR_PARTIAL_RESTIC_SYNC | [Manual] |

### 2. Quarterly Restore Test Procedure

**Frequency:** Minimum once per calendar quarter.

1. **Selection:** Identify a "Critical" backup from the last 30 days (e.g., Production DB)
2. **Environment:** Provision a non-production namespace or isolated K3s node
3. **Execution:** Use Velero to restore the selected backup
4. **Verification:** Run data integrity queries (row counts, checksums)
5. **Documentation:** Complete the Restore Test Evidence Template (Section 3)

### 3. Restore Test Evidence Template

| Field | Value |
|-------|-------|
| **Test ID** | BKP-TEST-YYYY-QX |
| **Backup Tested** | [Backup Name / Snapshot ID] |
| **Target Environment** | [Namespace/Cluster Name] |
| **Personnel** | [Engineer Name] |

**RTO/RPO Metrics:**

| Metric | Target | Actual |
|--------|--------|--------|
| RPO | 24 Hours | [Time since last backup] |
| RTO | 4 Hours | [Time from command to ready] |

**Validation Queries:**

- `SELECT count(*) FROM users;` -> Result: [Count] (Matches Prod: Yes/No)
- `kubectl get pods -n restore-test` -> Status: [Running]

**Pass/Fail:** [PASS/FAIL]
**Evidence Attachments:** [Link to CLI logs, screenshot of successful pod status]

### 4. Automated Backup Monitoring

1. **Sensor:** Query Velero API/CLI for backups completed in the last 24h
2. **Analyzer:** Filter for `Status: Failed` or `Status: PartiallyFailed`
3. **Notifier:** If failures > 0, trigger Slack/PagerDuty alert
4. **Logger:** Append results to the Backup Success Log in the Compliance Vault

### 5. Velero Command Reference

| Command | Purpose |
|---------|---------|
| `velero backup get` | List all backups |
| `velero backup describe <NAME> --details` | Check specific backup details |
| `velero backup logs <NAME>` | View backup logs (evidence) |
| `velero restore create --from-backup <NAME> --namespace-mappings prod:restore-test` | Execute restore |
| `velero restore describe <NAME>` | Verify restore status |

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve backup/restore strategy, review quarterly test results |
| **DevOps Lead** | Execute backups, run restore tests, maintain Velero configuration |
| **Compliance Lead** | Track restore test completion, archive evidence for auditors |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| SOC 2 | CC7.5 | System Recovery |
| SOC 2 | CC A1.2 | Recovery Testing |
| ISO 27001 | A.8.13 | Information Backup |
| HIPAA | 164.308(a)(7) | Contingency Plan |
| HIPAA | 164.310(d)(2)(iv) | Data Backup and Storage |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
