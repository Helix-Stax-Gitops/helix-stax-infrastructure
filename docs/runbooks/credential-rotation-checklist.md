# Credential Rotation Checklist

**Date**: 2026-03-06
**Reason**: Plaintext credentials found committed to git history (security review finding #1-3, #25)
**Decision**: Rotate all exposed credentials. Move to OpenBao/ESO when deployed. Git history rewrite deferred (rotate-first approach).
**Reference**: docs/review/security-assessment.md

---

## Exposed Credentials Inventory

| # | Service | File | Secret Type | Namespace | Status |
|---|---------|------|-------------|-----------|--------|
| 1 | pgvector DB | `k8s/pgvector/pgvector-secret.yaml` | POSTGRES_PASSWORD (stringData) | ai-agents | [ ] Rotated |
| 2 | Grafana admin | `k8s/monitoring/values.yaml` | adminPassword (plaintext in Helm values) | monitoring | [ ] Rotated |
| 3 | Ollama basic-auth | `k8s/ollama-ingress/basic-auth-secret.yaml` | APR1 htpasswd hash (crackable) | ai-agents | [ ] Rotated |
| 4 | n8n basic auth | `k8s/ai-agents/n8n-deployment.yaml` | N8N_BASIC_AUTH_PASSWORD (stringData) | ai-agents | [ ] Rotated |
| 5 | n8n encryption key | `k8s/ai-agents/n8n-deployment.yaml` | N8N_ENCRYPTION_KEY (stringData) | ai-agents | [ ] Rotated (see warning) |
| 6 | SearXNG secret key | `k8s/searxng/searxng-deployment.yaml` | server.secret_key (ConfigMap) | ai-agents | [ ] Rotated |

> **WARNING**: Rotating n8n's `N8N_ENCRYPTION_KEY` (item #5) will break all existing n8n credentials (API keys, OAuth tokens stored within n8n workflows). Only rotate if confirmed compromised. If the key was only exposed in git but never used by an attacker, the risk may be acceptable until OpenBao migration.

---

## Pre-Rotation Checklist

- [ ] Ensure kubectl access to cluster (`kubectl get nodes` succeeds)
- [ ] Confirm which services are currently running (`kubectl get pods -A`)
- [ ] Back up current secrets before rotation:
  ```bash
  kubectl -n ai-agents get secret pgvector-credentials -o yaml > /tmp/pgvector-secret-backup.yaml
  kubectl -n ai-agents get secret ollama-basic-auth -o yaml > /tmp/ollama-auth-backup.yaml
  kubectl -n ai-agents get secret n8n-secrets -o yaml > /tmp/n8n-secrets-backup.yaml
  ```
- [ ] Store new credentials in password manager before applying

---

## Rotation Procedures

### 1. pgvector Database Password

**Risk**: Active database -- incorrect rotation breaks n8n + Open WebUI vector queries.

**Steps**:

```bash
# 1. Generate new password
NEW_PG_PASS=$(openssl rand -base64 32)
echo "New pgvector password: $NEW_PG_PASS"
# Store in password manager NOW before proceeding

# 2. Connect to pgvector and change the password
kubectl -n ai-agents exec -it deploy/pgvector -- psql -U vectoruser -d vectordb -c \
  "ALTER USER vectoruser WITH PASSWORD '${NEW_PG_PASS}';"

# 3. Update the K8s secret with new password
kubectl -n ai-agents create secret generic pgvector-credentials \
  --from-literal=POSTGRES_DB=vectordb \
  --from-literal=POSTGRES_USER=vectoruser \
  --from-literal=POSTGRES_PASSWORD="${NEW_PG_PASS}" \
  --from-literal=DATABASE_URL="postgresql://vectoruser:${NEW_PG_PASS}@pgvector.ai-agents.svc:5432/vectordb" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Restart pgvector pod to pick up new secret
kubectl -n ai-agents rollout restart deployment pgvector

# 5. Wait for pod to be ready
kubectl -n ai-agents rollout status deployment pgvector --timeout=120s

# 6. Verify database connectivity
kubectl -n ai-agents exec -it deploy/pgvector -- psql -U vectoruser -d vectordb -c "SELECT 1;"

# 7. Restart any dependent services (n8n, Open WebUI if they reference pgvector)
kubectl -n ai-agents rollout restart deployment n8n 2>/dev/null || true
kubectl -n ai-agents rollout restart deployment open-webui 2>/dev/null || true
```

**Verification**:
- [ ] pgvector pod running and ready
- [ ] `SELECT 1` query succeeds with new credentials
- [ ] Old password rejected: `PGPASSWORD=OLD_PASS psql -h ... -U vectoruser` fails
- [ ] Dependent services reconnected (check pod logs)

---

### 2. Grafana Admin Password

**Risk**: Low -- admin login only, no downstream dependencies.

**Steps**:

```bash
# 1. Generate new password
NEW_GRAFANA_PASS=$(openssl rand -base64 24)
echo "New Grafana admin password: $NEW_GRAFANA_PASS"
# Store in password manager NOW

# 2. Change password via Grafana API (preferred -- no restart needed)
GRAFANA_POD=$(kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

kubectl -n monitoring exec "$GRAFANA_POD" -- \
  curl -s -X PUT http://localhost:3000/api/admin/users/1/password \
  -H "Content-Type: application/json" \
  -u "admin:CURRENT_PASSWORD_HERE" \
  -d "{\"password\": \"${NEW_GRAFANA_PASS}\"}"

# 3. Update Helm values to NOT contain plaintext password
#    Instead, create a K8s secret and reference it:
kubectl -n monitoring create secret generic grafana-admin-credentials \
  --from-literal=admin-password="${NEW_GRAFANA_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Verify login
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
# Test: curl -u admin:NEW_PASS http://localhost:3000/api/org
# Then kill the port-forward
```

**Post-rotation Helm values update** (remove plaintext from values.yaml):

Replace the `adminPassword` line in `k8s/monitoring/values.yaml` with:
```yaml
grafana:
  admin:
    existingSecret: grafana-admin-credentials
    passwordKey: admin-password
```

**Verification**:
- [ ] Login succeeds with new password at Grafana UI
- [ ] Old password `HelixStax2026!` rejected
- [ ] Helm values no longer contain plaintext password

---

### 3. Ollama Basic Auth

**Risk**: Low -- ingress auth only, no database dependency.

**Steps**:

```bash
# 1. Generate new password
NEW_OLLAMA_PASS=$(openssl rand -base64 24)
echo "New Ollama basic-auth password: $NEW_OLLAMA_PASS"
# Store in password manager NOW

# 2. Generate new htpasswd hash
#    Option A: Using htpasswd (if available)
NEW_HTPASSWD=$(htpasswd -nb admin "$NEW_OLLAMA_PASS")

#    Option B: Using openssl (if htpasswd not available)
#    NEW_HTPASSWD="admin:$(openssl passwd -apr1 "$NEW_OLLAMA_PASS")"

# 3. Update the K8s secret
kubectl -n ai-agents create secret generic ollama-basic-auth \
  --from-literal=users="${NEW_HTPASSWD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Traefik picks up secret changes automatically (no restart needed)
#    But if using cached middleware, force reload:
kubectl -n ai-agents rollout restart deployment traefik 2>/dev/null || true

# 5. Verify auth works
# curl -u admin:NEW_PASS http://ollama.138.201.131.157.nip.io/api/tags
```

**Verification**:
- [ ] `curl -u admin:NEW_PASS .../api/tags` returns 200
- [ ] `curl -u admin:OLD_PASS .../api/tags` returns 401
- [ ] Open WebUI Ollama connection still works (update connection settings if it uses basic auth)

---

### 4. n8n Basic Auth Password

**Risk**: Low -- login password only. n8n encryption key is handled separately.

**Steps**:

```bash
# 1. Generate new password
NEW_N8N_PASS=$(openssl rand -base64 24)
echo "New n8n basic auth password: $NEW_N8N_PASS"
# Store in password manager NOW

# 2. Update the K8s secret (preserve encryption key unchanged)
EXISTING_ENC_KEY=$(kubectl -n ai-agents get secret n8n-secrets -o jsonpath='{.data.N8N_ENCRYPTION_KEY}' | base64 -d)

kubectl -n ai-agents create secret generic n8n-secrets \
  --from-literal=N8N_ENCRYPTION_KEY="${EXISTING_ENC_KEY}" \
  --from-literal=N8N_BASIC_AUTH_PASSWORD="${NEW_N8N_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart n8n to pick up new secret
kubectl -n ai-agents rollout restart deployment n8n

# 4. Wait for ready
kubectl -n ai-agents rollout status deployment n8n --timeout=120s
```

**Verification**:
- [ ] n8n login succeeds with new password
- [ ] Old password rejected
- [ ] Existing workflows still execute (encryption key unchanged)

---

### 5. n8n Encryption Key (CONDITIONAL)

> **ONLY rotate if confirmed compromised.** Rotating this key invalidates all stored credentials in n8n workflows (API keys, OAuth tokens, database passwords stored within n8n). All credentials must be re-entered after rotation.

**Steps (if rotating)**:

```bash
# 1. Export all n8n workflows FIRST (before rotation)
# Via n8n UI: Settings > Export all workflows
# Or via API: curl http://n8n-host/api/v1/workflows -H "X-N8N-API-KEY: ..."

# 2. Generate new encryption key
NEW_ENC_KEY=$(openssl rand -hex 32)

# 3. Update secret
kubectl -n ai-agents create secret generic n8n-secrets \
  --from-literal=N8N_ENCRYPTION_KEY="${NEW_ENC_KEY}" \
  --from-literal=N8N_BASIC_AUTH_PASSWORD="CURRENT_AUTH_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Restart n8n
kubectl -n ai-agents rollout restart deployment n8n

# 5. Re-enter ALL credentials in n8n UI
# Every credential node (API keys, OAuth, DB passwords) must be re-configured
```

**Verification**:
- [ ] n8n starts successfully
- [ ] All credentials re-entered and tested
- [ ] Workflows execute end-to-end

---

### 6. SearXNG Secret Key

**Risk**: Very low -- internal service, no auth, key used for CSRF/session signing.

**Steps**:

```bash
# 1. Generate new secret key
NEW_SEARX_KEY=$(openssl rand -hex 32)

# 2. Update the ConfigMap
kubectl -n ai-agents get configmap searxng-settings -o yaml | \
  sed "s/secret_key: \".*\"/secret_key: \"${NEW_SEARX_KEY}\"/" | \
  kubectl apply -f -

# 3. Restart SearXNG
kubectl -n ai-agents rollout restart deployment searxng

# 4. Wait for ready
kubectl -n ai-agents rollout status deployment searxng --timeout=60s
```

**Verification**:
- [ ] SearXNG pod running
- [ ] Search queries return results

---

## Recommended Rotation Order

Execute in this order to minimize cascading failures:

1. **SearXNG secret key** (#6) -- lowest risk, validates the rotation process
2. **Ollama basic auth** (#3) -- no database, simple secret swap
3. **Grafana admin password** (#2) -- API-based rotation, no restart needed
4. **n8n basic auth password** (#4) -- secret update + restart
5. **pgvector database password** (#1) -- highest risk, database credential change
6. **n8n encryption key** (#5) -- ONLY if confirmed compromised

---

## Post-Rotation: Update Git Repository

After all rotations are complete, update the YAML files to remove plaintext credentials:

```bash
# 1. Replace pgvector-secret.yaml with placeholder
cat > k8s/pgvector/pgvector-secret.yaml << 'EOF'
# ROTATED 2026-03-06 -- This secret is now managed via kubectl.
# Do NOT commit real credentials to this file.
# See runbooks/credential-rotation-checklist.md
#
# To recreate:
#   kubectl -n ai-agents create secret generic pgvector-credentials \
#     --from-literal=POSTGRES_DB=vectordb \
#     --from-literal=POSTGRES_USER=vectoruser \
#     --from-literal=POSTGRES_PASSWORD="<from-password-manager>" \
#     --from-literal=DATABASE_URL="postgresql://vectoruser:<password>@pgvector.ai-agents.svc:5432/vectordb"
EOF

# 2. Replace ollama basic-auth-secret.yaml with placeholder
cat > k8s/ollama-ingress/basic-auth-secret.yaml << 'EOF'
# ROTATED 2026-03-06 -- This secret is now managed via kubectl.
# See runbooks/credential-rotation-checklist.md
#
# To recreate:
#   htpasswd -nb admin "<password>" > /tmp/users
#   kubectl -n ai-agents create secret generic ollama-basic-auth --from-file=users=/tmp/users
EOF

# 3. Replace n8n secret section with placeholder
cat > k8s/ai-agents/n8n-secret-placeholder.yaml << 'EOF'
# ROTATED 2026-03-06 -- n8n secrets are now managed via kubectl.
# See runbooks/credential-rotation-checklist.md
#
# To recreate:
#   kubectl -n ai-agents create secret generic n8n-secrets \
#     --from-literal=N8N_ENCRYPTION_KEY="<from-password-manager>" \
#     --from-literal=N8N_BASIC_AUTH_PASSWORD="<from-password-manager>"
EOF

# 4. Update monitoring values.yaml -- replace adminPassword with secret reference
#    (See Grafana section above for the Helm values change)

# 5. Update searxng-deployment.yaml -- replace secret_key with placeholder
#    sed -i 's/secret_key: ".*"/secret_key: "ROTATED-SEE-CONFIGMAP"/' k8s/searxng/searxng-deployment.yaml

# 6. Commit the sanitized files
git add -A
git commit -m "chore(security): remove plaintext credentials from tracked files

Credentials rotated per security assessment findings #1-3.
See runbooks/credential-rotation-checklist.md for procedures.
Secrets now managed via kubectl create secret (pre-OpenBao).
Ref: docs/review/security-assessment.md"
```

---

## Migration to OpenBao/ESO (Future)

When OpenBao and External Secrets Operator are deployed, each credential should be stored and synced as follows:

### OpenBao KV v2 Paths

| Secret | OpenBao Path | Keys |
|--------|-------------|------|
| pgvector | `secret/ai-agents/pgvector` | `username`, `password`, `database`, `database-url` |
| Grafana | `secret/monitoring/grafana` | `admin-password` |
| Ollama | `secret/ai-agents/ollama` | `basic-auth-htpasswd` |
| n8n | `secret/ai-agents/n8n` | `encryption-key`, `basic-auth-password` |
| SearXNG | `secret/ai-agents/searxng` | `secret-key` |

### ExternalSecret Template (per credential)

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: pgvector-credentials
  namespace: ai-agents
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: openbao-cluster-store
    kind: ClusterSecretStore
  target:
    name: pgvector-credentials
    creationPolicy: Owner
  data:
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: ai-agents/pgvector
        property: password
    - secretKey: POSTGRES_USER
      remoteRef:
        key: ai-agents/pgvector
        property: username
    - secretKey: POSTGRES_DB
      remoteRef:
        key: ai-agents/pgvector
        property: database
    - secretKey: DATABASE_URL
      remoteRef:
        key: ai-agents/pgvector
        property: database-url
```

Repeat this pattern for each service. The `ClusterSecretStore` resource (referencing OpenBao) must be created first. See `runbooks/secrets-management.md` section 1.4 for the planned architecture.

---

## Post-Rotation Verification (All Services)

Run this after all rotations are complete:

```bash
echo "=== Verifying all services ==="

# 1. pgvector
echo "--- pgvector ---"
kubectl -n ai-agents exec deploy/pgvector -- psql -U vectoruser -d vectordb -c "SELECT 'pgvector OK';" 2>&1

# 2. Grafana
echo "--- Grafana ---"
kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}'
echo ""

# 3. Ollama
echo "--- Ollama ---"
kubectl -n ai-agents get pods -l app=ollama -o jsonpath='{.items[0].status.phase}'
echo ""

# 4. n8n
echo "--- n8n ---"
kubectl -n ai-agents get pods -l app=n8n -o jsonpath='{.items[0].status.phase}'
echo ""

# 5. SearXNG
echo "--- SearXNG ---"
kubectl -n ai-agents get pods -l app=searxng -o jsonpath='{.items[0].status.phase}'
echo ""

# 6. Check for CrashLoopBackOff (any namespace)
echo "--- Crash check ---"
kubectl get pods -A | grep -E "CrashLoop|Error|ImagePull" || echo "No crashes detected"

echo "=== Done ==="
```

---

## Rollback Procedure

If a rotation causes service failure:

```bash
# Restore from backup (taken in pre-rotation checklist)
kubectl apply -f /tmp/pgvector-secret-backup.yaml
kubectl apply -f /tmp/ollama-auth-backup.yaml
kubectl apply -f /tmp/n8n-secrets-backup.yaml

# Restart affected pods
kubectl -n ai-agents rollout restart deployment pgvector n8n ollama searxng
kubectl -n monitoring rollout restart deployment kube-prometheus-stack-grafana

# For pgvector: also revert the database password
kubectl -n ai-agents exec -it deploy/pgvector -- psql -U vectoruser -d vectordb -c \
  "ALTER USER vectoruser WITH PASSWORD 'RESTORED_PASSWORD';"
```

> **Note**: Database password rollback requires the old password to still be valid in PostgreSQL. If the ALTER USER succeeded but the K8s secret update failed, you must use the NEW password to connect and revert.
