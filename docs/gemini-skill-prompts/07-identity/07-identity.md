# Gemini Deep Research: Identity and Workspace (Grouped Prompt)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are
Identity and workspace — Zitadel is the IdP for all services, Google Workspace is the business platform, they federate via SAML. This group covers two tightly-coupled layers that agents must understand together:

1. **Zitadel** — our identity provider and the single source of truth for authentication and authorization across the entire Helix Stax platform. It issues OIDC tokens and handles SAML federation so that Grafana, ArgoCD, Devtron, Harbor, Backstage, Outline, Rocket.Chat, MinIO Console, and Cloudflare Access all delegate login to Zitadel instead of managing their own users.
2. **Google Workspace** — Google Workspace Enterprise Standard is our business email, document collaboration, and identity foundation for the helixstax.com domain. It provides Gmail, Drive, Calendar, Groups, Meet, and the Google Cloud underpinning for Gemini API access. It also serves as a SAML identity provider federation point with Zitadel — staff log in to the Helix Stax platform with their Google accounts.

These two are grouped because the federation between them is the critical integration: Google Workspace authenticates staff (SAML to Zitadel), and Zitadel then issues OIDC tokens to all platform services. Agents configuring a new service's SSO must understand both what to configure in Zitadel (OIDC client) and what staff credentials flow through (Google → Zitadel → service). The Gemini CLI that agents use also connects to Google Cloud infrastructure tied to the same Google Workspace account.

## Our Specific Setup

### Zitadel
- **Deployment**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Database**: CloudNativePG (PostgreSQL) — Zitadel's backing store
- **Ingress**: Traefik IngressRoute CRDs → Cloudflare edge
- **Domains**: helixstax.com (public), helixstax.net (internal apps)
- **OIDC clients needed**: Grafana, ArgoCD, Devtron, Harbor, Backstage, Outline, Rocket.Chat, MinIO Console, Cloudflare Access
- **SAML**: Google Workspace federation (inbound IdP for staff login)
- **Secrets**: OpenBao + External Secrets Operator (no secrets in git)
- **CI/CD**: Devtron + ArgoCD (GitOps)
- **IaC**: OpenTofu + Helm

### Google Workspace
- **Plan**: Google Workspace Enterprise Standard
- **Primary domain**: helixstax.com
- **Admin email**: admin@helixstax.com
- **DNS**: All helixstax.com DNS records managed in Cloudflare (not Google's name servers)
- **Identity**: Zitadel is our primary OIDC/SAML IdP; Google Workspace federates WITH Zitadel
- **Email split**: Google Workspace (business email: @helixstax.com) + Postal (transactional email from platform services)
- **Gemini CLI**: Used by AI agents — needs Google Cloud project + API key/service account
- **Automation**: n8n handles most workflow automation and can call Google Workspace APIs
- **Internal apps**: On helixstax.net (separate domain, not managed by Google Workspace)
- **Team size**: Small (1-5 users initially, consulting firm model)

---

## What I Need Researched

---

# SECTION 1: Zitadel (Identity Provider)

### 1. CLI & API Reference
- Complete zitadel-tools CLI command set: what's available, what's not, when to use API directly
- Management API vs Auth API vs Admin API — which to use for which operations
- Authentication for API calls: personal access tokens, machine user tokens, service account JWTs
- API base URL patterns: `https://zitadel.helixstax.net/management/v1/` structure
- Common curl/httpie patterns for CRUD on projects, clients, users, roles, grants
- How to script bulk operations (creating multiple OIDC clients in CI)
- OpenTofu/Terraform Zitadel provider — available resources, example usage
- Rate limiting and pagination in the API

### 2. Deployment on K3s (Helm + CloudNativePG)
- Official Zitadel Helm chart: required values, chart repo URL, recommended version pinning
- CloudNativePG integration: how Zitadel connects to CNPG cluster (DSN format, user/db creation)
- Required environment variables and secrets (masterkey, database DSN) and how to inject via External Secrets Operator
- Traefik IngressRoute CRD example for Zitadel — TLS passthrough vs termination considerations
- Zitadel startup sequence: initialization, first-run bootstrap, creating the initial admin user
- Resource requests/limits for K3s single-worker setup
- Health check endpoints for Kubernetes liveness/readiness probes
- Upgrade procedure: Helm chart upgrade, database migration handling
- Configuring external domain (zitadel.helixstax.net) in Zitadel's own configuration

### 3. OIDC Client Configuration (Per Service)
- How to create an OIDC application in Zitadel: web app vs native app vs API vs machine user
- Client ID vs Client Secret — when each is needed, how to rotate secrets
- Redirect URI requirements: exact match vs wildcard, trailing slash gotchas
- For EACH service, provide: redirect URIs, grant types, scopes, PKCE requirements, and any service-specific notes:
  - **Grafana**: OAuth2 generic connector, team sync via groups claim
  - **ArgoCD**: OIDC connector, RBAC group mapping, CLI login flow (localhost redirect)
  - **Devtron**: OIDC configuration, admin vs developer role mapping
  - **Harbor**: OIDC mode, admin auto-onboard, group claim for project membership
  - **Backstage**: Zitadel auth provider plugin, sign-in resolver configuration
  - **Outline**: OIDC configuration, team provisioning
  - **Rocket.Chat**: OAuth2 custom provider, username claim mapping, avatar sync
  - **MinIO Console**: OIDC configuration, policy claim mapping to MinIO policies
  - **Cloudflare Access**: OIDC IdP configuration, service auth vs user auth

### 4. SAML Configuration (Google Workspace Federation)
- **Scenario A: Google Workspace as external IdP in Zitadel (OAuth/OIDC — preferred)**
  - Configure Google OAuth app in Google Cloud Console
  - Add Google as social/external IdP in Zitadel
  - Use case: let staff log in to Helix Stax platform services using their Google account
  - Scopes needed: openid, email, profile — what Zitadel requests from Google
  - JIT (Just-In-Time) provisioning: auto-creating Zitadel users on first Google SSO
  - Linking existing Zitadel users to Google identity
- **Scenario B: Zitadel as SP, Google Workspace as SAML IdP**
  - Setting up Zitadel as SP (Service Provider) consuming Google Workspace as IdP
  - Google Workspace SAML metadata import: entity ID, ACS URL, certificate
  - Attribute mapping: email, first name, last name, groups from Google
  - Testing SAML federation without breaking existing logins
- Which scenario makes more sense for a small consulting firm — recommendation with rationale
- User provisioning via SCIM: does Google Workspace support SCIM as SP? Zitadel SCIM provider setup

### 5. User Management (Organizations, Projects, Grants, Roles)
- Zitadel data model: Instance → Organization → Project → Application → Role hierarchy
- When to use multiple organizations vs a single org with multiple projects
- Creating and managing human users: invite flow, password reset, email verification
- Role management: defining custom roles in projects, assigning roles to users
- User grants: granting a user access to a project with specific roles
- Metadata: storing custom attributes on users (used in token claims via Actions)
- Groups/Teams concept in Zitadel — how services receive group membership in tokens
- Bulk user import: CSV or API-based user creation

### 6. Machine Users & Service Accounts
- Machine user vs human user — use cases for each
- Creating a machine user for CI pipelines (Devtron, n8n, ArgoCD)
- Personal access tokens (PATs): creating, scoping, expiry, rotation
- JWT profile keys: generating key pairs, uploading public key to Zitadel
- Authenticating as a machine user to the Management API
- Service account best practices: one per service, minimal scope, no shared tokens
- How to store machine user tokens in OpenBao and sync via External Secrets Operator

### 7. Actions v2 (Custom Logic on Auth Events)
- What Actions v2 can do: pre/post auth hooks, token enrichment, external HTTP calls
- Syntax: JavaScript-based, what APIs are available inside the action runtime
- Common use cases: adding custom claims to tokens, calling n8n webhook on login, logging to external system
- How to trigger an n8n workflow when a user logs in (webhook action)
- Enriching tokens with metadata fields (e.g., adding `org_id`, `team` claims)
- Debugging actions: how to see action execution logs and errors
- Limitations: execution timeout, allowed external hosts, no persistent state

### 8. Branding & MFA
- Custom login page branding: logo, colors, per-project theming
- Configuring a custom domain for the login page (login.helixstax.net vs zitadel.helixstax.net)
- MFA enforcement: making TOTP or passkey required for all users
- Passkeys (WebAuthn): configuration, device trust, fallback options
- TOTP: enforcing TOTP, grace period for enrollment
- Per-organization MFA policy vs instance-wide policy
- Session policies: idle timeout, max session age

### 9. Token Management (Access Tokens, Refresh Tokens, JWTs)
- Access token lifetime: recommended values per service type
- Refresh token configuration: rotation policy, absolute lifetime
- JWT claims: standard claims (sub, iss, aud) + Zitadel-specific claims structure
- Custom claims via Actions: adding roles, metadata, org info to tokens
- Token introspection endpoint: how services can validate opaque tokens
- JWKS endpoint: where services fetch public keys for JWT validation
- Revoking tokens: user logout, admin revocation, token blacklisting approach

### 10. Monitoring, Audit Logs & Troubleshooting
- Prometheus metrics endpoint: what metrics Zitadel exposes, key ones to alert on
- Grafana dashboard for Zitadel: community dashboards or building from scratch
- Audit log structure: where events are stored, how to query them
- Forwarding audit logs to Loki: log format, relevant fields to index
- Common OIDC errors and root causes:
  - `invalid_client` — client ID/secret mismatch
  - `redirect_uri_mismatch` — exact URI requirements
  - `invalid_grant` — expired auth code, PKCE failure
  - `access_denied` — role/grant missing
- Token introspection for debugging: using the introspect endpoint to decode opaque tokens
- OIDC discovery endpoint: `/.well-known/openid-configuration` fields
- Debugging Cloudflare Access + Zitadel auth failures: redirect loops, cookie issues
- Google Workspace SAML/OIDC debugging: checking assertion, attribute mapping errors

---

# SECTION 2: Google Workspace (Business Platform + Gemini Cloud)

### 1. Admin Console — Core Administration
- Admin SDK API vs Admin Console UI: when to use each, what's only available in UI
- User lifecycle management: create, suspend, delete, restore (30-day window), transfer data
- OU (Organizational Unit) structure for a small consulting firm: recommended OU design
- Groups vs OUs: when to use Google Groups vs OUs for policy application
- Admin roles: Super Admin vs custom roles, least-privilege admin setup
- Audit logs: Admin audit log, Login audit log — where to find them, how to export to SIEM or n8n
- Reports API: usage reports for storage, login activity, app usage — how to pull via API
- Directory API: programmatic user/group management via Admin SDK
- Service account impersonation: how to let a service account manage Workspace via domain-wide delegation
- Bulk operations: CSV import/export for users, groups — format and gotchas

### 2. DNS Records for helixstax.com in Cloudflare
- Complete set of required DNS records for Google Workspace: MX, SPF, DKIM, DMARC
  - MX records: exact values, priorities, TTL recommendations
  - SPF record: include:_spf.google.com + Postal's sending IPs, how to merge both senders correctly (avoid SPF record flattening issues, stay under 10 DNS lookup limit)
  - DKIM: how to generate and add the Google Workspace DKIM key in Cloudflare (TXT record at google._domainkey.helixstax.com)
  - DMARC: recommended policy for a new domain (p=none → p=quarantine → p=reject), monitoring with rua/ruf
- Coexistence of Google Workspace email with Postal (transactional):
  - Postal sends from a subdomain (e.g., mail.helixstax.com or notifications.helixstax.com) vs root domain
  - Separate DKIM selectors: Google's selector vs Postal's selector — no conflict
  - DMARC alignment: relaxed vs strict for subdomain transactional senders
- Google Workspace domain verification in Cloudflare: TXT record method
- Autoconfiguration records for email clients: autodiscover, autoconfig, SRV records

### 3. Zitadel + Google Workspace Federation (Cross-Reference)
- **Recommended: Google as external IdP in Zitadel (OAuth/OIDC)**
  - Configure Google OAuth app in Google Cloud Console (same project as Gemini API)
  - Add Google as social/external IdP in Zitadel
  - Staff login flow: staff goes to any platform service → redirected to Zitadel login → clicks "Login with Google" → Google authenticates → Zitadel issues OIDC token → service grants access
  - Scopes: openid, email, profile
  - JIT provisioning: auto-creating Zitadel user on first Google login, mapping Google email to Zitadel identity
- **Alternative: Zitadel as SP, Google as SAML IdP**
  - When this makes more sense (enterprise environments, Google admin control of all app access)
  - SAML app setup in Google Admin Console: entity ID, ACS URL for Zitadel
  - Attribute mapping: email, given_name, family_name from Google → Zitadel fields
- Recommendation for Helix Stax: which scenario, why, configuration steps for both Zitadel and Google Admin Console
- User provisioning via SCIM if applicable

### 4. Gemini CLI & Google Cloud Setup
- **Google Cloud project setup** for Helix Stax:
  - Create project, set billing account, enable necessary APIs
  - APIs to enable: Generative Language API (Gemini), Admin SDK, Drive API, Gmail API, Calendar API, Workspace Events API
  - Project-level vs org-level configuration
- **Gemini API access** for Claude Code agents and Gemini CLI:
  - API key vs service account credentials — which to use for CLI agents
  - Gemini CLI authentication: `gemini auth login` vs service account JSON
  - How to set GEMINI_API_KEY or GOOGLE_APPLICATION_CREDENTIALS for agent environments
  - Model access: which Gemini models are available on Enterprise vs API key access
  - Rate limits and quotas: requests per minute, tokens per minute — what to expect
  - Gemini Deep Research API: is this available programmatically or UI-only?
- **Service account setup**:
  - Create service account with minimum required permissions
  - Generate and store JSON key securely (in OpenBao, not in git)
  - Domain-wide delegation: when needed, which OAuth scopes to grant
  - Service account impersonation for Workspace API calls on behalf of users
- **Workload Identity Federation**: alternative to service account keys — how to configure for K3s workloads that need Google APIs without a JSON key file

### 5. Drive — File Organization for a Consulting Firm
- Shared Drive vs My Drive: why Shared Drives are required for business (no single-owner dependency)
- Recommended Shared Drive structure for a consulting firm:
  - Company Operations (internal docs, policies, SOPs)
  - Client Work (one folder per client, restricted sharing)
  - Templates (proposal templates, contract templates, report templates)
  - Marketing (brand assets, website content, social media)
- Drive permissions: how to structure sharing so client folders are isolated
- Drive API: how n8n or agents can read/write Drive files programmatically
  - Files.list, Files.get, Files.create, Files.update via Drive API v3
  - Service account access to Shared Drives: requires explicit membership
- Drive search operators for finding files via API

### 6. Gmail — Routing, Aliases, and Coexistence with Postal
- Gmail routing rules: how to route mail for specific addresses (e.g., support@helixstax.com → Rocket.Chat webhook via n8n)
- Aliases: admin@helixstax.com receiving mail for multiple aliases (info@, support@, hello@)
- Group email addresses: how Google Groups work as mailing lists (support@helixstax.com → all engineers)
- Forwarding rules: automated forwarding to n8n webhook for processing inbound email
- Gmail API: reading and sending email programmatically from n8n or agents
  - OAuth scopes for reading vs sending vs full access
  - Watch/push notifications: Gmail push to Pub/Sub → n8n trigger (vs polling)
- Postal coexistence:
  - Postal sends transactional email FROM platform services (Rocket.Chat notifications, Outline password resets)
  - Postal should use a subdomain (mail.helixstax.com) to keep Google Workspace reputation clean
  - How to configure reply-to headers so replies go to the Google Workspace inbox
  - SPF/DKIM alignment between Postal and Google in a shared-domain scenario
- Email retention: Vault vs Gmail native retention policies

### 7. Calendar — Resource Management & Automation
- Shared calendars: team calendar, client-facing availability calendar
- Calendar API for automation:
  - Creating events programmatically (n8n workflows for scheduling client calls)
  - Reading free/busy to check availability before booking
  - Calendar webhooks/push notifications (watch channels) for event changes → n8n
- Meet integration: auto-generating Meet links on calendar invite creation
- Working hours and time zones: setting organization-wide defaults

### 8. Groups — Team Management & Distribution Lists
- Google Groups vs Cloud Identity Groups: differences, when to use each
- Recommended groups for a consulting firm:
  - team@helixstax.com → all internal staff (distribution + security group)
  - clients@helixstax.com → client contacts (external-facing)
  - ops@helixstax.com → infra/ops alerts from Alertmanager/n8n
  - alerts@helixstax.com → monitoring alerts receiver (feeds into Gmail → n8n)
- Dynamic groups (Enterprise feature): auto-membership based on user attributes
- Groups API: programmatic group management, adding/removing members
- Collaborative inbox: using Groups as a shared inbox for support@ (vs Workspace email routing)
- Groups for access control: grant Drive folder access, Calendar access by group membership

### 9. Security — 2FA, Context-Aware Access, and DLP
- **2FA enforcement**:
  - Admin Console: enforce 2FA for all users, grace period for new users
  - Allowed 2FA methods: security keys (FIDO2) vs Google Authenticator vs backup codes
  - Enrollment reporting: how to check who hasn't enrolled
- **Context-Aware Access (Enterprise feature)**:
  - Access levels: define conditions (device trust, IP range, OS type)
  - Assign access levels to apps: require company-managed device to access Drive
  - Coexistence with Zitadel SSO: context-aware access applies before or after OIDC handoff?
- **DLP policies**:
  - Gmail DLP: scan outbound email for PII (SSNs, credit cards)
  - Drive DLP: scan files for sensitive content, restrict external sharing
  - Alert policies: DLP violations → Admin alert → n8n → Rocket.Chat
- **Login security**:
  - Less secure app access: should be disabled entirely
  - Third-party app access: OAuth app whitelisting, blocking unknown apps

### 10. API Automation via n8n & Agent Integration
- **Admin SDK via n8n**:
  - n8n Google Workspace nodes: which APIs have native n8n nodes vs HTTP Request nodes
  - Authentication in n8n: OAuth2 app vs service account — which is better for automation
  - Use cases: user onboarding (create user → add to groups → set up Drive folder → send welcome email)
  - Use cases: user offboarding (suspend → transfer Drive → revoke tokens → archive email)
  - Use cases: daily report of login activity → Rocket.Chat
- **Agent-level Google API access**:
  - How Claude Code agents or Gemini CLI agents call Google APIs (service account in OpenBao → ESO → pod env)
  - Gemini API calls from within K8s pods: Workload Identity Federation vs projected service account tokens
  - Rate limit handling: exponential backoff pattern for Google APIs
- **Workspace Events API**:
  - Push notifications for Drive, Calendar, Gmail changes → n8n webhook receiver
  - Pub/Sub vs direct webhook: which to use for n8n integration
- **Google Apps Script** (native automation):
  - When to use Apps Script vs n8n: in-Workspace automation vs cross-platform
  - Apps Script ↔ n8n integration: Apps Script calls n8n webhook, n8n calls Apps Script deployment
- **Backup of Workspace data**:
  - Google Vault: eDiscovery + retention for compliance — what it covers (Gmail, Drive, Chat, Meet)
  - Third-party backup for Workspace: is it needed at Enterprise Standard tier?

### 11. Compliance — Data Retention, Audit Logs, Vault
- **Google Vault**:
  - Matters and holds: how to put a legal hold on a user's data
  - Retention rules: default retention policy for Gmail, Drive, Chat
  - Export: how to export data for an audit or eDiscovery request
- **Audit logs**:
  - Admin audit log: every admin action logged, export to BigQuery or SIEM
  - Login audit log: all login events, including OAuth app access
  - Drive audit log: file access, sharing changes, downloads
  - Exporting to SIEM via n8n: Reports API polling vs Workspace Events API push
- **Data retention policies**:
  - Enterprise Standard includes Vault — use Vault retention rules
  - GDPR considerations: data residency (US vs EU), user data deletion requests
- **Compliance certifications**: what Google Workspace Enterprise Standard covers (SOC 2, ISO 27001, HIPAA BAA availability)

### 12. Cost Optimization & License Management
- **Enterprise Standard pricing**: per-user/month cost, what's included vs Business Starter/Standard/Plus
- **Features that justify Enterprise Standard** for a small consulting firm:
  - Vault (eDiscovery + retention), Advanced DLP, Context-Aware Access, Audit and reporting, Gemini for Workspace
- **License management**:
  - Assign licenses only to active users, how to suspend without losing data
  - Shared mailboxes: can you have an unattended account (noreply@helixstax.com) without a full license?
- **Storage management**:
  - Pooled storage model at Enterprise: all users share a pool
  - How to identify and clean up large files
- **Google Cloud billing**: separate from Workspace billing — how to track Gemini API costs vs Workspace costs

### 13. Google Workspace + Helix Stax Platform Integration (n8n Hub)
- n8n as the integration hub connecting Workspace to the rest of the Helix Stax stack:
  - Gmail → n8n: inbound email parsing, ticket creation in ClickUp
  - Calendar → n8n: meeting scheduled → create ClickUp task → notify Rocket.Chat
  - Drive → n8n: file uploaded by client → trigger Outline doc creation → notify team in Rocket.Chat
  - Admin SDK → n8n: new user created in Workspace → onboarding workflow (Zitadel account, Rocket.Chat invite, Outline invite)
  - Alertmanager → Gmail (ops@helixstax.com) as backup alert channel when Rocket.Chat is down
- Workspace as the business layer, Helix Stax platform (K3s) as the technical layer:
  - Which tools live in Workspace (Gmail, Drive, Calendar, Meet) vs platform (Rocket.Chat, Outline, Grafana)
  - Avoid duplication: don't run both Outline and Google Docs for the same purpose — decision criteria
  - Client-facing vs internal: clients interact via Google (Workspace) channel, team uses platform tools

---

## Required Output Format

Structure your response EXACTLY like this — it will be split into separate skill files for AI agents. Use `# Tool Name` as the top-level headers so the output can be mechanically split:

```markdown
# Zitadel

## Overview
[2-3 sentence description of what Zitadel does and why we use it]

## CLI & API Reference
### zitadel-tools CLI
[Commands with examples]
### Management API
[API patterns, authentication, curl examples]
### OpenTofu Provider
[Provider config, resource examples]

## K3s Deployment
### Helm Chart
[Chart repo, values file example, CloudNativePG integration]
### Secrets & Environment Variables
[How to inject masterkey and DSN via External Secrets Operator]
### Traefik IngressRoute
[CRD example]
### Bootstrap & First Run
[Initialization steps, admin user creation]

## OIDC Client Configuration
### Grafana
[redirect URIs, scopes, config snippet]
### ArgoCD
[redirect URIs, RBAC mapping, CLI flow]
### Devtron
[OIDC config]
### Harbor
[OIDC mode, group claims]
### Backstage
[Plugin config]
### Outline
[OIDC config]
### Rocket.Chat
[OAuth2 custom provider]
### MinIO Console
[OIDC + policy mapping]
### Cloudflare Access
[OIDC IdP config]

## Google Federation
### Recommended: Google as External IdP in Zitadel (OAuth/OIDC)
[Google Cloud Console OAuth app setup, Zitadel IdP config, JIT provisioning]
### Alternative: Zitadel as SP, Google as SAML IdP
[SAML app setup in Google Admin Console, attribute mapping]
### Staff Login Flow End-to-End
[Sequence: staff browser -> service -> Zitadel -> Google -> token issued -> access granted]
### Recommendation
[Which scenario to use and why]

## User Management
[Organizations, projects, roles, grants, bulk import]

## Machine Users & Service Accounts
[PATs, JWT profiles, OpenBao storage]

## Actions v2
[Syntax, examples, n8n webhook trigger, token enrichment]

## Branding & MFA
[Custom domain, theming, TOTP enforcement, passkeys]

## Token Management
[Lifetimes, JWT claims, introspection, JWKS, revocation]

## Monitoring & Audit Logs
[Prometheus metrics, Loki forwarding, Grafana dashboards]

## Troubleshooting
[OIDC errors, redirect issues, token debugging, Google federation failures]

# Google Workspace

## Overview
[2-3 sentence description of what Google Workspace provides and how it fits in the Helix Stax stack]

## Admin Console
### User Management
[CLI/API commands, user lifecycle procedures]
### OU & Groups Structure
[Recommended structure for a consulting firm]
### Admin Roles
[Least-privilege admin setup]
### Audit Log Access
[How to pull logs via API, export to n8n]

## DNS Records (Cloudflare)
### Required Records
[MX, SPF, DKIM, DMARC — exact values and Cloudflare-specific steps]
### SPF with Postal Coexistence
[Merged SPF record, lookup count management]
### DMARC Ramp-Up
[none -> quarantine -> reject policy progression]
### Email Client Autoconfiguration
[autodiscover/autoconfig SRV records]

## Zitadel Federation
### Scenario A: Google as External IdP in Zitadel (Recommended)
[Google Cloud Console OAuth app setup + Zitadel config]
### Scenario B: Zitadel as SP, Google as SAML IdP
[SAML setup steps in both Zitadel and Google Admin Console]
### Recommendation
[Which scenario to use and why for Helix Stax]

## Gemini CLI & Google Cloud Setup
### Project & API Setup
[gcloud commands to create project, enable APIs]
### Service Account Setup
[Create, key, store in OpenBao]
### Workload Identity Federation for K3s
[How pods call Google APIs without JSON keys]
### Rate Limits & Quotas
[What to expect, backoff pattern]

## Drive Organization
### Shared Drive Structure
[Recommended folder hierarchy]
### Drive API for Automation
[Key API calls with examples]
### Sharing Model
[Client isolation, team access]

## Gmail Configuration
### Routing & Aliases
[How to set up support@, info@ routing]
### Gmail API for n8n
[OAuth scopes, push notifications via Pub/Sub]
### Postal Coexistence
[Subdomain strategy, reply-to config]

## Calendar Automation
### Calendar API
[Key API calls, n8n integration]
### Resource Management
[Shared calendars, resource booking]

## Groups Configuration
### Recommended Groups
[team@, ops@, alerts@, clients@ setup]
### Groups API
[Programmatic management]
### Collaborative Inbox
[Support@ setup]

## Security
### 2FA Enforcement
[Admin Console steps, allowed methods]
### Context-Aware Access
[Access level definition, app assignment]
### DLP Policies
[Gmail DLP, Drive DLP, alert routing to n8n]
### Third-Party App Access
[OAuth app whitelist management]

## API Automation
### n8n Google Nodes
[Available native nodes, OAuth2 vs service account]
### Common Automation Workflows
[Onboarding, offboarding, reporting — n8n workflow outlines]
### Workspace Events API
[Push notification setup, event types]
### Apps Script vs n8n
[When to use each]

## Compliance
### Google Vault
[Matters, holds, retention rules, export]
### Audit Log Export
[Reports API -> n8n -> storage]
### GDPR & Data Residency
[Relevant settings, deletion request handling]
### Compliance Certifications
[SOC 2, ISO 27001, HIPAA BAA — what's covered]

## Cost Optimization
### License Management
[Active user tracking, shared mailbox workaround]
### Storage Management
[Pool monitoring, large file cleanup]
### Enterprise Standard Justification
[Feature breakdown vs lower tiers]

## Platform Integration (n8n Hub)
### Workspace -> Platform Flows
[Gmail -> ClickUp, Calendar -> Rocket.Chat, Drive -> Outline]
### Tool Boundaries
[What lives in Workspace vs K3s platform]
### Alerting Fallback
[Alertmanager -> Gmail ops@ as backup when Rocket.Chat is down]
```

Be thorough, opinionated, and practical. Include actual CLI commands (gcloud, zitadel-tools), actual DNS record values, actual OIDC config snippets per service, actual Kubernetes YAML, actual Helm values, and actual curl examples. Do NOT give me theory — give me copy-paste-ready configs for:
- Zitadel running on K3s behind Traefik and Cloudflare, backed by CloudNativePG
- Google Workspace Enterprise Standard on helixstax.com with Cloudflare managing DNS
- The full Google → Zitadel → platform-service login flow configured end-to-end

Where you must make assumptions, state them explicitly. Explicitly call out the federation between Google Workspace and Zitadel — both sides of the configuration — since this is the critical integration that connects the two tools in this group.
