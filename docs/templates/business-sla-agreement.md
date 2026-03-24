---
template: business-sla-agreement
category: business
task_type: sla
clickup_list: 04 Service Management > SLAs
auto_tags: [sla, support, client-facing, service-management]
required_fields: [Service Description, SLOs, Response Times, Escalation Policy, Credits/Remedies]
classification: client-facing
compliance_frameworks: [SOC2, ISO27001]
review_cycle: annually
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Service Level Agreement (SLA)

Use this template when defining service-level commitments for managed services, support retainers, or platform SLAs. File in ClickUp under 01 Platform > Service Management and share with clients who receive ongoing support or managed services.

## TLDR

A Service Level Agreement (SLA) defines the minimum acceptable performance standards, response times, uptime targets, and escalation procedures for managed services. SLAs include what happens when targets are missed (service credits or remediation). Critical for Tier-1 managed service engagements. Must be paired with an SOW that defines the full scope.

---

## 1. Service Overview

### 1.1 Service Description

**[REQUIRED]** What service is being provided under this SLA?

Example: "Helix Stax will provide 24/7 managed support for the Client's Kubernetes cluster running on Hetzner Cloud, including incident response, patch management, performance optimization, and security monitoring."

### 1.2 Service Hours

**[REQUIRED]** When is support available?

- **Standard Support**: Monday–Friday, 8 AM–6 PM US Eastern (excluding US federal holidays)
- **24/7 Support**: Available all days, all hours, including holidays

### 1.3 Escalation Contact

**[REQUIRED]** How does the Client reach Helix Stax?

| Severity | Primary Channel | Response Time | Secondary Channel |
|----------|-----------------|----------------|--------------------|
| **SEV-1 (Critical)** | Phone: [Number] + Slack: #incidents | 15 minutes | Email: [Email] |
| **SEV-2 (High)** | Slack: #incidents or email | 1 hour | Phone during business hours |
| **SEV-3 (Medium)** | Email or ClickUp | 4 hours | Next business day phone |
| **SEV-4 (Low)** | ClickUp task or email | 24 hours | Next available weekly review |

---

## 2. Service Level Objectives (SLOs)

**[REQUIRED]** Specific, measurable targets that define what "good" looks like.

### 2.1 Availability & Uptime

| Service Component | Target Uptime | Maximum Downtime/Month | Measurement |
|-------------------|---------------|------------------------|-------------|
| **Kubernetes API Server** | 99.9% | 43 minutes | Prometheus heartbeat from external probe |
| **Application Ingress** | 99.5% | 3.6 hours | HTTP GET from [URL] every 60 seconds |
| **Database (PostgreSQL)** | 99.9% | 43 minutes | Connection pool test every 10 seconds |
| **Identity Provider (Zitadel)** | 99.5% | 3.6 hours | Login flow test every 5 minutes |
| **Backup System** | Daily successful backup | 1 missed backup/month | Velero backup job log verification |

**Exclusions from Uptime Calculation** (do not count against SLO):
- Scheduled maintenance windows (max 4 hours/month, 24 hours' notice)
- Client-initiated actions (e.g., stopping the cluster)
- Third-party failures (e.g., Hetzner Cloud outage, BGP hijacking)
- DDoS attacks exceeding [Capacity]

### 2.2 Performance Targets

| Metric | Target | Measurement | Reporting Frequency |
|--------|--------|-------------|---------------------|
| **API Latency** (p95) | < 500ms | Monitor via Prometheus | Weekly report |
| **Pod Startup Time** | < 30 seconds | Average across all app pods | Weekly report |
| **Log Ingestion Latency** | < 5 seconds | Time from log generation to Loki | Weekly report |
| **Backup Completion Time** | < 1 hour | Velero job duration | Daily verification |

### 2.3 Security & Compliance

| Requirement | Target | Measurement | Review Cycle |
|-------------|--------|-------------|--------------|
| **Vulnerability Scans** | [X] scans/month | Container image + Kubernetes API scans | Weekly |
| **Patch Application** | Critical within 24 hours | OS + K8s patches applied | Daily monitoring |
| **Compliance Controls** | 95%+ passing | CTGA assessment or control checklist | Quarterly audit |
| **Audit Log Retention** | 12 months | Logs stored in Loki/object storage | Weekly verification |

---

## 3. Incident Response & Resolution

**[REQUIRED]** How Helix Stax will respond to and resolve issues.

### 3.1 Severity Definitions

| Severity | Definition | Impact | Response Target | Resolution Target |
|----------|-----------|--------|-----------------|-------------------|
| **SEV-1: Critical** | Production completely down; customer impact; data integrity at risk | All users affected; revenue impact | **15 minutes** (phone + Slack) | **4 hours** to mitigation |
| **SEV-2: High** | Major feature broken; workaround exists; performance severely degraded | Significant user impact; workaround burdensome | **1 hour** | **8 hours** to resolution |
| **SEV-3: Medium** | Feature degraded; minor performance impact; non-critical service down | Limited user impact; acceptable workaround | **4 hours** | **1 business day** |
| **SEV-4: Low** | Cosmetic issue; documentation bug; low-impact feature request | No user impact; enhancement | **24 hours** | **1 week** or as scheduled |

### 3.2 Response Commitments

**[REQUIRED]** What "response" means — Helix Stax commits to:

1. **Acknowledge** incident within the Response Target time
2. **Investigate** and determine initial root cause within 2x the Response Target
3. **Communicate** status updates every 30 minutes (SEV-1/2) or every 4 hours (SEV-3)
4. **Escalate** to engineering lead if not resolved within 50% of Resolution Target time
5. **Implement** fix or documented workaround within Resolution Target time

### 3.3 Post-Incident Review

For all SEV-1 and SEV-2 incidents:
- Helix Stax will schedule a post-incident review meeting within 48 hours
- Blameless retrospective will identify root cause and preventive measures
- Client will receive a written post-mortem report within 5 business days
- Follow-up fixes will be prioritized and tracked in ClickUp

---

## 4. Support Services

**[REQUIRED]** What support activities are included vs. optional add-ons.

### 4.1 Included in SLA

- **24/7 Incident Response**: Response to SEV-1/2/3/4 incidents per Section 3
- **Monthly Reviews**: Performance report + compliance status + optimization recommendations
- **Patch Management**: OS and Kubernetes security patches applied monthly (or critical patches immediately)
- **Backup Verification**: Weekly backup testing; restore drills every quarter
- **Access Management**: Quarterly review of user access, removal of inactive accounts
- **Email/Phone Support**: During service hours (Standard) or 24/7 (if selected)

### 4.2 Optional Add-Ons (Separate SOW Required)

- **Consulting**: Architecture reviews, capacity planning, optimization ($[Amount]/hour)
- **Managed Application Deployment**: CI/CD pipeline tuning, app debugging ($[Amount]/hour)
- **On-Site Support**: Travel to Client site ($[Amount]/day + expenses)
- **Custom Automation**: n8n workflows, scheduled reports ($[Amount]/hour)

---

## 5. Metrics & Reporting

**[REQUIRED]** How performance will be measured and reported.

### 5.1 Monitoring & Data Collection

Helix Stax will continuously monitor:
- Kubernetes cluster health via Prometheus
- Application performance via Grafana dashboards
- Logs and errors via Loki
- Security events via [Security monitoring tool]

All metrics are [publicly accessible via Grafana dashboard](https://[URL]) or provided in password-protected access.

### 5.2 Monthly Service Report

By the 5th business day of each month, Helix Stax will deliver:

| Section | Content |
|---------|---------|
| **Availability Summary** | Uptime %, any incidents, downtime details |
| **Performance Metrics** | API latency, pod startup time, backup duration |
| **Security & Compliance** | Vulnerability scan results, patches applied, compliance status |
| **Incidents & Resolutions** | All SEV-1/2/3 incidents, root causes, remediation steps |
| **Optimization Recommendations** | Suggested capacity increases, cost savings, security improvements |
| **Change Log** | All configuration changes, updates, patches applied |

### 5.3 Escalation Metrics

| Metric | Target | Alert If |
|--------|--------|----------|
| **Incidents Exceeding Resolution Target** | < 1/month | > 1 in any month |
| **Recurring Issues** | 0 (preventive action taken) | Same SEV-1/2 issue > 2x |
| **MTTR (Mean Time To Resolution)** | < [X hours] SEV-1/2 | > [X hours] average |
| **Availability vs. SLO** | >= stated SLO | < SLO in any month |

---

## 6. Service Credits & Remedies

**[REQUIRED]** What happens if Helix Stax misses SLO targets.

### 6.1 Availability Service Credits

If Kubernetes cluster uptime is less than the SLO, Client is entitled to service credits:

| Availability (Monthly) | Service Credit |
|------------------------|-----------------|
| 99.9% — 99.5% | 5% of that month's fee |
| 99.4% — 98.5% | 10% of that month's fee |
| 98.4% — 95.0% | 25% of that month's fee |
| < 95.0% | 50% of that month's fee |

**Example**: If uptime is 99.0% and monthly fee is $5,000, Client receives $500 credit.

### 6.2 Response Time Credits

If Helix Stax misses response targets on more than 2 SEV-1/2 incidents in a month:
- Client receives 10% service credit for that month

### 6.3 How to Claim Credits

- Client must submit a credit claim within 30 days of the month when SLO was missed
- Claim should reference specific incidents/dates
- Helix Stax will verify and apply credit to next month's invoice
- **Maximum monthly credit**: 50% of that month's fee

### 6.4 Credits Are Client's Sole Remedy

Service credits are Client's exclusive remedy for SLO misses. This does not waive Helix Stax's limitation of liability from the SOW.

---

## 7. Change Management

**[REQUIRED]** How changes to the infrastructure are handled to minimize disruption.

### 7.1 Change Windows

**Planned Changes** (minimal risk): Typically deployed during the week 2 PM–4 PM US Eastern without additional notice.

**Major Changes** (patches, upgrades, major config changes):
- 72 hours' notice required
- Scheduled during [Preferred Window, e.g., "Tuesday 2–4 PM US Eastern" or "Sunday 2–6 AM US Eastern"]
- Client can request alternative window if conflict exists

**Emergency Changes** (critical security patches):
- Deployed immediately (SEV-1 security issue)
- Post-deployment notification only

### 7.2 Rollback Procedures

Any change that causes a SEV-1/2 incident will be immediately rolled back unless Client requests otherwise.

---

## 8. Termination & Service Continuation

**[REQUIRED]** What happens if the SLA ends or is terminated.

### 8.1 Scheduled End of Service

[X] days before service termination date, Helix Stax will:
- Prepare final backup and provide to Client
- Export all monitoring data and dashboards
- Document all current configurations in runbooks
- Provide final status report

### 8.2 Early Termination

Either party may terminate with [X] days' written notice:
- Client receives prorated refund if prepaid
- Helix Stax provides data handoff at no additional cost

---

## 9. Limitations & Exclusions

**[REQUIRED]** What the SLA does NOT cover.

### 9.1 Not Covered

- Third-party failures (e.g., Hetzner Cloud outages, ISP issues, DNS failures)
- Client's misconfiguration or security compromise (e.g., Client accidentally deleting resources)
- Client's failure to apply patches or updates recommended by Helix Stax
- DDoS attacks exceeding [Capacity] or attacks outside Helix Stax's control
- Acts of God (natural disasters, etc.)
- Scheduled maintenance windows (up to 4 hours/month, 24 hours' notice)

### 9.2 Warranty Disclaimer

THIS SLA IS PROVIDED "AS-IS". HELIX STAX MAKES NO WARRANTY OF:

- Uptime exceeding the stated SLO (targets are "best effort")
- Data integrity, data recovery, or protection from loss
- Freedom from viruses, malware, or security breaches (Helix Stax monitors and responds, but cannot guarantee no breach will occur)
- Performance under abnormal conditions (e.g., DDoS, Client's excessive requests)

---

## 10. Compliance & Auditing

**[REQUIRED]** How SLA compliance is audited and verified.

### 10.1 Audit Rights

Client may request a third-party audit of SLA compliance, conducted at Client's expense. Helix Stax will:
- Grant read-only access to monitoring dashboards
- Provide logs and backup verification records
- Participate in 4-hour audit window (scheduled in advance)

### 10.2 Compliance Frameworks

This SLA supports the following compliance frameworks:

| Framework | Control | How This SLA Helps |
|-----------|---------|-------------------|
| **SOC 2** | CC6.1 (Change management) | Documents planned/emergency changes with rollback procedures |
| **SOC 2** | CC7.2 (System monitoring) | Continuous monitoring with metrics and alerting |
| **ISO 27001** | A.12.1.2 (Change management) | Structured change windows and approval process |
| **NIST CSF** | PR.IP-3 (Configuration change control) | Documents changes, verifies compliance |

---

## 11. General Terms

### 11.1 Effective Date & Duration

- **Effective Date**: [DATE]
- **Initial Term**: [X] months/year
- **Renewal**: Automatically renews for successive [X]-month periods unless either party provides 60 days' notice of non-renewal

### 11.2 Entire Agreement

This SLA is incorporated into the SOW referenced in Section 1. In case of conflict, this SLA takes precedence for operational matters.

### 11.3 Modification

This SLA may be modified by written agreement of both parties. Changes to SLO targets require [X] days' notice and both parties' written approval.

---

## SIGNATURES

| | |
|---|---|
| **CLIENT AUTHORIZATION** | |
| Name: ________________________ | Date: ____________ |
| Title: ________________________ | |
| Signature: ____________________ | |
| | |
| **HELIX STAX AUTHORIZATION** | |
| Name: Wakeem Williams | Date: ____________ |
| Title: Principal | |
| Signature: ____________________ | |

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| SOC 2 | CC6.1 | Change management — planned and emergency | Section 7 documents change windows and emergency procedures |
| SOC 2 | CC7.2 | Continuous monitoring and review | Section 5 documents continuous monitoring and monthly reporting |
| ISO 27001 | A.12.1.2 | Change management procedures | Change control process with rollback procedures |
| NIST CSF | PR.IP-3 | Configuration change control | Section 7 + Section 5.2 document changes and compliance verification |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] SLOs are specific and measurable (not vague)
- [ ] Response and resolution targets are realistic
- [ ] Severity definitions are clear
- [ ] Service credits are calculated and documented
- [ ] Escalation procedures are clear with actual contact information
- [ ] Exclusions are explicit (what is NOT covered)
- [ ] Both parties have signed and dated the SLA
- [ ] SLA is filed in ClickUp and shared with Client

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Client-Facing |
| **Version** | 1.0 |
