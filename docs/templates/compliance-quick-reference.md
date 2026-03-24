---
template: compliance-quick-reference
category: compliance
task_type: reference
clickup_list: 05 Compliance Program > Reference Materials
auto_tags: [compliance, quick-reference, training, poster]
required_fields: [Framework, Key Controls, Responsibilities, Resources]
classification: internal
compliance_frameworks: [SOC2, ISO27001, NIST]
review_cycle: annually
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: Compliance Quick Reference Card

Use this template to create a one-page, quick-reference compliance guide for a specific framework, project, or operational domain. Print and post at desks, or share as a PDF. File in `docs/compliance/` or on the ClickUp wiki.

## TLDR

A one-page (or 2-page) reference card distilling a compliance framework into essential information for Helix Stax staff. Designed to be scanned in 2–3 minutes. Useful for new hires, onboarding, incident response, and desk reminders. Print and post, or share as PDF.

---

# COMPLIANCE QUICK REFERENCE: [Framework Name]

**Framework**: [e.g., SOC 2 Type II]
**Version**: [e.g., 2022 Trust Services Criteria]
**Helix Stax Applicability**: [Full / Partial / Project-Specific]
**Last Updated**: [DATE]
**Next Review**: [DATE]

---

## What Is This Framework?

**[1–2 sentences]** Why do we care? What does it accomplish?

Example: "SOC 2 Type II demonstrates that Helix Stax has designed and operated effective security controls for a minimum 6-month period. Required by most enterprise customers; foundation for all IT consulting credibility."

---

## Who's Responsible?

| Role | Responsibility | Example |
|------|-----------------|---------|
| **CEO/Owner** (Wakeem) | Overall accountability | Approves control implementations |
| **Operations Lead** | Day-to-day compliance | Ensures controls are operating |
| **All Staff** | Following procedures | Don't skip security steps |
| **Auditors** (external) | Verifying controls | Annual SOC 2 audit |

---

## Core Controls at a Glance

**[Show 6–10 most critical controls in simple language]**

| Control # | Control Name | What It Means | Red Flag |
|-----------|-------------|--------------|----------|
| **CC6.1** | Access Control | Users only get access they need | Someone has access they don't need; no access review done |
| **CC6.2** | Privileged Access | Admin access is restricted | Admin password written on a sticky note |
| **CC7.1** | Defect Tracking | We document and fix security bugs | Security issue found but not tracked |
| **CC7.2** | System Monitoring | We continuously monitor systems | No one looking at logs or metrics |
| **CC8.1** | Change Management | Infrastructure changes are planned & approved | Code deployed to production without review |
| **CC9.2** | Vendor Risk | We vet and monitor vendors | Using random SaaS tool without security review |
| **A1.1** | Confidentiality | We protect sensitive data | Customer data exposed or improperly handled |
| **A1.2** | Backup & Recovery | We can recover from failures | Backup never tested; can't restore |

---

## Your Responsibilities (Checklist)

**Check these off to ensure YOU'RE compliant:**

### Every Day
- [ ] Use strong password (12+ chars, mixed case/number/symbol)
- [ ] Don't share passwords via email, Slack, or chat
- [ ] Lock your workstation when you leave (Windows+L or Cmd+Q)
- [ ] Report security incidents immediately (don't cover it up)

### Every Week
- [ ] Review your ClickUp task assignments (stay on top of work)
- [ ] Check for patch notifications (OS, containers, packages)
- [ ] Verify your access is still appropriate (no unnecessary admin)

### Every Month
- [ ] Acknowledge the security policy (admin reminder in email)
- [ ] Review your git commits (no secrets committed?)
- [ ] Attend security update if scheduled

### Every Quarter
- [ ] Participate in access review (confirm you still need your current access)
- [ ] Review compliance dashboard (understand control status)
- [ ] Report any concerns to Operations

---

## Key Procedures You Must Know

### Access Control
- **When**: New team member starts or role changes
- **Who**: IT/Ops lead + manager
- **What**: Provision or revoke access per RBAC (role-based access control)
- **Doc**: `docs/procedures/access-control.md`
- **Red Flag**: Someone has access they don't need; no one reviewing access lately

### Password Management
- **Rule 1**: 12+ characters (uppercase, lowercase, number, symbol)
- **Rule 2**: Never share via email; use password manager or OpenBao
- **Rule 3**: Never write down; if written down, destroy immediately
- **Rule 4**: Change immediately if leaked
- **Doc**: `docs/security-policy.md`

### Incident Response
- **When**: You discover a security issue or something's broken in production
- **Who**: Report to your manager + on-call engineer immediately
- **What**: Post in Rocket.Chat `#incidents` with specifics (no guessing)
- **What NOT**: Don't try to cover it up; don't restart services without guidance
- **Doc**: `docs/runbooks/incident-response.md`

### Change Management
- **Before deploying** infrastructure or config changes:
  1. Create a ClickUp task describing what you're changing
  2. Get peer review approval
  3. Test on staging cluster first
  4. Notify team in Rocket.Chat
  5. Deploy with monitoring ready
- **After deploying**: Log the change in ClickUp + confirm it worked
- **Doc**: `docs/procedures/change-management.md`

### Vendor Management
- **Before using new SaaS/tool**: Ask security team (email [security@helixstax.com])
- **Questions security will ask**:
  - Is sensitive data stored there?
  - Are they SOC 2 / ISO 27001 certified?
  - What's the data retention policy?
  - Can they be removed quickly if needed?
- **Doc**: `docs/procedures/vendor-risk.md`

---

## Common Scenarios & What To Do

| Scenario | Action | DON'T DO |
|----------|--------|----------|
| **You discover a bug in production** | 1. Post in #incidents. 2. Alert on-call. 3. Don't deploy a fix without review. | Don't restart services hoping it fixes it. Don't delete data. Don't cover it up. |
| **You receive a customer data request (GDPR/CCPA)** | 1. Forward to legal/compliance. 2. Don't respond directly. | Don't delete data to hide it. Don't share with anyone else first. |
| **Someone asks for your password** | Say "No, that's not how we work here." Share this: [Password policy link] | Don't share; don't make an exception. |
| **You find an unencrypted password in code** | 1. Report to security. 2. Rotate the password. 3. Update code to use secrets manager. | Don't commit the password (delete it). Don't ignore it. |
| **A vendor won't answer security questions** | Don't use them without security approval. Escalate to Wakeem. | Don't use them anyway. Don't wait forever. |
| **You notice suspicious activity (failed logins, etc.)** | Report to security/on-call immediately. | Don't investigate on your own. Don't assume it's harmless. |

---

## Metrics to Watch

**[What compliance "looks like" at Helix Stax]**

| Metric | Target | How We Measure | Owner |
|--------|--------|-----------------|-------|
| **Access reviews completed** | 100% annually | Auditor attestation | Ops |
| **Security incidents reported & resolved** | 100% within SLA | ClickUp + incident log | Ops |
| **Systems passing security scanning** | 100% | Weekly automated scans | DevOps |
| **Change management compliance** | 100% | Audit of ClickUp tasks vs deployed changes | DevOps |
| **Backup & recovery testing** | 4x annually | Test restore log | SRE |
| **Password breach notification response** | < 24 hours | Incident log | Security |

---

## FAQ (Frequently Asked Compliance Questions)

**Q: Do I have to change my password every 90 days?**
A: No. We use passphrases + 2FA instead (more secure). Change only if:
- You suspect it's compromised
- We alert you to a breach
- A vendor requires it

**Q: Is it OK to share access with a colleague?**
A: No. Everyone gets their own access. If they need it, request access for them (goes through approval).

**Q: Can I store customer data locally on my laptop?**
A: No. All customer data stays in secure systems (databases, encrypted storage). Use OpenBao for credentials.

**Q: What if I accidentally commit a password to GitHub?**
A: Immediately report to security. We'll:
1. Rotate the credential
2. Force-push to remove it from history
3. Audit if it was accessed
4. Document as a learning moment

**Q: Am I required to attend security training?**
A: Yes. Annual training is mandatory. Quarterly refreshers are optional but encouraged.

**Q: What if I notice a compliance gap?**
A: Report it! File a ClickUp task in 05 Compliance or email security@helixstax.com. We reward people for finding gaps early.

---

## Red Flags (What Compliance Problems Look Like)

🚨 **Stop and report if you see:**

- [ ] Passwords written on sticky notes
- [ ] Credentials in code, logs, or config files
- [ ] Someone using another person's account
- [ ] Data exported to personal laptops
- [ ] Unencrypted customer data in files
- [ ] Disabled 2FA or security controls
- [ ] Logs deleted or "cleaned up" suspiciously
- [ ] Vendor used without security review
- [ ] Infrastructure changes deployed without approval
- [ ] Incident/security issue hushed up instead of reported

**If you see any of these: Report to security@helixstax.com or your manager immediately.**

---

## Emergency: What If There's A Breach?

**Do this immediately:**

1. **Isolate** (don't delete; preserve evidence)
2. **Report** (Rocket.Chat #incidents + email security)
3. **Don't discuss publicly** (compliance communication only)
4. **Follow incident runbook** (`docs/runbooks/incident-response.md`)
5. **Let security lead** (don't investigate yourself)

**Don't do this:**
- ❌ Clean up logs to hide it
- ❌ Tell customers before legal/leadership approves
- ❌ Continue normal operations pretending it didn't happen
- ❌ Blame someone; focus on fixing it

---

## Key Documents (Bookmark These)

| Document | Link | When to Read |
|----------|------|--------------|
| **Security Policy** | `docs/security-policy.md` | Before starting; annually refresh |
| **Access Control Procedure** | `docs/procedures/access-control.md` | When access changes |
| **Incident Response Runbook** | `docs/runbooks/incident-response.md` | When an incident happens; also annual review |
| **Change Management** | `docs/procedures/change-management.md` | Before deploying infrastructure |
| **Data Retention & Privacy** | `docs/compliance/data-retention.md` | When handling customer data |
| **Vendor Risk Assessment** | `docs/procedures/vendor-risk.md` | Before using new vendor/tool |
| **Unified Control Matrix** | `docs/compliance/ucm.xlsx` | For audits; detailed mapping |

---

## Contact & Escalation

| Need | Contact | Email | Response Time |
|------|---------|-------|-----------------|
| **Access request** | IT/Ops Lead | [ops@helixstax.com] | Same day |
| **Security question** | Security Lead | [security@helixstax.com] | 24 hours |
| **Incident / Breach** | On-Call + Security | Rocket.Chat #incidents | 15 min |
| **Compliance audit** | Compliance Officer | [compliance@helixstax.com] | 2 business days |
| **General question** | Your Manager | [DM in Rocket.Chat] | 24 hours |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | [DATE] | Initial quick reference |

---

**Print this. Post at your desk. Reference before taking risky actions.**

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation Lead) |
| **Date** | 2026-03-22 |
| **Last Reviewed** | 2026-03-22 |
| **Classification** | Internal |
| **Version** | 1.0 |
