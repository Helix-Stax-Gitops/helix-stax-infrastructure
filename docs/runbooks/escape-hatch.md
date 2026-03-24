# Escape Hatch Procedures

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: ACTIVE
**Platform**: Helix Stax (2-node k3s + CX32 Authentik VM)
**Critical**: These procedures bypass the normal authentication stack. Use only during outages.

---

## Prerequisites

- Hetzner Cloud Console access (cloud.hetzner.com, Wakeem's account)
- Hetzner Robot Console access (robot.hetzner.com, Wakeem's account)
- SSH keys stored locally (not dependent on NetBird or any overlay)
- k3s kubeconfig stored locally at `~/.config/helix-stax/secrets/kubeconfig`
- Backup of Authentik admin credentials (not dependent on Authentik itself)

---

## Scenario 1: Authentik Down -- Cannot Log Into Services

### Symptoms
- SSO login pages return 502/503 or timeout
- "Unable to connect to provider" errors in Devtron/Grafana/n8n
- Authentik container crashed or CX32 VM unreachable

### Impact
- Cannot log into Devtron, Grafana, n8n, Open WebUI via SSO
- Direct API access to k3s still works (certificate auth, not SSO)

### Recovery Steps

**Step 1: Assess Authentik status**
```bash
# SSH to CX32 (direct SSH, not via NetBird)
ssh -i ~/.ssh/cx32-key root@<CX32_IP>

# Check Docker containers
docker ps -a | grep authentik
docker logs authentik-server --tail 50
docker logs authentik-worker --tail 50
docker logs authentik-postgresql --tail 50
```

**Step 2: Restart Authentik**
```bash
cd /opt/authentik
docker compose restart

# Wait 30 seconds, check status
docker compose ps
```

**Step 3: If PostgreSQL is corrupted**
```bash
# Stop everything
docker compose down

# Restore from backup (see backup-strategy.md section 5.2)
docker compose up -d postgresql
docker cp /backup/authentik-db/authentik-YYYYMMDD.dump authentik-postgresql:/tmp/
docker exec -t authentik-postgresql \
  pg_restore -U authentik -d authentik --clean --if-exists /tmp/authentik-YYYYMMDD.dump

docker compose up -d
```

**Step 4: If CX32 VM is unreachable**
```bash
# Use Hetzner Cloud Console
# 1. Go to cloud.hetzner.com > Servers > CX32 VM
# 2. Open VNC Console (works even if networking is down)
# 3. Login as root
# 4. Check: systemctl status docker, ip addr, journalctl -xe
```

**Step 5: Bypass SSO for emergency access to services**

While Authentik is being repaired, access services directly:

| Service | Bypass Method |
|---------|---------------|
| k3s/kubectl | Direct certificate auth via kubeconfig (no SSO dependency) |
| Devtron | Pre-SSO: admin password in `devtron-secret` K8s secret |
| Grafana | Local admin account (admin / stored password) |
| n8n | Direct pod port-forward: `kubectl -n ai-agents port-forward svc/n8n 5678:5678` |
| Open WebUI | Direct pod port-forward: `kubectl -n open-webui port-forward svc/open-webui 8080:8080` |

**Step 6: Create Authentik emergency admin (if admin locked out)**
```bash
ssh root@<CX32_IP>
docker exec -it authentik-server ak create_admin_user \
  --username emergency-admin \
  --email wakeem@helixstax.net \
  --password "$(openssl rand -base64 24)"
# Note: exact CLI may vary by Authentik version. Check:
# docker exec -it authentik-server ak --help
```

### Verification
- [ ] Authentik login page loads
- [ ] SSO login works for at least one service
- [ ] All services re-authenticate successfully

---

## Scenario 2: NetBird Down -- Cannot SSH to Servers

### Symptoms
- `netbird status` shows disconnected
- SSH connections via NetBird IPs timeout
- NetBird management server unreachable

### Impact
- Cannot SSH to servers via NetBird overlay
- Direct SSH via public IPs still works (if firewall allows)

### Recovery Steps

**Step 1: Use direct public IP SSH (primary fallback)**
```bash
# helix-cp-1 (Hetzner Cloud)
ssh -i ~/.ssh/helix-cp-1-key root@138.201.131.157

# helix-worker-1 (Hetzner Robot)
ssh -i ~/.ssh/helix-worker-1-key root@<WORKER_PUBLIC_IP>

# CX32 Authentik VM
ssh -i ~/.ssh/cx32-key root@<CX32_IP>
```

**Step 2: If direct SSH is also blocked (firewall misconfiguration)**
```bash
# Hetzner Cloud Console (VNC) for helix-cp-1
# 1. Go to cloud.hetzner.com > Servers > helix-cp-1
# 2. Click "Console" (VNC access, bypasses network entirely)
# 3. Login as root
# 4. Fix firewall: firewall-cmd --list-all
#    Or: iptables -L -n

# Hetzner Robot Console for helix-worker-1
# 1. Go to robot.hetzner.com > Servers > helix-worker-1
# 2. Click "Remote Console" (KVM/iLO)
# 3. Login as root
# 4. Fix firewall
```

**Step 3: Fix NetBird**
```bash
# On affected server (via direct SSH or console)
systemctl status netbird
journalctl -u netbird --since "1 hour ago"

# Restart NetBird
systemctl restart netbird

# If NetBird management server is the issue (hosted by NetBird SaaS):
# Wait for their service to recover. Nothing to do locally.
# Check status: https://status.netbird.io/
```

**Step 4: If NetBird needs re-enrollment**
```bash
# Remove stale peer
netbird down
netbird up --setup-key VAULT://netbird/setup-key
```

### Verification
- [ ] `netbird status` shows connected
- [ ] SSH via NetBird IP works
- [ ] All peers visible in NetBird dashboard

---

## Scenario 3: Cloudflare Down -- No DNS Resolution

### Symptoms
- `*.helixstax.net` domains do not resolve
- `dig helixstax.net` returns SERVFAIL or timeout
- Cloudflare status page shows incident

### Impact
- All web access via domain names fails
- Direct IP access still works
- Internal k3s DNS (CoreDNS) unaffected

### Recovery Steps

**Step 1: Confirm it is Cloudflare, not local DNS**
```bash
# Test with different DNS resolvers
dig helixstax.net @1.1.1.1    # Cloudflare DNS
dig helixstax.net @8.8.8.8    # Google DNS
dig helixstax.net @9.9.9.9    # Quad9

# If ALL fail, it is a Cloudflare (authoritative NS) outage
# If only some fail, it is a resolver cache issue (wait for TTL)
```

**Step 2: Access services via direct IP**

| Service | Direct IP URL |
|---------|---------------|
| Devtron | http://devtron.138.201.131.157.nip.io |
| Grafana | http://grafana.138.201.131.157.nip.io |
| n8n | http://n8n.138.201.131.157.nip.io |
| Open WebUI | http://chat.138.201.131.157.nip.io |
| Ollama API | http://138.201.131.157/ollama/ |
| Authentik | https://<CX32_IP> (direct, if TLS cert covers IP) |

Note: nip.io is a separate service. If both Cloudflare AND nip.io are down, use `kubectl port-forward`.

**Step 3: kubectl port-forward as last resort**
```bash
# Devtron
kubectl -n devtroncd port-forward svc/devtron-service 8080:80 &

# Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &

# n8n
kubectl -n ai-agents port-forward svc/n8n 5678:5678 &
```

**Step 4: If prolonged outage (>2 hours)**
```bash
# Option A: Move DNS to backup provider (Hetzner DNS)
# Pre-configure Hetzner DNS as secondary (see preparation below)
# Update domain registrar NS records to Hetzner

# Option B: Add /etc/hosts entries on your machine
echo "138.201.131.157 devtron.helixstax.net grafana.helixstax.net n8n.helixstax.net" | sudo tee -a /etc/hosts
```

### Preparation: Hetzner DNS as Backup

Pre-create all DNS records in Hetzner DNS (dns.hetzner.com) mirroring Cloudflare. Do NOT activate (keep Cloudflare as primary NS). In an emergency, change NS at registrar.

### Verification
- [ ] `dig helixstax.net` resolves
- [ ] Web access via domain names works
- [ ] Remove /etc/hosts entries if added

---

## Scenario 4: Google OAuth Upstream Outage

### Symptoms
- Authentik shows "Failed to connect to provider" for Google source
- Google Workspace login page unreachable
- accounts.google.com times out

### Impact
- Cannot authenticate via Google SSO
- Authentik local accounts still work
- Existing sessions remain valid until expiry

### Recovery Steps

**Step 1: Confirm Google outage**
```bash
# Check Google Workspace status
# https://www.google.com/appsstatus/dashboard/

curl -s -o /dev/null -w "%{http_code}" https://accounts.google.com
# If not 200, Google is likely having issues
```

**Step 2: Login with Authentik local admin**
```bash
# Authentik has a local admin account that does not depend on Google
# URL: https://auth.helixstax.net/if/flow/default-authentication-flow/
# Username: akadmin
# Password: VAULT://authentik/bootstrap-password
```

**Step 3: Create temporary local user (if needed)**
```bash
# In Authentik Admin UI (logged in as akadmin):
# Directory > Users > Create
# Set username, email, password
# Assign to appropriate groups
# This user can log in without Google OAuth
```

**Step 4: Inform downstream services**

Existing OIDC tokens issued by Authentik remain valid regardless of Google's status. Authentik is the IdP for downstream apps; Google is only the upstream source. No action needed for already-authenticated sessions.

**Step 5: When Google recovers**
- Google OAuth logins resume automatically
- Delete temporary local accounts
- No configuration changes needed

### Verification
- [ ] Google login works again
- [ ] Authentik Google source shows "Connected"
- [ ] Temporary local accounts removed

---

## Scenario 5: Complete Network Partition (Both Nodes Unreachable)

### Recovery Order

1. Access Hetzner Cloud Console (cloud.hetzner.com) for helix-cp-1
2. Access Hetzner Robot Console (robot.hetzner.com) for helix-worker-1
3. Fix networking on helix-cp-1 first (control plane)
4. Verify k3s server is running
5. Fix networking on helix-worker-1
6. Verify k3s agent reconnects
7. Check all pods: `kubectl get pods -A`

---

## Out-of-Band Admin Access Summary

| Access Method | Depends On | Bypasses |
|---------------|------------|----------|
| Hetzner Cloud Console (VNC) | Hetzner Cloud account | Network, SSH, firewall |
| Hetzner Robot Console (KVM) | Hetzner Robot account | Network, SSH, firewall |
| Direct SSH via public IP | Network + SSH keys | NetBird, Cloudflare DNS |
| kubectl with kubeconfig | Network to k3s API (6443) | Authentik, SSO |
| kubectl port-forward | kubectl access | Ingress, DNS, Cloudflare |
| nip.io URLs | nip.io service + network | Cloudflare DNS |
| Authentik local admin (akadmin) | Authentik running | Google OAuth |
| Service-specific local admin | Service running | Authentik, SSO |

### Emergency Contact

| Role | Name | Contact |
|------|------|---------|
| Platform Admin | Wakeem | Primary: Telegram, Secondary: email |
| Hetzner Support | -- | https://console.hetzner.cloud/support |
| Cloudflare Support | -- | https://dash.cloudflare.com/ (ticket) |
| NetBird Support | -- | https://app.netbird.io/ (support) |

---

## Verification (Periodic Drill)

Run quarterly:
- [ ] Can access helix-cp-1 via Hetzner VNC Console
- [ ] Can access helix-worker-1 via Hetzner Robot Console
- [ ] Direct SSH works without NetBird
- [ ] kubectl works with local kubeconfig
- [ ] Authentik local admin login works
- [ ] nip.io fallback URLs work
- [ ] Port-forward to each critical service works
