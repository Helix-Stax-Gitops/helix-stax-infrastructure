# Gemini Deep Research Prompt: Infrastructure Compliance Readiness

> **Instructions to Gemini**: This is a DEEP RESEARCH request. Take your time. I want exhaustive, detailed analysis — not summaries. Use your full context window. Search for the latest 2025-2026 documentation, CVEs, compatibility reports, and community discussions for every tool mentioned. Cross-reference official docs, GitHub issues, NIST publications, HHS guidance, and AICPA trust service criteria. Where you find conflicting information, present both sides with sources. I would rather have a thorough answer that takes longer than a quick surface-level response.

## WHO I AM
I'm the founder of **Helix Stax**, a technology consultancy based in Virginia (757 area).

### What Helix Stax Is
Helix Stax is a technology consultancy that helps small and mid-size businesses modernize their IT infrastructure, automate operations, and build secure, scalable systems. Our services include:
- **Infrastructure design and deployment** — Kubernetes, cloud architecture, CI/CD pipelines
- **Security hardening and compliance** — NIST, SOC 2, ISO 27001, HIPAA readiness
- **Automation** — n8n workflows, AI-assisted operations, monitoring and alerting
- **Managed infrastructure** — we host and operate client environments on hardened infrastructure
- **CTGA (Cybersecurity Technology Gap Assessment)** — proprietary assessment framework for evaluating client security posture

We practice what we preach — our own infrastructure is the reference implementation we show clients. If our infra is compliant, we can offer the same baseline to every client environment we spin up.

### Why Compliance Matters For Us
1. **Credibility** — "We built it for ourselves first" is the strongest pitch
2. **Client requirements** — enterprise and healthcare clients ask for SOC 2, ISO 27001, HIPAA
3. **Federal market** — Virginia (757) has heavy DoD/federal presence; FIPS + NIST opens doors
4. **Productization** — Phase 3 roadmap is one-command client environment provisioning with compliance baked in

I run a 3-node K3s Kubernetes cluster on Hetzner Cloud. I need to make my infrastructure compliant with **FIPS 140-3**, **SOC 2**, **ISO 27001**, and **HIPAA-ready** — not certified yet, but architecturally ready so I can pursue certification when clients require it.

## MY CURRENT INFRASTRUCTURE

### Compute
- **Control Plane**: Hetzner CPX31 (Ashburn, VA) — AlmaLinux 9.7, K3s v1.34.4+k3s1
- **Worker Node 1**: Hetzner CPX51 (64GB RAM) — AlmaLinux 9.7, K3s worker
- **Worker Node 2**: Hetzner (specs TBD) — AlmaLinux 9.7, K3s worker (3rd node being added)
- **Services VPS**: Hetzner CPX31 (Hillsboro, OR) — Authentik, NetBird
- **Home Server**: Dell 5540, Kubuntu 24.04, Docker (Nextcloud, Jellyfin, Portainer) — NOT production, personal use only

### Kubernetes Stack
- **Distribution**: K3s (lightweight Kubernetes)
- **CNI**: Flannel (bundled with K3s)
- **Ingress**: Traefik (bundled with K3s)
- **CI/CD**: Devtron + ArgoCD (Devtron wiped, fresh reinstall pending)
- **Storage**: local-path-provisioner (bundled)
- **GitOps**: ArgoCD (embedded in Devtron)

### Identity & Access
- **Authentication**: Zitadel (migrating from Authelia) — OIDC provider
- **IdPs**: GitHub + Google configured in Zitadel
- **Network Access**: NetBird (self-hosted on VPS)
- **Edge Security**: Cloudflare Zero Trust (tunnel, Access, device posture)
- **TLS**: Cloudflare Origin CA (15-year certs, no cert-manager)

### Data Layer
- **Database**: PostgreSQL (Devtron bundled subchart, planning CloudNativePG operator)
- **Vector DB**: pgvector at worker node (port 30432)
- **Object Storage**: MinIO (currently Docker Compose, migrating to K3s)
- **Container Registry**: Harbor (currently Docker Compose, migrating to K3s)

### Monitoring (deployed but not fully configured)
- **Metrics**: Prometheus (kube-prometheus-stack via Helm)
- **Dashboards**: Grafana
- **Logs**: NOT deployed yet (planning Loki)
- **Alerting**: NOT configured yet (planning Grafana OnCall)

### Secrets Management
- **Current**: Hardcoded or in environment variables (NOT secure)
- **Planned**: OpenBao (open-source Vault fork)

### CI/CD Pipeline (target state, not fully built yet)
```
VS Code + Claude Code → GitHub (public repos) → GitHub Actions (CI) → vCluster (test) → Harbor/GHCR (registry) → Devtron/ArgoCD (CD) → K3s (production)
```

### Operating System
- **AlmaLinux 9.7** on all servers (RHEL-family, SELinux capable, FIPS capable)
- FIPS mode NOT enabled yet
- SELinux status unknown (may be permissive or disabled)

### Key Planned Additions
- **vCluster**: Virtual K8s clusters for testing (on K3s worker node)
- **Okteto**: PR preview environments with vCluster
- **Lens**: Desktop K8s IDE for cluster management
- **Monokle**: Helm chart validation
- **Terraform**: Hetzner IaC (Phase 2)
- **Ansible**: Server configuration management (Phase 2)
- **Loki**: Log aggregation
- **Grafana OnCall**: Alerting and incident response
- **CrowdSec**: Intrusion detection + blocking
- **CloudNativePG**: Managed PostgreSQL operator for K3s

### Hosting Constraint
- **Hetzner has ISO 27001 and BSI C5 Type 2**
- **Hetzner does NOT have SOC 2 or HIPAA BAA**
- **Strategy**: Helix Stax internal infra stays on Hetzner. Client environments with PHI deploy on AWS/Azure/GCP (they sign BAAs). Terraform/Ansible must be provider-agnostic.

---

## WHAT I NEED YOU TO RESEARCH

### 1. FIPS 140-3 Compliance on AlmaLinux 9 + K3s

Research and provide a detailed, step-by-step guide for:

a) **Enabling FIPS mode on AlmaLinux 9.7**
   - Exact commands to enable FIPS 140-3 mode
   - Impact on K3s — does K3s work in FIPS mode? Known issues?
   - Impact on Flannel CNI in FIPS mode
   - Impact on Traefik in FIPS mode
   - Impact on etcd (K3s embedded) in FIPS mode
   - Any packages that need to be swapped for FIPS-validated versions
   - How to verify FIPS mode is active and working

b) **FIPS-compliant crypto across the stack**
   - PostgreSQL: Does it use FIPS-validated crypto when AlmaLinux FIPS mode is on?
   - Zitadel: FIPS compatibility — does it use Go's crypto/tls (which respects FIPS)?
   - Harbor: FIPS considerations
   - MinIO: FIPS considerations
   - OpenBao: FIPS mode support (it's a Vault fork — does it have FIPS seal?)
   - Cloudflare Origin CA: Is the certificate chain FIPS-compliant?
   - NetBird: WireGuard crypto — is it FIPS-validated?

c) **FIPS gaps and workarounds**
   - What tools in my stack will BREAK in FIPS mode?
   - What alternatives exist for non-FIPS-compliant components?
   - Is WireGuard (NetBird) FIPS-compliant? If not, what's the alternative for zero-trust networking?

### 2. SOC 2 Readiness with My Stack

Research and provide a detailed mapping of SOC 2 Trust Service Criteria to my infrastructure:

a) **Security (Common Criteria — CC)**
   | SOC 2 Control | My Tool | What I Need to Configure | Gap? |
   |--------------|---------|-------------------------|------|
   Map every CC control (CC1 through CC9) to my specific tools.

b) **Availability**
   - How do I prove availability with K3s + Hetzner?
   - Monitoring requirements: Is Prometheus + Grafana + Loki sufficient?
   - Backup requirements: What needs to be backed up, how, how often?
   - DR plan: Single control plane K3s (3 nodes: 1 CP + 2 workers) — what's my DR story?

c) **Confidentiality**
   - Data classification with my stack
   - Encryption requirements already covered by FIPS section
   - Network segmentation: Kubernetes NetworkPolicies — what do I need?
   - Namespace isolation requirements

d) **Processing Integrity**
   - Audit logging: What does Loki need to capture?
   - Change management: How does my GitOps pipeline (ArgoCD) satisfy this?
   - Input validation requirements for any custom code

e) **Privacy** (if applicable)
   - Do I need this criterion? (consultancy handling client data)
   - Data retention and deletion policies needed

f) **Evidence collection**
   - What logs/metrics/screenshots would an auditor want to see?
   - How do I automate evidence collection with my monitoring stack?
   - Recommended folder structure for SOC 2 evidence

### 3. ISO 27001:2022 Readiness with My Stack

Research and provide:

a) **ISMS (Information Security Management System) structure**
   - Mandatory documents I need to create
   - Policies I need to write (list them with brief descriptions)
   - Where should these live? (Obsidian vault? Git repo? Both?)

b) **Annex A controls mapping**
   Map every applicable Annex A control (ISO 27001:2022 has 93 controls in 4 themes) to my specific tools:
   | Annex A Control | My Tool | Configuration Needed | Status |
   |----------------|---------|---------------------|--------|

c) **Statement of Applicability (SoA)**
   - Which Annex A controls apply to a small consultancy running K3s on Hetzner?
   - Which controls can I mark as "not applicable" with justification?

d) **Internal audit approach**
   - Can I self-audit initially?
   - What's the minimum viable internal audit for a solo operator?
   - Tools to automate compliance checking against ISO 27001

### 4. HIPAA-Ready Architecture

Research and provide:

a) **HIPAA Security Rule — Technical Safeguards mapping**
   | HIPAA Requirement (§164.312) | My Tool | Configuration Needed | Gap? |
   |-----------------------------|---------|---------------------|------|
   Map every technical safeguard to my specific tools.

b) **HIPAA Security Rule — Administrative Safeguards**
   - What policies do I need as a solo operator / small consultancy?
   - Risk assessment requirements — how to do this with my stack
   - Workforce training requirements (even for a team of AI agents?)

c) **HIPAA Security Rule — Physical Safeguards**
   - Hetzner data center physical security — does their ISO 27001 cover this?
   - What about my home server (Dell 5540)? Can I use it for anything PHI-related?

d) **Business Associate Agreement (BAA) requirements**
   - What do I need in a BAA with clients?
   - Template or key clauses for a BAA
   - Sub-processor BAAs needed: Cloudflare, GitHub, any others?

e) **Multi-cloud HIPAA architecture**
   - When a healthcare client needs PHI hosting, what's the minimum viable setup on AWS/Azure/GCP?
   - Can I use my same Helm charts on EKS/AKS/GKE?
   - Terraform modules for HIPAA-eligible environments on each cloud
   - Cost estimates for a minimal HIPAA-eligible K8s cluster on each cloud provider

f) **PHI data flow architecture**
   - How to isolate PHI in a multi-tenant K8s environment
   - vCluster for client isolation — is this HIPAA-sufficient?
   - Network policies for PHI isolation
   - Encryption requirements specific to PHI

### 5. Cross-Framework Overlap

Research and provide:

a) **Control mapping across all four frameworks**
   | Control Area | FIPS 140-3 | SOC 2 | ISO 27001 | HIPAA | My Tool |
   |-------------|-----------|-------|-----------|-------|---------|
   Show where one implementation satisfies multiple frameworks.

b) **NIST CSF v2.0 as the unifying framework**
   - How does NIST CSF map to each of the four frameworks?
   - If I build to NIST CSF, what percentage of each framework am I covering?
   - What's left uncovered by NIST CSF for each framework?

c) **Priority order for implementation**
   - What should I implement first to get maximum cross-framework coverage?
   - What's the minimum viable compliance posture for a consultancy pitch?
   - What quick wins can I achieve this week vs this month vs this quarter?

### 6. Automated Compliance Tooling

Research and provide recommendations for:

a) **Policy-as-code tools for Kubernetes**
   - OPA/Gatekeeper vs Kyverno vs Kubewarden — which fits K3s best?
   - Pre-built policy libraries for FIPS/SOC 2/ISO 27001/HIPAA
   - How to integrate with my ArgoCD GitOps pipeline

b) **Compliance scanning**
   - CIS Kubernetes Benchmark scanner for K3s
   - OpenSCAP for AlmaLinux FIPS/STIG compliance
   - Container image scanning (Harbor Trivy — already have it)
   - Kubernetes security scanning (kubeaudit, kube-bench, polaris)

c) **Audit log aggregation for compliance**
   - What Loki queries satisfy SOC 2 audit requirements?
   - What retention periods are required (SOC 2, ISO 27001, HIPAA)?
   - Immutable log storage — how to prevent log tampering?

d) **Compliance dashboards**
   - Grafana dashboards for compliance monitoring
   - What metrics/alerts map to compliance controls?
   - Can I build a "compliance status" dashboard for client-facing demos?

---

## OUTPUT FORMAT

For each section, provide:
1. **Current state assessment** (based on what I described above)
2. **Gap analysis** (what's missing)
3. **Step-by-step remediation** (exact commands, configs, or actions)
4. **Priority** (critical / high / medium / low)
5. **Estimated effort** (hours/days for a solo operator with AI agent assistance)
6. **Cross-framework impact** (which other frameworks does this fix also satisfy?)

Organize your response as a structured implementation roadmap I can follow phase by phase. Be specific to MY stack — don't give generic advice. Reference exact tool names, Helm chart names, config file paths, and CLI commands where possible.

Where there are multiple options, give me a recommendation with trade-offs, not just a list.

Flag any areas where my current architecture is fundamentally incompatible with a framework and would require significant changes.

---

## 7. TOOL DISCOVERY — WHAT AM I MISSING?

Beyond what I already have planned, research and recommend tools I should consider:

### a) Compliance-Specific Tools
- **GRC platforms** (Governance, Risk, Compliance) — are there any open-source or affordable ones for a small consultancy? (e.g., Eramba, OpenGRC, Ciso Assistant, etc.)
- **Compliance automation platforms** — anything that auto-generates evidence for SOC 2/ISO 27001? (e.g., Vanta, Drata, Secureframe — but are there self-hosted/open-source alternatives?)
- **Risk assessment tools** — open-source tools for conducting HIPAA/NIST risk assessments
- **Policy management** — tools for creating, versioning, and distributing security policies (beyond just Obsidian markdown files)

### b) Kubernetes Security Tools I Might Not Know About
- **Runtime security**: Falco, Tetragon, Tracee — which fits K3s + AlmaLinux best?
- **Network policies**: Calico vs Cilium network policies on Flannel — what can I do without changing CNI?
- **Secrets operators**: External Secrets Operator vs Vault Secrets Operator (for OpenBao) — which is better for multi-framework compliance?
- **Image signing**: Cosign/Sigstore for supply chain security — how does this map to compliance frameworks?
- **SBOM generation**: Syft, Trivy — do compliance frameworks require SBOMs?
- **Admission controllers**: What policies should I enforce at admission for compliance?
- **Certificate management**: If I'm not using cert-manager (Cloudflare Origin CA), am I missing certificate rotation/lifecycle tools?

### c) Observability for Compliance
- **Audit trail tools**: Beyond Loki — are there specialized K8s audit log tools?
- **Kubernetes audit policy**: What events must be captured for each compliance framework?
- **SIEM**: Do I need a SIEM? Can Grafana + Loki serve as a lightweight SIEM for compliance?
- **File integrity monitoring**: AIDE, OSSEC — needed for compliance?
- **Vulnerability management**: Beyond Trivy — continuous vulnerability tracking and remediation workflow tools

### d) Backup & Disaster Recovery
- **K8s backup tools**: Velero, Kasten — which works best with K3s + local-path-provisioner?
- **Database backup**: pgBackRest, Barman — for PostgreSQL/CloudNativePG compliance-grade backups
- **DR testing**: Tools or approaches for automated DR testing
- **Cross-region backup**: Offsite backup to different Hetzner region or cloud provider — options?

### e) Identity & Access Beyond What I Have
- **Privileged Access Management (PAM)**: Do I need one? Open-source options?
- **Service mesh**: Do compliance frameworks require mutual TLS between services? If so, Linkerd vs Istio on K3s?
- **API gateway**: Beyond Traefik — do I need an API gateway with rate limiting, OAuth2, API key management for compliance?

### f) Client-Facing Compliance Tools
- **Trust centers / security pages**: Tools to create a public-facing security posture page (like what Vanta/Drata generate)
- **Compliance questionnaire automation**: Tools that auto-fill vendor security questionnaires (SIG, CAIQ, etc.)
- **Penetration testing**: Open-source or affordable pentest tools I should run regularly
- **Bug bounty platforms**: Worth setting up for a small consultancy?

### g) Development Pipeline Security
- **SAST** (Static Application Security Testing): Tools for scanning Helm charts, Dockerfiles, Python, TypeScript
- **DAST** (Dynamic Application Security Testing): Tools for scanning running services
- **Dependency scanning**: Beyond Trivy — Grype, Snyk open-source, Dependabot for GitHub
- **Pre-commit hooks**: What security checks should run before every commit?
- **GitHub Actions security**: Actions for compliance checks in CI pipeline

For each tool recommendation:
1. **Name and what it does**
2. **Open-source / free tier / paid?**
3. **K3s + AlmaLinux compatible?**
4. **Helm chart available?**
5. **Which compliance framework(s) it satisfies**
6. **Priority for my situation** (must-have / nice-to-have / future)
7. **How it fits into my existing pipeline**

---

## 8. IMPLEMENTATION ROADMAP

Based on everything above, create a phased implementation roadmap:

### Phase 0: Quick Wins (This Week)
- What can I enable/configure TODAY with zero new tools?
- What policies can I write THIS WEEK?

### Phase 1: Foundation (This Month)
- Core security controls to implement
- Tools to install and configure
- Policies and procedures to document

### Phase 2: Hardening (Next Month)
- Advanced security controls
- Automated compliance checking
- Monitoring and alerting for compliance

### Phase 3: Audit-Ready (60-90 Days)
- Evidence collection automation
- Internal audit procedures
- Gap remediation
- Client-facing compliance documentation

### Phase 4: Client Environments (When Needed)
- Multi-cloud HIPAA setup
- Per-client isolation architecture
- BAA templates and legal requirements

For each phase, specify:
- Exact tools to install (with Helm chart names and versions where applicable)
- Configuration changes (with commands or config snippets)
- Documents to create (with templates or outlines)
- Estimated hours of work
- What compliance frameworks each item satisfies
- Dependencies (what must be done before this)

---

## OUTPUT FORMAT

For each section, provide:
1. **Current state assessment** (based on what I described above)
2. **Gap analysis** (what's missing)
3. **Step-by-step remediation** (exact commands, configs, or actions)
4. **Priority** (critical / high / medium / low)
5. **Estimated effort** (hours/days for a solo operator with AI agent assistance)
6. **Cross-framework impact** (which other frameworks does this fix also satisfy?)

Organize your response as a structured implementation roadmap I can follow phase by phase. Be specific to MY stack — don't give generic advice. Reference exact tool names, Helm chart names, config file paths, and CLI commands where possible.

Where there are multiple options, give me a recommendation with trade-offs, not just a list.

Flag any areas where my current architecture is fundamentally incompatible with a framework and would require significant changes.

**IMPORTANT**: I am a solo operator with AI coding agents (Claude Code with PACT framework — 15+ specialist agents). Factor this into effort estimates — I can parallelize work across agents but I am the only human reviewer. Suggest which tasks can be delegated to agents vs which require my personal attention.
