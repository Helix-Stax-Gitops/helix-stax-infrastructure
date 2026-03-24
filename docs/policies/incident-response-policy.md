---
title: "Incident Response Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-004"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC7.3", "CC7.4", "CC7.5"]
  - framework: "ISO 27001"
    controls: ["A.5.24", "A.5.25", "A.5.26", "A.5.27", "A.6.8"]
  - framework: "HIPAA"
    controls: ["164.308(a)(6)(i)", "164.308(a)(6)(ii)", "164.410", "164.414"]
  - framework: "NIST CSF"
    controls: ["RS.RP-1", "RS.CO-2", "RS.AN-1", "RS.MI-1", "RC.RP-1"]
---

# Incident Response Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Incident Response Policy defines how Helix Stax detects, contains, eradicates, recovers from, and learns from security incidents. Follows NIST 800-61 methodology. Includes HIPAA breach notification requirements (60-day window). Required by SOC 2 CC7.4, ISO 27001 A.5.24, HIPAA 164.308(a)(6). Approved by CEO.

---

## 1. Purpose

This policy establishes the procedures for identifying, responding to, and recovering from information security incidents. It ensures timely containment of threats, preservation of forensic evidence, compliance with breach notification obligations, and continuous improvement through lessons learned.

## 2. Scope

This policy applies to all security incidents affecting:

- Helix Stax infrastructure (K3s cluster, Hetzner Cloud nodes, Cloudflare edge)
- All applications and services deployed on the platform
- All data processed, stored, or transmitted by Helix Stax systems
- Client environments managed under the Delivery workspace
- Third-party services integrated with Helix Stax systems

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Security Incident** | An event that actually or potentially compromises the confidentiality, integrity, or availability of an information asset |
| **Security Event** | An observable occurrence relevant to security (e.g., a failed login) that does not necessarily constitute an incident |
| **Breach** | A confirmed incident involving unauthorized access to or disclosure of protected data, including Protected Health Information (PHI) |
| **Indicator of Compromise (IOC)** | A forensic artifact that indicates a system has been compromised (e.g., malicious IP, file hash, unusual process) |
| **Evidence Preservation** | The process of securing and documenting forensic evidence in a manner that maintains its integrity for investigation |

## 4. Policy Statements

### 4.1 Incident Classification

**PS-004.1**: All security incidents shall be classified using the following severity levels:

| Severity | Criteria | Response Time | Example |
|----------|----------|--------------|---------|
| **Critical (P1)** | Active data breach; complete service outage; credential compromise | Immediate (within 15 minutes) | Unauthorized database access; cluster-wide outage; leaked API keys |
| **High (P2)** | Partial service degradation; attempted intrusion detected; vulnerability actively exploited | Within 1 hour | DDoS attack; failed brute-force attempts exceeding threshold; CVE with known exploit |
| **Medium (P3)** | Suspicious activity; policy violation detected; non-critical vulnerability | Within 4 hours | Anomalous login patterns; unauthorized configuration change; medium-severity CVE |
| **Low (P4)** | Informational security event; minor policy deviation | Within 24 hours | Single failed login; misconfigured non-production resource |

### 4.2 Detection

**PS-004.2**: Incident detection shall be supported by the following monitoring systems:

- CrowdSec for host-level and Traefik-level intrusion detection
- Prometheus/Alertmanager for infrastructure and application anomalies
- Loki for centralized log aggregation and correlation
- AIDE for file integrity monitoring on cluster nodes
- Kubernetes audit logs for API server activity
- Cloudflare security event logs

**PS-004.3**: All detection alerts for P1 and P2 events shall be delivered to Rocket.Chat within 5 minutes of detection. Alert fatigue shall be managed by tuning thresholds quarterly.

### 4.3 Containment

**PS-004.4**: Upon confirming a P1 or P2 incident, the following containment actions shall be executed:

1. **Network isolation**: Execute `firewall-cmd --panic-on` on affected nodes to sever all connections if lateral movement is suspected
2. **Account lockout**: Disable compromised accounts in Zitadel immediately
3. **Workload isolation**: Cordon and drain affected Kubernetes nodes (`kubectl cordon`, `kubectl drain`)
4. **Preserve state**: Capture a Hetzner snapshot of affected nodes via API before any remediation changes

**PS-004.5**: Containment actions shall be documented in real-time in a dedicated Rocket.Chat incident channel created for each P1/P2 incident.

### 4.4 Eradication and Recovery

**PS-004.6**: Eradication shall address the root cause, not just symptoms. Actions include: patching exploited vulnerabilities, rotating all potentially compromised credentials, removing malicious artifacts, and hardening the attack vector.

**PS-004.7**: Recovery shall restore services using known-good configurations from Git (GitOps) and verified backups (Velero). Systems shall not be restored from potentially compromised state.

**PS-004.8**: Before returning a recovered system to production, a security verification shall confirm: patches applied, credentials rotated, monitoring re-enabled, and no residual IOCs detected.

### 4.5 Evidence Preservation

**PS-004.9**: Forensic evidence shall be preserved for all P1 and P2 incidents:

- Hetzner snapshots of affected nodes captured before remediation
- Memory dumps acquired using AVML where applicable
- Relevant logs exported from Loki and archived to MinIO with S3 Object Lock (Compliance Mode)
- All evidence artifacts shall be SHA-256 hashed and the hash recorded in the incident record
- Evidence shall be retained for a minimum of 7 years for HIPAA-related incidents and 1 year for all other incidents

### 4.6 Breach Notification (HIPAA)

**PS-004.10**: If an incident involves confirmed unauthorized access to Protected Health Information (PHI):

1. Notify affected individuals within 60 days of breach discovery
2. Notify the HHS Secretary via the HHS breach portal
3. If the breach affects 500+ individuals, notify prominent media outlets in the affected jurisdiction
4. Document the breach notification in the incident record with dates, recipients, and content of notifications

**PS-004.11**: A breach risk assessment shall be performed using the four-factor test defined in 45 CFR 164.402: (1) nature and extent of PHI involved, (2) unauthorized person who accessed/used the PHI, (3) whether PHI was actually acquired or viewed, (4) extent to which risk has been mitigated.

### 4.7 Post-Incident Review

**PS-004.12**: A post-incident review (lessons learned) shall be conducted within 5 business days of incident closure for P1/P2 incidents and within 10 business days for P3 incidents. The review shall document: timeline, root cause, actions taken, what worked, what did not, and corrective actions.

**PS-004.13**: Corrective actions from post-incident reviews shall be tracked as tasks in ClickUp (Folder 03: Security Operations) with assigned owners and due dates.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Incident Commander for P1 incidents; authorizes breach notifications; approves external communications; final authority on containment decisions |
| **Security Lead** | Leads incident response for P2-P4; performs forensic analysis; preserves evidence; conducts post-incident reviews |
| **System Administrator** | Executes containment and recovery actions; implements patches; restores services from GitOps/backups |
| **Compliance Lead** | Manages breach notification process; coordinates with legal counsel; updates risk register |
| **All Personnel** | Report suspected incidents immediately to Security Lead; do not attempt independent remediation |

## 6. Compliance & Enforcement

Failure to report a suspected security incident within the timeframes defined in this policy constitutes a serious policy violation. Intentional concealment of a security incident constitutes a critical policy violation.

## 7. Exceptions Process

No exceptions are permitted for incident reporting obligations or HIPAA breach notification requirements. Exceptions to specific containment procedures may be granted by the CEO during an active incident, documented in the incident record.

## 8. Related Documents

- Information Security Policy (POL-001)
- Data Classification Policy (POL-005)
- Backup & Recovery Policy (POL-006)
- Business Continuity Policy (POL-010)
- NIST SP 800-61 Rev. 2: Computer Security Incident Handling Guide
- `docs/runbooks/` -- Incident Response runbooks

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
| **Policy ID** | POL-004 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
