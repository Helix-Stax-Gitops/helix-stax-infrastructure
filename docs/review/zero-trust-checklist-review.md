# Zero Trust Getting Started Checklist — Security Review

**Reviewer**: Ezra Raines (stax-security-engineer)
**Date**: 2026-03-23
**Source**: Cloudflare Zero Trust dashboard "Getting Started" checklist
**Context**: WARP enrolled, secrets-vault Worker live with JWT auth, server rebuild imminent

---

## Timing Decision: Before or After Server Rebuild?

The server rebuild (new Hetzner US-region VPS, fresh AlmaLinux 9.7, K3s from scratch) changes the attack surface significantly. Items are categorized accordingly:

| Timing | Rationale |
|--------|-----------|
| **BEFORE rebuild** | Items that protect the workstation, the Cloudflare account, and the rebuild process itself |
| **AFTER rebuild** | Items that depend on running services, production traffic, or K3s being operational |
| **EITHER** | Items that are account-level config and independent of server state |

---

## Item 1: Add a DNS Location

**Dashboard text**: "Map DNS endpoints to physical locations to apply DNS policies"

**Recommendation**: LATER (after rebuild)

**What it does**: DNS Locations in Cloudflare Gateway map a source IP or DNS-over-HTTPS endpoint to a physical location (e.g., "Wakeem Workstation", "Hetzner US VPS"). Gateway DNS policies then apply per-location -- you can block malware DNS for the VPS but allow it for a test lab, for example.

**Why LATER**:
- DNS Locations require knowing the egress IPs of the devices you want to protect. The VPS does not exist yet (new IPs after rebuild).
- WARP-enrolled devices already route DNS through Gateway by default. A DNS Location is only needed for devices that cannot run WARP (the K3s nodes, IoT, network gear).
- After rebuild, the K3s nodes will have stable IPs. Create a DNS Location for them then.

**What phase**: Phase 2 (post-K3s deployment), when you configure Gateway DNS filtering for the cluster nodes.

**Security implications of skipping NOW**: Minimal. WARP-enrolled workstation already gets Gateway DNS filtering. The servers being rebuilt do not exist yet. Once K3s nodes are live and NOT running WARP, they will resolve DNS without Gateway filtering -- that is when this becomes important.

**Action when ready**:
1. Zero Trust Dashboard > Gateway > DNS Locations > Add Location
2. Name: "Hetzner US Cluster"
3. Source IP: the new VPS egress IP(s)
4. Optionally configure a DNS-over-HTTPS endpoint for the nodes
5. Then create Gateway DNS policies that reference this location

---

## Item 2: Manage Device Enrollment Permissions

**Dashboard text**: "Define who can connect devices to your organization"

**Recommendation**: DONE -- verify configuration is correct

**Current state**: WARP enrollment policy created via API. Verify:
- Only `KeemWilliams` GitHub identity (or `admin@helixstax.com` email) can enroll devices
- No wildcard enrollment rules (e.g., "allow any email from `*`")
- Enrollment requires authentication (not "allow all")

**Verification steps**:
```
Zero Trust Dashboard > Settings > WARP Client > Device enrollment permissions
```

Confirm:
- Rule type: Allow
- Selector: specific identity (GitHub username or email), NOT "everyone"
- No additional Allow rules that are overly broad

**SECURITY FINDING: MEDIUM -- Verify no "Everyone" enrollment rule exists**

If an "Everyone" or "Any valid identity" enrollment rule exists alongside your specific rule, any person who can authenticate via any configured IdP can enroll a device in your Zero Trust org. This grants them Gateway DNS filtering, and -- depending on Access policies -- potentially access to tunneled services via device posture checks.

**Remediation**: Ensure exactly one enrollment rule exists, scoped to your identity only. Delete any broader rules.

---

## Item 3: Issue Root CA Certificates for Your Account

**Dashboard text**: "Install device certificates to apply advanced security features"

**Recommendation**: NOW (before rebuild)

**What it does**: Cloudflare generates a root CA certificate unique to your Zero Trust account. You install it on enrolled devices. This enables:
1. **TLS inspection (HTTP policy)**: Gateway can decrypt, inspect, and re-encrypt HTTPS traffic to detect malware, data loss, and policy violations in encrypted traffic
2. **Block-by-SNI enforcement**: Without the CA, Gateway can only see the SNI (hostname) of HTTPS requests, not the full URL path or request body
3. **Device posture verification**: The installed certificate proves the device is managed and compliant

**Why NOW (before rebuild)**:
- Your workstation is where Claude Code agents run. Those agents hit external APIs (OpenAI, Anthropic, GitHub, ClickUp). TLS inspection lets Gateway enforce policies on what data leaves your machine.
- The secrets-vault Worker is accessed from your workstation. With TLS inspection, you can create an HTTP policy that logs all requests to `secrets-vault.helixstax.workers.dev` -- giving you an audit trail of which secrets were accessed and when.
- Installing the CA on the workstation takes 5 minutes and has zero dependency on the server rebuild.
- After rebuild, you install the same CA on K3s nodes if you want Gateway HTTP inspection on cluster egress traffic.

**Security implications of skipping**:
- **No TLS inspection**: Gateway sees only DNS queries and SNI hostnames, not full URLs or request bodies. A malicious dependency could exfiltrate data via HTTPS POST to a domain that looks benign (e.g., `analytics.legit-looking.com`) and Gateway would not see the payload.
- **Weaker device posture**: Without the CA cert, device posture checks are limited to "WARP is connected." With it, you can verify "WARP is connected AND device has the org CA installed" -- a stronger signal that the device is managed.
- **No HTTP policies**: The "Bypass inspection for TLS-incompatible applications" item (Item 6) is meaningless without this. You cannot bypass what you have not enabled.

**Implementation steps**:

1. Zero Trust Dashboard > Settings > WARP Client > Certificates
2. Click "Download certificate" (or use the API)
3. Install on Windows:
   ```
   # Double-click the .pem file, or:
   certutil -addstore -user Root <path-to-cloudflare-root-ca.pem>
   ```
4. In WARP client settings, enable "TLS decryption" (Gateway > Settings > Network > TLS decryption > Enable)
5. Verify: Visit https://help.teams.cloudflare.com and check that the certificate chain shows Cloudflare's org-specific CA, not the standard Cloudflare CA

**Gotchas**:
- Some dev tools (Python `requests`, Node.js `https`) may reject the custom CA unless you set `REQUESTS_CA_BUNDLE` / `NODE_EXTRA_CA_CERTS` environment variables pointing to the Cloudflare CA bundle. Plan for this.
- If you use WSL, the CA must be installed inside WSL separately (`update-ca-certificates`).

---

## Item 4: Customize Your Block Page

**Dashboard text**: "Manage what users will view when they navigate to websites you have blocked"

**Recommendation**: LATER (low priority, after rebuild)

**What it does**: When Gateway blocks a DNS query or HTTP request (malware, policy violation), it shows a block page. The default is a generic Cloudflare page. Customizing it lets you brand it and provide contact info.

**Why LATER**: This is cosmetic. The default block page works. You are the only user. Branding a block page for yourself is not a security control.

**What phase**: Phase 3+ (after client onboarding begins, when blocked pages might be seen by non-technical users or contractors).

**Security implications of skipping**: None. The block still works regardless of the page design.

---

## Item 5: Add a Policy to Block Malware (One-Click)

**Dashboard text**: "Create a one-click policy to block DNS queries that contain malware from resolving on your devices"

**Recommendation**: NOW (before rebuild)

**What it does**: Creates a Gateway DNS policy that blocks resolution of known-malicious domains using Cloudflare's threat intelligence feed. One click. Immediate protection.

**Why NOW**:
- Your workstation is the primary attack surface right now. It runs Claude Code agents that execute arbitrary shell commands, install npm/pip packages, and fetch from URLs. A supply chain attack via typosquatted package or compromised dependency could attempt DNS resolution of a C2 domain. This policy blocks that at the DNS layer.
- Costs nothing. Takes 10 seconds. Zero risk of breaking anything (malware domains are not domains you want to resolve).
- Applies to all WARP-enrolled devices immediately.
- After rebuild, K3s nodes get this protection too once they use Gateway DNS (via DNS Location or WARP).

**Security implications of skipping**: WARP routes DNS through Gateway, but without a DNS policy, Gateway just resolves everything. It becomes a fancy DNS proxy with no filtering. This defeats the purpose of having Gateway at all.

**Implementation**:
1. Zero Trust Dashboard > Gateway > Firewall Policies > DNS > Create policy
2. Or use the "one-click" button in the Getting Started checklist
3. Verify: `nslookup malware.testcategory.com` should return `0.0.0.0` or NXDOMAIN (Cloudflare provides test domains)

**Recommended additional DNS policies** (create alongside):

| Policy | What it blocks | Priority |
|--------|---------------|----------|
| Block malware | Known malware C2 domains | NOW |
| Block phishing | Known phishing domains | NOW |
| Block cryptomining | Cryptojacking domains | NOW |
| Block newly-seen domains | Domains <24h old (high false positive, start in log-only mode) | AFTER rebuild (needs tuning) |

---

## Item 6: Bypass Inspection for TLS-Incompatible Applications (One-Click)

**Dashboard text**: "Add a one-click HTTP policy to exclude a list of trusted applications from inspection"

**Recommendation**: NOW (immediately after Item 3)

**What it does**: Some applications pin their TLS certificates and will break if Gateway intercepts their traffic (even with the root CA installed). This creates an HTTP policy that skips TLS inspection for a curated list of known-incompatible apps (banking apps, some enterprise SaaS, certificate pinning services).

**Why NOW**: This is a prerequisite companion to Item 3 (Root CA). If you enable TLS inspection (Item 3) without this bypass list, you risk breaking:
- Windows Update (certificate pinning)
- Microsoft Defender updates
- Some banking/financial sites if accessed from the workstation
- Any tool that does HPKP or custom cert store checks

**Dependency**: Only relevant if you do Item 3. If you skip Item 3, skip this too.

**Security implications of skipping**: Applications that pin certificates will fail with TLS errors. You will spend time debugging "SSL handshake failed" errors that are actually Gateway inspection conflicts.

**Implementation**:
1. Use the one-click button in the Getting Started checklist
2. Review the bypass list -- ensure it includes applications you actually use
3. Add custom bypasses if needed:
   - Gateway > HTTP Policies > Do Not Inspect
   - Add any internal tools that use mTLS or custom CA chains

---

## Item 7: Investigate Vulnerabilities with Logs

**Dashboard text**: "View Gateway activity logs to identify anomalies"

**Recommendation**: LATER (after Items 3 and 5 are active, after rebuild)

**What it does**: Points you to the Gateway activity logs. This is not a configuration action -- it is a reminder to review logs.

**Why LATER**: Logs are only useful after policies are generating data. Once DNS malware blocking (Item 5) and TLS inspection (Item 3) are active, wait 1-2 weeks, then review:
- Blocked DNS queries (any unexpected malware hits from your workstation?)
- HTTP policy blocks (any TLS inspection issues?)
- Access audit logs (who/what is authenticating to your tunneled services?)

**What phase**: Ongoing operational practice. Build into a weekly review cadence.

**Security implications of skipping**: You will not know if your policies are working or if threats are being blocked. Policies without log review are set-and-forget security theater.

**Recommended log review cadence**:
- Weekly: Gateway DNS blocks, Access authentication events
- Monthly: Gateway HTTP blocks, device posture failures
- On-demand: After any security incident or policy change

---

## Summary: Sequenced Action Plan

### BEFORE Server Rebuild (do this week)

| Order | Item | Time | Dependency |
|-------|------|------|------------|
| 1 | Item 2: Verify WARP enrollment policy | 5 min | None |
| 2 | Item 5: Block malware DNS policy | 2 min | WARP enrolled |
| 3 | Item 3: Install root CA certificate | 15 min | WARP enrolled |
| 4 | Item 6: TLS inspection bypass list | 5 min | Item 3 |

**Total: ~30 minutes for meaningful security uplift.**

### AFTER Server Rebuild

| Order | Item | Phase | Dependency |
|-------|------|-------|------------|
| 5 | Item 1: DNS Location for K3s nodes | Phase 2 | K3s nodes have stable IPs |
| 6 | Item 7: Log review cadence | Ongoing | Items 3+5 generating data |
| 7 | Item 4: Custom block page | Phase 3+ | Client/contractor onboarding |

---

## Security Findings

### SECURITY FINDING: MEDIUM -- WARP Enrollment Scope Verification Needed

**Location**: Cloudflare Zero Trust > Settings > WARP Client > Device enrollment
**Issue**: Enrollment policy was created via API. Must verify no "Everyone" or wildcard enrollment rule was inadvertently created alongside the intended specific-identity rule.
**Attack Vector**: An overly broad enrollment rule allows any authenticated user to enroll a device, potentially gaining access to resources protected by "WARP is connected" device posture checks (including the secrets-vault Worker).
**Impact**: Unauthorized device enrollment -> vault access via WARP posture check bypass.
**Remediation**: Verify exactly one enrollment rule exists, scoped to KeemWilliams/admin@helixstax.com only. Delete any broader rules.
**Reference**: CWE-284 (Improper Access Control)

### SECURITY FINDING: MEDIUM -- Root CA Absence Limits Gateway Effectiveness

**Location**: Cloudflare Gateway configuration
**Issue**: Without the org root CA installed, Gateway can only inspect DNS queries and TLS SNI. HTTP policies (which inspect full URLs and request bodies) are non-functional.
**Attack Vector**: A compromised npm/pip package or malicious dependency exfiltrates data via HTTPS POST. Gateway sees only the destination domain (which may appear benign), not the payload.
**Impact**: Data exfiltration from workstation via encrypted channels goes undetected.
**Remediation**: Install root CA (Item 3), enable TLS inspection, apply bypass list (Item 6).
**Reference**: NIST CSF PR.DS-2 (Data in transit is protected)

### SECURITY FINDING: LOW -- No Gateway DNS Policies Active

**Location**: Cloudflare Gateway > DNS Policies
**Issue**: WARP is enrolled but no DNS filtering policies exist. Gateway resolves all DNS queries without filtering.
**Attack Vector**: Malware or compromised dependency resolves C2 domain. DNS resolution succeeds because no block policy exists.
**Impact**: First layer of defense (DNS filtering) is bypassed by default.
**Remediation**: Enable one-click malware blocking (Item 5). Add phishing and cryptomining blocks.
**Reference**: CIS Controls v8, Control 9.2 (Use DNS filtering services)

---

## SECURITY REVIEW SUMMARY

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 1 |

**Files reviewed**: Cloudflare Zero Trust Getting Started checklist (7 items), secrets-vault Worker source, ADR-001, cloudflare-zero-trust-setup.sh, cloudflare-zero-trust runbook, bootstrap-credential-strategy
**Overall assessment**: PASS WITH CONCERNS

No blocking issues. The 4 "do now" items are straightforward and take under 30 minutes total. The most impactful action is the malware DNS policy (Item 5) -- it is one click and immediately protects the workstation during the rebuild process.

---

HANDOFF:
1. Produced: `docs/review/zero-trust-checklist-review.md`
2. Key decisions: Sequenced all 7 items into before/after rebuild based on dependency analysis and current attack surface (workstation is primary target pre-rebuild)
3. Areas of uncertainty:
   - [MEDIUM] WARP enrollment policy scope -- cannot verify from static review, needs dashboard check
   - [LOW] Root CA compatibility with Claude Code agent HTTP clients (Python requests, Node fetch) -- may need env var tuning
4. Integration points: Items 3+5+6 must be done before any production traffic flows through the rebuilt cluster
5. Open questions:
   - Is the WARP split tunnel config already including `*.helixstax.workers.dev`? If not, WARP enrollment alone may not route vault traffic through Gateway.
   - Are there any other devices (phone, tablet, second machine) that should be enrolled in WARP?
