# ADR-011: SOC 2 First Compliance Pursuit Order

## TLDR

Pursue SOC 2 Type I first (Month 3), then Type II (Month 9), then ISO 27001 (Month 12+). HIPAA and CMMC addressed per-client demand only.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax is an infrastructure consultancy that must demonstrate security credibility to prospective clients. Multiple compliance frameworks are relevant: SOC 2 (most requested by US enterprise buyers), ISO 27001 (international recognition), HIPAA (healthcare clients), CMMC (defense industrial base), and NIST 800-171 (controlled unclassified information).

Pursuing all frameworks simultaneously is infeasible for a single-operator organization. Each framework requires audit preparation, evidence collection, policy documentation, and auditor engagement. However, significant control overlap exists between frameworks -- approximately 80% of SOC 2 controls map directly to ISO 27001.

The strategic question is: which framework provides the fastest credibility with the target market while building a foundation that minimizes effort for subsequent certifications?

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: SOC 2 first | Type I -> Type II -> ISO 27001 | Fastest US market credibility, 80% overlap with ISO | US-centric, ISO requires separate audit | Builds foundation for all other frameworks |
| **Option B**: ISO 27001 first | ISO certification, then SOC 2 | International recognition, comprehensive ISMS | Longer initial timeline (~12 months), less US market impact | Strong foundation, slower market entry |
| **Option C**: Dual pursuit | SOC 2 + ISO 27001 simultaneously | Both certifications faster | Double the audit effort and cost, resource infeasible for single operator | Maximum coverage, maximum burden |
| **Option D**: HIPAA first | HIPAA compliance, then others | Immediate healthcare market access | Narrow market, no formal certification (self-attestation) | Limited credibility outside healthcare |

---

## Decision

We will pursue compliance certifications in the following order:

**Phase 1 -- SOC 2 Type I (Target: Month 3):**
- Point-in-time assessment of control design
- Demonstrates that security controls exist and are properly designed
- Requires: policies, procedures, technical controls, evidence of design
- Output: SOC 2 Type I report from CPA firm

**Phase 2 -- SOC 2 Type II (Target: Month 9, after 6-month observation):**
- Assesses operating effectiveness of controls over a 6-month observation period
- Observation window begins after Type I completion
- Requires: continuous evidence collection, automated scanning, incident response records
- Output: SOC 2 Type II report (the gold standard for enterprise buyers)

**Phase 3 -- ISO 27001:2022 (Target: Month 12+):**
- Leverages 80% control overlap with SOC 2
- ISMS documentation largely complete from SOC 2 preparation
- Gap analysis focuses on ISO-specific controls (risk treatment plans, management review)
- Output: ISO 27001 certificate (3-year validity with annual surveillance audits)

**Phase 4 -- HIPAA / CMMC / NIST 800-171 (On demand):**
- Addressed per-client contractual requirement only
- Infrastructure is inherently compliant through SOC 2 + ISO 27001 controls
- HIPAA requires Business Associate Agreement and specific safeguard documentation
- CMMC requires assessment by C3PAO (Certified Third-Party Assessment Organization)

---

## Rationale

SOC 2 is the most requested compliance certification in the US enterprise market. Type I can be achieved in approximately 3 months, providing immediate credibility for sales conversations. The 6-month Type II observation window runs in the background while the business operates normally -- the infrastructure automation (Airflow DAGs, OpenSCAP scanning, evidence archival) generates evidence continuously. ISO 27001 builds on 80% of the same controls, making it an efficient follow-on rather than a parallel effort. Pursuing HIPAA or CMMC without a specific client contract is premature investment.

---

## Consequences

### Positive

- Fastest path to market credibility (SOC 2 Type I in ~3 months)
- Automated evidence collection (ADR-012, ADR-013) runs during Type II observation
- 80% control reuse from SOC 2 to ISO 27001 minimizes duplication
- Per-client frameworks (HIPAA, CMMC) addressed only when revenue justifies investment
- UCM (Unified Control Matrix) in ClickUp maps controls across all frameworks

### Negative

- No ISO 27001 certification for 12+ months -- may lose international prospects
- SOC 2 Type II requires 6-month observation before report issuance
- CPA firm engagement costs for SOC 2 audits (~$20-50K depending on scope)
- HIPAA/CMMC deferred -- healthcare and defense clients must wait
- Single-operator environment may raise auditor concerns about segregation of duties

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Complete UCM control mapping in ClickUp | Wakeem Williams | 2026-04-13 | TBD |
| Draft SOC 2 policies (information security, access control, change management) | Wakeem Williams | 2026-04-27 | TBD |
| Engage CPA firm for SOC 2 Type I readiness assessment | Wakeem Williams | 2026-05-15 | TBD |
| Deploy automated evidence collection (ADR-012, ADR-013) | Wakeem Williams | 2026-05-01 | TBD |
| Begin SOC 2 Type II observation period | Wakeem Williams | 2026-06-01 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| ClickUp (Compliance Program) | UCM, evidence tracking, audit preparation lists |
| Airflow | DAGs for automated evidence generation |
| MinIO | Immutable evidence archival (ADR-013) |
| OpenSCAP / Lynis / AIDE | Scanning stack produces audit evidence (ADR-012) |
| All infrastructure components | Subject to SOC 2 Trust Services Criteria |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC1.1-CC1.5 | Control environment | Establishes formal compliance program |
| ISO 27001 | 4.1-10.2 | ISMS requirements | SOC 2 controls form 80% of ISMS foundation |
| NIST CSF 2.0 | GV.OC-01 | Organizational context | Compliance roadmap aligned with business objectives |
| CIS Controls v8.1 | IG1-IG3 | Implementation Groups | Controls scaled to organizational maturity |
| HIPAA | 164.308(a)(1) | Security management process | Infrastructure controls satisfy HIPAA safeguards |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
