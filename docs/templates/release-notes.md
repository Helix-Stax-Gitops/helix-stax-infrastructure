# TEMPLATE: Release Notes

Use this template for every production release.
Store in `CHANGELOG.md` (repo root) or `docs/releases/vX.Y.Z.md`.
Publish before the deploy, not after.

---

## Release: vX.Y.Z

**Release date**: YYYY-MM-DD

**Release type**: [ ] Major  [ ] Minor  [ ] Patch  [ ] Hotfix

**Deployed by**: <!-- Name -->

**Pipeline run**: <!-- Link to Devtron / ArgoCD deployment -->

---

## Summary

<!-- 2-4 sentences. What changed and why this release matters.
     Write for a non-technical reader. No jargon. -->

---

## New Features

<!-- List only what's new. One item per line. Link to the GitHub issue or PR. -->

- [#NNN] Short description of the feature
- [#NNN] Short description of the feature

<!-- If none: "No new features in this release." -->

---

## Bug Fixes

<!-- List defects resolved. One item per line. -->

- [#NNN] Short description of what was fixed
- [#NNN] Short description of what was fixed

<!-- If none: "No bug fixes in this release." -->

---

## Breaking Changes

<!-- List anything that requires action from operators or clients after upgrade.
     If none, write "None." — do not leave blank. -->

| Change | Impact | Required Action |
|--------|--------|-----------------|
| | | |

---

## Known Issues

<!-- Defects present in this release that are not yet fixed.
     Include workarounds if they exist. -->

| Issue | Workaround |
|-------|-----------|
| | |

<!-- If none: "No known issues." -->

---

## Upgrade Instructions

<!-- Step-by-step. Include every manual step required.
     If the pipeline handles everything automatically, say so. -->

**Automatic (pipeline deploys on merge)**: Yes / No

**Manual steps required**:

```bash
# Paste any manual commands here
```

**Database migrations**: Yes / No
<!-- If yes, migrations run automatically via Helm hook: Yes / No -->

**Config changes required**: Yes / No
<!-- If yes, list which values.yaml keys changed or were added -->

**Rollback procedure**:

```bash
helm rollback <release-name> <revision>
```

---

## Dependencies Updated

| Dependency | Previous Version | New Version | Notes |
|------------|-----------------|-------------|-------|
| | | | |

---

## Tested In

- [ ] vCluster preview (PR #NNN)
- [ ] Dev environment
- [ ] Staging
- [ ] Production

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
