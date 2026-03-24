# Gemini Deep Research: CI/CD Pipeline Architecture for K3s with Devtron + ArgoCD

## Who I Am
I run Helix Stax, a small IT consulting company building an autonomous infrastructure on K3s. I need to design the CORRECT CI/CD pipeline using Devtron and ArgoCD. I've written a theoretical pipeline but I'm not sure the flow is right — I need Gemini to research how Devtron and ArgoCD actually work together and tell me the correct architecture.

## What Devtron Is
Devtron is an open-source CI/CD platform built on top of Kubernetes. It provides a web UI for managing CI/CD pipelines, Helm chart deployments, and application lifecycle management. Devtron **bundles ArgoCD internally** — it installs its own ArgoCD instance and uses it for GitOps deployments under the hood.

**Key Devtron concepts:**
- **CI Pipeline**: Build Docker images from source code using Kaniko (no Docker daemon needed), run tests, security scans
- **CD Pipeline**: Deploy to Kubernetes using Helm charts, supports rolling updates, blue-green, canary
- **Chart Store**: Deploy third-party Helm charts (like deploying Prometheus, Grafana, etc.) without writing CI/CD pipelines
- **Global Configuration**: Container registries, Git accounts, cluster management, environment management
- **Applications**: Each app has a CI pipeline (build) and CD pipeline (deploy) connected together
- **Environments**: dev, staging, prod — promotion between environments
- **Built-in ArgoCD**: Devtron uses ArgoCD internally for GitOps syncing — you don't install ArgoCD separately

## What ArgoCD Is
ArgoCD is a GitOps continuous delivery tool for Kubernetes. It watches a Git repository for Kubernetes manifests (YAML, Helm charts, Kustomize) and automatically syncs the cluster state to match what's in Git.

**Key ArgoCD concepts:**
- **Application**: Points to a Git repo + path containing K8s manifests
- **Sync**: Compares desired state (Git) vs actual state (cluster) and reconciles
- **Auto-sync**: Automatically applies changes when Git changes
- **Self-heal**: Reverts manual cluster changes to match Git
- **Rollback**: Revert to a previous Git commit/state
- **App of Apps**: One Application that manages other Applications

## What GitHub Is (in our context)
GitHub is our source code repository and collaboration platform. All application source code and infrastructure-as-code (IaC) lives in GitHub repositories. GitHub is the TRIGGER for the entire CI/CD pipeline — when a developer pushes code or merges a pull request, that event starts the pipeline.

**Key GitHub concepts for CI/CD:**
- **Repositories**: Where code lives. We have separate repos for infra (`helix-stax-infrastructure`), apps, and shared libraries
- **Branches**: `main` is production. Feature branches for development. Branch protection rules prevent direct pushes to main.
- **Pull Requests (PRs)**: Code review before merging to main. PR triggers CI pipeline for validation.
- **Webhooks**: GitHub sends HTTP POST events to Devtron when code is pushed, PR is opened/merged, etc. This is how Devtron knows to start a build.
- **GitHub Actions**: GitHub's own CI/CD — we do NOT use this because Devtron handles CI/CD. But we might use Actions for lightweight checks (linting, Gitleaks pre-scan).
- **Commit SHA**: Every commit has a unique hash. Devtron uses this to tag Docker images (e.g., `harbor.helixstax.net/app:abc123f`).
- **GitHub App vs PAT**: Two ways Devtron authenticates with GitHub to clone repos. Which is better for our setup?

**GitHub → Devtron connection:**
```
Developer pushes code → GitHub webhook fires → Devtron receives webhook
→ Devtron clones repo at that commit → CI pipeline starts
```

## What the Other Pipeline Tools Are

**Harbor** — Self-hosted container registry (like Docker Hub but private). Stores Docker images built by Devtron. Has built-in Trivy vulnerability scanning (scan-on-push), robot accounts for automation, Helm chart OCI storage, image replication, and garbage collection. Lives on our K3s cluster.

**Kaniko** — Builds Docker images INSIDE Kubernetes without needing a Docker daemon. Devtron uses Kaniko by default for CI builds. Runs as a pod, reads a Dockerfile, builds the image, pushes to Harbor.

**Trivy** — Vulnerability scanner by Aqua Security. Scans Docker images for known CVEs (Common Vulnerabilities and Exposures). Can run as a Devtron CI plugin AND as Harbor's built-in scanner (scan-on-push). Returns JSON reports of vulnerabilities by severity (CRITICAL, HIGH, MEDIUM, LOW).

**Cosign** — Image signing tool by Sigstore. Cryptographically signs Docker images after build to prove they haven't been tampered with. Kyverno can verify these signatures before allowing deployment.

**Syft** — SBOM (Software Bill of Materials) generator by Anchore. Scans a Docker image and outputs a list of every package, library, and dependency inside it. Output formats: SPDX, CycloneDX, JSON. Required for supply chain security and compliance audits.

**Gitleaks** — Secret scanning tool. Scans git repositories and files for hardcoded credentials (API keys, tokens, passwords). Can run as a pre-commit hook (local) and as a CI pipeline step (Devtron plugin).

**Kyverno** — Kubernetes policy engine. Runs as an admission controller — intercepts every resource being created/updated in K3s and validates it against policies. Policies like: "only allow images from Harbor", "require resource limits", "verify Cosign signature", "no privileged containers".

**SOPS + age** — Encrypts secrets in Git repositories. SOPS encrypts YAML/JSON values, age provides the encryption keys. Secrets are committed to Git encrypted and decrypted at deploy time. GitOps-safe — encrypted secrets can live in Git without exposure.

**OpenBao** — Self-hosted secrets vault (HashiCorp Vault fork). Stores and manages secrets at runtime. Dynamic database credentials, PKI certificates, API keys. Accessed by K8s pods via Kubernetes auth.

**External Secrets Operator (ESO)** — Kubernetes operator that syncs secrets from OpenBao to K8s Secrets. Watches ExternalSecret CRDs, fetches values from OpenBao, creates/updates K8s Secrets automatically. The bridge between "secrets in vault" and "secrets in pods".

**vCluster** — Creates virtual Kubernetes clusters inside your real K3s cluster. Used for PR preview environments — each pull request gets its own isolated cluster for testing, then destroyed after merge.

**Helm** — Kubernetes package manager. Packages K8s manifests as reusable "charts" with configurable values. Devtron uses Helm under the hood for deployments. Values files (`values.yaml`) configure each service.

**n8n** — Workflow automation platform. The central integration hub — receives webhooks from Devtron, GitHub, ArgoCD, Alertmanager, and routes notifications to Rocket.Chat, ClickUp, Postal (email).

**Prometheus + Grafana + Loki + Alertmanager** — Monitoring stack. Prometheus collects metrics, Grafana visualizes them, Loki stores logs, Alertmanager routes alerts. Used for post-deployment health checks and ongoing monitoring.

**Rocket.Chat** — Self-hosted team messaging (like Slack). Receives CI/CD notifications via n8n webhooks.

**ClickUp** — Project management. CI/CD events update task statuses (deploy succeeded → close task).

## My Current Stack
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (2 nodes)
- **Container Registry**: Harbor (self-hosted on K3s)
- **Source Code**: GitHub
- **IaC**: OpenTofu (provisioning) + Ansible (configuration)
- **Package Manager**: Helm 3
- **Secrets**: SOPS + age (encrypted in Git) → OpenBao (runtime) → External Secrets Operator (K8s Secrets)
- **Policy**: Kyverno (admission control, image verification)
- **Scanning**: Trivy (vulnerability scanning in Harbor), Gitleaks (secret scanning)
- **Image Signing**: Cosign
- **SBOM**: Syft
- **Monitoring**: Prometheus + Grafana + Loki + Alertmanager
- **Automation**: n8n
- **Communication**: Rocket.Chat
- **Project Management**: ClickUp

## What I'm Confused About

### 1. Devtron + Internal ArgoCD Relationship (THIS IS CRITICAL)
Devtron installs ArgoCD internally as part of its stack. I need to understand EXACTLY how this works:

- When I install Devtron with `--set installer.modules={cicd,argo}`, what version of ArgoCD gets installed?
- Where does Devtron's internal ArgoCD live? (namespace, pods, services)
- Can I access the internal ArgoCD UI directly? How?
- Does Devtron's internal ArgoCD have its own Application CRDs?
- If I create an ArgoCD Application manually (via kubectl), does Devtron see it?
- If Devtron creates a deployment, can I see it in ArgoCD UI?
- Do I need a SEPARATE standalone ArgoCD? Or is Devtron's internal ArgoCD sufficient for everything?
- What happens if I install standalone ArgoCD alongside Devtron's internal ArgoCD? Conflicts?
- Can Devtron's internal ArgoCD do app-of-apps pattern?
- Can Devtron's internal ArgoCD watch external Git repos (not just Devtron-managed apps)?
- What CRDs does Devtron install? Do they overlap with standalone ArgoCD CRDs?
- How does Devtron delegate to its internal ArgoCD? (API calls? CRD creation? Direct DB access?)
- If I want ArgoCD features Devtron doesn't expose (ApplicationSets, multi-source apps, sync waves), can I use them through Devtron's internal ArgoCD?
- What's the Devtron admin password vs ArgoCD admin password? Same or different?
- How do I configure Devtron's internal ArgoCD (RBAC, SSO, notifications)? Through Devtron UI or ArgoCD config?

**Bottom line: I need ONE answer — use Devtron's internal ArgoCD for everything, or install standalone ArgoCD alongside it. Not both unless there's a clear separation.**

### 2. Correct CI Pipeline Flow (Devtron-specific, step by step)
I need the EXACT sequence Devtron executes when a CI pipeline runs. Not generic CI — Devtron-specific:

- **Source checkout**: How does Devtron clone from GitHub? SSH key or HTTPS token? Where is this configured? (Global Configuration → Git Accounts)
- **Pre-build stage**: What runs here? Can I run Gitleaks here? What Devtron plugins exist for pre-build?
- **Build stage**:
  - Devtron uses Kaniko by default — how does it work? (no Docker daemon, builds in-cluster)
  - Can I use Buildpacks instead? When should I?
  - How do I configure the Dockerfile path?
  - How do I pass build args?
  - Multi-stage Dockerfiles — any Devtron-specific gotchas?
  - Build cache — how does Kaniko cache layers? Can I cache in Harbor?
- **Post-build stage**: What runs here? This is where security tools should go?
  - Devtron plugins — list EVERY official plugin available:
    - Gitleaks plugin? How to configure?
    - Trivy plugin? Does it scan the built image?
    - Cosign plugin? Does it sign the image after build?
    - Syft plugin? Does it generate SBOM?
    - SonarQube plugin?
    - Custom script plugin? Can I run arbitrary bash?
  - What order do post-build plugins execute?
  - If a plugin fails, does it block the pipeline?
- **Push to Harbor**:
  - How does Devtron push to a self-hosted Harbor? (Global Configuration → Container Registry)
  - Robot account or user account?
  - Image tag format — what does Devtron use? (commit hash? version? custom?)
  - Does Devtron tag with both commit hash AND a human-readable tag?
- **Harbor scan-on-push**: After Devtron pushes to Harbor, Harbor's Trivy scans automatically. Is this redundant with Devtron's Trivy plugin? Should I scan in BOTH places or just one?
- **Pre-CI and Post-CI webhooks**: Can I trigger n8n before/after CI? What payload does the webhook contain?

### 3. Correct CD Pipeline Flow (Devtron + internal ArgoCD)
This is where I'm most confused. After CI pushes an image to Harbor:

- **Devtron CD Pipeline creation**: In Devtron UI, how do I create a CD pipeline for an app?
  - What deployment strategies does Devtron support? (rolling, blue-green, canary, recreate)
  - How do I select which strategy?
  - What's the default?
- **GitOps vs non-GitOps mode**: Devtron supports both:
  - **GitOps mode**: Devtron commits updated manifests to a Git repo → internal ArgoCD syncs to cluster
  - **Helm mode**: Devtron deploys directly via Helm (no Git commit)
  - Which should I use? What are the trade-offs?
  - If GitOps mode — what Git repo does Devtron write to? Can I control this?
  - If GitOps mode — does Devtron create the ArgoCD Application CRD automatically?
- **Pre-deployment stage**: What can run here?
  - Database migrations?
  - Kyverno policy dry-run?
  - Config validation?
  - Notification to Rocket.Chat ("deploying version X...")?
- **Deployment execution**:
  - Devtron tells its internal ArgoCD to sync
  - ArgoCD applies the Helm chart / manifests to K3s
  - How does Kyverno intercept this? (ValidatingAdmissionWebhook)
  - If Kyverno rejects (e.g., unsigned image, missing labels), what happens in Devtron?
  - Does Devtron show Kyverno violations in its UI?
- **SOPS / External Secrets Operator flow during deploy**:
  - Encrypted secrets in Git → how does ArgoCD decrypt them?
  - Does Devtron handle SOPS decryption or does ArgoCD?
  - Where does External Secrets Operator fit? Does it create K8s Secrets before the pod starts?
  - Correct flow: SOPS-encrypted values in Git → ArgoCD syncs → ESO reads from OpenBao → creates K8s Secret → pod mounts secret?
  - Or does Devtron handle secrets differently through its own Global Configuration → External Secrets?
- **Post-deployment stage**: What can run here?
  - Health checks — how does Devtron verify the deployment is healthy?
  - Smoke tests?
  - Prometheus metric validation?
  - Grafana annotation creation?
  - n8n webhook notification (success/failure)?
  - ClickUp task status update?
  - Rocket.Chat notification?
- **Rollback**:
  - How does Devtron rollback? (ArgoCD rollback? Helm rollback? Git revert?)
  - Automatic rollback on failed health check?
  - Manual rollback from Devtron UI?
  - How many revisions kept?
- **Approval gates between environments**:
  - Dev deploys automatically after CI?
  - Staging requires manual approval?
  - Production requires manual approval + what else?
  - How do I configure approval gates in Devtron?
  - Can I require multiple approvers?

### 4. GitOps Repository Structure
- Should Helm values live in the same repo as source code or a separate infra repo?
- How does the infra repo structure work with Devtron + ArgoCD?
- What does Devtron expect vs what does ArgoCD expect?
- How do I structure for app-of-apps pattern?

### 5. Environment Promotion
- How does Devtron handle dev → staging → production promotion?
- Does it update Git (GitOps) or deploy directly (non-GitOps)?
- How do approval gates work between environments?
- vCluster for PR preview environments — how does this integrate?

### 6. Notifications and Observability
- Devtron webhook notifications — what events can trigger webhooks?
- How to notify Rocket.Chat on build success/failure
- How to notify ClickUp on deployment status
- How to create Grafana annotations on deploy
- How does n8n receive Devtron/ArgoCD events?
- Prometheus metrics for CI/CD pipeline health

### 7. Security Pipeline Integration
- Where in the pipeline does each security tool run?
- Gitleaks: pre-commit hook? CI stage? Both?
- Trivy: in CI? scan-on-push in Harbor? Both?
- Cosign: sign after build? verify before deploy?
- Kyverno: what policies to enforce at admission?
- SBOM: generate during CI, store where?
- How to fail the pipeline if security checks fail

### 8. Multi-App Deployment (Devtron Applications vs Chart Store)
I have 15+ services on K3s. Two ways to deploy them in Devtron:

**Devtron Applications** (full CI/CD pipeline):
- Custom apps we write code for (website, APIs, internal tools)
- Has CI pipeline (build from source) + CD pipeline (deploy to K3s)

**Devtron Chart Store** (deploy pre-built Helm charts):
- Third-party apps (Prometheus, Grafana, Zitadel, n8n, Harbor, etc.)
- No CI — just deploy a Helm chart with custom values
- Devtron manages the Helm release lifecycle

**Questions**:
- Which of my 15+ services should be Applications vs Chart Store?
- Can Chart Store apps still use GitOps mode? (values in Git → ArgoCD syncs?)
- Can I manage Chart Store apps' values.yaml in my infra Git repo?
- Dependency order: PostgreSQL must deploy before Zitadel, n8n, Backstage, etc. How does Devtron handle this?
- Does Devtron support sync waves or deploy ordering like ArgoCD?
- If I add a new service, what's the step-by-step in Devtron? (Global Config → App → Pipeline → Environment → Deploy)

**My services and recommended deployment type**:
| Service | Type | CI Pipeline? | Reasoning |
|---------|------|-------------|-----------|
| helixstax.com (Astro) | Application | Yes | Custom code, we build it |
| Client APIs | Application | Yes | Custom code |
| PostgreSQL (CloudNativePG) | Chart Store | No | Helm chart, operator-managed |
| Valkey | Chart Store | No | Helm chart |
| MinIO | Chart Store | No | Helm chart |
| Harbor | Chart Store | No | Helm chart |
| Zitadel | Chart Store | No | Helm chart |
| n8n | Chart Store | No | Helm chart |
| Grafana/Prometheus/Loki | Chart Store | No | kube-prometheus-stack Helm chart |
| ArgoCD | ??? | No | Devtron installs it internally — do I manage it separately? |
| CrowdSec | Chart Store | No | Helm chart |
| Backstage | Chart Store | No | Helm chart |
| Outline | Chart Store | No | Helm chart |
| Rocket.Chat | Chart Store | No | Helm chart |
| Velero | Chart Store | No | Helm chart |

**Is this the right split? Tell me if I'm wrong.**

### 9. Artifacts — Where Does Everything Go?
Every step of the pipeline produces artifacts. I need to know where EACH artifact is stored, how long it's retained, and how to access it later.

**CI Artifacts:**
- **Docker images** → Harbor. But what tag format? How long retained? Garbage collection policy?
- **Build logs** → Where does Devtron store build logs? How long? Exportable to Loki?
- **Test results** → Unit test output, coverage reports. Where do they go? Can I store in MinIO?
- **SAST reports** → SonarQube or Devtron built-in? Where is the report stored?
- **SBOM (Syft output)** → JSON/SPDX/CycloneDX format. Where to store? Harbor supports SBOM attachment to images — how?
- **Cosign signatures** → Stored in Harbor alongside the image? OCI artifact format?
- **Gitleaks report** → JSON output. Where stored? How to review later?
- **Trivy scan results** → In Harbor (scan-on-push) AND/OR Devtron plugin output? Where is the vulnerability report accessible?

**CD Artifacts:**
- **Helm release history** → `helm history` shows past releases. How many revisions does Devtron keep?
- **ArgoCD sync history** → Every sync recorded. Where? How long?
- **Deployment manifests** → The actual YAML applied to K3s. Stored in Git (GitOps mode) or lost (Helm mode)?
- **Rollback snapshots** → What exactly is saved for rollback? Full manifest? Just image tag?

**Compliance Artifacts (CRITICAL for SOC 2 / HIPAA):**
- **Audit trail** → Who deployed what, when, to which environment. Where is this log?
- **Approval records** → Who approved the production deploy? Stored where?
- **Evidence collection** → How to automatically export CI/CD artifacts as compliance evidence to MinIO WORM storage?
- **Change management records** → Every deployment = a change. How to auto-create ClickUp change request tasks?

**Where artifacts should live in our stack:**
| Artifact | Primary Storage | Backup | Retention |
|----------|----------------|--------|-----------|
| Docker images | Harbor | Harbor replication? | ? |
| Build logs | Devtron? Loki? | MinIO | ? |
| SBOM | Harbor (OCI artifact) | MinIO | ? |
| Trivy reports | Harbor | MinIO | ? |
| Cosign signatures | Harbor (OCI artifact) | — | Forever |
| Test results | ? | MinIO | ? |
| Deployment history | ArgoCD/Devtron | Git (GitOps) | ? |
| Compliance evidence | MinIO WORM | Backblaze B2 | 7 years |

**Tell me the correct storage location and retention policy for EACH artifact. What does Devtron handle automatically vs what do I need to configure?**

### 10. Devtron Global Configuration Checklist
Walk me through EVERY Global Configuration setting I need to configure in Devtron before creating my first pipeline:

- **Git Accounts**: Connect GitHub (SSH or HTTPS? GitHub App or PAT?)
- **Container Registry**: Connect Harbor (robot account credentials, registry URL, push/pull config)
- **Cluster & Environments**: My K3s cluster config (kubeconfig, environment names: dev/staging/prod)
- **Chart Repositories**: Add Harbor as Helm OCI registry for Chart Store
- **Notification Configurations**: Webhook to n8n for all pipeline events
- **External Secret Manager**: Connect OpenBao? Or use ESO separately?
- **SSO/OIDC**: Zitadel as IdP for Devtron login
- **Authorization**: RBAC policies — who can deploy to prod?
- **Custom Charts**: How to add my own Helm chart templates
- **Image Pull Secret**: How K3s pulls images from Harbor (imagePullSecrets, robot account)

### 10. Correct End-to-End Flow — TWO scenarios

**Scenario A: Custom Application (we wrote the code)**
```
Developer pushes to GitHub
→ [What happens step by step in Devtron?]
→ [Where does each security tool run?]
→ [How does the image get to Harbor?]
→ [How does the deployment reach K3s?]
→ [How do we know it worked?]
→ [How does rollback work?]
→ [Who gets notified?]
```

**Scenario B: Third-Party Helm Chart (deploying Grafana, n8n, etc.)**
```
I want to deploy n8n to K3s via Devtron Chart Store
→ [What happens step by step?]
→ [Where do I put my custom values.yaml?]
→ [Does it go through ArgoCD?]
→ [How do upgrades work?]
→ [How do I rollback a Chart Store app?]
```

**Scenario C: Infrastructure change (OpenTofu/Ansible, not Devtron)**
```
I want to add a new Hetzner node
→ [This doesn't go through Devtron at all, correct?]
→ [OpenTofu provisions → Ansible configures → K3s joins]
→ [How does Devtron know about the new node?]
```

### 11. What I'm Doing Wrong
My theoretical pipeline is probably wrong. Here it is — tear it apart:

```
My current (probably wrong) pipeline:
GitHub push → Gitleaks (secrets scan) → Devtron CI (build + test + SAST + SBOM/Syft + sign/Cosign)
→ Harbor (store + Trivy scan + verify signature) → vCluster (PR preview)
→ ArgoCD (SOPS decrypt + Kyverno policy check + rolling deploy + health check + auto-rollback)
→ Post-deploy (Prometheus verify + n8n notify Rocket.Chat/ClickUp + Grafana annotation)
```

**Specific things that might be wrong:**
- Am I using "ArgoCD" when I should say "Devtron's internal ArgoCD"?
- Does vCluster preview actually work with Devtron? How?
- Is SOPS decryption done by ArgoCD or by ESO or by Devtron?
- Where exactly does Kyverno intercept — at ArgoCD sync time or at K8s admission time?
- Should Gitleaks run as a Devtron pre-build plugin or as a Git pre-commit hook or both?
- Is the notification flow (post-deploy) a Devtron feature or do I build it with n8n webhooks?

**Give me the CORRECTED pipeline with the right tool at each step.**

## Required Output Format

```markdown
# CI/CD Pipeline Architecture — Helix Stax

## Executive Summary
[2-3 sentences on the correct architecture]

## Devtron + ArgoCD: The Correct Relationship
[How they work together, not against each other]

## Correct CI Pipeline (Step by Step)
| Step | Tool | What Happens | Devtron Config | Failure Action |

## Correct CD Pipeline (Step by Step)
| Step | Tool | What Happens | Config | Failure Action |

## GitOps Repository Structure
[Correct folder layout]

## Security Pipeline Integration
| Security Tool | When It Runs | Where It Runs | What Fails the Pipeline |

## Environment Promotion Flow
[dev → staging → prod with approval gates]

## Notification & Webhook Configuration
| Event | Source | Destination | How |

## What You Got Wrong
[List everything incorrect in my theoretical pipeline]

## Correct End-to-End Flow (Final Answer)
[The definitive pipeline diagram]
```

Be opinionated. Tell me the ONE correct way to do this, not five options. I'm using Devtron + ArgoCD + Harbor + K3s on Hetzner. Give me the exact configuration, not theory.
