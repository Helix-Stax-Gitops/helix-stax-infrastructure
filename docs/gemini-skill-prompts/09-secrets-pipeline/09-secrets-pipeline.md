# Gemini Deep Research: Secrets Pipeline (Grouped)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document — split into three separate skill files after you produce it.

## What These Tools Are (Group Introduction)
These three tools form the complete secrets lifecycle at Helix Stax. They are a pipeline — each stage hands off to the next:

- **SOPS + age**: Secrets at rest in git. Developers encrypt secrets before committing using age public keys. The encrypted ciphertext is safe to commit. age is the encryption backend; SOPS is the file-format wrapper.
- **OpenBao**: Secrets at runtime. The central secrets store — the HashiCorp Vault fork under the Linux Foundation (MPL-2.0 license). Stores KV secrets, issues dynamic database credentials, acts as internal CA (PKI), and provides envelope encryption (transit). Runs inside K3s.
- **External Secrets Operator (ESO)**: The bridge. ESO reads secrets from OpenBao and creates native Kubernetes Secret objects that pods can consume. Without ESO, pods would need Vault Agent sidecars or direct API calls.

Full pipeline: Developer encrypts with SOPS+age → commits to git → ArgoCD syncs manifests (but NOT the secret values — those stay in OpenBao) → ESO ClusterSecretStore reads from OpenBao → ESO creates K8s Secret → pod mounts secret as env var or volume.

## Our Specific Setup
- **Cluster**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12 CP, helix-worker-1: 138.201.131.157 worker)
- **Domains**: helixstax.com (public), helixstax.net (internal)
- **Identity**: Zitadel (OIDC for services including OpenBao UI login)
- **CI/CD**: Devtron + ArgoCD (GitOps — all manifests in git)
- **Registry**: Harbor
- **Database**: CloudNativePG (PostgreSQL) — OpenBao issues dynamic credentials
- **Monitoring**: Prometheus + Grafana + Loki + Alertmanager
- **Gitleaks**: Pre-commit and CI secret scanning (upstream guard)
- **Primary key backend**: OpenBao Transit engine (age as fallback for local dev without OpenBao access)
- **age**: used for local development and CI bootstrap before OpenBao is available
- **File types we encrypt**: Kubernetes Secret YAML manifests, Helm `values-secrets.yaml` files, `.env` files for local dev reference
- **GitOps flow**: SOPS-encrypted files in git → ArgoCD + KSOPS decrypts → K8s Secret objects created
- **OpenBao**: running in K3s, Transit engine at path `transit/`, key name `sops-key`
- **Repos**: GitHub (KeemWilliams) — infrastructure repo, app repos
- **Key services needing secrets**: Zitadel (PG credentials), CloudNativePG (superuser, app users), Harbor (admin, robot accounts), MinIO (access/secret key), Grafana (admin, OIDC client), n8n (encryption key, PG credentials), Rocket.Chat (OIDC client secret), Devtron (Harbor credentials)
- **Compliance**: NIST CSF 2.0, SOC 2 — secrets management is a key control area

---

## What I Need Researched

### SECTION A: SOPS + age

#### A1. How SOPS and age Work Together
- age vs GPG: why we chose age (simpler, no key server, X25519 curve)
- SOPS file format: how it wraps any YAML/JSON/ENV/binary file with encrypted values + metadata
- The `.sops.yaml` config file: key selection by path, creation rules, key groups
- age key anatomy: public key (X25519), private key (stored securely), key file format
- How SOPS stores the DEK (data encryption key) per recipient in the file header

#### A2. Key Management with age
- Generating age keys: `age-keygen -o key.txt` — output format
- Key file format: private key (`AGE-SECRET-KEY-1...`) and public key (`age1...`)
- Where to store age private key: `$HOME/.config/sops/age/keys.txt` (default location SOPS checks)
- Windows path: `AppData\Roaming\sops\age\keys.txt`
- Multiple recipients: how to encrypt for multiple age keys (team members + CI key)
- Key rotation: adding a new age key, re-encrypting all secrets, removing old key
- Backing up age keys: recommended practices — where to securely store (OpenBao KV as ironic backup)
- Age key for CI (Devtron): how to inject the private key into the CI pipeline securely

#### A3. SOPS CLI Reference
- `sops --encrypt`: encrypting a file in place or to stdout
  - Syntax: `sops --encrypt --in-place secrets.yaml`; output to stdout: `sops --encrypt secrets.yaml > secrets.enc.yaml`
  - Specifying key type at command line: `--age`, `--hc-vault-transit` flags
- `sops --decrypt`: decrypting a file
  - In-place: `sops --decrypt --in-place secrets.yaml`; to stdout: `sops --decrypt secrets.yaml`
  - Output format flag: `--output-type yaml/json/dotenv/binary`
  - Extracting a single key: `sops --decrypt --extract '["key"]["subkey"]' secrets.yaml`
- `sops --edit`: opening an encrypted file in $EDITOR (decrypt → edit → re-encrypt on save)
  - Editor configuration: $EDITOR env var; what happens if edit is interrupted (temp file cleanup)
- `sops --rotate`: rotating the data encryption key (DEK) while keeping the same master keys
  - Syntax: `sops --rotate --in-place secrets.yaml`; when to rotate: regularly, after key exposure
- `sops --updatekeys`: re-encrypting with a new or updated set of master keys
  - Use case: adding a new team member's age key, switching from age to OpenBao transit
  - Syntax: `sops updatekeys secrets.yaml`; requires the file to be currently decryptable
- `sops filestatus`: checking if a file is encrypted or not
- Global flags: `--config`, `--verbose`, `--ignore-mac`
- Environment variables: `SOPS_AGE_KEY_FILE`, `VAULT_ADDR`, `VAULT_TOKEN` / `BAO_ADDR`

#### A4. OpenBao Transit Integration (Primary Key Backend)
- OpenBao Transit engine setup for SOPS:
  - Enable transit: `bao secrets enable transit`
  - Create SOPS key: `bao write transit/keys/sops-key type=aes256-gcm96`
  - Key policy: what OpenBao policy does SOPS need? (encrypt, decrypt, describe)
- SOPS configuration for OpenBao Transit:
  - `.sops.yaml` key reference: `hc_vault_transit_uri` format
  - Environment variables: `VAULT_ADDR` (or `BAO_ADDR`?), `VAULT_TOKEN`
  - Token auth vs AppRole auth vs Kubernetes auth for CI pipelines
- How SOPS uses transit: SOPS generates a random DEK, encrypts with transit, stores encrypted DEK in file
- Key rotation in OpenBao: `bao write transit/keys/sops-key/rotate` — does this automatically re-encrypt SOPS files? (No — you need `sops --rotate`)
- OpenBao unavailable: what happens when OpenBao is sealed and you try to decrypt a SOPS file
- Multiple key backends in one file: encrypting with BOTH age (for local dev) AND OpenBao transit (for CI/CD)

#### A5. File Formats (YAML, JSON, ENV, Binary)
- **YAML** (primary use case — K8s Secret manifests):
  - What gets encrypted: by default, all leaf values
  - Partial encryption: using `--encrypted-regex` to encrypt only sensitive fields
  - Example: encrypting only `data.*` in a K8s Secret manifest, leaving metadata unencrypted
  - The `sops:` metadata block added to the file — structure and purpose
  - MAC (message authentication code): what it is, `--ignore-mac` flag (when safe, when dangerous)
- **JSON**: leaf-value encryption behavior, use case: Terraform tfvars.json
- **ENV / dotenv**: encrypting `.env` files — all values encrypted, keys visible
- **Binary**: encrypting non-structured files — `sops --encrypt --input-type binary --output-type binary key.pem`
- Partial encryption with `--encrypted-regex`: `--encrypted-regex '^(data|stringData)$'` for K8s Secrets

#### A6. .sops.yaml (Creation Rules & Path-Based Configuration)
- File location: repo root (SOPS searches upward from the file being encrypted)
- Complete `.sops.yaml` structure: `creation_rules` array, `stores` config
- `path_regex`: regex matching which files the rule applies to; first matching rule wins
- Key specification in rules: `age`, `hc_vault_transit_uri`, `pgp`, multiple key types in one rule
- Example `.sops.yaml` for our repo structure:
  - `secrets/**/*.yaml` → OpenBao Transit + CI age key
  - `secrets/dev/**/*.yaml` → developer age key only
  - `helm/**/values-secrets.yaml` → OpenBao Transit + CI age key
  - `.env.*.sops` → developer age key only
- `encrypted_regex` in `.sops.yaml`: applying partial encryption globally

#### A7. What We Encrypt with SOPS
- Helm values files containing secrets (e.g., `values-secrets.yaml`)
- Ansible vars files (Ansible vault replacement)
- Environment-specific secrets: `secrets.prod.yaml`, `secrets.dev.yaml`
- What NOT to encrypt with SOPS (non-sensitive config, public certs, CRD definitions)
- ArgoCD Application files? (NO — ArgoCD reads from git, secrets must NOT be in ArgoCD manifests)

#### A8. GitOps Workflow with ArgoCD
- The full flow: developer encrypts → commits → pushes → ArgoCD detects → decrypts → applies
- **KSOPS** (Kustomize + SOPS):
  - What KSOPS is: a Kustomize plugin that calls SOPS during `kustomize build`
  - Installation in ArgoCD: custom ArgoCD image with KSOPS binary + Kustomize plugin
  - `ksops-generator.yaml`: the GeneratorConfig file that references SOPS-encrypted files
  - ArgoCD's access to OpenBao: Kubernetes auth ServiceAccount with decrypt policy
- **helm-secrets** (Helm + SOPS): Helm plugin wrapping SOPS; ArgoCD integration
- Recommended approach for K3s: KSOPS vs helm-secrets vs ArgoCD native — which to use and why
- How ArgoCD's ServiceAccount authenticates to OpenBao for decryption

#### A9. Key Rotation Workflow
- When to rotate age keys: annual rotation, key compromise, team member departure
- When to rotate OpenBao transit key: `bao write transit/keys/sops-key/rotate`
- Full key rotation procedure: generate new pair → `sops updatekeys` → commit → verify → revoke old
- Automating `sops updatekeys` across all files: shell script with `find` + loop
- Emergency rotation (compromised key): urgency changes the procedure — what to do immediately

#### A10. Multi-Key Encryption (CI + Developer + OpenBao)
- Why multi-key: CI needs to decrypt with one key, developer with another, OpenBao in cluster with transit
- Example: one SOPS file encrypted with 3 keys simultaneously (developer age, CI age, OpenBao transit)
- `.sops.yaml` rule with all three keys
- What happens if one key is unavailable: SOPS tries all keys, succeeds with any one

#### A11. Developer Workflow
- VS Code: `sops-vscode` extension or workflow for editing encrypted files
- `sops --edit` as the primary developer workflow: always edit encrypted, never decrypt-in-place
- Shell aliases: `sops-edit`, `sops-view`
- Pre-commit integration: running `sops --encrypt --in-place` if unencrypted secret detected
- The "edit loop" danger: editing a decrypted file directly, forgetting to re-encrypt before committing

#### A12. SOPS Troubleshooting
- `Error: Failed to get the data key required to decrypt the SOPS file`:
  - OpenBao unavailable / sealed; wrong VAULT_ADDR / BAO_ADDR; token expired; age key file not found
- `MAC mismatch`: file was modified outside SOPS — causes and `--ignore-mac` safety considerations
- `Could not find a suitable key for decryption`: none of the encrypted DEKs match available keys
- `sops metadata not found`: file is not SOPS-encrypted
- SOPS version mismatch: different SOPS versions between local and CI
- OpenBao transit key not found: key deleted, path changed, or policy missing
- Debugging SOPS: `--verbose` flag for step-by-step decryption process output
- ArgoCD / KSOPS decryption failures: where to look in ArgoCD logs, common KSOPS errors

---

### SECTION B: OpenBao

#### B1. OpenBao vs HashiCorp Vault
- Why OpenBao (Linux Foundation fork, MPL-2.0 license, drop-in Vault replacement)
- API compatibility: OpenBao is 100% API-compatible with Vault — all Vault clients work
- CLI differences: `bao` CLI vs `vault` CLI (same commands, different binary name)
- Helm chart: `openbao/openbao` — differences from HashiCorp Vault Helm chart
- Environment variables: VAULT_ADDR (vs BAO_ADDR?), VAULT_TOKEN, VAULT_SKIP_VERIFY — what changed in OpenBao

#### B2. K3s Deployment (Helm + Raft HA)
- Official OpenBao Helm chart: repo URL, chart name, recommended version
- Raft storage configuration in Helm values: node discovery in K3s, cluster address
- Integrated Raft storage vs external storage — recommendation for our 2-node cluster
- HA mode: 3-node Raft quorum on a 2-node cluster — how to handle this (single-node Raft for now?)
- TLS configuration: OpenBao serving TLS, cert-manager issuing the cert
- Required PersistentVolumeClaim configuration for Raft data
- Traefik IngressRoute CRD for OpenBao UI (HTTPS, TLS termination)
- Resource requests/limits appropriate for small cluster
- Init container or Job for bootstrapping: running `bao operator init` on first deploy
- Kubernetes liveness/readiness probes: correct endpoints and sealed-state behavior
- Helm upgrade procedure without causing outage

#### B3. Auto-Unseal
- Why auto-unseal matters: K3s pod restarts, upgrades, node reboots require unseal
- Auto-unseal with cloud KMS: Hetzner doesn't have KMS — alternatives
- Recommended approach: OpenBao Transit auto-unseal using a separate small OpenBao instance, OR `systemd` with sealed unseal key stored in a secure location
- Manual unseal procedure: when it's unavoidable and how to do it safely
- Seal status monitoring: Prometheus alert for sealed state

#### B4. Authentication Methods
- Kubernetes auth method: how pods authenticate to OpenBao using their ServiceAccount JWT
- Configuring the Kubernetes auth backend: `kubernetes_host`, `kubernetes_ca_cert`, `token_reviewer_jwt`
- Enabling Kubernetes auth: `bao auth enable kubernetes`, configure with K3s API server URL and CA cert
- Creating roles: binding ServiceAccount + namespace to a policy
- Example role for each major service (Grafana, n8n, ArgoCD, Harbor)
- Token TTL recommendations for pod auth
- OIDC auth (Zitadel): for human operators logging into OpenBao UI
- AppRole auth: for CI/CD systems (Devtron) that can't use K8s ServiceAccount JWT
- Token auth: for bootstrapping only — never for production long-lived use
- How External Secrets Operator authenticates to OpenBao using Kubernetes auth

#### B5. Secret Engines

##### KV v2 (Key-Value)
- Enabling KV v2: `bao secrets enable -path=secret kv-v2`
- Namespace/path conventions: `secret/helix-stax/{service}/{key}`
- Versioning: how KV v2 stores versions, how to retrieve previous versions; metadata: TTLs, custom metadata per secret
- Writing and reading secrets: `bao kv put`, `bao kv get`, `bao kv list`
- Soft delete vs hard destroy — when to use each
- Path structure best practices:
  - `secret/data/zitadel/` — Zitadel masterkey, DB DSN
  - `secret/data/grafana/` — OAuth client secret
  - `secret/data/harbor/` — admin password, robot account tokens
  - `secret/data/minio/` — root credentials, access keys
  - `secret/data/argocd/` — OIDC secret
  - `secret/data/n8n/` — DB credentials, webhook secrets
  - `secret/data/crowdsec/` — API keys, bouncer tokens
  - `secret/data/gitleaks/` — scanning tokens

##### Database Engine (Dynamic Credentials for CloudNativePG)
- Enabling the database secrets engine and configuring PostgreSQL connection
- CloudNativePG specifics: connecting OpenBao to the CNPG cluster endpoint
- Creating roles: read-only, read-write, admin; dynamic credentials flow; lease TTL recommendations
- How applications request dynamic credentials: ESO integration vs agent sidecar
- Revoking credentials when a pod dies (automatic lease expiry)
- Rotating the root database password (OpenBao-managed)
- Services that should use dynamic creds vs static KV secrets — decision matrix

##### PKI Engine (Internal CA)
- Setting up a root CA and intermediate CA in OpenBao
- Issuing TLS certificates for internal services (helixstax.net subdomains)
- cert-manager integration: using OpenBao as a cert-manager Issuer (vault-issuer)
- Certificate TTL recommendations: short-lived certs for pods, longer for infrastructure
- Auto-renewal: how cert-manager + OpenBao handles certificate rotation
- CRL configuration; how this interacts with Cloudflare edge TLS and Traefik

##### Transit Engine (Encryption as a Service)
- Enabling transit engine and creating encryption keys
- Encrypt/decrypt operations via API (for application-level encryption)
- Key rotation: rotating transit keys without re-encrypting all data
- Using transit for SOPS key management: OpenBao transit as SOPS KMS backend
- Using transit for auto-unseal (as described in B3)
- Key types: AES-GCM-256 vs ECDSA vs RSA — which for SOPS
- Convergent encryption — what it is, when to use it

#### B6. Policy Management (Least Privilege)
- HCL policy syntax: capabilities (create, read, update, delete, list, sudo, deny)
- Policy design pattern: one policy per service, scoped to its KV path
- Example policies for each service:
  - External Secrets Operator: read-only on all `secret/data/` paths
  - Grafana: read on `secret/data/grafana/`
  - n8n: read on `secret/data/n8n/`, write for storing workflow secrets
  - ArgoCD: read on `secret/data/argocd/`
  - Harbor: read on `secret/data/harbor/`
- Admin policy vs operator policy — what the human admin needs
- Zitadel OIDC auth policy for human operators
- Policy testing: `bao token capabilities` to verify access
- Policy naming conventions: `{service}-read`, `{service}-admin`

#### B7. CLI Reference (bao)
- Authentication: `bao login`, `bao token lookup`
- KV operations: `bao kv put/get/delete/list/rollback`
- Auth management: `bao auth list`, `bao auth enable`, `bao write auth/kubernetes/config`
- Policy management: `bao policy write/read/list/delete`
- Secret engine management: `bao secrets enable/disable/list`
- Lease management: `bao lease renew/revoke`
- Operator commands: `bao operator init`, `bao operator unseal`, `bao operator seal`, `bao operator raft list-peers`
- Raft snapshot backup: `bao operator raft snapshot save` to MinIO via CronJob
- Audit log: `bao audit enable file file_path=/vault/logs/audit.log`
- How to set up shell aliases and environment for daily operations

#### B8. Zitadel OIDC Integration (Human Access)
- Configuring OpenBao UI login via Zitadel OIDC
- OIDC auth method setup: client ID/secret, redirect URIs, scopes
- Mapping Zitadel claims (roles, groups) to OpenBao policies
- Allowed redirect URIs for the OpenBao UI OIDC flow
- Human operator workflow: browser → Zitadel login → OpenBao UI token

#### B9. Audit Logging, Backup & Recovery
- Audit device configuration: enabling file audit log, syslog audit log
- Forwarding audit logs to Loki: log format (JSON), Promtail config to pick up OpenBao audit log
- Key audit log fields: `auth.display_name`, `request.path`, `response.data` — what to index in Loki
- Raft snapshot backup: automated `bao operator raft snapshot save` to MinIO via CronJob
- Backup schedule recommendations and retention policy
- Restoring from Raft snapshot: procedure, gotchas
- What Velero backup misses: in-memory unseal keys (never persisted)
- Testing restore: procedure for validating a snapshot is restorable

#### B10. Monitoring and Troubleshooting
- OpenBao Prometheus metrics endpoint
- Key metrics: seal status, token counts, lease counts, request latency
- Grafana dashboard for OpenBao
- Alertmanager rules: alert on sealed state, on root token use, on failed auth attempts
- Troubleshooting seal/unseal: what causes unexpected sealing, how to recover
- Token expiry errors: renewing tokens, what happens when root token expires
- Auth failures: Kubernetes JWT validation errors, OIDC misconfiguration
- Performance: OpenBao memory usage, read/write latency under load
- Gotchas: Bootstrap chicken-and-egg, root token handling, dynamic creds and connection pooling

---

### SECTION C: External Secrets Operator (ESO)

#### C1. Architecture and How ESO Works
- ESO components: operator deployment, CRDs (SecretStore, ClusterSecretStore, ExternalSecret, ClusterExternalSecret, PushSecret)
- Reconciliation loop: ESO polls OpenBao at `refreshInterval`, compares to K8s Secret, updates if stale
- SecretStore vs ClusterSecretStore: namespace-scoped vs cluster-wide — which to use
- How ESO authenticates to OpenBao: Kubernetes auth method (ESO ServiceAccount JWT)

#### C2. ClusterSecretStore Configuration (OpenBao)
- Full ClusterSecretStore YAML for OpenBao (Vault-compatible provider)
- OpenBao endpoint, CA cert (from cert-manager), namespace
- Kubernetes auth: ServiceAccount name, role name
- TLS configuration for ESO → OpenBao communication

#### C3. ExternalSecret CRDs
- Full ExternalSecret YAML: name, store reference, refreshInterval, target Secret name
- Mapping OpenBao KV paths to K8s Secret keys
- Template transformations: renaming keys, base64 encoding, combining multiple secrets
- `secretStoreRef.kind`: ExternalSecret vs ClusterExternalSecret
- How ESO handles KV v2 paths (needs `data/` prefix in path)
- How ESO handles dynamic database credentials (vault `database/creds/` path)
- Example ExternalSecret manifests for: Zitadel DB DSN, Grafana OAuth secret, Harbor robot token

#### C4. Refresh Intervals and Secret Rotation
- Setting appropriate `refreshInterval` per secret type: static KV (1h), dynamic DB creds (TTL/2), PKI certs (1d)
- What happens when OpenBao renews a dynamic credential: ESO picks up new creds, updates K8s Secret — does the pod reload?
- Pod secret reload strategies: Reloader (stakater/reloader) watching K8s Secrets, pod restart annotation
- Manual force-refresh: deleting the ExternalSecret to force immediate resync

#### C5. Secrets for Each Helix Stax Service
- For each service: OpenBao path, ESO ExternalSecret spec, K8s Secret name, how pod consumes it
- Services to cover: Zitadel, CloudNativePG, Harbor, MinIO, Grafana, n8n, Rocket.Chat, Devtron, ArgoCD, cert-manager
- Special case: CloudNativePG — CNPG manages its own K8s Secrets for PG users; how does OpenBao interact?

#### C6. PushSecret (Writing Secrets TO OpenBao from K8s)
- Use case: bootstrapping secrets that start as K8s Secrets (e.g., cert-manager TLS certs pushed to OpenBao)
- PushSecret CRD configuration
- When to use PushSecret vs manually writing to OpenBao

#### C7. ESO Monitoring and Troubleshooting
- Prometheus metrics from ESO operator
- Grafana dashboard for ESO sync status
- Key status conditions: `SecretSynced`, `SecretSyncedError`
- Debugging ESO: `kubectl describe externalsecret`, checking ESO operator logs
- Common errors: wrong path format for KV v2, auth failure, OpenBao sealed
- Gotchas: KV v2 path prefix, dynamic creds TTL alignment, ESO restart behavior

---

### SECTION D: Full Pipeline Flows

#### D1. Developer Secret Workflow
Step-by-step: creating a new secret → encrypting with SOPS+age → committing to git → how it gets to OpenBao → how ESO delivers it to the pod.
- Who writes to OpenBao: humans via `bao kv put` or via ArgoCD SOPS plugin decrypting and writing?
- Clarify: does ArgoCD write decrypted SOPS values to OpenBao? Or does OpenBao have values pre-loaded manually and SOPS is only for local/CI use?
- Recommended authoritative pattern for our GitOps setup

#### D2. Key Rotation Procedures
- Rotating an age key: steps, which files to re-key, how to communicate to CI
- Rotating an OpenBao unseal key: `bao operator rekey`
- Rotating OpenBao root token: why you should and how
- Rotating a KV v2 secret in OpenBao: put new version → ESO picks up → pods reload
- Rotating a dynamic database credential: OpenBao handles it automatically; what to monitor
- Rotating a PKI root CA: when and how (disruptive, plan carefully)

#### D3. Emergency Procedures
- OpenBao sealed after restart: unseal steps, automation considerations
- OpenBao pod crash recovery: Raft log recovery, restoring from Velero backup
- ESO operator failure: secrets are already in K8s Secrets — pods continue running; ESO just can't refresh
- SOPS key lost: what you've lost, recovery options, why backups of age private key matter
- Mass secret rotation after a breach: priority order, which services are most critical

#### D4. Backup Strategy for Secrets
- Velero backup of OpenBao PVC: does this capture all secrets? (Raft storage yes, encrypted at rest)
- What Velero backup misses: in-memory unseal keys (never persisted)
- OpenBao's own snapshot: `bao operator raft snapshot save`
- Where snapshots go: MinIO bucket, then Backblaze B2 via Velero
- Testing restore: procedure for validating a snapshot is restorable

---

## Required Output Format

Structure your response with these EXACT top-level headers (using `#`) so it can be split into three separate skill files. Each section must be self-contained — do not assume the reader has read the other sections.

```markdown
# SOPS + age

## Overview
[What SOPS and age are and their role in the Helix Stax secrets pipeline]

## How SOPS and age Work Together
[DEK, file format, age key anatomy]

## Key Management
### Key Generation
[age-keygen, file format, storage location]
### Key Storage Locations
[Linux: ~/.config/sops/age/keys.txt, Windows: AppData path]
### Multiple Recipients
[CI key, developer key, team members]
### Key Rotation
[New pair, updatekeys, retire old key]
### Backup
[Recommended practices]

## CLI Reference
### encrypt
[Full syntax, flags, examples]
### decrypt
[Full syntax, single-key extract, output types]
### edit
[In-place editing workflow]
### rotate
[DEK rotation]
### updatekeys
[Master key rotation]
### Environment Variables
[SOPS_AGE_KEY_FILE, VAULT_ADDR/BAO_ADDR, VAULT_TOKEN]

## OpenBao Transit Integration
### Setup
[Enable transit, create key, policy required]
### .sops.yaml Configuration
[hc_vault_transit_uri format]
### CI Authentication
[Token auth vs Kubernetes auth]
### Multi-Backend
[age + transit in same file]

## File Formats
### YAML (K8s Secrets)
[Partial encryption with --encrypted-regex, sops: metadata block]
### JSON & ENV
[Use cases, commands]
### Binary
[Arbitrary file encryption]

## .sops.yaml (Creation Rules)
### Full Example
[Complete .sops.yaml for our repo structure]
### Path Regex Patterns
[secrets/**, helm/**/values-secrets.yaml]
### Multiple Rules
[Priority, dev vs prod keys]

## What We Encrypt
[Helm values, Ansible vars, what NOT to encrypt]

## GitOps with ArgoCD
### KSOPS Setup
[Custom ArgoCD image, ksops-generator.yaml, ServiceAccount policy]
### helm-secrets Setup
[Plugin config, ArgoCD integration]
### Recommendation
[Which approach to use and why]

## Key Rotation Workflow
### Standard Rotation
[Step-by-step procedure]
### Emergency Rotation
[Compromised key procedure]
### Automation Script
[Shell script for bulk updatekeys]

## Multi-Key Encryption
[.sops.yaml with developer + CI + OpenBao transit keys]

## Developer Workflow
[sops --edit, shell aliases, VS Code, pre-commit integration]

## CI Integration (Devtron)
[Injecting age key, decryption in pipeline, ArgoCD SOPS plugin]

## Troubleshooting
### Decryption Failures
[OpenBao unavailable, wrong path, token expired]
### MAC Mismatch
[Causes, --ignore-mac safety]
### Key Not Found
[age key path, transit key missing]
### ArgoCD / KSOPS Errors
[Log locations, common failures]

## Gotchas
[Re-keying pitfalls, ArgoCD exposure risks, large binary files]

---

# OpenBao

## Overview
[What OpenBao is, why we use it over Vault, its role in the secrets pipeline]

## Deployment on K3s
### Helm Chart
[Repo, values example, Raft config]
### Auto-Unseal Strategy
[Options for Hetzner, recommended approach]
### Traefik IngressRoute
[CRD example]
### Bootstrap Procedure
[Init, unseal, root token handling]
### Kubernetes Probes
[Liveness/readiness with sealed-state behavior]

## Auto-Unseal
[Options, recommended approach for Hetzner, seal monitoring]

## Authentication Methods
[Kubernetes auth, OIDC/Zitadel, AppRole, token — when to use each]

## Secret Engines
### KV v2
### Path Structure
[Our secret hierarchy with examples]
### Versioning & Metadata
[Version management commands]
### Database Engine (CloudNativePG)
[Connection config, role creation, TTL, which services use it]
### PKI Engine
[Root + intermediate CA, cert-manager integration, TTLs]
### Transit Engine
[Encryption keys, rotation, SOPS integration]

## Policy Management
[Per-service HCL policy examples, naming conventions]

## CLI Reference (bao)
### KV Commands
[Commands with examples]
### Auth Commands
[Commands with examples]
### Policy Commands
[Commands with examples]
### Operator Commands
[init, unseal, raft, rotate examples]
### Environment Variables
[BAO_ADDR vs VAULT_ADDR, token setup]

## Zitadel OIDC Integration
[Auth method config, role mapping, redirect URIs]

## Audit Logging
[Audit device config, Loki forwarding, key fields to index]

## Monitoring and Audit
[Prometheus metrics, Grafana dashboard, Alertmanager rules]

## Backup & Recovery
[Raft snapshot CronJob to MinIO, restore procedure, Velero PVC backup]

## Troubleshooting
[Seal/unseal, token expiry, auth failures, Raft issues]

## Gotchas
[Bootstrap chicken-and-egg, root token handling, dynamic creds and connection pooling]

---

# External Secrets Operator (ESO)

## Overview
[What ESO is and how it bridges OpenBao to K8s Secrets]

## Architecture
[CRDs, reconciliation loop, SecretStore vs ClusterSecretStore]

## ClusterSecretStore Configuration
[Full YAML for OpenBao backend, Kubernetes auth setup]

## ExternalSecret CRDs
[Full YAML examples, KV v2 path format, template transformations]

## Secrets for Each Helix Stax Service
[Per-service table: OpenBao path → ExternalSecret spec → K8s Secret → pod consumption]

## Refresh Intervals and Secret Rotation
[Intervals by type, pod reload strategies, Reloader, manual force-refresh]

## PushSecret
[Writing K8s Secrets to OpenBao, use cases]

## Monitoring and Troubleshooting
[Prometheus metrics, sync status conditions, debugging commands]

## Gotchas
[KV v2 path prefix, dynamic creds TTL alignment, ESO restart behavior]

---

# Secrets Pipeline: Full Flows and Emergency Procedures

## Developer Secret Workflow
[End-to-end: create → SOPS encrypt → commit → OpenBao → ESO → pod]

## Authoritative Pattern for GitOps
[Who writes to OpenBao, SOPS role, ArgoCD SOPS plugin decision]

## Key Rotation Procedures
[age key, OpenBao unseal key, root token, KV v2 secret, dynamic creds, PKI CA]

## Emergency Procedures
[OpenBao sealed, pod crash, ESO failure, SOPS key lost, mass rotation after breach]

## Backup Strategy
[Velero PVC backup, OpenBao Raft snapshot, MinIO → Backblaze B2, restore testing]
```

Be thorough, opinionated, and practical. Include actual CLI commands (`bao kv put`, `sops --encrypt`, `kubectl get externalsecret`), actual YAML (ClusterSecretStore, ExternalSecret, OpenBao policy HCL), actual `.sops.yaml` config, and actual Helm values snippets. Do NOT give me theory — give me copy-paste-ready configs for a K3s cluster on AlmaLinux 9.7 at Hetzner Cloud. Flag any difference between OpenBao and HashiCorp Vault where it matters.
