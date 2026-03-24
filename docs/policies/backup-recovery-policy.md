---
title: "Backup & Recovery Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-006"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC7.5", "CC9.1"]
  - framework: "ISO 27001"
    controls: ["A.8.13", "A.8.14"]
  - framework: "HIPAA"
    controls: ["164.308(a)(7)(i)", "164.308(a)(7)(ii)(A)", "164.310(d)(2)(iv)"]
  - framework: "NIST CSF"
    controls: ["PR.IP-4", "RC.RP-1"]
---

# Backup & Recovery Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Backup & Recovery Policy defines RPO/RTO targets, backup schedules (Velero daily), restore testing cadence (quarterly), offsite storage (Backblaze B2), and encryption requirements for all backups. Required by SOC 2 CC7.5, ISO 27001 A.8.13, HIPAA 164.308(a)(7). Approved by CEO.

---

## 1. Purpose

This policy ensures that Helix Stax can recover critical systems and data following a disaster, hardware failure, data corruption, or security incident. It defines backup frequency, retention, encryption, storage locations, and restore verification procedures.

## 2. Scope

This policy applies to all data and systems hosted on the Helix Stax K3s cluster, including:

- Kubernetes cluster state (etcd, manifests, secrets)
- PostgreSQL databases (CloudNativePG)
- MinIO object storage buckets
- Harbor container registry
- Application persistent volumes
- Configuration repositories (Git)
- OpenBao secrets engine data

## 3. Definitions

| Term | Definition |
|------|-----------|
| **RPO (Recovery Point Objective)** | The maximum acceptable amount of data loss measured in time; how far back the most recent usable backup extends |
| **RTO (Recovery Time Objective)** | The maximum acceptable time to restore a service to operational status after a disruption |
| **Velero** | Kubernetes-native backup tool used for cluster state and persistent volume snapshots |
| **Offsite Backup** | A backup copy stored at a geographically separate location from the primary data center |

## 4. Policy Statements

### 4.1 RPO/RTO Targets

**PS-006.1**: Recovery objectives shall be defined per service tier:

| Tier | Services | RPO | RTO | Backup Frequency |
|------|----------|-----|-----|-------------------|
| **Tier 1 (Critical)** | PostgreSQL (CloudNativePG), OpenBao, Zitadel | 1 hour | 4 hours | Continuous WAL archiving + daily full |
| **Tier 2 (Important)** | MinIO, Harbor, Devtron, ArgoCD, n8n | 24 hours | 8 hours | Daily |
| **Tier 3 (Standard)** | Rocket.Chat, Outline, Grafana dashboards, Prometheus data | 24 hours | 24 hours | Daily |
| **Tier 4 (Recoverable)** | Stateless applications, cached data (Valkey) | N/A | 1 hour | Not backed up; rebuilt from Git/config |

### 4.2 Backup Schedule and Method

**PS-006.2**: Velero shall perform daily backups of all Kubernetes namespaces, including persistent volume snapshots, at 02:00 UTC. Backup jobs shall complete within the maintenance window (02:00-04:00 UTC).

**PS-006.3**: CloudNativePG shall be configured for continuous WAL (Write-Ahead Log) archiving to MinIO, enabling point-in-time recovery for Tier 1 databases. Full base backups shall run daily.

**PS-006.4**: Git repositories serve as the authoritative source of truth for all infrastructure-as-code, Helm values, and application configurations. Git hosting (GitHub) provides geographic redundancy. Local clones on cluster nodes provide an additional recovery path.

### 4.3 Encryption

**PS-006.5**: All backups shall be encrypted at rest using AES-256 before storage. Encryption keys shall be managed in OpenBao and shall not be stored on the same media as the backup data.

**PS-006.6**: All backup transfers to offsite storage (Backblaze B2) shall be encrypted in transit using TLS 1.3.

**PS-006.7**: Backblaze B2 buckets used for backup storage shall have S3 Object Lock enabled in Compliance Mode to prevent deletion or modification during the retention period.

### 4.4 Retention

**PS-006.8**: Backup retention periods shall be:

| Backup Type | Retention (On-site MinIO) | Retention (Offsite B2) |
|-------------|---------------------------|------------------------|
| Daily Velero snapshots | 30 days | 90 days |
| PostgreSQL WAL archives | 7 days | 30 days |
| PostgreSQL full backups | 30 days | 1 year |
| Monthly consolidated backup | 90 days | 7 years (HIPAA) |

**PS-006.9**: Backups containing data classified as Restricted (including PHI) shall be retained for a minimum of 7 years in compliance with HIPAA requirements and stored with Object Lock enabled.

### 4.5 Restore Testing

**PS-006.10**: Restore tests shall be performed quarterly using an isolated K3d test cluster. Each quarterly test shall verify:

1. Velero restore of at least one full namespace
2. PostgreSQL point-in-time recovery to a specified timestamp
3. Application functionality after restore (health checks, login, data integrity)
4. Restore completion within the defined RTO for the tested tier

**PS-006.11**: Restore test results shall be documented, including: test date, tester, backup used, restore time achieved, data integrity verification, and pass/fail determination. Results shall be archived as compliance evidence in MinIO.

**PS-006.12**: If a restore test fails, a corrective action shall be created in ClickUp (Folder 02: Platform Engineering) and remediated within 14 days. A re-test shall be performed after remediation.

### 4.6 Backup Monitoring

**PS-006.13**: Backup job success/failure shall be monitored via Prometheus. Failed backup jobs shall trigger a P2 alert to Rocket.Chat within 15 minutes. Two consecutive backup failures shall trigger a P1 alert.

**PS-006.14**: Backup storage utilization on MinIO and Backblaze B2 shall be monitored. Alerts shall fire when utilization exceeds 80% of allocated capacity.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Approves RPO/RTO targets; reviews quarterly restore test results; authorizes backup retention changes |
| **System Administrator** | Configures and monitors Velero, CloudNativePG backups, and offsite replication; executes restore tests; troubleshoots failures |
| **Security Lead** | Manages backup encryption keys in OpenBao; verifies Object Lock configuration; reviews backup access logs |
| **Compliance Lead** | Ensures backup retention meets regulatory requirements; archives restore test evidence |

## 6. Compliance & Enforcement

Failure to perform scheduled backups, disabling backup encryption, or neglecting quarterly restore testing constitutes a serious policy violation. Deletion or modification of backup data outside the documented retention policy requires CEO approval and constitutes a critical action.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. Backup exceptions additionally require documentation of the compensating recovery mechanism for the exempted system.

## 8. Related Documents

- Information Security Policy (POL-001)
- Data Classification Policy (POL-005)
- Business Continuity Policy (POL-010)
- Incident Response Policy (POL-004)
- Operational Runbook: Backup Verification and Restore Test

## 9. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial policy creation |

## 10. Approval

| Role | Name | Date |
|------|------|------|
| **Policy Owner** | Wakeem Williams, CEO | 2026-03-23 |
| **Approved By** | Wakeem Williams, CEO | 2026-03-23 |

---

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation) |
| **Policy ID** | POL-006 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
