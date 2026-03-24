---
title: "Information Security Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-001"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC1.1", "CC1.2", "CC1.3"]
  - framework: "ISO 27001"
    controls: ["5.2", "5.3", "6.2"]
  - framework: "NIST CSF"
    controls: ["GV.PO", "GV.RM"]
---

# Information Security Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Information Security Policy establishes Helix Stax's top-level commitment to protecting the confidentiality, integrity, and availability of all information assets. Required by SOC 2 CC1.1, ISO 27001 clause 5.2, and NIST CSF GV.PO. Approved by CEO.

---

## 1. Purpose

This policy defines Helix Stax's commitment to information security and establishes the governance framework under which all subordinate security policies operate. It provides management direction, assigns organizational responsibilities, and sets the security objectives that guide technical and operational controls across the infrastructure.

## 2. Scope

This policy applies to:

- All Helix Stax employees, contractors, and vendors with access to company systems
- All information assets including K3s cluster nodes (heart, helix-worker-1), cloud infrastructure on Hetzner, Cloudflare edge services, and all applications deployed on the platform
- All data processed, stored, or transmitted by Helix Stax systems regardless of classification level
- All client environments managed under the Delivery workspace

**Exemptions**: None. This policy has no exemptions.

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Information Asset** | Any data, system, application, or infrastructure component owned or managed by Helix Stax |
| **Security Incident** | Any event that compromises the confidentiality, integrity, or availability of an information asset |
| **Risk Owner** | The individual accountable for managing a specific identified risk |
| **Control** | A safeguard or countermeasure designed to reduce identified risk to an acceptable level |

## 4. Policy Statements

**PS-001.1**: Helix Stax shall maintain an Information Security Management System (ISMS) aligned with ISO 27001:2022 and SOC 2 Trust Services Criteria.

**PS-001.2**: All information assets shall be classified according to the Data Classification Policy (POL-005) and protected with controls appropriate to their classification level.

**PS-001.3**: Security objectives shall be established annually, documented in the risk register, and reviewed quarterly for progress.

**PS-001.4**: All access to production systems shall require multi-factor authentication (MFA) enforced via Zitadel OIDC. No exceptions are permitted for administrative accounts.

**PS-001.5**: Security controls shall be implemented following a defense-in-depth model across all 10 layers: physical/cloud, network edge, host OS, container runtime, orchestration, network overlay, admission, runtime security, application, and data.

**PS-001.6**: All security events shall be logged to a centralized logging system (Loki) with a minimum retention period of 90 days for operational logs and 1 year for audit logs.

**PS-001.7**: Vulnerability scanning shall be performed weekly using OpenSCAP against the CIS Benchmark Level 1 profile for AlmaLinux 9. Critical vulnerabilities (CVSS 9.0+) shall be remediated within 48 hours; high vulnerabilities (CVSS 7.0-8.9) within 14 days.

**PS-001.8**: No secrets, credentials, or private keys shall be stored in version control. All secrets shall be managed through OpenBao with External Secrets Operator for Kubernetes integration.

**PS-001.9**: All container images deployed to production shall be signed using Cosign and verified by Kyverno admission policies before scheduling.

**PS-001.10**: This policy and all subordinate policies shall be reviewed annually, or sooner if triggered by a security incident, regulatory change, or significant infrastructure modification.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Ultimate accountability for information security; approves policy; allocates resources; accepts residual risk |
| **Security Lead** | Implements technical controls; conducts security reviews; manages incident response; reports security posture to CEO |
| **Compliance Lead** | Maintains compliance evidence; coordinates audits; tracks remediation; manages the Unified Control Matrix |
| **System Administrator** | Configures and maintains security controls on K3s, Hetzner, and all platform services |
| **All Personnel** | Comply with security policies; report suspected incidents; complete security awareness training |

## 6. Compliance & Enforcement

Violations of this policy shall be handled according to the severity framework:

| Severity | Example | Consequence |
|----------|---------|-------------|
| Minor | Failure to complete training on time | Verbal warning; mandatory retraining |
| Serious | Unauthorized access to a restricted system | Written warning; access suspension pending investigation |
| Critical | Intentional data exfiltration or credential theft | Immediate suspension; termination; legal action if warranted |

All violations shall be reported to the Security Lead at security@helixstax.com.

## 7. Exceptions Process

1. Submit exception request to CEO with written business justification
2. Complete a risk assessment identifying the security impact of the exception
3. Define compensating controls to offset the identified risk
4. Obtain written approval from CEO
5. Document the exception in `docs/policies/exception-register.md` with an expiration date not exceeding 12 months
6. Re-approval is required before the exception expires

## 8. Related Documents

- Access Control Policy (POL-002)
- Change Management Policy (POL-003)
- Incident Response Policy (POL-004)
- Data Classification Policy (POL-005)
- Risk Assessment Policy (POL-009)
- `docs/adr/` -- Architecture Decision Records
- Gemini Deep Research: Server Hardening & Security Automation

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
| **Policy ID** | POL-001 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |
