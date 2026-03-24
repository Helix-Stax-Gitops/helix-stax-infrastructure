---
template: people-first-five-minutes
category: people
task_type: onboarding-guide
clickup_list: 06 Process Library > Onboarding
auto_tags: [first-day, quick-start, onboarding, people]
required_fields: [Welcome Message, Critical Links, First Steps, Emergency Contacts]
classification: internal
compliance_frameworks: [general]
review_cycle: per-use
author: Wakeem Williams
version: 1.0
---

# TEMPLATE: First Five Minutes Guide (New Team Member or Client)

Use this template as a quick-start guide for anyone brand new to Helix Stax or a client engagement. File in ClickUp or share via email/Slack to new arrivals before their first day. This should take 5 minutes to read and immediately give them something to do.

## TLDR

A 5-minute guide for brand-new team members or clients. Answers: "Where do I go?" "Who do I contact?" "What's my first task?" No deep technical content—just practical next steps and critical links.

---

## Welcome!

Welcome to [Helix Stax / Client Name]! We're excited to have you here. This is a rapid-fire guide to get you oriented in the first 5 minutes. Don't worry if this feels overwhelming—it will make sense soon.

**Your Name**: [Onboardee name]
**Start Date**: [Today's date]
**Your Role**: [e.g., "Backend Engineer", "Infrastructure Manager"]
**Your Manager**: [Manager name] — email them if anything is confusing

---

## Right Now: Next 5 Minutes

### Step 1: Accept Invitations (2 min)

Check your email for invitations to:

1. **Google Workspace** (corporate email)
   - Link: [Google Workspace login]
   - Action: Accept the invitation; set up 2FA
   - You'll receive 2 more emails with other tool invites

2. **ClickUp** (project management)
   - Link: [ClickUp workspace]
   - Action: Log in, poke around the Delivery or Platform space
   - Don't worry about understanding everything yet

3. **Rocket.Chat** (team communication)
   - Link: [Rocket.Chat server]
   - Action: Log in; post "Hi everyone!" in #introductions
   - You're now visible to the team

### Step 2: Bookmark These Links (2 min)

Bookmark all of these (Ctrl+D or Cmd+D) for easy access later:

| Name | Link | Why You Need It |
|------|------|-----------------|
| **Company Website** | https://helixstax.com | Our public brand |
| **ClickUp Workspace** | [Your workspace URL] | All tasks and projects |
| **GitHub** | https://github.com/KeemWilliams | Our code |
| **Grafana Dashboards** | [Grafana URL, if applicable] | Monitoring & metrics |
| **Runbooks** | [Link to runbooks folder] | "How do I do X?" answers |
| **Docs Wiki** | [Link to docs] | Architecture, guides, policies |

### Step 3: Introduce Yourself (1 min)

Open **Rocket.Chat** and go to `#introductions` channel.

Post something like:
> "Hi everyone! I'm [Your Name], starting today as [Your Role]. I'm from [City/Location] and I'm excited to [brief reason you're here]. Looking forward to working with you all!"

Hit Enter. Done. You're now on everyone's radar and they'll likely welcome you back.

---

## Your First Day: Next Few Hours

### Check Your Email

You should have received:
- [ ] Rocket.Chat login details
- [ ] ClickUp invitation
- [ ] GitHub access (if applicable)
- [ ] Calendar invite for "Day 1 Orientation" (your manager scheduled this)
- [ ] Welcome email with more details

### Attend Day 1 Orientation Meeting

**[Manager will schedule this]**

Your manager will host a 1-hour "Day 1 Orientation" meeting. They will:
- Welcome you to the team
- Answer basic questions
- Walk you through tools (ClickUp, Rocket.Chat, etc.)
- Give you a list of people to meet over the next few days

**What to do**: Show up on time, ask questions, take notes.

---

## Your First Task: Today or Tomorrow

Don't dive into complex work yet. Instead, do this simple, guided task:

### Task: Explore ClickUp & Read Your Role Overview

**Time**: 15–30 minutes

1. **Open ClickUp**
2. **Go to**: 01 Platform > [Your Department] OR Delivery > [Your Client] (ask manager which)
3. **Look for**: A task labeled `[ONBOARDING] First Task: Explore ClickUp` or similar
4. **Read it**: The task has links to key docs for your role
5. **Complete it**: Just click "Mark Complete" when done
6. **Ask questions**: If anything is confusing, ask your manager or post in Rocket.Chat `#[your-team]`

This first task is designed to be non-risky and help you understand how we organize work.

---

## Critical Links (Bookmark These!)

### Communication & Collaboration

| Tool | Link | What It's For |
|------|------|---------------|
| **Rocket.Chat** | [URL] | Team chat (internal only) |
| **ClickUp** | [URL] | Tasks, projects, assignments |
| **Google Meet** | [Google Calendar] | Meetings |
| **Email** | Gmail (via Google Workspace) | Official communication |

### Documentation & Knowledge

| Resource | Link | What It Has |
|----------|------|-----------|
| **Docs Wiki** | [URL] | Architecture, runbooks, guides |
| **GitHub** | https://github.com/KeemWilliams | All code |
| **Runbooks** | [Docs/runbooks folder] | "How do I...?" answers |
| **This Template** | [Onboarding folder in ClickUp] | Onboarding docs |

### Tools (Role-Dependent)

| Tool | Link | Why? |
|------|------|------|
| **Kubernetes Dashboard** (if eng) | [URL] | Cluster status |
| **Grafana** (if ops) | [URL] | Monitoring dashboards |
| **GitHub** | https://github.com/KeemWilliams | Code reviews, pull requests |

---

## Who to Ask If You Have Questions

| Question Type | Ask This Person | How to Reach Them |
|---------------|-----------------|-------------------|
| "How do I do X in ClickUp?" | Your manager | Rocket.Chat DM or email |
| "What's our architecture?" | Engineering lead / Architect | Email or Rocket.Chat channel |
| "How do I deploy code?" | Your team lead | Code review PR comments or Slack |
| "I found a bug!" | Report it in GitHub Issues or Rocket.Chat | Escalate to your manager if critical |
| "I don't understand a policy/process" | HR or Ops lead | Email or Rocket.Chat |
| **EMERGENCY — Production Down** | [On-call engineer] | [Pager link or emergency phone] |

---

## Your Calendar for This Week

Ask your manager to add these to your calendar:

| Day | Event | Duration | Purpose |
|-----|-------|----------|---------|
| **Today** | Day 1 Orientation | 1 hour | Welcome + tool setup |
| **Tomorrow (Day 2)** | 1-on-1 with [Manager] | 30 min | Check in, questions |
| **Wed (Day 3)** | Meet [Team Lead 1] | 30 min | Intro to your team |
| **Thu (Day 4)** | Meet [Team Lead 2] | 30 min | Intro to another team |
| **Fri (Day 5)** | Week 1 Wrap-Up with Manager | 30 min | How's it going? Next steps |

---

## What NOT to Do Yet

- **Don't deploy anything** to production (wait until you have explicit permission)
- **Don't change critical configs** without approval
- **Don't share passwords or credentials** via email or Slack (use OpenBao or secure link)
- **Don't worry about understanding everything** — you have weeks to learn
- **Don't be shy about asking questions** — we expect you to ask lots

---

## Keyboard Shortcuts & Productivity Tips

### ClickUp

| Shortcut | Action |
|----------|--------|
| `Ctrl+K` (Mac: `Cmd+K`) | Quick search for any task |
| `Ctrl+Shift+N` (Mac: `Cmd+Shift+N`) | Create new task |
| Click `Comments` tab | See task discussion thread |

### Rocket.Chat

| Shortcut | Action |
|----------|--------|
| `@[name]` | Mention someone (they'll get notified) |
| `#[channel-name]` | Link to a channel |
| `Shift+Enter` | Line break in message (don't send yet) |
| `/remind [message] in 2 hours` | Set a reminder |

### GitHub

| Shortcut | Action |
|----------|--------|
| `?` (while on GitHub) | Open keyboard shortcut menu |
| `g` then `p` | Go to pull requests |
| `c` | Create new issue |

---

## Your First Week Goals

By the end of Week 1, you should:

- [ ] Have access to all required tools (email, ClickUp, Rocket.Chat, GitHub)
- [ ] Know your manager and key team members (names & roles)
- [ ] Understand the ClickUp workspace structure
- [ ] Know where to find documentation (Docs Wiki, Runbooks)
- [ ] Completed your first simple task (without breaking anything)
- [ ] Know how to ask for help
- [ ] Know the critical escalation path (who to call if production breaks)

You don't need to understand everything. Learning on the job is expected.

---

## Common Questions

### "I don't have access to [tool]"
**Answer**: Email your manager or post in Rocket.Chat `#[team]`. Access is usually provisioned within 24 hours.

### "I can't log in"
**Answer**:
1. Check your email for the invitation link
2. Reset your password if needed
3. Try using your Google Workspace account
4. Contact IT/Ops: [IT contact]

### "What's the company's security policy?"
**Answer**: See `docs/security-policy.md` in the wiki (or ask your manager for the link). TL;DR: Use strong passwords, enable 2FA, don't share credentials via email.

### "When should I be online? What time zone?"
**Answer**: Ask your manager. Different roles have different expectations (some are 9–5, some are async).

### "Who should I be paired with for training?"
**Answer**: Your manager will assign a mentor/buddy for your role. They'll be your go-to person for role-specific questions.

---

## Emergencies & Escalation

### If Something Breaks in Production

1. **Stay calm**
2. **Don't restart or delete anything** without guidance
3. **Post in Rocket.Chat** `#incidents` with:
   - What's broken (be specific)
   - When it broke
   - What you last did (if applicable)
4. **Tag on-call engineer** or escalate to manager
5. **Wait for instructions** — don't make it worse

### If You Find a Security Issue

**Do NOT post in public Slack/Rocket.Chat channels**

1. Email [Security Contact]: [email]
2. Or DM a manager immediately
3. Describe the issue (no details needed yet)
4. We'll investigate and advise

---

## Random Tips to Succeed

1. **Take notes** — write down important stuff (tools, processes, people's names)
2. **Ask "dumb" questions** — everyone did on their first day. We expect it.
3. **Read the runbooks** — "How do I...?" questions are answered there first
4. **Watch others** — observe how experienced team members structure their work
5. **Be kind to yourself** — you're learning a lot. It will slow down after Week 2.
6. **Check Rocket.Chat daily** — team announcements happen there
7. **Show up on time** — punctuality goes a long way with a new team

---

## Next Steps (After This Guide)

1. ✅ **Now**: Read this guide (you're doing it!)
2. ✅ **Today**: Accept tool invitations
3. ✅ **Today**: Introduce yourself in Rocket.Chat
4. ✅ **Today**: Attend Day 1 Orientation with your manager
5. ✅ **Tomorrow**: Complete your first task
6. ✅ **This week**: Meet your team and key people
7. ✅ **Week 2**: Start contributing to actual projects

---

## Contact Sheet (Print This or Bookmark)

| Role | Name | Email | Rocket.Chat | Phone |
|------|------|-------|-------------|-------|
| **Your Manager** | [Name] | [email] | @[username] | [phone] |
| **Your Team Lead** | [Name] | [email] | @[username] | [phone] |
| **IT/Ops Support** | [Name] | [email] | @[username] | [phone] |
| **HR/People** | [Name] | [email] | @[username] | [phone] |
| **On-Call Eng** | See PagerDuty | — | — | [Pager] |

---

## Final Note

You were hired because we believe in you. Be patient with yourself, ask questions, and contribute as soon as you're ready.

**Welcome to the team!**

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
