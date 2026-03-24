# ADR-013: Immutable Evidence Archival

## TLDR

Archive all compliance evidence to MinIO S3 Object Lock (Compliance Mode) with SHA-256 hashes committed separately, providing tamper-evident chain of custody for 7-year HIPAA and 1-year SOC 2 retention.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax generates compliance evidence continuously: OpenSCAP ARF reports, Lynis assessments, AIDE integrity checks, Airflow task logs, CrowdSec detection logs, Velero backup verification results, and audit trails from all infrastructure components. Auditors for SOC 2, ISO 27001, and HIPAA require this evidence to be:

1. **Immutable**: Evidence cannot be retroactively modified or deleted
2. **Verifiable**: Integrity of each artifact can be independently confirmed
3. **Retained**: Evidence preserved for the required retention period (7 years for HIPAA, 1 year minimum for SOC 2)
4. **Accessible**: Evidence can be retrieved on demand during audits

Standard file storage (local disk, regular S3 buckets) does not satisfy immutability -- files can be overwritten or deleted. Cloud-managed WORM (Write Once Read Many) storage is available from AWS S3 Glacier but introduces external dependency. MinIO, already deployed in the Helix Stax stack, supports S3 Object Lock in Compliance Mode -- objects cannot be overwritten or deleted until the retention period expires, even by the root user.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: MinIO S3 Object Lock (Compliance) | Self-hosted WORM storage with hash verification | No external dependency, compliant with retention requirements, self-hosted | Depends on MinIO uptime, storage capacity planning needed | Satisfies SOC 2, ISO 27001, HIPAA retention |
| **Option B**: AWS S3 Glacier | Cloud WORM storage | Highly durable, managed service | External dependency, cost per GB, data sovereignty | Strong retention, external dependency |
| **Option C**: Local filesystem with permissions | Read-only files on host disk | Simplest approach | Root can still modify, no retention enforcement, disk failure = data loss | Fails immutability requirement |
| **Option D**: Blockchain-based notarization | Hash anchoring to public blockchain | Strongest tamper evidence | Overkill, cost, complexity, latency | Exceeds requirements |

---

## Decision

We will archive all compliance evidence to MinIO using S3 Object Lock in Compliance Mode, with SHA-256 hashes committed to a separate verification chain.

**Architecture:**

```
Evidence generated (OpenSCAP, Lynis, AIDE, Airflow, etc.)
  |
  +-- SHA-256 hash computed
  |     |
  |     +-- Hash committed to evidence-hashes Git repo (immutable Git history)
  |     +-- Hash stored as MinIO object metadata
  |
  +-- Object uploaded to MinIO with Object Lock
        |
        +-- Compliance Mode (cannot be deleted/overwritten)
        +-- Retention: 7 years (HIPAA bucket) or 1 year (SOC 2 bucket)
```

**MinIO bucket configuration:**

| Bucket | Purpose | Retention | Object Lock Mode |
|--------|---------|-----------|------------------|
| `evidence-hipaa` | Evidence for HIPAA-covered engagements | 7 years | Compliance |
| `evidence-soc2` | General compliance evidence | 1 year | Compliance |
| `evidence-iso27001` | ISO-specific evidence | 3 years (certification cycle) | Compliance |

**Hash verification chain:**
- Every uploaded object has its SHA-256 hash computed before upload
- Hash stored as custom metadata on the MinIO object (`x-amz-meta-sha256`)
- Hash also committed to a dedicated Git repository (`evidence-hashes`)
- Two independent records of each hash -- MinIO metadata and Git history
- Verification: download object, recompute hash, compare against both records

**Evidence naming convention:**
```
{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}.{ext}
Example: CC7.2_openscap-arf_2026-03-23_v1.xml
```

**Encryption:**
- MinIO SSE-KMS via OpenBao for encryption at rest (ADR-006)
- LUKS provides underlying disk encryption (ADR-005)
- Double encryption: LUKS (disk) + SSE-KMS (object)

---

## Rationale

MinIO S3 Object Lock in Compliance Mode provides WORM semantics that satisfy all three frameworks' retention requirements. Compliance Mode is stronger than Governance Mode -- even the MinIO root user cannot delete objects before retention expires. The dual-hash approach (MinIO metadata + Git commits) creates a tamper-evident chain: if an object is modified, its hash will not match either record. Using self-hosted MinIO avoids external cloud dependency while providing the same S3-compatible WORM interface that auditors expect. The separate Git repository for hashes provides an independent verification path that does not depend on MinIO's integrity.

---

## Consequences

### Positive

- True WORM storage -- objects cannot be deleted even by administrators
- Tamper-evident via dual SHA-256 verification (MinIO metadata + Git history)
- Self-hosted -- no external cloud dependency for evidence storage
- S3-compatible API -- standard tooling works (aws-cli, mc, s3cmd)
- Retention periods enforced by MinIO, not by policy alone
- Evidence naming convention enables automated retrieval during audits
- SSE-KMS encryption satisfies data-at-rest requirements

### Negative

- Storage capacity must be planned -- objects accumulate and cannot be deleted early
- 7-year HIPAA retention requires significant storage over time (mitigated by compression)
- MinIO must remain operational for evidence access -- backup to Backblaze B2 provides offsite copy
- Compliance Mode Object Lock cannot be shortened after creation -- incorrect retention is permanent
- Hash Git repository grows linearly with evidence volume

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Create MinIO buckets with Object Lock enabled | Wakeem Williams | 2026-04-27 | TBD |
| Configure retention policies per bucket | Wakeem Williams | 2026-04-27 | TBD |
| Create evidence-hashes Git repository | Wakeem Williams | 2026-04-27 | TBD |
| Build evidence upload script (hash + upload + Git commit) | Wakeem Williams | 2026-05-04 | TBD |
| Integrate with Airflow DAGs for automated archival | Wakeem Williams | 2026-05-04 | TBD |
| Configure Backblaze B2 replication for offsite backup | Wakeem Williams | 2026-05-11 | TBD |
| Estimate storage capacity for 7-year retention | Wakeem Williams | 2026-05-04 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| MinIO | Object Lock enabled, new evidence buckets created |
| OpenBao | SSE-KMS key for evidence encryption |
| Airflow | DAGs modified to upload evidence after scanning tasks |
| Git (evidence-hashes repo) | New repository for hash verification chain |
| Backblaze B2 | Offsite replication target for evidence buckets |
| OpenSCAP / Lynis / AIDE | Scan outputs routed to evidence archival pipeline |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC7.2 | System monitoring | Evidence of monitoring activities preserved immutably |
| SOC 2 | CC7.3 | Evaluate security events | Archived evidence supports event evaluation |
| ISO 27001 | A.8.10 | Information deletion | Object Lock prevents premature deletion |
| ISO 27001 | A.8.15 | Logging | Immutable log archival with integrity verification |
| NIST CSF 2.0 | PR.DS-1 | Data-at-rest protected | SSE-KMS + LUKS double encryption |
| NIST CSF 2.0 | DE.AE-3 | Event data aggregated and correlated | Centralized evidence repository enables correlation |
| HIPAA | 164.312(b) | Audit controls | 7-year retention satisfies HIPAA audit trail requirements |
| HIPAA | 164.312(c)(1) | Integrity controls | SHA-256 hashes provide integrity verification |
| CIS Controls v8.1 | 8.1 | Establish audit log management process | Immutable archival with retention enforcement |
| CIS Controls v8.1 | 3.11 | Encrypt sensitive data at rest | SSE-KMS encryption for all evidence objects |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
