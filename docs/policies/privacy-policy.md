---
title: "Privacy Policy"
policy_id: POL-012
category: policy
classification: PUBLIC
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: HIPAA
    controls: ["164.520", "164.528"]
  - framework: VCDPA
    controls: ["59.1-575 through 59.1-584"]
  - framework: CCPA
    controls: ["1798.100 through 1798.199"]
  - framework: SOC 2
    controls: ["P1.0", "P1.1"]
  - framework: ISO 27001
    controls: ["A.5.34", "A.5.35"]
---

# Privacy Policy

## TLDR

Public-facing privacy policy governing how Helix Stax collects, uses, and protects personal data. Compliant with VCDPA, CCPA, and HIPAA Privacy Rule. Covers client data processing, AI deployment practices, and individual rights. Approved by CEO.

---

## Purpose

This policy describes how Helix Stax collects, uses, and shares information in compliance with the Virginia Consumer Data Protection Act (VCDPA), California Consumer Privacy Act (CCPA), and HIPAA Privacy Rule where applicable.

## Scope

- All website visitors (helixstax.com)
- All clients and their data
- All Helix Stax infrastructure processing personal data
- All personnel handling personal data or PHI

---

## Policy Statements

### 1. Introduction

Helix Stax ("we," "us," or "our") is an IT consulting firm providing infrastructure management, DevOps orchestration, and AI deployment services. We are committed to protecting the privacy of our clients and website visitors.

### 2. Information We Collect

- **Client Information:** Business contact information (names, emails, billing addresses) necessary for contract fulfillment.
- **Infrastructure Metadata:** When managing client systems (K3s clusters, Hetzner Cloud instances), we may collect log data, IP addresses, and performance metrics. We act as a **Data Processor** regarding client-owned data.
- **Website Data:** We use privacy-preserving analytics to collect information about website interactions (Astro/Tailwind-based site).

### 3. How We Use Your Information

- Provision and manage IT infrastructure
- Maintain security and monitor for threats (SOC 2/ISO 27001 requirements)
- Comply with legal obligations and regulatory audits
- Communicate technical updates and service availability

### 4. Data Processing and Artificial Intelligence (AI)

- **Local AI Deployment:** Helix Stax prioritizes local AI models (via Ollama and Open WebUI) hosted on private infrastructure. Data processed via local AI deployments does not leave our controlled environment and is not used to train third-party models.
- **Client Data Isolation:** Client data used in AI-assisted workflows is strictly isolated and purged per the client's data retention policy.

### 5. Security and Data Storage

- **Infrastructure:** Internal systems hosted on AlmaLinux 9.7 servers within Hetzner Cloud and Cloudflare's global network.
- **Encryption:** All data at rest encrypted using AES-256. Data in transit protected via TLS 1.3.
- **Backups:** Secure, immutable backups stored in Backblaze B2 with Object Lock enabled.

### 6. HIPAA Privacy Rule Compliance

While Helix Stax is an IT firm and not a healthcare provider, we operate as a **Business Associate** for clients who are Covered Entities. We do not use PHI for marketing or any purpose other than those authorized in our BAAs.

### 7. Your Rights (VCDPA and CCPA)

Virginia and California residents may have the right to:

- **Access:** Confirm if we are processing your personal data and obtain a copy
- **Correction:** Correct inaccuracies in your personal data
- **Deletion:** Request the deletion of personal data provided by or obtained about you
- **Opt-Out:** Opt-out of processing for targeted advertising or profiling
- **Appeals:** If we decline a request, you may appeal by contacting our Privacy Officer

### 8. Data Breach Notification

In the event of a security breach involving personal data or PHI, Helix Stax will notify affected clients and individuals within the timeframes required by state law and HIPAA (typically within 72 hours for PHI-related breaches).

### 9. Contact Information

**Helix Stax Privacy Office**
Email: privacy@helixstax.com

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **Privacy Officer / CEO** | Respond to privacy requests, maintain policy, oversee HIPAA compliance |
| **DevOps Lead** | Implement encryption and data isolation controls |
| **All Personnel** | Handle personal data per policy, report privacy incidents immediately |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| HIPAA | 164.520 | Notice of Privacy Practices |
| HIPAA | 164.528 | Accounting of Disclosures |
| VCDPA | 59.1-575 | Consumer Rights and Data Processing |
| CCPA | 1798.100 | Consumer Right to Know |
| SOC 2 | P1.0 | Privacy Criteria |
| SOC 2 | P1.1 | Privacy Notice |
| ISO 27001 | A.5.34 | Privacy and Protection of PII |
| ISO 27001 | A.5.35 | Independent Review of Information Security |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
