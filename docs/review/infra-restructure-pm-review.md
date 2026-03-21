# Infrastructure Restructure: PM Review

**Author**: Wakeem Williams
**Co-Author**: Sable Navarro (Product Manager)
**Date**: 2026-03-20
**Status**: REVIEW COMPLETE -- AWAITING WAKEEM DECISION

---

## 1. Executive Summary

Two solid documents from Cass and Remy that are largely complementary, not conflicting. Remy identified 54 misplaced files contaminating the infra repo that need to exit before any structural work begins. Cass designed a clean service-per-folder architecture that will make the repo genuinely useful as a GitOps source of truth. The critical sequencing constraint: Phase 1 (content cleanup) must complete before Phase 2 (repo restructure) begins, and OpenTofu state must be migrated to a remote backend before any `terraform/` directory moves.

---

## 2. Architecture Review (Cass Whitfield -- infra-repo-restructure.md)

### 2.1 Completeness

**Strengths:**
- Comprehensive service inventory covering all 25+ stack components
- ArgoCD integration fully designed (app-of-apps + ApplicationSet patterns)
- Per-service folder convention is explicit and templated
- Pre-requisites called out (worktree merge, state migration)
- Implementation phased across 7 phases with dependency ordering

**Gaps identified:**
- The doc says `docs/` is "DO NOT TOUCH" (Section 2.6) but the target structure (Section 4) still shows `compliance-templates/`, `content/`, and other misplaced directories inside `docs/`. This is inconsistent with Remy's audit -- the target state in Cass's doc should reflect a clean `docs/` tree, not the current contaminated one.
- No mention of how the `feature/zero-trust-network` worktree conflict gets resolved before Phase 0. That worktree has its own `docker-compose/`, `terraform/`, and `scripts/` copies. The pre-requisite is listed but the resolution path is not detailed.
- `assets/` is listed as MUST NOT MOVE (Section 6.3) but Remy's audit shows all 9 SVGs in `assets/icons/clickup/` are misplaced and should be moved. These two documents conflict here.
- The ApplicationSet YAML (Section 7.2) has a logic error: the `exclude` pattern uses a scalar under `path` but the correct YAML structure for an exclusion entry in ArgoCD's git directory generator requires a separate list item. Minor but would break on deploy.
- No `netbird-acls.md` mention in the target `docs/` structure (Section 4) -- it exists today and should stay (confirmed by Remy's audit).
- No guidance on how to handle `docs/WHERE-EVERYTHING-GOES.md` -- Remy flags it as borderline.

### 2.2 Feasibility

High. The design is realistic for a single-operator solo project. The phased approach is appropriate -- no big-bang migrations. Each phase is a discrete PR.

Primary feasibility concern: **OpenTofu state migration is a gate for Phase 2 of the repo restructure.** If state is not moved to a remote backend (MinIO S3 or Backblaze B2) first, moving `terraform/` to `opentofu/environments/prod/` risks corrupting active state. Cass flags this correctly in Section 6.2 and the risk table. Do not skip it.

Secondary concern: the `feature/zero-trust-network` worktree. If this is an active worktree that has diverged from main on the files being restructured, merging or closing it before the restructure is not optional.

### 2.3 Risk Assessment

| Risk | Cass's Assessment | PM Assessment |
|------|------------------|---------------|
| OpenTofu state breaks | HIGH -- migrate to remote first | AGREE -- this is the single biggest technical risk |
| Runbook links break | MEDIUM -- `docs/` not moving | LOW -- `scripts/` is only 3 files, low blast radius |
| CLAUDE.md paths stale | LOW | LOW -- trivial fix |
| Worktree divergence | MEDIUM | MEDIUM -- needs resolution path, not just a note |
| ArgoCD bootstrap chicken-and-egg | LOW | LOW -- well-understood pattern |
| Empty folders committed | LOW | LOW -- good discipline to defer folder creation to deploy time |

Mitigations are adequate for all risks except the worktree -- that needs a concrete resolution step.

### 2.4 Dependencies

Sequential dependencies for Phase 2 (repo restructure):
1. `feature/zero-trust-network` worktree must be merged or closed
2. OpenTofu remote state backend must be configured and state migrated
3. Phase 1 content cleanup (Remy's scope) should be complete so the `docs/` structure being preserved is the clean version, not the contaminated one

### 2.5 Alignment

Fully aligned with Helix Stax priorities:
- K3s as THE deployment target: service-per-folder directly serves K3s/ArgoCD GitOps
- `docker-compose/` quarantined to `archive/`: correct
- ArgoCD native: the ApplicationSet design is exactly right for a GitOps-first approach
- Dependency chain ordering matches CLAUDE.md's task dependency chain

---

## 3. Content Audit Review (Remy Alcazar -- infra-repo-content-audit.md)

### 3.1 Completeness

**Strengths:**
- 184 files scanned, 54 misplaced, 130 clean -- clear accounting
- Every misplaced file has a recommended destination and action
- Migration order is prioritized by contamination severity and safety
- Post-migration directory cleanup is mapped
- `docs/gemini-skill-prompts/` explicitly preserved per mission brief

**Gaps identified:**
- Destination directories for some moves may not exist yet. Example: `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` is unlikely to have been created. The executor of Phase 1 needs to `mkdir -p` all destinations before moving files.
- No mention of whether moved files need git history preserved (use `git mv` + `git log --follow` instead of filesystem move). For an infra repo cleaning up non-infra files, git history on the source side may be considered disposable, but it should be a conscious call.
- The `docs/gemini-agent-ecosystem-optimization-prompt.md`, `docs/gemini-clickup-task-sweep-prompt.md`, `docs/gemini-claude-code-infrastructure-research-prompt.md`, `docs/gemini-cli-google-cloud-setup-prompt.md`, and `docs/gemini-template-generation-prompt.md` are flagged as misplaced -- but Cass's architecture doc (Section 2.6) says there are "4 Gemini prompt files at the `docs/` root" to be moved during cleanup. These are the same files. Both docs agree they move. Good.
- `docs/google-deep-research-templates-prompt.md` is listed separately from the Gemini prompts -- needs to move alongside them.
- Recommended destination for AI tooling prompts is `~/.claude/prompts/` OR vault. This is two options, not one. Wakeem needs to pick a canonical home. Recommendation: `~/.claude/prompts/` since these are Claude/Gemini operational prompts, not business content.
- The compliance templates have two different destination roots: some go to `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` and some go to `C:\Users\MSI LAPTOP\HelixStax\business\ctga\templates\`. The CTGA-specific ones correctly separate from the general compliance ones. No issue here -- just noting the split.
- `docs/plans/clickup-workspace-overhaul.md` is listed for eventual move "after ClickUp work is complete." This is the only deferred move. It should stay for now.

### 3.2 Feasibility

High. Phase 1 is purely a file-move operation with zero risk to infra code. All 54 files are in `docs/`, `assets/`, or root-level `docs/` (the Gemini prompts). No IaC is touched.

The recommended migration order (11 steps) is sound. The LinkedIn cluster first makes sense -- highest contamination, zero cross-references, cleanest move.

One feasibility note: some destination paths (business workspace `C:\Wakeem\workspace\helix_stax\`, vault `C:\Users\MSI LAPTOP\HelixStax\vault\`) may need directory creation before the moves. This is trivial but should be scripted or at least listed explicitly.

### 3.3 Risk Assessment

| Risk | Severity | Notes |
|------|----------|-------|
| Moving a file referenced by another doc in the repo | VERY LOW | Remy confirmed infra code is clean. Only `docs/` contaminated, and those files have no cross-references to infra code. |
| Destination directory doesn't exist | LOW | Easily mitigated by `mkdir -p` before each move batch |
| git history loss on moved files | LOW | These files have no infra value -- git history loss is acceptable. Use `git mv` anyway for cleanliness. |
| Missing a misplaced file | LOW | 184 files scanned, explicit table coverage. Unlikely but possible. |

### 3.4 Dependencies

Phase 1 has no upstream dependencies. It can start immediately.
Internal ordering: Remy's 11-step recommended order is correct. Follow it.

### 3.5 Alignment

Fully aligned. Cleaning non-infra content out of the infra repo is prerequisite hygiene for the repo to function as a clean GitOps source of truth.

---

## 4. Gaps and Concerns

### 4.1 Cross-Document Conflicts

| Issue | Cass Says | Remy Says | Resolution |
|-------|-----------|-----------|------------|
| `assets/icons/clickup/` | MUST NOT MOVE (Section 6.3) | Move all 9 SVGs out | Remy is correct. These SVGs have no infra purpose. Remove from Cass's "must not move" list. |
| Target `docs/` structure | Shows contaminated state | Shows post-cleanup state | Cass's target structure (Section 4) should be updated to reflect post-cleanup `docs/` once Phase 1 is done. Not a blocker -- just a doc consistency issue. |

### 4.2 Unanswered Questions

1. **Canonical home for AI tooling prompts**: `~/.claude/prompts/` vs vault? Pick one. Recommendation: `~/.claude/prompts/`.
2. **Worktree resolution**: `feature/zero-trust-network` -- merge into main, or close and discard? This needs a call from Wakeem.
3. **Remote state backend timing**: Is MinIO available yet? If not, can Backblaze B2 serve as the remote backend temporarily? State migration is on the critical path for Phase 2.
4. **`docs/WHERE-EVERYTHING-GOES.md`**: Stay in infra repo or move to vault? Remy says borderline. It currently references this repo, so leaving it here is defensible until vault is active.
5. **Git history on Phase 1 moves**: Use `git mv` (preserves history in source repo) or simple filesystem move + delete? For non-infra files being evicted, either is acceptable -- just pick one approach and be consistent.

### 4.3 Scope Boundaries

Phase 1 (content cleanup) is clearly bounded and low risk. Start immediately.

Phase 2 (repo restructure) has a hard prerequisite: OpenTofu remote state migration. Do not start Phase 2 without it.

The `docs/gemini-skill-prompts/` directory was explicitly flagged as just reorganized -- confirmed do not touch in both documents and in the mission brief.

---

## 5. Unified Migration Plan

### Phase 1: Content Evacuation (Start Now -- No Prerequisites)

**Objective**: Remove all 54 non-infra files from the infra repo. Zero risk to infra code.

**Who**: DevOps agent or Wakeem directly (simple file moves)
**Estimated effort**: 1 session
**PR**: Single commit batch, "chore: evacuate non-infra content from docs/ and assets/"

#### Step 1.1 -- LinkedIn Content Cluster (7 files)

Move from infra repo to business workspace:

| Source (relative to repo root) | Destination |
|--------------------------------|-------------|
| `docs/content/linkedin-carousel-draft.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\` |
| `docs/review/linkedin-content-final-verdict.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` |
| `docs/review/linkedin-content-marketing-review.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` |
| `docs/review/linkedin-content-pm-review.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` |
| `docs/review/linkedin-content-seo-review.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\linkedin\carousel\reviews\` |
| `docs/preparation/linkedin-facebook-strategy-research.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\research\` |
| `docs/preparation/seo-social-media-strategy.md` | `C:\Wakeem\workspace\helix_stax\01_Social_Media\research\` |

After: delete empty `docs/content/` directory.

#### Step 1.2 -- Positioning and Marketing Docs (3 files)

| Source | Destination |
|--------|-------------|
| `docs/review/compliant-automation-marketing.md` | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` |
| `docs/review/compliant-automation-positioning.md` | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` |
| `docs/review/whats-missing-marketing-deep-dive.md` | `C:\Wakeem\workspace\helix_stax\04_Marketing\positioning\` |

#### Step 1.3 -- ClickUp UI Assets (9 SVGs)

| Source | Destination |
|--------|-------------|
| `assets/icons/clickup/*.svg` (all 9) | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\icons\` |

After: delete `assets/icons/clickup/`, then `assets/icons/`, then `assets/` (all empty).

#### Step 1.4 -- AI Tooling Prompts (6 files at docs/ root)

Canonical destination: `~/.claude/prompts/` (decision required -- see Section 4.2 item 1)

| Source | Destination |
|--------|-------------|
| `docs/gemini-agent-ecosystem-optimization-prompt.md` | `~/.claude/prompts/` |
| `docs/gemini-clickup-task-sweep-prompt.md` | `~/.claude/prompts/` |
| `docs/gemini-claude-code-infrastructure-research-prompt.md` | `~/.claude/prompts/` |
| `docs/gemini-cli-google-cloud-setup-prompt.md` | `~/.claude/prompts/` |
| `docs/gemini-template-generation-prompt.md` | `~/.claude/prompts/` |
| `docs/google-deep-research-templates-prompt.md` | `~/.claude/prompts/` |

#### Step 1.5 -- AI Tooling Architecture Outputs (3 files)

| Source | Destination |
|--------|-------------|
| `docs/architecture/claude-code-agent-tool-integration.md` | `~/.claude/` reference or vault |
| `docs/architecture/gemini-cli-google-cloud-enterprise.md` | `~/.claude/` reference or vault |
| `docs/architecture/gemini-cli-google-cloud-enterprise-summary.md` | `~/.claude/` reference or vault |

#### Step 1.6 -- Compliance Templates (5 files)

| Source | Destination |
|--------|-------------|
| `docs/compliance-templates/annual-compliance-review.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` |
| `docs/compliance-templates/dashboard-guide.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` |
| `docs/compliance-templates/monthly-compliance-status-report.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` |
| `docs/compliance-templates/quarterly-risk-assessment.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\templates\` |
| `docs/compliance-templates/ctga-assessment-report.md` | `C:\Users\MSI LAPTOP\HelixStax\business\ctga\templates\` |

After: delete empty `docs/compliance-templates/` directory.

#### Step 1.7 -- Business Templates (8 files)

| Source | Destination |
|--------|-------------|
| `docs/templates/GEMINI-COMPLETE-TEMPLATE-LIBRARY.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\templates\` |
| `docs/templates/client-proposal.md` | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` |
| `docs/templates/statement-of-work.md` | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` |
| `docs/templates/sla-definition.md` | `C:\Users\MSI LAPTOP\HelixStax\business\templates\` |
| `docs/templates/offboarding-checklist.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\hr\templates\` |
| `docs/templates/onboarding-checklist-team-member.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\hr\templates\` |
| `docs/templates/meeting-notes.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\templates\` |
| `docs/templates/sprint-review-retro.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\templates\` |

`docs/templates/` stays -- 6 infra templates remain (bug-report, feature-request, incident-report, security-advisory, n8n-workflow-readme, release-notes).

#### Step 1.8 -- ClickUp and Ops Research (5 files)

| Source | Destination |
|--------|-------------|
| `docs/preparation/workspace-structure-research.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` |
| `docs/preparation/clickup-automations-deep-research.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` |
| `docs/preparation/compliance-structure-research.md` | `C:\Wakeem\workspace\helix_stax\00_Corporate\compliance\research\` |
| `docs/review/session-status-report.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` |
| `docs/review/workspace-verification-report.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` |

#### Step 1.9 -- Marketing Research (2 files)

| Source | Destination |
|--------|-------------|
| `docs/preparation/linkedin-facebook-strategy-research.md` | Already covered in Step 1.1 |
| `docs/preparation/seo-social-media-strategy.md` | Already covered in Step 1.1 |

(These were listed in Remy's Step 9 but are already captured in Step 1.1 above -- no duplication needed.)

#### Step 1.10 -- Business Event Research and Rebranding (2 files)

| Source | Destination |
|--------|-------------|
| `docs/preparation/business-event-workflows-deep-research.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\n8n\research\` |
| `docs/preparation/rebranding-and-tools-research.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\research\` |

#### Step 1.11 -- Deferred Move (after ClickUp work is complete)

| Source | Destination |
|--------|-------------|
| `docs/plans/clickup-workspace-overhaul.md` | `C:\Wakeem\workspace\helix_stax\07_Technology\clickup\` |

**Phase 1 end state:**
- `docs/content/` -- DELETED (empty)
- `docs/compliance-templates/` -- DELETED (empty)
- `assets/` -- DELETED (empty)
- `docs/review/` -- clean (infra PR reviews only)
- `docs/templates/` -- 6 infra templates remain
- `docs/architecture/` -- 2 infra docs remain
- `docs/preparation/` -- 4 infra docs remain
- `docs/gemini-skill-prompts/` -- UNTOUCHED

---

### Phase 2: Repo Restructure (After Phase 1 + Prerequisites Met)

**Objective**: Reshape the infra repo into service-per-folder GitOps architecture per Cass's design.

**Hard prerequisites (all must be true before starting):**
- [ ] Phase 1 content evacuation COMPLETE
- [ ] `feature/zero-trust-network` worktree merged or closed
- [ ] OpenTofu state migrated to remote backend (MinIO S3 or Backblaze B2)
- [ ] `tofu plan` confirms zero drift after state migration

#### Phase 2.0 -- Skeleton and Rename (Single PR)

Implements Cass's Phase 1 (Section 9):

1. Rename `terraform/` to `opentofu/`
2. Create `opentofu/environments/prod/` and move root `.tf` files into it
3. Move `opentofu/modules/` (already correct relative path, update `module source` references in `main.tf`)
4. Move `terraform/cloud-init/` to `opentofu/cloud-init/`
5. Move `terraform/k3s/` to `opentofu/k3s/`
6. Move `scripts/cloudflare-zero-trust-setup.sh` to `services/cloudflare/scripts/zero-trust-setup.sh`
7. Move `scripts/cloudflare-finalize-github-idp.sh` to `services/cloudflare/scripts/finalize-github-idp.sh`
8. Move `scripts/firewall-setup.sh` to `opentofu/k3s/firewall-setup.sh`
9. Move `docker-compose/` to `archive/docker-compose/`
10. Copy useful configs from archive: `openbao/config.hcl` to `services/openbao/config/`, `redis/redis.conf.template` to `services/valkey/config/valkey.conf` (adapted)
11. Delete empty `helm/` directory
12. Create `platform/` with initial namespace definitions
13. Update CLAUDE.md conventions section
14. Update `.gitignore` if needed
15. Run `tofu init` + `tofu plan` in new location -- verify zero changes

**PR title**: "feat: service-per-folder skeleton -- rename terraform/, archive docker-compose/, stub platform/"

#### Phase 2.1 through 2.6 -- Services (Deploy-Driven)

As each service is deployed to K3s, create its service folder. Follow Cass's dependency chain (Sections 9, Phase 2-6). Do not pre-create empty folders. One service PR per deploy event.

Deployment order:
1. traefik, cert-manager
2. cloudnativepg, valkey, minio, harbor
3. zitadel, openbao, external-secrets, crowdsec, kyverno
4. argocd (full GitOps takeover), devtron, prometheus, grafana, loki
5. n8n, rocket-chat, outline, backstage, postal, velero, website
6. ollama, open-webui, searxng
7. ansible/ (when OS automation is needed)

---

## 6. Recommendations

1. **Start Phase 1 now.** No prerequisites. Low risk. The repo is cleaner the moment these 54 files leave.

2. **Decide the AI prompts destination before Phase 1 executes.** `~/.claude/prompts/` is recommended. Takes 30 seconds to decide.

3. **Resolve the worktree before scheduling Phase 2.** Check the state of `feature/zero-trust-network`. If the work there is valuable, merge it. If it's stale, close it. Either way, it must be gone before restructuring begins.

4. **Treat OpenTofu state migration as a standalone task.** It is a prerequisite for Phase 2, not part of Phase 2. Schedule it separately with appropriate care (backup state first, configure MinIO S3 backend in `backend.tf`, run `tofu init -migrate-state`, verify `tofu plan` shows zero drift).

5. **Fix the ApplicationSet YAML before ArgoCD deploy.** Cass's `applicationset.yaml` (Section 7.2) has the exclusion entry under the same list item as the include -- the `exclude: true` flag needs to be on a separate list entry. Catch this in the ArgoCD service PR review.

6. **Do not merge Cass's target structure (Section 4) until Phase 1 is done.** The architecture doc still shows the contaminated `docs/` tree. Once Phase 1 is complete, update the architecture doc's Section 4 to reflect the clean target state.

7. **Use `git mv` for Phase 1 moves within the infra repo.** Even though we're evicting files, `git mv` keeps the repo history clean and the commit message clear. Files moving to external directories (business workspace, vault) are simple filesystem copies followed by `git rm`.

---

## 7. Decision Points for Wakeem

The following require Wakeem's decision before work proceeds:

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| D1 | Canonical destination for AI tooling prompts (6 files) | A) `~/.claude/prompts/` B) `C:\Users\MSI LAPTOP\HelixStax\vault\prompts\` | A -- these are operational AI prompts, not business content |
| D2 | `feature/zero-trust-network` worktree -- merge or close? | A) Merge into main (preserve work) B) Close and discard (treat as stale) | Assess: does this worktree have uncommitted work that belongs in main? |
| D3 | Remote state backend for OpenTofu | A) MinIO (internal, already planned) B) Backblaze B2 (external, simpler to set up now) C) Defer until MinIO is deployed on K3s | B for now -- get state off local disk immediately. Migrate to MinIO once it's deployed. |
| D4 | `docs/WHERE-EVERYTHING-GOES.md` -- stay or move? | A) Stay in infra repo (useful navigational reference) B) Move to vault when vault is active | A for now -- move it when vault is ready |
| D5 | Phase 1 git strategy -- `git mv` or filesystem copy + `git rm`? | A) `git mv` within repo, filesystem copy + `git rm` for external moves B) All filesystem copies + `git rm` for evicted files | A -- cleaner history |

---

**End of document.**
