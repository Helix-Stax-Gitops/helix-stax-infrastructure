# ADR-012: OpenSCAP + Lynis + AIDE Scanning Stack

## TLDR

Deploy a three-tool scanning stack on the host OS: OpenSCAP (weekly CIS L1 audit), Lynis (daily hardening index), AIDE (daily file integrity monitoring). All cron-based, all on-host.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax must continuously verify that host-level security controls remain in place and detect unauthorized changes to critical system files. SOC 2 CC7.2 requires ongoing monitoring, ISO 27001 A.8.8 requires vulnerability management, and HIPAA 164.312(b) requires audit controls. A single scanning tool cannot cover all three requirements:

1. **Configuration compliance**: Are CIS L1 controls still applied? (Drift detection against a known-good baseline)
2. **Hardening posture**: What is the overall security posture of the host? (Holistic assessment beyond a single benchmark)
3. **File integrity**: Have any critical system files been modified unexpectedly? (Tamper detection)

OpenSCAP evaluates against formal SCAP profiles and produces ARF/XCCDF reports accepted by auditors. Lynis provides a broader hardening assessment with a numeric "Hardening Index" useful for trending. AIDE detects unauthorized file changes at the filesystem level. Each tool serves a distinct purpose with minimal overlap.

All three tools run on the host OS via cron, not inside K3s. K3s workloads are ephemeral and pod-level scanning is handled by NeuVector (ADR-009). Host-level scanning targets the persistent OS layer that K3s runs on.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: OpenSCAP + Lynis + AIDE | Three complementary tools, cron-based | Complete coverage (compliance + posture + FIM), auditor-accepted | Three tools to maintain, potential alert fatigue | Full SOC 2, ISO 27001, HIPAA coverage |
| **Option B**: OpenSCAP only | Single compliance scanner | Simplest, strong audit reports | No FIM, no holistic posture scoring | Partial -- misses integrity monitoring |
| **Option C**: Lynis only | Single hardening assessor | Broad coverage, easy scoring | Not formally SCAP-compliant, no FIM | Weak -- not accepted as formal audit evidence |
| **Option D**: Commercial scanner (Qualys, Nessus) | Managed vulnerability scanning | Professional reports, support | Cost, external dependency, agent overhead | Strong but expensive |

---

## Decision

We will deploy three scanning tools on each AlmaLinux host, each serving a distinct function:

**OpenSCAP (Weekly):**
- Profile: `xccdf_org.ssgproject.content_profile_cis_server_l1`
- Tailoring file: `/etc/security/scap/helix-stax-k3s-tailoring.xml` (K3s exceptions documented)
- Output: ARF XML + XCCDF HTML reports
- Storage: SHA-256 hashed, archived to MinIO (ADR-013)
- Schedule: Weekly (Sunday 02:00 UTC)

```bash
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-$(date +%F).xml \
  --report /var/log/compliance/report-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml
```

**Lynis (Daily):**
- Generates Hardening Index score (0-100)
- Score scraped and pushed to Prometheus for Grafana trending
- Alerts on score drops exceeding threshold (>5 points)
- Schedule: Daily (03:00 UTC)

**AIDE (Daily):**
- File integrity monitoring for critical system files
- K3s exclusions configured to prevent false positives:
  - `/var/lib/rancher/k3s/agent/containerd/` (container runtime)
  - `/var/lib/rancher/k3s/data/` (K3s data)
  - `/var/log/containers/`, `/var/log/pods/` (container logs)
  - `/run/k3s/`, `/run/containerd/`, `/run/flannel/` (runtime state)
- Critical paths monitored with `NORMAL` checks: `/usr/local/bin/k3s`
- Permission-only monitoring for: `/etc/rancher/k3s/config.yaml`, TLS certificates
- Schedule: Daily (04:00 UTC)

**Auto-remediation policy:**
- Deterministic, low-risk controls (file permissions): auto-remediate
- Complex state changes (kernel params, firewall, services): alert-only, human review required

---

## Rationale

Each tool addresses a distinct compliance requirement that the others cannot satisfy. OpenSCAP produces the formal ARF/XCCDF reports that auditors universally accept as evidence of CIS compliance. Lynis provides a holistic hardening index that enables posture trending over time -- a metric auditors value for demonstrating continuous improvement. AIDE detects unauthorized file modifications that neither OpenSCAP nor Lynis are designed to catch. Running on the host (not in K3s) ensures the scanning tools cannot be influenced by a compromised container or orchestrator.

---

## Consequences

### Positive

- Three distinct compliance signals: benchmark compliance, posture score, file integrity
- OpenSCAP ARF reports are universally accepted by SOC 2 and ISO 27001 auditors
- Lynis Hardening Index provides trendable metric for Grafana dashboards
- AIDE catches unauthorized changes that configuration scanners miss
- K3s exclusions prevent false positives from ephemeral container activity
- All results hashable and archivable for immutable evidence (ADR-013)

### Negative

- Three cron jobs generating daily/weekly output -- requires log rotation and storage management
- AIDE database must be rebased after legitimate system changes (package updates, config changes)
- Initial AIDE baseline build may take significant time on first run
- False positive management across three tools requires ongoing tuning
- Scanning during business hours could impact K3s workload performance (mitigated by off-hours scheduling)

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Install OpenSCAP + scap-security-guide on both nodes | Wakeem Williams | 2026-04-13 | TBD |
| Create OpenSCAP tailoring file with K3s exceptions | Wakeem Williams | 2026-04-13 | TBD |
| Install and configure Lynis with Prometheus exporter | Wakeem Williams | 2026-04-13 | TBD |
| Install AIDE and build initial baseline database | Wakeem Williams | 2026-04-20 | TBD |
| Configure AIDE K3s exclusions | Wakeem Williams | 2026-04-20 | TBD |
| Create cron jobs for all three scanners | Wakeem Williams | 2026-04-20 | TBD |
| Create Grafana dashboard for Lynis Hardening Index | Wakeem Williams | 2026-04-27 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| AlmaLinux hosts | Three scanning tools installed and cron-scheduled |
| Prometheus | Lynis Hardening Index metric ingested |
| Grafana | Dashboard for compliance posture trending |
| MinIO | Scan results archived with immutable storage (ADR-013) |
| n8n | Alert routing for scan failures and AIDE changes |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC7.2 | System monitoring | Three-tool continuous monitoring stack |
| SOC 2 | CC6.3 | Logical access / secure configuration | OpenSCAP verifies CIS L1 compliance weekly |
| ISO 27001 | A.8.8 | Management of technical vulnerabilities | OpenSCAP detects configuration drift from baseline |
| ISO 27001 | A.8.15 | Logging | All scan results logged and archived |
| NIST CSF 2.0 | DE.CM-1 | Networks and systems monitored | Daily + weekly automated scanning |
| NIST CSF 2.0 | DE.CM-8 | Vulnerability scans performed | OpenSCAP + Lynis provide complementary scanning |
| HIPAA | 164.312(b) | Audit controls | AIDE file integrity + OpenSCAP audit trails |
| CIS Controls v8.1 | 4.1 | Secure configuration process | OpenSCAP validates CIS Benchmark compliance |
| CIS Controls v8.1 | 8.1 | Audit log management | Scan results hashed and archived |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
