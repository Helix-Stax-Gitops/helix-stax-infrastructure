# Gemini Deep Research Results: Compliance Architecture Report

> **Date**: 2026-03-19
> **Source**: Gemini Deep Research
> **Scope**: FIPS 140-3, SOC 2, ISO 27001, HIPAA readiness for Helix Stax K3s infrastructure

## Key Findings Summary

### Critical Discoveries

1. **NetBird/WireGuard is FIPS-incompatible** — ChaCha20-Poly1305 is not NIST-approved. Must migrate to WolfGuard or strongSwan IPSec.

2. **K3s FIPS strict mode crashes** — `GODEBUG=fips140=only` panics on SHA-1 in K3s internals (Issue #13651). Use `GODEBUG=fips140=on` instead until patched.

3. **AlmaLinux FIPS requires TuxCare ESU** — AlmaLinux Foundation stops maintaining minor releases. Need commercial extended support to maintain validated FIPS boundaries.

4. **OpenBao lacks formal FIPS 140-3 validation** — FIPS-compliant image exists but CMVP certification on roadmap for 2028. Cannot satisfy strict federal mandates for secrets management.

5. **15-year Cloudflare Origin CA certs violate rotation principles** — Need cert-manager for automated certificate lifecycle management (ISO 27001 requirement).

6. **Hetzner cannot host PHI** — No BAA, no SOC 2. Healthcare client data must go to AWS/Azure/GCP.

7. **NIST CSF 2.0 covers 85%+ of SOC 2 + ISO 27001 + HIPAA** — Use it as the unifying framework.

### Tool Recommendations from Gemini

| Tool | Purpose | Priority | Frameworks |
|------|---------|----------|------------|
| **CISO Assistant** | Open-source GRC platform | Must-have | SOC 2, ISO 27001, HIPAA, NIST CSF |
| **Kyverno** | Policy-as-code (over OPA Gatekeeper) | Must-have | All |
| **External Secrets Operator** | Sync secrets from OpenBao to K8s | Must-have | All |
| **Velero** | K8s backup + disaster recovery | Must-have | SOC 2, HIPAA, ISO 27001 |
| **cert-manager** | Automated TLS certificate lifecycle | Must-have | ISO 27001 |
| **Linkerd** | Lightweight mTLS service mesh | Nice-to-have (Phase 2) | HIPAA, FIPS |
| **Tetragon** | eBPF runtime security | Nice-to-have (Phase 2) | SOC 2, ISO 27001 |
| **Cosign/Sigstore** | Container image signing | Future | SOC 2, ISO 27001 |
| **kube-bench** | CIS K8s benchmark scanner | Must-have | SOC 2, ISO 27001 |
| **WolfGuard or strongSwan** | FIPS-compliant VPN (replaces NetBird) | Must-have (if FIPS required) | FIPS 140-3 |

### Effort Estimates

| Phase | Hours | AI Agent Hours | Human Hours |
|-------|-------|---------------|-------------|
| Phase 0: Quick Wins (this week) | 10 | 8 | 2 |
| Phase 1: Foundation (this month) | 35 | 15 | 20 |
| Phase 2: Hardening (next month) | 40 | 25 | 15 |
| Phase 3: Audit-Ready (60-90 days) | 30 | 15 | 15 |
| Phase 4: Client Environments (when needed) | 45/client | 30 | 15 |
| **Total (Phases 0-3)** | **115** | **63** | **52** |

---

## Full Report

[See gemini-compliance-research-prompt.md for the complete 8-section report with detailed remediation steps, control mappings, and implementation roadmap]
