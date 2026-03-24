# Secrets Management

**Author**: Wakeem Williams
**Date**: 2026-03-05 (updated 2026-03-06)
**Status**: ACTIVE
**Platform**: Helix Stax (2-node k3s + CX32 Authentik VM + Cloudflare)

> **KNOWN EXPOSURE**: A security review on 2026-03-06 found plaintext credentials committed to git history (pgvector password, Grafana admin password, Ollama htpasswd, n8n passwords, SearXNG secret key). These credentials require immediate rotation. See **[credential-rotation-checklist.md](credential-rotation-checklist.md)** for the full rotation runbook.

---

## Prerequisites

- `kubectl` configured with cluster kubeconfig
- Access to Hetzner Cloud Console (for VM management)
- Cloudflare dashboard access (Wakeem's account)
- Google Workspace admin access (for OAuth app management)

---

## 1. Secrets Inventory

### 1.1 Infrastructure Secrets

| Secret | Location | Type | Used By |
|--------|----------|------|---------|
| k3s server token | `/var/lib/rancher/k3s/server/token` on helix-cp-1 | Shared secret | k3s agent join |
| k3s kubeconfig | `~/.config/helix-stax/secrets/kubeconfig` (local) | Certificate + key | kubectl, CI/CD |
| SSH private key (helix-cp-1) | `~/.ssh/` (Wakeem's machine) | RSA/Ed25519 key | Server access |
| SSH private key (helix-worker-1) | `~/.ssh/` (Wakeem's machine) | RSA/Ed25519 key | Server access |
| SSH private key (CX32) | `~/.ssh/` (Wakeem's machine) | RSA/Ed25519 key | Authentik VM access |
| Hetzner Cloud API token | Hetzner Cloud Console | API token | Terraform, CCM |
| Hetzner Robot credentials | Hetzner Robot web UI | Username + password | Server management |
| Restic backup password | VAULT://backup/restic-password | Passphrase | Backup encryption |

### 1.2 Application Secrets (Kubernetes)

| Secret Name | Namespace | Contents | Used By |
|-------------|-----------|----------|---------|
| devtron-secret | devtroncd | Devtron admin password | Devtron dashboard login |
| postgresql-postgresql | devtroncd | PostgreSQL credentials | Devtron, ArgoCD |
| n8n-secret | ai-agents | N8N_ENCRYPTION_KEY, DB creds | n8n |
| ollama-basic-auth | ai-agents | htpasswd for Ollama ingress | Traefik basic auth |
| open-webui-secret | open-webui | WEBUI_SECRET_KEY | Open WebUI |
| pgvector-secret | ai-agents | POSTGRES_PASSWORD | pgvector |
| grafana-admin | monitoring | admin password | Grafana login |

### 1.3 External Service Secrets

| Secret | Provider | Scope | Used By |
|--------|----------|-------|---------|
| Cloudflare API token | Cloudflare | DNS edit (3 zones) | cert-manager, external-dns |
| Cloudflare API token (read-only) | Cloudflare | DNS read (3 zones) | Backup scripts |
| Google OAuth client ID | Google Cloud Console | OpenID Connect | Authentik (upstream IdP) |
| Google OAuth client secret | Google Cloud Console | OpenID Connect | Authentik (upstream IdP) |
| GitHub PAT (Devtron) | GitHub | repo, packages:read | Devtron git-sensor |
| NetBird setup key | NetBird dashboard | Peer enrollment | NetBird clients |
| Authentik secret key | CX32 `.env` | Django secret | Authentik |
| Authentik PostgreSQL password | CX32 `.env` | DB auth | Authentik |
| Authentik bootstrap password | CX32 `.env` | Initial admin | Authentik setup |

### 1.4 Future Secrets (Post-Vault Deployment)

When OpenBao + ESO are deployed, all K8s secrets will migrate to:
- **OpenBao KV v2** at `secret/<namespace>/<app>`
- **ExternalSecret CRDs** syncing to K8s secrets
- K8s secrets become ESO-managed (not manually created)

---

## 2. VAULT:// Reference Resolution

Throughout documentation, `VAULT://` references indicate secrets that must be resolved at deploy time.

### Current Resolution (Pre-Vault)

Until OpenBao is deployed, `VAULT://` references resolve manually:

| Reference | Resolution |
|-----------|------------|
| `VAULT://cloudflare/api-token` | Cloudflare dashboard > API Tokens |
| `VAULT://cloudflare/api-token-readonly` | Cloudflare dashboard > API Tokens (read-only) |
| `VAULT://google/oauth-client-id` | Google Cloud Console > Credentials |
| `VAULT://google/oauth-client-secret` | Google Cloud Console > Credentials |
| `VAULT://authentik/secret-key` | Generated: `openssl rand -base64 60` |
| `VAULT://authentik/pg-password` | Generated: `openssl rand -base64 32` |
| `VAULT://authentik/bootstrap-password` | Chosen by admin |
| `VAULT://backup/restic-password` | Generated: `openssl rand -base64 32` |
| `VAULT://netbird/setup-key` | NetBird dashboard > Setup Keys |
| `VAULT://github/pat-devtron` | GitHub > Settings > Tokens |

### Future Resolution (Post-Vault)

```
VAULT://cloudflare/api-token
  -> OpenBao KV v2: secret/data/cloudflare {"api-token": "..."}
  -> ExternalSecret: spec.data[].remoteRef.key = "secret/data/cloudflare"
  -> K8s Secret: cloudflare-credentials in target namespace
  -> Pod env: secretKeyRef to cloudflare-credentials
```

---

## 3. Rotation Schedule

### 3.1 Regular Rotation

| Secret | Rotation Interval | Procedure |
|--------|-------------------|-----------|
| Devtron admin password | 90 days | See 3.3 |
| Grafana admin password | 90 days | Grafana UI > Admin > Change password |
| Ollama basic auth | 90 days | `htpasswd -nb admin <new-pass>`, update K8s secret |
| n8n encryption key | Never (breaks existing credentials) | Only rotate if compromised |
| GitHub PAT (Devtron) | 90 days (or use fine-grained with expiry) | GitHub > Settings > Tokens > Regenerate |
| Cloudflare API token | 180 days | Cloudflare > API Tokens > Roll |
| Google OAuth client secret | 180 days | Google Cloud Console > Credentials > Reset |
| NetBird setup key | On use (one-time keys preferred) | NetBird dashboard > Setup Keys |
| Restic backup password | Annually | See 3.4 |
| SSH keys | Annually | See 3.5 |

### 3.2 Rotation Triggers (Immediate)

Rotate immediately if:
- Secret exposed in logs, git, or public channel
- Team member with access leaves the project
- Suspicious authentication activity detected
- Vendor reports a breach

> **2026-03-06**: Trigger activated -- credentials found in git history. See [credential-rotation-checklist.md](credential-rotation-checklist.md) for the active rotation plan.

### 3.3 Devtron Admin Password Rotation

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 24)

# 2. Update K8s secret
kubectl -n devtroncd get secret devtron-secret -o json \
  | jq --arg pw "$(echo -n "$NEW_PASS" | base64)" '.data["admin-password"]=$pw' \
  | kubectl apply -f -

# 3. Restart Devtron to pick up new secret
kubectl -n devtroncd rollout restart deployment devtron

# 4. Verify login with new password
echo "New Devtron admin password: $NEW_PASS"

# 5. Store securely (Wakeem's password manager)
```

### 3.4 Restic Backup Password Rotation

```bash
# WARNING: Changing restic password requires re-initializing the repository
# Old backups become inaccessible without old password

# 1. Verify current backups are intact
restic check

# 2. Save old password securely (needed to access old snapshots)
# 3. Change password
restic key add    # Enter new password
restic key list   # Note old key ID
restic key remove <old-key-id>

# 4. Update VAULT://backup/restic-password
# 5. Test backup + restore cycle
```

### 3.5 SSH Key Rotation

```bash
# 1. Generate new key pair
ssh-keygen -t ed25519 -f ~/.ssh/helix-cp-1-new -C "wakeem@helixstax.net"

# 2. Add new public key to server
ssh helix-cp-1 "echo '$(cat ~/.ssh/helix-cp-1-new.pub)' >> ~/.ssh/authorized_keys"

# 3. Test login with new key
ssh -i ~/.ssh/helix-cp-1-new helix-cp-1

# 4. Remove old public key from server
ssh -i ~/.ssh/helix-cp-1-new helix-cp-1 "sed -i '/OLD_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys"

# 5. Update local SSH config
# 6. Repeat for helix-worker-1 and CX32
```

---

## 4. Emergency Secret Rotation

### Scenario: Secret Compromised

**Response time**: Within 1 hour of discovery.

```
1. IDENTIFY which secret is compromised
2. ASSESS blast radius (what can the attacker access?)
3. ROTATE the compromised secret immediately
4. REVOKE old tokens/keys at the provider
5. AUDIT logs for unauthorized access during exposure window
6. NOTIFY Wakeem if not already aware
7. DOCUMENT in incident log (see incident-response.md)
```

### Emergency: Kubeconfig Compromised

```bash
# CRITICAL: Full cluster access compromised

# 1. Rotate k3s server certificate
systemctl stop k3s
rm /var/lib/rancher/k3s/server/tls/client-admin.crt
rm /var/lib/rancher/k3s/server/tls/client-admin.key
systemctl start k3s
# k3s regenerates on start

# 2. Extract new kubeconfig
cat /etc/rancher/k3s/k3s.yaml  # Copy and update server URL

# 3. Delete old kubeconfig from all locations
# 4. Check audit logs for unauthorized API calls
kubectl logs -n kube-system -l component=kube-apiserver --since=24h | grep -i "unauthorized\|forbidden"
```

### Emergency: Cloudflare API Token Compromised

```bash
# 1. Go to Cloudflare dashboard > API Tokens
# 2. Delete compromised token immediately
# 3. Create new token with same (minimal) permissions
# 4. Update in cert-manager/external-dns K8s secrets
# 5. Check Cloudflare audit log for unauthorized changes
# 6. Review DNS records for tampering
```

---

## 5. Minimal API Scopes

### Cloudflare API Token (cert-manager + external-dns)

| Permission | Resource | Why |
|------------|----------|-----|
| Zone:DNS:Edit | helixstax.net, helixstax.com, vacancyservices.com | cert-manager ACME DNS-01 challenges, external-dns record management |
| Zone:Zone:Read | helixstax.net, helixstax.com, vacancyservices.com | List zones for DNS record lookup |

**Do NOT grant**: Zone Settings, Firewall, WAF, Workers, Pages, or Account-level permissions.

### Cloudflare API Token (backup/read-only)

| Permission | Resource | Why |
|------------|----------|-----|
| Zone:DNS:Read | All zones | Export DNS records for backup |

### Google OAuth (Authentik upstream)

| Scope | Why |
|-------|-----|
| `openid` | OIDC identity |
| `email` | User email for matching |
| `profile` | Display name |

**Do NOT grant**: Drive, Calendar, Admin SDK, or any Google Workspace admin scopes.

### GitHub PAT (Devtron)

| Permission | Why |
|------------|-----|
| `repo` (or fine-grained: Contents read) | Clone source repos |
| `read:packages` | Pull from GHCR |
| `write:packages` | Push images to GHCR |

**Do NOT grant**: admin:org, delete_repo, admin:repo_hook (Devtron creates webhooks via its own mechanism).

### NetBird

| Scope | Why |
|-------|-----|
| Setup key: reusable, with expiry | Peer enrollment |
| Peer group: helix-stax-servers | Limit network access |

**Do NOT grant**: Admin API token (only needed for NetBird management, not peer enrollment).

---

## 6. Secret Generation Standards

| Type | Method | Minimum Length |
|------|--------|---------------|
| Database passwords | `openssl rand -base64 32` | 32 characters |
| API tokens | Provider-generated | Provider default |
| Encryption keys | `openssl rand -base64 60` | 60 characters |
| Admin passwords | Chosen + stored in password manager | 16 characters, mixed case + numbers + symbols |
| SSH keys | `ssh-keygen -t ed25519` | Ed25519 (fixed 256-bit) |

---

## 7. Verification

After any secret rotation:

- [ ] Service using the secret restarts cleanly
- [ ] Authentication works with new credentials
- [ ] Old credentials are rejected (test explicitly)
- [ ] Backup scripts still work (if backup credentials changed)
- [ ] Monitoring alerts are not firing
- [ ] Updated credential stored in Wakeem's password manager
