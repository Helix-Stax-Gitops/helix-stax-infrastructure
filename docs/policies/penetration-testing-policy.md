---
title: "Penetration Testing Policy"
policy_id: POL-017
category: policy
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
    controls: ["CC4.1", "CC7.1"]
  - framework: ISO 27001
    controls: ["A.8.8"]
  - framework: NIST
    controls: ["RA-5", "SP 800-115"]
---

# Penetration Testing Policy

## TLDR

Establishes requirements for periodic penetration testing to identify and remediate security vulnerabilities within the Helix Stax environment. Defines methodology, scope, frequency, vendor criteria, rules of engagement, and remediation timelines. Required by SOC 2, ISO 27001, and NIST. Approved by CEO.

---

## Purpose

This policy establishes the requirements for periodic penetration testing to identify and remediate security vulnerabilities within the Helix Stax environment. This process validates the effectiveness of technical controls and ensures the resilience of the K3s-based infrastructure against modern threat actors.

## Scope

- All production-facing assets and supporting infrastructure
- External perimeter, application layer, orchestration layer, and API surface
- Excludes third-party SaaS providers (subject to SOC 2 Type II report reviews)

---

## Policy Statements

### 1. Methodology Selection

All penetration tests must adhere to a combination of:

- **OWASP Top 10 / ASVS:** For web application and API security (specifically Zitadel and custom apps)
- **PTES (Penetration Testing Execution Standard):** For end-to-end execution flow
- **NIST SP 800-115:** For technical testing methodology and reporting standards

### 2. Scope of Testing

| Target | Description |
|--------|-------------|
| **External Perimeter** | Cloudflare WAF configurations, DNS entries, public IP ranges |
| **Application Layer** | Zitadel (Identity), Traefik (Ingress), customer-facing microservices |
| **Orchestration Layer** | K3s Control Plane security, Node-to-Node encryption (Flannel WireGuard), RBAC |
| **API Surface** | Internal and external REST/gRPC endpoints |
| **Excluded** | Third-party SaaS (Backblaze B2) -- subject to SOC 2 report review |

### 3. Automated Scanning vs. Manual Testing

- **Automated Scanning:** Performed weekly using OpenSCAP, Lynis, and CrowdSec for baseline configuration drift and known CVEs
- **Manual Penetration Testing:** Performed by an independent third party to identify complex logic flaws, vulnerability chaining, and bypasses of WAF/Ingress controls

### 4. Frequency

- **Annual:** Comprehensive external penetration test at least once every 12 months
- **Trigger-Based:** Required following any "Significant Change" -- K3s version migration, CNI change, major Zitadel OIDC flow changes, or introduction of new high-risk data processing services

### 5. Vendor Criteria

Testing must be performed by an independent, CREST or OSCP/OSCE-certified firm providing:

- Proof of professional liability insurance
- Clean background check for all assigned testers
- Experience with Kubernetes/Cloud-Native environments

### 6. Rules of Engagement (RoE)

- **Timeline:** Testing scheduled during low-traffic windows for "Active/Destructive" testing
- **Emergency Contact:** A "Stop Test" contact must be available 24/7 during the testing window
- **Data Handling:** Testers must not exfiltrate PII/PHI. Use "Proof of Concept" (PoC) files instead of real sensitive data

### 7. Reporting and Remediation Tracking

1. **Draft Report:** Vendor delivers initial findings
2. **Severity Rating:** Findings categorized using CVSS v3.1 scores
3. **Remediation Timelines:**
   - Critical: 15 days
   - High: 30 days
   - Medium: 90 days
4. **Tracking:** All findings logged in ClickUp (Space: 03 Security and Compliance)
5. **Re-test:** Formal re-test of Critical and High findings required within 30 days of remediation

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve testing scope and vendor, review findings |
| **DevOps Lead** | Coordinate testing windows, implement remediations |
| **External Vendor** | Execute tests per RoE, deliver findings report |
| **Compliance Lead** | Track remediation progress, maintain evidence for audits |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| SOC 2 | CC4.1 | Monitoring Activities |
| SOC 2 | CC7.1 | Identification and Analysis of Significant Issues |
| ISO 27001 | A.8.8 | Management of Technical Vulnerabilities |
| NIST | RA-5 | Vulnerability Scanning |
| NIST | SP 800-115 | Technical Guide to Information Security Testing |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
