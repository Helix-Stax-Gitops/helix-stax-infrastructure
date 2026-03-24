# Gemini Deep Research: Helix Stax Template Library

Copy this entire prompt into Gemini Deep Research. It will research best practices, then generate the complete ~46-template library in one response.

---

## PROMPT START

---

## Section 1: Your Role

You are a **Senior Compliance & Documentation Architect** with 15+ years of experience designing document template libraries for IT consulting firms that serve regulated industries. You have deep expertise in:

- **Compliance frameworks**: SOC 2 Type II, NIST CSF 2.0, NIST SP 800-53, ISO 27001, HIPAA, PCI DSS 4.0, CIS Controls v8
- **IT service management**: ITIL 4 practices (change enablement, incident management, problem management, service request management)
- **Software delivery**: Agile/Scrum ceremonies, ADR methodology, SRE post-mortem culture
- **Consulting operations**: Proposals, SOWs, SLAs, client lifecycle management

Your output becomes the **OFFICIAL Helix Stax template library**. Every template will be used in production by humans and AI agents. No generic boilerplate. Every field must earn its place.

---

## Section 2: What This Is

You are building the complete document template library for **Helix Stax** — an IT consulting firm specializing in infrastructure, compliance, and security services.

### Company Context

| Field | Value |
|-------|-------|
| **Company** | Helix Stax |
| **Domain** | helixstax.com |
| **Owner** | Wakeem Williams (admin@helixstax.com) |
| **Focus** | IT consulting — infrastructure, compliance (SOC 2, NIST, ISO 27001, HIPAA, PCI DSS), managed services |
| **Proprietary Framework** | CTGA (Controls, Technology, Growth, Adoption) — maturity assessment scoring 100-900 across 4 strands |
| **AI Agents** | 23 PACT specialist agents with full names (see attribution table below) |
| **Infrastructure** | K3s cluster on Hetzner Cloud, GitOps via ArgoCD + Devtron |
| **Project Management** | ClickUp (2 spaces: 01 Platform, 02 Delivery) |
| **Chat** | Rocket.Chat (self-hosted, NOT Telegram, NOT Slack) |

### Tech Stack (use these names exactly — never substitute)

| Correct Name | DO NOT Use |
|-------------|------------|
| Valkey | Redis |
| OpenTofu | Terraform |
| Rocket.Chat | Telegram, Slack |
| Zitadel | Authentik, Auth0 |
| OpenBao | HashiCorp Vault |
| CloudNativePG | plain PostgreSQL |
| AlmaLinux | Ubuntu, CentOS |

### Full Stack Reference

K3s, Traefik, cert-manager, Cloudflare, CloudNativePG (PostgreSQL), Valkey, MinIO, Harbor, Zitadel (OIDC/SAML), Devtron, ArgoCD, Prometheus, Grafana, Loki, Alertmanager, CrowdSec, Velero, n8n, Rocket.Chat, Backstage, Outline, OpenBao, External Secrets Operator, Helm, Ansible, OpenTofu

### How These Templates Are Used

1. **Humans** fill them in when creating tasks, reports, and deliverables
2. **AI agents** parse them programmatically — consistent field labels and structured sections are critical for machine consumption
3. **ClickUp automations** auto-attach the correct template when a task is created with a specific task type
4. **Auditors** reference them during SOC 2 Type II and ISO 27001 certification audits — templates ARE the evidence trail
5. **Clients** receive client-facing templates as deliverables — these represent the Helix Stax brand

### Compliance Frameworks

| Tier | Frameworks | When |
|------|-----------|------|
| **Tier 1** (Always) | NIST CSF 2.0, SOC 2, ISO 27001, CIS Controls v8 | Every engagement |
| **Tier 2** (Per client) | HIPAA, PCI DSS 4.0, NIST 800-171, CMMC 2.0, GDPR, CCPA | When client requires |

---

## Section 3: Research Phase (BEFORE Generating)

**Do this research BEFORE generating any templates.** Apply findings to every template. This is what separates best-in-class from boilerplate.

### 3.1 Industry Benchmarking
Research how **Deloitte, Accenture, KPMG, and top MSPs** structure their IT consulting templates. What sections are mandatory? What do their internal document standards require? How do they handle version control and classification?

### 3.2 SOC 2 Type II Documentation Requirements
Research what **SOC 2 Type II auditors specifically look for** in documented information. What are the Trust Services Criteria that require documented templates? Focus on CC6.2 (access controls), CC7.1 (vulnerability management), CC3.3 (risk assessment), CC8.1 (change management), A1.2/A1.3 (availability/disaster recovery), CC9.2 (vendor management). What evidence format do auditors prefer?

### 3.3 ISO 27001 Clause 7.5
Research **ISO 27001 Clause 7.5 documented information requirements**. What metadata must every controlled document contain? How do identification, description, format, review, and approval work? What does "documented information" mean in audit context?

### 3.4 NIST SP 800-53 Audit Records
Research **NIST SP 800-53 audit record requirements**. What fields must audit records contain? How do AU (Audit and Accountability) family controls drive template design? What does NIST CSF 2.0 require for documented procedures?

### 3.5 Post-Mortem Best Practices
Research **Google SRE post-mortem format** (from the SRE book), **PagerDuty's incident review process**, and **Atlassian's post-incident review**. What fields do the best incident retrospectives include that most templates miss? How do blameless post-mortems work structurally?

### 3.6 ADR Best Practices
Research **Michael Nygard's original ADR format**, **MADR (Markdown ADR)**, and the **Joel Parker Henderson ADR collection** (github.com/joelparkerhenderson/architecture-decision-record). What makes a good ADR vs a bad one? What fields are essential vs noise?

### 3.7 ITIL 4 Templates
Research **ITIL 4 change enablement**, **service request management**, and **problem management** template structures. What does ITIL 4 specifically require for Change Advisory Board (CAB) records? How do standard vs normal vs emergency changes differ in documentation?

### 3.8 Template Anti-Patterns
Research **what makes people skip fields in templates**. What are the most common template design mistakes? How do you design fill-in-able templates that people ACTUALLY complete? What is the optimal number of required fields before completion rates drop?

### 3.9 AI Agent Consumption
Research how templates should be structured for **AI agent consumption**. What makes a template machine-parseable? How should field labels be formatted for LLM extraction? What structural patterns enable automated field population?

### 3.10 Consulting Proposal Psychology
Research **what makes IT consulting proposals win**. What sections do decision-makers actually read? How should pricing be presented — anchoring, tiered options, value-based? What is the ideal proposal length? How do the Big Four structure their proposals?

---

## Section 4: Standards (EVERY Template Must Follow)

### 4.1 File Naming

- File name: `{category}-{name}.md` (lowercase, hyphenated)
  - Examples: `compliance-access-review-report.md`, `operational-runbook.md`, `client-proposal.md`
- Title: `# TEMPLATE: {Name}`
- Subtitle: One line explaining when to use this template and where to file it

### 4.2 YAML Frontmatter (Header Block)

Every template begins with this YAML frontmatter block:

```yaml
---
template: {name}
category: {operational|compliance|client|business|agile|security|infrastructure|hr|communication|release|reference|incident}
task_type: {bug|feature|incident|change-request|security-finding|compliance-control|service-request|sprint|meeting|release|onboarding|offboarding|proposal|sow|etc}
clickup_list: {which ClickUp list this attaches to — from the workspace structure}
auto_tags: [array of tags auto-applied when this template is used]
required_fields: [fields that MUST be filled before the task can move to the next status]
classification: {internal|client-facing|confidential}
compliance_frameworks: [which frameworks require or benefit from this template — e.g., SOC2, NIST, ISO27001]
review_cycle: {monthly|quarterly|annually|per-use}
author: Wakeem Williams
version: 1.0
---
```

### 4.3 Body Structure

Every template body follows this order:

1. **TLDR** — 2-3 sentences maximum. What this template is for and when to use it. A reader should know within 5 seconds whether this is the right template.

2. **Sections** — Clear markdown H2 headers. Use tables over prose wherever possible. Keep sections scannable — a reader should find what they need in under 30 seconds.

3. **Field Markers** — Mark every field as `[REQUIRED]` or `[OPTIONAL]`. Required fields are the minimum viable documentation. Optional fields add value but should not block completion.

4. **Compliance Mapping** — Table at the bottom of every template:

```markdown
## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC8.1 | Change management documentation | Records change details, risk, rollback, approvals |
| ISO 27001 | A.12.1.2 | Change management | Provides structured change request with CAB approval |
| NIST CSF | PR.IP-3 | Configuration change control | Documents before/after state and rollback procedures |
```

5. **Definition of Done** — Checklist of what must be true before this work item is considered "complete":

```markdown
## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Template has been reviewed by {role}
- [ ] {Domain-specific completion criteria}
```

6. **Example** — At least one filled-in example per template showing what GOOD looks like. Use realistic Helix Stax scenarios. The example teaches by showing, not telling.

### 4.4 Footer

Every template ends with:

```markdown
---
Author: Wakeem Williams
Co-Author: {Agent Full Name} ({Role})
Date: YYYY-MM-DD
Last Reviewed: YYYY-MM-DD
Classification: {Internal | Client-Facing | Confidential}
Version: X.Y
```

### 4.5 Terminology (Enforce Consistently)

| Term | Use For | Never Mix With |
|------|---------|---------------|
| **Priority**: P1 (Critical), P2 (High), P3 (Normal), P4 (Low) | Business impact ranking on ALL non-incident templates | SEV scale |
| **Severity**: SEV-1, SEV-2, SEV-3, SEV-4 | Operational incident severity ONLY (Incident Report, Post-Mortem) | P scale |

**Technology names** — always use: Valkey (NOT Redis), OpenTofu (NOT Terraform), Rocket.Chat (NOT Telegram/Slack), Zitadel (NOT Authentik), OpenBao (NOT HashiCorp Vault), CloudNativePG (NOT plain PostgreSQL), AlmaLinux (NOT Ubuntu/CentOS).

### 4.6 Design Principles

- **No empty section headings** — every section must have guidance text (HTML comments or placeholder text) explaining what to write
- **Imperative voice** for action items ("Deploy the fix", not "The fix should be deployed")
- **No emojis** in any template
- **Tables over prose** — wherever data has 2+ attributes, use a table
- **Checkboxes for checklists** — use `- [ ]` format for anything that gets checked off
- **Scannable** — a reader finds what they need in under 30 seconds
- **Consistent field labels** — identical concepts use identical labels across all templates (e.g., always "Affected Services", never sometimes "Impacted Services")

### 4.7 Agent Attribution

Use these exact names as Co-Author, matched to the template's domain:

| Agent | Full Name | Role | Co-Authors Templates In |
|-------|-----------|------|------------------------|
| Sable | Sable Navarro | Product Manager | Business, client delivery, agile |
| Remy | Remy Alcazar | Research Analyst | Research-heavy templates |
| Scout | Scout Calloway | Integration Advisor | Integration, workflow |
| Cass | Cass Whitfield | System Architect | Architecture, ADRs, infrastructure design |
| Lena | Lena Takeda | UI/UX Designer | UI-related templates |
| Dax | Dax Okafor | Backend Developer | Backend operational templates |
| Wren | Wren Ashby | Frontend Developer | Frontend operational templates |
| Soren | Soren Lindqvist | Data Engineer | Database, data templates |
| Kit | Kit Morrow | Infrastructure Engineer | Infrastructure, deployment, DR, capacity |
| Nix | Nix Patel | Automation Engineer | n8n workflows, automation |
| Petra | Petra Vanek | Test Engineer | Testing, QA templates |
| Ezra | Ezra Raines | Security Engineer | Security, vulnerability, incident response, pen test |
| Bex | Bex Cordero | QA Specialist | QA, verification |
| Vigil | Vigil Frost | Automation Monitor | Monitoring, alerting |
| Clio | Clio Amari | Memory Keeper | Knowledge management |
| Quinn | Quinn Mercer | Documentation Lead | General docs, SOPs, meeting notes, reference docs |
| Sage | Sage Holloway | SEO Specialist | Marketing, content |
| Pixel | Pixel Zheng | Visual Content Creator | Visual, branding |

**Rule**: Match Co-Author to template domain. Security templates = Ezra Raines. Infrastructure templates = Kit Morrow. Client-facing business templates = Sable Navarro. Compliance templates = Ezra Raines (security-adjacent) or Quinn Mercer (reporting). When in doubt, use Quinn Mercer.

---

## Section 5: Complete Template Inventory (~46 Templates)

Generate ALL templates below. Each template must follow Section 4 standards completely.

---

### Category A: Operational (5 templates)

**A1. Runbook**
- **When**: Step-by-step guide for diagnosing and resolving a specific operational scenario
- **ClickUp List**: 06 Process Library > Runbooks
- **Task Type**: runbook
- **Required Fields**: TLDR, Prerequisites, Step-by-Step Procedure, Rollback, Verification
- **Auto-Tags**: [type:runbook, phase:operate]
- **Compliance**: NIST CSF PR.IP-9 (response plans), SOC 2 CC7.4
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, When to Use This Runbook, Prerequisites (tools, access, permissions), Step-by-Step Procedure (numbered with exact bash commands), Rollback Procedure, Verification (how to confirm the fix worked), Escalation Path, Compliance Mapping

**A2. SOP (Standard Operating Procedure)**
- **When**: Documenting a repeatable business or technical process
- **ClickUp List**: 06 Process Library > SOPs
- **Task Type**: sop
- **Required Fields**: TLDR, Purpose, Scope, Roles, Procedure, Verification
- **Auto-Tags**: [type:sop, phase:operate]
- **Compliance**: ISO 27001 Clause 7.5, SOC 2 CC1.1, NIST CSF GV.PO
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Purpose, Scope (what this covers and explicitly what it does NOT cover), Roles & Responsibilities table (RACI), Procedure (phased with verification checkpoints after each phase), Exception Process (what to do when the SOP cannot be followed — who approves exceptions and how they are documented), Verification Checklist, Approval table (name, role, date, signature)

**A3. ADR (Architecture Decision Record)**
- **When**: Recording a significant technical or architectural decision
- **ClickUp List**: 07 Product & Strategy > ADRs
- **Task Type**: adr
- **Required Fields**: TLDR, Status, Decision Date, Context, Decision, Consequences
- **Auto-Tags**: [type:adr, phase:architect]
- **Compliance**: ISO 27001 A.12.1.2, SOC 2 CC8.1
- **Co-Author**: Cass Whitfield (System Architect)
- **Key sections**: TLDR (the decision in one sentence + status [Proposed|Accepted|Deprecated|Superseded] + decision date), Context (why this decision is needed — business and technical drivers), Decision (what was decided), Options Considered (table with option name, description, pros, cons, compliance impact per option), Rationale (why this option won), Consequences (positive, negative, and follow-on work required)
- **IMPORTANT**: Decision Date is the date the decision was made, which is distinct from the Document Date in the footer. Include both.

**A4. Post-Mortem**
- **When**: After resolving any SEV-1 or SEV-2 incident. Recommended for SEV-3.
- **ClickUp List**: 04 Service Management > Incidents
- **Task Type**: post-mortem
- **Required Fields**: TLDR, Timeline, Root Cause, Impact, Five Whys, Action Items
- **Auto-Tags**: [type:post-mortem, phase:review]
- **Compliance**: SOC 2 CC7.3/CC7.4/CC7.5, NIST CSF RS.AN, ISO 27001 A.16.1.6
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Incident Metadata table (severity, duration, detection method, commander), Timeline table (UTC timestamps — be exact), Root Cause (one specific paragraph, not "the pod crashed" but the actual underlying cause), Impact table (services affected, users affected, data loss yes/no, SLA breach yes/no, PHI/PII exposed yes/no, revenue impact), Five Whys (chain from symptom to root cause), What Went Well, What Went Wrong, "Was there a runbook? Did it help?" field (forces evaluation of preparedness), Action Items table (action, owner, due date, status, linked ticket), Compliance Mapping
- **Blameless**: Include a note that post-mortems are blameless — focus on systems, not individuals

**A5. Change Request**
- **When**: Any planned modification to production systems, configurations, or infrastructure
- **ClickUp List**: 04 Service Management > Changes
- **Task Type**: change-request
- **Required Fields**: TLDR, Description (before/after state), Risk Assessment, Rollback Plan, CAB Approval
- **Auto-Tags**: [type:change-request, phase:deploy]
- **Compliance**: SOC 2 CC8.1, ISO 27001 A.12.1.2, NIST CSF PR.IP-3, ITIL 4 Change Enablement
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Change Type (standard/normal/emergency — per ITIL 4), Description (before state, after state, what changes), Justification (why this change is needed), Risk Assessment table (risk, likelihood, impact, mitigation), Affected Services table, Testing Results (what was tested and how before requesting production change), Rollback Plan (exact steps to undo, including commands), Implementation Plan (step-by-step with estimated duration per step), CAB Approval field (approver name, date, decision [approved/rejected/deferred], conditions), Compliance Mapping

---

### Category B: Compliance (9 templates)

**B1. Monthly Compliance Status Report**
- **When**: First business day of each month
- **ClickUp List**: 05 Compliance Program > Reports
- **Task Type**: compliance-report
- **Required Fields**: Reporting Period, Frameworks Covered, Posture Score, Open POA&M Count, Controls by Status
- **Auto-Tags**: [type:compliance-report, cadence:monthly]
- **Compliance**: SOC 2 CC4.1/CC4.2, ISO 27001 Clause 9.1, NIST CSF ID.GV
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Header table (reporting period, frameworks covered, overall posture score, previous period score, trend), Controls by Status table (framework, total controls, compliant, partially compliant, non-compliant, not assessed), Open POA&M Count (with aging: <30 days, 30-60, 60-90, >90), New Findings This Period, Resolved Findings This Period, Evidence Collection Summary (collected vs required), Top 3 Risks, Key Actions for Next Period

**B2. Quarterly Risk Assessment**
- **When**: Quarterly (January, April, July, October)
- **ClickUp List**: 05 Compliance Program > Risk Register
- **Task Type**: risk-assessment
- **Required Fields**: Risk Landscape Summary, Top 10 Risks, New Risks, POA&M Progress
- **Auto-Tags**: [type:risk-assessment, cadence:quarterly]
- **Compliance**: SOC 2 CC3.1/CC3.2/CC3.3, ISO 27001 Clause 6.1, NIST CSF ID.RA
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Header table (quarter, assessment date, assessor, methodology), Risk Landscape Summary (narrative overview of threat environment), Top 10 Risks table (rank, risk ID, description, likelihood, impact, risk score, trend vs last quarter, owner, treatment [accept/mitigate/transfer/avoid]), New Risks Identified, Risks Closed/Downgraded, Vulnerability Trends (4-quarter rolling comparison), POA&M Progress table, Recommendations

**B3. Annual Compliance Review**
- **When**: End of fiscal year or before annual audit
- **ClickUp List**: 05 Compliance Program > Audits
- **Task Type**: annual-review
- **Required Fields**: Year-over-Year Posture, Audit Results, Control Maturity, Strategic Roadmap
- **Auto-Tags**: [type:annual-review, cadence:annually]
- **Compliance**: SOC 2 CC4.1, ISO 27001 Clause 9.3, NIST CSF GV.OC
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Executive Summary (for leadership consumption), Year-over-Year Posture by Framework table, Audit Results Summary (findings, observations, recommendations), Control Maturity by Domain (scoring each domain on a 1-5 maturity scale), Key Accomplishments, Gaps Remaining, Strategic Roadmap for Next Year, Budget Recommendations

**B4. CTGA Assessment Report**
- **When**: Client engagement — initial or recurring assessment
- **ClickUp List**: 02 Delivery > {Client} > Assessments
- **Task Type**: ctga-assessment
- **Required Fields**: Client Name, Assessment Date, Overall Score, Per-Strand Scores, Findings, Remediation Roadmap
- **Auto-Tags**: [type:ctga, classification:client-facing]
- **Compliance**: Maps to all Tier 1 frameworks via strand-to-control mapping
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Client-Facing
- **Key sections**: TLDR, Header table (client, assessment date, assessor, overall score 100-900, previous score if recurring, score delta), Score Overview table (4 strands: Controls max 225, Technology max 225, Growth max 225, Adoption max 225), Per-Strand Breakdown (each strand gets its own section with domain scoring table, observations, and strand-specific recommendations), Maturity Band (100-300 Reactive, 301-500 Developing, 501-700 Proactive, 701-900 Optimized), Findings by Priority (P1 Critical through P4 Low), Remediation Roadmap (phased: Phase 1 Quick Wins 0-30 days, Phase 2 Foundation 30-90 days, Phase 3 Maturation 90-180 days — each with projected score impact), Recommended Services, Next Assessment Date

**B5. Access Review Report**
- **When**: Quarterly or upon role change
- **ClickUp List**: 03 Security Operations > Access Reviews
- **Task Type**: access-review
- **Required Fields**: Review Period, Systems Reviewed, Accounts Reviewed, Findings
- **Auto-Tags**: [type:access-review, cadence:quarterly, domain:identity]
- **Compliance**: SOC 2 CC6.2/CC6.3, ISO 27001 A.9.2.5/A.9.2.6, NIST SP 800-53 AC-2
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Header table (review period, reviewer, review methodology), Systems Reviewed table (system name, total accounts, active, inactive, privileged, service accounts), Findings table (finding ID, system, account, issue [orphaned/excessive/shared/stale], remediation, status), Privileged Access Review (separate scrutiny for admin/root accounts), Service Account Review, Remediation Actions Taken, Exceptions Granted (with justification and expiry date), Compliance Mapping

**B6. Vulnerability Management Report**
- **When**: Monthly or after significant scan
- **ClickUp List**: 03 Security Operations > Vulnerabilities
- **Task Type**: vuln-report
- **Required Fields**: Scan Date, Scanner Used, Total Findings, Critical/High Counts, Remediation Status
- **Auto-Tags**: [type:vuln-report, cadence:monthly, domain:security]
- **Compliance**: SOC 2 CC7.1, ISO 27001 A.12.6.1, NIST SP 800-53 RA-5, PCI DSS 11.3
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Header table (scan date, scanner [Trivy/Grype/etc], scope, previous scan date), Summary table (severity: critical/high/medium/low/info, new this period, resolved, open, SLA status), Critical and High Findings Detail table (CVE ID, affected component, CVSS score, exploitable yes/no, remediation status, owner, due date), Trend Analysis (month-over-month), Mean Time to Remediate by severity, Exceptions/Risk Acceptances, Compliance Mapping

**B7. Evidence Collection Log**
- **When**: Ongoing — every time compliance evidence is collected
- **ClickUp List**: 05 Compliance Program > Evidence Vault
- **Task Type**: evidence-log
- **Required Fields**: Control ID, Evidence Type, Collection Date, Collector, Storage Location
- **Auto-Tags**: [type:evidence, domain:compliance]
- **Compliance**: ISO 27001 Clause 7.5, SOC 2 CC4.1
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Evidence Metadata table (evidence ID following naming convention `{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}`, control ID, control description, framework mapping, evidence type [screenshot/config export/log extract/policy document/attestation], collection date, collector name, storage location, retention period), Evidence Description (what this evidence proves and how it satisfies the control), Chain of Custody (who handled this evidence and when), Verification (how an auditor can independently verify this evidence), Compliance Mapping

**B8. Risk Acceptance Form**
- **When**: When a known risk is accepted rather than mitigated
- **ClickUp List**: 05 Compliance Program > Risk Register
- **Task Type**: risk-acceptance
- **Required Fields**: Risk Description, CVSS/Risk Score, Business Justification, Approval Authority, Review Date
- **Auto-Tags**: [type:risk-acceptance, domain:compliance]
- **Compliance**: SOC 2 CC3.3, ISO 27001 Clause 6.1.3, NIST SP 800-53 PM-9
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Risk Identification table (risk ID, description, affected systems, discovered date, discovered by), Risk Scoring table (likelihood, impact, overall score, CVSS if applicable), Business Justification (why accepting is preferable to mitigating — must be specific, not "too expensive"), Compensating Controls (what reduces residual risk), Approval Authority (tiered: P4 risks = team lead, P3 = engineering manager, P2 = VP/Director, P1 = CEO/owner — name, title, date, signature), Conditions of Acceptance (constraints — e.g., "accepted for 90 days only"), Review Date (no longer than 90 days out), Compliance Mapping

**B9. Vendor/Third-Party Risk Assessment**
- **When**: Before onboarding a new vendor or annually for existing vendors
- **ClickUp List**: 05 Compliance Program > Vendors
- **Task Type**: vendor-risk
- **Required Fields**: Vendor Name, Data Classification, Security Questionnaire Summary, Risk Rating, Approval
- **Auto-Tags**: [type:vendor-risk, domain:compliance]
- **Compliance**: SOC 2 CC9.2, ISO 27001 A.15.1/A.15.2, NIST SP 800-53 SA-9
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Vendor Information table (name, contact, service provided, contract dates, data shared, data classification [public/internal/confidential/restricted]), Security Posture Assessment (SOC 2 report available?, ISO 27001 certified?, penetration test results shared?, insurance?), Data Handling table (what data they access, where stored, encryption at rest, encryption in transit, retention, deletion process), Access Review (what access do they have to Helix Stax systems, how is it controlled), Risk Rating (Low/Medium/High/Critical with justification), Remediation Requirements (what the vendor must fix before approval or by a deadline), Approval Decision (approved/approved with conditions/rejected, approver, date), Next Review Date, Compliance Mapping

---

### Category C: Security (4 templates)

**C1. Bug Report**
- **When**: Any defect, regression, or unexpected behavior
- **ClickUp List**: 02 Platform Engineering > Backlog (or relevant project list)
- **Task Type**: bug
- **Required Fields**: TLDR, Steps to Reproduce, Expected vs Actual, Environment, Priority
- **Auto-Tags**: [type:bug]
- **Compliance**: SOC 2 CC7.1 (where security-related), CC8.1 (triggers change management)
- **Co-Author**: Petra Vanek (Test Engineer)
- **Key sections**: TLDR, Steps to Reproduce (numbered, exact), Expected Behavior, Actual Behavior, Environment table (service/component, version/image tag, cluster, namespace, URL), Priority (P1-P4 scale — NOT SEV), PHI/PII Flag (yes/no — does this bug expose or risk exposing protected health information or personally identifiable information?), Screenshots/Logs, Component/Service Affected checklist (Zitadel, Harbor, MinIO, ArgoCD/Devtron, Traefik, n8n, helixstax.com, CloudNativePG, Valkey, other), Workaround (if known), Compliance Mapping

**C2. Security Advisory**
- **When**: CVEs, vulnerability disclosures, or internal security findings
- **ClickUp List**: 03 Security Operations > Vulnerabilities
- **Task Type**: security-advisory
- **Required Fields**: TLDR, CVE/ID, Affected Systems, CVSS Score, Remediation Steps
- **Auto-Tags**: [type:security-advisory, domain:security]
- **Compliance**: SOC 2 CC7.1/CC7.2, ISO 27001 A.12.6.1, NIST SP 800-53 SI-5
- **Co-Author**: Ezra Raines (Security Engineer)
- **Classification**: Confidential (until remediated)
- **Key sections**: TLDR, CVE/ID table (CVE ID, internal ID if no CVE, NVD link, vendor advisory link), Affected Systems table (component, affected versions, patched version, deployed in Helix Stax yes/no), CVSS table (score, vector, severity rating, exploitability [remote/local/physical], authentication required [none/user/admin], exploit in the wild [yes/no/unknown]), Affected Clients field (list any client environments that are affected — critical for consulting firm), Discovery Method, Remediation Steps (exact commands), Workaround (if patching is delayed), Risk Acceptance (if remediation is deferred — requires Risk Acceptance Form B8, approval authority for accepting security risk), Disclosure Timeline table, Compliance Mapping

**C3. Incident Response Plan**
- **When**: Defining the response procedure for a specific incident TYPE (distinct from Post-Mortem which reviews AFTER)
- **ClickUp List**: 03 Security Operations > Incident Response
- **Task Type**: incident-response-plan
- **Required Fields**: Incident Type, Detection Methods, Response Steps, Communication Plan, Recovery Steps
- **Auto-Tags**: [type:ir-plan, domain:security]
- **Compliance**: SOC 2 CC7.3/CC7.4, ISO 27001 A.16.1, NIST CSF RS, HIPAA 164.308(a)(6)
- **Co-Author**: Ezra Raines (Security Engineer)
- **Key sections**: TLDR, Incident Type (what specific incident this plan covers — e.g., "ransomware", "data breach", "DDoS", "credential compromise"), Detection Methods (how this incident type is detected — alerts, indicators of compromise), Severity Classification (how to determine SEV-1 through SEV-4 for this incident type), Response Team table (role, name, contact, backup), Response Steps (phased: Identification, Containment, Eradication, Recovery, Lessons Learned — per NIST SP 800-61), Communication Plan (who to notify, when, how — internal team, management, clients, legal, regulators), Evidence Preservation (what to capture before remediation destroys forensic data), Recovery Steps, Compliance Mapping

**C4. Penetration Test Summary Report**
- **When**: After completing a penetration test for a client or internally
- **ClickUp List**: 03 Security Operations > Assessments OR 02 Delivery > {Client}
- **Task Type**: pen-test-report
- **Required Fields**: Scope, Methodology, Findings Summary, Critical/High Findings Detail
- **Auto-Tags**: [type:pen-test, classification:confidential]
- **Compliance**: SOC 2 CC7.1, PCI DSS 11.3/11.4, ISO 27001 A.18.2.3
- **Co-Author**: Ezra Raines (Security Engineer)
- **Classification**: Confidential
- **Key sections**: TLDR, Engagement Details table (client, dates, scope, methodology [OWASP/PTES/NIST], tester, report date), Executive Summary (for non-technical leadership), Scope table (in-scope systems/networks/applications, out-of-scope items, testing type [black box/grey box/white box]), Findings Summary table (severity, count, remediated during test, open), Detailed Findings (per finding: ID, title, severity, CVSS, description, evidence/screenshots, remediation recommendation, references), Positive Observations (what the client is doing well — important for client relationship), Remediation Priority Matrix, Compliance Mapping

---

### Category D: Infrastructure (4 templates)

**D1. Deployment Verification Checklist**
- **When**: After every production deployment
- **ClickUp List**: 02 Platform Engineering > Deployments
- **Task Type**: deployment-verification
- **Required Fields**: Service Deployed, Version, Pre-Deploy Checks, Post-Deploy Checks, Rollback Tested
- **Auto-Tags**: [type:deploy-verify, phase:deploy]
- **Compliance**: SOC 2 CC8.1, ISO 27001 A.14.2.2
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Deployment Metadata table (service, version/tag, deployer, pipeline run link, environment, deployment method [Helm/ArgoCD/manual]), Pre-Deployment Checklist (change request approved, tests passing, staging verified, rollback plan documented, database migrations reviewed), Deployment Steps (what was executed), Post-Deployment Checklist (health check endpoints responding, logs clean, metrics nominal, alerting configured, smoke tests passed), Rollback Tested field (was rollback actually tested in staging? yes/no — if no, justify), Compliance Mapping

**D2. Infrastructure Provisioning Checklist**
- **When**: Provisioning new servers, clusters, or cloud resources
- **ClickUp List**: 02 Platform Engineering > Infrastructure
- **Task Type**: provisioning
- **Required Fields**: Resource Type, Provider, CIS Benchmark Gates, Hardening Verification
- **Auto-Tags**: [type:provisioning, domain:infrastructure]
- **Compliance**: CIS Benchmarks, SOC 2 CC6.1, NIST SP 800-53 CM-2/CM-6, ISO 27001 A.12.1.1
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Resource Details table (type, provider [Hetzner], region, OS [AlmaLinux 9.7], specs), CIS Benchmark Gates checklist (each gate = a CIS control that must pass before proceeding — SELinux enforcing, SSH hardened, firewall configured, unnecessary services disabled, audit logging enabled, etc.), Network Configuration, Access Control (SSH keys, Zitadel OIDC, OpenBao policies), Monitoring Setup (Prometheus endpoint, Grafana dashboard, Loki log shipping, Alertmanager rules), Backup Configuration (Velero schedule, retention policy), Hardening Verification (how was hardening verified — CIS-CAT scan results, manual checks), Compliance Mapping

**D3. Capacity Planning Report**
- **When**: Quarterly or when approaching resource thresholds
- **ClickUp List**: 04 Service Management > Capacity
- **Task Type**: capacity-report
- **Required Fields**: Current Utilization, Growth Trend, Projected Exhaustion Date, Recommendations
- **Auto-Tags**: [type:capacity, cadence:quarterly, domain:infrastructure]
- **Compliance**: SOC 2 A1.1, ISO 27001 A.12.1.3
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Current Cluster Resources table (node, CPU allocated/total, memory allocated/total, storage used/total, % utilized), Per-Service Resource Consumption table (service, CPU requests/limits, memory requests/limits, storage, replica count), Growth Trend (month-over-month resource consumption), Projected Exhaustion Date (at current growth rate, when does each resource type hit 80% and 100%?), Bottleneck Analysis (what runs out first?), Cost Analysis (current monthly cost, projected cost), Recommendations (scale up, scale out, optimize, or no action), Compliance Mapping

**D4. DR Test Report**
- **When**: Semi-annually or after significant infrastructure changes
- **ClickUp List**: 04 Service Management > DR/BCP
- **Task Type**: dr-test
- **Required Fields**: Test Date, Scenarios Tested, RTO/RPO Results, Findings
- **Auto-Tags**: [type:dr-test, cadence:semi-annual, domain:infrastructure]
- **Compliance**: SOC 2 A1.2/A1.3, ISO 27001 A.17.1.3, NIST SP 800-53 CP-4
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Test Metadata table (test date, test lead, participants, test type [tabletop/partial failover/full failover]), Scenarios Tested table (scenario ID, description, expected RTO, actual RTO, expected RPO, actual RPO, result [pass/fail]), Detailed Scenario Results (per scenario: steps executed, observations, issues encountered), Backup Verification (were backups successfully restored? Velero restore tested? Data integrity confirmed?), Communication Test (was the communication plan activated? Response times?), Findings table (finding, severity, remediation, owner, due date), Compliance Mapping

---

### Category E: Client Delivery (6 templates)

**E1. Client Proposal**
- **When**: Responding to a prospect or pitching a new engagement
- **ClickUp List**: 01 Business Operations > Sales
- **Task Type**: proposal
- **Required Fields**: Client Name, Executive Summary, Service Scope, Pricing, Timeline
- **Auto-Tags**: [type:proposal, classification:client-facing]
- **Compliance**: N/A (business document, but compliance capabilities are a selling point)
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Client-Facing
- **Key sections**: Cover Page (Helix Stax branding, client name, date, prepared by Wakeem Williams), Executive Summary (client challenges restated in their language, proposed value — max 1 page), Understanding of Your Challenges (show you listened — bullet their pain points), Proposed Solution (what Helix Stax will do, mapped to their challenges), Service Scope table (service, description, deliverables, duration), Timeline with Milestones, Pricing Tiers table (use anchoring: Tier 1 Assessment, Tier 2 Managed, Tier 3 Premium — present highest first), Investment Summary (reframe "cost" as "investment"), Why Helix Stax (differentiators: CTGA framework, 23 AI agents, compliance-first, SOC 2 ready infrastructure), About Wakeem Williams (brief founder bio), Engagement Terms (payment, IP, confidentiality), Next Steps (clear call to action with specific next meeting date)

**E2. Statement of Work (SOW)**
- **When**: After proposal acceptance, before work begins
- **ClickUp List**: 01 Business Operations > Sales OR 02 Delivery > {Client}
- **Task Type**: sow
- **Required Fields**: Scope, Deliverables, Timeline, Pricing, Acceptance Criteria, Change Control
- **Auto-Tags**: [type:sow, classification:client-facing]
- **Compliance**: N/A (contractual document)
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Client-Facing
- **Key sections**: Header table (project title, client, Helix Stax contact, effective date, end date, SOW number), Scope of Work (detailed description of what is included and explicitly what is excluded), Deliverables table (deliverable ID, description, format, due date, acceptance criteria), Timeline/Milestones table, Pricing table (item, unit, quantity, rate, total), Payment Terms (schedule, method, late payment policy), Change Control Process (how scope changes are requested, evaluated, priced, and approved), Assumptions (conditions that must remain true for this SOW to hold), Roles and Responsibilities (client vs Helix Stax), Acceptance Process (how deliverables are accepted or rejected), Termination clause, Signature blocks (client + Helix Stax)

**E3. SLA Definition**
- **When**: Defining service level agreements for managed services clients
- **ClickUp List**: 02 Delivery > {Client} > SLAs
- **Task Type**: sla
- **Required Fields**: Service Name, SLA Tiers, Uptime Target, Response Time, Resolution Time
- **Auto-Tags**: [type:sla, classification:client-facing]
- **Compliance**: SOC 2 A1.1, ISO 27001 A.15.2.1
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Client-Facing
- **Key sections**: TLDR, Service Description, SLA Tiers table (Platinum: 4hr response/8hr resolution, Gold: 8hr response/24hr resolution, Silver: 24hr response/48hr resolution, Bronze: 48hr response/5-day resolution), Uptime Targets (99.9%, 99.5%, etc. with corresponding allowable downtime per month), Response Time vs Resolution Time (define the distinction clearly), Escalation Path table (timeframe, action, contact), Exclusions (scheduled maintenance, force majeure, client-caused issues), SLA Credits/Penalties table (breach threshold, credit percentage), Measurement Method (how uptime and response times are measured — Grafana dashboards, incident tickets), Reporting Frequency (monthly SLA reports), Compliance Mapping

**E4. Client Health Score Report**
- **When**: Monthly or quarterly for active managed services clients
- **ClickUp List**: 00 Delivery Operations > Health Scores
- **Task Type**: health-score
- **Required Fields**: Client Name, Reporting Period, Overall Score, Component Scores
- **Auto-Tags**: [type:health-score, cadence:monthly, classification:internal]
- **Compliance**: SOC 2 CC2.3 (communication)
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Internal
- **Key sections**: TLDR, Client Metadata table (client, engagement type, start date, account manager), Overall Health Score (1-10 scale with color: 8-10 Green, 5-7 Yellow, 1-4 Red), Component Scores table (category: Infrastructure Stability, Security Posture, Ticket Resolution, Client Satisfaction, Contract Health — each scored 1-10 with trend arrow), Key Metrics table (uptime %, mean time to resolve, open tickets, SLA breaches this period), Risks and Concerns, Opportunities (upsell, expansion), Action Items, Comparison to Previous Period

**E5. Client Onboarding Checklist**
- **When**: New client engagement begins
- **ClickUp List**: 00 Delivery Operations > Onboarding
- **Task Type**: client-onboarding
- **Required Fields**: Client Name, Engagement Type, Primary Contact, All checklist items
- **Auto-Tags**: [type:client-onboarding, phase:onboard]
- **Compliance**: SOC 2 CC9.2 (vendor management from client perspective), ISO 27001 A.15.1
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Client Details table (name, primary contact, technical contact, billing contact, industry, engagement type), Pre-Kickoff checklist (SOW signed, NDA signed, invoice sent, payment received, ClickUp folder created, Rocket.Chat channel created, welcome email sent), Access Setup checklist (client portal access, monitoring dashboard access [read-only Grafana], shared drive folder, Zitadel guest account if needed), Kickoff Meeting checklist (introductions complete, scope reviewed, timeline confirmed, communication cadence agreed, escalation contacts exchanged), Technical Setup checklist (network connectivity, VPN/access verified, initial assessment scheduled, baseline documentation collected), Compliance Setup checklist (data classification agreed, data handling procedures shared, compliance requirements confirmed, BAA signed if HIPAA), Compliance Mapping

**E6. Client Offboarding Checklist**
- **When**: Client engagement ends (completion, termination, or transition)
- **ClickUp List**: 00 Delivery Operations > Offboarding
- **Task Type**: client-offboarding
- **Required Fields**: Client Name, Offboarding Reason, All checklist items
- **Auto-Tags**: [type:client-offboarding, phase:offboard]
- **Compliance**: SOC 2 CC6.5 (access revocation), ISO 27001 A.15.2.2
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Client Details table (name, engagement end date, offboarding reason [completed/terminated/transitioned], knowledge transfer required yes/no), Access Revocation checklist (Zitadel guest account deactivated NOT deleted for audit trail, Grafana access removed, Rocket.Chat channel archived, shared drive access removed, VPN/network access removed, all client-specific credentials rotated), Data Handling checklist (client data exported and delivered, client data deleted from Helix Stax systems per retention policy, deletion confirmation sent to client, data handling attestation signed), Knowledge Transfer checklist (documentation delivered, runbooks transferred, training completed if applicable), Financial checklist (final invoice sent, payment received, contract officially closed), Post-Engagement checklist (client health score final entry, lessons learned captured, feedback requested, ClickUp folder archived), Compliance Mapping

---

### Category F: Agile/Sprint (3 templates)

**F1. Sprint Planning Template**
- **When**: Sprint planning ceremony (start of each sprint)
- **ClickUp List**: Relevant project list in 02 Platform Engineering or 02 Delivery
- **Task Type**: sprint-planning
- **Required Fields**: Sprint Number, Sprint Goal, Capacity, Selected Items
- **Auto-Tags**: [type:sprint-planning, phase:plan]
- **Compliance**: N/A
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Sprint Metadata table (sprint number, start date, end date, duration, team capacity in points), Sprint Goal (one clear sentence — what does "success" look like at the end of this sprint?), Carried Over from Previous Sprint table (task, points, reason for carry-over), Selected Items table (task ID, title, priority, estimate, assignee, acceptance criteria summary), Total Commitment (points committed vs capacity), Risks/Dependencies (what could block this sprint), Definition of Done (sprint-level — all items meet their individual DoD, demo completed, retro scheduled)

**F2. Sprint Review / Retrospective**
- **When**: End of each sprint
- **ClickUp List**: Relevant project list
- **Task Type**: sprint-retro
- **Required Fields**: Sprint Number, Velocity, Completed Items, What Went Well, What Didn't, Action Items
- **Auto-Tags**: [type:sprint-retro, phase:review]
- **Compliance**: N/A
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Sprint Metadata table (sprint number, dates, sprint goal achieved yes/no), Velocity table (planned points, completed points, carry-over points, velocity trend last 3 sprints), Completed Items table (task ID, title, points, assignee, demo-ready yes/no), Carried Over table (task ID, title, points, reason), Demo Notes (what was demonstrated, stakeholder feedback), What Went Well (bullets — celebrate wins), What Didn't Go Well (bullets — no blame, focus on process), Action Items table (action, owner, due date, status — carry forward until done)

**F3. Backlog Grooming Notes**
- **When**: Backlog refinement sessions
- **ClickUp List**: Relevant project list
- **Task Type**: grooming
- **Required Fields**: Items Reviewed, Estimates Applied, Items Deferred
- **Auto-Tags**: [type:grooming, phase:plan]
- **Compliance**: N/A
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Session Metadata table (date, attendees, items reviewed count, duration), Items Reviewed table (task ID, title, current priority, estimate applied, ready for sprint yes/no, notes), Items Deferred table (task ID, title, reason deferred), Items Split (items that were too large and were broken into smaller tasks), New Items Added (items that emerged during grooming), Decisions Made (any priority changes, scope clarifications)

---

### Category G: Communication (2 templates)

**G1. Meeting Notes**
- **When**: Any scheduled meeting
- **ClickUp List**: Relevant project/engagement list
- **Task Type**: meeting
- **Required Fields**: Date, Attendees, Agenda, Decisions Made, Action Items
- **Auto-Tags**: [type:meeting]
- **Compliance**: ISO 27001 Clause 7.5 (where decisions affect security), SOC 2 CC2.3
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR (one-line summary of what was decided), Meeting Metadata table (date, time, duration, location/link, facilitator), Attendees table (name, role, present yes/no), Agenda (numbered items), Discussion Points (per agenda item — key points only, not a transcript), Decisions Made (numbered — each decision is a clear statement, not a discussion), Action Items table (action, owner, due date, status), Next Meeting (date, time, agenda preview if known), Compliance Mapping (only if meeting involved compliance-relevant decisions)

**G2. Discovery Session Notes**
- **When**: Initial client discovery call or requirements gathering session
- **ClickUp List**: 01 Business Operations > Sales OR 02 Delivery > {Client}
- **Task Type**: discovery
- **Required Fields**: Client Name, Attendees, Business Challenges, Technical Environment, Next Steps
- **Auto-Tags**: [type:discovery, phase:prepare]
- **Compliance**: N/A
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Confidential
- **Key sections**: TLDR (one-line summary of client situation and fit), Client Information table (company, industry, size, revenue range, current IT team size), Attendees table (name, title, role in decision), Business Challenges (what problems did they describe — use their words), Current Environment (infrastructure, key vendors, compliance requirements, pain points), Decision Criteria (what matters to them: cost, speed, compliance, expertise?), Budget Indicators (budget range if shared, fiscal year timing, procurement process), Timeline (urgency, any hard deadlines), Competition (other vendors they are evaluating if mentioned), Fit Assessment (internal only — is this a good fit for Helix Stax? why/why not?), Next Steps (specific actions with dates), Follow-Up Items (questions to research before next meeting)

---

### Category H: Release & Integration (3 templates)

**H1. Release Notes**
- **When**: Every production release
- **ClickUp List**: 02 Platform Engineering > Releases
- **Task Type**: release
- **Required Fields**: Version, Release Date, Summary, Changes, Rollback Tested
- **Auto-Tags**: [type:release, phase:deploy]
- **Compliance**: SOC 2 CC8.1 (change management), ISO 27001 A.14.2.2
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Release Metadata table (version, release date, release type [major/minor/patch/hotfix], deployed by, pipeline run link), Summary (2-4 sentences for a non-technical reader), New Features (bulleted with issue/PR links), Bug Fixes (bulleted with issue/PR links), Improvements/Enhancements, Breaking Changes table (change, impact, required action — bold if any exist), Known Issues table (issue, workaround), Compliance Impact (does this release affect any compliance controls? which ones?), Upgrade Instructions (step-by-step including database migrations if any), Rollback Tested field (was rollback tested in staging before this release? yes/no), Rollback Instructions (exact commands), Dependencies Updated table (dependency, previous version, new version, notes), Compliance Mapping

**H2. Feature Request**
- **When**: Proposing new capabilities, integrations, or improvements
- **ClickUp List**: 07 Product & Strategy > Roadmap OR relevant project list
- **Task Type**: feature
- **Required Fields**: TLDR, Problem Statement, Proposed Solution, Acceptance Criteria, Priority
- **Auto-Tags**: [type:feature]
- **Compliance**: SOC 2 CC8.1 (if feature changes production systems)
- **Co-Author**: Sable Navarro (Product Manager)
- **Key sections**: TLDR, Problem Statement (who is affected, current behavior, pain — be specific), Proposed Solution, Acceptance Criteria checklist (Given/When/Then format), Priority (P1-P4 with justification), Compliance Impact (does this feature affect compliance posture? does it need a compliance review before implementation?), Effort Sizing (T-shirt size: XS/S/M/L/XL with rough hour ranges), Alternatives Considered table (alternative, why rejected), Dependencies, Out of Scope, Compliance Mapping

**H3. n8n Workflow README**
- **When**: Documenting any n8n automation workflow
- **ClickUp List**: 06 Process Library > Automation Recipes
- **Task Type**: workflow-readme
- **Required Fields**: TLDR, Trigger, Flow Description, Credentials Required, Error Handling
- **Auto-Tags**: [type:n8n-workflow, domain:automation]
- **Compliance**: SOC 2 CC6.1 (if workflow handles access), CC8.1 (if workflow makes changes)
- **Co-Author**: Nix Patel (Automation Engineer)
- **Key sections**: TLDR (one sentence: what it does and when it runs), Trigger table (trigger type [webhook/cron/event/manual], trigger detail, cron expression if applicable, webhook URL if applicable, expected frequency), Data Classification (what data does this workflow process? [public/internal/confidential/restricted] — critical for compliance), Flow Description (step-by-step data path: "When X happens, Y is fetched from Z, transformed into W, and sent to V"), What It Creates/Modifies table (system, action, detail), Credentials Required table (credential name in n8n, service, stored in OpenBao yes/no, rotation schedule), Error Handling (on node failure behavior, retry config, error notification destination), Rate Limits (API rate limits to be aware of), Dependencies table (dependency, type [workflow/service/API], notes), Last Tested Date (when was this workflow last manually verified?), Debugging Guide (how to test, sample payloads, common failure modes table, where to find logs), Version History table, Compliance Mapping

---

### Category I: Incident & Change (3 templates)

**I1. Incident Report**
- **When**: Any unplanned service interruption or degradation (the report, not the post-mortem analysis)
- **ClickUp List**: 04 Service Management > Incidents
- **Task Type**: incident
- **Required Fields**: TLDR, Detection, Severity, Affected Services, Timeline, Immediate Actions
- **Auto-Tags**: [type:incident, domain:operations]
- **Compliance**: SOC 2 CC7.2/CC7.3, ISO 27001 A.16.1.2, NIST CSF RS.RP
- **Co-Author**: Kit Morrow (Infrastructure Engineer)
- **Key sections**: TLDR, Detection table (detected at, detected by, detection method [Grafana alert/Rocket.Chat notification/user complaint/manual check], time to detection), Severity (SEV-1 through SEV-4 with response time SLAs per severity), Affected Services table (service, namespace, cluster, impact), Impact table (users affected, duration, data loss yes/no, revenue impact, client-facing yes/no), PHI/PII Flag (was protected health information or personally identifiable information potentially exposed? yes/no — if yes, triggers HIPAA/GDPR notification requirements), SLA Breach field (did this incident breach any client SLA? which client, which SLA metric?), Timeline table (UTC timestamps), Immediate Actions Taken (numbered with commands), Escalation Tracking (was it escalated? to whom? when? was escalation timely per SLA?), Resolution, Root Cause (brief — full analysis in Post-Mortem), Compliance Mapping

**I2. CAB Record (Change Advisory Board)**
- **When**: CAB meeting to review change requests (per ITIL 4)
- **ClickUp List**: 04 Service Management > Changes
- **Task Type**: cab-record
- **Required Fields**: Meeting Date, Changes Reviewed, Decisions
- **Auto-Tags**: [type:cab, domain:itil]
- **Compliance**: SOC 2 CC8.1, ISO 27001 A.12.1.2, ITIL 4 Change Enablement
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, CAB Meeting Metadata table (date, time, attendees, facilitator), Changes Reviewed table (change request ID, title, requester, type [standard/normal/emergency], risk level, decision [approved/rejected/deferred/returned for more info], conditions, approver), Approved Changes Summary (brief notes on each approved change), Rejected/Deferred Changes (reason for rejection or deferral, what is needed to reconsider), Emergency Changes Ratified (emergency changes that were implemented and now need formal ratification), Upcoming Changes (preview of changes expected at next CAB), Action Items, Next CAB Date, Compliance Mapping

**I3. Service Request**
- **When**: Any standard service request (access, provisioning, information)
- **ClickUp List**: 04 Service Management > Service Requests
- **Task Type**: service-request
- **Required Fields**: Requester, Request Type, Description, Priority
- **Auto-Tags**: [type:service-request, domain:itil]
- **Compliance**: SOC 2 CC6.2 (if access-related), ITIL 4 Service Request Management
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Requester Information table (name, role, department, contact), Request Type (access request, account provisioning, information request, configuration change, other), Request Description (what is being requested and why), Priority (P1-P4), Approval Required (yes/no, if yes who), Fulfillment Steps (what was done to fulfill the request), Completion Verification (requester confirmed the request is fulfilled), Compliance Mapping

---

### Category J: People (2 templates)

**J1. Onboarding Checklist (Team Member)**
- **When**: New team member joins
- **ClickUp List**: 01 Business Operations > HR
- **Task Type**: onboarding
- **Required Fields**: Name, Role, Start Date, Manager, All checklist items
- **Auto-Tags**: [type:onboarding, domain:hr]
- **Compliance**: SOC 2 CC1.4 (accountability), CC6.2 (access provisioning), ISO 27001 A.7.1
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, New Hire Details table (name, role, start date, manager, department), Day 1 — Access Provisioning checklist (ClickUp invite + role assignment, GitHub org + team, Google Workspace, Zitadel user + groups, Grafana account + role, Rocket.Chat channels, Devtron access if Senior+, OpenBao scoped policy, MDM enrollment if applicable, device issued and serial number logged), Day 1 — Orientation checklist (workspace README walkthrough, CI/CD pipeline orientation, monitoring dashboards orientation, team introductions, key contacts shared), Week 1 — Training checklist (security awareness training assigned and completed, compliance training for relevant frameworks, tool-specific training), Week 1 — Documentation checklist (NDA signed, employment agreement signed, acceptable use policy signed, access logged in audit trail), Compliance Mapping

**J2. Offboarding Checklist (Team Member)**
- **When**: Team member departs (resignation, termination, contract end)
- **ClickUp List**: 01 Business Operations > HR
- **Task Type**: offboarding
- **Required Fields**: Name, Role, Last Day, Offboarding Reason, All checklist items
- **Auto-Tags**: [type:offboarding, domain:hr]
- **Compliance**: SOC 2 CC6.5 (access revocation), ISO 27001 A.7.3, NIST SP 800-53 PS-4
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Key sections**: TLDR, Departing Member Details table (name, role, last day, reason [resignation/termination/contract end], manager, knowledge transfer required yes/no), Access Revocation checklist (ClickUp removed, GitHub removed — check open PRs first, Google Workspace access removed — verify no personal files in shared drives, Zitadel deactivated NOT deleted for audit trail, Grafana deactivated, Devtron access removed, OpenBao policies revoked + shared secret rotation triggered, Rocket.Chat removed, MDM device wiped if applicable), Knowledge Transfer checklist (documentation updated, runbooks current, handoff meetings completed), IP and Security checklist (IP assignment reviewed, any client access revoked, devices returned, device wiped and verified), Client Notification (if departing member was a client contact — notify client of new contact), Financial checklist (final payroll processed, benefits terminated, expense reports settled), Exit Interview (conducted yes/no, feedback captured), Audit Trail (all access removal logged with timestamps), Compliance Mapping

---

### Category K: Reference Docs (3 templates)

These are full-content reference documents, not fill-in templates. Generate them with complete, production-ready content based on the Helix Stax workspace structure described in Section 2.

**K1. Workspace README**
- **ClickUp List**: Top-level Doc in 01 Platform space
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Classification**: Internal
- **Content**: What is this workspace (two spaces: 01 Platform for internal ops, 02 Delivery for client work), folder structure explained per folder (all 7 Platform folders + Delivery Operations folder), naming conventions (numbered folders, imperative task names, [BUG]/[INC] prefixes), tag taxonomy (domain:, type:, env:, svc:, phase:, modifiers), required fields (every task must have assignee + priority), agent attribution model (23 agents with full names from the attribution table), key automations overview, key views, links to templates

**K2. Onboarding Guide: First 5 Minutes**
- **ClickUp List**: Top-level Doc in 01 Platform space
- **Co-Author**: Quinn Mercer (Documentation Lead)
- **Classification**: Internal
- **Content**: Step-by-step for new team members: (1) Read this doc, (2) Understand two spaces (01 Platform = internal, 02 Delivery = clients), (3) Find your first task in My Work view, (4) Naming rules for tasks, (5) Tag system explained, (6) Where to ask questions (Rocket.Chat #general), (7) Key contact (Wakeem Williams, admin@helixstax.com), (8) Required training (security awareness, compliance basics)

**K3. Compliance Quick Reference**
- **ClickUp List**: 05 Compliance Program (top-level Doc)
- **Co-Author**: Ezra Raines (Security Engineer)
- **Classification**: Internal
- **Content**: Framework-to-ClickUp-list mapping table (NIST CSF -> which lists, SOC 2 -> which lists, ISO 27001 -> which lists), how to find any control in under 2 minutes (step-by-step), UCM structure explained (Unified Control Matrix — ~80 controls mapped across frameworks), evidence naming convention with field breakdown table (`{CONTROL-ID}_{TYPE}_{DATE}_{VERSION}`), evidence types reference table (screenshot, config export, log extract, policy document, attestation), common auditor requests table (what auditors ask for, where to find it in ClickUp, who to contact)

---

### Category L: Business (2 templates)

**L1. Invoice Template**
- **When**: Billing a client
- **ClickUp List**: 01 Business Operations > Finance
- **Task Type**: invoice
- **Required Fields**: Client Name, Invoice Number, Line Items, Total, Payment Terms
- **Auto-Tags**: [type:invoice, classification:client-facing]
- **Compliance**: N/A
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Client-Facing
- **Key sections**: TLDR, Invoice Header (Helix Stax company details, client billing details, invoice number [INV-YYYY-NNN], invoice date, due date, PO number if applicable), Line Items table (item description, quantity, unit price, total), Subtotal, Tax (if applicable), Total Due, Payment Terms (net-30/net-15/due on receipt, accepted methods, wire transfer details, late payment policy), Notes (any additional terms or references to SOW), Footer with Helix Stax contact

**L2. NDA / Confidentiality Agreement**
- **When**: Before sharing confidential information with prospects, partners, or contractors
- **ClickUp List**: 01 Business Operations > Legal
- **Task Type**: nda
- **Required Fields**: Parties, Effective Date, Confidential Information Definition, Term
- **Auto-Tags**: [type:nda, classification:confidential]
- **Compliance**: SOC 2 CC1.4, ISO 27001 A.13.2.4
- **Co-Author**: Sable Navarro (Product Manager)
- **Classification**: Confidential
- **Key sections**: TLDR, Parties table (disclosing party, receiving party, addresses, contacts), Effective Date, Definition of Confidential Information (what is covered — should include: technical data, business information, client information, CTGA methodology, proprietary frameworks), Exclusions (what is NOT confidential — publicly available, independently developed, received from third party without restriction), Obligations of Receiving Party (protect with reasonable care, limit access, no reverse engineering), Permitted Disclosures (legal requirement, with notice to disclosing party), Term (duration of agreement and survival period for obligations), Return/Destruction of Information, Remedies (injunctive relief), Governing Law, Signature Blocks

---

## Section 6: ClickUp Integration Map

Generate a complete mapping table showing how every template connects to the ClickUp workspace:

```markdown
## ClickUp Integration Map

| # | Template | ClickUp List | Task Type | Auto-Attach Trigger | Auto-Tags |
|---|----------|-------------|-----------|---------------------|-----------|
| A1 | Runbook | 06 Process Library > Runbooks | runbook | Task created with type "runbook" | type:runbook, phase:operate |
| A2 | SOP | 06 Process Library > SOPs | sop | Task created with type "sop" | type:sop, phase:operate |
| ... | ... | ... | ... | ... | ... |
```

Complete this table for ALL ~46 templates. The "Auto-Attach Trigger" column should specify the ClickUp automation trigger condition (typically: task created in specific list, or task type set to specific value).

---

## Section 7: Existing Templates to Fix

Six templates already exist locally and need to be upgraded to match the new standards. When generating these 6 templates (C1 Bug Report, H2 Feature Request, I1 Incident Report, C2 Security Advisory, H1 Release Notes, H3 n8n Workflow README), apply these specific fixes:

| Fix | Details |
|-----|---------|
| **Replace Telegram** | All references to "Telegram notification" or "Telegram" must be replaced with "Rocket.Chat" |
| **Replace Redis** | All references to "Redis" must be replaced with "Valkey" |
| **Add YAML frontmatter** | None of the existing templates have frontmatter — add it per Section 4.2 |
| **Add Compliance Mapping** | None of the existing templates have a compliance mapping section — add it per Section 4.3 |
| **Add Definition of Done** | None of the existing templates have this — add it per Section 4.3 |
| **Add PHI/PII flag** | Bug Report and Incident Report need a PHI/PII exposure flag |
| **Add Example** | None of the existing templates have a filled-in example — add at least one per template |
| **Fix footer** | Add "Last Reviewed" and "Classification" fields to footer |
| **Fix Co-Author** | Match Co-Author to template domain (security templates = Ezra Raines, not Quinn Mercer; infrastructure templates = Kit Morrow; testing = Petra Vanek) |
| **Fix Priority/Severity** | Bug Report currently uses SEV scale — should use P (Priority) scale. Only Incident Report and Post-Mortem use SEV. |

---

## Section 8: Output Format

### Per-Template Format

Each template should be output as a **complete, ready-to-use markdown file** containing:

1. YAML frontmatter (per Section 4.2)
2. Title line: `# TEMPLATE: {Name}`
3. Subtitle: one line explaining when to use this template
4. All body sections with placeholder guidance text (HTML comments or descriptive text explaining what to write in each field)
5. `[REQUIRED]` / `[OPTIONAL]` markers on every field
6. Compliance Mapping table
7. Definition of Done checklist
8. At least one filled-in example using realistic Helix Stax scenarios
9. Footer (per Section 4.4)

### Template Length

- Simple templates (Meeting Notes, Service Request): 50-80 lines
- Standard templates (Bug Report, Feature Request, ADR): 80-120 lines
- Complex templates (CTGA Assessment, Client Proposal, Incident Response Plan, Post-Mortem): 120-200 lines

### Output Structure

Output ALL ~46 templates in one response. Separate each template with:

```
---
<!-- END TEMPLATE: {Name} -->
---
<!-- BEGIN TEMPLATE: {Next Name} -->
---
```

### Category Order

Output in this order: A (Operational), B (Compliance), C (Security), D (Infrastructure), E (Client Delivery), F (Agile/Sprint), G (Communication), H (Release & Integration), I (Incident & Change), J (People), K (Reference Docs), L (Business).

---

Generate all templates now. Apply your research findings to every template. Make each one best-in-class.

## PROMPT END
