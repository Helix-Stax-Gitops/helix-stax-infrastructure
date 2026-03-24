# ADR-003: CrowdSec Replaces fail2ban

## TLDR

Replace fail2ban with CrowdSec for intrusion detection and automated IP banning, deployed as a dual-tier architecture across host and K3s.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax infrastructure requires automated intrusion prevention at both the host OS layer (SSH brute force, service abuse) and the Kubernetes ingress layer (application-layer attacks against web services). The existing fail2ban installation operates in isolation on each host, analyzing local log files and maintaining per-host ban lists with no shared intelligence.

As the cluster scales and Traefik handles increasing ingress traffic, the IDS must integrate with Kubernetes-native workloads and benefit from community threat intelligence. fail2ban's architecture -- single-threaded Python, local-only ban state, regex-based log parsing -- becomes a liability under volumetric attacks and provides no cross-node coordination.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: CrowdSec dual-tier | Host agent + K3s DaemonSet with Traefik bouncer | Go-based (low resource), global threat intel, K3s native | Newer project, smaller community than fail2ban | Satisfies SOC 2 DE.CM, ISO 27001 A.12.6 |
| **Option B**: Keep fail2ban | Continue existing fail2ban setup | Mature, well-documented, simple config | Python single-threaded, no shared intel, no K3s integration | Partial -- host only, no ingress coverage |
| **Option C**: Cloudflare WAF only | Rely entirely on Cloudflare edge protection | Zero host overhead, managed service | No protection for non-proxied traffic (.net domain), no host-level IDS | Incomplete -- misses host and internal traffic |

---

## Decision

We will deploy CrowdSec in a dual-tier architecture, fully replacing fail2ban:

**Tier 1 -- Host Level:**
- CrowdSec agent on each AlmaLinux node
- Monitors sshd, firewalld, and system logs
- firewalld bouncer applies bans at the OS firewall level
- Subscribes to CrowdSec Central API for global threat intelligence

**Tier 2 -- Kubernetes Level:**
- CrowdSec deployed as a DaemonSet in K3s
- Traefik bouncer middleware inspects ingress traffic
- Parses Traefik access logs for application-layer attack patterns
- Shares ban decisions with host-level agents via Local API

fail2ban will be removed from all nodes after CrowdSec is verified operational.

---

## Rationale

CrowdSec addresses every fail2ban limitation: it is written in Go (lower resource consumption under load), aggregates threat intelligence from a global community network, and provides first-class Kubernetes integration via DaemonSet and Traefik bouncer. The dual-tier model ensures coverage at both the OS and ingress layers, which fail2ban cannot achieve without significant custom scripting. Cloudflare WAF alone leaves the `.net` domain (grey-cloud, DNS-only) and internal cluster traffic unprotected.

---

## Consequences

### Positive

- Unified IDS covering both host OS and K3s ingress traffic
- Global threat intelligence blocks known-bad IPs before they attack
- Go-based engine handles volumetric attacks without resource exhaustion
- Traefik bouncer provides L7 protection for all ingress-routed services
- Ban state shared across nodes via Local API

### Negative

- Migration period requires running both CrowdSec and fail2ban temporarily
- CrowdSec Central API is a third-party dependency (can operate without it in degraded mode)
- Custom parsers needed for non-standard log formats
- Team must learn new tooling (cscli, scenario definitions, bouncer configuration)

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Install CrowdSec agent on heart and helix-worker-1 | Wakeem Williams | 2026-04-13 | TBD |
| Deploy CrowdSec DaemonSet + Traefik bouncer in K3s | Wakeem Williams | 2026-04-13 | TBD |
| Remove fail2ban from all nodes | Wakeem Williams | 2026-04-20 | TBD |
| Configure alerting to Rocket.Chat via n8n | Wakeem Williams | 2026-04-20 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| AlmaLinux hosts (heart, helix-worker-1) | CrowdSec agent replaces fail2ban |
| K3s cluster | CrowdSec DaemonSet added |
| Traefik | Bouncer middleware added to ingress chain |
| firewalld | CrowdSec bouncer manages ban rules |
| n8n | New webhook for CrowdSec alert notifications |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC7.2 | System monitoring | CrowdSec provides continuous intrusion detection |
| ISO 27001 | A.12.6.1 | Management of technical vulnerabilities | Automated blocking of known attack patterns |
| NIST CSF 2.0 | DE.CM-1 | Networks monitored for cybersecurity events | Dual-tier monitoring at host and ingress layers |
| CIS Controls v8.1 | 13.1 | Centralize security event alerting | CrowdSec Central API + local alert forwarding |
| HIPAA | 164.312(b) | Audit controls | CrowdSec logs all detection and ban events |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
