---
template: security-threat-model
category: security
task_type: threat-model
clickup_list: "03 Security Operations"
auto_tags: ["security", "threat-model", "stride"]
required_fields: ["TLDR", "Assessment Metadata", "System Overview", "Trust Boundaries", "STRIDE Analysis", "Threat Summary", "Mitigation Plan"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Threat Model

Use for systematically identifying threats to a system, asset, or process using the STRIDE methodology. Store in `docs/security/threat-models/{system-name}-threat-model-{YYYY-MM-DD}.md`.

---

## TLDR

<!-- One sentence: system name, assessment date, STRIDE categories analyzed, number of threats, highest severity threat. -->

Example: Zitadel identity system threat model as of 2026-03-22. Assessed STRIDE across 6 components. Identified 18 threats; highest severity: authentication bypass via SAML SSO misconfiguration (HIGH).

---

## Assessment Metadata

### [REQUIRED] Threat Model Information

| Field | Value |
|-------|-------|
| **System Name** | |
| **Assessment Date** | YYYY-MM-DD |
| **Assessed By** | |
| **Threat Model Owner** | |
| **Review Cycle** | Quarterly / Biannually / Annually |

### [REQUIRED] Assessment Scope

**System components in scope:**

- [ ] User authentication
- [ ] Authorization & access control
- [ ] Data storage (databases)
- [ ] Data transmission (networks)
- [ ] API endpoints
- [ ] Third-party integrations
- [ ] Infrastructure (K3s, networking)
- [ ] Application code
- [ ] Supply chain / dependencies

---

## System Overview & Data Flow

### [REQUIRED] System Description

**High-level description of the system being modeled:**

(2-3 paragraphs describing what the system does, who uses it, what data it processes)

---

### [REQUIRED] Trust Boundaries

**Trust boundaries** (where data crosses from trusted to untrusted):

| Boundary | Trusted Side | Untrusted Side | Data Type |
|----------|--------------|-----------------|-----------|
| | | | |
| | | | |

**Trust boundary diagram** (ASCII or text description):

```
[User/Internet] ---|TLS/HTTPS|---> [Ingress/Cloudflare]
                                      ---|Firewall|---> [K3s Cluster]
                                                         ---|Network Policy|---> [Pod]
                                                                                  ---|RBAC|---> [Database]
```

### [REQUIRED] Data Flow

**Critical data flows through the system:**

| # | Source | Destination | Data | Protocol | Authentication |
|---|--------|-------------|------|----------|-----------------|
| 1 | User browser | API | JSON / credentials | HTTPS + TLS | OAuth2 / OIDC |
| 2 | API | Database | Queries / data | PostgreSQL protocol | mTLS + RBAC |
| 3 | | | | | |

---

## STRIDE Threat Analysis

The STRIDE methodology examines six threat categories:

- **S**poofing: Impersonation (fake identity)
- **T**ampering: Unauthorized modification (data integrity)
- **R**epudiation: Denial of action (non-repudiation)
- **I**nformation Disclosure: Data leakage (confidentiality)
- **D**enial of Service: Unavailability
- **E**levation of Privilege: Unauthorized access (authorization)

---

## Component-Based Threat Analysis

### [REQUIRED] Component 1: [Name - e.g., API Server]

#### STRIDE Threats for This Component

##### Spoofing

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| S-001 | Attacker spoofs user identity via forged JWT | No JWT signature validation | Medium | High | **HIGH** | Validate all JWT signatures with public key |
| S-002 | | | | | | |

##### Tampering

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| T-001 | Attacker modifies API request in transit | No TLS encryption | Low (TLS in use) | Critical | MEDIUM | Enforce HTTPS only, HSTS headers |
| T-002 | | | | | | |

##### Repudiation

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| R-001 | User denies making API call | No audit logging | Medium | Medium | MEDIUM | Enable audit logging for all API calls |
| R-002 | | | | | | |

##### Information Disclosure

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| I-001 | API returns sensitive error messages | Verbose error handling | Medium | Medium | MEDIUM | Generic error messages, detailed logs server-side only |
| I-002 | | | | | | |

##### Denial of Service

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| D-001 | Attacker floods API with requests | No rate limiting | High | High | **HIGH** | Implement rate limiting (API Gateway / Cloudflare) |
| D-002 | | | | | | |

##### Elevation of Privilege

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| E-001 | Attacker escalates from user to admin | RBAC not enforced | Low (RBAC in place) | Critical | HIGH | Audit RBAC rules, least privilege enforcement |
| E-002 | | | | | | |

---

### [OPTIONAL] Component 2: [Name]

#### STRIDE Threats for This Component

##### Spoofing

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

##### Tampering

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

##### Repudiation

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

##### Information Disclosure

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

##### Denial of Service

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

##### Elevation of Privilege

| Threat # | Threat | Root Cause | Likelihood | Impact | Severity | Mitigation |
|----------|--------|-----------|-----------|--------|----------|-----------|
| | | | | | | |

---

## Threat Summary & Prioritization

### [REQUIRED] Threat Inventory

**All identified threats:**

| Threat ID | Category | Threat | Likelihood | Impact | Severity | Status |
|-----------|----------|--------|-----------|--------|----------|--------|
| S-001 | Spoofing | JWT forgery | Medium | High | HIGH | Open / Mitigated / Accepted |
| T-001 | Tampering | Man-in-middle | Low | Critical | MEDIUM | Open / Mitigated / Accepted |
| D-001 | DoS | API flooding | High | High | HIGH | Mitigated |
| | | | | | | |

### [REQUIRED] Risk Matrix

| | Low Impact | Medium Impact | High Impact | Critical Impact |
|---|-----------|---------------|-------------|-----------------|
| **Low Likelihood** | Green (4) | Green (3) | Yellow (6) | Orange (1) |
| **Medium Likelihood** | Green (3) | Yellow (8) | Orange (4) | Red (2) |
| **High Likelihood** | Yellow (1) | Orange (5) | Red (2) | Red (1) |

**Risks by severity:**

- **RED (Critical)**: Threats S-001, E-001, D-001 — Require immediate mitigation
- **ORANGE (High)**: Threats T-001, I-001 — Should mitigate in current sprint
- **YELLOW (Medium)**: Threats R-001 — Mitigate within 1-2 months
- **GREEN (Low)**: All others — Monitor, mitigate if feasible

---

## Mitigation & Controls

### [REQUIRED] Mitigation Plan for HIGH/RED Threats

#### Threat: D-001 (API DoS)

| Component | Mitigation | Owner | Timeline | Status |
|-----------|-----------|-------|----------|--------|
| Cloudflare WAF | Configure rate limiting: 100 req/min per IP | Security Lead | Week 1 | Planned |
| API Gateway | Implement request throttling in Kong | Backend Lead | Week 2 | Planned |
| Monitoring | Alert on anomalous traffic patterns | SRE | Week 2 | Planned |

#### Threat: S-001 (JWT Forgery)

| Component | Mitigation | Owner | Timeline | Status |
|-----------|-----------|-------|----------|--------|
| API Server | Validate JWT signature on every request | Backend Lead | COMPLETE | Verified |
| Configuration | Ensure public key is from trusted IdP | Security Lead | COMPLETE | Verified |
| Testing | Unit test JWT validation, pen test SSO | Test Engineer | Week 2 | In Progress |

---

## Dependencies & Assumptions

### [REQUIRED] Trust Assumptions

**Assumptions about what is trustworthy:**

- [ ] TLS/HTTPS is secure (no MITM)
- [ ] Cloudflare infrastructure is secure
- [ ] Zitadel IdP is secure
- [ ] PostgreSQL database is secure (network isolation)
- [ ] K3s control plane is secure (RBAC, network policy)
- [ ] All employees follow security policies

**If any assumption is violated**, which threats are re-activated?

- If TLS broken: S-001, T-001, I-001 escalate from Medium to Critical
- If RBAC broken: E-001 escalates to Critical

### [REQUIRED] External Dependencies

**Third-party security dependencies:**

| Component | Vendor | Security Responsibility | Monitoring |
|-----------|--------|------------------------|-----------|
| Cloudflare | External | DDoS mitigation, WAF | Uptime dashboard |
| Zitadel | Internal | OIDC/SAML implementation | Audit logs |
| PostgreSQL | Internal | Data encryption, access control | Prometheus metrics |

---

## Testing & Validation

### [REQUIRED] Threat Validation

**How will mitigations be verified?**

| Threat | Validation Method | Test Owner | Frequency |
|--------|-------------------|-----------|-----------|
| S-001 | Unit test JWT validation + pen test | Test Lead | Before each release |
| D-001 | Load test (1000 req/sec) | SRE | Quarterly |
| T-001 | SSL Labs scan | Security Lead | Monthly |

### [OPTIONAL] Penetration Testing

- [ ] Has system been pen-tested? [ ] Yes [ ] No
- [ ] If yes, date: __________ Finding: [link to report]
- [ ] Next pen-test scheduled: YYYY-MM-DD

---

## Compliance & Controls

### [REQUIRED] Security Control Mapping

This threat model satisfies:

| Framework | Control | Requirement | How Satisfied |
|-----------|---------|-------------|---------------|
| SOC 2 | C3.1 | Logical access controls | Threat S-001, E-001 mitigations |
| ISO 27001 | A.12.6.1 | Vulnerability management | STRIDE identifies vulnerabilities |
| NIST CSF | PR.DS-1 | Data protection | Threats related to data security identified |

---

## Review & Maintenance

### [REQUIRED] Threat Model Update Plan

**This threat model will be reviewed:**

- [ ] **When system changes**: Architecture change, new component, new integration
- [ ] **When threat landscape changes**: New attack pattern emerges
- [ ] **Quarterly**: General refresh and mitigation validation
- [ ] **Annually**: Full reassessment

**Last reviewed**: ___________
**Next review**: YYYY-MM-DD
**Last major update**: YYYY-MM-DD (reason: ___________)

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **System** | [system name] |
| **Classification** | Confidential |
