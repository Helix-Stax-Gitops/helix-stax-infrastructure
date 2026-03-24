---
template: release-notes
category: release
task_type: release
clickup_list: "02 Platform Engineering"
auto_tags: ["release", "deployment", "changelog"]
required_fields: ["Release", "Summary", "Breaking Changes", "Upgrade Instructions", "Tested In"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF"]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Release Notes

Use this template for every production release.
Store in `CHANGELOG.md` (repo root) or `docs/releases/vX.Y.Z.md`.
Publish before the deploy, not after.

## Release: vX.Y.Z [REQUIRED]

**Release date**: YYYY-MM-DD

**Release type**: [ ] Major  [ ] Minor  [ ] Patch  [ ] Hotfix

**Deployed by**: [Name]

**Pipeline run**: [Link to Devtron / ArgoCD deployment]

---

## Summary [REQUIRED]

2-4 sentences. What changed and why this release matters.
Write for a non-technical reader. No jargon.

---

## New Features [OPTIONAL]

List only what's new. One item per line. Link to the GitHub issue or PR.

- [#NNN] Short description of the feature
- [#NNN] Short description of the feature

If none: "No new features in this release."

---

## Bug Fixes [OPTIONAL]

List defects resolved. One item per line.

- [#NNN] Short description of what was fixed
- [#NNN] Short description of what was fixed

If none: "No bug fixes in this release."

---

## Breaking Changes [REQUIRED]

List anything that requires action from operators or clients after upgrade.
If none, write "None." — do not leave blank.

| Change | Impact | Required Action |
|--------|--------|-----------------|
| [Change description] | [Impact on systems/users] | [Specific action required] |

---

## Known Issues [OPTIONAL]

Defects present in this release that are not yet fixed.
Include workarounds if they exist.

| Issue | Workaround |
|-------|-----------|
| [Issue description] | [Workaround or "No workaround"] |

If none: "No known issues."

---

## Upgrade Instructions [REQUIRED]

Step-by-step. Include every manual step required.
If the pipeline handles everything automatically, say so.

**Automatic (pipeline deploys on merge)**: Yes / No

**Manual steps required**:

```bash
# Paste any manual commands here, or state "None — automatic"
```

**Database migrations**: Yes / No
If yes, migrations run automatically via Helm hook: Yes / No

**Config changes required**: Yes / No
If yes, list which values.yaml keys changed or were added:
- [Key]: [Old value] → [New value]

**Rollback procedure**:

```bash
helm rollback <release-name> <revision>
```

---

## Dependencies Updated [OPTIONAL]

| Dependency | Previous Version | New Version | Notes |
|------------|-----------------|-------------|-------|
| [Dependency name] | [Old version] | [New version] | [Security patch/feature/etc] |

---

## Tested In [REQUIRED]

- [ ] vCluster preview (PR #NNN)
- [ ] Dev environment
- [ ] Staging
- [ ] Production

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This Template Satisfies It |
|-----------|-----------|-------------|-------------------------------|
| SOC 2 | CC8.1 | Change management — documented releases and change history | Release notes capture all changes, dependencies, and rollback procedures |
| SOC 2 | CC7.2 | System monitoring — deployment records for audit trail | Release date and deployer create audit record |
| NIST CSF | PR.IP-3 | Configuration change control — documented changes and testing | Breaking changes and testing environments explicitly documented |

## Definition of Done

- [ ] All [REQUIRED] fields are filled
- [ ] Tested in at least vCluster + one live environment before production
- [ ] Breaking changes explicitly listed with required actions
- [ ] Upgrade/rollback procedures tested and verified
- [ ] Dependencies updated table completed
- [ ] Release notes published before deploy (not after)
- [ ] Deployment pipeline run linked
- [ ] Deployed by field identifies the person who triggered the deploy

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.1 |
