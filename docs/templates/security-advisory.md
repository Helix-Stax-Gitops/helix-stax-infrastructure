# TEMPLATE: Security Advisory

Use this template for CVEs, vulnerability disclosures, or internal security findings.
Store in `docs/runbooks/security/YYYY-MM-DD-{slug}.md`.
Treat all security advisories as confidential until remediated.

---

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

## Related

<!-- Links to related ADRs, runbooks, or incidents. -->

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
