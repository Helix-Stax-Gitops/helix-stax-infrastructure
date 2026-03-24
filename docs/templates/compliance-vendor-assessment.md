---
template: compliance-vendor-assessment
category: compliance
task_type: vendor-assessment
clickup_list: "05 Compliance Program"
auto_tags: ["vendor", "assessment", "compliance", "security"]
required_fields: ["TLDR", "Vendor Information", "Security Controls", "Risk Assessment", "Decision", "Post-Approval Monitoring"]
classification: confidential
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Third-Party Vendor Security Assessment

Use for evaluating third-party vendors, SaaS providers, and service partners against Helix Stax security and compliance requirements. Store in `docs/compliance/vendor-assessments/{vendor-name}-assessment-{YYYY-MM-DD}.md`.

---

## TLDR

<!-- One sentence: vendor name, service, overall risk rating, recommendation. -->

Example: Backblaze B2 provides S3-compatible backup storage with AES-256 encryption; LOW risk. Recommend approval for production backup use with cost monitoring.

---

## Vendor Information

### [REQUIRED] Basic Details

| Field | Value |
|-------|-------|
| **Vendor Name** | |
| **Service/Product** | |
| **Proposed Use Case** | |
| **Service Type** | SaaS / On-premise / Hybrid / API / Hardware |
| **Data Classification** | Public / Internal / Confidential / Sensitive |
| **Vendor Location** | |
| **Vendor Size** | Startup / SMB / Mid-market / Enterprise |

### [REQUIRED] Contact Information

| Role | Name | Email | Phone |
|------|------|-------|-------|
| **Account Manager** | | | |
| **Security Contact** | | | |
| **Support Contact** | | | |

### [OPTIONAL] Existing Relationship

- [ ] Current customer (since _____)
- [ ] Pilot/trial period (from _____ to _____)
- [ ] New vendor under evaluation
- [ ] Renewal/contract extension

---

## Security Controls Assessment

### [REQUIRED] Encryption & Data Protection

| Control | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Encryption in transit** | ✓ / ✗ / N/A | TLS 1.2+ | |
| **Encryption at rest** | ✓ / ✗ / N/A | AES-256 | |
| **Key management** | ✓ / ✗ / N/A | Link to KMS docs | Customer-managed or vendor? |
| **Data residency** | ✓ / ✗ / N/A | US/EU/etc. | Acceptable locations? |
| **Data wiping** | ✓ / ✗ / N/A | Cryptographic erasure | On deletion/end of service |

### [REQUIRED] Authentication & Access Control

| Control | Status | Evidence | Notes |
|--------|--------|----------|-------|
| **Multi-factor authentication (MFA)** | ✓ / ✗ / N/A | Link to docs | Required for admin accounts |
| **Role-based access control (RBAC)** | ✓ / ✗ / N/A | Link to docs | Granular permissions? |
| **SSO/SAML/OIDC** | ✓ / ✗ / N/A | Link to docs | Can we integrate with Zitadel? |
| **API key rotation** | ✓ / ✗ / N/A | Link to docs | Automatic or manual? |
| **Audit logging** | ✓ / ✗ / N/A | Link to docs | Who accesses what, when |

### [REQUIRED] Vulnerability Management

| Control | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Vulnerability disclosure policy** | ✓ / ✗ / N/A | Link to docs | Responsible disclosure process? |
| **Security updates cadence** | ✓ / ✗ / N/A | Monthly / Quarterly | SLA for critical patches? |
| **Penetration testing** | ✓ / ✗ / N/A | Annual / Third-party | Independent validation? |
| **Code scanning** | ✓ / ✗ / N/A | SAST / Dependency scan | Proactive flaw detection? |

### [REQUIRED] Availability & Disaster Recovery

| Control | Status | Value | Notes |
|---------|--------|-------|-------|
| **Uptime SLA** | ✓ / ✗ / N/A | ___% | Acceptable for our use? |
| **RTO (Recovery Time Objective)** | ✓ / ✗ / N/A | ___ minutes | How fast can they recover? |
| **RPO (Recovery Point Objective)** | ✓ / ✗ / N/A | ___ minutes | Maximum data loss? |
| **Redundancy** | ✓ / ✗ / N/A | Multi-AZ / Multi-region | Geographically diverse? |
| **Backup frequency** | ✓ / ✗ / N/A | ___ hourly | Frequency of snapshots? |

### [REQUIRED] Compliance Certifications

| Certification | Current | Expiry | Verified | Notes |
|---------------|---------|--------|----------|-------|
| **SOC 2 Type II** | ✓ / ✗ | Date | Link | Critical for us |
| **ISO 27001** | ✓ / ✗ | Date | Link | Information security |
| **HIPAA BAA** | ✓ / ✗ / N/A | Date | Link | If health data involved |
| **PCI DSS** | ✓ / ✗ / N/A | Date | Link | If payment data involved |
| **GDPR DPA** | ✓ / ✗ / N/A | Date | Link | EU data processing |

---

## Operational Assessment

### [REQUIRED] Integration Capability

- [ ] API available (REST / GraphQL / GRPC)
- [ ] Documentation quality: ___/10
- [ ] SDK availability: [ ] Python [ ] Go [ ] Node.js [ ] Java [ ] Other: _____
- [ ] Webhook/event support: Yes / No
- [ ] Rate limits acceptable: Yes / No / Unknown

**Integration complexity**: Simple (1 day) / Moderate (1 week) / Complex (3+ weeks)

### [REQUIRED] Support & Service Level

| Metric | Value | Acceptable? |
|--------|-------|-------------|
| **Support channel** | Email / Phone / Chat / Slack | |
| **Support hours** | 24/7 / Business hours / Limited | |
| **Response time (critical)** | ___ minutes | Yes / No |
| **Response time (non-critical)** | ___ hours | Yes / No |
| **SLA penalties** | $ / % credit | Yes / No |

### [REQUIRED] Documentation & Training

- [ ] Comprehensive documentation available
- [ ] Video tutorials or quickstart guide
- [ ] Community/forums for support
- [ ] Training available (paid/free)
- [ ] Migration assistance offered

---

## Risk Assessment

### [REQUIRED] Risk Scoring

| Risk Factor | Low | Medium | High | Score | Mitigation |
|-------------|-----|--------|------|-------|-----------|
| **Security posture** | All controls ✓ | <80% controls | <50% controls | | |
| **Compliance alignment** | Certs match all frameworks | Partial match | No match | | |
| **Data sensitivity** | Public data | Internal data | Confidential/Sensitive | | |
| **Vendor financial stability** | Public, profitable | Mid-size, stable | Startup, unfunded | | |
| **Vendor security track record** | No breaches (5y) | Minor incidents | Major breach | | |
| **Country of operation** | US/Five Eyes | Friendly | Unfriendly/Unknown | | |
| **Dependency risk** | Non-critical service | Important but alternatives | Critical, no alternatives | | |

**Overall Risk Score**: ___ / 10 (Lower is better)

- **0-3**: GREEN — Low risk, approve
- **4-6**: YELLOW — Medium risk, require mitigations
- **7-10**: RED — High risk, escalate to security team

### [REQUIRED] Risk Mitigations

For each RED or YELLOW risk, document mitigation:

| Risk | Mitigation Strategy | Owner | Target Date |
|------|-------------------|-------|-------------|
| | | | |
| | | | |

---

## Compliance Mapping

### [REQUIRED] Framework Alignment

| Framework | Control | Requirement | Vendor Compliance | Gap? |
|-----------|---------|-------------|-------------------|------|
| **SOC 2** | C1 | Organization obtains/generates info | Documented in SOC 2 report | No |
| **SOC 2** | C3.1 | Logical & physical access controls | Link to evidence | |
| **ISO 27001** | A.8.3 | User registration and access management | Documented | |
| **ISO 27001** | A.12.2.1 | Control of operational software | Change control process | |
| **NIST CSF** | ID.SC-1 | Asset management | Inventory provided | |
| **NIST CSF** | PR.AC-1 | Access control policy | Link to vendor docs | |

---

## Contract & Legal Review

### [REQUIRED] Contractual Requirements

- [ ] Data Processing Agreement (DPA) signed
- [ ] Security Addendum in place
- [ ] Service Level Agreement (SLA) reviewed
- [ ] Confidentiality Agreement signed
- [ ] Liability limits acceptable ($_____ max)
- [ ] Termination clause allows 30-day exit
- [ ] Data deletion guarantee upon termination

### [OPTIONAL] Cost & Budget Impact

| Component | Annual Cost | Commitment | Notes |
|-----------|------------|-----------|-------|
| Service | $___/year | 1-3 year | Startup cost: $_____ |
| Support | $___/year | | |
| **Total** | $___/year | | |

**Budget owner**: ________________
**Approved budget**: $___/year

---

## Decision & Approval

### [REQUIRED] Recommendation

- [ ] **APPROVED** — Vendor meets all requirements. Proceed to contract negotiation.
- [ ] **CONDITIONAL APPROVAL** — Vendor acceptable with mitigations completed by [date].
- [ ] **UNDER REVIEW** — Need additional information: [specify].
- [ ] **REJECTED** — Vendor does not meet requirements. Reasons: [specify].

### [REQUIRED] Approval Sign-Off

| Role | Name | Date | Approval |
|------|------|------|----------|
| **Security Lead** | | | ✓ / ✗ |
| **Compliance Lead** | | | ✓ / ✗ |
| **Finance/Procurement** | | | ✓ / ✗ |
| **Service Owner** | | | ✓ / ✗ |

---

## Post-Approval Monitoring

### [REQUIRED] Ongoing Compliance

After vendor approval, Helix Stax will:

- [ ] Monitor vendor security advisories (quarterly minimum)
- [ ] Request updated SOC 2/ISO 27001 reports annually
- [ ] Conduct security reassessment every 2 years
- [ ] Review and update DPA annually
- [ ] Test vendor SLA commitments annually
- [ ] Document any incidents or security events

**Reassessment date**: ___________

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Confidential |
