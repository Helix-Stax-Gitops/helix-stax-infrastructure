# Gemini Deep Research: GitHub Workflows, Actions, and API — CI Automation and Integration

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can automate, integrate, and manage workflows without hallucinating. This research will become that reference document.

## What These Tools Are

GitHub is our source control platform and the authoritative source of truth for all code. It is NOT our primary CI/CD system — that role belongs to Devtron (CI builds) and ArgoCD (GitOps CD). GitHub is responsible for:

- **Source of truth**: All code, IaC, Helm charts, Ansible roles, and agent definitions live here
- **Supplementary CI**: Actions run validation jobs that Devtron doesn't handle — IaC linting, Ansible linting, code quality, pre-commit checks, PR automation
- **Webhook source**: GitHub events (push, PR, issue) fire webhooks to n8n, which orchestrates downstream automation
- **Agent tooling**: Claude Code uses `gh` CLI extensively for PR management, issue tracking, and release operations

The `gh` CLI is how our AI agents interact with GitHub programmatically. Claude Code agents run `gh pr create`, `gh issue create`, `gh api`, `gh run list` — this is a primary interface, not a convenience tool.

Understanding the exact GitHub Actions patterns, webhook configuration, `gh` CLI reference, and the boundary between GitHub Actions and Devtron/ArgoCD is essential before writing any CI workflows.

## Our Specific Setup

- **GitHub org**: KeemWilliams (personal account, repos live here)
- **Primary repo**: `helix-stax-infra` (IaC, Helm, Ansible, docs)
- **Additional repos**: app repos per service
- **Primary CI**: Devtron (builds Docker images, pushes to Harbor)
- **Primary CD**: ArgoCD (GitOps, watches `helix-stax-infra` Helm values)
- **GitHub Actions role**: Supplementary — linting, validation, PR automation, webhooks to n8n
- **Registry**: Harbor at `harbor.helixstax.net` (NOT GitHub Container Registry — GHCR is not our registry)
- **Secrets manager**: OpenBao (Vault API) + SOPS (encrypted secrets in git with age keys)
- **IaC**: OpenTofu (NOT Terraform) — needs validation/plan in Actions on PR
- **Ansible**: Linting via `ansible-lint` in Actions on PR
- **Automation hub**: n8n receives GitHub webhooks and orchestrates downstream tasks
- **Identity**: Zitadel for platform SSO — GitHub uses its own auth (not Zitadel)
- **Platform**: Windows workstation running Claude Code, K3s on AlmaLinux 9.7 as deploy target
- **Domains**: helixstax.com (public), helixstax.net (internal)
- **Claude Code agents**: Use `gh` CLI for all GitHub operations — PR creation, issue filing, release tagging

---

## What I Need Researched

---

### GH-1. `gh` CLI Complete Reference for Agent Use

Claude Code agents use `gh` as the primary GitHub interface. Document every subcommand relevant to agent automation:

**Authentication:**
- `gh auth login` — methods: browser, token, SSH. Environment variable `GH_TOKEN` for non-interactive auth
- `gh auth status` — verify authentication state
- `gh auth token` — print current token (useful for scripting)
- `GITHUB_TOKEN` vs `GH_TOKEN`: which takes precedence, when to use each
- Token scopes needed for: PR operations, issue operations, release operations, repo operations, Actions secrets

**Pull Request operations:**
- `gh pr create --title --body --base --head --draft --label --assignee --reviewer` — full flag reference
- `gh pr list` — filtering flags: `--state`, `--author`, `--label`, `--base`, `--json`, `--jq`
- `gh pr view <number>` — fields available, `--json` output schema
- `gh pr merge <number>` — merge methods: `--merge`, `--squash`, `--rebase`, `--auto`, `--delete-branch`
- `gh pr review <number>` — `--approve`, `--request-changes`, `--comment`
- `gh pr edit <number>` — editing title, body, labels, assignees, reviewers
- `gh pr checks <number>` — status of CI checks on a PR
- `gh pr diff <number>` — view diff
- `gh pr close` / `gh pr reopen`
- `--json` output: complete schema of PR fields available as JSON

**Issue operations:**
- `gh issue create --title --body --label --assignee --milestone --project`
- `gh issue list` — filtering by state, label, assignee, milestone
- `gh issue view <number>` — JSON output schema
- `gh issue edit <number>` — editing labels, assignees, milestones
- `gh issue close <number>` — with `--reason` (completed, not_planned)
- `gh issue comment <number> --body`
- `gh issue develop <number>` — create branch linked to issue
- `--json` fields available for issues

**Release operations:**
- `gh release create <tag>` — `--title`, `--notes`, `--notes-file`, `--draft`, `--prerelease`, `--target`, `--generate-notes`
- `gh release list` — format, filtering
- `gh release view <tag>` — JSON output
- `gh release upload <tag> <file>` — attach assets
- `gh release edit <tag>` — modify existing release
- `gh release delete <tag>`
- Auto-generated release notes: `--generate-notes` flag, how GitHub builds the changelog from PR titles

**API operations:**
- `gh api <endpoint>` — base usage, HTTP methods (`--method GET/POST/PATCH/DELETE`)
- `--field`, `--raw-field` for request body
- `--jq` for response filtering
- `--paginate` for paginated endpoints
- GraphQL: `gh api graphql --field query=@query.graphql`
- Common REST endpoints via `gh api`: repos, issues, PRs, Actions, secrets, webhooks
- Rate limit checking: `gh api rate_limit`

**Actions/Workflow operations:**
- `gh run list` — list workflow runs, filtering by workflow, branch, status
- `gh run view <run-id>` — run details, logs
- `gh run watch <run-id>` — tail a run in real time
- `gh run rerun <run-id>` — rerun failed jobs
- `gh run cancel <run-id>`
- `gh workflow list` — list defined workflows
- `gh workflow run <workflow>` — manually trigger a `workflow_dispatch` workflow
- `gh workflow enable` / `gh workflow disable`

**Repository operations:**
- `gh repo view` — repo details
- `gh repo clone` — with depth, branch options
- `gh repo create` — options for private/public, initialize, add remote
- `gh repo list` — listing org repos with filtering
- `gh repo set-default` — set default repo for `gh` commands in a directory
- `gh secret set` / `gh secret list` / `gh secret delete` — managing Actions secrets
- `gh variable set` / `gh variable list` — managing Actions variables (non-secret)

**Output and scripting patterns:**
- `--json` + `--jq` pipeline patterns for agent scripts
- Exit codes: when `gh` returns non-zero, what codes mean what
- Environment variables that affect `gh` behavior: `GH_HOST`, `GH_REPO`, `GH_TOKEN`, `GH_EDITOR`, `NO_COLOR`, `GH_PROMPT_DISABLED`
- Using `gh` in non-interactive mode (agents): flags to suppress prompts
- HEREDOC patterns for multi-line PR/issue bodies

---

### GH-2. GitHub Actions Core Concepts

Comprehensive reference for writing Actions workflows:

**Workflow file structure:**
- Location: `.github/workflows/*.yml`
- Required fields: `name`, `on`, `jobs`
- Job structure: `runs-on`, `steps`, `needs`, `if`, `env`, `outputs`
- Step structure: `name`, `uses`, `run`, `with`, `env`, `id`, `if`, `continue-on-error`

**Trigger events (`on:`) — all relevant variants:**
- `push`: `branches`, `tags`, `paths`, `paths-ignore` filters
- `pull_request`: `types` (opened, synchronize, reopened, closed, labeled), `branches`, `paths`
- `pull_request_target`: when to use vs `pull_request` (fork PRs, security implications)
- `workflow_dispatch`: manual triggers with `inputs` (string, boolean, choice, environment)
- `schedule`: cron syntax, timezone (UTC), minimum frequency (every 5 minutes)
- `workflow_call`: making a reusable workflow callable from other workflows — inputs, outputs, secrets
- `release`: types (created, published, prereleased)
- `issues`: types (opened, labeled, closed)
- `issue_comment`: comment on issue or PR
- `repository_dispatch`: external trigger via GitHub API — use case for n8n or external systems triggering Actions

**Runners:**
- `ubuntu-latest`: what version this resolves to currently, when it changes, how to pin (`ubuntu-24.04`)
- `self-hosted` runners: when to use (access to internal network, AlmaLinux for compatibility testing)
- Runner OS and available tools: what's pre-installed on `ubuntu-latest` (git, curl, node, python, docker, kubectl, helm, etc.)
- `runs-on: [self-hosted, linux, x64]`: label targeting for self-hosted

**Expressions and contexts:**
- `${{ github.* }}`: `github.sha`, `github.ref`, `github.ref_name`, `github.event_name`, `github.actor`, `github.repository`, `github.run_id`, `github.run_number`, `github.head_ref`, `github.base_ref`
- `${{ env.* }}`: job-level vs step-level env vars
- `${{ secrets.* }}` and `${{ vars.* }}`
- `${{ steps.<id>.outputs.* }}`: consuming step outputs
- `${{ needs.<job>.outputs.* }}`: consuming job outputs
- `${{ runner.os }}`, `${{ runner.arch }}`
- Conditional expressions: `if: github.ref == 'refs/heads/main'`, `if: contains(github.event.pull_request.labels.*.name, 'deploy')`, `if: failure()`, `if: always()`
- `${{ toJSON(...) }}`, `${{ fromJSON(...) }}`, `${{ format(...) }}`, `${{ join(...) }}`

**Environment variables:**
- Setting at workflow, job, and step level
- `GITHUB_OUTPUT`: appending key=value pairs for step outputs (`echo "key=value" >> $GITHUB_OUTPUT`)
- `GITHUB_ENV`: setting env vars for subsequent steps (`echo "KEY=value" >> $GITHUB_ENV`)
- `GITHUB_STEP_SUMMARY`: adding to job summary markdown (`echo "## Summary" >> $GITHUB_STEP_SUMMARY`)
- `GITHUB_PATH`: adding to PATH for subsequent steps
- `GITHUB_TOKEN`: the auto-generated token for workflow runs — permissions, what it can/cannot do

**Caching:**
- `actions/cache`: key structure, restore-keys fallback, cache paths
- Cache hit/miss in subsequent steps: `steps.<id>.outputs.cache-hit`
- Cache size limits (10GB per repo), eviction policy
- Language-specific cache patterns: pip cache (`~/.cache/pip`), npm cache, Go module cache

**Artifacts:**
- `actions/upload-artifact`: name, path, retention-days
- `actions/download-artifact`: name, path
- Artifact size limits (500MB per artifact, 2GB per run)
- Sharing artifacts between jobs in the same workflow

**Job matrix:**
- `strategy.matrix`: defining matrix dimensions
- `matrix.include` and `matrix.exclude`
- `fail-fast`: default behavior, when to set `false`
- Max parallel jobs

**Concurrency:**
- `concurrency` key: `group`, `cancel-in-progress`
- Patterns: cancel in-progress runs on new push to same branch
- Use at workflow level vs job level

---

### GH-3. GitHub Actions for OpenTofu (IaC Validation)

Our IaC is OpenTofu (not Terraform). Document complete patterns for IaC CI:

**Why Actions for OpenTofu (not Devtron):**
- Devtron handles application builds and deploys; IaC validation on PR is a GitHub-native pattern
- `tofu validate` and `tofu plan` should run before any PR to `helix-stax-infra` is merged
- This is a quality gate, not a deployment pipeline

**OpenTofu vs Terraform in Actions:**
- `opentofu/setup-opentofu` action: exact action name, version pinning, inputs (`tofu_version`, `tofu_wrapper`)
- The `tofu_wrapper` option: what it does (wraps `tofu` commands to capture output), why useful for PR comments
- Difference from `hashicorp/setup-terraform` — drop-in but different action name
- Where to find `opentofu/setup-opentofu`: GitHub marketplace link, repository

**Authentication for OpenTofu in Actions:**
- OpenTofu needs Hetzner API credentials to validate provider, access state
- Options: GitHub Actions secrets (simplest), OIDC with Hetzner (if supported), OpenBao dynamic creds
- For our setup: Hetzner API token stored as GitHub Actions secret `HETZNER_API_TOKEN`
- OpenTofu state backend (S3-compatible MinIO or Hetzner Object Storage): `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` as secrets, or SOPS-encrypted backend config

**Complete `tofu validate` + `tofu plan` workflow pattern:**
- Workflow trigger: `pull_request` to `main`, paths filter on `opentofu/**`
- Steps: checkout, setup-opentofu, `tofu init`, `tofu validate`, `tofu plan -no-color`
- Posting plan output as PR comment: `peter-evans/create-or-update-comment` pattern
- Handling plan output that is too long for a comment (truncation, artifact upload)
- `tofu plan -out=tfplan` + upload as artifact for `tofu apply` in separate job
- Cost of running `tofu plan` on every PR: API calls to Hetzner, rate limits

**`tofu fmt` check:**
- Running `tofu fmt -check -recursive` to fail PRs with unformatted IaC
- How to auto-fix formatting in CI (commit back, or just fail and let developer fix)

**Security concerns with IaC in Actions:**
- Never print full plan output in public repos (may expose resource names, IPs, secrets)
- `sensitive` variables in plan output: `tofu plan` still shows "sensitive value"
- Storing state: do NOT use `terraform.tfstate` in git — use remote state backend
- SOPS: if backend credentials are SOPS-encrypted in the repo, how to decrypt in Actions

---

### GH-4. GitHub Actions for Ansible Linting

**Why lint Ansible in Actions:**
- `ansible-lint` catches syntax errors, deprecated modules, best practice violations before a playbook runs on real servers
- Runs on PR, blocks merge if lint score degrades

**`ansible-lint` in Actions:**
- Using `ansible/ansible-lint-action` (official GitHub Action) vs running `pip install ansible-lint` manually
- `ansible/ansible-lint-action` inputs: `path`, `args`, working directory
- Running lint on specific directories: `ansible/` or a per-role path
- `ansible-lint` configuration file: `.ansible-lint` — profile settings (`production`, `safety`, `shared`), `exclude_paths`, `warn_list`, `skip_list`
- Exit codes: 0 (pass), 1 (violations found), 2 (internal error)
- SARIF output for GitHub Code Scanning integration: `--format sarif > results.sarif`, `github/codeql-action/upload-sarif`

**`ansible-lint` + `yamllint`:**
- `yamllint` as a prerequisite or companion check
- `.yamllint` config file for Ansible-specific YAML style (line length, truthy values)

**Molecule testing in Actions:**
- When Molecule (Ansible role testing framework) belongs in Actions vs local dev
- Resource requirements: Molecule with Docker driver runs Docker-in-Docker — does `ubuntu-latest` support this?
- `molecule test` for simple role validation vs full integration test

**Role-specific linting triggers:**
- Path filters: only lint roles that changed on a PR (`paths: ['ansible/roles/**']`)
- Matrix strategy for linting multiple roles in parallel

---

### GH-5. GitHub Actions for Code Quality

**ShellCheck (shell script linting):**
- `ludeeus/action-shellcheck` — inputs, severity levels, format options
- Running on `*.sh` files in the repo
- `shellcheck -e SC2086` style exclusion patterns — when and why to exclude
- ShellCheck SARIF output for GitHub Code Scanning

**Markdown linting:**
- `DavidAnson/markdownlint-cli2-action` — the standard markdown lint action
- `.markdownlint.yaml` config: rules to enable/disable (line length MD013, first heading MD041)
- When markdown lint matters: docs/, runbooks/, ADRs, prompt files like this one
- Vale prose linting: what it is, when to use it vs markdownlint

**Pre-commit hooks as Actions:**
- `pre-commit/action` — running `.pre-commit-config.yaml` in Actions
- Why run pre-commit in CI even if devs run it locally: catching commits that bypass hooks
- Common hooks: `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-json`, `detect-private-key`
- `detect-private-key` hook: critical for our setup — should always be enabled
- SOPS-specific pre-commit hooks: checking that `.enc.yaml` files are actually encrypted

**YAML validation:**
- Validating Helm values files: `helm lint` in Actions
- `helm lint --strict charts/<chart>` — what `--strict` adds
- Kubernetes manifest validation: `kubeval` or `kubeconform` — which is maintained
- `kubeconform` with custom schema locations for CRD-heavy stacks (Traefik IngressRoute, etc.)

---

### GH-6. GitHub Actions + Devtron Boundary

This is a critical architectural decision for our stack. Document the exact division of responsibilities:

**What Devtron handles (GitHub Actions must NOT duplicate):**
- Docker image builds: Devtron CI pipelines build images and push to Harbor
- Helm deploys: ArgoCD watches Git, applies Helm chart changes to K3s
- Environment promotion: staging → production managed by Devtron/ArgoCD
- Image scanning: Harbor has Trivy built-in; Devtron can trigger scans

**What GitHub Actions handles (Devtron/ArgoCD must NOT duplicate):**
- OpenTofu validate/plan on PR (IaC changes before merge)
- Ansible lint on PR (playbook changes before merge)
- Code quality checks: shellcheck, markdownlint, pre-commit
- PR labeling and automation (auto-labeler based on paths)
- Stale issue management (scheduled Actions job)
- Release creation and changelog generation (tag-triggered)
- Webhook delivery to n8n (GitHub native, not Actions)

**The overlap zone (requires clear policy):**
- Secret scanning: GitHub native secret scanning vs Actions workflow vs Devtron scan
- Dependency updates: Dependabot (GitHub native) vs manual vs Actions job
- Container image builds for non-app infrastructure: build a utility container vs use pre-built
- Integration tests: Devtron post-deploy tests vs Actions PR tests vs separate test pipeline

**Triggering Devtron from Actions (if needed):**
- Devtron has a REST API — can Actions trigger a Devtron pipeline via API call?
- When this pattern makes sense vs letting Devtron watch Git directly
- Avoiding double-trigger: Devtron watches Git; if Actions also fires Devtron, you get two builds

**Triggering n8n from GitHub (Actions vs Webhooks):**
- GitHub Webhooks: configured at org/repo level, fire on every matching event, no compute cost
- GitHub Actions `repository_dispatch`: fires from a workflow, more control, requires Actions to be running first
- Recommendation: use native GitHub Webhooks to n8n for real-time event processing; Actions for CI checks
- n8n webhook URL pattern for GitHub: `https://n8n.helixstax.net/webhook/<path>`

---

### GH-7. Webhook Configuration to n8n

**GitHub webhook setup:**
- Where to configure: repo Settings > Webhooks vs org-level webhooks
- Payload URL: `https://n8n.helixstax.net/webhook/<path>`
- Content type: `application/json` (n8n expects this)
- Secret: HMAC-SHA256 signature validation — how to configure in n8n to verify `X-Hub-Signature-256` header
- Events to subscribe: push, pull_request, issues, issue_comment, release, create (tag), workflow_run
- Active vs inactive webhooks

**Webhook payload structure:**
- `push` event payload: `ref`, `commits[]` (id, message, author), `repository`, `pusher`, `before`, `after`
- `pull_request` event payload: `action`, `number`, `pull_request` (title, body, user, labels, base, head, merged)
- `issues` event payload: `action`, `issue` (number, title, labels, assignees, state)
- `release` event payload: `action`, `release` (tag_name, name, body, prerelease, draft)
- `workflow_run` event payload: `action` (completed, requested), `workflow_run` (name, conclusion, head_sha)
- Common fields in all payloads: `repository`, `organization`, `sender`

**Webhook delivery reliability:**
- GitHub retry behavior: how many retries, retry interval, timeout (10 seconds)
- What happens when n8n is down: GitHub queues deliveries, retries up to 3 days
- Viewing delivery logs: repo Settings > Webhooks > Recent Deliveries — redeliver manually
- Webhook delivery latency: typically under 5 seconds

**n8n GitHub Trigger node vs webhook:**
- `GitHub Trigger` node in n8n: uses webhooks under the hood, easier setup
- Manual webhook node: more control, custom payload handling
- Recommended approach for our setup: n8n `GitHub Trigger` node for standard events

**Webhook security:**
- `X-Hub-Signature-256` header: HMAC-SHA256 of payload body using webhook secret
- Verifying in n8n: using the `Header Auth` credential + webhook validation
- IP allowlisting: GitHub webhook IP ranges (published at `https://api.github.com/meta`) — relevant if n8n is behind firewall
- Exposure: n8n webhook endpoint must be publicly reachable — confirm Traefik IngressRoute for n8n is configured

---

### GH-8. Branch Protection and Repository Policies

**Branch protection rules:**
- Target: `main` branch
- Required status checks: how to add Actions workflow check names, `strict` option (must be up-to-date)
- Required reviews: number of approvals, dismiss stale reviews, require review from code owners
- Restrict push access: who can push directly to `main`
- Require signed commits: GPG or SSH signing — interaction with Windows + WSL setup
- Require linear history: squash/rebase only, no merge commits
- Allow force pushes / deletions: when to allow (never for `main`)

**CODEOWNERS:**
- `.github/CODEOWNERS` file format: `path @owner` patterns
- How CODEOWNERS interacts with required reviews: auto-requesting review from owners
- Glob patterns: `*.tf` for all OpenTofu files, `ansible/**` for all Ansible
- Our setup: Wakeem as sole owner — still useful for auto-requesting review from yourself? (Probably no)
- When CODEOWNERS matters more: when adding collaborators or contractor access

**Rulesets (newer branch protection mechanism):**
- GitHub Rulesets vs classic branch protection: what rulesets add (multiple patterns, bypass lists, org-level)
- `required_workflows`: requiring specific Actions workflows to pass — more flexible than status checks
- Bypass actors: who can bypass rules (admin, Dependabot, specific apps)
- Organization-level rulesets vs repo-level

**Protected tags:**
- Protecting version tags (`v*`) from deletion or modification
- Who can create protected tags

---

### GH-9. GitHub Environments and Secrets

**Environments:**
- Creating environments: `staging`, `production` in repo Settings > Environments
- Environment protection rules: required reviewers before job runs in that environment
- Deployment branches: restrict which branches can deploy to an environment
- Wait timer: delay before environment job runs

**Secrets scoping:**
- Repository secrets: available to all workflows in the repo
- Environment secrets: only available to jobs targeting that environment
- Organization secrets: available to selected repos in the org — useful for shared tokens
- Secret resolution order: environment > repository > organization

**Secrets we need for our workflows:**
- `HETZNER_API_TOKEN`: OpenTofu provider auth, read from GitHub Actions secret
- `SOPS_AGE_KEY`: age private key for decrypting SOPS-encrypted files in CI
- `OPENBAO_TOKEN` or `OPENBAO_ROLE_ID` + `OPENBAO_SECRET_ID`: if Actions needs to read OpenBao secrets
- `HARBOR_USERNAME` + `HARBOR_PASSWORD`: if Actions pushes anything to Harbor (normally Devtron does this)
- `N8N_WEBHOOK_SECRET`: if Actions calls n8n webhooks and needs to authenticate

**SOPS + age in Actions:**
- Installing `age` and `sops` in an Actions workflow: download from GitHub releases, pin versions
- Decrypting a SOPS file: `SOPS_AGE_KEY=${{ secrets.SOPS_AGE_KEY }} sops -d encrypted.yaml > decrypted.yaml`
- `SOPS_AGE_KEY_FILE` vs `SOPS_AGE_KEY` env var: which sops supports
- Preventing decrypted file from being printed in logs: `::add-mask::` pattern, `set +x`
- Security: decrypted files should be used within the step only, never uploaded as artifacts

**OpenBao/Vault in Actions:**
- `hashicorp/vault-action` — works with OpenBao (Vault API compatible)
- Auth methods: token auth (simplest), AppRole (recommended for CI), JWT/OIDC (most secure)
- GitHub Actions OIDC + OpenBao: using GitHub's OIDC provider to authenticate to OpenBao without static secrets
- OIDC setup: OpenBao JWT auth backend, `bound_claims` for repo/workflow restrictions
- Why this matters: eliminates static `OPENBAO_TOKEN` from GitHub Secrets — security improvement

**Variables (non-secret):**
- `vars.*` context: non-sensitive configuration stored at repo/env/org level
- When to use variables vs secrets: `TOFU_VERSION=1.7.0` as variable, not secret
- Environment-specific variables: `REGISTRY_URL=harbor.helixstax.net` varies per environment

---

### GH-10. GitHub API v3 (REST) and v4 (GraphQL)

**REST API (v3):**
- Base URL: `https://api.github.com`
- Authentication: `Authorization: Bearer <token>` header (personal access token or `GITHUB_TOKEN`)
- Rate limits: authenticated (5,000 req/hr), secondary rate limits (per-minute burst), search API (30 req/min)
- Checking rate limit: `GET /rate_limit`
- Key endpoints for automation:
  - `GET /repos/{owner}/{repo}/pulls` — list PRs with `state`, `base`, `labels` filters
  - `POST /repos/{owner}/{repo}/issues` — create issue
  - `POST /repos/{owner}/{repo}/issues/{number}/comments` — add comment
  - `PATCH /repos/{owner}/{repo}/issues/{number}` — update issue (labels, assignees, state)
  - `POST /repos/{owner}/{repo}/releases` — create release
  - `GET /repos/{owner}/{repo}/actions/runs` — list workflow runs
  - `POST /repos/{owner}/{repo}/dispatches` — `repository_dispatch` trigger
  - `GET /repos/{owner}/{repo}/hooks` — list webhooks
  - `POST /repos/{owner}/{repo}/hooks` — create webhook
  - `POST /orgs/{org}/repos` — create repo in org
  - `PUT /repos/{owner}/{repo}/contents/{path}` — create/update file via API
- Pagination: `Link` header with `rel="next"`, `per_page` param (max 100)
- Error responses: 4xx codes, `message` field, `errors` array

**GraphQL API (v4):**
- Endpoint: `POST https://api.github.com/graphql`
- Authentication: same as REST
- Why GraphQL over REST: fetch exactly what you need in one request, no over-fetching
- Key queries:
  - `viewer { login }` — verify auth
  - `repository(owner: "KeemWilliams", name: "helix-stax-infra") { pullRequests(states: OPEN) { nodes { number title } } }` — list PRs
  - `search(query: "repo:KeemWilliams/helix-stax-infra is:pr is:open", type: ISSUE)` — search PRs
  - Querying project boards: `ProjectV2` type
- Mutations:
  - `addComment(input: {subjectId: ..., body: ...})` — add PR/issue comment
  - `createIssue(input: {...})` — create issue
  - `mergePullRequest(input: {pullRequestId: ..., mergeMethod: SQUASH})` — merge PR
  - `addLabelsToLabelable` — add labels
- Cursor-based pagination: `pageInfo { endCursor hasNextPage }`, `after: "cursor"` arg
- Node IDs: REST returns number IDs; GraphQL uses global node IDs — conversion: `GET /repos/{owner}/{repo}/issues/{number}` returns `node_id`
- Rate limits in GraphQL: point-based system, not request count — complex queries cost more points

**Using `gh api` for both REST and GraphQL:**
- `gh api /repos/{owner}/{repo}/issues` — REST via gh
- `gh api graphql -f query='query { viewer { login } }'` — GraphQL via gh
- `gh api --paginate /repos/{owner}/{repo}/pulls` — automatic pagination
- `gh api --jq '.[] | {number, title}'` — inline jq filtering

---

### GH-11. PR Automation Patterns

**Auto-labeling:**
- `actions/labeler` — the standard auto-labeler action
- `.github/labeler.yml` config: label name → path glob mapping
  - `infrastructure`: `opentofu/**`, `ansible/**`
  - `helm`: `helm/**`
  - `docs`: `docs/**`, `*.md`
  - `agents`: `.claude/**`
- `pull-request-labeler` vs `actions/labeler` — which is maintained
- Using changed files to label: how the action detects changed files

**PR templates:**
- `.github/pull_request_template.md` — single template applied to all PRs
- Multiple templates: `.github/PULL_REQUEST_TEMPLATE/*.md` — user selects at PR creation
- Our template should include: Summary, Changes table, Test plan, Risks, Related tasks
- How `gh pr create` uses the template: `--body-file .github/pull_request_template.md` or auto-applied via GitHub web

**Issue templates:**
- `.github/ISSUE_TEMPLATE/*.yml` — structured issue forms (GitHub issue forms, not just markdown)
- Issue form fields: `input`, `textarea`, `dropdown`, `checkboxes`, `markdown`
- `config.yml` in `.github/ISSUE_TEMPLATE/` — disable blank issues, add external links
- Templates for: bug report, feature request, infra task (links to ClickUp), security report

**Auto-assignment:**
- `actions/auto-assign-action` — auto-assign PR author as assignee on PR open
- Rule-based assignment: assign reviewers based on PR labels or changed paths

**Stale bot:**
- `actions/stale` — mark and close stale issues/PRs
- Config: `days-before-stale`, `days-before-close`, `stale-issue-label`, `stale-pr-label`
- Exemption labels: `pinned`, `security`, `in-progress` — don't mark these stale
- Our use case: close stale feature requests after 90 days; keep infra issues open longer

**Conventional commits enforcement:**
- `amannn/action-semantic-pull-request` — validates PR title follows Conventional Commits
- Why: enables auto-changelog generation based on commit types (`feat:`, `fix:`, `chore:`)
- Types we use: `feat`, `fix`, `docs`, `chore`, `infra`, `ci`, `sec`
- `commitlint` in pre-commit: enforcing at commit time, not just PR time

---

### GH-12. Release Automation

**Tag-based release triggers:**
- Trigger: `on: push: tags: ['v*.*.*']`
- Semantic versioning: `v1.2.3` format — when to bump major/minor/patch
- Creating tags: `git tag v1.2.3 && git push origin v1.2.3` vs `gh release create v1.2.3`

**Auto-generated changelogs:**
- `--generate-notes` in `gh release create`: GitHub builds changelog from merged PR titles since last tag
- `.github/release.yml` — changelog categories config: group PRs by label in release notes
- Example config: `feat` label → "New Features" section, `fix` → "Bug Fixes", `infra` → "Infrastructure"
- How to preview generated notes before publishing: `gh release create --draft --generate-notes`

**`release-please` (Google's release automation):**
- What it is: bot that creates a "release PR" that accumulates changes until you merge it to release
- `release-please-action` — setup, `release-type` (simple, node, go, etc.)
- `.release-please-manifest.json` and `release-please-config.json`
- When to use `release-please` vs simple tag-triggered releases: teams with multiple repos or versioned packages; probably overkill for our infra repo

**Semantic Release:**
- `semantic-release/semantic-release`: analyzes commits, determines version bump, creates release, publishes
- Requires Conventional Commits format
- When to use: for app repos where versioning is automated; our infra repo is less conventional

**Our recommended pattern for helix-stax-infra:**
- Simple: tag manually with `gh release create v1.2.3 --generate-notes --title "v1.2.3"`
- The release notes come from merged PR titles (requires Conventional Commits PR titles)

---

### GH-13. Security Features

**Dependabot:**
- `dependabot.yml` config: `package-ecosystem` options (pip, npm, github-actions, docker, terraform)
- `github-actions` ecosystem: keeps Action versions in `uses:` up-to-date — critical for pinning SHA vs tag
- Update schedule: daily, weekly, monthly
- PR labels, reviewers, assignees for Dependabot PRs
- Auto-merge Dependabot PRs: safe for patch updates to Actions, not for major deps
- Dependabot security alerts vs version updates: two separate features

**Secret scanning:**
- Automatically enabled for public repos; can enable for private
- Custom patterns: define regex patterns for internal secrets (OpenBao token format, Harbor API key format)
- Secret scanning push protection: blocks pushes containing detected secrets before they land in git
- What it detects by default: AWS keys, GitHub tokens, Stripe keys, ~200 providers
- Alerts: where to find them (Security tab > Secret scanning), how to mark false positives

**Code scanning (CodeQL):**
- `.github/workflows/codeql.yml` — standard setup via "Set up this workflow" button
- Languages supported: javascript, python, go, ruby, java, cpp, csharp, swift
- For our repos: Python (Ansible scripts, agent code), shell scripts via `github/codeql-action/analyze`
- Running on schedule + PR: recommended config
- SARIF results: integrates with Security tab > Code scanning alerts

**CODEOWNERS for security review:**
- `.github/CODEOWNERS` requiring security review for specific paths:
  - `ansible/roles/hardening/**` → requires review
  - `opentofu/modules/firewall/**` → requires review
  - `.github/workflows/**` → requires review (Actions workflow changes themselves)

**Actions security:**
- Pinning Actions to commit SHA vs version tag: `uses: actions/checkout@v4` vs `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`
- Why SHA pinning matters: a compromised `v4` tag could inject malicious code; SHA is immutable
- `dependabot.yml` for `github-actions` ecosystem keeps SHA-pinned Actions updated automatically
- `GITHUB_TOKEN` permissions: principle of least privilege — `permissions: contents: read` at workflow level, override per job
- `pull_request_target` security: runs with write access even for fork PRs — never use `pull_request_target` with `actions/checkout` on fork HEAD

**Audit log:**
- GitHub org audit log: what events are logged, how long retained
- `gh api /orgs/{org}/audit-log` — accessing audit log via API
- Streaming audit log to SIEM: supported providers, webhook delivery

---

### GH-14. Reusable Workflows and Composite Actions

**Reusable workflows:**
- `workflow_call` trigger: making a workflow callable
- Inputs: `inputs.<name>` (required/optional, type: string/boolean/number/choice)
- Secrets: `secrets: inherit` vs explicit secret passing
- Outputs: `outputs.<name>` referencing job outputs
- Calling from another workflow: `uses: ./.github/workflows/validate.yml` (same repo) or `uses: KeemWilliams/helix-stax-infra/.github/workflows/validate.yml@main` (cross-repo)
- When to use reusable workflows: shared validation logic across multiple repos

**Composite actions:**
- Defined in `.github/actions/<name>/action.yml`
- `runs.using: composite` — steps array using shell or other actions
- Inputs and outputs
- When to use composite action vs reusable workflow: composite for step grouping within a job; reusable workflow for full job sharing
- Example: composite action `setup-tofu` that installs OpenTofu + configures auth in one step

**Workflow templates (starter workflows):**
- `.github/workflow-templates/` at org level — templates shown when adding new workflow
- When relevant: if we add repos and want standard lint setups

---

### GH-15. Claude Code Action (Future Team Use)

**What it is:**
- `anthropics/claude-code-action` — a GitHub Action that runs Claude Code as a reviewer/implementer
- Triggered by PR comments mentioning `@claude` or on PR open
- Claude Code reads the repo, understands context, can comment or implement changes

**Setup requirements:**
- `ANTHROPIC_API_KEY` as GitHub Actions secret
- Permissions: `pull-requests: write`, `contents: write` (if implementing changes)
- Trigger: `issue_comment` event, checking `contains(github.event.comment.body, '@claude')`

**Use cases for Helix Stax:**
- Code review: `@claude review this PR for security issues`
- Implementation: `@claude implement the changes described in this issue`
- Documentation: `@claude update the runbook for this change`
- IaC review: `@claude check if this OpenTofu change follows our patterns`

**How Claude Code uses CLAUDE.md in repos:**
- Project-level `CLAUDE.md` files provide context to Claude Code about conventions, stack, patterns
- `CLAUDE.md` at repo root is loaded automatically
- `.claude/` directory: agent definitions, skills — Claude Code-specific tooling
- For `helix-stax-infra`: CLAUDE.md should document our conventions (OpenTofu not Terraform, AlmaLinux 9.7, etc.)

**Limitations and considerations:**
- API cost per invocation: Claude API usage charged per token
- Security: Claude Code sees all repo contents — ensure no secrets are in plaintext
- Permissions: careful with `contents: write` — Claude could commit code
- `fork` PRs: ANTHROPIC_API_KEY not available to fork PRs — action only works on same-repo PRs

---

### GH-16. CLAUDE.md and `.claude/` in GitHub Repos

**How Claude Code uses project context:**
- `CLAUDE.md` at repo root: read at session start, informs agent about project conventions
- Nested `CLAUDE.md` files: `ansible/CLAUDE.md`, `opentofu/CLAUDE.md` for directory-specific context
- `.claude/agents/`: project-local agent definitions (stax-* agents)
- `.claude/skills/`: project-local skills loaded by agents
- `.claude/settings.json`: project-level settings (pre-approved bash commands, etc.)
- `.pact-project`: marker file identifying project root for agent registry scanning

**What goes in CLAUDE.md for helix-stax-infra:**
- Stack decisions: OpenTofu NOT Terraform, AlmaLinux 9.7, K3s, Zitadel NOT Authentik
- Convention rules: no secrets in git, all production via Helm, no Docker Compose
- Node IPs and SSH details for agent reference
- ClickUp IDs for task tracking
- Naming conventions, file locations

**`.claude/` in git vs .gitignore:**
- `.claude/agents/` and `CLAUDE.md`: commit to git (project instructions)
- `.claude/settings.json`: commit if team-shared; `.gitignore` if personal preferences
- Agent memory directories (`~/.claude/agent-memory/`): never commit — user-scope only

---

### GH-17. Monorepo vs Multi-Repo Patterns

**Our pattern: separate repos per concern:**
- `helix-stax-infra`: IaC, Helm, Ansible — the platform repo
- Per-service repos: application code (future)
- Rationale: IaC and app code have different access controls, audit trails, deploy frequencies

**Cross-repo references in Actions:**
- Calling a reusable workflow from another repo: `uses: KeemWilliams/helix-stax-infra/.github/workflows/lint.yml@main`
- Cross-repo dispatch: `repository_dispatch` to trigger a workflow in another repo
- Shared action in `.github` repo: GitHub's special `.github` repo for org-wide defaults

**ArgoCD and multi-repo:**
- ArgoCD watches `helix-stax-infra` for Helm chart changes; app repos for Dockerfile changes
- Each app repo has its own `Dockerfile`; CI (Devtron) builds the image
- ArgoCD `Application` manifest points at the Helm chart in `helix-stax-infra` with image tag override

**GitHub Projects vs ClickUp:**
- GitHub Projects (Project Boards): kanban at the code level — PR status, issue status
- ClickUp: our primary project management — business tasks, sprints, roadmap
- Our policy: ClickUp for all task management; GitHub Issues for bugs/tasks that are code-linked; GitHub Projects not used (ClickUp replaces it)
- Cross-linking: ClickUp tasks reference GitHub PRs/issues via URL; GitHub Issues may mention ClickUp task IDs in description

---

### Best Practices and Anti-Patterns

**Top 10 best practices for GitHub in a self-hosted K3s environment:**
- What are the most impactful security configurations for a small team (one person) on GitHub?
- How should GitHub Actions secrets be structured for a single-person team vs a larger team?
- What is the correct way to handle SOPS keys in Actions without exposing them in logs?
- What branch protection rules are essential vs nice-to-have for a one-person operation?
- When should a GitHub Action be a reusable workflow vs a composite action vs a simple step?

**Anti-patterns that affect our setup specifically:**
- Using `pull_request_target` without understanding the security implications
- Not pinning Action versions to SHA (supply chain risk)
- Putting the same CI logic in both Devtron AND GitHub Actions (double builds)
- Using GHCR when Harbor is already deployed (fragmented registry)
- Forgetting that `GITHUB_TOKEN` expires with the job — no long-lived credential
- Running `tofu apply` in Actions instead of restricting to `tofu plan` (apply via ArgoCD/manual only)
- Storing OpenBao root token in GitHub Secrets (use AppRole or OIDC instead)
- GitHub Actions as a full CD system when ArgoCD is already deployed

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| GitHub Actions vs Devtron | Linting, validation, PR automation | GitHub Actions | Native GitHub, no Devtron overhead |
| GitHub Actions vs Devtron | Docker builds, Helm deploys | Devtron | Devtron CI/CD is primary pipeline |
| Webhooks vs `repository_dispatch` | n8n needs real-time GitHub events | GitHub Webhooks | Lower latency, no Actions overhead |
| REST vs GraphQL API | Simple CRUD operations | REST via `gh api` | Simpler, `gh` wraps it well |
| REST vs GraphQL API | Complex queries, batch operations | GraphQL | One request, exact data shape |
| GHCR vs Harbor | Container images | Harbor | Already deployed, single registry |
| SOPS in Actions vs OpenBao OIDC | Short-term | SOPS + GitHub Secret | Simpler to implement initially |
| SOPS in Actions vs OpenBao OIDC | Long-term | OpenBao OIDC | No static credentials in GitHub |
| `tofu plan` in Actions | On every PR to `main` | Yes | Catch IaC errors before merge |
| `tofu apply` in Actions | Never | Never | Apply only via manual or ArgoCD |
| SHA-pinning Actions | Always | Always | Supply chain security |
| GitHub Projects | Project management | Never (use ClickUp) | ClickUp is our PM system |

### Common Pitfalls

- `GITHUB_TOKEN` has limited permissions by default — must explicitly grant `permissions: pull-requests: write` or the PR comment step fails silently
- `gh` CLI in Actions needs `GITHUB_TOKEN` set: usually auto-set, but `gh auth login --with-token <<< "$GITHUB_TOKEN"` is the explicit pattern
- `on: pull_request` runs with read-only token for fork PRs — if you need write access, use `pull_request_target` with extreme caution
- OpenTofu state in Actions: if state is in MinIO (S3-compatible), the `AWS_*` env vars must point at MinIO not real AWS
- SOPS decrypt output must be masked immediately: `echo "::add-mask::$(cat decrypted.yaml | grep password | awk '{print $2}')"` — but this is fragile; better to never print decrypted content
- Webhook delivery failures are silent unless you check the delivery log: set up n8n alerting for webhook failures
- `gh pr create` in Actions requires a branch other than `main` — if running on `main`, it fails; ensure the workflow runs on a feature branch
- Branch protection + GITHUB_TOKEN: the auto-generated `GITHUB_TOKEN` cannot bypass branch protection rules — if a bot commit needs to go to `main`, it needs a PAT with bypass permissions
- `workflow_dispatch` inputs are strings only — no `int` type, cast explicitly in workflow
- Dependabot PRs don't have access to org-level secrets by default — need `dependabot.yml` secret configuration or `pull_request_target` workflow

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- `gh` CLI quick reference: most-used commands for PR, issue, release, api, run operations
- GitHub Actions trigger reference: `on:` events with common filters
- Secrets and variables: how to set and consume in workflows
- Webhook event payload fields quick reference
- Branch protection checklist
- Troubleshooting: common failures and fixes (GITHUB_TOKEN permissions, fork PR limits, rate limits)
- Integration points: Actions ↔ n8n, Actions ↔ OpenTofu, Actions ↔ Ansible, gh CLI ↔ Claude Code
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete `gh` CLI flag reference for every subcommand (pr, issue, release, api, run, workflow, secret, variable)
- Complete GitHub Actions context reference (`github.*`, `env.*`, `secrets.*`, `steps.*`, `needs.*`)
- Complete webhook payload schemas for push, pull_request, issues, release events
- Complete branch protection ruleset configuration
- Complete `dependabot.yml` config for our stack (github-actions, terraform/opentofu, docker)
- Complete `.github/labeler.yml` for helix-stax-infra path structure
- OpenBao OIDC configuration for Actions (full setup procedure)
- SOPS + age decrypt pattern in Actions (complete workflow snippet)
- `kubeconform` validation workflow for Helm output

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real workflow: OpenTofu validate + plan on PR (`opentofu/**` path filter, post plan as comment)
- Real workflow: Ansible lint on PR (`ansible/**` path filter, SARIF upload)
- Real workflow: pre-commit checks on PR (all repos)
- Real workflow: release creation with auto-generated changelog (tag trigger)
- Real workflow: ShellCheck on all `.sh` files
- Complete `.github/CODEOWNERS` for helix-stax-infra
- Complete `.github/pull_request_template.md` matching our HANDOFF format
- Complete `.github/ISSUE_TEMPLATE/` set (bug, infra-task, security)
- Complete `dependabot.yml` for helix-stax-infra
- Complete `.github/labeler.yml` for helix-stax-infra
- `gh` CLI one-liners for agent use: create PR, add label, close issue, create release, trigger workflow
- n8n GitHub Trigger node setup (webhook URL, signature verification, event filtering)
- Reusable lint workflow called from multiple repos
- `CLAUDE.md` template for a new app repo in the Helix Stax ecosystem

Use `# GitHub Workflows, Actions, and API` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual workflow YAML, actual `gh` CLI commands, actual webhook payloads, and actual GitHub API calls. Do NOT give theory — give copy-paste-ready workflows and commands for the Helix Stax environment (KeemWilliams org, helix-stax-infra repo, n8n at n8n.helixstax.net, Harbor at harbor.helixstax.net).
