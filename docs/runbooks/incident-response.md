# Incident Response

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: ACTIVE
**Platform**: Helix Stax (single admin: Wakeem)

---

## Prerequisites

- Access to monitoring (Grafana, Prometheus alerts)
- SSH access to all servers (see escape-hatch.md for fallbacks)
- This runbook bookmarked / accessible offline

---

## 1. Severity Levels

| Level | Name | Description | Examples |
|-------|------|-------------|----------|
| **P1** | Critical | Platform down, data at risk, security breach | k3s API unreachable, data loss detected, credential leak, both nodes down |
| **P2** | Major | Significant service degradation | Devtron unreachable, Authentik SSO down, worker node offline, CI/CD broken |
| **P3** | Minor | Single service impacted, workaround available | n8n workflow failures, Grafana dashboard errors, single pod crash loop |
| **P4** | Low | Cosmetic, non-urgent improvements | Slow dashboard load, log noise, non-critical alert tuning |

---

## 2. Response Timeline

| Level | Acknowledge | Investigate | Mitigate | Resolve | Post-Incident Review |
|-------|-------------|-------------|----------|---------|---------------------|
| **P1** | 15 min | 30 min | 1 hour | 4 hours | Required (within 48h) |
| **P2** | 1 hour | 2 hours | 4 hours | 24 hours | Required (within 1 week) |
| **P3** | 4 hours | 8 hours | 24 hours | 1 week | Optional |
| **P4** | 1 day | 1 week | 2 weeks | 1 month | Not required |

Note: These are targets for a single-admin platform. Wakeem is human and has a life. The platform is not mission-critical 24/7 SaaS -- reasonable response times are acceptable.

---

## 3. Incident Response Process

### 3.1 Detection

Incidents are detected via:
1. **Automated alerts**: Prometheus/Alertmanager -> Grafana -> email/Telegram
2. **Manual observation**: Dashboard check, user report, routine audit
3. **External report**: GitHub notification, Hetzner status page, vendor alert

### 3.2 Triage (ASSESS)

```
1. WHAT is affected? (which services, which users)
2. WHEN did it start? (check Grafana for change point)
3. WHY might it have happened? (recent change? external event?)
4. HOW BAD is it? (P1-P4 severity)
5. IS IT GETTING WORSE? (trending or stable)
```

### 3.3 Response Workflow

```
DETECT -> TRIAGE -> CONTAIN -> FIX -> VERIFY -> DOCUMENT
```

**DETECT**: Alert fires or issue observed.

**TRIAGE**: Assign severity (P1-P4). For P1/P2, drop everything else.

**CONTAIN**: Stop the bleeding. Examples:
- Scale down a crashing deployment
- Block malicious IP in firewall
- Disable compromised credentials
- Redirect traffic away from broken service

**FIX**: Root cause repair. Examples:
- Apply hotfix
- Restore from backup
- Re-provision resource
- Roll back deployment

**VERIFY**: Confirm the fix works:
- Service responds correctly
- No new errors in logs
- Monitoring shows recovery
- Related services unaffected

**DOCUMENT**: Fill out post-incident review (see section 5).

---

## 4. Communication Template

### Internal Incident Log (Markdown)

```markdown
# Incident: [TITLE]

**Severity**: P[1-4]
**Status**: [Investigating | Identified | Mitigating | Resolved]
**Started**: YYYY-MM-DD HH:MM UTC
**Resolved**: YYYY-MM-DD HH:MM UTC (or ongoing)
**Duration**: X hours Y minutes

## Impact
[What services were affected, what users could/couldn't do]

## Timeline
- HH:MM - Alert fired / Issue detected
- HH:MM - Investigation started
- HH:MM - Root cause identified
- HH:MM - Mitigation applied
- HH:MM - Service restored
- HH:MM - Verified fully resolved

## Root Cause
[Technical description of what went wrong]

## Resolution
[What was done to fix it]

## Action Items
- [ ] [Preventive measure 1]
- [ ] [Preventive measure 2]
```

### Quick Status Update (for Telegram/notes)

```
[P{1-4}] {Service} - {Status}
Impact: {one line}
ETA: {when you expect resolution}
```

Example:
```
[P2] Devtron - Investigating
Impact: CI/CD pipelines not triggering
ETA: ~1 hour
```

---

## 5. Post-Incident Review Template

Required for P1 and P2. Store in `docs/incidents/YYYY-MM-DD-title.md`.

```markdown
# Post-Incident Review: [TITLE]

**Date**: YYYY-MM-DD
**Severity**: P[1-2]
**Duration**: X hours Y minutes
**Author**: Wakeem

## Summary
[2-3 sentences: what happened, impact, resolution]

## Detection
- How was the incident detected?
- How long between start and detection?
- Could detection have been faster?

## Timeline
[Detailed timeline with timestamps]

## Root Cause Analysis
[Technical deep dive into why this happened]

### Contributing Factors
1. [Factor 1]
2. [Factor 2]

### 5 Whys
1. Why did X happen? Because Y.
2. Why did Y happen? Because Z.
3. ...

## What Went Well
- [Positive aspect 1]
- [Positive aspect 2]

## What Went Poorly
- [Issue 1]
- [Issue 2]

## Action Items

| Action | Priority | Due Date | Status |
|--------|----------|----------|--------|
| [Preventive measure] | High | YYYY-MM-DD | Open |
| [Monitoring improvement] | Medium | YYYY-MM-DD | Open |
| [Documentation update] | Low | YYYY-MM-DD | Open |

## Lessons Learned
[Key takeaways for future incidents]
```

---

## 6. Escalation: Single Admin Risk

### The Bus Factor Problem

Wakeem is the sole admin. If Wakeem is unavailable:

**Immediate mitigations (already in place):**
- k3s is self-healing (pods restart automatically)
- Backups run on cron (no manual intervention)
- Monitoring alerts fire regardless of who is watching
- Services remain running without admin action

**Preparation for extended unavailability:**

1. **Documented escape hatches**: This runbook + escape-hatch.md enable another technical person to recover services.

2. **Break-glass credentials packet**: Store the following in a sealed, secure location (encrypted USB or trusted third party):
   - Hetzner Cloud login (email + password + 2FA recovery code)
   - Hetzner Robot login
   - SSH private keys for all servers
   - k3s kubeconfig
   - Authentik akadmin password
   - Devtron admin password
   - Grafana admin password
   - Restic backup password
   - Cloudflare login credentials

3. **Trusted backup person**: Identify one trusted person who can:
   - Access the break-glass packet
   - Follow these runbooks
   - Perform basic recovery (restart services, restore from backup)
   - Does NOT need deep K8s expertise -- runbooks are step-by-step

4. **Service degradation is acceptable**: If Wakeem is unavailable for days:
   - Self-healing covers most pod failures
   - Automatic backups protect data
   - Cert auto-renewal prevents TLS expiry
   - No manual intervention needed for steady-state operation
   - Only true infrastructure failure (node death, DC outage) requires human action

### When to Panic

| Situation | Response |
|-----------|----------|
| Pod crash loops | Don't panic. K8s restarts pods. Check if self-heals in 15 min. |
| Single node offline | Follow escape-hatch.md. One node down = degraded but functional. |
| Both nodes offline | Use Hetzner consoles. This is a P1 but recoverable. |
| Data corruption detected | Stop writes. Restore from backup. See backup-strategy.md. |
| Security breach suspected | Isolate: disable external access. Rotate all creds. See secrets-management.md. |

---

## 7. Common Incident Playbooks

### Playbook: Pod in CrashLoopBackOff

```bash
# 1. Identify the pod
kubectl get pods -A | grep -i crash

# 2. Check logs
kubectl -n <ns> logs <pod> --previous

# 3. Check events
kubectl -n <ns> describe pod <pod>

# 4. Common fixes:
#    - OOM: Increase memory limits
#    - Config error: Check ConfigMap/Secret
#    - Image pull: Check image tag and registry auth
#    - Dependency: Check if dependent service is running
```

### Playbook: Node NotReady

```bash
# 1. Check node status
kubectl get nodes
kubectl describe node <node>

# 2. SSH to the node
ssh root@<node-ip>

# 3. Check k3s service
systemctl status k3s       # or k3s-agent for worker
journalctl -u k3s --since "30 min ago"

# 4. Check resources
free -h
df -h
top -b -n1 | head -20

# 5. Restart k3s if needed
systemctl restart k3s
```

### Playbook: TLS Certificate Expired

```bash
# 1. Check cert status
kubectl get certificates -A
kubectl describe certificate <name> -n <ns>

# 2. Force renewal
kubectl delete certificate <name> -n <ns>
# cert-manager will recreate and re-issue

# 3. If cert-manager is broken, use self-signed as emergency:
openssl req -x509 -nodes -days 7 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.helixstax.net"
kubectl -n <ns> create secret tls emergency-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key
```

---

## 8. Verification

Quarterly drill:
- [ ] Can Wakeem access all servers via at least 2 methods?
- [ ] Break-glass credential packet is up to date
- [ ] Backup restore tested (pick one service, restore, verify)
- [ ] Alert notification chain works (trigger test alert, verify delivery)
- [ ] Trusted backup person knows where credentials are stored
- [ ] Incident log directory exists (`docs/incidents/`)
