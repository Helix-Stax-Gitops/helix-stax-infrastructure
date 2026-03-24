# Gemini Deep Research: Security Stack (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into four separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These four tools form Helix Stax's layered security perimeter. They operate at different layers and complement each other — no single tool covers everything:

- **NeuVector**: Runtime container security. L7 deep packet inspection, process-level microsegmentation, network rules, vulnerability scanning, and compliance templates inside the K3s cluster.
- **CrowdSec**: Network and log-based threat intelligence. Reads logs from Traefik, SSH, and K3s audit logs; uses community threat feeds; blocks attackers via Cloudflare bouncer and iptables.
- **Kyverno**: Kubernetes admission control and policy enforcement. Validates, mutates, and generates K8s resources. The policy gate before anything runs in the cluster.
- **Gitleaks**: Pre-commit and CI secret scanning. Catches secrets before they reach git — the first line of defense in the secrets pipeline.

Together: Gitleaks catches secrets before commit → Kyverno enforces policy at admission → CrowdSec monitors runtime network traffic and logs → NeuVector enforces runtime container behavior.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Domains**: helixstax.com (public), helixstax.net (internal apps)
- **Identity**: Zitadel (OIDC for all services)
- **Edge**: Cloudflare (WAF + Zero Trust) → Traefik → K3s
- **Ingress**: Traefik with IngressRoute CRDs
- **Registry**: Harbor (image scanning with Trivy)
- **CI/CD**: Devtron + ArgoCD
- **Secrets**: OpenBao + External Secrets Operator + SOPS+age
- **Monitoring**: Prometheus + Grafana + Loki + Alertmanager → Rocket.Chat
- **Compliance targets**: NIST CSF 2.0, CIS Controls v8, SOC 2, ISO 27001
- **Secrets we need to detect (Gitleaks)**: OpenBao tokens (`hvs.*`, `bao.*`), Zitadel service account keys, MinIO access/secret keys, Hetzner API tokens, Harbor robot account tokens, age private keys, Cloudflare API tokens, SOPS encrypted blocks that got accidentally decrypted, GitHub PATs, Google service account JSON files, Backblaze B2 application keys

---

## What I Need Researched

### SECTION A: NeuVector (Deep Coverage — New to This Prompt)

#### A1. Architecture & Deployment on K3s
- NeuVector component roles: Controller, Enforcer, Manager, Scanner, Updater
- How NeuVector runs on K3s specifically (privileged DaemonSet for Enforcer, controller HA)
- Helm chart deployment: `neuvector/neuvector-helm`, values.yaml for K3s
- Namespace, RBAC, and PSA/PSP considerations on K3s
- CRD-based configuration vs UI-based — which survives upgrades
- Container runtime detection: K3s uses containerd — how NeuVector hooks into containerd
- Air-gapped deployment with Harbor as image mirror

#### A2. NeuVector CLI (neuvector-cli / REST API)
- How to interact with NeuVector: REST API, neuvector-cli tool, kubectl plugin
- Login and session management (JWT tokens)
- Querying network activity, policy violations, and alerts via CLI
- Exporting and importing security policies as JSON (for GitOps)
- Scanning images on-demand via CLI
- Generating compliance reports via CLI/API
- Listing and modifying network rules via API

#### A3. Runtime Security Policies
- Modes: Discover, Monitor, Protect — what each means, when to use each
- Process profile rules: allowlisting processes per container group
- File access monitoring: what files NeuVector watches inside containers
- Network rules: whitelist-based L4/L7 ingress/egress per service
- Custom groups: how to define service groups by namespace + label selectors
- Policy-as-code: exporting full ruleset to JSON, storing in git (encrypted with SOPS+age)
- How NeuVector handles sidecar containers (Linkerd, Istio, etc.)

#### A4. Deep Packet Inspection (DPI) and L7 Network Rules
- Which protocols NeuVector can decode: HTTP, HTTPS (with TLS interception?), DNS, Redis, PostgreSQL, gRPC
- How to write L7 rules (allow GET /api/health, deny POST /admin)
- Performance impact of DPI on K3s at small scale
- DPI vs Kyverno NetworkPolicy — when to use each
- How NeuVector's DPI interacts with Traefik's TLS termination

#### A5. Vulnerability Scanning
- NeuVector Scanner vs Trivy in Harbor — what each covers, which is authoritative
- How NeuVector scans running containers (vs Harbor scanning images at push)
- CVE database update cadence and how to trigger manual updates
- Admission control based on vulnerability score: blocking pods with critical CVEs
- How NeuVector scan results feed into compliance reports
- Registry integration with Harbor — scanning Harbor images from NeuVector

#### A6. Compliance Templates
- Built-in compliance templates: CIS Docker Benchmark, CIS Kubernetes Benchmark, NIST, PCI DSS, GDPR
- How to run a compliance scan and export results (JSON, PDF)
- Mapping NeuVector compliance checks to our UCM (Unified Control Matrix)
- Scheduling automated compliance scans
- Combining NeuVector compliance output with Kyverno policy reports for audit evidence

#### A7. NeuVector Admission Control vs Kyverno
- NeuVector has its own admission webhook — how it coexists with Kyverno
- Which to use for which policies: NeuVector (image-based, CVE-based) vs Kyverno (manifest-based)
- Ordering: which webhook fires first
- Can NeuVector enforce that all images come from Harbor only? (vs Kyverno doing the same)
- Conflict scenarios: what happens when both deny the same pod

#### A8. Multi-Cluster and Federation
- NeuVector federation for managing multiple clusters from a single controller
- How to set up federation with our 2-node K3s cluster (single cluster, but future-proofing)
- Remote cluster enrollment and policy sync

#### A9. NeuVector + Zitadel Integration
- NeuVector Manager login via OIDC (Zitadel as IdP)
- OIDC configuration in NeuVector: client ID, scopes, group mapping to NeuVector roles
- SAML vs OIDC support in NeuVector

---

### SECTION B: CrowdSec (Deep Coverage)

#### B1. K3s-Specific Deployment
- CrowdSec architecture in K3s: LAPI (central) vs Agent (per-node DaemonSet) — recommended topology for 2-node cluster
- Official Helm chart: `crowdsec/crowdsec`, values structure, separating LAPI deployment from Agent DaemonSet
- Persistent storage for LAPI: PVC for SQLite database (or PostgreSQL for HA)
- How agents on each node register to the central LAPI
- Mounting host log paths into agent pods: `/var/log/`, `/var/log/traefik/`, `/var/log/k3s/`
- Running on AlmaLinux with SELinux: SELinux policies or booleans needed for CrowdSec to read logs
- K3s-specific log locations: where are Traefik access logs and K3s audit logs on AlmaLinux 9.7?
- Resource limits: CPU/memory for LAPI vs agent on small cluster

#### B2. CLI Reference (cscli)
- Complete `cscli` command reference organized by subcommand
- `cscli decisions`: list, add, delete — managing manual IP blocks and bans
- `cscli alerts`: list, inspect, flush — viewing and managing alerts
- `cscli bouncers`: list, add, delete — managing bouncer registrations and API keys
- `cscli collections`: list, install, remove, upgrade, inspect — managing detection rulesets
- `cscli parsers`: list, install, remove, upgrade — managing log parsers
- `cscli scenarios`: list, install, remove, upgrade — managing attack scenario detection
- `cscli hub`: update, upgrade, list — managing the CrowdSec Hub
- `cscli metrics`: viewing agent metrics, LAPI metrics, bouncer metrics
- `cscli lapi`: register, status — LAPI registration and connectivity
- `cscli machine`: list, add, delete — managing agents registered to LAPI
- `cscli console`: enroll, status — CrowdSec Console enrollment
- Useful flags: output formats (json, table, raw), filtering by type/scope/value

#### B3. Collections (Detection Rulesets for Our Stack)
- Exact `cscli collections install` commands for our stack:
  - AlmaLinux / Linux base collections
  - SSH brute force detection (crowdsecurity/sshd)
  - Traefik log parsing (crowdsecurity/traefik or equivalent)
  - HTTP scanner detection (crowdsecurity/http-cve, crowdsecurity/nginx — adapted for Traefik)
  - K3s / Kubernetes API protection
  - CVE exploit attempt detection
- How to verify a collection is working: checking parser hits in `cscli metrics`
- Updating all installed collections: one-liner
- Writing a custom parser for K3s API server audit logs
- Writing a custom scenario for detecting kubectl exec abuse
- How to test parsers locally before deploying

#### B4. Bouncers (Traefik Middleware + nftables Firewall + Cloudflare)
- **Cloudflare bouncer**: blocking IPs at edge before traffic hits our cluster
- **Traefik Bouncer**:
  - Installation method in K3s: plugin vs middleware deployment
  - Helm/config for Traefik CrowdSec plugin: crowdsec-bouncer-traefik-plugin
  - Middleware CRD example for Traefik; applying globally vs per-IngressRoute
  - Bouncer API key generation: `cscli bouncers add traefik-bouncer`
  - LAPI URL configuration for the bouncer pod to reach LAPI
  - Handling Cloudflare real IP: configuring bouncer to use CF-Connecting-IP not remote_addr
- **Firewall Bouncer (nftables)**:
  - Installing `crowdsec-firewall-bouncer-nftables` on AlmaLinux 9.7 hosts
  - Configuration file: `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`
  - nftables table/chain that the bouncer manages; verifying blocks: `nft list ruleset`
  - SELinux considerations for firewall bouncer on AlmaLinux
  - Running the firewall bouncer as a systemd service on both nodes
- How bouncers are layered — which fires first, redundancy strategy
- Bouncer authentication: LAPI keys, how to rotate them

#### B5. Cloudflare IP Whitelisting & Parsers
- **Critical**: All public traffic arrives from Cloudflare edge IPs — CrowdSec must read CF-Connecting-IP
- How to configure CrowdSec to trust Cloudflare edge IPs and parse real client IP from headers
- Whitelisting all Cloudflare edge IP ranges so they're never banned at the firewall level
- Whitelist configuration: expressions in YAML, IP range support (CIDR)
- Traefik JSON access log parser: is it built-in or do we need a custom parser?
- SSH log parser for AlmaLinux (`/var/log/secure` instead of `/var/log/auth.log`)
- K3s audit log parser: format of K3s audit log, parsing API server events
- Custom parser YAML syntax: how to write a parser for a new log format
- Parser stages: s00-raw, s01-syslog, s02-enrich — what happens at each stage
- Testing parsers: `cscli explain` for debugging why a log line isn't being parsed

#### B6. Scenarios and Alerting
- How scenarios work: leaky bucket algorithm, capacity, leak rate, trigger
- Key scenarios for our stack (install commands + what they detect):
  - SSH brute force (`crowdsecurity/ssh-bf`)
  - HTTP 4xx flood (`crowdsecurity/http-bad-user-agent`, `crowdsecurity/http-crawl-non_statics`)
  - CVE exploit probes (`crowdsecurity/http-cve-*`)
  - K8s API scanner; port scan detection
- Writing a custom scenario: YAML syntax, leaky bucket parameters, filters
- Whitelisting legitimate traffic in scenarios (e.g., internal monitoring probes from Grafana)
- CrowdSec notification system: HTTP notification plugin for n8n webhook when an alert fires
- Notification configuration file: `/etc/crowdsec/notifications/http.yaml`
- Profile configuration: which alerts trigger which notifications
- n8n webhook payload from CrowdSec: JSON structure, available fields
- Filtering notifications: only alert on high-severity scenarios

#### B7. CrowdSec Metrics, Monitoring & Troubleshooting
- CrowdSec Prometheus metrics endpoint: port, path, how to enable
- Key metrics: `cs_decisions_count`, `cs_active_decisions`, `cs_parser_hits`, `cs_scenario_overflow`
- Prometheus ServiceMonitor CRD for scraping CrowdSec metrics
- Official Grafana dashboard ID for CrowdSec
- Alertmanager rules for CrowdSec: when to page vs when to log
- Troubleshooting false positives: whitelisting, `cscli explain`, `cscli decisions delete --ip X.X.X.X`
- Troubleshooting parser errors: log line not matching, `cscli explain --log` output
- Bouncer connectivity issues: bouncer can't reach LAPI, API key invalid
- SELinux denials blocking CrowdSec on AlmaLinux: `ausearch -c crowdsec` to find denials
- Agent not sending data to LAPI: registration, network policy issues in K3s

#### B8. CrowdSec vs NeuVector: Complementarity
- CrowdSec's scope: network traffic, SSH, web logs, external threat intelligence
- NeuVector's scope: container runtime, process behavior, intra-cluster L7 traffic
- Gap analysis: what CrowdSec catches that NeuVector misses (and vice versa)
- Alert deduplication: both tools may alert on same incident — how to handle in Alertmanager

---

### SECTION C: Kyverno (Deep Coverage)

#### C1. CLI Reference (kyverno CLI)
- Installing the Kyverno CLI: package manager, binary, container
- `kyverno apply`: applying policies to resource files without a cluster — for CI validation
  - Syntax: `kyverno apply <policy.yaml> --resource <resource.yaml>`
  - Multiple policies and resources: glob patterns, directory scanning
  - Output formats: table, JSON, YAML; exit codes for CI (non-zero on policy violation)
- `kyverno test`: structured testing with test manifests
  - Test file format: `kyverno-test.yaml` structure; writing test cases: pass/fail expectations per resource
  - Running tests: `kyverno test <directory>`
- `kyverno validate`: validating policy YAML itself for correctness
- `kyverno version`: checking CLI vs controller compatibility
- Key CLI flags: `--detailed-results`, `--policy-report`, `--git-branch`

#### C2. Policy Types (Validate, Mutate, Generate, VerifyImages)
- **Validate**: blocking non-compliant resources at admission
  - Rule anatomy: `match`, `exclude`, `validate` blocks
  - Validation expressions: `pattern`, `deny`, `foreach`
  - CEL (Common Expression Language) validation — Kyverno 1.11+ feature, syntax differences from JMESPath
  - Audit vs Enforce mode: `validationFailureAction: Audit` vs `Enforce`
- **Mutate**: modifying resources at admission
  - `patchStrategicMerge`, `patchesJson6902`, `foreach` for mutating arrays (containers list)
  - Order of mutation vs validation (mutation happens first)
- **Generate**: creating companion resources automatically
  - Triggers: on new Namespace creation, on new resource matching rule
  - Cloning and synchronization: keeping generated resources in sync
  - Use case: auto-create NetworkPolicy and ResourceQuota when namespace is created
- **VerifyImages**: Cosign signature verification
  - How Kyverno contacts Harbor registry to fetch image signatures
  - Cosign key pair: where the public key lives (K8s Secret), how Kyverno references it
  - Attestations: verifying SBOM attestations, vulnerability scan results
  - Mutation after verification: replacing `image:tag` with `image@sha256:digest` for immutability
  - Enforcing NeuVector scan results via Kyverno: VerifyImages with Harbor/Trivy attestations

#### C3. Essential Policies for Our Cluster
Provide complete, copy-paste-ready YAML for each:
- **require-resource-limits**: all containers must have CPU and memory limits
- **disallow-privileged-containers**: no `securityContext.privileged: true`
- **disallow-host-path**: no hostPath volumes (except in system namespaces)
- **require-harbor-registry**: all container images must come from `harbor.helixstax.net/` — block Docker Hub, ghcr.io, etc.
- **disallow-latest-tag**: no `image:latest` — must use specific tags or digests
- **require-namespace-labels**: namespaces must have `team` and `env` labels
- **disallow-root-user**: containers must not run as UID 0
- **require-readonly-root-filesystem**: containers must set `readOnlyRootFilesystem: true`
- **disallow-host-network**: no `hostNetwork: true` in pod specs
- **require-pod-disruption-budget**: Deployments with >1 replica must have a PodDisruptionBudget
- **no-privileged-containers**, **resource limits required**, **required labels (app/team/env)**, **no host network/PID/IPC**, **no NodePort Services**, **Traefik IngressRoute requires TLS**, **Zitadel client secrets in OpenBao only**
- Pod Security Standards enforcement via Kyverno (vs PSA built into K3s)

#### C4. Image Verification (Cosign + Harbor)
- How Cosign signs images in Devtron CI: `cosign sign` command, where the signing key lives
- How Kyverno's `verifyImages` rule references the Cosign public key
- Harbor-specific configuration: does Harbor proxy Cosign signature attachments, or does Kyverno query Harbor OCI registry directly?
- Handling private registry authentication: Kyverno needs credentials to pull from Harbor
- Policy example: verify all images in the `production` namespace are signed
- What happens when an unsigned image is deployed: error message format
- Attestation verification: verifying a Trivy scan attestation attached to the image
- How to write a Kyverno policy that blocks images with critical CVEs (using Harbor/Trivy metadata)

#### C5. Policy Exceptions (System Namespaces)
- `PolicyException` CRD (Kyverno 1.11+): how to write exceptions for specific namespaces/resources
- Alternative: using `exclude` blocks in policy rules to skip system namespaces
- List of namespaces that need exceptions: kube-system, traefik, cert-manager, kyverno itself, crowdsec, openbao, neuvector
- Best practice: use `exclude` for permanent system exceptions, `PolicyException` for temporary or per-resource exceptions
- Auditing exceptions: how to see which exceptions are active

#### C6. Generate Policies (Auto-Create Companion Resources)
- **auto-networkpolicy**: when a new namespace is created, generate a default-deny NetworkPolicy
  - Template for the generated NetworkPolicy; synchronization if the policy template changes
- **auto-resourcequota**: when a new namespace with label `tier=standard` is created, generate a ResourceQuota
- **auto-limitrange**: generate a LimitRange with default container limits per namespace
- Troubleshooting generate policies: checking if generation fired, viewing generated resources

#### C7. Audit vs Enforce Mode & Migration Strategy
- Cluster with existing workloads: starting in Audit mode, migrating to Enforce
- Policy report generation: `PolicyReport` and `ClusterPolicyReport` CRDs
- Reading policy reports: `kubectl get policyreport -A`, key fields
- `kyverno-background-scan`: how background scanning works for existing resources
- Per-rule mode override: some rules Enforce, others Audit in same policy

#### C8. CI/CD Integration (Devtron Pipelines + ArgoCD)
- Installing Kyverno CLI in a Devtron CI pipeline (container-based)
- Pre-deploy validation step: `kyverno apply policies/ --resource manifests/ --detailed-results`
- Failing the pipeline on policy violations: exit code handling
- `kyverno test` in CI for policy unit tests
- How ArgoCD applies Kyverno policies (CRDs deployed first, then policies, then apps)
- Policy exceptions CRD: granting targeted exemptions without modifying the policy
- Kyverno policy reports: PolicyReport and ClusterPolicyReport CRDs — how to query them
- Kyverno webhook timeout and failure policy (Fail vs Ignore) — recommendation for production
- Kyverno HA deployment (3 replicas) on a 2-node cluster — resource requirements
- Webhook exclusions to prevent deadlocks (kube-system, kyverno namespace itself)

#### C9. Monitoring (Policy Reports, Prometheus, Grafana) & Troubleshooting
- Prometheus metrics from Kyverno: endpoint, key metrics
  - `kyverno_policy_results_total`, `kyverno_admission_requests_total`, `kyverno_policy_execution_duration_seconds`
- Prometheus ServiceMonitor CRD for Kyverno; kyverno-policy-reporter for Prometheus integration
- Grafana dashboards: community dashboard IDs for Kyverno
- Alerting: Alertmanager rules for policy violation spikes
- Troubleshooting webhook failures: `kubectl get validatingwebhookconfigurations`, webhook timeout causing pods stuck Pending
- Policy not matching resources: debugging with `kubectl describe clusterpolicy`, checking match conditions

---

### SECTION D: Gitleaks (Deep Coverage)

#### D1. CLI Reference (gitleaks detect / protect / generate-config)
- `gitleaks detect`: scanning an existing repository (full history)
  - Syntax: `gitleaks detect --source . --report-format json --report-path gitleaks-report.json`
  - `--log-opts`: controlling git log depth; `--branch`: scanning specific branch; `--no-git`: scanning non-git directories
  - Exit codes: 0 (no leaks), 1 (leaks found), 126 (error) — how to use in scripts
- `gitleaks protect`: scanning staged changes (pre-commit mode)
  - Syntax: `gitleaks protect --staged --source . --verbose`
  - How this differs from `detect` — only scans what's staged, not history
- `gitleaks version`, `gitleaks generate-config`
- Global flags: `--config`, `--verbose`, `--log-level`, `--redact`
- Output formats: `json`, `csv`, `sarif`, `table` — when to use each

#### D2. Configuration (.gitleaks.toml)
- File location: repo root vs XDG config dir vs `--config` flag
- Config file structure: `title`, `[extend]`, `[[rules]]`, `[allowlist]`
- **Extending the default ruleset**: `[extend]` block — using `useDefault = true` to include built-in rules
- Rule anatomy: `id`, `description`, `regex`, `keywords`, `entropy`, `secretGroup`, `allowlist`
- Global `[allowlist]` section: commits to skip, paths to skip, regex patterns to ignore
- Performance: how `keywords` field dramatically speeds up scanning

#### D3. Custom Rules for Our Secret Types
Provide complete rule TOML for each:
- **OpenBao / Vault tokens**: `hvs.*` prefix (service tokens), `hvb.*` (batch tokens), `bao.*` prefix
- **Zitadel service account keys**: JSON format keys, PAT format
- **MinIO access keys and secret keys**: format pattern, entropy threshold
- **Hetzner API tokens**: format (64-char alphanumeric)
- **Harbor robot account tokens**: format (`robot$*|*` or similar)
- **age private keys**: `AGE-SECRET-KEY-1*` prefix — critical to detect
- **Cloudflare API tokens**: format pattern
- **GitHub PATs**: classic (`ghp_*`), fine-grained (`github_pat_*`)
- **Google service account JSON**: detecting the full JSON blob pattern
- **Backblaze B2 application keys**: format pattern
- **SOPS decrypted secrets** (accidentally committed): how to detect a YAML file that should be SOPS-encrypted but isn't
- **Generic high-entropy strings in .env files**: catch-all for unrecognized secrets

#### D4. SOPS Integration (Don't Flag Encrypted Blocks as Leaks)
- The problem: SOPS-encrypted YAML contains `ENC[AES256_GCM,...]` blocks that look like random data — may trigger entropy rules
- Configuring Gitleaks to ignore SOPS-encrypted files: path-based allowlisting
- Detecting when a SOPS file was accidentally decrypted and committed in plaintext (opposite problem)
- Recommended directory structure: all encrypted files in `secrets/` directory
- Example allowlist rule: `paths = ["secrets/.*\\.yaml$"]` or using regex to match SOPS metadata headers

#### D5. Baseline Management & Pre-commit Hook
- `.gitleaksignore` file: format (fingerprint-based), how fingerprints are generated
- Generating a baseline: `gitleaks detect --baseline-path gitleaks-baseline.json`
- Using baseline in subsequent scans: `--baseline-path` flag
- Risk: what happens if someone adds a real secret after the baseline
- `.pre-commit-config.yaml` entry for Gitleaks: repo URL, hook ID, version pinning
- Alternative: direct Git hook (`git/hooks/pre-commit`) without pre-commit framework
- Windows-compatible pre-commit setup (developer machines run Windows)
- Staged-only mode in hook: `--staged` flag so hook doesn't scan full history on every commit

#### D6. Devtron CI Pipeline Integration
- Container image for Gitleaks in CI: `zricethezav/gitleaks:latest` vs version-pinned image
- Devtron CI step: running `gitleaks detect` on the checked-out source
- Failing the pipeline: Devtron behavior when a step returns non-zero exit code
- JSON report output: saving report as artifact in Devtron
- Scanning only changed files in a PR/commit vs full repo: `--log-opts` for commit range
- GitHub Actions integration (for any repos that use GH Actions): workflow YAML step

#### D7. Full History Scanning & Security Incident Response
- Running a full history scan: `gitleaks detect --source . --log-opts="--all"`
- Interpreting the report: JSON schema, key fields (RuleID, File, StartLine, Commit, Author, Date)
- What to do when you find a historical leak:
  - Rotate the secret immediately (before purging history)
  - Purge from git history: `git filter-repo` vs BFG Repo Cleaner
  - Force push to GitHub: `git push --force-with-lease`
  - Notify all collaborators to re-clone
- What to do when gitleaks fires in CI: rotate, rewrite history, Rocket.Chat alert via n8n
- Integrating gitleaks output (SARIF format) with GitHub Security tab
- Parsing JSON report with n8n: workflow to read report, extract findings, post to Rocket.Chat

#### D8. Troubleshooting (False Positives, Performance, Large Repos)
- Common false positives: test fixtures with fake credentials, example config files, encrypted/encoded data, old rotated secrets
- How to identify which rule triggered a finding: JSON report `RuleID` field
- Tuning entropy threshold: balancing sensitivity vs false positive rate
- Gitleaks running too slowly: `keywords` field, `--max-target-megabytes`, excluding generated files
- Rule not matching: testing a rule regex against a sample string — RE2 syntax validation
- Version compatibility: Gitleaks v8 breaking changes from v7

---

### SECTION E: Cross-Tool Integration and Alert Routing

#### E1. Unified Alert Pipeline
- All four tools → Prometheus metrics → Alertmanager → Rocket.Chat
- NeuVector: which Prometheus metrics to alert on (policy violations, CVEs found, compliance failures)
- CrowdSec: Prometheus metrics for ban decisions and scenario triggers
- Kyverno: PolicyReport failures → Prometheus (via kyverno-policy-reporter) → Alertmanager
- Gitleaks: CI failures → n8n webhook → Rocket.Chat #security channel
- Alertmanager routing: severity labels (critical/warning/info), grouping, inhibition rules

#### E2. Compliance Reporting: Combined Evidence
- NeuVector compliance scan results + Kyverno PolicyReport + CrowdSec decision logs = audit evidence
- How to collect and export: NeuVector (REST API JSON), Kyverno (kubectl get policyreport -o json), CrowdSec (cscli decisions list --output json)
- Storing compliance evidence: MinIO bucket with date-stamped JSON exports
- Mapping to UCM controls: which tool covers which NIST CSF / CIS Controls category

#### E3. Layered Defense Map
- Provide a clear table showing: Attack scenario → which tool catches it → how it's blocked
- Example scenarios: cryptominer in container, credential stuffed login, image from untrusted registry, privileged pod deploy attempt, secret committed to git, lateral movement attempt inside cluster

---

### Best Practices & Anti-Patterns
- What are the top 10 best practices for this tool in production?
- What are the most common mistakes and anti-patterns? Rank by severity (critical → low)
- What configurations look correct but silently cause problems?
- What defaults should NEVER be used in production?
- What are the performance anti-patterns that waste resources?

### Decision Matrix
- When to use X vs Y (for every major decision point in this tool)
- Clear criteria table: "If [condition], use [approach], because [reason]"
- Trade-off analysis for each decision
- What questions to ask before choosing an approach

### Common Pitfalls
- Mistakes that waste hours of debugging — with prevention
- Version-specific gotchas for current releases
- Integration pitfalls with other tools in our stack
- Migration pitfalls when upgrading

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CLI commands with examples
- Configuration patterns with copy-paste snippets
- Troubleshooting decision tree (symptom → cause → fix)
- Integration points with other tools in our stack
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Full API/CLI reference (every flag, every option)
- Complete configuration schema with all fields documented
- Advanced patterns and edge cases
- Performance tuning parameters
- Security hardening checklist
- Architecture diagrams (ASCII)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (178.156.233.12, 138.201.131.157), domains (helixstax.com, helixstax.net), and service names
- Annotated YAML/JSON manifests
- Before/after troubleshooting scenarios
- Step-by-step runbooks for common operations
- Integration examples with our specific stack (K3s, Traefik, Zitadel, CloudNativePG, etc.)

Use `# Tool Name` as top-level headers to separate each tool's output for splitting into separate skill directories.

Be thorough, opinionated, and practical. Include actual commands, actual configs, and actual error messages. Do NOT give theory — give copy-paste-ready content for a K3s cluster on Hetzner behind Cloudflare.

```markdown
# NeuVector

## Overview
[What NeuVector is and why we use it in the Helix Stax K3s cluster]

## Architecture & K3s Deployment
[Component roles, Helm deployment, containerd integration]

## CLI and REST API Reference
[Commands, login, querying, policy export/import]

## Runtime Security Policies
[Modes, process profiles, file monitoring, network rules, policy-as-code]

## Deep Packet Inspection (L7 Rules)
[Protocol support, rule syntax, performance, DPI vs Traefik TLS interaction]

## Vulnerability Scanning
[NeuVector Scanner vs Trivy, CVE database, admission control based on CVE]

## Compliance Templates
[CIS, NIST, PCI, running scans, exporting results, UCM mapping]

## Admission Control vs Kyverno
[Coexistence, ordering, which to use for which policies]

## Zitadel OIDC Integration
[Manager login via OIDC, client config, role mapping]

## Multi-Cluster Federation
[Setup, policy sync, future-proofing]

## Troubleshooting
[Common issues, debug commands, log locations]

## Gotchas
[K3s-specific issues, upgrade warnings, anti-patterns]

---

# CrowdSec

## Overview
[What CrowdSec is and its role in the Helix Stax security stack]

## K3s Deployment
[DaemonSet, log paths on AlmaLinux, Traefik log location, Helm values]

## CLI Reference (cscli)
### Decisions
[Commands with examples]
### Alerts
[Commands with examples]
### Bouncers
[Commands with examples]
### Collections & Hub
[Commands with examples]
### Metrics
[Commands with examples]

## Collections
[Exact install commands for our stack]

## Bouncer Configuration
[Cloudflare bouncer, Traefik bouncer, nftables bouncer — layered strategy]

## Parsers
### Traefik JSON Logs
[Parser config, Traefik log format requirements]
### SSH on AlmaLinux
[/var/log/secure path]
### K3s Audit Logs
[Audit log format, parser]
### Custom Parser Syntax
[YAML template]

## Scenarios
[Key scenarios, install commands, custom scenario template, whitelisting]

## Cloudflare Integration
### IP Whitelisting
[Whitelist config for CF edge IPs]
### Real IP Extraction
[CF-Connecting-IP header config]

## Alerting (Rocket.Chat via n8n)
[HTTP notification plugin config, profile config, n8n payload]

## CrowdSec vs NeuVector: Complementarity
[Scope comparison, gap analysis, alert deduplication]

## Metrics and Dashboards
[Prometheus metrics, Grafana dashboard ID, Alertmanager rules]

## Troubleshooting
[False positives, parser errors, bouncer issues, SELinux denials]

## Gotchas
[K3s-specific gotchas, bouncer ordering, Cloudflare real IP]

---

# Kyverno

## Overview
[What Kyverno is and its role as admission controller in K3s]

## CLI Reference (kyverno CLI)
### apply
[Command with examples for CI validation]
### test
[Test file format, running tests]
### validate
[Policy YAML validation]

## Policy Types
### Validate
[Rule anatomy, CEL vs JMESPath, action modes]
### Mutate
[patchStrategicMerge, patchesJson6902, foreach]
### Generate
[Triggers, cloning, synchronization]
### VerifyImages
[Cosign integration, Harbor auth, attestations]

## Essential Policies
### require-resource-limits
[Complete YAML]
### disallow-privileged-containers
[Complete YAML]
### require-harbor-registry
[Complete YAML]
### disallow-latest-tag
[Complete YAML]
### require-namespace-labels
[Complete YAML]
[...remaining policies]

## Image Verification (Cosign + Harbor)
### Cosign + Harbor Setup
[Key reference, Harbor auth, policy example]
### Enforcing NeuVector/Trivy Scan Results
[CVE-blocking policy via Harbor attestations]

## Policy Exceptions
### PolicyException CRD
[Example for system namespaces]
### Exclude Blocks
[Per-rule namespace exclusions]

## Generate Policies
### auto-networkpolicy
[Complete YAML with NetworkPolicy template]
### auto-resourcequota
[Complete YAML]

## Audit vs Enforce Migration
[Strategy, PolicyReport reading, workflow]

## CI/CD Integration
### Devtron Pipeline
[CLI commands, exit code handling]
### ArgoCD Pre-sync Hook
[Hook manifest, sync wave ordering]

## Performance and Reliability
[HA deployment, webhook timeout/failure policy, deadlock prevention]

## Monitoring
### Prometheus Metrics
[Key metrics, ServiceMonitor CRD]
### Grafana Dashboards
[Community dashboard IDs]

## Troubleshooting
[Webhook failures, policy not matching, performance tuning]

## Gotchas
[Namespace exemptions, PSA vs Kyverno, upgrade ordering]

---

# Gitleaks

## Overview
[What Gitleaks is and its role as the first line of defense in our secrets pipeline]

## CLI Reference
### detect
[Full syntax, flags, exit codes, examples]
### protect
[Pre-commit mode, staged scanning]
### Output Formats
[json, csv, sarif — when to use each]

## Configuration (.gitleaks.toml)
### Structure
[File anatomy, extend block, allowlist]
### Rule Anatomy
[id, regex, keywords, entropy, secretGroup]
### Example Base Config
[Complete .gitleaks.toml for our stack]

## Custom Rules
### OpenBao / Vault Tokens
[Complete rule TOML]
### Zitadel Keys
[Complete rule TOML]
### MinIO Credentials
[Complete rule TOML]
### Hetzner API Tokens
[Complete rule TOML]
### Harbor Robot Tokens
[Complete rule TOML]
### age Private Keys
[Complete rule TOML]
### Cloudflare API Tokens
[Complete rule TOML]
### GitHub PATs
[Complete rule TOML]
### Google Service Account JSON
[Complete rule TOML]
[...remaining rules]

## SOPS Integration
[Allowlisting encrypted files, detecting accidentally decrypted files]

## Baseline Management
[.gitleaksignore format, baseline generation, suppression workflow]

## Pre-commit Hook
### pre-commit Framework
[.pre-commit-config.yaml]
### Windows Setup
[Windows-compatible instructions]

## Devtron CI Integration
[Pipeline step config, container image, artifact saving]

## Full History Scanning
[Commands, report interpretation, remediation workflow]

## Security Incident Response
[What to do when a finding fires: rotate, rewrite history, Rocket.Chat alert]

## SARIF Output and GitHub Integration
[SARIF format, GitHub Security tab integration]

## Troubleshooting
[False positives, allowlist syntax, rule debugging]

## Gotchas
[Pre-commit vs CI differences, force-push caveats, history scan performance]

---

# Cross-Tool Integration

## Unified Alert Pipeline
[All tools → Prometheus → Alertmanager → Rocket.Chat routing with severity labels]

## Compliance Reporting
[Collecting evidence from all four tools, MinIO storage, UCM mapping]

## Layered Defense Map
[Attack scenario table: scenario → tool that catches it → how it's blocked]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual Helm values snippets, actual Kyverno and NeuVector policy YAML, actual CrowdSec parser YAML, and actual Gitleaks rule TOML. Do NOT give me theory — give me copy-paste-ready configs for a K3s cluster on AlmaLinux 9.7 at Hetzner Cloud. Flag any command or config that differs between K3s and standard Kubernetes.
