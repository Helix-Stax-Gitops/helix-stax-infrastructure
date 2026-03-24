---
template: business-statement-of-work
category: business
task_type: sow
clickup_list: 01 Delivery Operations > Contracts
auto_tags: [sow, contract, client-facing, legal]
required_fields: [Services, Deliverables, Timeline, Investment, Payment Terms, Signatures]
classification: client-facing
compliance_frameworks: [general-business]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Statement of Work (SOW)

Use this template when formalizing a consulting engagement. The SOW is a binding contract that follows the Proposal. File in ClickUp under Delivery > [Client Name] and have both parties sign before work begins.

## TLDR

A formal, legally binding Statement of Work (SOW) that defines services, deliverables, timeline, payment terms, and liability limits. SOWs are signed by both parties before engagement begins. This template is the contract — be precise, reference the approved Proposal, and document assumptions clearly.

---

## 1. Engagement Details

### Parties

| Role | Entity | Contact |
|------|--------|---------|
| **Service Provider** | Helix Stax, Inc. | Wakeem Williams, admin@helixstax.com |
| **Client** | [Client Legal Name] | [Client Contact Name], [Client Email], [Client Phone] |

### Effective Date

This SOW is effective upon the date of the last signature below: **________________** (MM/DD/YYYY)

### Reference Documentation

This SOW references and incorporates by reference:
- **Proposal**: [Proposal Document Title, Date]
- **Any attached Exhibits**: [e.g., "Exhibit A: Architecture Design Specifications"]

---

## 2. Scope of Services

**[REQUIRED]** Detailed description of what Helix Stax will deliver. Should match Proposal but be more precise and formal.

### 2.1 Services In Scope

Helix Stax will deliver the following services during the Engagement Period:

**Phase 1: Assessment**
- Conduct current-state infrastructure audit using the CTGA (Controls, Technology, Growth, Adoption) maturity framework
- Deliver Current-State Assessment Report with findings and CTGA scoring
- Identify compliance gaps against [Framework], [Framework] (e.g., NIST CSF, SOC 2)

**Phase 2: Design**
- Develop Kubernetes architecture design document
- Design compliance control implementation for [Framework]
- Conduct design review session with Client stakeholders
- Obtain Client sign-off on final architecture design

**Phase 3: Implementation**
- Provision Kubernetes (K3s) cluster on [Infrastructure, e.g., Hetzner Cloud]
- Deploy identity management system (Zitadel) with OIDC/SAML
- Implement CI/CD pipeline ([ArgoCD/Devtron/other])
- Deploy monitoring and compliance automation ([Prometheus/Grafana/Loki/other])
- Conduct user acceptance testing (UAT) with Client

**Phase 4: Handoff & Training**
- Develop comprehensive runbooks for infrastructure operations
- Conduct team training ([Number] days, [Number] people) on:
  - Kubernetes cluster administration
  - Deploying applications to the cluster
  - Incident response procedures
  - Backup and disaster recovery
- Provide 2-week post-go-live support ([X] hours per week)

### 2.2 Services Out of Scope

Helix Stax will NOT provide:
- [e.g., Migrating existing workloads from AWS — scope for separate SOW]
- [e.g., Custom application development or code review beyond infrastructure]
- [e.g., 24/7 managed service support — optional add-on via separate SLA]
- [e.g., Client's internal change management, approvals, or procurement processes]

### 2.3 Client Responsibilities

**[REQUIRED]** What must the Client provide for the engagement to succeed?

The Client agrees to:
- **Infrastructure Access**: Provision Hetzner Cloud account (or equivalent) with [specific requirements] within 5 business days of SOW signature
- **Decision-Making**: Designate primary decision-maker and technical point of contact available at least [X] hours per week
- **Collaboration**: Provide [X] person-hours per week from Client team for meetings, requirements clarification, and UAT
- **Approval Timeline**: Review and approve design documents within 5 business days of delivery
- **Data & Secrets**: Supply any necessary configuration, credentials, or data migration requirements in a secure manner (e.g., via OpenBao, not email)

---

## 3. Deliverables

**[REQUIRED]** Specific, measurable deliverables with acceptance criteria.

| # | Deliverable | Phase | Format | Client Acceptance Criteria | Due Date |
|---|-------------|-------|--------|---------------------------|-----------|
| 1 | Current-State Assessment Report | 1 | PDF + Markdown | Client approves findings; CTGA scores signed off | [DATE] |
| 2 | Architecture Design Document | 2 | PDF + Markdown | Client technical team approves design; no open questions on compliance | [DATE] |
| 3 | Infrastructure Code Repository | 3 | Git + Helm charts | Cluster passes [X] NIST controls; all manifests peer-reviewed | [DATE] |
| 4 | Deployed Kubernetes Cluster | 3 | Live Production | Passes UAT; uptime verified for [X] hours; security scan clean | [DATE] |
| 5 | Operations Runbooks | 4 | Markdown in Git | Cover 10 operational procedures; team confirms usability | [DATE] |
| 6 | Team Training (2 days) | 4 | Live Workshop | [X] attendees; post-training assessment > [Score] passing | [DATE] |
| 7 | Knowledge Transfer Documentation | 4 | Confluence/Wiki | Covers architecture, operations, troubleshooting; Client team confirms completeness | [DATE] |

---

## 4. Timeline & Milestones

**[REQUIRED]** Detailed phase timeline with go-live date and key milestones.

| Phase | Duration | Start | End | Key Milestones | Owner |
|-------|----------|-------|-----|-----------------|-------|
| **Phase 1: Assess** | 2 weeks | [DATE] | [DATE] | Kickoff meeting (Day 1), Assessment complete (Day 10), Report delivered (Day 14) | Helix Stax |
| **Phase 2: Design** | 3 weeks | [DATE] | [DATE] | Design review meeting (Day 5), Client feedback incorporated (Day 10), Sign-off meeting (Day 21) | Helix Stax |
| **Phase 3: Build** | 6 weeks | [DATE] | [DATE] | Infrastructure code ready (Day 14), Zitadel integration live (Day 21), CI/CD complete (Day 35), UAT (Day 42) | Helix Stax + Client |
| **Phase 4: Handoff** | 2 weeks | [DATE] | [DATE] | Training Day 1-2 (Days 1-2), Runbook review (Days 3-10), Go-live readiness (Day 14) | Helix Stax + Client |
| **Post-Go-Live Support** | 2 weeks | [DATE] | [DATE] | Daily standups, incident response, optimization recommendations | Helix Stax |

### Critical Path Dependencies

- Helix Stax cannot begin Phase 2 until Client approves Phase 1 findings (within 5 days)
- Phase 3 cannot begin until Hetzner Cloud account is provisioned and credentials provided
- Phase 4 cannot begin until Phase 3 UAT is signed off by Client technical team

---

## 5. Investment & Payment Terms

**[REQUIRED]** Total cost, itemized breakdown, and payment schedule.

### 5.1 Total Engagement Investment

**Total Fixed Price: $[AMOUNT] USD (excl. tax if applicable)**

### 5.2 Payment Schedule

| Milestone | % of Total | Amount | Due Date |
|-----------|-----------|--------|----------|
| Upon SOW Signature | 33% | $[Amount] | [DATE] |
| Upon Phase 2 Completion & Approval | 33% | $[Amount] | [DATE] |
| Upon Phase 4 Completion & Sign-Off | 34% | $[Amount] | [DATE] |
| **Total** | 100% | **$[Total Amount]** | |

### 5.3 Infrastructure Costs

**[REQUIRED]** If Client is responsible for infrastructure rental:

- Hetzner Cloud VPS costs: Client pays directly to Hetzner (~$[Amount]/month)
- Helix Stax will assist with Hetzner account setup and sizing recommendations
- Helix Stax does NOT mark up infrastructure costs

### 5.4 Out-of-Scope Change Requests

Any work outside the defined Scope of Services (Section 2) will be documented in a Change Request, estimated separately, and quoted at $[Hourly Rate]/hour. Change Requests must be approved in writing before work begins.

### 5.5 Payment Method & Terms

- **Payment Due**: Net 30 days from invoice date
- **Accepted Methods**: ACH transfer, wire transfer, check
- **Invoice Address**: [Helix Stax Address]
- **Late Payment**: If payment is not received within 30 days, Helix Stax may pause work until payment is current

---

## 6. Acceptance & Sign-Off

**[REQUIRED]** How will the Client formally accept deliverables?

### 6.1 Acceptance Criteria

Each deliverable is considered "Accepted" when:

1. The deliverable meets the Client Acceptance Criteria listed in Section 3
2. The Client has [X] business days to review and provide feedback
3. Client provides written sign-off (email from authorized approver is sufficient)
4. Any critical issues raised by Client are resolved by Helix Stax within [X] business days

### 6.2 Final Sign-Off

Upon completion of Phase 4, the Client will formally sign off on the entire engagement using the form below:

---

**ENGAGEMENT COMPLETION SIGN-OFF**

I certify that Helix Stax has completed all deliverables as specified in this Statement of Work, and the Client's team is prepared to operate the infrastructure independently.

| Field | Value |
|-------|-------|
| **Client Authorized Signatory** | [Name, Title] |
| **Signature** | ____________________ |
| **Date** | ____________________ |
| **Helix Stax Representative** | [Name, Title] |
| **Signature** | ____________________ |
| **Date** | ____________________ |

---

## 7. Responsibilities & Assumptions

**[REQUIRED]** What both parties are responsible for, and what assumptions underpin the timeline/cost.

### 7.1 Helix Stax Responsibilities

- Deliver services and deliverables per Section 3 with professional standards
- Assign experienced team members to the engagement (see Team Assignments in Proposal)
- Respond to Client inquiries within 24 business hours
- Perform 5 business days of post-go-live support at no additional cost

### 7.2 Client Responsibilities

- Provide timely approvals and sign-offs (see Section 2.3)
- Provide necessary infrastructure, access, and credentials securely
- Dedicate sufficient internal resources for collaboration and training
- Make decisions and clear blockers within defined timeframes

### 7.3 Key Assumptions

This SOW assumes:

- Client will provide Hetzner Cloud account access by [DATE] (or infrastructure costs will be $[X] higher if Helix Stax provisions on Client's behalf)
- Client technical team will dedicate [X] person-hours per week to this project
- No major scope creep or Client-side delays beyond [X] calendar days total
- Client's existing infrastructure/secrets will be provided securely via [method]
- No major compliance changes (e.g., new regulatory requirements) will be imposed during the engagement

---

## 8. Intellectual Property & Confidentiality

**[REQUIRED]** Ownership of code, documentation, and confidential information.

### 8.1 Intellectual Property Ownership

- **Client-Specific Code & Infrastructure**: All Kubernetes manifests, Helm charts, and infrastructure code created specifically for Client belong to Client upon full payment
- **Helix Stax Tools & Methodologies**: Helix Stax retains ownership of:
  - CTGA assessment framework
  - Standard architectural patterns and designs
  - Documentation templates and runbook templates
  - Scripts and tools not specific to Client
- **Third-Party Software**: All open-source (K8s, Prometheus, etc.) and commercial software remains subject to their respective licenses

### 8.2 Confidentiality

- Helix Stax will keep all Client data, configurations, and secrets confidential
- Client information will not be shared with third parties except as necessary for service delivery
- Confidentiality obligations survive termination for [X] years

---

## 9. Warranty & Limitations

**[REQUIRED]** What Helix Stax guarantees, and liability limits.

### 9.1 Warranty

Helix Stax warrants that:
- Deliverables will be substantially free of defects upon delivery
- Services will be performed in a professional and workmanlike manner
- All personnel assigned are qualified and experienced

**Warranty Period**: 30 days from Phase 4 completion sign-off
- If critical defects are discovered within 30 days, Helix Stax will remedy them at no additional cost
- "Critical defect" = prevents core functionality (e.g., cluster won't start, authentication is broken)

### 9.2 Limitation of Liability

IN NO EVENT SHALL HELIX STAX BE LIABLE FOR:

- Indirect, incidental, consequential, or punitive damages (lost profits, lost data, business interruption, etc.)
- Damages exceeding the total fees paid under this SOW
- Issues caused by Client's failure to follow recommendations or security practices
- Issues caused by third-party systems (e.g., Hetzner Cloud outages, DNS failures)

**Client's sole remedy** for breach is repair of deliverables or, if repair is not possible, a refund of fees paid.

### 9.3 No Guarantees for Third-Party Software

Helix Stax makes no warranty regarding uptime, performance, or security of third-party tools (Kubernetes, Zitadel, ArgoCD, etc.). These tools are provided "as-is" subject to their own open-source licenses.

---

## 10. Termination & Suspension

**[OPTIONAL]** Under what conditions can either party end the engagement?

### 10.1 Termination for Convenience

Either party may terminate this SOW with [X] days' written notice:
- If terminated by Client: Client pays for work completed + reasonable wind-down costs
- If terminated by Helix Stax: Full refund of any unearned deposits

### 10.2 Termination for Cause

Helix Stax may immediately suspend work if:
- Client fails to make a payment when due and doesn't remedy within 10 days
- Client denies Helix Stax access to required infrastructure or information

---

## 11. General Terms

### 11.1 Governing Law

This SOW is governed by the laws of [State/Country]. Any disputes will be resolved through binding arbitration in [Location].

### 11.2 Entire Agreement

This SOW, including the Proposal referenced in Section 1, constitutes the entire agreement between the parties regarding this engagement. Any modifications must be in writing and signed by both parties.

### 11.3 Signatures

By signing below, both parties agree to the terms and conditions of this Statement of Work.

---

## SIGNATURES

| | |
|---|---|
| **CLIENT AUTHORIZATION** | |
| Name: ________________________ | Date: ____________ |
| Title: ________________________ | |
| Company: [Client Name] | |
| Signature: ____________________ | |
| | |
| **HELIX STAX AUTHORIZATION** | |
| Name: Wakeem Williams | Date: ____________ |
| Title: Principal | |
| Company: Helix Stax, Inc. | |
| Signature: ____________________ | |

---

## Compliance Mapping

| Framework | Control | Requirement | How This Template Satisfies It |
|-----------|---------|-------------|-------------------------------|
| General Business | Contract Management | Clear scope, terms, and deliverables prevent disputes | Detailed scope, timeline, acceptance criteria, and liability limits |
| SOC 2 | CC3.3 (Risk Acceptance) | Document decisions to accept risks | Assumptions and limitations sections document risk acceptance |

---

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Proposal and SOW are aligned (no contradictions)
- [ ] Timeline includes specific dates for each milestone
- [ ] Payment schedule is clear and signed off by both parties
- [ ] Client responsibilities and assumptions are explicit
- [ ] Deliverables have measurable acceptance criteria
- [ ] Both parties have signed and dated the SOW
- [ ] SOW is filed in ClickUp under Delivery > [Client Name]

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
