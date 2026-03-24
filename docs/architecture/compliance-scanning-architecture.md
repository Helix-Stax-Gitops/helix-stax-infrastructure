---
title: Compliance Scanning Architecture
author: Wakeem Williams
co_author: Quinn Mercer
date: 2026-03-23
status: Active
version: "1.0"
compliance_frameworks:
  - SOC 2 (CC7.1, CC7.2, CC8.1)
  - ISO 27001:2022 (A.8.8, A.8.15, A.8.34)
  - NIST CSF 2.0 (DE.CM-1, DE.CM-3, DE.CM-8)
  - CIS Controls v8.1 (4.1, 8.1)
  - HIPAA (164.308(a)(8), 164.312(b))
references:
  - ADR-002 (CIS L1 over STIG)
  - ADR-012 (Scanning stack)
  - ADR-013 (Immutable evidence archival)
  - docs/architecture/dual-workflow-architecture.md
---

# Compliance Scanning Architecture

## 1. Overview

Automated compliance scanning provides continuous assurance that the Helix Stax infrastructure remains hardened and drift-free. Three tools operate in concert: OpenSCAP for benchmark compliance, Lynis for hardening scoring, and AIDE for file integrity monitoring. All scan results are hashed, archived immutably, and surfaced through dashboards and alerts.

---

## 2. Scanning Stack

| Tool | Purpose | Output Format | Frequency | Target |
|------|---------|---------------|-----------|--------|
| OpenSCAP | CIS L1 benchmark compliance | ARF XML + XCCDF HTML | Weekly | Both nodes |
| Lynis | Hardening index scoring | JSON + text report | Daily | Both nodes |
| AIDE | File integrity monitoring | Text diff report | Daily | Both nodes |
| Ansible --check --diff | Configuration drift detection | Ansible diff output | Daily | Both nodes |
| kube-bench | CIS Kubernetes Benchmark | JSON report | Weekly | K3s cluster |

---

## 3. OpenSCAP Configuration

### 3.1 Profile Selection

**Primary profile**: CIS Benchmark Level 1 - Server
```
Profile ID: xccdf_org.ssgproject.content_profile_cis_server_l1
Content:    /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

**Selective Level 2 adoptions** (documented in tailoring file):
- IPv6 disabled at kernel level
- auditd configuration immutability (-e 2)
- Obscure network protocols blacklisted (DCCP, SCTP, RDS)

### 3.2 K3s Tailoring File

The tailoring file (`/etc/security/scap/helix-stax-k3s-tailoring.xml`) documents all control exceptions required for K3s operation. This file is version-controlled in the infra repo.

**Excepted controls**:
| Control | Rule ID | Reason |
|---------|---------|--------|
| IPv4 forwarding | rhel9cis_rule_3_1_1 | Required for pod networking |
| Packet routing | rhel9cis_rule_3_1_2 | Required for CNI |
| ICMP redirects | rhel9cis_rule_3_2_2 | Required for Flannel |
| Firewalld forward chains | -- | K3s manages iptables rules dynamically |
| br_netfilter module | -- | Required for bridge networking |
| overlay module | -- | Required for containerd |

### 3.3 Scan Command

```bash
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-$(date +%F).xml \
  --report /var/log/compliance/report-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

### 3.4 Auditor Acceptance

OpenSCAP ARF XML and XCCDF HTML reports are universally accepted by SOC 2 and ISO 27001 auditors as definitive compliance evidence. The tailoring file provides auditors with explicit documentation of why each exception exists.

---

## 4. Lynis Configuration

### 4.1 Hardening Index

Lynis produces a numerical "Hardening Index" (0-100) that serves as a quick health indicator.

| Score Range | Status | Action |
|-------------|--------|--------|
| 85-100 | Excellent | No action |
| 70-84 | Good | Review suggestions |
| 50-69 | Fair | Remediation required |
| 0-49 | Critical | Immediate remediation |

**Target score**: 85+ on both nodes.

### 4.2 Scan Command

```bash
lynis audit system --quick --no-colors \
  --report-file /var/log/compliance/lynis-report-$(date +%F).dat \
  --log-file /var/log/compliance/lynis-$(date +%F).log
```

### 4.3 Prometheus Integration

The Lynis hardening index is scraped by a custom exporter and pushed to Prometheus for dashboard display in Grafana.

```
lynis_hardening_index{node="helix-stax-cp"} 87
lynis_hardening_index{node="helix-stax-vps"} 85
```

---

## 5. AIDE Configuration

### 5.1 K3s Exclusions

AIDE must exclude K3s dynamic paths to avoid false positives on every scan.

```
# /etc/aide.conf -- K3s exclusions

# Exclude containerd overlay mounts (change constantly)
!/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs
!/var/lib/rancher/k3s/data

# Exclude container/pod logs (rotated by kubelet)
!/var/log/containers
!/var/log/pods

# Exclude runtime state directories
!/run/k3s
!/run/containerd
!/run/flannel

# Monitor K3s binaries and config (detect tampering)
/usr/local/bin/k3s NORMAL
/etc/rancher/k3s/config.yaml PERMS
/var/lib/rancher/k3s/server/tls/*.crt PERMS
```

### 5.2 Scan Command

```bash
aide --check --config=/etc/aide.conf \
  --report=file:/var/log/compliance/aide-$(date +%F).txt
```

### 5.3 Alert Thresholds

| Change Type | Alert Level | Action |
|-------------|-------------|--------|
| System binary modified | CRITICAL | Immediate investigation |
| Config file permission change | HIGH | Review within 4 hours |
| New file in monitored directory | MEDIUM | Review within 24 hours |
| K3s TLS cert permission change | CRITICAL | Immediate investigation |

---

## 6. Scanning Cadence Table

```
+--------+---+---+---+---+---+---+---+
| Tool   | M | T | W | T | F | S | S |
+--------+---+---+---+---+---+---+---+
| Lynis  | x | x | x | x | x | x | x |  Daily 02:00 UTC
| AIDE   | x | x | x | x | x | x | x |  Daily 03:00 UTC
| Ansible| x | x | x | x | x | x | x |  Daily 04:00 UTC
| OpenSC |   |   |   |   |   |   | x |  Weekly Sunday 01:00 UTC
| kube-b |   |   |   |   |   |   | x |  Weekly Sunday 02:00 UTC
+--------+---+---+---+---+---+---+---+

Scans are staggered to avoid resource contention.
All times are UTC to avoid DST complications.
```

---

## 7. Evidence Pipeline

### 7.1 Architecture

```
+------------+     +------------+     +------------+     +------------+
|  Scanner   | --> |  Hash      | --> |  MinIO     | --> |  Grafana   |
|  (host)    |     |  (SHA-256) |     |  (Object   |     |  Dashboard |
|            |     |            |     |   Lock)    |     |            |
+------------+     +------------+     +------------+     +------------+
     |                                      |
     |  Scan result file                    |  Immutable evidence
     v                                      v
+------------+                       +------------+
|  Airflow   |                       |  Auditor   |
|  DAG       |                       |  Access    |
|  (trigger) |                       |  (pre-signed URLs)
+------------+                       +------------+
```

### 7.2 Evidence Flow (Step by Step)

```
1. SCAN
   Airflow DAG triggers scan on target node via SSH:
     - OpenSCAP: oscap xccdf eval ... -> ARF XML + HTML report
     - Lynis: lynis audit system -> report .dat + .log
     - AIDE: aide --check -> diff report
       |
       v
2. HASH
   Airflow task computes SHA-256 hash of each output file:
     sha256sum /var/log/compliance/arf-results-2026-03-23.xml
     -> a1b2c3d4...  arf-results-2026-03-23.xml
       |
       v
3. ARCHIVE
   Airflow task uploads to MinIO evidence bucket:
     Bucket: compliance-evidence
     Path: /{year}/{month}/{tool}/{hostname}/{filename}
     Object Lock: COMPLIANCE mode, 7-year retention
     Metadata: SHA-256 hash, scan timestamp, node, tool version
       |
       v
4. INDEX
   Airflow task writes scan metadata to PostgreSQL:
     - scan_id, timestamp, node, tool, result_summary
     - pass/fail counts, score (Lynis), drift items (AIDE)
       |
       v
5. DASHBOARD
   Grafana queries PostgreSQL for scan history:
     - Compliance score trend (Lynis hardening index)
     - OpenSCAP pass/fail ratio over time
     - AIDE drift events timeline
     - kube-bench CIS score
       |
       v
6. ALERT (on failure/drift)
   Airflow on_failure_callback -> n8n webhook:
     -> Rocket.Chat #compliance-alerts
     -> ClickUp task (if remediation needed)
```

### 7.3 MinIO Object Lock Configuration

```
Bucket:         compliance-evidence
Versioning:     Enabled (required for Object Lock)
Object Lock:    COMPLIANCE mode
Retention:      7 years (HIPAA maximum)
Access:         Read-only for auditors (pre-signed URLs, 24h expiry)
Replication:    Backblaze B2 (offsite copy)
```

**Compliance mode** means: even the MinIO root user cannot delete or modify objects during the retention period. This satisfies HIPAA 164.312(b) and SOC 2 CC7.2 requirements for tamper-evident audit trails.

---

## 8. Drift Detection Strategy

Three independent drift detection mechanisms ensure no unauthorized changes go unnoticed.

### 8.1 Comparison Matrix

| Mechanism | What It Detects | Scope | Frequency |
|-----------|----------------|-------|-----------|
| OpenSCAP | CIS benchmark deviations | OS configuration | Weekly |
| Ansible --check --diff | Configuration file changes vs desired state | All managed configs | Daily |
| AIDE | File additions, modifications, deletions | File system integrity | Daily |

### 8.2 How They Complement Each Other

```
OpenSCAP: "Is the system compliant with CIS L1?"
  - Broad benchmark check (200+ controls)
  - Catches systemic misconfigurations
  - Weekly cadence is sufficient (benchmarks don't change daily)

Ansible --check --diff: "Has anything changed from our declared state?"
  - Compares current state to Ansible playbook definitions
  - Catches manual changes (someone ran a command outside IaC)
  - Daily cadence catches drift within 24 hours

AIDE: "Have any files been modified, added, or deleted?"
  - Binary-level integrity verification (checksums)
  - Catches rootkits, unauthorized binary replacements, config tampering
  - Daily cadence with immediate alerting on critical paths
```

### 8.3 Auto-Remediation Policy

| Drift Type | Action | Rationale |
|------------|--------|-----------|
| File permissions (non-critical) | Auto-remediate | Deterministic, low risk |
| Package version drift | Alert only | May break running services |
| Kernel parameters | Alert only | Reboot may be required |
| Firewall rules | Alert only | May disrupt K3s networking |
| Service configuration | Alert only | Requires context-aware decision |
| Binary modification | HALT + investigate | Potential compromise indicator |

**Rule**: Only deterministic, low-risk controls are auto-remediated. Complex state changes (kernel params, firewall, services) generate alerts for human review.

---

## 9. Alert Pipeline

### 9.1 Architecture

```
+------------+     +------------+     +------------------+
|  Drift     | --> |  Airflow   | --> |  n8n webhook     |
|  detected  |     |  callback  |     |  /drift-alert    |
+------------+     +------------+     +------------------+
                                             |
                         +-------------------+-------------------+
                         |                                       |
                         v                                       v
                  +------------------+                  +------------------+
                  |  Rocket.Chat     |                  |  ClickUp         |
                  |  #compliance     |                  |  Security Ops    |
                  |  -alerts         |                  |  (task created)  |
                  +------------------+                  +------------------+
```

### 9.2 Alert Severity Routing

| Severity | Rocket.Chat Channel | ClickUp Action | Response SLA |
|----------|---------------------|----------------|--------------|
| CRITICAL | #incident-response | Task + @mention | 1 hour |
| HIGH | #compliance-alerts | Task created | 4 hours |
| MEDIUM | #compliance-alerts | Task created | 24 hours |
| LOW | #infra-digest (weekly) | No task | Next review |

---

## 10. Compliance Mapping

| Scanning Control | SOC 2 | ISO 27001 | NIST CSF | CIS v8.1 | HIPAA |
|-----------------|-------|-----------|----------|----------|-------|
| Weekly CIS benchmark scan | CC7.1 | A.8.8 | DE.CM-8 | 4.1 | 164.308(a)(8) |
| Daily hardening index | CC7.2 | A.8.34 | DE.CM-3 | 4.1 | 164.308(a)(8) |
| Daily file integrity monitoring | CC7.2 | A.8.15 | DE.CM-3 | 8.1 | 164.312(b) |
| Immutable evidence archival | CC8.1 | A.8.15 | DE.CM-3 | 8.11 | 164.312(b) |
| Automated drift alerting | CC7.2 | A.8.16 | DE.CM-1 | 8.2 | 164.308(a)(1) |
| Configuration-as-code (Ansible) | CC8.1 | A.8.9 | PR.IP-1 | 4.1 | 164.312(a)(1) |

---

## 11. Related Documents

| Document | Relevance |
|----------|-----------|
| [dual-workflow-architecture.md](dual-workflow-architecture.md) | Airflow DAGs that orchestrate scanning |
| [defense-in-depth-architecture.md](defense-in-depth-architecture.md) | Layer 2 controls verified by scanning |
| [infrastructure-buildout-master-plan.md](infrastructure-buildout-master-plan.md) | Scanning deployed in Phase 2, evidence pipeline in Phase 5 |
| [secrets-lifecycle-architecture.md](secrets-lifecycle-architecture.md) | Evidence hashing and archival in MinIO |
