# Gemini Deep Research: Communication Stack (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into two separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These two tools form the communication stack at Helix Stax:

- **Rocket.Chat**: Self-hosted team and client communication platform, replacing Slack and Telegram. Handles internal team chat, client-facing channels, monitoring alert notifications, and agent-to-human escalation. Chosen for OIDC SSO with Zitadel, rich REST and Realtime API, webhook integrations with n8n and Alertmanager, and guest access for client channels.
- **Postal**: Self-hosted transactional email server. All system-generated email — monitoring alerts from Alertmanager, user notifications from Grafana, account emails from Zitadel, form submissions from the website, workflow emails from n8n, and account invitations from Outline and Backstage — routes through Postal. Google Workspace handles business email (team@helixstax.com). Postal handles everything programmatic.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (helix-stax-cp: 178.156.233.12 cpx31 ash-dc1 control plane; helix-stax-vps: 5.78.145.30 cpx31 hil-dc1 role TBD)
- **Identity**: Zitadel as OIDC provider for SSO (primary login method for both)
- **Rocket.Chat domain**: chat.helixstax.net via Traefik IngressRoute
- **Postal domain**: mail.helixstax.net (Postal UI), sending domains: helixstax.com and helixstax.net
- **Ingress**: Traefik with TLS termination, behind Cloudflare
- **Rocket.Chat database**: MongoDB (NOT CloudNativePG; needs a MongoDB operator or standalone deployment on K3s)
- **Postal database**: MariaDB (Postal's native requirement — NOT CloudNativePG; needs separate MariaDB deployment)
- **Cache**: Valkey (Redis-compatible) — Postal uses Redis for job queues
- **DNS**: Cloudflare manages all DNS records — SPF, DKIM, DMARC, MX for both domains
- **Monitoring**: Alertmanager → Rocket.Chat webhook for infrastructure alerts
- **Automation**: n8n ↔ Rocket.Chat (both directions); Postal webhook events → n8n → Rocket.Chat
- **CI/CD**: ArgoCD and Devtron posting deploy notifications to Rocket.Chat channels
- **Security**: CrowdSec alerting via Rocket.Chat webhook
- **Postal coexistence**: Google Workspace for business email (inbound + team mailboxes), Postal for transactional only (outbound only)
- **Postal consumers**: Alertmanager, Grafana, Zitadel, n8n, Outline, Backstage — all get dedicated SMTP credentials
- **Port requirements**: Postal needs port 25 open on the K3s node for outbound delivery — Hetzner firewall rules required

---

## What I Need Researched

### SECTION A: Rocket.Chat

#### A1. REST API Reference
- API base URL: `/api/v1/` — authentication methods: `X-Auth-Token` + `X-User-Id` headers vs OAuth tokens
- Auth endpoints: `POST /api/v1/login`, `POST /api/v1/logout`, `GET /api/v1/me`
- Channels: `GET /api/v1/channels.list`, `POST /api/v1/channels.create`, `GET /api/v1/channels.info`, `POST /api/v1/channels.invite`
- Rooms: `GET /api/v1/rooms.get` — difference between channels, groups (private), direct messages, omnichannel
- Messages: `POST /api/v1/chat.postMessage` — full payload schema (roomId, channel, text, attachments, blocks)
- Message attachments: color, title, text, fields, image_url, thumb_url, footer — complete schema
- Message blocks (KitUI): button, section, divider, image — for interactive messages
- Users: `GET /api/v1/users.list`, `POST /api/v1/users.create`, `POST /api/v1/users.setActiveStatus`
- Groups (private channels): create, invite, kick, archive
- Direct messages: `POST /api/v1/dm.create`, posting to a DM
- Pagination: `count`, `offset` params, `total` in response
- Rate limiting: documented limits, headers returned, backoff strategy
- Realtime API (WebSocket): `ddp` protocol — subscribe to room messages, user status, notifications

#### A2. Deployment on K3s
- Helm chart: `rocketchat/rocketchat` official chart — values to override for our setup
- MongoDB: Rocket.Chat requires MongoDB — options: Bitnami MongoDB chart, MongoDB Community Operator, or standalone StatefulSet; which is most maintainable on K3s at small scale
- MongoDB connection string format: `MONGO_URL` and `MONGO_OPLOG_URL` env vars
- Replica set requirement: why Rocket.Chat requires a MongoDB replica set even for single-node, how to configure
- Kubernetes resources: Deployment (or StatefulSet?), Service, ConfigMap, Secret, IngressRoute
- Environment variables: `ROOT_URL`, `PORT`, `MONGO_URL`, `MONGO_OPLOG_URL`, `DEPLOY_PLATFORM=helm-chart`
- Resource requests/limits: realistic values for a small team (10-20 users)
- WebSocket support in Traefik: IngressRoute configuration for `Upgrade: websocket` headers
- Persistent storage: MongoDB PVC sizing, backup considerations
- ArgoCD Application manifest: sync waves (MongoDB first, then Rocket.Chat)
- Startup order: Rocket.Chat fails if MongoDB isn't ready — init container or retry pattern
- File uploads: where uploaded files are stored (GridFS in MongoDB vs external S3) — MinIO integration option

#### A3. OIDC: SSO with Zitadel
- Rocket.Chat OAuth2/OIDC configuration: Admin -> Administration -> OAuth -> Add custom OAuth
- Required fields in Rocket.Chat custom OAuth setup: Name, Enable, Client ID, Client Secret, Authorization URL, Token URL, Token Sent Via, Identity Token Sent Via, User Info URL, Scope, Login Style
- Zitadel-specific URLs for each OAuth field (using `auth.helixstax.net`)
- Redirect URI format: exact callback URL Rocket.Chat registers
- Claim mapping: mapping OIDC `name`, `email`, `picture` claims to Rocket.Chat user fields
- Role/group sync: mapping Zitadel groups to Rocket.Chat roles via `roles_claim` or custom field
- Auto-provisioning: creating Rocket.Chat accounts on first OIDC login
- Making OIDC the default login method: hiding username/password form
- Admin account bootstrap: how to ensure at least one admin exists before OIDC is fully configured
- SSO logout: back-channel logout or redirect to Zitadel logout endpoint

#### A4. Channel Management
- Channel naming conventions: `#ops-alerts`, `#devops`, `#client-{name}`, `#general`
- Default channels: setting which channels new users auto-join on account creation
- Channel types: public (`c`), private group (`p`), direct (`d`), omnichannel livechat — when to use each
- Read-only channels: creating announcement channels that only admins can post to
- Channel retention policies: auto-purge old messages (compliance, storage management)
- Pinning messages: API call to pin important messages in a channel
- Channel notifications: per-channel notification preferences (alerts channel should notify even on DND)
- Archiving channels: how to archive vs delete, recovering archived channels

#### A5. Integrations: Incoming Webhooks
- Creating an incoming webhook in Rocket.Chat admin: name, channel, script option
- Incoming webhook URL format: `https://chat.helixstax.net/hooks/{id}/{token}`
- Payload format: `{ "text": "...", "attachments": [...] }` — full schema
- Rich message formatting: markdown support, attachment colors, fields layout
- **Alertmanager integration**: configuring Alertmanager `receivers` with `rocket_chat_configs` or generic webhook receiver — payload mapping, alert grouping, severity colors
- **n8n integration**: n8n HTTP Request node sending formatted messages to Rocket.Chat incoming webhook
- **ArgoCD integration**: ArgoCD notification service sending sync status to `#ops-deployments` channel
- **Devtron integration**: Devtron build/deploy notifications to Rocket.Chat
- **CrowdSec integration**: CrowdSec bouncer or notification plugin sending security events to `#sec-alerts`
- Custom scripts on incoming webhooks: processing payload with JavaScript to format messages

#### A6. Integrations: Outgoing Webhooks
- Creating an outgoing webhook: trigger words, channel scope, URLs to call
- Outgoing webhook payload schema: what Rocket.Chat sends to the external URL
- Verifying the request: token field in payload for authentication
- n8n as outgoing webhook target: receiving Rocket.Chat messages in n8n, routing by channel or trigger word
- Use cases: `/commands` that trigger n8n workflows, logging channel messages for compliance, escalation routing
- Response handling: can the outgoing webhook response post back to the channel?

#### A7. Bots and Notification Automation
- Creating a bot user in Rocket.Chat: bot flag, bot permissions, appropriate roles
- Generating a bot API token: `X-Auth-Token` + `X-User-Id` for the bot user
- Bot posting messages: `POST /api/v1/chat.postMessage` from a bot account
- Alert notification bot: receives Alertmanager webhooks, formats and posts to `#ops-alerts` with severity color coding
- Deployment notification bot: posts ArgoCD sync results with success/failure emoji and diff link
- On-call bot: posting escalation messages to specific users via DM when alert fires
- Slash commands: registering custom slash commands that call n8n workflows
- Realtime API for bots: subscribing to room stream for interactive bot responses

#### A8. Client Guest Access
- Guest users in Rocket.Chat: what the guest role can and cannot do
- Inviting a client to a specific channel without exposing other channels
- Guest user limits: any license restrictions on guest count in Community edition
- Omnichannel Livechat: separate from guest access — when to use Livechat vs a private channel for clients
- Client channel setup: `#client-{company}` private channel, client as guest member
- Hiding internal channels from guests: ensuring guests only see their designated channels
- Guest expiration: can guest access be time-limited?

#### A9. Administration: Users, Roles, and Audit
- Admin panel key sections: Users, Rooms, Integrations, OAuth, Email, Push, Logs
- Roles: admin, moderator, user, guest, anonymous, bot — permissions matrix
- Custom roles: creating a "client" role with restricted permissions
- Email configuration: Rocket.Chat outbound email via Postal SMTP — `SMTP_Host`, `SMTP_Port`, `SMTP_Username`, `SMTP_Password` env vars or admin panel settings
- Push notifications: mobile app push via Rocket.Chat Cloud gateway — self-hosted push gateway option, env vars
- Audit log: where to find it, what events are logged (login, message edit/delete, room create)
- Admin REST API: endpoints for user management and config automation
- Rate limiting admin: configuring per-user rate limits to prevent abuse

#### A10. Monitoring and Troubleshooting
- Prometheus metrics: Rocket.Chat exposes `/metrics` endpoint — how to enable and configure
- Key metrics: active users, messages per minute, WebSocket connections, MongoDB query time, queue depth
- Grafana dashboard: community dashboard ID for Rocket.Chat metrics
- Loki log shipping: Rocket.Chat logs to stdout in K3s, Promtail picks up and ships to Loki
- Troubleshooting WebSocket issues behind Cloudflare + Traefik:
  - Cloudflare WebSocket proxying: ensure it's enabled (it is by default on proxied records)
  - Traefik WebSocket: `Upgrade` header forwarding in IngressRoute middlewares
  - Common symptom: chat connects then immediately disconnects — check `rootUrl` mismatch
- OIDC SSO failures: "OAuth app not found", redirect URI mismatch, clock skew between Zitadel and Rocket.Chat
- MongoDB replica set issues: Rocket.Chat won't start without oplog access — how to verify replica set is healthy
- High memory: MongoDB memory usage — WiredTiger cache size tuning (`--wiredTigerCacheSizeGB`)
- Message delivery failure: outgoing webhook not firing — check webhook logs in admin panel
- Push notification not delivered: gateway connectivity, App ID mismatch, certificate issues

---

### SECTION B: Postal

#### B1. REST API Reference
- API base URL: `/api/v1/` — authentication: `X-Server-API-Key` header (per-server API key)
- Messages API: `POST /api/v1/send/message` — full payload (to, from, subject, html_body, text_body, attachments, headers, reply_to, cc, bcc, tag)
- Send raw message: `POST /api/v1/send/raw` — sending a pre-built MIME message
- Message status: `GET /api/v1/messages/{id}` — checking delivery status, bounce info
- Message deliveries: delivery attempts, timestamps, SMTP response codes
- Domains API: listing configured sending domains
- Servers API: listing mail servers in an organization
- Credentials API: managing SMTP credentials via API
- Webhook event payload: what Postal sends on delivery, hard bounce, soft bounce, spam complaint, click, open events — full JSON schema
- Rate limits: any documented API rate limits

#### B2. Deployment on K3s
- Postal's architecture components: web UI, worker, SMTP server, Cron — which run as separate containers or a single image
- Docker image: `ghcr.io/postalserver/postal` — which tag to pin, how versions work
- MariaDB requirement: deploying MariaDB on K3s — Bitnami MariaDB Helm chart values for Postal compatibility (charset utf8mb4, collation, explicit db/user creation)
- MariaDB connection env vars: `POSTAL_DATABASE_HOST`, `POSTAL_DATABASE_USERNAME`, `POSTAL_DATABASE_PASSWORD`, `POSTAL_DATABASE_NAME`
- Valkey (Redis) connection: `POSTAL_REDIS_HOST`, `POSTAL_REDIS_PORT`, `POSTAL_REDIS_PASSWORD` or connection URL format
- Full environment variable reference: all required and optional Postal env vars including `POSTAL_WEB_HOST`, `POSTAL_RAILS_SECRET_KEY`, `POSTAL_SMTP_SERVER_ENABLE`, `POSTAL_SMTP_SERVER_PORT`, etc.
- `postal.yml` config file: full annotated example covering database, redis, SMTP, logging, DNS, webhooks
- Kubernetes manifest: Deployment (or multiple Deployments for web + worker + cron), Services, ConfigMap (postal.yml), Secrets
- Port requirements: port 25 (SMTP inbound/outbound delivery), 587 (submission), 2525 (alternative submission), 443 (web UI) — how to expose port 25 via Traefik or hostPort
- Hetzner firewall: opening port 25 outbound from the worker node — critical for email delivery
- NodePort or hostNetwork for SMTP: why port 25 typically can't go through Traefik without TCP passthrough — configuration options
- Traefik TCP IngressRoute for port 25 and 587: STARTTLS passthrough vs termination
- Postal initialization: `postal initialize` command, `postal initialize-config`, admin user creation
- ArgoCD Application manifest: sync waves (MariaDB first, Valkey ready check, then Postal)

#### B3. DNS Setup in Cloudflare
- MX records: should Postal have MX records for helixstax.com and helixstax.net? (Only if receiving inbound — clarify for transactional-only setup)
- SPF records: `TXT` record at domain root — correct SPF syntax for Postal sending via Hetzner IP (`v=spf1 ip4:178.156.233.12 ip4:5.78.145.30 include:_spf.google.com ~all`)
- DKIM: how Postal generates DKIM keys, where to get the public key for DNS, `TXT` record format (`postal._domainkey.helixstax.com`)
- DMARC: `TXT` record at `_dmarc.helixstax.com` — recommended policy for transactional sending (`p=quarantine` vs `p=reject`), `rua` report address
- Return-Path domain: `_returnpath.helixstax.com` CNAME for bounce tracking
- Click/open tracking: CNAME for Postal's tracking domain (`track.helixstax.com` -> Postal)
- PTR record: reverse DNS for the sending IP — how to set PTR on Hetzner Cloud IPs (crucial for deliverability)
- Cloudflare proxy considerations: SMTP ports should NOT go through Cloudflare proxy — which records need "DNS only" (grey cloud)
- SPF alignment: ensuring `MAIL FROM` domain aligns with SPF for DMARC pass
- DKIM alignment: ensuring `From:` header domain aligns with DKIM signing domain

#### B4. Organizations, Servers, and Credentials
- Postal data model: Organization -> Server -> Credential (SMTP user)
- Creating an organization via CLI: `postal make-org`
- Creating a mail server within an organization: UI steps vs CLI
- SMTP credential creation: per-service credentials (one for Alertmanager, one for Grafana, one for Zitadel, etc.)
- SMTP credential format: username, password, connection string
- SMTP connection string for each consumer: `smtp://postal-user:password@mail.helixstax.net:587`
- API key per server: how to generate and manage server API keys for programmatic sending
- Sending domains: adding helixstax.com and helixstax.net as verified sending domains — DNS verification steps in Postal UI

#### B5. Per-Service SMTP Configuration
- **Alertmanager**: `smtp_configs` in `alertmanager.yml` — `from`, `to`, `smarthost`, `auth_username`, `auth_password`, `require_tls`
- **Grafana**: `[smtp]` section in `grafana.ini` or env vars (`GF_SMTP_ENABLED`, `GF_SMTP_HOST`, `GF_SMTP_USER`, `GF_SMTP_PASSWORD`, `GF_SMTP_FROM_ADDRESS`)
- **Zitadel**: SMTP settings in Zitadel console for system email (password reset, verification) — env vars or API config
- **n8n**: Email Send node configuration — SMTP credentials, from address
- **Outline**: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_NAME`, `SMTP_FROM_EMAIL` env vars
- **Backstage**: Backstage notification plugin SMTP config (if used)
- **Rocket.Chat**: outbound email configuration via Postal for Rocket.Chat notifications
- Each service should use a dedicated Postal SMTP credential — never share credentials between services
- Recommended "from" addresses: `alerts@helixstax.net`, `grafana@helixstax.net`, `auth@helixstax.com`, `noreply@helixstax.com`

#### B6. Webhook Events and Delivery Tracking
- Configuring webhooks in Postal: per-server webhook URL (pointing to n8n)
- Webhook event types: `MessageDelivered`, `MessageBounced`, `MessageHeld`, `MessageDelayed`, `SpamComplaint`, `DomainDNSError`
- Webhook payload schema: `event`, `timestamp`, `message` object (id, to, from, subject, tag), `details` object
- Verifying webhook authenticity: signature header, HMAC verification in n8n
- n8n webhook node for Postal events: routing by event type, handling bounce notifications
- Bounce handling workflow: Postal fires bounce webhook -> n8n -> logs to ClickUp or Rocket.Chat alert
- Using `tag` field: tagging outbound emails by service (e.g., `tag: "alertmanager"`) for filtering in webhooks and analytics
- Message retention: how long Postal keeps message logs — configuring retention period

#### B7. IP Warming and Deliverability
- Why IP warming matters: fresh Hetzner IP has no reputation — ISPs throttle unknown IPs
- IP warming schedule: typical 2-4 week ramp-up plan for transactional email volume
- Hetzner IP reputation check: how to check if Hetzner's IP block is on any blacklists before starting
- Tools for checking deliverability: MXToolbox, Mail-tester.com, Google Postmaster Tools — how to use each
- Gmail Postmaster Tools setup: registering helixstax.com for domain reputation monitoring
- Blacklist monitoring: checking MTA blocklists (Spamhaus ZEN, Barracuda, SORBS) — how to delist
- Soft bounce vs hard bounce: how Postal handles each, retry behavior, auto-suppression
- Volume limits: keeping transactional volume low (under 100/day initially) during warmup

#### B8. HTML Email Templates
- Postal's built-in template support: does Postal have a template engine? (No — templates are per-application)
- Recommended approach: create HTML templates in n8n workflows or per-service, send rendered HTML via Postal SMTP
- Alert email template: clean HTML for Alertmanager alerts — subject line format, body with severity, description, runbook link, silence link
- Minimal HTML email boilerplate: table-based layout that renders in Gmail, Outlook, Apple Mail
- Plain-text alternative: always include `text/plain` part alongside `text/html`
- Unsubscribe header: `List-Unsubscribe` header for transactional email compliance (CAN-SPAM)
- Email footer: required legal elements for commercial email (company name, address)
- Brand colors: using Helix Stax brand in email headers (logo, primary color)

#### B9. Google Workspace Coexistence
- Sending domain separation: Google Workspace owns `@helixstax.com` MX for business email; Postal sends FROM `@helixstax.com` but does NOT receive inbound
- SPF merging: single SPF record at `helixstax.com` must include both Google and Postal sending IPs — `v=spf1 include:_spf.google.com ip4:178.156.233.12 ip4:5.78.145.30 ~all` (max 10 DNS lookups)
- DKIM coexistence: Google uses `google._domainkey.helixstax.com`; Postal uses `postal._domainkey.helixstax.com` — different selectors, no conflict
- DMARC with dual senders: both Google and Postal must pass SPF or DKIM for DMARC to not reject — alignment requirements
- When to use each: business email (human-to-human) -> Google Workspace; transactional (system-generated) -> Postal
- Avoiding confusion: using `noreply@helixstax.com` from Postal so recipients know it's automated; human from addresses on Google Workspace

#### B10. Monitoring and Troubleshooting
- Postal admin dashboard: delivery rates, bounce rates, held messages, queue depth — where to find in UI
- Prometheus metrics: does Postal expose `/metrics`? If not, what to monitor via blackbox exporter or log parsing
- Key metrics to alert on: bounce rate > 5%, delivery queue depth > 100, held messages (spam flagged)
- Log output in K3s: Postal logs to stdout — shipping to Loki via Promtail, key log patterns to alert on
- Common issues:
  - Port 25 blocked: Hetzner or upstream ISP blocking outbound port 25 — checking and requesting unblock
  - SPF failure: `550 SPF check failed` — diagnosing with `dig TXT helixstax.com`, MXToolbox SPF test
  - DKIM failure: missing DNS record, key mismatch — verifying with `opendkim-testkey` or online DKIM checker
  - DMARC rejection: alignment failure — using DMARC analyzer to read `rua` reports
  - Delivery deferred: temporary 4xx from recipient MTA — Postal retry behavior, when to investigate
  - Message held as spam: Postal's built-in spam filter flagging your own alerts — whitelist configuration
  - MariaDB connection refused: charset/collation mismatch, max connections exhausted
  - Valkey connection timeout: Postal worker queue stalling — checking Redis connection from worker pod
  - Web UI not loading: Rails secret key missing, database migration not run
- Gotchas: Port 25 ISP blocking, SPF 10-lookup limit, MariaDB charset, DMARC alignment pitfalls

---

### Best Practices & Anti-Patterns
- What are the top 10 best practices for this tool in production?
- What are the most common mistakes and anti-patterns? Rank by severity (critical → low)
- What configurations look correct but silently cause problems?
- What defaults should NEVER be used in production?
- What are the performance anti-patterns that waste resources?

### Decision Matrix
- When to use X vs Y (for every major decision point in this tool)
- Clear criteria table: "If [condition], use [approach], because [reason]"
- Trade-off analysis for each decision
- What questions to ask before choosing an approach

### Common Pitfalls
- Mistakes that waste hours of debugging — with prevention
- Version-specific gotchas for current releases
- Integration pitfalls with other tools in our stack
- Migration pitfalls when upgrading

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- CLI commands with examples
- Configuration patterns with copy-paste snippets
- Troubleshooting decision tree (symptom → cause → fix)
- Integration points with other tools in our stack
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Full API/CLI reference (every flag, every option)
- Complete configuration schema with all fields documented
- Advanced patterns and edge cases
- Performance tuning parameters
- Security hardening checklist
- Architecture diagrams (ASCII)

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (helix-stax-cp: 178.156.233.12, helix-stax-vps: 5.78.145.30), domains (helixstax.com, helixstax.net), and service names
- Annotated YAML/JSON manifests
- Before/after troubleshooting scenarios
- Step-by-step runbooks for common operations
- Integration examples with our specific stack (K3s, Traefik, Zitadel, CloudNativePG, etc.)

Use `# Tool Name` as top-level headers to separate each tool's output for splitting into separate skill directories.

Be thorough, opinionated, and practical. Include actual commands, actual configs, and actual error messages. Do NOT give theory — give copy-paste-ready content for a K3s cluster on Hetzner behind Cloudflare.

```markdown
# Rocket.Chat

## Overview
[2-3 sentence description of what Rocket.Chat does and why we use it]

## Deployment on K3s
### MongoDB Setup
[Replica set config, Helm chart values]
### Rocket.Chat Helm Values
[Key overrides]
### Environment Variables
[Complete env var reference]
### Traefik IngressRoute with WebSocket
[IngressRoute manifest with WS middleware]
### ArgoCD Application Manifest
[Sync waves example]

## OIDC with Zitadel
### Admin Panel Configuration
[Step-by-step OAuth setup]
### Zitadel Client Setup
[Required settings, redirect URI]
### Claim Mapping
[Field mapping config]
### Role Sync
[Group-to-role mapping]

## REST API Reference
### Authentication
[Token format, login curl]
### Posting Messages
[chat.postMessage with attachments example]
### User Management
[Create, list, deactivate]
### Channel Management
[Create, invite, archive]

## Realtime API (WebSocket)
### Connection
[DDP protocol example]
### Subscribing to Room Messages
[Subscription payload]

## Incoming Webhooks
### Creating a Webhook
[Admin steps + URL format]
### Payload Schema
[Full message payload]
### Alertmanager Integration
[receiver config]
### ArgoCD Integration
[notification config]
### n8n Integration
[HTTP Request node config]
### CrowdSec Integration
[Plugin or webhook config]

## Outgoing Webhooks
### Configuration
[Admin steps]
### n8n as Target
[Webhook -> n8n flow]

## Bots
### Creating a Bot User
[Steps + token generation]
### Alert Notification Bot
[Message format, severity colors]
### Slash Commands
[Registration + n8n call]

## Client Guest Access
### Guest Role Setup
[Permissions, channel isolation]
### Invite Flow
[How clients receive access]

## Administration
### Email via Postal
[SMTP env vars]
### Push Notifications
[Gateway config]
### Audit Logging
[Access and events]

## Monitoring
### Prometheus Metrics
[Enable metrics, scrape config]
### Grafana Dashboard
[Dashboard ID or import]
### Loki Integration
[Promtail config for Rocket.Chat logs]

## Troubleshooting
[Symptom -> cause -> fix for each issue]

## Gotchas
[WebSocket gotchas, MongoDB replica set requirement, Cloudflare proxy behavior]

---

# Postal

## Overview
[2-3 sentence description of what Postal does and why we use it]

## Deployment on K3s
### Architecture
[Component breakdown: web, worker, SMTP server, cron]
### MariaDB Setup
[Helm chart values, required config]
### Valkey Integration
[Redis connection config]
### Environment Variables
[Complete env var reference]
### postal.yml
[Full annotated config example]
### Port 25 Exposure
[hostNetwork, NodePort, or Traefik TCP — with config]
### Traefik IngressRoute (Web UI + SMTP)
[Manifests for HTTP and TCP routes]
### Postal Initialization
[CLI commands: initialize, make-org, admin user]
### ArgoCD Application Manifest
[Sync waves example]

## DNS Setup in Cloudflare
### SPF Record
[Exact TXT record for dual-sender setup]
### DKIM Record
[How to get key from Postal, DNS record format]
### DMARC Record
[Recommended policy and rua address]
### PTR Record
[How to set on Hetzner]
### Return-Path CNAME
[Bounce tracking setup]
### Click/Open Tracking CNAME
[Tracking domain config]

## Organizations, Servers, and Credentials
### Creating an Organization
[CLI command]
### Creating a Mail Server
[UI steps]
### SMTP Credentials per Service
[List of services with recommended usernames and from addresses]
### API Key Generation
[How to get server API key]

## Per-Service SMTP Config
### Alertmanager
[alertmanager.yml smtp_configs block]
### Grafana
[grafana.ini or env vars]
### Zitadel
[SMTP settings]
### n8n
[Email Send node config]
### Outline
[SMTP env vars]
### Rocket.Chat
[SMTP settings for outbound notifications]

## REST API Reference
### Sending a Message
[curl example with full payload]
### Checking Message Status
[curl example]
### Webhook Payload
[Full event schema]

## Webhook Integration with n8n
### Webhook Configuration
[Postal admin steps]
### n8n Webhook Receiver
[Workflow pattern]
### Bounce Handling
[Alert routing]

## Deliverability
### IP Warming Schedule
[Week-by-week ramp plan]
### Blacklist Checking
[Tools and process]
### Google Postmaster Tools
[Setup steps]
### Spam Content Checklist
[What to avoid in alert emails]

## Email Templates
### Alert Email Template
[HTML boilerplate with severity styling]
### Required Compliance Elements
[Unsubscribe, footer]

## Google Workspace Coexistence
### SPF Merge
[Combined SPF record]
### DKIM Coexistence
[Selector separation]
### DMARC Alignment
[Both senders passing]
### When to Use Each
[Decision table]

## Monitoring
### Key Metrics
[Bounce rate, queue depth, delivery rate]
### Loki Log Shipping
[Promtail config + key patterns]
### Alerting Rules
[Prometheus alerting rules if applicable]

## Troubleshooting
[Symptom -> cause -> fix for each issue]

## Gotchas
[Port 25 ISP blocking, SPF 10-lookup limit, MariaDB charset, DMARC alignment pitfalls]
```

Be thorough, opinionated, and practical. Include actual API curl commands, actual Helm values, actual Traefik IngressRoute YAML with WebSocket middleware, actual Alertmanager receiver configs, actual DNS record values, actual `postal.yml` config, actual per-service SMTP configs (Alertmanager, Grafana, Zitadel, n8n, Outline, Rocket.Chat), and actual Kubernetes manifests with TCP IngressRoute for SMTP. Do NOT give me theory — give me copy-paste-ready configs for Rocket.Chat on K3s with MongoDB + Zitadel OIDC, and Postal running on K3s behind Traefik sending from helixstax.com alongside Google Workspace.
