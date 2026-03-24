Of course. This is a comprehensive request that perfectly aligns with the purpose of a deep research AI. The goal is to create a canonical, non-hallucinated reference for AI agents to operate your infrastructure. I will structure the output exactly as requested, focusing on practical, copy-paste-ready information tailored to the Helix Stax environment.

# GitHub Workflows, Actions, and API

---
### ## SKILL.md Content
---
This document is a core reference for AI agents interacting with the Helix Stax GitHub environment. Use it for daily operations.

#### **`gh` CLI Quick Reference**

**Authentication:**
- **Non-interactive login (for agents):** `export GH_TOKEN=<your_pat>`
- **Verify status:** `gh auth status`
- **Use in Actions:** Set `env: GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}`

**Pull Request (PR) Operations:**
- **Create PR:** `gh pr create --title "feat: New feature" --body-file - --base main --head my-feature-branch --label "feat,needs-review"`
- **List PRs:** `gh pr list --state open --author "@me"`
- **Merge PR:** `gh pr merge <number> --squash --delete-branch`
- **Approve PR:** `gh pr review <number> --approve`
- **Check CI Status:** `gh pr checks <number>`
- **Edit PR:** `gh pr edit <number> --add-label "bugfix" --remove-assignee "@me"`
- **View PR JSON:** `gh pr view <number> --json number,title,state,labels,headRefName`

**Issue Operations:**
- **Create Issue:** `gh issue create --title "Bug: API is slow" --body "..." --label "bug,performance" --assignee "KeemWilliams"`
- **List Issues:** `gh issue list --label "bug" --state open`
- **Close Issue:** `gh issue close <number> --reason completed`
- **Comment on Issue:** `gh issue comment <number> --body "I'm working on this."`

**Release Operations:**
- **Create Release from Tag:** `gh release create v1.2.3 --generate-notes --title "Release v1.2.3" --prerelease`
- **Upload Asset:** `gh release upload v1.2.3 ./my-asset.zip`

**Actions/Workflow Operations:**
- **List Runs:** `gh run list --workflow "ci.yml" --branch "main"`
- **View Run Logs:** `gh run view <run-id> --log`
- **Trigger Manual Workflow:** `gh workflow run "manual-task.yml" -f input1=value1`

**API and Scripting:**
- **Generic GET:** `gh api /repos/{owner}/{repo}/pulls --jq '.[0].title'`
- **Generic POST:** `gh api --method POST /repos/{owner}/{repo}/issues -f title="API Issue" -f body="Details"`
- **Get Rate Limit:** `gh api rate_limit`

#### **GitHub Actions Quick Reference**

**Common Triggers (`on:`)**
```yaml
on:
  push:
    branches: [ main ]
    tags: [ 'v*.*.*' ]
    paths: [ 'src/**' ]

  pull_request:
    types: [ opened, synchronize, reopened ]
    branches: [ main ]
    paths: [ 'src/**' ]

  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to run in'
        required: true
        type: choice
        options: [ staging, production ]

  schedule:
    - cron: '30 5 * * 1' # Every Monday at 05:30 UTC
```

**Step Outputs and Environment Variables**
```yaml
- name: Set an output
  id: my_step
  run: echo "my_output=hello" >> $GITHUB_OUTPUT

- name: Use the output
  run: echo "The output was ${{ steps.my_step.outputs.my_output }}"

- name: Set an env var for next steps
  run: echo "MY_VAR=world" >> $GITHUB_ENV
```

**Secrets and Variables**
- **In a step:** `env: MY_SECRET: ${{ secrets.MY_SECRET_NAME }}`
- **In a step:** `env: MY_VAR: ${{ vars.MY_VARIABLE_NAME }}`

#### **Integration Points & Boundaries**

| Task | Tool | Why |
|---|---|---|
| IaC Validation (`tofu plan`) | GitHub Actions | Quality gate on PR, before merge. |
| Ansible Linting | GitHub Actions | Catches syntax errors on PR. |
| Code Quality (shellcheck, etc.) | GitHub Actions | Static analysis is a CI task. |
| PR Automation (labeling) | GitHub Actions | Native GitHub ecosystem. |
| **Docker Image Builds** | **Devtron** | Primary CI pipeline. |
| **Helm Deployments** | **ArgoCD** | Primary CD (GitOps). |
| Real-time Event Orchestration | GitHub Webhooks → n8n | Lower latency, no Actions overhead. |
| Triggering a Devtron build | Devtron watches Git | Avoids complex cross-system calls. |

#### **Branch Protection Checklist (for `helix-stax-infra/main`)**
- [x] Require a pull request before merging
- [x] Require status checks to pass before merging (`tofu-validate`, `ansible-lint`, `code-quality`)
- [x] Require conversation resolution before merging
- [x] Require linear history (squash merges)
- [x] Do not allow force pushes
- [x] Require signed commits

#### **Troubleshooting & Common Pitfalls**
- **Permission Denied (e.g., commenting on PR):** The job needs `permissions: pull-requests: write`. `GITHUB_TOKEN` permissions are minimal by default.
- **Fork PRs fail on steps needing secrets:** Secrets are not passed to PRs from forks. Use `pull_request_target` with extreme caution or require changes to be made on a branch in the main repo.
- **`gh` CLI auth fails in Actions:** Ensure `GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}` is in the step's `env` block.
- **`gh pr create` fails:** Ensure the workflow is running on a feature branch, not `main`.
- **SOPS key exposed in logs:** Never `echo` or `cat` decrypted files. Mask secrets with `::add-mask::` if absolutely necessary, but preferably avoid printing them at all.
- **Webhook not firing in n8n:** Check GitHub Repo > Settings > Webhooks > Recent Deliveries for `200 OK` responses. Redeliver failed events manually. Verify the n8n webhook URL and secret.

---
### ## reference.md Content
---
This document provides deep specifications for GitHub tools and concepts used at Helix Stax.

#### **GH-1. `gh` CLI Complete Reference**

**Authentication**
- `gh auth login`: Interactive login.
  - `--with-token`: Pass token via stdin.
  - `--hostname helixstax.net`: For GitHub Enterprise Server (not our case).
- `gh auth status`: Shows active account and authentication method.
- `gh auth token`: Prints the active auth token.
- `GITHUB_TOKEN` vs `GH_TOKEN`:
  - `GH_TOKEN`: A PAT you create. Used by `gh` CLI for non-interactive auth. Takes precedence.
  - `GITHUB_TOKEN`: An auto-generated, short-lived token provided *inside* a GitHub Actions workflow. Its permissions are defined by the workflow's `permissions:` block.
- **Token Scopes Needed for Agents:**
  - `repo`: Full control of repositories (needed for creating PRs, managing releases, repo operations).
  - `workflow`: For managing and triggering Actions (`gh workflow run`).
  - `write:packages`, `read:packages`: Not needed (we use Harbor).
  - `admin:org`: For org-level operations. Use with care.
  - `delete_repo`: For repo deletion.

**Pull Request (PR) Operations**
- `gh pr create`: Creates a PR.
  - `--title <string>`: Title.
  - `--body <string>`: Body.
  - `--body-file <file>`: Read body from file (`-` for stdin).
  - `--base <branch>`: The branch to merge into (e.g., `main`).
  - `--head <branch>`: The branch to merge from.
  - `--draft`: Create as a draft.
  - `--label <name>,<name>`: Add labels.
  - `--assignee <user>`: Assign someone.
  - `--reviewer <user>`: Request a review.
- `gh pr list`: Lists PRs.
  - `--state <open|closed|merged|all>`
  - `--author <user>`
  - `--label <name>`
  - `--base <branch>`
  - `--json <fields>`: Output as JSON. Fields: `number`, `title`, `author`, `labels`, `state`, `headRefName`, `baseRefName`, `url`, `createdAt`, `updatedAt`.
  - `--jq <expression>`: Filter JSON output.
- `gh pr view <number>`: View a single PR.
  - `--json <fields>`: Same fields as `list`, plus `body`, `comments`, `reviews`, `commits`, `files`, `statusCheckRollup`.
- `gh pr merge <number>`: Merges a PR.
  - `--merge`: Create a merge commit.
  - `--squash`: Squash commits into one. (Our standard)
  - `--rebase`: Rebase and merge.
  - `--auto`: Enable auto-merge.
  - `--delete-branch`: Delete the head branch after merge.
- `gh pr review <number>`: Add a review.
  - `--approve`: Approve changes.
  - `--request-changes`: Request changes.
  - `--comment <body>`: Add a comment.
- `gh pr edit <number>`: Edits a PR.
  - `--title`, `--body`, `--add-label`, `--remove-label`, `--add-assignee`, `--remove-assignee`, `--add-reviewer`, `--remove-reviewer`.
- `gh pr checks <number>`: Shows status of checks. `--watch` to poll.
- `gh pr diff <number>`: Shows the diff.
- `gh pr close <number>` / `gh pr reopen <number>`: Closes/reopens a PR.

**Issue Operations**
- `gh issue create`:
  - `--title`, `--body`, `--body-file`, `--label`, `--assignee`, `--project '<name>'`, `--milestone '<name>'`.
- `gh issue list`:
  - `--state <open|closed|all>`, `--label`, `--assignee`, `--milestone`.
  - JSON fields: `number`, `title`, `state`, `author`, `labels`, `assignees`, `body`, `url`, `createdAt`, `updatedAt`.
- `gh issue view <number>`: View an issue.
- `gh issue edit <number>`:
  - `--title`, `--body`, `--add-label`, `--remove-label`, etc.
- `gh issue close <number>` / `gh issue reopen <number>`:
  - `--reason <completed|not_planned>`: For closing.
- `gh issue comment <number> --body <body>`: Adds a comment.
- `gh issue develop <number> --name <branch-name>`: Create a branch for an issue.

**Release Operations**
- `gh release create <tag>`:
  - `--title <string>`, `--notes <string>`, `--notes-file <file>`, `--draft`, `--prerelease`.
  - `--target <branch>`: Target branch or commit SHA.
  - `--generate-notes`: Auto-generate notes from PRs since last release. Uses PR titles and `.github/release.yml` config.
- `gh release list`: `--limit <int>`.
- `gh release view <tag>`: `--json <fields>`.
- `gh release upload <tag> <file...>`: Attaches files.
- `gh release edit <tag>`: Modify a release.
- `gh release delete <tag>`: Deletes a release.

**API Operations**
- `gh api <endpoint>`: Makes an authenticated API call.
  - `--method <GET|POST|...>`: HTTP Method.
  - `-f, --field <key=value>`: Form field for POST/PATCH.
  - `-F, --raw-field <key=value>`: Raw form field (file uploads).
  - `--jq <expression>`: Filter JSON response.
  - `--paginate`: Automatically follows `Link` header for paginated results.
- `gh api graphql -f query=@<file>.graphql`: Executes a GraphQL query.
- `gh api rate_limit`: Checks rate limit status.

**Actions/Workflow Operations**
- `gh run list`:
  - `--workflow <name.yml>`, `--branch <name>`, `--status <completed|...>`
- `gh run view <id>`: View run details. `--log` for full logs, `--job <id>` for job-specific logs.
- `gh run watch <id>`: Live tail logs.
- `gh run rerun <id>`: Reruns a workflow. `--failed` to rerun only failed jobs.
- `gh run cancel <id>`: Cancels a run.
- `gh workflow list`: Lists workflow files.
- `gh workflow run <workflow.yml>`: Manually triggers `workflow_dispatch`.
  - `-f <key=value>`: Pass inputs.
- `gh workflow enable|disable <workflow.yml>`: Enables/disables a workflow.

**Repository Operations**
- `gh repo view`: View repo details.
- `gh repo create <name>`: `--private`, `--public`, `--add-remote`, `--source .`.
- `gh repo list <org>`: List repos in an organization.
- `gh repo set-default <owner/repo>`: Sets the default repo for the current directory.
- `gh secret set <name>`: Sets an Actions secret.
  - `--body <value>`, `--env <name>` (for environment secret), `--org` (for org secret).
- `gh secret list`: `-e <env>`, `--org`.
- `gh secret delete <name>`.
- `gh variable set/list/delete`: Same as secrets, for non-sensitive values.

**Non-Interactive/Scripting**
- Flags: Most commands accept `--repo <owner/repo>` to avoid prompts.
- Environment Variables:
  - `GH_REPO`: Overrides repo detection.
  - `GH_HOST`: Overrides GitHub hostname.
  - `GH_TOKEN`: PAT for auth.
  - `GH_EDITOR`: Editor for commands like `gh issue create`.
  - `NO_COLOR`: Disables color output.
  - `GH_PROMPT_DISABLED=1`: Fails instead of prompting. Essential for scripts.
- HEREDOC for multiline bodies: `gh pr create --body-file - <<< "Multi-line body here"`

#### **GH-2. GitHub Actions Core Concepts**

**Workflow File Structure (`.github/workflows/*.yml`)**
- `name`: Workflow name displayed in UI.
- `on`: Trigger event(s).
- `jobs`: A map of one or more jobs.
  - `<job_id>`:
    - `name`: Job name displayed in UI.
    - `runs-on`: Runner type (e.g., `ubuntu-latest`, `[self-hosted, linux]`). `ubuntu-latest` currently maps to `ubuntu-22.04`.
    - `needs`: A list of `job_id`s that must complete first.
    - `if`: Conditional to run the job.
    - `env`: Map of environment variables for all steps in the job.
    - `outputs`: Map of outputs to share with other jobs.
    - `steps`: An array of steps.
      - `name`: Step name.
      - `uses`: Action to run (e.g., `actions/checkout@v4`).
      - `with`: Inputs for the action.
      - `run`: Shell command to execute.
      - `env`: Step-specific environment variables.
      - `id`: ID to reference step outputs.
      - `if`: Conditional to run the step.
      - `continue-on-error: true`: Allows workflow to continue if this step fails.

**Trigger Events (`on:`) Detailed**
- `push`:
  - `branches`/`branches-ignore`: `[ 'main', 'releases/**' ]`
  - `tags`/`tags-ignore`: `[ 'v*.*.*' ]`
  - `paths`/`paths-ignore`: `[ 'src/**', 'docs/**' ]`
- `pull_request`:
  - `types`: `opened`, `synchronize`, `reopened`, `closed`, `labeled`, `unlabeled`, `edited`. `synchronize` is for new commits to the PR branch.
- `pull_request_target`: Runs in the context of the *base* branch. It has write access and access to secrets even for fork PRs. **Extremely dangerous** if you check out and run code from the PR head. Use only for labeling or commenting based on PR metadata.
- `workflow_dispatch`: Manual trigger.
  - `inputs`: Defines UI form elements. Types: `string`, `boolean`, `choice`, `environment`.
- `schedule`: Cron trigger (`*/5 * * * *` is the min frequency). Always runs on the default branch.
- `workflow_call`: Makes a workflow reusable.
  - `inputs`: Defines inputs the caller can pass.
  - `outputs`: Defines outputs the caller can receive.
  - `secrets`: Defines secrets the caller can pass (e.g., `my_secret: { required: true }`) or `inherit`.
- `repository_dispatch`: External trigger via API.
  - `types`: Custom event types to filter on.

**Contexts**
- `github`: Event payload. `github.sha`, `github.ref`, `github.ref_name`, `github.event_name`, `github.actor`, `github.repository`, `github.run_id`, `github.run_number`.
  - For PRs: `github.head_ref` (feature branch), `github.base_ref` (base branch).
- `env`: Environment variables.
- `secrets`: Secrets.
- `vars`: Non-secret variables.
- `steps`: Step outputs. `steps.<id>.outputs.<key>`.
- `needs`: Job outputs. `needs.<job_id>.outputs.<key>`.
- `runner`: Runner info. `runner.os`, `runner.arch`, `runner.temp`.
- `job`: Job status. `job.status`.
- **Functions:** `contains()`, `startsWith()`, `endsWith()`, `format()`, `join()`, `toJSON()`, `fromJSON()`.
- **Status Checks:** `if: success()`, `if: failure()`, `if: always()`, `if: cancelled()`.

**Environment Variables**
- `GITHUB_OUTPUT`: Path to a file for setting step outputs. `echo "key=value" >> $GITHUB_OUTPUT`.
- `GITHUB_ENV`: Path to a file for setting environment variables for subsequent steps. `echo "KEY=value" >> $GITHUB_ENV`.
- `GITHUB_STEP_SUMMARY`: Path to a file to append Markdown content to the job summary.
- `GITHUB_PATH`: Path to a file to add directories to the `PATH` for subsequent steps.
- `GITHUB_TOKEN`: Auto-generated token. Permissions are controlled by the `permissions:` key at the workflow or job level.

**Caching (`actions/cache@v4`)**
- `path`: Directory to cache.
- `key`: `runner.os}-${{ hashFiles('**/lockfiles') }}`. A cache hit only occurs on an exact key match.
- `restore-keys`: Fallback keys for partial matches.
- `steps.<id>.outputs.cache-hit`: `true` if an exact match was found.

**Artifacts (`actions/upload-artifact@v4` / `actions/download-artifact@v4`)**
- `name`: Artifact name.
- `path`: File/directory to upload/download to.
- `retention-days`: How long to keep the artifact.

**Concurrency**
- `concurrency`:
  - `group`: A string to group jobs. Often `github.workflow}-${{ github.ref }}`.
  - `cancel-in-progress: true`: Cancels any in-progress runs in the same concurrency group.

#### **GH-7. Webhook Payload Structure**

**Webhook Configuration:**
- **URL:** `https://n8n.helixstax.net/webhook/<path-from-n8n-node>`
- **Content type:** `application/json`
- **Secret:** A strong random string. Used by n8n to verify the `X-Hub-Signature-256` header.
- **Events:** Select only the events you need (e.g., `pull_request`, `issues`, `push`).

**Common Payload Fields:**
- `repository`: `{ "name": "...", "full_name": "..." }`
- `organization`: `{ "login": "KeemWilliams" }`
- `sender`: `{ "login": "...", "type": "User" }`

**`pull_request` Payload:**
```json
{
  "action": "opened",
  "number": 123,
  "pull_request": {
    "url": "...",
    "id": 12345,
    "node_id": "...",
    "number": 123,
    "state": "open",
    "title": "feat: Add new feature",
    "user": { "login": "KeemWilliams" },
    "body": "...",
    "labels": [ { "name": "feat" } ],
    "head": { "ref": "feature-branch", "sha": "..." },
    "base": { "ref": "main", "sha": "..." },
    "merged": false,
    "mergeable": true
  }
}
```

**`push` Payload:**
```json
{
  "ref": "refs/heads/main",
  "before": "...",
  "after": "...",
  "commits": [
    {
      "id": "...",
      "message": "feat: Add new feature\n\n- Details",
      "author": { "name": "...", "email": "..." }
    }
  ],
  "pusher": { "name": "...", "email": "..." }
}
```

**`issues` Payload:**
```json
{
  "action": "opened",
  "issue": {
    "number": 124,
    "title": "Bug report",
    "user": { "login": "KeemWilliams" },
    "labels": [ { "name": "bug" } ],
    "state": "open",
    "assignees": []
  }
}
```

#### **GH-9. Secrets and OpenBao/SOPS**

**Secrets Scoping**
- **Environment:** Highest priority. Tied to a specific environment (e.g., `production`).
- **Repository:** Available to all workflows in the repo.
- **Organization:** Available to selected repos in the org. Lowest priority.

**SOPS + age in Actions**
1.  **Store Key:** Save the `age` private key (starts with `AGE-SECRET-KEY-`) as a repository secret named `SOPS_AGE_KEY`.
2.  **Workflow Steps:**
    ```yaml
    - name: Decrypt SOPS file
      env:
        SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
      run: |
        # Install sops and age
        # (Assuming they are not already on the runner)
        sudo curl -o /usr/local/bin/sops -L https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
        sudo chmod +x /usr/local/bin/sops
        # Decrypt
        sops --decrypt path/to/encrypted.yaml > decrypted.yaml
        # IMPORTANT: Do not cat or echo the decrypted file.
        # Use its contents in this step, then remove it.
        rm decrypted.yaml
    ```
3.  **To prevent log leaks:** Any tool that might echo the decrypted content should be run with `set +x` or its output redirected to `/dev/null`. Masking (`::add-mask::`) is a fallback, not a primary defense.

**OpenBao OIDC Authentication (Long-term, more secure)**
This eliminates static tokens from GitHub Secrets.
1.  **Configure GitHub as OIDC Provider in OpenBao:**
    - Enable the JWT auth backend in OpenBao: `bao auth enable jwt`.
    - Configure it to trust GitHub's OIDC provider:
      ```bash
      bao write auth/jwt/config \
        oidc_discovery_url="https://token.actions.githubusercontent.com" \
        bound_issuer="https://token.actions.githubusercontent.com"
      ```
2.  **Create a Role in OpenBao:**
    - The role binds the OIDC token claims (like repo name) to an OpenBao policy.
      ```bash
      bao write auth/jwt/role/helix-stax-infra-ci \
        role_type="jwt" \
        user_claim="repository" \
        bound_claims='{"repository": "KeemWilliams/helix-stax-infra"}' \
        policies="ci-policy" \
        ttl="15m"
      ```
3.  **Use in GitHub Actions (`hashicorp/vault-action`):**
    ```yaml
    - name: Authenticate to OpenBao
      uses: hashicorp/vault-action@v2
      with:
        url: https://bao.helixstax.net # Or your OpenBao address
        method: jwt
        role: helix-stax-infra-ci
    - name: Retrieve secret
      run: echo "My secret is $MY_SECRET_FROM_BAO"
      env:
        MY_SECRET_FROM_BAO: ${{ secrets.MY_SECRET_FROM_BAO }} # Assuming the action maps secrets to this context
    ```

---
### ## examples.md Content
---
This file contains copy-paste-ready examples, configurations, and workflows for the Helix Stax environment.

#### **Real Workflow: OpenTofu Validate & Plan on PR**

**File: `.github/workflows/tofu-plan.yml`**
```yaml
name: 'OpenTofu Plan'

on:
  pull_request:
    paths:
      - 'opentofu/**'
      - '.github/workflows/tofu-plan.yml'

permissions:
  contents: read
  pull-requests: write # Allows commenting on the PR

jobs:
  plan:
    name: 'OpenTofu Plan'
    runs-on: ubuntu-latest
    env:
      # Assuming Hetzner token is needed for provider init/plan
      HETZNER_TOKEN: ${{ secrets.HETZNER_API_TOKEN }}
      # Add S3-compatible backend secrets if needed
      # AWS_ACCESS_KEY_ID: ${{ secrets.S3_ACCESS_KEY }}
      # AWS_SECRET_ACCESS_KEY: ${{ secrets.S3_SECRET_KEY }}
      TF_IN_AUTOMATION: true

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: '1.7.2' # Pin to a specific version

      - name: OpenTofu Init
        id: init
        working-directory: ./opentofu
        run: tofu init -no-color

      - name: OpenTofu Validate
        id: validate
        working-directory: ./opentofu
        run: tofu validate -no-color

      - name: OpenTofu Plan
        id: plan
        working-directory: ./opentofu
        run: tofu plan -no-color -out=tfplan

      - name: Format Plan Output
        id: format-plan
        run: |
          PLAN_OUTPUT=$(tofu -C ./opentofu show -no-color tfplan)
          # Use a HEREDOC to handle multi-line string escaping
          EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
          echo "PLAN<<$EOF" >> "$GITHUB_OUTPUT"
          echo "#### OpenTofu Plan" >> "$GITHUB_OUTPUT"
          echo '```' >> "$GITHUB_OUTPUT"
          echo "$PLAN_OUTPUT" >> "$GITHUB_OUTPUT"
          echo '```' >> "$GITHUB_OUTPUT"
          echo "$EOF" >> "$GITHUB_OUTPUT"

      - name: Post Plan to PR
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.pull_request.number }}
          body: ${{ steps.format-plan.outputs.PLAN }}
          # Edit previous comment if one exists
          edit-mode: replace
```

#### **Real Workflow: Ansible Lint on PR**

**File: `.github/workflows/ansible-lint.yml`**
```yaml
name: Ansible Lint

on:
  pull_request:
    paths:
      - 'ansible/**'
      - '.github/workflows/ansible-lint.yml'

permissions:
  contents: read
  security-events: write # Allows uploading SARIF results

jobs:
  lint:
    name: 'Ansible Lint'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Ansible Lint
        uses: ansible/ansible-lint-action@main
        with:
          path: "ansible/"
          # Generates SARIF report for Code Scanning
          args: "--format sarif -o ansible-lint-results.sarif"

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: ansible-lint-results.sarif
          category: ansible-lint
```

#### **Real Workflow: Pre-Commit & Quality Checks**

**File: `.github/workflows/quality-checks.yml`**
```yaml
name: Code Quality Checks

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  pre-commit:
    name: Pre-Commit Hooks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - uses: pre-commit/action@v3.0.1

  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@2.0.0
        with:
          scandir: './' # Scan all shell scripts in the repo

  markdownlint:
    name: Markdown Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run markdownlint
        uses: DavidAnson/markdownlint-cli2-action@v16
        with:
          globs: '**/*.md'
```

#### **Real Workflow: Release Creation**

**File: `.github/workflows/release.yml`**
```yaml
name: Create Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write # Needed for gh release create

jobs:
  create-release:
    name: Create Release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Create GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${{ github.ref_name }} \
            --generate-notes \
            --title "Release ${{ github.ref_name }}"
```

**File: `.github/release.yml` (To categorize release notes)**
```yaml
changelog:
  categories:
    - title: '🚀 New Features'
      labels:
        - 'feat'
        - 'feature'
    - title: '🐛 Bug Fixes'
      labels:
        - 'fix'
        - 'bug'
    - title: '⚙️ Infrastructure Changes'
      labels:
        - 'infra'
        - 'ansible'
        - 'opentofu'
    - title: '📄 Documentation'
      labels:
        - 'docs'
    - title: '🤖 CI/CD'
      labels:
        - 'ci'
    - title: '🧹 Chores & Maintenance'
      labels:
        - 'chore'
```

#### **Configuration Files**

**`.github/CODEOWNERS`**
```
# All infrastructure changes are owned by Keem
* @KeemWilliams

# Specific review for critical changes
.github/workflows/ @KeemWilliams
opentofu/ @KeemWilliams
ansible/ @KeemWilliams
```

**`.github/dependabot.yml`**
```yaml
version: 2
updates:
  # Keep GitHub Actions up to date
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
    labels:
      - "ci"
      - "dependencies"

  # Check for OpenTofu provider updates (if using a dependency file)
  - package-ecosystem: "terraform"
    directory: "/opentofu"
    schedule:
      interval: "monthly"
    commit-message:
      prefix: "infra"
    labels:
      - "infra"
      - "dependencies"
      
  # Check for Dockerfile base image updates
  - package-ecosystem: "docker"
    directory: "/" # Assuming Dockerfiles are at root
    schedule:
      interval: "monthly"
    labels:
      - "infra"
      - "dependencies"
```

**`.github/labeler.yml`**
```yaml
'infra':
  - 'opentofu/**'
  - 'ansible/**'

'helm':
  - 'helm/**'

'ci':
  - '.github/**'

'docs':
  - 'docs/**'
  - '*.md'

'agents':
  - '.claude/**'
  - 'CLAUDE.md'
```

**`.github/pull_request_template.md`**
```markdown
<!--
Thank you for your contribution to Helix Stax!
This template helps ensure all necessary information is provided.
-->

### Summary
*A brief, one-sentence summary of the change.*

---

### Changes
*A detailed, bulleted list of the changes made in this PR.*
-
-
-

---

### Test Plan
*How were these changes tested? Describe the steps to reproduce your tests.*
- [ ] Ran `tofu plan` successfully.
- [ ] Ran `ansible-lint` with no new errors.
- [ ] Deployed to a local K3s cluster and verified...
- [ ] Manual verification steps...

---

### Risks & Mitigations
*What could go wrong with this change? How can we roll it back?*
- **Risk:**
- **Mitigation:**

---

### Related Tasks
*Link to any related ClickUp tasks, GitHub issues, or other documents.*
- ClickUp Task: `https://app.clickup.com/t/...`
- Related Issue: #...
```

#### **`gh` CLI Agent One-Liners**

```bash
# Create a PR from the current branch to main, with content from a file
gh pr create --base main --title "feat: New API endpoint" --body-file /path/to/pr_body.md

# Add a label and a comment to an existing PR
gh pr edit 123 --add-label "security"
gh pr comment 123 --body "Added a security label for review."

# Merge a PR that has passed its checks
gh pr merge 123 --squash --delete-branch --auto

# Create an issue and assign it
gh issue create --title "Fix dashboard rendering" --body "See screenshot." --label "bug,ui" --assignee "KeemWilliams"

# Trigger a manual workflow run to deploy to staging
gh workflow run deploy.yml --ref main -f environment=staging

# Get the SHA of the latest commit on main for an ArgoCD sync
gh api /repos/KeemWilliams/helix-stax-infra/branches/main --jq '.commit.sha'
```

#### **`CLAUDE.md` Template for a New App Repo**

```markdown
# Claude Code Project Context: My New App

This file provides context for AI agents working on this repository.

## Project Overview
- **Project Name:** My New App
- **Purpose:** [Describe what this application does]
- **Source Repo:** `KeemWilliams/my-new-app`

## Our Tech Stack
- **Source Control:** GitHub (`KeemWilliams` org)
- **CI System:** Devtron (for Docker builds), GitHub Actions (for lint/test)
- **CD System:** ArgoCD (GitOps)
- **Container Registry:** Harbor at `harbor.helixstax.net`. **We do not use GHCR.**
- **Deployment Target:** K3s on AlmaLinux 9.7
- **IaC:** OpenTofu (managed in `helix-stax-infra` repo)
- **Configuration Management:** Ansible (managed in `helix-stax-infra` repo)
- **Secrets:** OpenBao (Vault API) for runtime secrets, SOPS with `age` for secrets in git.
- **Identity:** Zitadel for SSO.
- **Task Management:** ClickUp is the source of truth for tasks. GitHub Issues are for code-specific bugs/tasks.

## Repository Conventions
- **Branches:** Create feature branches from `main`. All work happens in a PR.
- **Commits:** Follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification (e.g., `feat:`, `fix:`, `docs:`, `ci:`, `chore:`).
- **Dockerfile:** The `Dockerfile` in the root of this repo is used by Devtron to build the production image. The base image should be as minimal as possible (e.g., `alpine` or `distroless`).
- **Helm Chart:** The Helm chart for this application lives in the `helix-stax-infra` repository under `helm/charts/my-new-app`. All changes to deployment configuration (replicas, service ports, ingress) must be made there.
- **CI/CD:**
  - This repo's GitHub Actions (`/.github/workflows`) are for linting, unit tests, and code quality ONLY.
  - Pushing a new tag to this repo triggers Devtron to build a new Docker image and push it to Harbor.
  - ArgoCD then updates the K3s deployment by pulling the new image tag.
- **Secrets:** No plaintext secrets should ever be committed. Use SOPS-encrypted files for test fixtures if needed. Runtime secrets are injected by OpenBao.
```
