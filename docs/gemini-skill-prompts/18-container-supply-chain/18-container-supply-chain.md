# Gemini Deep Research: Container Supply Chain (Docker/OCI Image Building + Harbor)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
This group covers the container image lifecycle from build to runtime verification. Images are built using Kaniko (no Docker daemon — runs inside Devtron CI pods) and stored in Harbor (self-hosted OCI registry on our K3s cluster). These two tools are inseparable in our pipeline: build practices directly affect what Harbor scans, how Trivy reports vulnerabilities, whether Cosign signatures validate, and whether ArgoCD can deploy. Kyverno enforces image policies at admission. NeuVector monitors at runtime.

Note: Harbor has a prior prompt (prompt 11) covering basic setup. This prompt goes DEEPER on the build side and the full image supply chain — from Dockerfile authoring through signing, SBOM generation, promotion between environments, and runtime enforcement.

## Our Specific Setup
- **Build tool**: Kaniko running inside Devtron CI pods (no Docker daemon on nodes — K3s uses containerd)
- **Registry**: Harbor on K3s, accessible at registry.helixstax.net (internal) and via Cloudflare tunnel
- **Image promotion**: dev project → staging project → prod project inside Harbor
- **Scanning**: Trivy scan-on-push enabled in Harbor
- **Signing**: Cosign (keyless via Sigstore, or key-based with OpenBao-managed keys)
- **SBOM**: Syft generates SBOMs attached as OCI artifacts
- **Policy enforcement**: Kyverno validates signatures and scan results at admission
- **Runtime**: NeuVector monitors running containers for behavioral anomalies
- **CI**: Devtron orchestrates the full pipeline (build → scan → sign → push → deploy)
- **GitOps**: ArgoCD deploys from Harbor, Kyverno blocks unsigned or unscanned images

## What I Need Researched

### Dockerfile Best Practices

- Multi-stage builds: anatomy of `FROM ... AS builder` + `FROM ... COPY --from=builder`, minimizing final image size, which files NOT to copy
- Base image selection: distroless vs Alpine vs UBI 9 (Red Hat Universal Base Image) — trade-offs for K3s/AlmaLinux environment, using `cgr.dev/chainguard` images
- Layer caching strategy: ordering instructions for maximum cache reuse, `RUN --mount=type=cache` for package managers (npm, pip, go mod), cache invalidation pitfalls
- `.dockerignore`: what to always exclude (`.git`, `node_modules`, secrets, test fixtures), syntax (glob patterns, negation with `!`)
- User and permission best practices: never run as root, `USER 1001:1001`, `--chown` flag on COPY, numeric UIDs for Kubernetes
- `COPY` vs `ADD`: when ADD is acceptable (remote URLs, auto-extraction of tarballs) vs when COPY is preferred (always, for reproducibility)
- `ARG` vs `ENV`: build-time vs runtime, not using ARG for secrets (they appear in `docker history`), BuildKit secret mounts
- `HEALTHCHECK`: instruction syntax, exit codes, interaction with Kubernetes liveness/readiness probes
- Labels and annotations: OCI image annotations (`org.opencontainers.image.*`), provenance labels, how they surface in Harbor
- Reproducible builds: pinning base image digests (`FROM alpine@sha256:...`), deterministic package installs, SOURCE_DATE_EPOCH

### BuildKit Features

- BuildKit vs legacy builder: enabling BuildKit (`DOCKER_BUILDKIT=1`), `buildkitd` daemon, `buildctl` CLI
- Build secrets: `--secret id=mysecret,src=./secret.txt` + `RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret` — secrets NOT baked into layers
- SSH forwarding: `--ssh default` + `RUN --mount=type=ssh` for private git repos during build
- Cache mounts: `RUN --mount=type=cache,target=/root/.npm npm ci` — persistent cache across builds
- Bind mounts in RUN: `RUN --mount=type=bind,source=.,target=/src` for read-only source access
- Inline cache: `--cache-from type=registry,ref=registry.helixstax.net/dev/myapp:cache`, `--cache-to type=inline`
- Registry cache: external cache backend to Harbor, cache key strategies
- `--output` options: exporting to tar, local directory, OCI layout
- `bake` files: HCL-based multi-target build definitions, matrix builds

### Kaniko (No Docker Daemon)

- How Kaniko works: running as a container, reading Dockerfile, building layers, pushing directly to registry — no Docker socket required
- Kaniko executor image: `gcr.io/kaniko-project/executor:latest` — using a specific digest for reproducibility
- Required flags: `--context` (git URL, GCS, local dir), `--dockerfile`, `--destination registry.helixstax.net/dev/myapp:tag`
- Credentials: providing registry auth in `/kaniko/.docker/config.json`, using Kubernetes secrets for Harbor credentials
- Caching with Kaniko: `--cache=true`, `--cache-repo registry.helixstax.net/kaniko-cache/myapp`, cache TTL (`--cache-ttl`)
- BuildKit parity gaps: what Kaniko supports vs doesn't (RUN --mount=type=cache partially supported, --secret support)
- Snapshot mode: `--snapshotMode=redo` vs `--snapshotMode=time` — which is more reproducible
- Verbosity and debugging: `--verbosity=debug`, reading Kaniko logs in Devtron
- Devtron CI integration: Kaniko as the build step, how Devtron passes `--destination` with image tag, pipeline YAML structure
- Common Kaniko failures: permission denied on `/workspace`, registry auth errors, context size limits, `--insecure` flag for internal registries (when to use vs TLS)
- Multi-stage with Kaniko: supported and recommended, `--target` for specific stage
- Skipping unused stages: `--skip-unused-stages`

### OCI Image Spec and Supply Chain

- OCI image manifest: `mediaType`, `config`, `layers` — understanding the JSON structure, `manifest.json`, `index.json` for multi-arch
- Image digests vs tags: why digest pinning (`image@sha256:...`) is more secure than tags, immutable tags in Harbor
- Multi-architecture images: `docker manifest create`, `docker buildx build --platform linux/amd64,linux/arm64`, manifest lists in Harbor
- Image signing with Cosign:
  - Keyless signing via Sigstore (OIDC-based, no long-lived key) — `cosign sign --identity-token`
  - Key-based signing with OpenBao-managed keys — `cosign sign --key` workflow
  - `cosign verify` command and output
  - Storing signatures as OCI artifacts in same repository (`.sig` suffix)
  - Cosign + Harbor: signatures stored alongside images
- SBOM generation with Syft:
  - `syft registry.helixstax.net/dev/myapp:tag -o spdx-json > sbom.json`
  - Attaching SBOM as OCI artifact: `cosign attach sbom --sbom sbom.json image@sha256:...`
  - SBOM formats: SPDX vs CycloneDX, which to prefer and why
- Vulnerability scanning with Grype at build time (before push):
  - `grype registry.helixstax.net/dev/myapp:tag`
  - Fail build on CRITICAL: `grype ... --fail-on critical`
  - Grype vs Trivy: when to use each, Grype at CI time vs Trivy scan-on-push in Harbor
- Image provenance (SLSA): `cosign attest --predicate provenance.json`, SLSA levels relevant to a 2-node K3s cluster

### Harbor Deep Dive — Build Integration

- Push workflow from Kaniko: authenticating with robot account, `--destination` flag format, tag conventions (`sha-$COMMIT`, `latest`, semver)
- Robot accounts per pipeline: Harbor robot accounts scoped to a single project, push-only permission, rotating credentials
- Trivy scan-on-push: how it works, webhook on scan completion, what happens when CRITICAL vulns found — blocking vs alerting
- Tag immutability: configuring in Harbor UI/API, preventing `latest` overwrite in prod project, still allowing in dev project
- Image promotion workflow:
  - dev: every commit builds and pushes (mutable tags OK)
  - staging: promotion from dev via Harbor replication rule or explicit re-tag, Trivy gate required
  - prod: promotion from staging only, signature verification required, immutable tags enforced
- Replication policies: pull-based vs push-based, trigger on push vs scheduled, filter by tag pattern, flattening vs preserving namespaces
- Garbage collection: scheduling in Harbor (off-peak), what gets collected (untagged manifests), safety — never GC during active deployments
- Harbor webhooks: configuring webhook for push events, scan completion events — forwarding to n8n for pipeline automation
- Harbor API: REST API endpoints for image list, scan status, tag deletion, replication trigger, robot account CRUD

### Kyverno — Image Policy Enforcement

- Kyverno ClusterPolicy for image signing: `verifyImages` rule, `imageReferences`, `attestors` with Cosign public key or keyless
- Requiring scan results: Kyverno checking Harbor scan status via API (custom policy or external data)
- Blocking unsigned images: policy to require `cosign verify` passes before pod admission
- Allowed registries: policy restricting images to `registry.helixstax.net` only (no pulling from Docker Hub in prod)
- Mutation policies: adding labels, annotations, resource limits to all pods
- Policy exceptions: how to exempt system namespaces (kube-system, etc.) from image signing requirements
- Audit vs enforce mode: starting in audit, reviewing violations, promoting to enforce

### NeuVector — Runtime Security

- What NeuVector monitors: syscall behavior, network connections between pods, file access, process execution
- Network policy learning mode: letting NeuVector observe traffic, then enforcing discovered policies
- Behavioral baseline: detecting when a container does something outside its learned profile
- Integration with Harbor: NeuVector pulling scan results, correlating with runtime behavior
- Alerting: NeuVector → n8n webhook → Rocket.Chat notification for anomalies
- NeuVector in K3s: deployment considerations, CRDs, admission webhook interaction with Kyverno

### Full Pipeline — Cross-Cutting

- End-to-end flow: `git push` → Devtron CI triggers → Kaniko builds → Grype scans → Kaniko pushes to Harbor → Trivy scan-on-push → Cosign signs → Syft SBOM attached → Devtron triggers ArgoCD → ArgoCD syncs → Kyverno validates signature → Pod scheduled → NeuVector monitors
- Image tag strategy: `sha-$GIT_SHA` as primary tag, `latest` only in dev, semver tags for releases
- Rollback: ArgoCD rollback to previous image digest, Kyverno still validates rollback image
- Promotion gates: what must pass before image moves from dev → staging → prod (scan result, signature, SBOM present)
- Secret management in builds: OpenBao → External Secrets Operator injects build secrets into CI pod → Kaniko uses via BuildKit secret mounts
- Build caching strategy: Kaniko cache repo in Harbor kaniko-cache project, cache invalidation on base image digest change

## Required Output Format

Structure your response EXACTLY like this — it will be split into separate skill files for AI agents. Use `# Tool Name` as top-level headers so the output can be mechanically split:

```markdown
# Docker/OCI Image Building

## Overview
[2-3 sentence description]

## Dockerfile Best Practices
### Multi-Stage Builds
[patterns and examples]
### Base Image Selection
[distroless vs Alpine vs UBI vs Chainguard trade-offs]
### Layer Caching
[ordering rules, RUN --mount=type=cache]
### Security Hardening
[USER, no root, secret handling]
### Reproducibility
[digest pinning, SOURCE_DATE_EPOCH]

## BuildKit
### Key Features
[secrets, SSH, cache mounts, bind mounts]
### Registry Cache
[--cache-from/--cache-to with Harbor]
### Bake Files
[multi-target build example]

## Kaniko
### How It Works
[architecture, no Docker socket]
### Required Configuration
[flags, auth, destination format]
### Caching with Kaniko
[--cache=true, cache repo in Harbor]
### Devtron Integration
[pipeline YAML, build step config]
### Common Failures and Fixes
[permission errors, auth errors, context issues]

## OCI Image Spec
### Manifest Structure
[manifest JSON anatomy]
### Multi-Arch Images
[manifest list, platform targeting]

## Supply Chain Security
### Cosign Signing
[keyless and key-based workflows, verify command]
### SBOM with Syft
[generation, attachment as OCI artifact]
### Grype at Build Time
[scanning before push, fail-on-critical]
### SLSA Provenance
[attestation basics]

# Harbor

## Overview
[2-3 sentence description — complement to prompt 11, focus on build integration]

## Robot Accounts for CI
[per-pipeline accounts, push-only scope, credential rotation]

## Trivy Scan-on-Push
[configuration, scan results, blocking policy]

## Tag Immutability
[per-project config, dev vs prod difference]

## Image Promotion Workflow
### Dev -> Staging
[gates, replication or re-tag]
### Staging -> Prod
[signature requirement, immutable tags]

## Replication Policies
[push vs pull, trigger types, tag filters]

## Garbage Collection
[scheduling, safety rules]

## Webhooks
[push and scan events, n8n integration]

## Harbor API Reference
[key endpoints for CI/CD automation]

# Kyverno

## Overview
[2-3 sentence description]

## Image Signing Policy
[verifyImages ClusterPolicy example]

## Registry Allowlist
[restricting to internal registry]

## System Namespace Exemptions
[policy exception patterns]

## Audit vs Enforce Mode
[migration path]

# NeuVector

## Overview
[2-3 sentence description]

## Learning Mode
[traffic baseline, process baseline]

## Enforcement
[behavioral anomaly detection]

## Alerting Integration
[webhook to n8n to Rocket.Chat]

# Full Pipeline Reference

## End-to-End Flow
[git push -> running pod, all steps]

## Image Tag Strategy
[sha, latest, semver conventions]

## Rollback Procedure
[ArgoCD rollback with policy validation]

## Promotion Gates
[what must pass at each stage]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual config YAML snippets, and actual error messages. Do NOT give theory — give copy-paste-ready commands and configs for a Kaniko + Harbor + Kyverno stack on K3s. Assume no Docker daemon is available on nodes (K3s uses containerd).
