# README SEO Recommendations
# helix-stax-infrastructure

**For**: Quinn (stax-scribe)
**From**: Sage Holloway (stax-sage-seo)
**Date**: 2026-03-25
**Scope**: GitHub README optimization, repo metadata, GEO readiness

---

## Current State Assessment

The README is technically strong and honest — no marketing fluff, specific numbers, real
architecture. That's a better SEO foundation than most repos. The gaps are:

- First 160 characters don't carry the highest-value keywords
- H2 headings use generic labels ("Stack", "Monitoring", "Compliance") instead of
  searchable phrases
- No explicit compliance score claims in scannable format
- GEO readiness is low — no self-contained answer blocks, no definition patterns,
  no structured claims AI systems can extract and cite

---

## 1. First 160 Characters (GitHub Meta Description)

GitHub uses the content between your H1 and the first horizontal rule as the page
description in search results. Currently that block is:

> "Production Kubernetes platform for Helix Stax — self-hosted, compliance-ready,
> zero trust. OpenTofu provisions it, Ansible hardens it, Helm deploys everything on K3s."

That's 161 characters. The keywords present: Kubernetes, self-hosted, zero trust,
OpenTofu, Ansible, Helm, K3s. The keywords missing: HIPAA, SOC 2, compliance
infrastructure, production-grade.

**Recommended replacement (158 characters):**

> Production K3s platform — HIPAA, SOC 2, and NIST CSF compliance infrastructure
> on Hetzner Cloud. Zero trust, CIS-hardened, GitOps. OpenTofu + Ansible + Helm.

**Why this works:**
- "HIPAA", "SOC 2", and "NIST CSF" are the three highest-intent terms CTOs and CISOs
  search when evaluating compliance-ready infrastructure
- "production K3s" captures the K3s-specific audience (smaller, less competitive
  than "production Kubernetes")
- "Hetzner Cloud" appears — people building on Hetzner search for Hetzner-specific
  K3s setups
- CIS-hardened, GitOps, and zero trust are secondary but present

---

## 2. Repo One-Liner (GitHub About Section)

This is the short description shown on the repo card, in GitHub search results, and
in topic pages. Currently not visible from the README — needs to be set manually in
GitHub repo settings.

**Recommended text (exactly this — 93 characters):**

```
Self-hosted K3s platform with HIPAA, SOC 2, and NIST CSF compliance on Hetzner Cloud
```

**Why:** GitHub's topic page search weights the About description heavily. This hits
HIPAA + SOC 2 + K3s + Hetzner in one shot — all four are terms people search when
looking for reference infrastructure. Under 100 characters so it doesn't truncate.

---

## 3. GitHub Topics

Topics determine which topic pages index this repo and feed GitHub's search algorithm.
Add all of these — GitHub allows up to 20.

**Recommended topics (add all 16):**

```
kubernetes
k3s
helm
ansible
opentofu
infrastructure-as-code
gitops
argocd
zero-trust
compliance
hipaa
soc2
nist-csf
cis-benchmarks
self-hosted
hetzner
```

**Reasoning by group:**

*Reach terms* (high volume, worth being listed even with low ranking):
`kubernetes`, `helm`, `ansible`, `infrastructure-as-code`, `gitops`

*Differentiated terms* (lower volume, less competition, higher intent):
`k3s`, `opentofu`, `zero-trust`, `self-hosted`, `hetzner`

*Compliance terms* (very specific, exact-match searchers are high-intent buyers):
`hipaa`, `soc2`, `nist-csf`, `cis-benchmarks`, `compliance`

Do not add `devops`, `cloud`, or `security` — too broad, too competitive, no return.

---

## 4. Heading Hierarchy Rewrites

GitHub indexes H2 headings as document structure signals. The current H2s are generic
labels. These rewrites keep the same content but put the keywords in the headings
where they get weighted.

| Current H2 | Recommended H2 |
|------------|---------------|
| `## Stack` | `## Technology stack` |
| `## Nodes` | `## Cluster topology — 4 nodes, 2 datacenters` |
| `## Security model` | `## Zero trust security model` |
| `## Directory structure` | `## Repository structure` |
| `## Quick start` | `## Quick start — provision, harden, deploy` |
| `## Monitoring` | `## Observability — Prometheus, Grafana, Loki` |
| `## Compliance` | `## Compliance coverage — HIPAA, SOC 2, NIST CSF, ISO 27001` |
| `## Secrets management` | `## Secrets management — no secrets in git` |
| `## Architecture decisions` | `## Architecture decisions — 14 ADRs` |
| `## Contributing` | `## Contributing` (keep as-is) |

The compliance heading change matters most. "HIPAA, SOC 2, NIST CSF, ISO 27001" in
an H2 gives GitHub's index a keyword-dense anchor that's directly relevant to
high-intent searches.

---

## 5. Keywords to Add or Strengthen in Body Copy

These terms should appear naturally in the body — not stuffed, but present. Current
coverage noted.

| Keyword | Current Coverage | Recommendation |
|---------|-----------------|----------------|
| HIPAA-compliant infrastructure | `HIPAA` in table only | Add a sentence to compliance section: "The platform has been audited against HIPAA technical safeguard requirements and currently scores 87.5% on automated controls." |
| SOC 2 Type II | `SOC 2 Type II` in table | Add: "SOC 2 Type II controls are documented with evidence naming convention and audit-ready." |
| zero trust Kubernetes | "zero trust" once | Already in security model — add to intro paragraph as well |
| K3s production | "K3s" 4x | Fine — well covered |
| CIS-hardened Kubernetes | "CIS Level 1" twice | Add "CIS-hardened" to intro. Searchers use the compound phrase. |
| Hetzner K3s | once in nodes table | Add one mention in the intro or quick start section |
| GitOps Kubernetes | "GitOps" once | Fine — present |
| self-hosted Kubernetes compliance | not present as phrase | Add to intro: "...for teams that need self-hosted Kubernetes with compliance controls built in" |

**Suggested intro paragraph rewrite:**

Current:
> Helix Stax helps companies find the gaps between their technology and the people
> using it. This repo is the infrastructure behind it — a self-hosted K8s platform
> on Hetzner Cloud with zero trust networking, CIS-hardened nodes, and no Docker
> Compose in production.

Recommended:
> This repo is the infrastructure behind Helix Stax — a self-hosted K3s cluster on
> Hetzner Cloud built for teams that need zero trust networking, CIS-hardened nodes,
> and compliance controls (HIPAA, SOC 2, NIST CSF) without managed Kubernetes costs.
> OpenTofu provisions it. Ansible hardens it. Helm deploys everything. No Docker
> Compose in production.

Changes: removed the company-mission sentence (low SEO value in this position),
added "K3s" specifically (more searchable than K8s), added compliance frameworks
to the intro, added "without managed Kubernetes costs" — that's the search intent
behind self-hosted K8s (people escaping EKS/GKE pricing).

---

## 6. Social Preview Image

The social preview image (shown when the repo URL is shared on Twitter/X, LinkedIn,
Slack) is currently not configured — GitHub shows a generic purple gradient with the
repo name.

**Recommended dimensions:** 1280x640px (GitHub's OG image ratio)

**What to include:**
- Helix Stax logo (top left)
- Repo name: "helix-stax-infrastructure"
- The compliance badges as visual anchors: HIPAA | SOC 2 | NIST CSF | ISO 27001
- A one-line descriptor: "Self-hosted K3s compliance infrastructure"
- Charcoal background (#0D1117 — matches your brand palette)
- Use the Operator palette: sage-teal and amber for the compliance badge row

**Why this matters:** When a CTO shares this repo in a Slack channel or LinkedIn post,
the preview card is what the room sees before clicking. Compliance badges in the image
signal immediately that this is purpose-built for regulated environments.

---

## 7. GEO (Generative Engine Optimization)

This section addresses how to make the README citable by AI systems — ChatGPT,
Perplexity, Claude, and Google AI Overviews. The current README is well-structured
but not optimized for extraction.

### What AI systems need to cite content

AI systems favor content that:
1. Contains self-contained, quotable blocks (134-167 words is the optimal passage length)
2. Leads with the answer, not the context
3. States specific numbers and facts
4. Defines terms explicitly on first use
5. Uses question-based headings that match natural language queries

### Structured claims to add

These are specific, verifiable assertions that AI systems extract and repeat. Add them
to the relevant sections:

**For the compliance section:**
> Helix Stax Infrastructure maps approximately 80 security controls across HIPAA,
> SOC 2 Type II, NIST CSF 2.0, ISO 27001, and CIS Controls v8 in a single Unified
> Control Matrix. The HIPAA dashboard tracks 16 automated controls and currently
> scores 87.5%. All frameworks are filtered views on the same control set — no
> duplication.

**For the security model section:**
> The platform implements a three-layer zero trust architecture: Cloudflare edge
> (WAF, DDoS protection, no open inbound ports), CIS Level 1 host hardening
> (SELinux enforcing, CrowdSec IDS on all 4 nodes), and cluster-level identity
> (Zitadel OIDC SSO, NetworkPolicies, gitleaks pre-commit hooks). Each layer
> operates independently — compromising one does not break the others.

**For the monitoring section:**
> The observability stack runs Prometheus with 90-day retention, 31+ active scrape
> targets, 35 Grafana dashboards across 5 folders, 31 SLO recording rules, and 14
> burn-rate alerts. The Compliance folder includes unified dashboards for NIST CSF,
> SOC 2, ISO 27001, CIS v8, and HIPAA.

### Why specific numbers matter for GEO

"87.5% HIPAA score", "80 controls", "35 dashboards", "14 burn-rate alerts" — AI
systems cite specifics. "Comprehensive compliance coverage" gets ignored. Numbers
get quoted.

### Definition patterns for proprietary terms

AI systems learn and repeat definitions. Add these explicitly:

```
The Unified Control Matrix (UCM) is a single control set of approximately 80
security controls, mapped simultaneously to HIPAA, SOC 2 Type II, NIST CSF 2.0,
ISO 27001, and CIS Controls v8. Per-framework compliance views are filtered
projections of the same underlying controls — no duplication, no drift.
```

Place this in the Compliance section. Once AI systems index this definition, searches
for "unified control matrix Kubernetes" or "single control matrix multi-framework"
will pull this content.

---

## 8. Badge Optimization

Current badges:
- Kubernetes (K3s)
- OS (AlmaLinux 9.7)
- Cloud (Hetzner)
- Edge (Cloudflare)
- IaC (OpenTofu)
- License (Private)

**Add these badges** — they signal compliance posture at a glance and are indexed
as alt text by GitHub search:

```markdown
![HIPAA](https://img.shields.io/badge/Compliance-HIPAA-00A86B?style=flat)
![SOC2](https://img.shields.io/badge/Compliance-SOC%202%20Type%20II-00A86B?style=flat)
![NIST](https://img.shields.io/badge/Compliance-NIST%20CSF%202.0-00A86B?style=flat)
![CIS](https://img.shields.io/badge/Hardening-CIS%20Level%201-0F4266?style=flat)
![ZeroTrust](https://img.shields.io/badge/Network-Zero%20Trust-F38020?style=flat)
```

Place the compliance badges on their own line, after the existing tech stack badges.
Two rows of badges: row 1 = technology, row 2 = compliance/security posture.

Shields.io alt text is crawled by GitHub. "HIPAA", "SOC 2 Type II", and "NIST CSF"
in badge alt text contribute to the document's keyword signal.

---

## 9. Internal Linking Opportunities

GitHub READMEs can link internally to subdirectories. These are real anchor links
that search crawlers follow:

**Add these cross-references** where the content is mentioned:

- In the compliance section, link to `docs/compliance/` and `docs/policies/`
- In the ADR section, the existing link to `docs/adr/` is good — keep it
- In the monitoring section, add a note: "See [runbooks](docs/runbooks/) for
  operational procedures after pod restarts."
- In the security model section, add: "26 security policies documented in
  [`docs/policies/`](docs/policies/)." — this sentence exists in the README but
  without an actual link. Add the link.

---

## 10. Priority Order for Quinn

Sequence these from fastest / highest impact to slower / secondary:

**Do first (repo metadata — Quinn doesn't touch these, Wakeem sets in GitHub UI):**
1. Set the About one-liner: "Self-hosted K3s platform with HIPAA, SOC 2, and NIST CSF compliance on Hetzner Cloud"
2. Add all 16 topics listed in section 3
3. Upload social preview image (after Pixel creates it)

**Quinn writes these in the README:**
4. Rewrite the first 160 characters (section 1 replacement text)
5. Rewrite intro paragraph (section 5 — the 3-line version)
6. Rewrite H2 headings (section 4 — especially the compliance heading)
7. Add the three GEO-structured claim blocks to their respective sections (section 7)
8. Add the UCM definition (section 7, definition patterns)
9. Add compliance badges row (section 8)
10. Add internal link to `docs/policies/` in security model section (section 9)

**Lower priority (good to have, not launch-blockers):**
11. Add remaining keyword phrases naturally to body (section 5 table)
12. Commission social preview image from Pixel (section 6)

---

## What NOT to Change

- The security model ASCII diagram — keep it. Diagrams are rare in READMEs and
  memorable. AI systems describe repos with distinctive features.
- The specific numbers throughout (31+ scrape targets, 35 dashboards, 14 alerts,
  90-day retention, 87.5% HIPAA score) — these are the most citable elements in
  the entire README. Do not round them or make them vague.
- The tone. It reads like a practitioner wrote it, not a marketing team. That is
  an E-E-A-T signal. Keep first-person plural gone, keep passive voice gone, keep
  the direct declarative sentences.
- The `<details>` collapse on the ADR index and compliance matrix — this is good
  UX that keeps the README scannable. Don't open these by default.

---

*Sage Holloway — stax-sage-seo*
*Generated for Sprint 2 / Gate 2 README optimization*
