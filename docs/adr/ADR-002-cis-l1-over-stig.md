# ADR-002: CIS Level 1 over STIG for Host Hardening

## TLDR

Adopt CIS Benchmark Level 1 - Server as the baseline hardening profile for AlmaLinux 9.7, with selective Level 2 controls. No full STIG application.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax runs AlmaLinux 9.7 on Hetzner Cloud VPS nodes hosting a K3s cluster. The infrastructure must satisfy SOC 2 Type II, ISO 27001, and eventually HIPAA requirements. Two primary hardening frameworks exist for RHEL-family systems: DISA STIG (DoD-origin, CAT I/II/III severity) and CIS Benchmarks (consensus-based, Level 1/Level 2).

Both frameworks share substantial control overlap, but they differ in verification strictness. STIG requires explicit configuration file definitions where CIS permits reliance on system defaults. When automated remediation tools (OpenSCAP, Ansible `ansible-lockdown/RHEL9-CIS`) apply both profiles concurrently, configuration oscillation occurs -- controls from one profile overwrite the other in a loop.

Additionally, K3s requires several kernel and network settings that STIG explicitly prohibits: IPv4 forwarding (`net.ipv4.ip_forward=1`), bridge netfilter (`net.bridge.bridge-nf-call-iptables=1`), and dynamic iptables rule manipulation by the CNI. Full STIG compliance would break the cluster.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: CIS L1 + selective L2 | CIS Server L1 baseline, cherry-pick L2 controls | K3s compatible, auditor-accepted, automatable | Misses some STIG-specific DoD controls | Satisfies SOC 2, ISO 27001, HIPAA |
| **Option B**: Full STIG | Apply DISA STIG profile entirely | Maximum hardening depth | Config oscillation with CIS, breaks K3s networking, smartcard requirements irrelevant | Exceeds commercial compliance needs |
| **Option C**: CIS L2 full | Apply complete CIS Level 2 | Stronger than L1 | Host-level iptables restrictions conflict with K3s CNI | Satisfies all frameworks but operationally fragile |

---

## Decision

We will use CIS Benchmark Level 1 - Server (`xccdf_org.ssgproject.content_profile_cis_server_l1`) as the foundational hardening baseline, with selective Level 2 controls adopted where they do not conflict with K3s operations.

**Selective L2 controls adopted:**
- Disable IPv6 at kernel level
- Configure strict `tcp_wrappers`
- Enforce auditd immutability (`-e 2` flag)
- Blacklist obscure network protocols (DCCP, SCTP, RDS)

**L2 controls explicitly excluded:**
- Host-level iptables/firewalld state restrictions (K3s CNI requires dynamic rule manipulation)

**STIG controls explicitly excluded:**
- Smartcard authentication requirements (no DoD PKI)
- Strict FIPS mode (negative ROI for commercial compliance)
- Disabling IP forwarding (breaks K3s networking)

Ansible automation uses `ansible-lockdown/RHEL9-CIS` with K3s exceptions in `group_vars/all.yml`:

```yaml
rhel9cis_rule_3_1_1: false  # Allow IPv4 IP Forwarding
rhel9cis_rule_3_1_2: false  # Allow packet routing
rhel9cis_rule_3_2_2: false  # Allow ICMP Redirects
```

---

## Rationale

CIS L1 is universally accepted by SOC 2 and ISO 27001 auditors. STIG is designed for DoD environments with requirements (smartcard auth, strict FIPS) that provide no value for a commercial consultancy. Applying both profiles simultaneously causes configuration oscillation that degrades system stability. The selective L2 approach captures high-value defense-in-depth controls without triggering K3s incompatibilities.

---

## Consequences

### Positive

- Clean, automatable baseline with no configuration oscillation
- K3s cluster remains fully operational under hardened host
- OpenSCAP tailoring file documents all exceptions for auditors
- Ansible role provides idempotent remediation

### Negative

- Not STIG-compliant -- excludes DoD/FedRAMP customers until profile is expanded
- Selective L2 adoption requires manual curation and periodic review as CIS Benchmarks update
- K3s exceptions must be documented in OpenSCAP tailoring file and justified to auditors

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Create OpenSCAP tailoring.xml with K3s exceptions | Wakeem Williams | 2026-04-06 | TBD |
| Configure Ansible RHEL9-CIS role with group_vars | Wakeem Williams | 2026-04-06 | TBD |
| Address CIS L1 gaps: GRUB password, ASLR, cron.allow | Wakeem Williams | 2026-04-13 | TBD |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC6.3 | Logical access / secure configuration | CIS L1 enforces secure defaults across OS |
| ISO 27001 | A.8.8 | Management of technical vulnerabilities | Automated CIS scanning detects configuration drift |
| NIST CSF 2.0 | PR.IP-1 | Baseline configuration | CIS L1 profile provides auditable baseline |
| CIS Controls v8.1 | 4.1 | Establish and maintain secure configuration | Direct implementation via CIS Benchmark |
| HIPAA | 164.308(a)(1)(ii)(A) | Risk analysis | CIS profile addresses identified technical risks |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
