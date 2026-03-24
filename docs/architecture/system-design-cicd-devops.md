# System Design 101: CI/CD and DevOps Reference for Helix Stax

**Source**: ByteByteGo System Design 101 (https://github.com/ByteByteGoHq/system-design-101)
**License**: CC BY-NC-ND 4.0
**Last Updated**: 2026-03-20
**Author**: Remy (Research Analyst, Helix Stax)

---

## Purpose

This document maps concepts from the ByteByteGo System Design 101 repository to the Helix Stax infrastructure stack. For each concept, it records what the pattern is, how Helix Stax applies it specifically, the architectural decision taken, and the upstream diagram reference.

**Helix Stax CI/CD Pipeline (canonical)**:
```
GitHub Push
  → Devtron CI (build + test)
    → Harbor (image store + Trivy scan)
      → ArgoCD (GitOps deploy to K3s)
```

Infrastructure provisioning: OpenTofu (IaC) + Ansible (OS config) + Helm (K8s apps)

---

## 1. CI/CD Pipelines

### 1.1 CI/CD Pipeline — Core Concept

**What it is**: CI/CD automates the code-to-production journey. Continuous Integration merges code frequently and runs automated tests on every commit to catch integration problems early. Continuous Deployment carries successful builds automatically into production environments through standardized release workflows.

**Canonical stages** (ByteByteGo model):
1. Code Commit — developer pushes to version control
2. Build Trigger — CI server detects push and starts pipeline
3. Compilation and Testing — build artifacts created, unit/integration tests run
4. Results Reporting — test outcomes returned to developer fast
5. Artifact Deployment — successful build promoted to staging
6. Staging Validation — integration tests against staging environment
7. Production Deployment — CD system carries approved artifact to production

**How Helix Stax uses it**: Our pipeline maps directly to these stages:

| Stage | Helix Stax Implementation |
|-------|--------------------------|
| Code Commit | GitHub (public repo, feature branch push or PR merge) |
| Build Trigger | Devtron CI webhook fires on GitHub push event |
| Compilation and Testing | Devtron CI pipeline: Docker build, unit tests, lint |
| Results Reporting | Devtron UI + GitHub status checks |
| Artifact Deployment | Harbor registry receives tagged image + Trivy vulnerability scan |
| Staging Validation | ArgoCD sync to vCluster (test environment) |
| Production Deployment | ArgoCD GitOps sync to K3s cluster on Hetzner |

**Design decision**: The promotion gate sits between Harbor and ArgoCD. An image is only eligible for K3s deployment after Trivy scan completes with no CRITICAL findings. This is enforced in the Devtron pipeline configuration, not as a post-deploy check.

**Diagram reference**: https://bytebytego.com/guides/cicd-pipeline-explained-in-simple-terms

---

### 1.2 Deployment Strategies

**What it is**: The method used to replace a running version of a service with a new one. Different strategies trade off risk, cost, complexity, and downtime tolerance.

**The five strategies from ByteByteGo**:

| Strategy | Mechanism | Downtime | Best For |
|----------|-----------|----------|----------|
| Big Bang | All instances replaced at once | Yes | Dev/test only |
| Rolling Update | Instances updated sequentially, old ones removed as new ones pass health checks | No | Periodic production releases |
| Blue-Green | Two parallel environments; traffic switches atomically | No | Critical updates, instant rollback |
| Canary | New version serves a small traffic slice first | No | Risk-limited evaluation |
| Feature Toggle | Feature flags control which users see which behavior | No | A/B testing, gradual enablement |

**How Helix Stax uses it**:

- **Rolling Update** is the default for all services. ArgoCD applies Kubernetes rolling update by default with `maxUnavailable: 1` and `maxSurge: 1`.
- **Blue-Green** is reserved for Zitadel and any auth-adjacent service where a failed deployment cannot be tolerated. Two Helm releases (blue/green) are maintained; Traefik IngressRoute switches traffic.
- **Canary** is not yet implemented but is on the roadmap for the Helix Stax web application frontend once PostHog is integrated for measurement.
- **Feature Toggle** is handled at the application layer (environment variables via K8s ConfigMaps), not at the infrastructure layer.

**Design decision**: Do not implement blue-green at the infrastructure level for stateless microservices. The cost of maintaining two parallel sets of pods in a 2-node K3s cluster is not justified. Blue-green is reserved for stateful or auth-critical services only. Rolling updates provide sufficient safety for stateless workloads.

**Diagram reference**: https://bytebytego.com/guides/top-5-most-used-deployment-strategies | https://bytebytego.com/guides/kubernetes-deployment-strategies

---

### 1.3 Kubernetes Deployment Strategies (K8s-specific)

**What it is**: Kubernetes native deployment mechanisms that implement the abstract strategies above at the pod level.

**ByteByteGo K8s strategy breakdown**:

| K8s Strategy | Notes |
|--------------|-------|
| Recreate | Kills all pods then creates new ones. Causes downtime. Dev use only. |
| Rolling Update | Default. Sequential pod replacement. Zero downtime. |
| Shadow | Mirrors live traffic to new version using mock services. Good for performance testing. |
| Canary | Small percentage of pods run new version. Requires traffic splitting (Traefik or service mesh). |
| Blue-Green | Two full deployments exist simultaneously. Service object switches selector. |
| A/B Testing | Multiple versions run for different user segments. Requires header/cookie based routing. |

**How Helix Stax uses it**:

- Default `RollingUpdate` strategy in all Helm chart `values.yaml` files.
- Shadow deployments are not used. The K3s cluster does not have the capacity to sustain mirrored traffic at scale.
- Canary at K8s level would require Traefik traffic weighting. Traefik v2 supports this via `TraefficService` weighted round-robin. This is feasible on the current stack but not yet deployed.
- Blue-green via selector swap is used for Zitadel only.

**Design decision**: Traefik is the single ingress. All advanced traffic routing (canary, A/B) passes through Traefik IngressRoute resources. No service mesh (Istio, Linkerd) is added to the stack — complexity is not justified on a 2-node cluster and Flannel CNI does not require it.

**Diagram reference**: https://bytebytego.com/guides/kubernetes-deployment-strategies

---

## 2. Docker Concepts

### 2.1 Eight Core Docker Concepts

**What they are** (ByteByteGo definitions):

1. **Dockerfile** — Instructions file specifying base image, dependencies, and run command to build an image.
2. **Docker Image** — Immutable, layered package containing code, runtime, libraries, and config. Versioned and portable.
3. **Docker Container** — A running instance of an image. Isolated from host and other containers via namespaces and cgroups.
4. **Docker Registry** — Centralized store for images. Docker Hub is the default public registry.
5. **Docker Volumes** — Persistent storage outside the container filesystem. Survives container restarts.
6. **Docker Compose** — Tool for defining multi-container stacks in YAML. Not a production deployment tool.
7. **Docker Networks** — Virtual network infrastructure controlling container-to-container and container-to-host connectivity.
8. **Docker CLI** — Primary interface for building images, running containers, managing volumes and networks.

**How Helix Stax uses it**:

| Concept | Helix Stax Implementation |
|---------|--------------------------|
| Dockerfile | Each service repo contains a Dockerfile. Multi-stage builds are required (builder stage + runtime stage). |
| Docker Image | Built by Devtron CI. Tagged with `git-sha` and `latest`. Pushed to Harbor at `harbor.helixstax.com/<project>/<service>:<tag>`. |
| Docker Container | K3s runs containers via containerd, not Docker daemon. No Docker socket exposed on nodes. |
| Docker Registry | Harbor is the internal registry. Docker Hub is not used for service images. |
| Docker Volumes | PersistentVolumeClaims in K3s backed by Longhorn (planned) or local-path-provisioner. |
| Docker Compose | Transitional use only during migration. Target state is 100% K3s. No new services should be Compose-only. |
| Docker Networks | Replaced by Flannel CNI in K3s. Pod networking is managed by Flannel. Services communicate via Kubernetes Service DNS. |
| Docker CLI | Used in Devtron CI build steps. Not available on K3s nodes for runtime operations. Use `kubectl` and `crictl` instead. |

**Design decision**: Do not install the Docker daemon on K3s nodes. K3s uses containerd as its container runtime. Installing Docker on worker nodes creates unnecessary confusion between Docker-managed and K3s-managed containers, duplicates storage, and expands the attack surface. All image building happens in Devtron CI pipelines, not on cluster nodes.

**Diagram reference**: https://bytebytego.com/guides/top-8-must-know-docker-concepts

---

### 2.2 Docker Best Practices (9 from ByteByteGo)

**What they are**:

1. **Use official images** — Security, reliability, regular security updates.
2. **Pin specific versions** — Never use `latest`. Tag images with exact versions to avoid unpredictable behavior across environments.
3. **Multi-stage builds** — Separate build environment from runtime image. Exclude build tools, compilers, and dev dependencies from the final image.
4. **Use .dockerignore** — Exclude unnecessary files from build context. Reduces build time and image size.
5. **Least privileged user** — Run processes as a non-root user inside the container.
6. **Environment variables** — Inject config via environment variables, not hardcoded values. Enables portability across dev/staging/production.
7. **Layer caching order** — Put infrequently changing layers (base image, system dependencies) before frequently changing layers (application code). Maximizes cache reuse.
8. **Label images** — Metadata labels for version, maintainer, build date improve registry management.
9. **Scan images** — Automated vulnerability scanning catches CVEs before deployment.

**How Helix Stax enforces these**:

| Practice | Enforcement Mechanism |
|----------|-----------------------|
| Pin versions | CI pipeline rejects `latest` tag on base images (Devtron lint step) |
| Multi-stage builds | Required in all service Dockerfiles. Reviewed in PR. |
| Least privileged user | `USER nonroot` directive required. Trivy flags CRITICAL if container runs as root. |
| Environment variables | Kubernetes Secrets and ConfigMaps injected as env vars. No secrets in Dockerfiles. |
| Scan images | Harbor Trivy integration scans every push. CRITICAL CVEs block ArgoCD sync. |
| Labels | Devtron CI injects `org.opencontainers.image.*` labels at build time. |

**Design decision**: Trivy is the single scanning tool. Harbor's native Trivy integration covers both registry-level and pull-time scanning. No additional standalone scanner is added. Scan policy: CRITICAL findings block deployment. HIGH findings generate a warning and require manual sign-off in Devtron.

**Diagram reference**: https://bytebytego.com/guides/9-docker-best-practices-you-must-know

---

## 3. Kubernetes Concepts and Design Patterns

### 3.1 Ten Kubernetes Design Patterns

**What they are** (ByteByteGo categories):

**Foundational Patterns**

1. **Health Probe Pattern** — Every container must expose liveness, readiness, and startup probe endpoints. Kubernetes uses these to determine whether to route traffic to a pod and whether to restart it.

2. **Predictable Demands Pattern** — Containers declare CPU requests, CPU limits, memory requests, and memory limits. Kubernetes uses these for scheduling decisions and resource accounting.

3. **Automated Placement Pattern** — Kubernetes scheduler assigns pods to nodes based on declared resource requirements, node taints, tolerations, affinity rules, and anti-affinity rules.

**Structural Patterns**

4. **Init Container Pattern** — A separate container with its own lifecycle runs to completion before the main container starts. Used to fetch secrets, run database migrations, or seed configuration.

5. **Sidecar Pattern** — An additional container runs alongside the main application container in the same pod, sharing the network namespace and optional volumes. Extends functionality without modifying the main container.

**Behavioral Patterns**

6. **Batch Job Pattern** — Kubernetes Jobs manage isolated units of work that must run to completion. CronJobs schedule recurring batch work.

7. **Stateful Service Pattern** — StatefulSets provide stable network identities and ordered pod creation/deletion for distributed stateful applications like databases.

8. **Service Discovery Pattern** — Kubernetes Service objects and CoreDNS provide internal DNS-based service discovery. Services abstract the set of pods behind a stable virtual IP.

**Higher-Level Patterns**

9. **Controller Pattern** — Kubernetes controllers continuously reconcile observed state with declared desired state. The control loop is the fundamental operating model.

10. **Operator Pattern** — An Operator encodes operational knowledge (installation, upgrades, backups, failure recovery) in a custom controller and custom resource definitions. Automates day-2 operations for complex stateful applications.

**How Helix Stax uses each pattern**:

| Pattern | Helix Stax Application |
|---------|------------------------|
| Health Probe | Required in all Helm charts. `/healthz` and `/readyz` endpoints minimum. Devtron CI validates probes are defined before merge. |
| Predictable Demands | All deployments set `resources.requests` and `resources.limits` in Helm values. LimitRange objects prevent unbounded pods. |
| Automated Placement | Workloads are spread across `heart` (CP) and `helix-worker-1` using `podAntiAffinity` for critical services. CP node is not cordoned — it accepts workloads on this 2-node cluster. |
| Init Container | Used in Zitadel deployment for database readiness check. Used in any service that depends on a migration job completing. |
| Sidecar | Not yet broadly used. Planned for Promtail (log shipping) as a sidecar alongside application pods when Loki is deployed. |
| Batch Job | Used for database migrations (Helm hooks: `pre-upgrade` Jobs). Planned for scheduled data processing tasks. |
| Stateful Service | StatefulSets for PostgreSQL, Redis, Harbor registry components. |
| Service Discovery | All inter-service communication uses Kubernetes DNS (`<service>.<namespace>.svc.cluster.local`). No hardcoded IPs. |
| Controller Pattern | Understood as the operating model for all Kubernetes resources. ArgoCD's reconciliation loop is a controller. |
| Operator Pattern | Planned for PostgreSQL via CloudNativePG operator. Currently using manual Helm chart for Postgres — migration planned. |

**Design decision**: The Sidecar pattern is accepted but not mandated today. Services requiring log aggregation will use a Promtail sidecar rather than a DaemonSet-only approach, because DaemonSets can miss logs if pods rotate faster than the DaemonSet flush interval. This decision is revisited when Loki is deployed.

**Diagram reference**: https://bytebytego.com/guides/top-10-k8s-design-patterns

---

### 3.2 Kubernetes Service Types (Top 4)

**What they are**: Kubernetes Service objects expose pods at different network scopes.

| Type | Scope | How It Works |
|------|-------|--------------|
| ClusterIP | Internal only | Stable virtual IP accessible only within the cluster. Default type. |
| NodePort | External via node IP | Exposes a port on every node. Traffic arrives at `<node-ip>:<node-port>` and routes to pods. |
| LoadBalancer | External via cloud LB | Cloud provider provisions a load balancer. Not usable on bare-metal K3s without MetalLB or similar. |
| ExternalName | DNS alias | Maps service name to an external DNS name. No proxying. |

**How Helix Stax uses it**:

- **ClusterIP** is the default for all internal services. All pod-to-pod communication goes through ClusterIP services and Kubernetes DNS.
- **NodePort** is not used in production. It was used during initial testing before Traefik was configured. All external traffic now enters through Traefik.
- **LoadBalancer** is not used. Hetzner Kubernetes loadbalancers are not provisioned. Instead, Cloudflare Tunnel terminates public traffic and routes it to Traefik via the internal cluster IP.
- **ExternalName** is used for external managed services that need to be addressable inside the cluster (e.g., an external managed database).

**Design decision**: Cloudflare Tunnel is the edge. There is no LoadBalancer Service type in the cluster. Public traffic path is: Cloudflare DNS → Cloudflare Tunnel → Traefik IngressController (ClusterIP + NodePort 80/443) → Service (ClusterIP) → Pod. This avoids exposing any node IPs publicly.

**Diagram reference**: https://bytebytego.com/guides/top-4-kubernetes-service-types-in-one-diagram

---

## 4. Microservices Architecture Patterns

### 4.1 Nine Best Practices for Microservices (ByteByteGo)

**What they are**:

1. **Separate data storage** — Each service owns its own database. No two services share a schema or a database instance for writes.
2. **Code maturity alignment** — Services at different maturity levels should not be tightly coupled. A stable service should not be blocked by an experimental one.
3. **Independent builds** — Each service has its own CI/CD pipeline. A build failure in one service does not block others.
4. **Single responsibility** — Each service handles exactly one business capability.
5. **Container deployment** — Services are packaged as container images for environment consistency.
6. **Stateless design** — Services do not hold session state in memory. State lives in databases, caches (Redis), or is passed by the caller.
7. **Domain-driven design** — Service boundaries align with business domains, not technical layers.
8. **Micro frontend architecture** — Frontend components align with backend service boundaries where feasible.
9. **Orchestration** — Coordination between services uses an orchestrator (explicit control flow) or choreography (event-driven, implicit).

**How Helix Stax applies these**:

| Practice | Helix Stax Status and Decision |
|----------|-------------------------------|
| Separate data storage | Enforced. Each service namespace gets its own PostgreSQL database (separate database, same Postgres instance today; separate instances planned). |
| Independent builds | Enforced. Each service repo has its own Devtron CI pipeline. No shared build pipelines. |
| Single responsibility | Enforced at design review. Services are scoped to one bounded context. |
| Container deployment | Enforced. All services run as container images on K3s. |
| Stateless design | Required. Services must not store session state locally. Redis is available for distributed session storage. |
| Domain-driven design | Applied during service boundary design. Business domains map to Kubernetes namespaces (e.g., `auth`, `core`, `media`). |
| Micro frontend | Not applicable at current scale. Helix Stax frontend is a single Astro app. Micro frontends are not planned until the product scales significantly. |
| Orchestration vs Choreography | See section 4.2 below. |

**Design decision**: PostgreSQL database-per-service is the rule. Today, multiple databases live on the same Postgres instance because the cluster is small. The schema-per-service boundary is still enforced (no cross-service JOINs, no shared tables). When services grow, separate instances are provisioned via CloudNativePG with minimal code changes.

---

### 4.2 Orchestration vs. Choreography

**What they are**:

- **Orchestration**: A central coordinator (orchestrator) explicitly directs each service to perform its step. The orchestrator knows the full workflow and calls each service in sequence or parallel. If a step fails, the orchestrator handles compensation.
- **Choreography**: Services react to events. Each service subscribes to events and emits new events when its work is done. No central coordinator exists. Services are decoupled but the overall flow is implicit and harder to trace.

| Dimension | Orchestration | Choreography |
|-----------|--------------|--------------|
| Control | Centralized | Decentralized |
| Visibility | High — orchestrator has full picture | Low — distributed across services |
| Coupling | Services coupled to orchestrator | Services coupled to event schema only |
| Failure handling | Orchestrator manages compensation | Each service handles its own failures |
| Complexity | Simpler to trace, harder to scale orchestrator | Complex to trace, easy to add new subscribers |

**How Helix Stax uses it**:

- **Orchestration** is used for multi-step business workflows (e.g., user onboarding: create account → provision workspace → send welcome email). n8n functions as the workflow orchestrator for these cross-service flows.
- **Choreography** is used for audit logging and analytics events. Services emit events to a message bus (NATS or Kafka, TBD). Log consumers subscribe independently without the emitting service caring about consumers.

**Design decision**: Default to orchestration for user-facing workflows where failure compensation and visibility matter. Use choreography for fire-and-forget events (logs, analytics, notifications) where loss of one consumer does not break the user flow. Do not mix the two patterns in a single workflow — pick one and be explicit in the service design doc.

**Diagram reference**: https://bytebytego.com/guides/orchestration-vs-choreography (currently 404 — check ByteByteGo for updated URL)

---

## 5. Git Workflows and Branching Strategies

### 5.1 How Git Works

**What it is**: Git is a distributed version control system. Every clone is a full copy of the repository with complete history. Developers work on local branches, commit changes, and push to shared remotes. The core data model is a directed acyclic graph (DAG) of commit objects.

**Key workflow** (ByteByteGo model):
- Working tree → Staging area (index) → Local repository → Remote repository
- `git add` moves changes from working tree to staging area
- `git commit` writes staged changes to local repository as a new commit object
- `git push` copies local commits to the remote repository

**How Helix Stax uses it**: Standard Git workflow with GitHub as the remote. All infrastructure-as-code, Helm charts, Ansible playbooks, and application source code lives in GitHub. ArgoCD watches specific Git repos and branches for declarative state.

---

### 5.2 Git Merge vs. Git Rebase

**What they are**:

**Merge** creates a new merge commit that ties the histories of two branches together. The commit graph is non-linear but the history of both branches is preserved exactly as it happened.

```
main:    A - B - C - G'
                      |
feature: A - B - D - E - F
```
G' is the merge commit containing all changes.

**Rebase** replays the commits of a feature branch on top of the current tip of the target branch. Creates new commit objects (E', F', G') with the same changes but different parent pointers. The result is a linear history.

```
Before rebase:         After rebase:
main:    A - B - C     main:    A - B - C - E' - F' - G'
feature: A - D - E - F
```

| Dimension | Merge | Rebase |
|-----------|-------|--------|
| History | Non-linear, preserves actual sequence | Linear, cleaner log |
| Safety | Safe on public/shared branches | NEVER on public branches — rewrites history |
| Traceability | Full context preserved | Harder to trace original branch work |
| Conflict resolution | Once at merge time | Once per rebased commit |

**Critical rule from ByteByteGo**: "Never rebase on public branches." Rebasing rewrites commit SHAs. Anyone who has based work on those commits will have divergent history.

**How Helix Stax uses it**:

- **Merge** for integrating feature branches into `main`. PRs are merged with a merge commit (no squash, no rebase). This preserves the PR history and makes ArgoCD sync events traceable to specific PRs.
- **Rebase** is permitted locally on private feature branches before opening a PR, to keep the branch current with `main` and reduce merge conflicts at PR time.
- **No force pushes** to `main` or any shared branch. Branch protection rules enforce this in GitHub.
- **No squash merges** for infrastructure repos. Atomic commits with meaningful messages are required. Each commit in `main` should be individually deployable.

**Design decision**: Merge commits in `main` provide an audit trail linking ArgoCD sync events to specific PRs. Squash merges discard the intermediate commit history, making it harder to bisect a regression. The slight noise in git log is acceptable.

**Diagram reference**: https://bytebytego.com/guides/git-merge-vs-git-rebate

---

### 5.3 Branching Strategy

**Recommended model for Helix Stax** (derived from ByteByteGo Git workflow + infrastructure constraints):

```
main           — Production state. ArgoCD watches this branch.
  ├── feature/  — Short-lived feature branches. PR → main.
  ├── fix/       — Bug fix branches. PR → main.
  ├── infra/     — Infrastructure change branches. PR → main.
  └── release/  — (Reserved for versioned releases if needed later)
```

**Rules**:
- `main` is always deployable. ArgoCD auto-syncs on merge.
- Feature branches are short-lived (days, not weeks). Long-lived branches drift and create large merge conflicts.
- Each PR touches one concern. A PR that changes both application code and Helm chart is allowed; a PR that changes three unrelated services is not.
- Commit messages follow Conventional Commits format: `feat:`, `fix:`, `chore:`, `docs:`, `infra:`, `ci:`.

**Design decision**: No separate `develop` or `staging` branch. Environment promotion is handled by ArgoCD `ApplicationSet` with environment overlays (Kustomize patches or Helm values overrides), not by branch names. The branch is `main`; the environment is determined by the ArgoCD Application target namespace and values file.

---

## 6. Cloud and Distributed System Design Patterns

### 6.1 Infrastructure as Code — Terraform/OpenTofu Workflow

**What it is**: Infrastructure as Code (IaC) replaces manual cloud resource provisioning with declarative configuration files. Terraform (and its open-source fork OpenTofu) follows a plan → apply workflow:

1. **Write** — Define resources in `.tf` files using HCL. Use variables, modules, and community registry modules for reuse.
2. **Plan** — `tofu plan` compares desired state (`.tf` files) against current state (`terraform.tfstate`). Shows what will be created, modified, or destroyed.
3. **Apply** — `tofu apply` executes the plan, making API calls to providers (Hetzner Cloud, Cloudflare, etc.) to provision resources.
4. **State** — `terraform.tfstate` tracks all provisioned resources. This file is the source of truth for infrastructure.

**How Helix Stax uses it**:

| Layer | Tool | Scope |
|-------|------|-------|
| Cloud infrastructure | OpenTofu | Hetzner servers, networks, firewalls, volumes, floating IPs |
| DNS and CDN | OpenTofu (Cloudflare provider) | DNS records, Cloudflare Tunnel configuration, Access policies |
| K8s apps | Helm | Application deployments, services, ingress rules |
| OS configuration | Ansible | AlmaLinux packages, SELinux policies, K3s installation, user management |

**Design decision**: OpenTofu is strictly for infrastructure that lives outside Kubernetes (cloud VMs, DNS, networking). It does not manage Kubernetes resources directly. Kubernetes resources are managed by Helm + ArgoCD. This keeps the IaC blast radius contained — a `tofu apply` error cannot break a running K3s cluster.

**Diagram reference**: https://bytebytego.com/guides/how-does-terraform-turn-code-into-cloud

---

### 6.2 Seven Distributed System Patterns (ByteByteGo)

**What they are** and how Helix Stax applies each:

**1. Ambassador**
A proxy container that sits between a service and the external world, handling cross-cutting concerns like retries, circuit breaking, and authentication. Implemented as a sidecar or as a dedicated proxy service.

*Helix Stax*: Traefik serves as the cluster-level ambassador for all inbound traffic. Per-service ambassadors are not used today.

**2. Circuit Breaker**
Prevents cascading failures by detecting when a downstream service is unhealthy and short-circuiting calls to it. The circuit opens (stops calls), waits, then allows test calls to detect recovery.

*Helix Stax*: Not yet implemented at the application layer. Planned via Traefik middleware (retry and circuit breaker plugins) for inter-service HTTP calls. Services should handle circuit breaker logic internally using a library (e.g., resilience4j for JVM services) rather than relying on infrastructure-level handling alone.

**3. CQRS (Command Query Responsibility Segregation)**
Separates the write model (commands that change state) from the read model (queries that return state). Write and read operations use different data models, potentially different databases.

*Helix Stax*: Applied selectively for high-read services. The primary pattern is a write-optimized PostgreSQL for commands and a read replica or Redis cache for queries. Full CQRS with separate event-sourced write stores is not warranted at current scale.

**4. Event Sourcing**
State is derived from a sequence of immutable events rather than stored as current state. The event log is the source of truth; current state is computed by replaying events.

*Helix Stax*: Not implemented as the primary pattern. Reserved for audit-critical domains (billing, user account changes). For those domains, a shadow event log (PostgreSQL append-only table) captures all state-changing events alongside the main write model.

**5. Leader Election**
In a distributed system, one node is designated the leader and performs operations that must not run concurrently (e.g., scheduled jobs, lock acquisition). Algorithms like Raft or etcd-based leases are used.

*Helix Stax*: K3s uses etcd (or SQLite in single-node mode) for leader election of the control plane. Application-level leader election for CronJobs is handled by Kubernetes `CronJob` objects with `concurrencyPolicy: Forbid`. No custom leader election is implemented.

**6. Publisher/Subscriber**
Services communicate asynchronously through a message broker. Publishers emit events without knowing who consumes them. Subscribers register interest in event types.

*Helix Stax*: NATS is the planned message bus for internal pub/sub. Current state: direct HTTP calls between services. NATS deployment is on the infrastructure roadmap. When deployed, it runs as a StatefulSet in the `messaging` namespace.

**7. Sharding**
Data is partitioned across multiple storage nodes based on a shard key (e.g., user ID modulo N). Each shard holds a subset of the total data, enabling horizontal scaling of storage.

*Helix Stax*: Not currently implemented. PostgreSQL runs as a single primary instance. Sharding is not warranted at current scale. If the platform grows to multi-tenant SaaS at significant user volume, CloudNativePG with Patroni or Citus would be evaluated for horizontal scaling.

**Diagram reference**: https://bytebytego.com/guides/top-7-most-used-distributed-system-patterns

---

### 6.3 Observability — Logging, Tracing, and Metrics

**What they are**: Three complementary signals for understanding system behavior:

| Signal | What It Records | Volume | Primary Tool (ByteByteGo) |
|--------|----------------|--------|--------------------------|
| Logs | Discrete events (request received, error thrown, DB query executed) | Highest | ELK stack (Elasticsearch, Logstash, Kibana) |
| Traces | Single request journey across multiple services (latency, path) | Medium | OpenTelemetry (standard framework) |
| Metrics | Aggregated numeric measurements over time (QPS, latency p99, error rate) | Lowest | Prometheus → time-series DB → Grafana |

**How Helix Stax implements each**:

**Logging**:
- Log aggregation: Promtail (log shipper) → Loki (log storage) → Grafana (visualization)
- Log format: JSON structured logs required from all services
- Log levels: ERROR for failures, WARN for degraded behavior, INFO for operational events, DEBUG disabled in production
- Retention: 30 days in Loki, then expired

**Tracing**:
- Standard: OpenTelemetry SDK in all services
- Collector: OpenTelemetry Collector deployed as DaemonSet
- Backend: Tempo (Grafana's tracing backend) planned; Jaeger as interim
- Trace propagation: W3C TraceContext headers required on all inter-service HTTP calls

**Metrics**:
- Prometheus scrapes all services via ServiceMonitor CRDs (kube-prometheus-stack)
- All services must expose `/metrics` endpoint in Prometheus format
- Alert rules defined in PrometheusRule CRDs, managed as Helm chart values
- Grafana for dashboards. Alertmanager routes to PagerDuty or Rocket.Chat for on-call

**Design decision**: Use the Grafana stack (Loki + Tempo + Grafana + Prometheus) for unified observability rather than mixing tools (e.g., Datadog + Jaeger + ELK). Single UI, single installation, single license model. The `kube-prometheus-stack` Helm chart is the canonical deployment for the metrics layer.

**Diagram reference**: https://bytebytego.com/guides/logging-tracing-metrics

---

## 7. DevOps, SRE, and Platform Engineering

**What they are** (ByteByteGo distinction):

| Role | Focus | Ownership |
|------|-------|-----------|
| DevOps | Bridge between development and operations. Automate build, test, deploy pipelines. Reduce friction in the software delivery lifecycle. | CI/CD pipeline, automation tooling |
| SRE (Site Reliability Engineering) | Apply software engineering principles to operations. Define SLOs/SLIs. Error budgets. Incident management. | Reliability, on-call, toil reduction |
| Platform Engineering | Build internal developer platform (IDP). Abstract infrastructure complexity so product teams self-serve. | Internal tooling, golden paths, developer experience |

**How Helix Stax maps to these roles**:

At current scale, these three disciplines are performed by the same team. The distinctions are used for prioritization rather than org structure:

- **DevOps work** = Devtron CI pipeline configuration, Harbor maintenance, ArgoCD Application definitions, Helm chart management
- **SRE work** = Defining uptime SLOs for each service, configuring alerting, writing runbooks, chaos testing
- **Platform Engineering work** = Documenting the golden path for deploying a new service, providing Helm chart templates, onboarding guides for contributors

**Design decision**: The internal developer platform target is: a developer pushes a feature branch, a PR opens, CI runs, a reviewer approves, merge to main triggers ArgoCD sync, service is live within 5 minutes. No manual steps after the PR merge. This is the "golden path" that all new services must follow.

---

## 8. Summary: Helix Stax Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Default deployment strategy | Rolling Update | Zero downtime, sufficient for stateless services on 2-node K3s |
| Blue-green use case | Auth services only | Cost of dual environments not justified for stateless workloads |
| Container runtime on nodes | containerd (no Docker daemon) | K3s default, cleaner security boundary |
| Internal registry | Harbor with Trivy | Self-hosted, OIDC-integrated, vulnerability scanning built in |
| Traffic entry | Cloudflare Tunnel → Traefik | No exposed node IPs, Cloudflare origin CA, no cert-manager needed |
| Service discovery | Kubernetes DNS (ClusterIP) | Native, no additional tooling required |
| Data storage per service | Separate PostgreSQL databases | Enforces service independence; same instance today, separate on growth |
| IaC tool | OpenTofu (Terraform fork) | Open-source, same HCL syntax, no license concerns |
| OS configuration | Ansible | AlmaLinux/RHEL-family, dnf-based, SELinux-aware playbooks |
| Observability stack | Grafana (Loki + Tempo + Prometheus) | Unified UI, single deployment, open-source |
| Message bus | NATS (planned) | Lightweight, K8s-native, suitable for pub/sub at current scale |
| Git branching | Trunk-based (`main` is production) | ArgoCD watches `main`; environment separation via Helm values overlay |
| Merge strategy | Merge commits (no squash) | Preserves PR history, enables ArgoCD sync traceability |

---

## 9. Open Questions

1. **NATS vs Kafka**: NATS is lighter but Kafka provides stronger delivery guarantees and replay capability. Decide before implementing the first async workflow.

2. **CloudNativePG timeline**: Manual Postgres Helm chart is a stopgap. When does CloudNativePG operator get deployed? This unlocks HA, automated backups, and the path to sharding.

3. **Canary deployment readiness**: Traefik supports weighted routing for canary. PostHog is needed for measurement. Is there a service that warrants canary before PostHog is live?

4. **Loki retention policy**: 30 days assumed. Is this sufficient for compliance or audit requirements for the target market?

5. **Operator pattern for Zitadel**: The Zitadel community maintains a Kubernetes Operator. Should we migrate from the current Helm-only deployment? Operator provides automated cert rotation and config reconciliation.

---

*Research compiled by Remy (stax-preparer) from ByteByteGo System Design 101 repository and bytebytego.com guides.*
*All diagrams and guides are copyright ByteByteGo, licensed CC BY-NC-ND 4.0.*
