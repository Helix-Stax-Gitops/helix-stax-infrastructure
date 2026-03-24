# Cloudflare Audit Prompt — Review

**Reviewed by**: stax-preparer (Remy Alcazar)
**Date**: 2026-03-23
**Prompt file**: `00-cloudflare-full-audit-prompt.md`

---

## 1. Completeness — Missing Products

The prompt's product list is thorough but has a few gaps from 2025 Birthday Week and AI Week announcements:

**Missing from Developer Platform section:**
- **Email Service** (new, 2025) — Send email directly from Workers with native bindings. Distinct from Email Routing (receive/forward). Relevant: transactional email from n8n workflows, agent notifications. The prompt covers Email Routing and Email Workers but not this new unified send+receive binding.
- **R2 SQL** (2025) — Serverless ad-hoc query engine over R2 Data Catalog (Iceberg tables). The prompt lists "R2 Data Catalog" and "R2 SQL" separately — both are present, so this is fine. Verified.
- **Cloudflare Data Platform** — Listed in the prompt? No. The prompt lists R2 Data Catalog and R2 SQL individually but not the overarching "Data Platform" suite (Pipelines + R2 Data Catalog + R2 SQL packaged together). Worth naming explicitly so Gemini understands it as a product family.
- **AI Index** (2025) — AI-optimized search indexing with built-in MCP server. Not in the prompt. High relevance: helixstax.com website + AI agents doing content retrieval.
- **AI Crawl Control** (formerly AI Audit) (2025) — Controls how AI crawlers index your content (block/allow by crawler, set 402 responses). Not in the prompt under Security or Other. Highly relevant for helixstax.com.
- **Replicate** (acquired Nov 2025) — Open-source ML model hosting/fine-tuning via API. Cloudflare acquisition. May be relevant as a Workers AI complement for fine-tuned models. Worth a mention in the audit.
- **Workers VPC** — Listed in the prompt under Developer Platform. Verified present.
- **VibeSDK** — Open-source vibe coding platform. Probably too niche for this audit; skip.
- **Cap'n Web** — RPC protocol. Edge case; skip.
- **Content Signals Policy** — Relevant for the helixstax.com website if Wakeem publishes CTGA framework content and wants to control AI training use. Worth a one-line mention.
- **Smart Shield** — Listed under Performance ("Speed, Auto Minify, Early Hints..."). Not explicitly named. The prompt groups it loosely under Speed but Smart Shield is its own product (application performance + security overlay). Worth naming explicitly.
- **Media Transformations** — Image/video transformations GA. The prompt covers Images and Stream but not Media Transformations as a distinct product. Add to the list.
- **Observatory** — Cloudflare's built-in web performance testing tool (uses Lighthouse). Relevant for the helixstax.com website launch. Not in the prompt.

**Missing from Zero Trust section:**
- **Post-Quantum WARP / PQC** — The prompt mentions WARP but does not call out Cloudflare One's post-quantum encryption (now live for SASE). Worth asking Gemini about for a forward-looking infra.

**Missing from Other/Specialized section:**
- **Cloudflare for AI** (Firewall for AI / LLM protection) — Prompt injection defense, PII detection in LLM traffic. Not in the prompt. Extremely relevant: 23 agents making LLM calls.
- **AI Gateway's newer features**: The prompt mentions AI Gateway but doesn't call out its "Firewall for AI" (prompt injection, sensitive data detection) capabilities that launched in 2025. Ask Gemini to cover these.

**Already present and verified:**
- Containers, Durable Objects, Queues, Pipelines, Pub/Sub, Workflows, Vectorize, AutoRAG, Agents SDK, Browser Rendering — all listed.
- Cloudflare Tunnel, Spectrum, Magic Transit, Magic WAN, Magic Firewall — all listed.
- CASB, DLP, DEX, Browser Isolation, Email Security/Area 1 — all listed.

**Net verdict**: Add ~8 products to the list. Not a major gap — Gemini should still catch most of these from context, but naming them explicitly gets better audit coverage.

---

## 2. Accuracy — "Current Setup" Section

Cross-checked against `CLAUDE.md` and `helix-stax-infrastructure/CLAUDE.md`:

**Accurate:**
- Zitadel as identity provider — correct (CLAUDE.md updated 2026-03-20 confirms Zitadel, NOT Authentik).
- CloudNativePG for PostgreSQL — correct.
- Valkey (not Redis) — correct.
- Devtron + ArgoCD — correct.
- Harbor for container registry — correct.
- MinIO for object storage — correct.
- OpenBao for on-cluster secrets — correct.
- Rocket.Chat (not Telegram) — correct.
- CrowdSec IDS — listed in infra CLAUDE.md, not mentioned in the prompt. Not an inaccuracy but a gap in the "current setup" description.
- Velero for backups — listed in infra CLAUDE.md, not mentioned in the prompt. Same.
- Backstage (Phase 3+) and Outline — both in infra CLAUDE.md, not in the prompt. OK to omit since they're not deployed yet.

**Inaccuracy found — Node IPs swapped:**
The prompt states:
> "2-node K3s cluster (CP: 178.156.233.12, Worker: 138.201.131.157)"

Both CLAUDE.md files confirm:
- `heart` = Control Plane = **178.156.233.12**
- `helix-worker-1` = Worker = **138.201.131.157**

This matches the prompt. No swap. Verified correct.

**Inaccuracy found — Workers KV for secrets:**
The prompt says "secrets-vault: Workers KV-backed credential store for all platform secrets." The project also uses OpenBao on-cluster for secrets. The prompt presents Workers KV as if it's the primary/sole secrets backend. This may mislead Gemini into recommending a Cloudflare-only secrets strategy when the actual architecture is hybrid (OpenBao on-cluster + Workers KV at edge). Suggest adding a clarifying note: "Workers KV handles edge/agent secrets; OpenBao on-cluster handles K3s workload secrets."

**Minor omission:**
The prompt doesn't mention CrowdSec (IDS) or Velero (backups) in the infrastructure list. Relevant because Gemini might recommend Cloudflare products that overlap with CrowdSec (e.g., Bot Management, DDoS). Worth adding so Gemini can give more targeted "use this instead of / alongside CrowdSec" verdicts.

**Cert-manager note:**
The infra CLAUDE.md lists `cert-manager` in the architecture diagram but the main CLAUDE.md says "NO cert-manager, NO Let's Encrypt." The infra file was updated 2026-03-20 and appears to reflect a new direction. The prompt correctly states Cloudflare Origin CA with no cert-manager. If cert-manager was added back, the prompt should be updated before pasting. Verify current state before submitting.

---

## 3. MCP Coverage

**Official server count:** The prompt claims 15 official CF MCP servers. The GitHub repo (`cloudflare/mcp-server-cloudflare`) confirms exactly 15. The count is correct.

**The prompt is missing one significant repo:** `github.com/cloudflare/mcp` is a SEPARATE repository from `mcp-server-cloudflare`. It's a token-efficient MCP server for the ENTIRE Cloudflare API (~2,500 endpoints, ~1,069 tokens via "Code Mode"). This is essentially the "Cloudflare Admin MCP" that the prompt says Wakeem is planning to build. Wakeem should know this already exists. This is a HIGH-VALUE finding — building a custom CF Admin MCP from scratch when Cloudflare already published one is wasted effort.

**Recommended addition to the prompt:**
> "Note: Cloudflare also published `github.com/cloudflare/mcp` — a separate token-efficient server covering all ~2,500 API endpoints (DNS CRUD, tunnel management, Zero Trust app config, SSL/TLS settings) via Code Mode. Please evaluate whether this covers my planned 'Cloudflare Admin MCP' use case before I build custom."

**Community MCP servers:**
A GitHub topic search (`cloudflare-mcp`) found ~15 community repos. None are production-grade Cloudflare management tools — they're demos (booking tennis courts, rickroll generators, TV episode summarizers). No community CF MCP server is worth adding to the prompt or agent ecosystem. The official `cloudflare/mcp` repo is the only meaningful finding here.

**AI Index MCP server:** Cloudflare's AI Index product (2025) ships with its own MCP server for AI-optimized search. Not mentioned in the prompt's MCP table. Worth noting.

---

## 4. Questions Quality

The 12 questions are well-targeted. A few additions and adjustments worth considering:

**Strong as-is:**
- Q1 (Tunnels vs Proxied DNS) — Right question for a K3s+Traefik setup.
- Q3 (Zero Trust for solo founder) — Critical. Well scoped.
- Q4 (Email security stack) — Exact DNS records request is smart; Gemini should produce copy-paste records.
- Q7 (AI Gateway) — High value for an agent platform.
- Q9 (Hyperdrive for PostgreSQL) — Specific and actionable.
- Q12 (What am I doing wrong?) — Good forcing function for Gemini to surface non-obvious risks.

**Suggested additions:**

**Q13: Cloudflare vs CrowdSec**
> "I run CrowdSec IDS on-cluster for bot/threat detection. Where does it overlap with Cloudflare Bot Management, WAF custom rules, and DDoS protection? Should I keep both, replace CrowdSec with CF tools, or use them in a layered way?"

This question is missing and the overlap is non-trivial for a solo founder managing two security layers.

**Q14: Agent-to-Worker authentication at scale**
> "I have 23 AI agents calling Workers endpoints (MCP servers). Currently using Cloudflare Zero Trust service tokens. As I add more agents and eventually client-facing agents, what's the right auth model? Service tokens per agent? WARP device posture? mTLS? Cloudflare Access for Infrastructure?"

Q3 covers WARP for personal device. Q11 touches MCP endpoint protection. But neither covers the specific agent-to-Worker auth pattern at scale. This is architecturally distinct.

**Q15: Cloudflare Firewall for AI / LLM Protection**
> "I route LLM calls through Workers. Cloudflare AI Gateway now includes prompt injection detection and PII scrubbing. Should I enable these for my agent traffic? What are the false positive risks for agentic workloads?"

The prompt asks about AI Gateway in Q7 but doesn't specifically call out the Firewall for AI features. This is worth a dedicated question given 23 agents making LLM calls.

**Q2 adjustment — mention `cloudflare/mcp` repo:**
After confirming the CF Admin MCP exists, Q8 (MCP Server Strategy) should ask Gemini to evaluate it: "Is `github.com/cloudflare/mcp` sufficient for my Cloudflare Admin MCP needs, or should I build custom?"

**Q10 (Cost Optimization) is slightly weak:**
It asks for "best ROI for solo founder" which is good, but should specify: "Assume I will eventually onboard 3-5 consulting clients needing isolated Zero Trust access to their environments. Does this change the tier recommendation?" Without this, Gemini may optimize for solo use only.

---

## 5. Prompt Engineering Assessment

**Length:** The prompt is ~1,700 words. Gemini Deep Research handles prompts up to ~32K tokens; this is well within limits. Do not split.

**Structure:** Well-structured with clear sections, tables, and numbered questions. Gemini Deep Research responds well to this format.

**The "AUDIT EVERY CLOUDFLARE PRODUCT" section:**
Listing 117+ products inline as a comma-separated paragraph is harder for Gemini to track than a bulleted or table format. Products listed in dense prose (e.g., "Speed (Auto Minify, Early Hints, HTTP/2, HTTP/3, 0-RTT, Brotli), Rocket Loader, Polish, Mirage...") will likely cause some products to be skipped or grouped together in Gemini's output. Consider breaking each major category into a proper bulleted list so each product gets individual audit treatment.

**The output format request:**
Requesting "complete product audit table (all 117+ products with verdicts)" + "architecture diagram" + "MCP integration plan" + "implementation roadmap" + "cost breakdown" in one response may cause Gemini to truncate the product table. The product audit is the most valuable output. Suggest deprioritizing the architecture diagram (Gemini produces poor ASCII diagrams anyway) and noting "the product audit table takes priority; other sections can be brief."

**"117+ products" claim:**
The actual count across all categories in the prompt is approximately 95-100 products when counted individually (some categories lump sub-products together, e.g., "HTTP/2, HTTP/3, 0-RTT" counted as one Speed product vs. three). Setting expectations at "100+" is more accurate. Using "117+" may cause Gemini to pad with non-products to hit the count.

**One structural improvement:**
Move the "Known issues from a recent security audit" section to AFTER the product list, not before. Currently it introduces conclusions before the audit context. Better flow: (1) setup, (2) full product list, (3) known issues, (4) deep-dive questions. This prevents Gemini from anchoring its audit on the known issues list and missing things that aren't already flagged.

---

## Summary of Changes to Make Before Submitting

| Priority | Change | Effort |
|----------|--------|--------|
| HIGH | Add note about `github.com/cloudflare/mcp` to MCP section and Q8 | 3 lines |
| HIGH | Clarify secrets architecture (Workers KV = edge secrets; OpenBao = cluster secrets) | 1 line |
| HIGH | Add Cloudflare Firewall for AI / LLM protection to Security section and Q15 | 2 lines |
| MEDIUM | Add AI Crawl Control, Email Service, AI Index, Smart Shield, Observatory, Content Signals Policy, Media Transformations to product list | 7 lines |
| MEDIUM | Add Q13 (CrowdSec vs CF security tools), Q14 (agent auth at scale) | 4 lines |
| MEDIUM | Move "Known issues" section after product list | reorder |
| LOW | Reformat dense product categories into bullet lists | formatting |
| LOW | Change "117+" to "100+" or remove the count entirely | 1 word |
| LOW | Add "assuming 3-5 future clients" context to Q10 | 1 sentence |
| LOW | Add post-quantum WARP callout to Zero Trust section | 1 line |
| LOW | Deprioritize architecture diagram in output format request | 1 sentence |
| LOW | Add CrowdSec and Velero to infrastructure list | 1 line |
| VERIFY | Confirm cert-manager is NOT in use before submitting | check infra CLAUDE.md |

---

## One High-Value Finding to Act On Immediately

The `github.com/cloudflare/mcp` repo is the "Cloudflare Admin MCP" Wakeem plans to build. It covers DNS CRUD, tunnel management, Zero Trust app config, SSL/TLS — the exact gap called out in the prompt. Evaluate this before starting any custom build. At minimum, ask Gemini to evaluate it as part of Q8.

---

HANDOFF:
1. Produced: `docs/gemini-skill-prompts/00-cloudflare-prompt-review.md`
2. Key decisions: Confirmed 15 official CF MCP servers (count is correct). Found `cloudflare/mcp` as a 16th distinct repo covering admin operations — high-value finding. Verified product list has ~8 gaps from 2025 announcements. Verified accuracy of current setup section with one meaningful clarification needed (secrets architecture dual-backend).
3. Reasoning chain: Read the prompt, fetched the GitHub repo directly for server count verification, fetched Cloudflare products page and Birthday Week 2025 announcements for gap analysis, searched GitHub topics for community MCP servers.
4. Areas of uncertainty:
   - [MEDIUM] cert-manager status — infra CLAUDE.md (updated 2026-03-20) includes cert-manager in architecture diagram, contradicting "NO cert-manager" in main CLAUDE.md. Verify before submitting prompt.
   - [LOW] Exact product count (95 vs 117) — Cloudflare doesn't publish an official numbered catalog. The "117+" figure is an estimate. Low risk since Gemini will audit what's listed.
5. Integration points: None — this is a documentation review only.
6. Open questions: Is cert-manager currently deployed or not? This affects one line in the prompt's current setup section.
