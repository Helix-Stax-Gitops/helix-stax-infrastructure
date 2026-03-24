---
title: Secrets Lifecycle Architecture
author: Wakeem Williams
co_author: Quinn Mercer
date: 2026-03-23
status: Active
version: "1.0"
compliance_frameworks:
  - SOC 2 (CC6.1, CC6.7)
  - ISO 27001:2022 (A.5.33, A.8.24)
  - NIST CSF 2.0 (PR.AC-1, PR.DS-1)
  - HIPAA (164.312(a)(2)(iv), 164.312(d))
references:
  - ADR-005 (LUKS FDE with dracut-sshd)
  - ADR-006 (OpenBao transit unseal)
  - ADR-008 (Dual workflow engine)
  - docs/architecture/secrets-management.md
---

# Secrets Lifecycle Architecture

## 1. Overview

OpenBao serves as the single source of truth for all secrets in the Helix Stax infrastructure. This document defines the complete lifecycle: generation, storage, rotation, distribution, consumption, and retirement of secrets across the three-store model (OpenBao, Cloudflare Secrets Store, local .env.secrets).

---

## 2. Three-Store Model

```
+----------------------------+     +----------------------------+
|    OpenBao (Primary KMS)   |     |  Cloudflare Secrets Store  |
|    K3s cluster / Hetzner   |     |  Edge / Workers            |
+----------------------------+     +----------------------------+
| Dynamic secrets:           |     | Worker secrets:            |
|   - PostgreSQL creds       |     |   - API keys (ClickUp)     |
|   - PKI certificates       |     |   - OAuth creds (Google)   |
|   - SSH keys               |     |   - CF API tokens          |
| Static secrets:            |     |   - Service tokens         |
|   - Cosign signing keys    |     +----------------------------+
|   - MinIO SSE-KMS keys     |                 ^
|   - Transit unseal keys    |                 |
+----------------------------+      Sync via rotation pipeline
              |
              v
+----------------------------+
|  ESO (External Secrets     |
|  Operator) -> K8s Secrets  |
+----------------------------+
              |
              v
+----------------------------+
|  K8s Pods consume secrets  |
|  via env vars or volumes   |
+----------------------------+
```

---

## 3. OpenBao Architecture

### 3.1 Transit Unseal Node (ADR-006)

On Hetzner bare metal without a cloud KMS, OpenBao cannot use auto-unseal via AWS KMS or GCP KMS. Instead, a dedicated Transit Unseal Node provides automatic unseal on reboot.

```
+--------------------------------------------+
|  helix-stax-cp (Control Plane)             |
|                                            |
|  +--------------------------------------+  |
|  |  OpenBao Primary (HA)                |  |
|  |  seal "transit" {                    |  |
|  |    address = "http://unseal:8200"    |  |
|  |    token   = "<transit-token>"       |  |
|  |    key_name = "autounseal"           |  |
|  |  }                                   |  |
|  +--------------------------------------+  |
|              |                              |
|              | Transit API call             |
|              v                              |
|  +--------------------------------------+  |
|  |  OpenBao Transit Node (standalone)   |  |
|  |  - Dedicated to unseal operations    |  |
|  |  - transit/keys/autounseal           |  |
|  |  - Minimal attack surface            |  |
|  |  - Separate Shamir keys for init     |  |
|  +--------------------------------------+  |
+--------------------------------------------+

Alternative (emergency): Manual Shamir Secret Sharing
  - 3 key shares, threshold of 2
  - Shares stored in separate physical locations
  - Used only if transit node fails
```

### 3.2 Secret Engines

| Engine | Mount Path | Purpose | Consumers |
|--------|-----------|---------|-----------|
| KV v2 | `secret/` | Static secrets (API keys, tokens) | ESO -> K8s pods |
| Database | `database/` | Dynamic PostgreSQL credentials | CloudNativePG, apps |
| PKI | `pki/` | Internal TLS certificates | cert-manager, services |
| SSH | `ssh/` | Signed SSH certificates | Ansible, operators |
| Transit | `transit/` | Encryption-as-a-service | MinIO SSE-KMS, Cosign |
| TOTP | `totp/` | Time-based OTP generation | Break-glass access |

### 3.3 Auth Methods

| Method | Use Case | TTL |
|--------|----------|-----|
| Kubernetes | Pod identity -> secret access | 1h |
| AppRole | CI/CD pipeline authentication | 30m |
| Userpass | Human operator emergency access | 8h |
| Token | Transit unseal node | Non-expiring (scoped) |

---

## 4. Dynamic Secrets

### 4.1 PostgreSQL Dynamic Credentials

OpenBao generates short-lived PostgreSQL credentials on demand.

```
+----------+     +----------+     +----------+     +----------+
|  K8s Pod | --> |   ESO    | --> |  OpenBao | --> | CloudNPG |
| (app)    |     | (sync)   |     | database/|     | (PG)     |
+----------+     +----------+     +----------+     +----------+

Flow:
1. ESO ExternalSecret references OpenBao database/ engine
2. OpenBao generates temporary PG user with scoped permissions
3. Credentials injected as K8s Secret
4. Pod consumes credentials via env var
5. Credentials auto-expire after TTL (1h default)
6. OpenBao revokes credentials on lease expiry
```

**Rotation**: Automatic via lease expiry. No manual rotation needed.

### 4.2 PKI Certificates

OpenBao issues short-lived TLS certificates for internal mTLS.

| Certificate Type | TTL | Rotation | Consumers |
|-----------------|-----|----------|-----------|
| Internal service TLS | 24h | Automatic (cert-manager) | Inter-service communication |
| Intermediate CA | 1 year | Manual renewal | cert-manager |
| Root CA | 10 years | Manual (offline ceremony) | Trust anchor |

### 4.3 SSH Certificates

Signed SSH certificates replace static SSH keys for operator access.

```
Operator -> OpenBao SSH sign -> Signed certificate (TTL 8h)
         -> SSH to server with signed cert
         -> Server validates against OpenBao CA public key
```

---

## 5. Auto-Rotation Pipeline

### 5.1 Pipeline Architecture

```
+----------+     +-----------+     +----------+     +------------------+
| OpenBao  | --> |  Airflow  | --> |   n8n    | --> | Cloudflare       |
| (rotate) |     |  DAG      |     | (webhook)|     | Secrets Store    |
+----------+     +-----------+     +----------+     | API update       |
     |                                    |          +------------------+
     |                                    |
     |                                    v
     |                           +------------------+
     |                           | Rocket.Chat      |
     |                           | (notification)   |
     |                           +------------------+
     |
     v
+------------------+
| MinIO            |
| (audit log)      |
| Object Lock      |
+------------------+
```

### 5.2 Rotation Flow (Step by Step)

```
1. TRIGGER
   Airflow DAG runs on schedule (or OpenBao lease expiry event)
       |
       v
2. ROTATE
   Airflow task calls OpenBao API:
     POST /v1/sys/rotate       (for encryption keys)
     POST /v1/database/rotate-root/{name}  (for DB creds)
     POST /v1/pki/tidy         (for cert cleanup)
       |
       v
3. VERIFY
   Airflow task verifies new secret is functional:
     - DB connection test with new creds
     - TLS handshake with new cert
     - API call with new token
       |
       v
4. SYNC (if Cloudflare secrets affected)
   Airflow SimpleHttpOperator -> n8n webhook:
     POST https://n8n.helixstax.net/webhook/secret-rotation
     Body: { "secret_name": "...", "store": "cloudflare" }
       |
       v
5. UPDATE CLOUDFLARE
   n8n workflow:
     - Fetch new value from OpenBao KV
     - PUT to Cloudflare Secrets Store API
     - Verify Worker can read new value
       |
       v
6. NOTIFY
   n8n -> Rocket.Chat #infra-alerts:
     "Secret {name} rotated successfully. New expiry: {date}"
       |
       v
7. AUDIT
   n8n -> MinIO (Object Lock bucket):
     Upload rotation evidence: timestamp, secret name,
     rotation type, verification result, SHA-256 hash
```

### 5.3 Rotation Cadence

| Secret Type | Rotation Period | Method | Framework Requirement |
|-------------|----------------|--------|----------------------|
| PostgreSQL dynamic creds | 1 hour (TTL) | Automatic (lease expiry) | SOC 2 CC6.1 |
| API keys (ClickUp, etc.) | 90 days | Airflow DAG | ISO 27001 A.5.33 |
| TLS certificates (internal) | 24 hours | cert-manager + OpenBao PKI | NIST CSF PR.AC-1 |
| SSH certificates | 8 hours (TTL) | On-demand signing | CIS Controls v8.1 5.2 |
| Cosign signing key | 180 days | Manual (ceremony) | SOC 2 CC6.7 |
| OpenBao encryption key | 90 days | Airflow DAG | HIPAA 164.312(a)(2)(iv) |
| MinIO SSE-KMS key | 365 days | Manual + Airflow notify | ISO 27001 A.8.24 |
| Transit unseal token | Never (scoped) | Manual if compromised | ADR-006 |
| Cloudflare API token | 90 days | Airflow DAG | SOC 2 CC6.1 |

---

## 6. External Secrets Operator (ESO)

ESO bridges OpenBao and Kubernetes, syncing secrets into K8s-native Secret objects.

```
+------------------+     +------------------+     +------------------+
|  OpenBao         | <-- |  ESO             | --> |  K8s Secret      |
|  secret/data/app |     |  SecretStore     |     |  app-secrets     |
+------------------+     |  ExternalSecret  |     +------------------+
                          +------------------+            |
                                                          v
                                                  +------------------+
                                                  |  Pod             |
                                                  |  env/volume      |
                                                  +------------------+

ESO Refresh Interval: 1 minute (default)
ESO reconciles ExternalSecret -> K8s Secret on each interval
If OpenBao value changes, K8s Secret updates automatically
Pod restart required for env var consumption (not volume)
```

---

## 7. Emergency Rotation Playbook

### 7.1 Trigger Conditions

- Credential exposure detected (git commit, log leak, CVE)
- Personnel departure with access to secrets
- Breach or suspected compromise at any layer
- Audit finding requiring immediate remediation

### 7.2 Emergency Procedure

```
IMMEDIATE (< 15 minutes):
  1. Identify scope: which secrets are affected?
  2. Revoke compromised credentials in OpenBao:
       vault lease revoke -prefix <path>
  3. Rotate affected secrets:
       vault write -force <engine>/rotate-root/<name>
  4. If Cloudflare secrets: trigger n8n emergency webhook
  5. Notify #incident-response in Rocket.Chat

FOLLOW-UP (< 1 hour):
  6. Verify all consumers are using new credentials
  7. Review audit logs for unauthorized usage of old credentials
  8. Update rotation evidence in MinIO (Object Lock)

POST-INCIDENT (< 24 hours):
  9. Root cause analysis
  10. Update rotation cadence if warranted
  11. File incident report (docs/runbooks/incident-report template)
```

### 7.3 Break-Glass Access

For emergency access when normal auth is unavailable:

```
Break-Glass Procedure:
  1. Retrieve Shamir key shares (2 of 3 required)
     - Share 1: Wakeem (physical token)
     - Share 2: Encrypted backup (Backblaze B2)
     - Share 3: Printed and sealed (offsite safe)
  2. Manually unseal OpenBao:
       vault operator unseal <share-1>
       vault operator unseal <share-2>
  3. Use root token (generated from shares) for emergency ops
  4. Revoke root token immediately after use:
       vault token revoke <root-token>
  5. Document all actions taken during break-glass event
```

---

## 8. Compliance Evidence

| Control | Evidence | Storage | Retention |
|---------|----------|---------|-----------|
| Key rotation performed | Rotation event log + timestamp | MinIO (Object Lock) | 7 years (HIPAA) |
| Access to secrets audited | OpenBao audit log | Loki + MinIO archive | 1 year (SOC 2) |
| Encryption at rest verified | LUKS + SSE-KMS config | OpenSCAP report | 1 year |
| Dynamic creds TTL enforced | OpenBao lease metadata | OpenBao audit log | 1 year |
| Emergency rotation tested | Quarterly drill report | MinIO (Object Lock) | 7 years |

---

## 9. Related Documents

| Document | Relevance |
|----------|-----------|
| [secrets-management.md](secrets-management.md) | Three-store model details, Cloudflare inventory |
| [infrastructure-buildout-master-plan.md](infrastructure-buildout-master-plan.md) | OpenBao deployment in Phase 3 |
| [dual-workflow-architecture.md](dual-workflow-architecture.md) | Airflow DAG + n8n webhook integration |
| [compliance-scanning-architecture.md](compliance-scanning-architecture.md) | Evidence pipeline to MinIO |
