# Cloudflare Security Insights Review

**Date**: 2026-03-23
**Reviewer**: Ezra Raines (stax-security-engineer)
**Source**: Cloudflare Security Insights export (2026-03-23 18:17 UTC)
**Domains**: helixstax.com, helixstax.net (auth.helixstax.net, s3.helixstax.net)

---

## SECURITY REVIEW SUMMARY

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 3 |
| MEDIUM | 3 |
| LOW | 3 |
| **Total** | **10** |

**Overall Assessment: FAIL**

One CRITICAL finding (identity endpoint serving without TLS) and three HIGH findings require immediate remediation before any production workloads are deployed.

---

## CRITICAL Findings

### FINDING-1: Identity Endpoint (auth.helixstax.net) Has No TLS Encryption

**Severity**: CRITICAL
**Cloudflare Category**: Compliance violation
**Subject**: auth.helixstax.net

**Issue**: Cloudflare detected that auth.helixstax.net accepts HTTP on port 80 but does NOT accept HTTPS on port 443. This means the Zitadel identity provider -- the OIDC issuer for the entire platform -- is transmitting authentication tokens, session cookies, and user credentials in plaintext.

**Attack Vector**: Any network observer between the client and origin (ISP, Hetzner network peer, compromised router, coffeeshop WiFi) can intercept:
- OIDC authorization codes and tokens
- User passwords during login flows
- Session cookies for all authenticated services
- JWT tokens issued by Zitadel
- NetBird OIDC tokens (management.json references `https://auth.helixstax.net/application/o/netbird/`)

**Impact**:
- Complete authentication bypass via stolen tokens
- Account takeover for all platform users
- Credential harvesting at scale
- Compromise of every service that trusts Zitadel as its IdP (NetBird, internal portals, all OIDC-protected apps)

**Evidence from codebase**: auth.helixstax.net is the OIDC issuer for:
- Zitadel (`docker-compose/zitadel/docker-compose.yml` -- `ZITADEL_EXTERNALDOMAIN: auth.helixstax.net`)
- NetBird management (`docker-compose/netbird/management.json` -- 8 references to `https://auth.helixstax.net`)
- NetBird dashboard (`docker-compose/netbird/docker-compose.yml` -- `AUTH_AUTHORITY`)
- All future OIDC-protected services

**Remediation** (Effort: 15-30 minutes):
1. **Cloudflare Dashboard > helixstax.net > SSL/TLS**: Set encryption mode to **Full (strict)**
2. **Verify Origin Certificate**: Ensure Cloudflare Origin CA cert is installed on the origin server for auth.helixstax.net. The nginx config at `docker-compose/nginx/conf.d/auth.helixstax.net.conf` references Let's Encrypt certs -- verify these exist or switch to Origin CA.
3. **Enable "Always Use HTTPS"**: Cloudflare Dashboard > helixstax.net > SSL/TLS > Edge Certificates > Always Use HTTPS = ON
4. **Enable HSTS**: Same page, HSTS > Enable with `max-age=31536000; includeSubDomains`
5. **Verify**: `curl -I https://auth.helixstax.net` returns 200 with valid TLS; `curl -I http://auth.helixstax.net` returns 301 redirect to HTTPS

**Reference**: CWE-319 (Cleartext Transmission of Sensitive Information), OWASP A02:2021 (Cryptographic Failures)

---

## HIGH Findings

### FINDING-2: MinIO Object Storage (s3.helixstax.net) Has No TLS Encryption

**Severity**: HIGH
**Cloudflare Category**: Compliance violation
**Subject**: s3.helixstax.net

**Issue**: s3.helixstax.net accepts HTTP on port 80 but does NOT accept HTTPS on port 443. MinIO handles object storage including potentially sensitive data, backups, Harbor registry artifacts, and application assets.

**Attack Vector**: Credentials (MinIO access keys and secret keys) are transmitted in HTTP headers for every S3 API call. An attacker on the network path can capture these credentials and gain full read/write access to all storage buckets.

**Impact**:
- MinIO access key / secret key interception
- Unauthorized access to all stored objects (backups, container images, application data)
- Data tampering (modify stored objects in transit)
- Data exfiltration

**Remediation** (Effort: 15-30 minutes):
1. **Cloudflare Dashboard > helixstax.net > SSL/TLS**: Set encryption mode to **Full (strict)** (same action as FINDING-1 -- zone-level setting covers all subdomains)
2. Verify Origin CA cert covers `*.helixstax.net` or has a specific cert for s3.helixstax.net
3. Enable "Always Use HTTPS" (zone-level, covers this subdomain too)
4. Enable HSTS for the zone

**Reference**: CWE-319, OWASP A02:2021

### FINDING-3: Cloudflare Account Users Without MFA

**Severity**: HIGH
**Cloudflare Category**: Weak authentication
**Subjects**: admin@helixstax.com, contact@wakeemwilliams.com

**Issue**: Two Cloudflare account users do not have MFA enabled. The Cloudflare account controls DNS, TLS settings, WAF rules, Zero Trust policies, and tunnel configurations for the entire platform.

**Attack Vector**:
- Credential stuffing / password spray against Cloudflare login
- Phishing for Cloudflare credentials
- Password reuse from other breached services
- Once in, attacker controls DNS (redirect auth.helixstax.net to attacker server), disables WAF, modifies Zero Trust policies, creates rogue tunnels

**Impact**:
- Complete platform compromise via DNS hijacking
- TLS downgrade attacks by modifying SSL settings
- Disabling WAF protections
- Creating backdoor tunnels into the cluster
- Modifying Zero Trust access policies to grant unauthorized access

**Remediation** (Effort: 5 minutes per user):
1. **Cloudflare Dashboard > My Profile > Authentication**: Enable TOTP or hardware key for admin@helixstax.com
2. Repeat for contact@wakeemwilliams.com
3. **Enforce account-wide**: Cloudflare Dashboard > Manage Account > Authentication > Require 2FA for all members = ON
4. Consider removing contact@wakeemwilliams.com if not actively needed (principle of least privilege)

**Reference**: CWE-308 (Use of Single-factor Authentication), OWASP A07:2021 (Identification and Authentication Failures)

### FINDING-4: DMARC Record Missing for helixstax.com

**Severity**: HIGH (elevated from Cloudflare's "Low" due to Google Workspace context)
**Cloudflare Category**: Email Security
**Subject**: helixstax.com (5 MX record entries without valid DMARC)

**Issue**: helixstax.com has MX records (Google Workspace) but no valid DMARC TXT record at `_dmarc.helixstax.com`. This means any attacker can send emails appearing to come from @helixstax.com and recipient mail servers have no policy to reject or quarantine them.

**Why HIGH (not LOW)**: helixstax.com is the primary business domain used for client communication, proposals, and consulting deliverables. Email spoofing of this domain directly undermines client trust and could be used in BEC (Business Email Compromise) attacks against clients.

**Attack Vector**:
- Spoof emails from admin@helixstax.com to clients with fake invoices
- Spoof consulting deliverables or proposals with modified content
- Phishing campaigns using helixstax.com as the sender domain
- Damage to domain reputation causing legitimate emails to land in spam

**Impact**:
- Business Email Compromise targeting clients
- Reputational damage to the consulting brand
- Legitimate emails flagged as spam (deliverability degradation)
- Potential financial fraud against clients

**Remediation** (Effort: 10 minutes):

Add the following DNS records in Cloudflare for helixstax.com:

**Step 1: Verify SPF record exists**
```
Type: TXT
Name: @
Value: v=spf1 include:_spf.google.com ~all
```

**Step 2: Add DMARC record (start with monitoring, then enforce)**
```
Type: TXT
Name: _dmarc
Value: v=DMARC1; p=none; rua=mailto:dmarc-reports@helixstax.com; ruf=mailto:dmarc-reports@helixstax.com; adkim=r; aspf=r; pct=100
```

**Step 3: Ramp-up schedule (change `p=` value)**
- Week 1-2: `p=none` (monitor only, review rua reports)
- Week 3-4: `p=quarantine; pct=25` (quarantine 25% of failing emails)
- Week 5-6: `p=quarantine; pct=100` (quarantine all failing emails)
- Week 7+: `p=reject` (reject all failing emails)

**Step 4: Verify DKIM is configured in Google Workspace**
- Google Admin Console > Apps > Google Workspace > Gmail > Authenticate email > Generate DKIM key
- Add the DKIM CNAME/TXT record to Cloudflare DNS

**Note**: The 5 duplicate findings in the CSV correspond to 5 MX records, all flagged individually. This is a single remediation action.

**Reference**: CWE-290 (Authentication Bypass by Spoofing), RFC 7489 (DMARC)

---

## MEDIUM Findings

### FINDING-5: "Always Use HTTPS" Not Enabled (auth.helixstax.net)

**Severity**: MEDIUM (subsumed by FINDING-1 remediation)
**Cloudflare Category**: Insecure configuration

**Issue**: HTTP requests to auth.helixstax.net are not redirected to HTTPS. Even after TLS is configured (FINDING-1), users or applications making HTTP requests will transmit data in cleartext unless forced redirect is enabled.

**Remediation**: Included in FINDING-1 remediation step 3.
**Effort**: Toggle (part of FINDING-1 fix)

### FINDING-6: "Always Use HTTPS" Not Enabled (s3.helixstax.net)

**Severity**: MEDIUM (subsumed by FINDING-2 remediation)
**Cloudflare Category**: Insecure configuration

**Issue**: HTTP requests to s3.helixstax.net are not redirected to HTTPS. S3 API clients making HTTP calls will transmit access keys in cleartext.

**Remediation**: Included in FINDING-2 remediation step 3.
**Effort**: Toggle (part of FINDING-2 fix)

### FINDING-7: Block AI Bots on helixstax.net

**Severity**: MEDIUM
**Cloudflare Category**: Configuration suggestion
**Subject**: helixstax.net (internal platform domain)

**Issue**: AI crawlers (GPTBot, Claude-Web, etc.) can access helixstax.net subdomains. Since helixstax.net hosts internal platform services (Grafana, n8n, Devtron, Zitadel), AI bots should not be indexing or scraping these endpoints.

**Attack Vector**: AI crawlers may index internal service metadata, error pages, or API responses that leak information about the platform stack.

**Remediation** (Effort: 1 minute):
1. **Cloudflare Dashboard > helixstax.net > Security > Bots > Block AI Bots**: Enable
2. This is a zone-level toggle -- covers all subdomains

**Reference**: CWE-200 (Exposure of Sensitive Information)

---

## LOW Findings

### FINDING-8: security.txt Not Configured (both domains)

**Severity**: LOW
**Subjects**: helixstax.com, helixstax.net

**Issue**: Neither domain has a `/.well-known/security.txt` file. This is a best practice (RFC 9116) that provides security researchers a clear channel to report vulnerabilities.

**Remediation** (Effort: 5 minutes):
1. Cloudflare Dashboard > each domain > Security > Security.txt > Configure
2. Set contact email (e.g., `security@helixstax.com`)
3. Set expiration date
4. Optionally link to a vulnerability disclosure policy

**Reference**: RFC 9116

### FINDING-9: AI Labyrinth Suggestion for helixstax.net

**Severity**: LOW
**Subject**: helixstax.net

**Issue**: Cloudflare suggests enabling AI Labyrinth, which serves AI-generated decoy content to AI crawlers, wasting their resources and protecting real content.

**Remediation** (Effort: 1 minute):
1. Cloudflare Dashboard > helixstax.net > Security > Bots > AI Labyrinth: Enable
2. Complementary to FINDING-7 (Block AI Bots)

### FINDING-10: HSTS Not Enabled (auth.helixstax.net, s3.helixstax.net)

**Severity**: LOW (subsumed by FINDING-1 and FINDING-2 remediation)

**Issue**: HSTS header not present on either subdomain. Without HSTS, browsers do not enforce HTTPS-only access, leaving users vulnerable to SSL stripping attacks on subsequent visits.

**Remediation**: Included in FINDING-1 and FINDING-2 remediation steps.
**Effort**: Toggle (part of TLS fix)

---

## Prioritized Remediation Plan

### Immediate (Today) -- CRITICAL + HIGH

| Priority | Finding | Action | Effort | Risk if Deferred |
|----------|---------|--------|--------|------------------|
| **P0** | FINDING-1 | Enable Full (strict) TLS + Always Use HTTPS + HSTS for helixstax.net zone | 15-30 min | Identity tokens transmitted in cleartext; full platform compromise possible |
| **P0** | FINDING-3 | Enable MFA on both Cloudflare accounts + enforce account-wide | 5 min | Single credential leak = total DNS/WAF/tunnel control |
| **P1** | FINDING-4 | Add DMARC + verify SPF + configure DKIM for helixstax.com | 10-15 min | Domain spoofing for BEC attacks against clients |

**Note**: FINDING-1 remediation (zone-level TLS settings) also resolves FINDING-2, FINDING-5, FINDING-6, and FINDING-10 in a single action since they share the helixstax.net zone.

### This Week -- MEDIUM

| Priority | Finding | Action | Effort |
|----------|---------|--------|--------|
| **P2** | FINDING-7 | Enable Block AI Bots on helixstax.net | 1 min toggle |

### When Convenient -- LOW

| Priority | Finding | Action | Effort |
|----------|---------|--------|--------|
| **P3** | FINDING-8 | Configure security.txt on both domains | 5 min |
| **P3** | FINDING-9 | Enable AI Labyrinth on helixstax.net | 1 min toggle |

---

## Pre-Remediation Checklist

Before enabling Full (strict) TLS on helixstax.net, verify:

- [ ] Cloudflare Origin CA certificate is installed on the origin server and covers `auth.helixstax.net` and `s3.helixstax.net` (check: the nginx config at `docker-compose/nginx/conf.d/auth.helixstax.net.conf` references Let's Encrypt paths -- ensure certs exist or update paths to Origin CA certs)
- [ ] DNS records for auth.helixstax.net and s3.helixstax.net are proxied (orange cloud) through Cloudflare, not DNS-only (gray cloud)
- [ ] Cloudflare tunnel or direct proxy is routing traffic to the origin on port 443
- [ ] Origin server firewall allows inbound 443 from Cloudflare IP ranges

After enabling, verify:
- [ ] `curl -I https://auth.helixstax.net` returns valid TLS handshake and 200/301
- [ ] `curl -I http://auth.helixstax.net` returns 301 redirect to HTTPS
- [ ] NetBird management can reach Zitadel OIDC endpoints over HTTPS
- [ ] Zitadel login flow works end-to-end with HTTPS

---

## Algedonic Signal Emitted

**HALT SECURITY** emitted for FINDING-1 (auth.helixstax.net without TLS). The identity endpoint for the entire platform is transmitting credentials and tokens in cleartext. No production workloads should be deployed until this is resolved.

---

## Notes

- The 18 CSV rows reduce to 10 distinct findings after deduplication (5 DMARC rows = 1 finding per MX record, HSTS/HTTPS/TLS findings grouped per host)
- helixstax.net zone-level TLS settings will resolve 6 of the 18 CSV rows in a single configuration change
- The DMARC ramp-up schedule is conservative to avoid disrupting legitimate email delivery during the monitoring phase
- Consider adding helixstax.net to the DMARC record as well once email sending from that domain is planned
- The `contact@wakeemwilliams.com` Cloudflare account should be audited for necessity -- remove if not actively needed
