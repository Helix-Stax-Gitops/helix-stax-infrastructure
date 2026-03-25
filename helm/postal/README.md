# Postal — Helm Chart Research

## Status: No Helm Chart Available

**Research date**: 2026-03-25
**Conclusion**: Postal cannot be deployed via Helm chart at this time. A `values.yaml`
has not been created because no suitable chart exists. See alternatives below.

---

## Why No Helm Chart Exists

### No Official Chart

The Postal project has never published an official Helm chart. The only official
Kubernetes tooling was `postalserver/k8s-hippo`, a bespoke deployment orchestrator
that was **archived on 2024-03-12** and is now read-only.

GitHub discussion [#1825](https://github.com/postalserver/postal/discussions/1825)
documents why: configuring all outbound IP addresses, PTR records, SPF/DKIM, and
routing outgoing traffic to a fixed IP requires more than a Helm chart.

### No Maintained Community Chart

Two community charts were evaluated:

| Chart | Last Active | Stars | Verdict |
|-------|------------|-------|---------|
| `netg5/postal-kubernetes-email` | ~2022, no recent commits | 0 | Abandoned |
| `linkyard/postal-kubernetes` | v1/v2 era, pre-dates v3 image | Inactive | Incompatible |

Both predate the current `ghcr.io/postalserver/postal` official image (v3+) and
would require significant rework.

---

## Technical Blockers for In-Cluster Postal

Even if a chart existed, in-cluster Postal has unresolved infrastructure problems
for the Helix Stax architecture:

### 1. MariaDB Dependency

Postal requires **MariaDB** (MySQL-compatible), not PostgreSQL. The cluster runs
CloudNativePG exclusively. Deploying a bundled MariaDB adds:
- A separate stateful database to manage and back up
- No integration with existing CNPG backup tooling (Velero + MinIO)
- Additional storage class and PVC overhead on the forge node

### 2. Fixed Outbound IP Requirement

Transactional email deliverability depends on the sending IP having:
- A matching **PTR (reverse DNS) record** (`mail.helixstax.com` → IP → `mail.helixstax.com`)
- An **SPF record** listing the exact sending IP
- Consistent IP across all sends (no ECMP/NAT randomization)

Kubernetes pods do not have stable outbound IPs without additional egress
infrastructure (static SNAT, MetalLB with dedicated pool, or a dedicated egress
node). Hetzner Cloud assigns the node IP for outbound traffic, but this IP is
shared with all other cluster workloads.

### 3. Multi-Process Architecture

Postal runs three separate processes from a single image:
- `web` — Rails web UI and API
- `smtp` — SMTP server (receives inbound + relays outbound)
- `worker` — Background job processor (Faktory-backed)

Running these as separate Kubernetes Deployments sharing a config volume (mounted
`postal.yml` + `signing.key`) is possible but not documented and requires manual
coordination of the signing key secret.

### 4. Port Exposure

SMTP requires port 25/tcp exposed publicly. Exposing port 25 from a Kubernetes
cluster via Traefik requires a dedicated TCP IngressRoute, and Hetzner Cloud
**blocks port 25 by default** on Cloud servers. This requires a support ticket to
Hetzner to unblock, and the sending IP's reputation starts at zero.

---

## Recommended Alternatives

### Option A: Managed Transactional Email (Recommended for Phase 1-2)

Use an external SMTP relay that handles deliverability, IP reputation, and
compliance. Configure n8n and application services with SMTP credentials.

| Provider | Free Tier | Approx Cost | Notes |
|----------|-----------|-------------|-------|
| **Resend** | 3,000/mo | $20/mo (50k) | Developer-friendly, good API |
| **Postmark** | 100/mo trial | $15/mo (10k) | Transactional-focused, strong deliverability |
| **Brevo (Sendinblue)** | 300/day | Free up to 300/day | Good for low volume |
| **Amazon SES** | 62k/mo (EC2) | $0.10/1k | Cheapest at scale, more setup |

**Action**: Add SMTP credentials to OpenBao at `secret/email/smtp`. Configure
Rocket.Chat, n8n, and any application services to use the external relay.

No Kubernetes changes required.

### Option B: Self-Hosted Postal on Dedicated VM (Future)

Deploy Postal on a dedicated Hetzner Cloud CX11 or CX21 instance using the
official Docker Compose configuration. This VM:
- Gets its own dedicated IP with a PTR record
- Runs MariaDB locally without touching the K3s cluster
- Uses the official `ghcr.io/postalserver/postal` image
- Is managed by Ansible, not Helm

When ready, an Ansible role in `ansible/roles/postal/` would provision this VM.
The K3s cluster would reference it only as an SMTP relay host.

**When to pursue**: When sending volume exceeds managed provider costs, or when
full control over email queuing and bounce handling is required.

### Option C: Docker Mailserver on K3s (Alternative In-Cluster)

`docker-mailserver/docker-mailserver` has an actively maintained Helm chart
(`docker-mailserver/docker-mailserver-helm`). It uses Postfix/Dovecot rather than
Postal's Rails stack and does not require MariaDB. However, it still requires
resolving the fixed outbound IP and port 25 problems listed above.

This is only viable once the cluster has a dedicated egress IP arrangement.

---

## Current State

Transactional email for helixstax.com is not yet configured. Until Postal or an
alternative is deployed:
- n8n workflows should be configured with a managed SMTP provider (Option A)
- Rocket.Chat SMTP should use the same managed provider
- Zitadel email (account verification) should use the managed provider

---

## If/When Revisiting Postal on K3s

Prerequisites that must exist before a `values.yaml` can be written:

1. A Helm chart must exist — either community-contributed or written in-house
2. A MariaDB operator or bundled chart must be selected and integrated
3. A dedicated egress IP or static SNAT must be configured for the forge node
4. Hetzner must unblock port 25 on the relevant server IP
5. PTR record must be configured in Hetzner DNS or Cloudflare
6. Postal signing key must be generated and stored in OpenBao

Track this work as a Platform Engineering backlog item in ClickUp.

---

## References

- [Postal official image](https://docs.postalserver.io/other/containers/)
- [Postal prerequisites](https://docs.postalserver.io/getting-started/prerequisites/)
- [Helm chart discussion #1825](https://github.com/postalserver/postal/discussions/1825)
- [k8s-hippo (archived)](https://github.com/postalserver/k8s-hippo)
- [docker-mailserver Helm chart](https://github.com/docker-mailserver/docker-mailserver-helm)
