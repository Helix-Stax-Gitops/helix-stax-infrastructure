# Gemini Deep Research: Internal Portals (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into two separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These two tools form the internal knowledge and developer portal layer at Helix Stax:

- **Backstage**: Internal developer portal and service catalog. Gives us a single pane of glass for all services, APIs, documentation, and infrastructure — replacing ad-hoc wikis and tribal knowledge. Used to onboard new services with software templates, track ownership, and surface Kubernetes deployment status, ArgoCD sync state, and Grafana dashboards in one place.
- **Outline**: Self-hosted knowledge base and team wiki. Serves two audiences: internal (runbooks, SOPs, architecture notes, agent playbooks) and external (client-facing landing pages and portal content). Chosen for its clean REST API for automation, SSO with Zitadel, and strong n8n integration.

## Our Specific Setup
- **Deployment**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Identity**: Zitadel as OIDC provider for SSO for both tools
- **Database**: CloudNativePG (PostgreSQL) — both Backstage and Outline require PostgreSQL
- **Ingress**: Traefik with TLS termination, behind Cloudflare
- **CI/CD**: Devtron + ArgoCD — both integrated as Backstage plugins
- **Monitoring**: Prometheus + Grafana + Loki — Grafana plugin for embedded dashboards
- **Object Storage**: MinIO (S3-compatible) — Outline file uploads; Backstage TechDocs storage
- **Cache**: Valkey (Redis-compatible) — Outline uses Redis for sessions and queues
- **Automation**: n8n integration via webhooks for auto-documentation workflows
- **Registry**: Harbor — service catalog lists container images
- **Backstage domain**: Internal — backstage.helixstax.net via Traefik IngressRoute (Phase 3+, not yet live)
- **Outline domain**: Internal — wiki.helixstax.net or docs.helixstax.net via Traefik IngressRoute (Active — deploy alongside core platform)

---

## What I Need Researched

### SECTION A: Backstage

#### A1. CLI Reference (backstage-cli)
- Full `backstage-cli` command list: `new`, `create-plugin`, `build`, `start`, `lint`, `test`, `versions:bump`
- How to scaffold a new Backstage app from scratch: `npx @backstage/create-app@latest`
- How to add and remove plugins via CLI
- How to build for production: `yarn build` vs `yarn build:backend`
- How to run Backstage locally for development: `yarn dev` and what ports it uses
- Environment variable injection patterns for Docker/K3s deployments
- How `backstage-cli package build` differs from `backstage-cli app build`

#### A2. Deployment on K3s
- Helm chart options: official `backstage/backstage` chart vs custom manifests — pros/cons for our scale
- Required Kubernetes resources: Deployment, Service, ConfigMap, Secret, IngressRoute (Traefik CRD)
- CloudNativePG integration: how Backstage connects to PostgreSQL, connection string format, SSL mode
- `app-config.yaml` vs `app-config.production.yaml` — how to layer configs in K3s via ConfigMap
- Resource requests/limits: realistic values for a small team (CPU, memory)
- Health check endpoints: `/healthcheck` and readiness/liveness probe configuration
- Docker image: building a custom Backstage image with plugins baked in — multi-stage Dockerfile pattern
- ArgoCD deployment: Application manifest for Backstage, sync waves for database-first ordering
- Secret management: injecting database credentials via External Secrets Operator / OpenBao

#### A3. Catalog: Defining Components
- `catalog-info.yaml` anatomy: `apiVersion`, `kind`, `metadata`, `spec` fields
- All entity kinds: Component, API, System, Domain, Resource, Location, Group, User
- `spec.type` values for Component: service, website, library, documentation
- `spec.lifecycle` values: production, experimental, deprecated
- `spec.owner` format: user and group references
- Relations: `dependsOn`, `providesApi`, `consumesApi`, `partOf`, `hasPart`
- How to register a catalog entity via the UI vs `catalog.locations` in `app-config.yaml`
- How to auto-discover `catalog-info.yaml` files from a GitHub org
- How to annotate with Kubernetes, ArgoCD, Grafana, and Harbor metadata
- Example `catalog-info.yaml` for a K3s-deployed backend service with all our stack's annotations

#### A4. Software Templates
- Template anatomy: `apiVersion: scaffolder.backstage.io/v1beta3`, `kind: Template`
- Parameters: form fields (string, number, boolean, object, array) — full field schema
- Steps: `fetch:template`, `publish:github`, `catalog:register` — all built-in step actions
- How to write a template that scaffolds a new microservice with: repo, Helm chart, ArgoCD Application, catalog-info.yaml, and basic CI pipeline
- Custom actions: how to write and register a custom scaffolder action
- Dry-run and testing templates locally before publishing
- Template variables: `${{ parameters.name }}` syntax and Nunjucks filters available
- How to make templates available only to certain groups

#### A5. TechDocs: Documentation-as-Code
- How TechDocs works: MkDocs + `techdocs-cli` + object storage
- `mkdocs.yml` minimal configuration for a Backstage service doc
- Annotating a component to enable TechDocs: `backstage.io/techdocs-ref` annotation
- Build modes: `local` (Backstage builds on-the-fly) vs `external` (pre-built, stored in MinIO)
- MinIO as TechDocs storage: `app-config.yaml` configuration for S3-compatible storage
- `techdocs-cli generate` and `techdocs-cli publish` commands with MinIO target
- CI pipeline step: auto-build and publish TechDocs on repo push
- Plugins and extensions: Mermaid diagrams, PlantUML, OpenAPI spec rendering in TechDocs

#### A6. Plugins: Our Stack Integrations
- **Kubernetes plugin**: `@backstage/plugin-kubernetes` — config to connect to our K3s cluster, label selector for surfacing deployments per component, RBAC requirements
- **ArgoCD plugin**: `roadiehq/backstage-plugin-argo-cd` — config for our ArgoCD instance, showing sync status per component
- **Grafana plugin**: `@backstage/plugin-grafana` or `roadiehq/backstage-plugin-grafana` — embedding dashboards, alert panels; config pointing to our Grafana instance
- **GitHub plugin**: `@backstage/plugin-github-actions` — showing CI pipeline runs per component
- **Harbor plugin**: any available Harbor registry plugin — showing image tags per component
- How to install a plugin: yarn add + register in `packages/app/src/App.tsx` and `packages/backend/src/index.ts`
- Plugin configuration in `app-config.yaml` — complete examples for each plugin above
- How to handle plugin authentication tokens securely (not in git)

#### A7. OIDC: SSO with Zitadel
- Backstage auth provider for OIDC: `@backstage/plugin-auth-backend-module-oidc-provider`
- `app-config.yaml` auth section: `providers.oidc` with `clientId`, `clientSecret`, `metadataUrl`, `scope`
- Zitadel-specific OIDC metadata URL format: `https://auth.helixstax.net/.well-known/openid-configuration`
- Redirect URI to register in Zitadel: format and Backstage callback path
- Sign-in resolver: mapping OIDC claims to Backstage user entities
- Guest access: how to allow unauthenticated read-only access to catalog (or disable it entirely)
- Group sync: mapping Zitadel groups/roles to Backstage groups for ownership and permissions
- Session management: cookie configuration, token refresh behavior

#### A8. Permissions Framework
- Backstage permissions plugin: `@backstage/plugin-permission-backend`
- Policy writing: allow/deny rules based on user identity, group membership, entity ownership
- Protecting catalog entities: read-only for guests, full CRUD for owners
- Protecting software templates: restrict which groups can create from which templates
- Integration with Zitadel groups for RBAC
- `app-config.yaml` permission section configuration

#### A9. API Reference
- Catalog API: `GET /api/catalog/entities`, query params (`filter`, `limit`, `offset`, `orderField`)
- Catalog API: `POST /api/catalog/locations` to register new entities
- Catalog API: `DELETE /api/catalog/entities/by-uid/{uid}` to remove stale entities
- Scaffolder API: `GET /api/scaffolder/v2/templates` — list available templates
- Scaffolder API: `POST /api/scaffolder/v2/tasks` — trigger a scaffolder task
- TechDocs API: `GET /api/techdocs/static/docs/{namespace}/{kind}/{name}/{path}`
- Search API: `GET /api/search/query?term=...` — full-text search across catalog, TechDocs, APIs
- Authentication: using Backstage service tokens for API calls from agents and automation
- Rate limits and pagination patterns

#### A10. Troubleshooting
- Plugin fails to load: common causes (version mismatches, missing backend registration, wrong import path)
- Catalog entity not appearing: how to debug location ingestion, check processor errors, validate YAML schema
- Database connectivity: CloudNativePG connection issues — SSL mode, pg_hba.conf, connection pool exhaustion
- OIDC login loop: common Zitadel + Backstage misconfigurations (redirect URI, scope, metadata URL)
- Kubernetes plugin shows no deployments: RBAC gaps, label selector mismatches, cluster config errors
- ArgoCD plugin shows stale status: token expiry, network policy blocking egress to ArgoCD API
- TechDocs not rendering: MinIO permission errors, missing `mkdocs.yml`, wrong annotation format
- High memory usage: Node.js heap tuning, plugin isolation patterns
- `yarn build` failures: common TypeScript errors in plugin development, peer dependency conflicts

---

### SECTION B: Outline

#### B1. REST API Reference
- API base URL and authentication: Bearer token format, how to generate API tokens per user or service account
- Collections API: `GET /api/collections.list`, `POST /api/collections.create`, `DELETE /api/collections.delete`
- Documents API: `GET /api/documents.list`, `POST /api/documents.create`, `PUT /api/documents.update`, `POST /api/documents.delete`, `POST /api/documents.search`
- Document publishing: `POST /api/documents.update` with `publish: true` field
- Attachments API: uploading files and images programmatically
- Users API: listing users, inviting members, managing roles
- Groups API: creating and managing groups, adding users to groups
- Auth API: session info, token validation
- Pagination: cursor-based vs offset pagination in Outline's API
- Rate limits: any documented limits on API calls
- Webhook payload format: what Outline sends to n8n on document create/update/delete events

#### B2. Deployment on K3s
- Docker image: `outlinewiki/outline` — which tag to pin, how often it updates
- Environment variables: complete list of required and optional env vars (`SECRET_KEY`, `UTILS_SECRET`, `DATABASE_URL`, `REDIS_URL`, `AWS_*` for MinIO, `URL`, `PORT`, OIDC vars)
- `SECRET_KEY` and `UTILS_SECRET` generation: `openssl rand -hex 32` pattern
- Kubernetes Deployment manifest: container spec, env from Secrets, resource requests/limits
- Kubernetes Service and Traefik IngressRoute: TLS passthrough vs TLS termination at Traefik
- CloudNativePG integration: `DATABASE_URL` format with SSL, user/password from CNPG-generated secrets
- Valkey integration: `REDIS_URL` format for Valkey (Redis-compatible), auth password
- MinIO integration: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_UPLOAD_BUCKET_NAME`, `AWS_S3_UPLOAD_BUCKET_URL`, `AWS_REGION` set to `us-east-1` for MinIO, `AWS_S3_FORCE_PATH_STYLE=true`
- Database migrations: how Outline handles migrations on startup vs manual `yarn sequelize db:migrate`
- Health check endpoints: `/api/health` — readiness and liveness probe config
- Persistent storage: does Outline need any PVCs beyond what MinIO provides? (Likely not)
- ArgoCD Application manifest: sync waves to ensure CloudNativePG cluster and Valkey are ready first

#### B3. OIDC: SSO with Zitadel
- Required environment variables for OIDC: `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_AUTH_URI`, `OIDC_TOKEN_URI`, `OIDC_USERINFO_URI`, `OIDC_LOGOUT_URI`, `OIDC_DISPLAY_NAME`, `OIDC_SCOPES`
- Zitadel-specific URLs for each OIDC endpoint (using `auth.helixstax.net` as our Zitadel domain)
- Redirect URI to register in Zitadel: exact callback path Outline uses
- Claim mapping: how Outline maps OIDC claims to user profile fields (name, email, avatar)
- Auto-provisioning: does Outline auto-create accounts on first OIDC login?
- Restricting access by email domain: `ALLOWED_DOMAINS` env var
- Admin bootstrap: how to make the first OIDC user an admin
- Disabling email/password auth when OIDC is the sole provider

#### B4. Collections and Document Organization
- Collection types: standard vs personal collections — when to use each
- Recommended collection structure for an IT consulting firm: internal ops, client portal, runbooks, product docs
- Document hierarchy: collections -> documents -> nested documents (max depth, any limits)
- Templates: creating document templates per collection for consistent structure
- Pinning documents: how pinning works, use cases for pinned docs in client-facing collections
- Archiving vs deleting: how Outline handles deleted documents, recovery period
- Importing content: importing Markdown files, Notion export, Confluence export
- Exporting content: exporting a collection as Markdown/PDF for backups

#### B5. Permissions: Teams, Groups, and Document Access
- Permission model: workspace-level vs collection-level vs document-level access
- Roles: admin, member, viewer, guest — what each can and cannot do
- Collection permissions: read, read+write, admin — how to assign per group
- Document-level overrides: sharing a specific document more broadly than its collection
- Guest access: inviting external users (clients) to specific collections without full account
- Groups: creating groups in Outline, mapping from Zitadel OIDC groups if supported
- Public sharing: enabling a public read-only link for a document or collection (client portal use case)
- API token permissions: scoping tokens to read-only or specific collections

#### B6. Search Configuration
- How Outline's full-text search works: built-in PostgreSQL full-text search vs external engine
- Search scope: searching across all collections vs scoped to one collection
- Boosting recent documents, pinned documents in search results
- Search API: `POST /api/documents.search` with `query`, `collectionId`, `userId` params
- Indexing lag: how quickly new documents become searchable after creation
- Search from n8n: using the search API in an n8n HTTP Request node to find documents

#### B7. Integrations: Webhooks and n8n
- Webhook configuration in Outline admin: how to register a webhook URL, which events are available
- Webhook payload structure: `event`, `document`, `collection`, `user` objects — full schema
- Verifying webhook signatures: `x-outline-signature` header, HMAC verification
- n8n Outline webhook trigger: receiving and routing Outline events in n8n
- Auto-documentation workflow: n8n watches for new Backstage `catalog-info.yaml` commits, creates/updates Outline document via API
- Runbook sync: n8n syncs a Markdown file from GitHub to an Outline document on push
- Alert-to-doc workflow: Alertmanager fires webhook -> n8n -> creates Outline incident doc
- API key management: using Outline API tokens as n8n credentials (HTTP Header Auth)

#### B8. Client-Facing Portal
- Using Outline as a client landing page: public collection with service status, onboarding docs, deliverables
- Custom domain: can Outline serve a collection on a custom subdomain (e.g., `portal.helixstax.com`)?
- Embedding Outline documents in other pages: iframe support, public embed links
- Branding: custom logo, color scheme, workspace name — where configured in admin UI
- Guest invite flow: how a client receives an invite, what they see without an account
- Audit trail: tracking when clients view shared documents
- Restricting guest access: preventing guests from seeing internal collections

#### B9. Import, Export, and Backup
- Importing Markdown: bulk import of `.md` files into a collection — CLI or API method
- Importing from Notion: Notion export format (.zip with Markdown) -> Outline import process
- Exporting a collection: `POST /api/collections.export` — what format, async job handling
- Database backup: CloudNativePG backup covers Outline's data — what tables matter most
- File attachment backup: MinIO bucket backup via Velero or `mc mirror` to Backblaze B2
- Point-in-time recovery: restoring Outline to a specific state from CNPG + MinIO backups
- Velero integration: annotating Outline's namespace for Velero backup with pre-backup hooks

#### B10. Monitoring and Troubleshooting
- Health check: `GET /api/health` — what it checks (DB connection, Redis connection, storage)
- Prometheus metrics: does Outline expose a `/metrics` endpoint? If not, what to monitor externally
- Key metrics to track via Prometheus blackbox exporter: uptime, response time for `/api/health`
- Log output: where Outline logs go in K3s (stdout), how to ship to Loki via Promtail
- Common issues:
  - SSO login fails: Zitadel redirect URI mismatch, missing scopes, clock skew
  - File uploads fail: MinIO bucket not created, wrong `AWS_S3_FORCE_PATH_STYLE`, CORS config
  - Search returns no results: PostgreSQL FTS index not built, wrong locale
  - Valkey connection refused: auth password mismatch, Valkey not ready before Outline starts
  - Outline stuck in redirect loop: `URL` env var mismatch, Traefik stripping headers
  - Database migration fails on startup: CloudNativePG user lacks migration permissions
- Debug mode: enabling verbose logging in Outline

---

## Required Output Format

Structure your response with these EXACT top-level headers (using `#`) so it can be split into two separate skill files. Each section must be self-contained — do not assume the reader has read the other section.

```markdown
# Backstage

## Overview
[2-3 sentence description of what Backstage does and why we use it]

## CLI Reference
### backstage-cli Commands
[Commands with examples]
### Building for Production
[Build commands, Docker image pattern]
### Local Development
[Dev commands, ports]

## Deployment on K3s
### Helm Chart
[Chart values, resource config]
### app-config.yaml (Production)
[Full annotated config example]
### CloudNativePG Integration
[Connection string, SSL, secret injection]
### ArgoCD Application Manifest
[Example manifest with sync waves]

## Catalog
### Entity Kinds
[All kinds with examples]
### catalog-info.yaml for a K3s Service
[Complete annotated example]
### Auto-Discovery
[GitHub org discovery config]

## Software Templates
### Template Anatomy
[Full example template]
### Built-in Step Actions
[All actions with examples]
### Custom Actions
[How to write and register]

## TechDocs
### Setup with MinIO
[app-config.yaml config]
### CLI Commands
[generate, publish with examples]
### CI Pipeline Integration
[Step example]

## Plugins
### Kubernetes Plugin
[Config + RBAC]
### ArgoCD Plugin
[Config + annotation]
### Grafana Plugin
[Config + dashboard embedding]
### GitHub Plugin
[Config + annotation]
### Harbor Plugin
[Config if available]

## OIDC with Zitadel
### app-config.yaml Auth Section
[Complete config]
### Zitadel OIDC Client Setup
[Required settings in Zitadel]
### Sign-in Resolver
[User mapping example]
### Group Sync
[Group mapping config]

## Permissions
[Policy examples, RBAC config]

## API Reference
### Catalog API
[Endpoints with curl examples]
### Scaffolder API
[Endpoints with curl examples]
### Search API
[Query examples]

## Troubleshooting
[Symptom -> cause -> fix for each issue]

## Gotchas
[Anti-patterns, version pinning, plugin conflicts]

---

# Outline

## Overview
[2-3 sentence description of what Outline does and why we use it]

## Deployment on K3s
### Environment Variables
[Complete env var reference with descriptions]
### Kubernetes Manifest
[Deployment, Service, IngressRoute examples]
### CloudNativePG Integration
[DATABASE_URL format, SSL, secret injection]
### Valkey Integration
[REDIS_URL format]
### MinIO Integration
[All AWS_* env vars for MinIO, path-style config]
### ArgoCD Application Manifest
[Example with sync waves]

## OIDC with Zitadel
### Environment Variables
[All OIDC env vars with Zitadel-specific values]
### Zitadel Client Setup
[Required settings, redirect URI]
### Access Control
[Domain restriction, admin bootstrap]

## Collections and Documents
### Recommended Structure
[Collection hierarchy for our use case]
### Templates
[How to create and use]
### Import/Export
[CLI and API methods]

## Permissions
### Role Reference
[Admin, member, viewer, guest]
### Collection Permissions
[How to configure per group]
### Guest/Client Access
[Invite flow, public sharing]

## Search
### Configuration
[PostgreSQL FTS setup]
### Search API
[curl examples]

## REST API Reference
### Authentication
[Token format, generation]
### Collections API
[Endpoints with curl examples]
### Documents API
[Endpoints with curl examples]
### Webhooks
[Event list, payload schema, signature verification]

## n8n Integration
### Webhook Setup
[Outline -> n8n flow]
### Auto-Documentation Workflow
[n8n workflow pattern]
### API Usage from n8n
[HTTP Request node config]

## Client Portal
### Public Collections
[Setup for client-facing content]
### Custom Branding
[Logo, colors, domain]
### Guest Access
[Invite and permission flow]

## Backup and Recovery
### Velero Integration
[Namespace annotation, hooks]
### MinIO File Backup
[mc mirror to Backblaze B2]
### Restore Procedure
[Step-by-step]

## Monitoring
### Health Check
[Probe config]
### Loki Log Shipping
[Promtail config]
### Key Metrics
[What to alert on]

## Troubleshooting
[Symptom -> cause -> fix for each issue]
```

Be thorough, opinionated, and practical. Include actual CLI commands, actual `app-config.yaml` snippets, actual `catalog-info.yaml` examples, actual Kubernetes manifests for both tools, actual API curl commands, and actual n8n workflow patterns. Do NOT give me theory — give me copy-paste-ready configs for Backstage and Outline running on K3s with CloudNativePG, Zitadel OIDC, MinIO, and Traefik.
