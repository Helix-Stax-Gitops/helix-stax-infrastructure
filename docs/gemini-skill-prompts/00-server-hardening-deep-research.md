# Gemini Deep Research: AlmaLinux 9 Server Hardening, Security Automation & Cryptography

## Role

You are a senior infrastructure security architect specializing in Linux hardening, compliance automation, and cryptographic architecture for regulated industries. You have deep expertise in DISA STIG, CIS Benchmarks, SOC 2 Type II, ISO 27001, NIST CSF 2.0, and HIPAA. You understand the practical trade-offs of security hardening in small-team, bootstrapped environments running Kubernetes.

## Context

**Organization**: Helix Stax — a US-based IT consulting firm specializing in infrastructure automation and compliance. 1-person team bootstrapping. Sells the CTGA Framework (Controls, Technology, Growth, Adoption) — a proprietary maturity assessment scored 100-900.

**Infrastructure**:
- Two AlmaLinux 9.7 servers on Hetzner Cloud (US regions)
  - helix-stax-cp (178.156.233.12, Ashburn VA) — K3s control plane
  - helix-stax-vps (5.78.145.30, Hillsboro OR) — K3s worker
- Already hardened manually: CIS L1 benchmark, SSH (port 2222, key-only, no root), firewalld (DROP default, rich rules), SELinux enforcing, fail2ban, auditd (25 rules), auto-updates, kernel tuning, credential scrub
- Next: K3s install, then Devtron CI/CD, then full workload stack

**Full Stack** (to be deployed on K3s):
Traefik (ingress), cert-manager (TLS), CloudNativePG (PostgreSQL), Valkey (cache), MinIO (object storage), Harbor (registry), Zitadel (identity/OIDC), Devtron + ArgoCD (CI/CD), Prometheus + Grafana + Loki (monitoring), CrowdSec (IDS), Kyverno (admission control), NeuVector (runtime security), OpenBao (secrets), Velero (backup), n8n (automation), Rocket.Chat, Backstage, Outline

**Compliance Targets**:
- Tier 1 (Now): SOC 2 Type II, ISO 27001, NIST CSF 2.0, CIS Controls v8, CIS Benchmarks
- Tier 2 (Per Client): HIPAA, PCI DSS 4.0, NIST 800-171, CMMC 2.0
- Tier 3 (Future): FedRAMP, StateRAMP

**Edge Security**: Cloudflare (CDN, WAF, Zero Trust, DDoS protection, Bot Fight Mode). WAF custom rules already deployed blocking scanners, hostile nations, Tor.

**Constraints**:
- 1-person team — automation over manual processes
- Open-source preferred — no TuxCare or commercial hardening vendors
- Must not break K3s — hardening and Kubernetes must coexist
- Everything must produce auditor-accepted evidence
- GitOps model — all security config in version control

---

## SECTION 1: STIG vs CIS BENCHMARK ANALYSIS

Research and provide:

1. Full comparison of DISA STIG for RHEL9/AlmaLinux 9 vs CIS Level 1 vs CIS Level 2
   - Total control count per profile
   - Overlap percentage (controls that appear in both)
   - Conflicts (controls where STIG and CIS disagree)
   - Severity distribution (CAT I/II/III for STIG, scored/unscored for CIS)

2. Recommended superset profile for multi-framework compliance
   - Which profile better satisfies SOC 2 vs ISO 27001 vs HIPAA
   - Can both be applied simultaneously? What breaks?
   - OpenSCAP profile IDs for each (`xccdf_org.ssgproject.content_profile_*`)

3. CIS Level 1 vs Level 2 decision framework
   - What does L2 add over L1?
   - Which L2 controls are worth adopting even if not targeting full L2?
   - Which L2 controls conflict with K3s?

4. Controls already applied (verify against our current state):
   - SSH: port 2222, key-only, MaxAuthTries 3, X11 disabled
   - Firewall: firewalld DROP default, rich rules per service
   - SELinux: enforcing, targeted policy
   - auditd: 25 rules (identity, sudo, SSH, cron, modules, sysctl, time)
   - Filesystem: /tmp nodev/nosuid/noexec, file permissions locked
   - Services: unnecessary services disabled
   - Kernel: IPv6 disabled, ICMP redirects off, SYN cookies on
   - What are we missing for full CIS L1? For STIG?

---

## SECTION 2: AUTOMATED COMPLIANCE SCANNING (Open Source)

No commercial vendors. Research fully open-source scanning and drift detection:

1. **OpenSCAP Architecture**
   - `oscap` CLI for on-demand scanning
   - SCAP Security Guide (SSG) content for AlmaLinux 9
   - Available profiles: CIS L1, CIS L2, STIG, HIPAA, PCI-DSS
   - Output formats: XCCDF results, ARF (Asset Reporting Format), HTML reports
   - Are OpenSCAP reports accepted by SOC 2 / ISO 27001 auditors as evidence?
   - Tailoring files: how to create custom profiles that except K3s-required controls

2. **Lynis**
   - What does Lynis catch that OpenSCAP doesn't?
   - Custom test profiles for AlmaLinux 9
   - Hardening index scoring
   - Integration with CI/CD

3. **AIDE (Advanced Intrusion Detection Environment)**
   - File integrity monitoring configuration for AlmaLinux 9
   - What directories/files to monitor vs exclude (K3s generates a lot of runtime files)
   - Alert integration (how to pipe AIDE alerts to n8n/Rocket.Chat)

4. **Scanning Cadence and Architecture**
   - Recommended schedule: daily drift detection vs weekly full audit vs monthly comprehensive
   - Cron job architecture on host (these scan the OS, not containers)
   - Results storage: where to archive reports (MinIO for tamper-evident storage?)
   - Dashboard: Grafana integration for compliance posture visualization
   - Alert pipeline: scan failure → n8n → Rocket.Chat + ClickUp task

5. **Drift Detection Strategy**
   - Compare approaches: OpenSCAP `--remediate` mode, Ansible `--check --diff`, AIDE database comparison
   - Automated remediation: when is it safe to auto-fix vs alert-only?
   - How to handle legitimate exceptions (K3s requirements) without false positives

---

## SECTION 3: CRYPTOGRAPHY & ENCRYPTION

SOC 2 (CC6.1, CC6.7) and HIPAA (164.312(a)(2)(iv), 164.312(e)(1)) require encryption. Research:

1. **Encryption at Rest**
   - LUKS full-disk encryption on AlmaLinux 9: feasibility on Hetzner Cloud VPS, performance impact, key management for remote unlock
   - PostgreSQL Transparent Data Encryption (CloudNativePG): does it support TDE? Alternatives?
   - MinIO server-side encryption (SSE-S3, SSE-KMS): configuration with OpenBao as KMS
   - Valkey encryption at rest: supported? Workarounds?
   - etcd encryption for K3s secrets at rest
   - Backup encryption: Velero + restic encryption before Backblaze B2

2. **Encryption in Transit**
   - TLS everywhere: cert-manager with Let's Encrypt for external, self-signed CA for internal
   - mTLS between K3s nodes: does Flannel support it? Do we need a service mesh (Linkerd/Istio)?
   - PostgreSQL TLS connections (require `sslmode=verify-full`)
   - Valkey TLS
   - MinIO TLS
   - Internal service-to-service: when is mTLS overkill vs necessary for compliance?

3. **Key Management**
   - OpenBao as central KMS: architecture for both host-level and K3s secrets
   - Key rotation policies: what cadence per framework (SOC 2, HIPAA)?
   - Transit secrets engine for application-level encrypt/decrypt
   - Auto-unseal strategy for OpenBao on a 2-node cluster (no cloud KMS available)

4. **Code and Container Signing**
   - Cosign + Sigstore for container image signing in Harbor
   - Kyverno policies to verify signatures before admission
   - Git commit signing: GPG vs SSH signing
   - SBOM generation and attestation (Syft, Grype)

5. **Cryptographic Standards**
   - Minimum TLS version (1.2 or 1.3 only?)
   - Cipher suite selection for FIPS 140-2 alignment
   - SSH key algorithm requirements (Ed25519 vs RSA-4096)
   - Hashing algorithms for integrity verification

---

## SECTION 4: K3s + HARDENED HOST COMPATIBILITY

1. Known conflicts between CIS/STIG hardening and K3s
   - Kernel modules required: br_netfilter, overlay, ip_tables, nf_conntrack
   - sysctl requirements: net.bridge.bridge-nf-call-iptables=1, net.ipv4.ip_forward=1
   - cgroup v2 configuration requirements
   - Which CIS/STIG controls must be excepted for K3s? Provide exact control IDs.

2. K3s API server hardening (CIS Kubernetes Benchmark)
   - kube-bench scan: how to run and interpret results on K3s
   - K3s-specific flags for hardening (--protect-kernel-defaults, --secrets-encryption)
   - RBAC hardening
   - Audit logging for K3s API server

3. Network policy enforcement
   - How do firewalld rich rules interact with K3s iptables/nftables rules?
   - Flannel + NetworkPolicy: do we need Calico for policy enforcement?
   - East-west traffic encryption between nodes

---

## SECTION 5: DEFENSE-IN-DEPTH LAYER MAP

Provide a complete security layer architecture diagram and analysis:

```
Layer 0: Physical/Cloud (Hetzner) — what controls?
Layer 1: Network Edge (Cloudflare) — WAF, DDoS, Bot Fight, Zero Trust
Layer 2: Host OS (AlmaLinux) — CIS/STIG, SELinux, firewalld, fail2ban, auditd
Layer 3: Container Runtime — containerd hardening, seccomp, AppArmor vs SELinux
Layer 4: Orchestration (K3s) — API server, RBAC, audit, secrets encryption
Layer 5: Network (Flannel) — NetworkPolicies, east-west controls
Layer 6: Admission (Kyverno) — image policies, resource limits, security contexts
Layer 7: Runtime (NeuVector) — process monitoring, network microsegmentation
Layer 8: Application (Zitadel, services) — AuthN/AuthZ, input validation
Layer 9: Data (PostgreSQL, MinIO) — encryption, access controls, backup
```

For each layer:
- What controls exist or should exist
- What tools enforce them
- What monitoring/alerting is in place
- Where are the gaps

Also address:
- CrowdSec placement: host-level daemon vs K3s DaemonSet vs both?
- CrowdSec + fail2ban coexistence or should CrowdSec replace fail2ban?
- Container supply chain: Harbor scanning → Cosign signing → Kyverno admission → NeuVector runtime

---

## SECTION 6: ANSIBLE AUTOMATION ARCHITECTURE

1. Role selection and structure
   - `ansible-lockdown/RHEL9-CIS` and `ansible-lockdown/RHEL9-STIG` roles: quality, maintenance status, AlmaLinux 9 compatibility
   - How to structure host_vars for CP vs worker (different firewall rules, different services)
   - Idempotent playbook design that won't break K3s on re-runs
   - Custom exception handling for K3s-required controls

2. Drift detection via Ansible
   - `--check --diff` as scheduled job
   - Reporting drift to Grafana/Rocket.Chat
   - Auto-remediation guardrails

3. Infrastructure-as-code for security
   - Hardening baseline stored as Ansible playbooks in infra repo
   - OpenSCAP tailoring files in version control
   - GitOps integration: ArgoCD reconciliation of security state?

4. Rolling patch strategy
   - 2-node K3s: drain workloads, patch, reboot, uncordon
   - Maintenance window requirements for SOC 2
   - dnf-automatic vs Ansible-managed patching

---

## SECTION 7: COMPLIANCE EVIDENCE & DOCUMENTATION

1. Exact audit artifacts per framework
   - SOC 2 Type II: what evidence for CC6.1 (logical access), CC6.6 (network security), CC6.7 (encryption), CC7.2 (monitoring)?
   - ISO 27001: Annex A evidence requirements for A.8 (asset management), A.12 (operations security), A.14 (system acquisition)
   - HIPAA: Technical safeguards evidence (164.312)
   - Do auditors accept OpenSCAP XCCDF/ARF reports directly?

2. Evidence collection automation
   - Script architecture: daily scan → report generation → MinIO archival → Grafana dashboard update
   - Tamper-evident storage: hashing reports, storing hashes in separate system
   - Retention periods per framework

3. Compliance reporting cadence
   - SOC 2 continuous monitoring requirements
   - ISO 27001 surveillance audit prep
   - Monthly compliance posture report template
   - Quarterly risk assessment automation

4. Policy-to-control traceability
   - Complete mapping: CIS AlmaLinux 9 controls → SOC 2 TSC → ISO 27001 Annex A → NIST CSF → HIPAA
   - How to maintain this mapping as controls evolve

---

## SECTION 8: OPERATIONAL RUNBOOKS NEEDED

List and outline these runbooks:
1. Hardening scan failure response
2. Patch management and maintenance window SOP
3. Drift remediation workflow
4. Access review and privilege audit
5. Incident response for host-level security events
6. Key rotation procedure (OpenBao, TLS certs, SSH keys)
7. Emergency access procedure (console access, break-glass)
8. Backup verification and restore test

---

## SECTION 9: STRATEGIC RECOMMENDATIONS

1. Compliance framework pursuit order
   - Which framework first for maximum client credibility with minimum audit cost?
   - Which controls overlap to reduce marginal cost of each additional framework?
   - Realistic timeline for SOC 2 Type II readiness for a 1-person team

2. Minimum viable hardening profile
   - What's the floor that satisfies auditors without creating an ops nightmare?
   - Which controls are "checkbox" vs "actually prevents breaches"?
   - Risk-based prioritization: what attacks are most likely against a small consulting firm?

3. Client-facing differentiation
   - How does "CIS + STIG dual-hardened infrastructure" translate to client trust?
   - Certifications, badges, attestations that can be displayed
   - How this maps to CTGA Framework scoring (what hardening level = what CTGA score?)

4. Phased timeline (realistic for 1 person)
   - Phase 1: Host hardening (DONE)
   - Phase 2: K3s hardening + automated scanning
   - Phase 3: Container pipeline security (Harbor + Cosign + Kyverno)
   - Phase 4: Continuous compliance monitoring + evidence automation
   - Phase 5: SOC 2 Type II audit readiness
   - Estimated effort per phase

---

## SECTION 10: SECRETS LIFECYCLE & AUTO-ROTATION

1. **OpenBao Dynamic Secrets**
   - Database secrets engine: auto-generated, short-lived PostgreSQL credentials (no static passwords)
   - SSH secrets engine: signed SSH certificates instead of static authorized_keys — how to configure for AlmaLinux 9 + K3s nodes
   - PKI secrets engine: internal CA for mTLS, auto-renewal
   - Transit secrets engine: application-level encrypt/decrypt without exposing keys
   - Token/lease TTLs: recommended durations per secret type

2. **Automatic Rotation Architecture**
   - OpenBao → Cloudflare Secrets Store sync pipeline:
     - OpenBao rotates a secret (new value generated)
     - n8n workflow triggered (webhook or polling)
     - n8n calls Cloudflare Secrets Store API to update the value
     - Workers automatically pick up new binding values on next request
     - Notification sent to Rocket.Chat confirming rotation
   - Which secrets can OpenBao rotate directly (databases, internal certs)?
   - Which need external API calls (Cloudflare tokens, ClickUp API, GitHub PAT, Hetzner tokens)?
   - n8n workflow design for each external provider's rotation API

3. **Cloudflare Secrets Store as Distribution Layer**
   - Architecture: OpenBao (source of truth + rotation engine) → Cloudflare Secrets Store (edge distribution for Workers) → Workers consume at runtime
   - Sync strategy: push on rotation vs scheduled reconciliation vs both?
   - Conflict resolution: what if manual update in Cloudflare diverges from OpenBao?
   - Worker binding hot-reload: do Workers pick up new secret values immediately or need redeploy?
   - Fallback: what happens if Cloudflare Secrets Store is unavailable?

4. **Rotation Cadence per Compliance Framework**
   - SOC 2 CC6.1: credential rotation requirements
   - HIPAA 164.312(d): authentication credential management
   - NIST 800-53 IA-5: authenticator management rotation intervals
   - ISO 27001 A.9.2.4: management of secret authentication information
   - Recommended cadence: 90 days for API tokens, 30 days for database creds, 365 days for TLS certs, on-demand for incident response

5. **Rotation Tracking & Audit Trail**
   - ClickUp task auto-creation N days before expiry (already have rotation task due 2026-06-20)
   - Rotation log: who rotated, when, which secret, old hash vs new hash (never log values)
   - Compliance evidence: rotation logs as SOC 2 / HIPAA audit artifacts
   - Alert on missed rotations (secret past due date without rotation)

6. **Emergency Rotation (Incident Response)**
   - "Rotate everything" playbook: what order, what dependencies?
   - Bulk rotation script: hit all provider APIs in sequence
   - Post-rotation verification: confirm all consumers still authenticate
   - Downtime impact assessment: which rotations cause service interruption?

---

## SECTION 11: DUAL WORKFLOW ENGINE ARCHITECTURE (n8n + Apache Airflow)

We are running TWO workflow engines with distinct responsibilities:

- **n8n**: Real-time triggers, webhooks, notifications, light integrations (Rocket.Chat alerts, ClickUp task creation, simple API glue)
- **Apache Airflow**: Scheduled, dependency-aware, auditable pipelines for compliance-critical operations

1. **Airflow DAGs for Security Operations**
   - Secrets rotation pipeline: OpenBao rotate → Cloudflare Secrets Store sync → verify consumers → notify
   - Compliance scanning: OpenSCAP daily scan → report generation → MinIO archival → Grafana dashboard update
   - Drift detection: Ansible --check --diff → diff report → alert if changed
   - Backup verification: Velero backup check → test restore → report
   - Evidence collection: gather scan reports + audit logs → package for auditors
   - Certificate expiry monitoring: check all TLS certs → alert 30 days before expiry
   - Access review automation: pull user lists → compare against approved access → flag deviations

2. **Airflow Architecture on K3s**
   - Helm chart deployment (official apache-airflow chart)
   - PostgreSQL backend (use existing CloudNativePG or dedicated instance?)
   - Valkey as Celery broker (or use KubernetesExecutor instead?)
   - KubernetesExecutor vs CeleryExecutor: which for a 2-node cluster?
   - DAG storage: git-sync sidecar from infra repo (GitOps)
   - Resource requirements: realistic sizing for small cluster
   - OIDC integration with Zitadel for Airflow UI access

3. **n8n vs Airflow Boundary**
   - Decision framework: when does a workflow belong in n8n vs Airflow?
   - n8n handles: webhook-triggered, real-time, simple chains, notifications
   - Airflow handles: scheduled, dependency chains, retry-critical, audit-logged, compliance evidence
   - Integration: can Airflow trigger n8n webhooks for notifications? Can n8n trigger Airflow DAGs?
   - Avoiding duplication: clear ownership of each workflow type

4. **Compliance Value of Airflow**
   - Immutable run history as audit evidence
   - SLA monitoring for rotation/scanning deadlines
   - Task-level logging for traceability
   - DAGs as code in git — auditable, version-controlled
   - How auditors view Airflow logs vs n8n execution history

---

## SECTION 12: INCIDENT RESPONSE & FORENSICS

1. **Incident Response Plan**
   - NIST 800-61 framework: Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned
   - Roles for a 1-person team: what can be automated vs requires human judgment?
   - Communication plan: HIPAA breach notification (60 days), SOC 2 incident disclosure
   - Client notification templates and timelines per framework

2. **Evidence Preservation**
   - Log collection: auditd, journald, K3s audit logs, Cloudflare logs
   - Forensic imaging: how to snapshot a Hetzner server without destroying evidence
   - Chain of custody for digital evidence
   - What NOT to do (don't reboot, don't wipe logs, don't patch before capturing state)

3. **Forensic Tools for AlmaLinux 9**
   - volatility3 for memory analysis
   - tcpdump / Wireshark for network capture
   - ausearch / aureport for audit log analysis
   - chkrootkit / rkhunter for rootkit detection
   - osquery for real-time host introspection
   - What should be pre-installed vs installed on-demand?

4. **Containment Strategies**
   - Network isolation: firewalld zone switch to full DROP
   - K3s: cordon + drain compromised node
   - Cloudflare: under-attack mode, IP block, disable Worker routes
   - OpenBao: revoke all leases from compromised host

---

## OUTPUT FORMAT

- Actionable recommendations with specific tool names, versions, and AlmaLinux 9 commands
- Decision matrices where trade-offs exist (not "it depends")
- Command examples for AlmaLinux 9 specifically (not generic RHEL)
- Priority labels: P0 (do now), P1 (before production), P2 (within 90 days), P3 (roadmap)
- Reference specific CIS control IDs, STIG rule IDs, SOC 2 criteria, ISO Annex A controls
- Architecture diagrams in ASCII/mermaid where helpful
- Separate output files: SKILL.md (core), reference.md (detailed), examples.md (commands)
