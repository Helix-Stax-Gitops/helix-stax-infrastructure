---
template: security-advisory
category: security
task_type: security-finding
clickup_list: "03 Security Operations"
auto_tags: ["security", "vulnerability", "cve"]
required_fields: ["TLDR", "CVE / ID", "Affected Systems", "Severity", "Remediation Steps"]
classification: confidential
compliance_frameworks: ["SOC 2", "NIST CSF", "ISO 27001", "NIST SP 800-53"]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Security Advisory

Use this template for CVEs, vulnerability disclosures, or internal security findings.
Store in `docs/runbooks/security/YYYY-MM-DD-{slug}.md`.
Treat all security advisories as confidential until remediated.

## TLDR

<!-- One sentence. What the vulnerability is and whether it has been patched. -->

Example: Traefik v2.10.4 is vulnerable to CVE-2024-45410 (request smuggling, CVSS 8.1); patched by upgrading to v2.10.7 on 2026-03-15.

---

## CVE / ID

| Field | Value |
|-------|-------|
| **CVE ID** | CVE-YYYY-XXXXX |
| **Internal ID** | SEC-YYYY-NNN (if no CVE) |
| **NVD Link** | https://nvd.nist.gov/vuln/detail/CVE-... |
| **Vendor Advisory** | <!-- Link to upstream advisory if available --> |

---

## Affected Systems

<!-- Be specific. Include version ranges. -->

| Component | Affected Versions | Patched Version | Deployed? |
|-----------|------------------|-----------------|-----------|
| | | | Yes / No |
| | | | Yes / No |

**Namespaces affected**:

**Clusters affected**: [ ] `heart` (CP)  [ ] `helix-worker-1`  [ ] vCluster

---

## Severity (CVSS)

| Field | Value |
|-------|-------|
| **CVSS Score** | X.X |
| **CVSS Vector** | CVSS:3.1/AV:.../AC:... |
| **Severity Rating** | Critical / High / Medium / Low / Informational |

**Exploitability**: [ ] Remote  [ ] Local  [ ] Physical

**Authentication required**: [ ] None  [ ] User  [ ] Admin

**Exploit available in the wild**: [ ] Yes  [ ] No  [ ] Unknown

---

## Discovery Method

<!-- How was this found? -->

- [ ] Automated scanner (Trivy, Grype, etc.)
- [ ] External CVE feed / advisory
- [ ] Manual audit
- [ ] Penetration test
- [ ] Bug bounty / responsible disclosure
- [ ] Other: _______________

**Discovered by**: <!-- Name or tool -->

**Discovery date**: YYYY-MM-DD

---

## Remediation Steps

<!-- Exact steps to patch. Commands required. -->

1.
2.
3.

**Commands**:

```bash
# Paste remediation commands here
```

**Verification** (confirm the fix worked):

```bash
# How to verify the patch is applied
```

**Rollback plan** (if the patch breaks something):

---

## Workaround

<!-- If immediate patching is not possible, what reduces risk in the interim? -->

<!-- If no workaround exists, state: "No workaround. Patch immediately." -->

---

## Disclosure Timeline

| Date | Event |
|------|-------|
| YYYY-MM-DD | Vulnerability discovered |
| YYYY-MM-DD | Internal team notified |
| YYYY-MM-DD | Remediation started |
| YYYY-MM-DD | Patch deployed |
| YYYY-MM-DD | Verification complete |
| YYYY-MM-DD | Advisory published (if applicable) |

---

## Risk Accepted (if not patched)

<!-- If remediation is deferred, document the decision here.
     Requires explicit sign-off. -->

**Risk accepted by**:
**Date**:
**Reason**:
**Review date** (no longer than 90 days out):

---

## Related [OPTIONAL]

Links to related ADRs, runbooks, or incidents.

- [Link to related resource]
- [Link to related resource]

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC6.1 | Vulnerability management — documented vulnerabilities and remediation | Advisory captures affected versions, CVSS, remediation, and verification steps |
| SOC 2 | CC7.2 | Security incident response — documented vulnerability responses | Disclosure timeline tracks discovery to patch deployment |
| NIST SP 800-53 | SI-2 | Security flaw remediation — documented vulnerabilities and fixes | Remediation steps and rollback procedures documented |
| NIST CSF | ID.RA-2 | Risk assessment — documented threat information | CVSS score and exploitability assess risk level |
| ISO 27001 | A.12.6.1 | Management of technical vulnerabilities — documented issues and remediation | Tracks affected systems and patching timeline |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] CVE ID or internal ID assigned
- [ ] CVSS score obtained from NVD or vendor
- [ ] Affected systems and versions documented
- [ ] Remediation steps tested and verified
- [ ] Disclosure timeline is complete and accurate
- [ ] Risk accepted (if not patched) has explicit sign-off
- [ ] Advisory marked confidential and access restricted
- [ ] Action items created in ClickUp with patch deadlines
- [ ] Follow-up verification scheduled

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Confidential |
| **Version** | 1.1 |
