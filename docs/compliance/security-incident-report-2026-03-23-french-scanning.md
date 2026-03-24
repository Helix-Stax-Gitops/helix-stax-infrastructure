---
title: "Security Incident Report: Credential Harvesting Campaign"
category: "compliance"
version: "1.0"
last_updated: "2026-03-23"
classification: "INTERNAL"
severity: "MEDIUM"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC7.2", "CC7.3", "CC7.4"]
  - framework: "ISO 27001"
    controls: ["A.12.4.1", "A.13.1.1", "A.16.1.5"]
  - framework: "NIST CSF"
    controls: ["DE.CM-1", "DE.AE-2", "RS.AN-1"]
---

# Security Incident Report: Credential Harvesting Campaign

**Date**: 2026-03-23
**Reported by**: Ezra Raines (stax-security-engineer)
**Severity**: MEDIUM
**Status**: MITIGATED

## Executive Summary

A coordinated credential harvesting / vulnerability scanning campaign was detected targeting helixstax.net (internal domain) from March 19-22, 2026. 17,208 total requests originated primarily from France (82%), with additional activity from Australia, Switzerland, and South Korea. Attackers probed for exposed environment files, git configs, and common web framework vulnerabilities. No data was exposed — Zitadel properly redirected all requests to login. WAF rules have been deployed to block future attempts.

## Timeline

| Date | Requests | Source | Attack Pattern |
|------|----------|--------|----------------|
| Mar 19 | 5,617 | France (curl/8.7.1) | Probing /cron/.env, /vm-docker-compose/.env, Zitadel UI |
| Mar 20 | 810 | Australia (Chrome/91) | Probing .env.production, .git/config, .s3cfg, keys.json, .env.stripe |
| Mar 21 | 10,029 | France (curl/8.7.1) | Massive scan: wp-config.php, secrets.yml, .gitlab-ci.yml, /api/v1/files, /debug/ |
| Mar 22 | 752 | Mixed (CH, KR, FR) | Continued probing, reduced volume |

## Impact Assessment

- **Data Exposure**: NONE — Zitadel redirected all unauthenticated requests to login (302)
- **Service Disruption**: NONE — services remained operational
- **Credential Compromise**: NONE — no credentials were accessible via the probed paths

## Attack Vectors

Attackers targeted:
- Environment files: `.env`, `.env.production`, `.env.stripe`, `.env.local`
- Git configuration: `.git/config`, `.gitignore`
- Cloud credentials: `.s3cfg`, `keys.json`, `cashier.rb`
- CMS/framework files: `wp-config.php`, `secrets.yml`, `.gitlab-ci.yml`
- Debug endpoints: `/debug/`, `/api/v1/files`
- Docker configs: `/vm-docker-compose/.env`, `.dockerignore`

## Response Actions

### Immediate (Completed 2026-03-23)
1. Deployed 5 WAF custom rules on helixstax.net (internal — strict):
   - BLOCK: Sensitive file probing (.env, .git, wp-config, secrets.yml, keys.json)
   - BLOCK: Tor exit nodes + non-US curl requests
   - BLOCK: Russia, China, North Korea, Iran
   - CHALLENGE: All non-ally countries
   - CHALLENGE: Known scanner user agents + empty UAs

2. Deployed 5 WAF custom rules on helixstax.com (public — permissive):
   - BLOCK: Sensitive file probing
   - BLOCK: Tor + hostile nations
   - CHALLENGE: Non-US curl, scanner UAs, non-ally countries

3. Enabled Bot Fight Mode + JS detection on both zones
4. Raised security level to HIGH on helixstax.net

### Pending
1. **URGENT**: Revoke old Cloudflare Global API Key (still active in secrets vault)
2. **URGENT**: Remove hardcoded API key from `scripts/cloudflare-zero-trust-setup.sh` line 24
3. Update secrets vault with new scoped API token
4. Monitor WAF analytics for 7 days to verify rule effectiveness
5. Consider Cloudflare Pro upgrade for helixstax.net ($20/mo — enhanced WAF, rate limiting)

## Findings Requiring Action

| Finding | Severity | Status |
|---------|----------|--------|
| Old Global API Key still active | HIGH | PENDING — revoke at dash.cloudflare.com |
| Hardcoded API key in git repo script | HIGH | PENDING — remove from cloudflare-zero-trust-setup.sh |
| Free plan limits (5 custom rules/zone) | MEDIUM | MONITORING — upgrade if more rules needed |
| Bot Fight Mode may affect API calls | LOW | MONITORING — watch for false positives |

## Lessons Learned

1. Internal domains need WAF rules from day one, not just after an incident
2. Automated scanning is constant — 17K requests in 4 days from a single campaign
3. Zitadel's default auth redirect behavior provided effective passive defense
4. Country-based blocking is effective against bot farms concentrated in specific regions

## Compliance Controls Satisfied

| Framework | Control | Description |
|-----------|---------|-------------|
| SOC 2 | CC7.2 | Monitoring of system components for anomalies |
| SOC 2 | CC7.3 | Evaluation of security events |
| SOC 2 | CC7.4 | Response to identified security incidents |
| ISO 27001 | A.12.4.1 | Event logging |
| ISO 27001 | A.13.1.1 | Network controls |
| ISO 27001 | A.16.1.5 | Response to information security incidents |
| NIST CSF | DE.CM-1 | Network monitoring for cybersecurity events |
| NIST CSF | DE.AE-2 | Analyzed events to understand attack targets and methods |
| NIST CSF | RS.AN-1 | Notifications from detection systems investigated |

---

*Author: Wakeem Williams | Co-Author: Ezra Raines | Documented by: Quinn Mercer*
*Classification: INTERNAL | Version: 1.0 | Date: 2026-03-23*
