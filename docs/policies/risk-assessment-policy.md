---
title: "Risk Assessment Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-009"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC3.1", "CC3.2", "CC3.3", "CC3.4"]
  - framework: "ISO 27001"
    controls: ["6.1.1", "6.1.2", "6.1.3", "8.2", "8.3"]
  - framework: "HIPAA"
    controls: ["164.308(a)(1)(ii)(A)", "164.308(a)(1)(ii)(B)"]
  - framework: "NIST CSF"
    controls: ["GV.RM-1", "GV.RM-2", "ID.RA-1", "ID.RA-2", "ID.RA-3"]
---

# Risk Assessment Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Risk Assessment Policy defines Helix Stax's methodology for identifying, analyzing, evaluating, and treating information security risks. Uses a 5x5 likelihood/impact matrix with four treatment options (accept, mitigate, transfer, avoid). Risk register maintained in ClickUp. Required by SOC 2 CC3.2, ISO 27001 clause 6.1, HIPAA 164.308(a)(1). Approved by CEO.

---

## 1. Purpose

This policy establishes a consistent, repeatable methodology for identifying and managing information security risks. It ensures that risks are identified before they materialize, assessed objectively, treated appropriately, and tracked to resolution. Risk assessment is foundational to the ISMS and drives control selection across all other policies.

## 2. Scope

This policy applies to all information assets, business processes, and technology systems within the Helix Stax operating environment, including:

- Infrastructure and platform components (K3s, Hetzner, Cloudflare)
- Applications and services deployed on the platform
- Data processing activities for Helix Stax and its clients
- Third-party vendor relationships
- Business processes and operational procedures

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Risk** | The potential for loss or harm resulting from a threat exploiting a vulnerability |
| **Threat** | A potential cause of an unwanted event that could result in harm to an asset |
| **Vulnerability** | A weakness in a system, process, or control that could be exploited by a threat |
| **Risk Appetite** | The level of risk the organization is willing to accept in pursuit of its objectives |
| **Risk Register** | A structured record of identified risks, their assessments, treatment decisions, and current status |
| **Residual Risk** | The risk remaining after treatment controls have been applied |

## 4. Policy Statements

### 4.1 Risk Identification

**PS-009.1**: Risk identification shall be performed through the following methods:

1. **Asset inventory review**: Enumerate information assets and identify associated threats and vulnerabilities
2. **Vulnerability scanning**: Weekly OpenSCAP scans against CIS Level 1 profile; continuous Trivy scanning of container images in Harbor
3. **Threat intelligence**: CrowdSec global threat intelligence feeds; Cloudflare security event analysis; vendor security advisories
4. **Incident analysis**: Review of past incidents and near-misses for recurring risk patterns
5. **Change assessment**: Evaluate risks introduced by proposed changes per the Change Management Policy (POL-003)
6. **Compliance gap analysis**: Identify risks from gaps between current controls and framework requirements (UCM in ClickUp Folder 05)

**PS-009.2**: All personnel shall report identified risks or potential vulnerabilities to the Security Lead. Risk identification is a continuous activity, not limited to scheduled assessments.

### 4.2 Risk Analysis

**PS-009.3**: Identified risks shall be analyzed using a 5x5 likelihood/impact matrix:

**Likelihood Scale:**

| Score | Level | Definition |
|-------|-------|-----------|
| 1 | Rare | Less than once per year; no known history |
| 2 | Unlikely | Once per year; has occurred in the industry |
| 3 | Possible | Quarterly occurrence; has occurred to similar organizations |
| 4 | Likely | Monthly occurrence; has occurred to Helix Stax |
| 5 | Almost Certain | Weekly or more frequent; actively occurring |

**Impact Scale:**

| Score | Level | Definition |
|-------|-------|-----------|
| 1 | Negligible | No data loss; no service impact; no regulatory consequence |
| 2 | Minor | Minimal data exposure (<10 records); service degradation <1 hour; no notification required |
| 3 | Moderate | Limited data exposure (10-500 records); service outage 1-4 hours; potential regulatory inquiry |
| 4 | Major | Significant data breach (500+ records); service outage 4-24 hours; regulatory notification required; client impact |
| 5 | Severe | Massive data breach; extended outage >24 hours; regulatory enforcement action; existential business impact |

**PS-009.4**: Risk score shall be calculated as Likelihood x Impact, yielding a score from 1 to 25:

| Risk Level | Score Range | Treatment Requirement |
|------------|-------------|----------------------|
| **Critical** | 20-25 | Immediate treatment required; CEO notification within 24 hours |
| **High** | 12-19 | Treatment plan required within 7 days |
| **Medium** | 6-11 | Treatment plan required within 30 days |
| **Low** | 1-5 | Accept or treat per business judgment; review annually |

### 4.3 Risk Treatment

**PS-009.5**: For each identified risk scoring Medium or above, a treatment decision shall be documented selecting one of four options:

| Option | Definition | When Appropriate | Documentation Required |
|--------|-----------|-----------------|----------------------|
| **Mitigate** | Implement controls to reduce likelihood or impact | Risk can be reduced to acceptable level with reasonable effort | Control description, owner, implementation timeline |
| **Transfer** | Shift risk to a third party (insurance, outsourcing) | Risk is better managed by another party | Transfer mechanism, residual risk assessment |
| **Avoid** | Eliminate the activity or condition that creates the risk | Risk is too high and cannot be adequately mitigated | Business impact of avoidance, alternative approach |
| **Accept** | Acknowledge the risk and take no additional action | Residual risk is within risk appetite; cost of treatment exceeds benefit | CEO-signed acceptance with justification |

**PS-009.6**: Risk acceptance for risks scoring High (12-19) requires written CEO approval. Risk acceptance for risks scoring Critical (20-25) is not permitted; these risks must be mitigated, transferred, or avoided.

### 4.4 Risk Register

**PS-009.7**: The risk register shall be maintained in ClickUp (Folder 05: Compliance Program, List: Risk Register) and shall include for each risk: (1) unique risk ID, (2) description, (3) affected assets, (4) likelihood score, (5) impact score, (6) risk score, (7) treatment decision, (8) control(s) applied, (9) risk owner, (10) residual risk score, (11) status, (12) review date.

**PS-009.8**: The risk register shall be reviewed quarterly by the CEO and updated to reflect: new risks identified, changes to existing risk scores, treatment progress, and closed risks.

### 4.5 Assessment Cadence

**PS-009.9**: A comprehensive risk assessment shall be performed annually, covering all assets, threats, and vulnerabilities in scope. The annual assessment shall be completed within Q1 of each calendar year.

**PS-009.10**: Ad-hoc risk assessments shall be triggered by: (1) significant infrastructure changes, (2) new client engagements involving Restricted data, (3) security incidents, (4) new regulatory requirements, (5) vendor changes for Critical tier services.

**PS-009.11**: Risk assessment results, including the methodology used, findings, and treatment decisions, shall be documented and archived as compliance evidence in MinIO with SHA-256 integrity verification.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Defines risk appetite; approves risk acceptance decisions; reviews risk register quarterly; accountable for residual risk posture |
| **Security Lead** | Conducts risk assessments; maintains risk register; recommends treatment options; monitors threat landscape |
| **Compliance Lead** | Maps risks to compliance framework controls; ensures treatment plans satisfy regulatory requirements |
| **System Administrator** | Implements technical risk mitigation controls; provides vulnerability scan data for risk identification |
| **All Personnel** | Report potential risks and vulnerabilities; participate in risk assessments as subject matter experts |

## 6. Compliance & Enforcement

Failure to conduct the annual risk assessment, failure to treat Critical risks, or accepting High risks without CEO approval constitutes a serious policy violation.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. No exceptions are permitted for: the annual risk assessment requirement, or treatment of Critical-scored risks.

## 8. Related Documents

- Information Security Policy (POL-001)
- Vendor Management Policy (POL-008)
- Incident Response Policy (POL-004)
- Data Classification Policy (POL-005)
- Unified Control Matrix (ClickUp Folder 05)
- NIST SP 800-30: Guide for Conducting Risk Assessments

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
| **Policy ID** | POL-009 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
