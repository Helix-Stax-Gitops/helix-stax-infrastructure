# ADR-009: Container Supply Chain Security

## TLDR

Implement a four-stage container supply chain pipeline: Harbor (scan + SBOM), Cosign (sign with OpenBao transit key), Kyverno (verify at admission), NeuVector (runtime behavioral monitoring).

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax deploys all workloads as containers on K3s. Without supply chain verification, the cluster is vulnerable to compromised base images, unpatched dependencies, unsigned artifacts, and runtime behavioral deviations. SOC 2 CC8.1 requires change management controls, and ISO 27001 A.8.8 requires vulnerability management for software components.

The container supply chain has four distinct trust boundaries:

1. **Build time**: Is the image free of known vulnerabilities?
2. **Attestation**: Can we prove who built it and that it has not been tampered with?
3. **Admission**: Should this image be allowed to run in the cluster?
4. **Runtime**: Is the running container behaving as expected?

Each boundary requires a dedicated tool. No single tool covers all four.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: Harbor + Cosign + Kyverno + NeuVector | Full 4-stage pipeline | Complete supply chain coverage, each stage independent | 4 tools to deploy and maintain | Full SOC 2 CC8.1, ISO 27001 A.8.8 |
| **Option B**: Harbor + Trivy only | Scan-only approach | Simple, single tool | No signing, no admission control, no runtime protection | Partial -- scanning without enforcement |
| **Option C**: Docker Content Trust | Docker-native signing | Built into Docker ecosystem | Deprecated approach, no K8s-native admission, no runtime | Weak compliance posture |
| **Option D**: Chainguard + Sigstore | Managed supply chain service | Pre-hardened images, managed signing | Vendor dependency, cost, limited custom image support | Strong but dependent on vendor |

---

## Decision

We will implement a four-stage container supply chain security pipeline:

**Stage 1 -- Vulnerability Scanning + SBOM (Harbor + Trivy):**
- All images pushed to Harbor are automatically scanned by the integrated Trivy scanner
- SBOM generated via Syft and attached to the image manifest
- Images with Critical/High CVEs are flagged; deployment policy prevents their use
- Scan results stored as Harbor artifacts for audit evidence

**Stage 2 -- Cryptographic Signing (Cosign):**
- Images passing vulnerability thresholds are signed with Cosign
- Signing key stored in OpenBao's transit secrets engine (never on disk)
- Signature attached to the OCI registry manifest in Harbor
- Cosign verification can be performed independently of Kyverno

**Stage 3 -- Admission Enforcement (Kyverno):**
- Kyverno ClusterPolicy enforces signature verification at pod admission
- `validationFailureAction: enforce` -- unsigned images are rejected, not just warned
- Policy applies to all images matching `harbor.helixstax.com/*/*:*`
- Pod Security Standards enforced via additional Kyverno policies

**Stage 4 -- Runtime Behavioral Monitoring (NeuVector):**
- NeuVector deployed in Discover mode initially, building behavioral profiles
- After profiling period, switched to Monitor mode (alert on deviations)
- Protect mode (block deviations) enabled after tuning to reduce false positives
- Zero-drift policy prevents runtime binary modifications

---

## Rationale

Each stage addresses a distinct trust boundary that the others cannot cover. Harbor+Trivy finds known vulnerabilities but cannot prevent unsigned images from deploying. Cosign proves provenance but cannot enforce policy at admission time. Kyverno blocks unsigned images but cannot detect runtime behavioral deviations. NeuVector monitors runtime behavior but cannot prevent a vulnerable image from being admitted. The four-stage pipeline provides defense in depth across the entire container lifecycle.

---

## Consequences

### Positive

- Complete container lifecycle security from build to runtime
- Cryptographic proof of image provenance via Cosign signatures
- Unsigned or vulnerable images cannot enter the cluster (Kyverno enforcement)
- Runtime behavioral monitoring detects zero-day exploits and container breakouts
- SBOM generation provides software inventory for compliance audits
- All signing keys managed by OpenBao -- no key material on developer machines

### Negative

- Four tools to deploy, configure, monitor, and maintain
- NeuVector requires a profiling period before Protect mode -- during this time, only alerting
- Cosign signing step adds time to CI/CD pipeline (~5-10 seconds per image)
- Kyverno admission webhook adds latency to pod creation (~50-200ms)
- Helm chart exceptions needed for privileged system pods (CrowdSec, NeuVector itself)
- False positives in NeuVector behavioral profiles require ongoing tuning

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Configure Harbor Trivy auto-scan policy | Wakeem Williams | 2026-05-11 | TBD |
| Set up Cosign with OpenBao transit key | Wakeem Williams | 2026-05-11 | TBD |
| Deploy Kyverno ClusterPolicy for image verification | Wakeem Williams | 2026-05-18 | TBD |
| Deploy NeuVector in Discover mode | Wakeem Williams | 2026-05-18 | TBD |
| Create CI/CD pipeline step for Cosign signing | Wakeem Williams | 2026-05-25 | TBD |
| Transition NeuVector from Discover to Monitor mode | Wakeem Williams | 2026-06-15 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| Harbor | Trivy scanning enabled, SBOM generation configured |
| OpenBao | Transit key created for Cosign signing |
| K3s API server | Kyverno admission webhook registered |
| Devtron CI pipeline | Cosign signing step added post-build |
| All deployed workloads | Subject to Kyverno admission and NeuVector monitoring |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC8.1 | Change management | Signed images with verified provenance |
| ISO 27001 | A.8.8 | Management of technical vulnerabilities | Trivy scanning detects CVEs before deployment |
| NIST CSF 2.0 | PR.DS-6 | Integrity checking mechanisms | Cosign signatures + Kyverno verification |
| HIPAA | 164.312(c)(1) | Integrity controls | Cryptographic signing prevents image tampering |
| CIS Controls v8.1 | 2.2 | Ensure authorized software is maintained | Kyverno admission rejects unauthorized images |
| NIST CSF 2.0 | DE.CM-7 | Monitor for unauthorized changes | NeuVector zero-drift runtime protection |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
