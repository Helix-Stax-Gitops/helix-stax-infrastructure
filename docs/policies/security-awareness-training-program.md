---
title: "Security Awareness Training Program"
policy_id: POL-018
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
  - framework: HIPAA
    controls: ["164.308(a)(5)"]
  - framework: SOC 2
    controls: ["CC1.4"]
  - framework: ISO 27001
    controls: ["A.6.3"]
---

# Security Awareness Training Program

## TLDR

Defines the security awareness training curriculum, frequency, delivery methods, testing, and completion tracking for all Helix Stax personnel. Required by HIPAA, SOC 2, and ISO 27001. Approved by CEO and Security Officer.

---

## Purpose

This program ensures that all Helix Stax personnel understand their role in protecting sensitive information (PII/PHI) and maintaining the security posture of the AlmaLinux/K3s infrastructure.

## Scope

- All employees, contractors, interns, and executives
- All personnel with access to Helix Stax or client systems

---

## Procedure Steps

### 1. Core Curriculum Topics

- **Phishing and Social Engineering:** Identifying suspicious emails, SMS (Smishing), and AI-generated deepfake voice/video
- **Data Handling (HIPAA Focus):** Proper handling of Protected Health Information (PHI), "Minimum Necessary" rule, and secure disposal
- **Remote Work Security:** VPN/Zero Trust usage, physical security of home offices, public Wi-Fi risks
- **Incident Reporting:** How to report a lost device or suspected breach within 1 hour to the Security Officer
- **AI Tool Usage:** Safe use of LLMs (Claude, Gemini, etc.) -- prohibiting upload of client code, secrets, or PII into public AI models
- **Credential Hygiene:** Mandatory use of Bitwarden/Passkeys and 2FA for all services (Zitadel, GitHub, Cloudflare)

### 2. Training Frequency

| Type | Timing | Requirement |
|------|--------|-------------|
| **New Hire Training** | Within 30 days of start date | No production data access until completion |
| **Annual Refresher** | Yearly | Mandatory for all personnel |
| **Ad-Hoc Training** | As needed | Triggered by significant incidents or repeated phishing simulation failures |

### 3. Delivery Methods and Resources

Helix Stax utilizes a "Lean Security" approach:

- **Primary Platform:** Internal LMS or structured ClickUp Doc modules
- **Resources:**
  - SANS OUCH! Newsletters (distributed monthly via Slack/Email)
  - FTC Cybersecurity for Small Business (baseline modules)
  - HHS Security 101 (HIPAA-specific training modules)
  - Wizer Training (free/low-cost interactive video modules)

### 4. Testing and Phishing Simulations

- **Quizzes:** Each training module concludes with a quiz (80% passing score required)
- **Phishing Simulations:** Performed quarterly using Gophish or KnowBe4 Free Phish-lite
- **Failure Consequence:** Employees who fail simulation must complete "Just-in-Time" remedial training

### 5. Completion Tracking and Evidence

- **Evidence Vault:** Certificates of completion and attendance logs stored in the Helix Stax Evidence Archival
- **Reporting:** Compliance status reviewed during monthly Management Review Meetings
- **Non-Compliance:** Failure to complete training within the 30-day window results in automated suspension of Zitadel OIDC accounts

### 6. Policy Acknowledgement

Upon completion, all users must digitally sign the Acceptable Use Policy (AUP) and Information Security Policy via the company HR portal or DocuSign.

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve curriculum, oversee program compliance |
| **HR Lead** | Track completion, enforce consequences for non-compliance |
| **Training Coordinator** | Develop materials, schedule sessions, run simulations |
| **All Personnel** | Complete required training, pass quizzes, report phishing attempts |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| HIPAA | 164.308(a)(5) | Security Awareness and Training |
| SOC 2 | CC1.4 | Board of Directors and Management Personnel |
| ISO 27001 | A.6.3 | Information Security Awareness, Education, and Training |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |
