# TEMPLATE: Bug Report

Use this template for any defect, regression, or unexpected behavior in Helix Stax services.
File in GitHub Issues with label `bug` before starting any fix work.

---

## TLDR

<!-- One sentence. What broke, and where. No background yet. -->

Example: The Zitadel login callback returns 500 when the `state` parameter is missing from the OAuth response.

---

## Steps to Reproduce

<!-- Numbered steps. Be exact. Include URLs, payloads, env vars if relevant. -->

1.
2.
3.
4.

**Reproducible in**: [ ] Local  [ ] vCluster preview  [ ] Dev  [ ] Production

**Frequency**: [ ] Always  [ ] Intermittent (~__% of attempts)  [ ] Once

---

## Expected vs Actual

| | Detail |
|---|---|
| **Expected** | |
| **Actual** | |

---

## Environment

| Field | Value |
|-------|-------|
| Service / Component | |
| Version / Image Tag | |
| Cluster | `heart` (CP) / `helix-worker-1` / vCluster |
| Namespace | |
| Ingress / URL | |
| Related PR or Commit | |

---

## Severity

Select one. See definitions below.

- [ ] **SEV-1 — Critical**: Production down or data loss. Requires immediate response.
- [ ] **SEV-2 — High**: Core feature broken; no workaround. Fix within 24 hours.
- [ ] **SEV-3 — Medium**: Feature degraded; workaround exists. Fix in next sprint.
- [ ] **SEV-4 — Low**: Cosmetic or minor inconvenience. Fix when convenient.

---

## Screenshots / Logs

<!-- Attach screenshots, paste relevant log lines, or link to Grafana/Loki query. -->
<!-- For logs: include timestamps and pod name. -->

```
# Paste log output here
```

---

## Component / Service Affected

<!-- Check all that apply. -->

- [ ] Zitadel (auth)
- [ ] Harbor (registry)
- [ ] MinIO (object storage)
- [ ] ArgoCD / Devtron (CI/CD)
- [ ] Traefik (ingress)
- [ ] Kong (API gateway)
- [ ] n8n (automation)
- [ ] Helix Stax website (helixstax.com)
- [ ] PostgreSQL
- [ ] Redis
- [ ] Other: _______________

---

## Additional Context

<!-- Anything else that helps. Recent deploys, config changes, related issues. -->

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
