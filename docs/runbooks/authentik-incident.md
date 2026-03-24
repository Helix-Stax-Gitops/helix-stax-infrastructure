# Authentik IdP Incident Runbook

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: PROPOSED
**System**: Authentik on CX32 VM (auth.vacancyservices.com)

---

## Quick Reference

| Item | Value |
|------|-------|
| VM IP | (CX32 public IP) |
| SSH | `ssh root@<vm-ip>` |
| Compose dir | `/opt/authentik` |
| Backup dir | `/opt/authentik/backups` |
| Logs | `docker logs authentik-server`, `docker logs authentik-worker` |
| Health check | `curl -sf https://auth.vacancyservices.com/-/health/live/` |
| Admin URL | `https://auth.vacancyservices.com/if/admin/` |

---

## 1. Admin Lockout Recovery

**Scenario**: All admin accounts are locked out (MFA device lost, password forgotten, account disabled).

### 1.1 Create Emergency Admin via CLI

```bash
ssh root@<vm-ip>

# Create a new admin user via Authentik management command
docker exec -it authentik-server \
    ak create_admin_user \
    --username emergency-admin \
    --email emergency@vacancyservices.com \
    --password '<temporary-strong-password>'
```

If `create_admin_user` is unavailable (older version), use the Django shell:

```bash
docker exec -it authentik-server \
    ak shell -c "
from authentik.core.models import User, Group
user = User.objects.create_user(
    username='emergency-admin',
    email='emergency@vacancyservices.com',
    name='Emergency Admin'
)
user.set_password('<temporary-strong-password>')
user.is_staff = True
user.is_superuser = True
user.save()
print(f'Created user: {user.username}')
"
```

### 1.2 Reset Existing Admin Password

```bash
docker exec -it authentik-server \
    ak shell -c "
from authentik.core.models import User
user = User.objects.get(username='akadmin')
user.set_password('<new-password>')
user.save()
print('Password reset complete')
"
```

### 1.3 Disable MFA for a User

```bash
docker exec -it authentik-server \
    ak shell -c "
from authentik.stages.authenticator_totp.models import TOTPDevice
from authentik.stages.authenticator_webauthn.models import WebAuthnDevice
from authentik.core.models import User
user = User.objects.get(username='akadmin')
# Remove all TOTP devices
TOTPDevice.objects.filter(user=user).delete()
# Remove all WebAuthn devices
WebAuthnDevice.objects.filter(user=user).delete()
print(f'All MFA devices removed for {user.username}')
"
```

### 1.4 Post-Recovery Actions

1. Log in with the emergency account
2. Re-enable or reconfigure MFA on primary admin account
3. Delete the emergency admin account
4. Review Authentik audit logs for unauthorized access attempts
5. If MFA device was lost: generate new TOTP seed or register new WebAuthn key

---

## 2. Database Corruption Recovery

**Scenario**: PostgreSQL data is corrupted, Authentik fails to start, or data inconsistency is detected.

### 2.1 Assess the Situation

```bash
ssh root@<vm-ip>

# Check PostgreSQL logs
docker logs authentik-postgres --tail 100

# Try connecting to the database
docker exec authentik-postgres psql -U authentik -d authentik -c "SELECT 1;"

# Check for corruption indicators
docker exec authentik-postgres psql -U authentik -d authentik -c "
    SELECT datname, datcollate, datctype
    FROM pg_database WHERE datname = 'authentik';
"
```

### 2.2 Restore from Backup

```bash
# List available backups
ls -la /opt/authentik/backups/daily/
ls -la /opt/authentik/backups/weekly/

# Restore from the most recent clean backup
/opt/authentik/scripts/restore_authentik_db.sh \
    /opt/authentik/backups/daily/authentik_<timestamp>.sql.gz
```

### 2.3 If No Backup Available

```bash
# Option 1: Attempt PostgreSQL recovery
docker exec authentik-postgres pg_resetwal /var/lib/postgresql/data
# WARNING: This may lose recent transactions

# Option 2: Fresh install (last resort)
docker compose -f /opt/authentik/docker-compose.yml down
docker volume rm authentik_postgres-data
docker compose -f /opt/authentik/docker-compose.yml up -d

# After fresh install:
# 1. Run initial setup at https://auth.vacancyservices.com/if/flow/initial-setup/
# 2. Reconfigure all OIDC providers
# 3. Reconfigure Google OAuth source
# 4. Recreate users and groups
# 5. Update OIDC client secrets in downstream apps
```

### 2.4 PostgreSQL Won't Start

```bash
# Check disk space
df -h

# Check if data directory is intact
docker run --rm -v authentik_postgres-data:/data alpine ls -la /data/

# Check for lock files
docker run --rm -v authentik_postgres-data:/data alpine cat /data/postmaster.pid 2>/dev/null

# If stale lock file exists
docker run --rm -v authentik_postgres-data:/data alpine rm /data/postmaster.pid
docker compose -f /opt/authentik/docker-compose.yml up -d postgresql
```

---

## 3. Certificate Expiry Emergency

**Scenario**: TLS certificates have expired or are about to expire. Users see browser warnings.

### 3.1 Check Current Certificate Status

```bash
ssh root@<vm-ip>

# Check cert expiry from outside
echo | openssl s_client -connect auth.vacancyservices.com:443 -servername auth.vacancyservices.com 2>/dev/null | openssl x509 -noout -dates

# Check Traefik's ACME storage
docker exec authentik-traefik cat /letsencrypt/acme.json | jq '.cloudflare.Certificates[] | {domain: .domain.main, expiry: .certificate}' 2>/dev/null || echo "Cannot parse acme.json"
```

### 3.2 Force Certificate Renewal

```bash
# Option 1: Delete ACME storage and restart Traefik (triggers fresh issuance)
docker compose -f /opt/authentik/docker-compose.yml stop traefik
docker run --rm -v authentik_traefik-certs:/certs alpine rm /certs/acme.json
docker compose -f /opt/authentik/docker-compose.yml up -d traefik

# Wait 1-2 minutes for DNS-01 challenge to complete
sleep 120
echo | openssl s_client -connect auth.vacancyservices.com:443 -servername auth.vacancyservices.com 2>/dev/null | openssl x509 -noout -dates
```

### 3.3 If DNS-01 Challenge Fails

```bash
# Verify Cloudflare API token is valid
docker exec authentik-traefik printenv CF_DNS_API_TOKEN
# (compare with expected value from secrets manager)

# Check Traefik logs for ACME errors
docker logs authentik-traefik --tail 50 | grep -i "acme\|cert\|challenge"

# Common issues:
# - Cloudflare API token expired -> generate new token, update .env, restart
# - DNS propagation delay -> increase delayBeforeCheck in traefik.yml
# - Rate limit hit -> wait 1 hour (Let's Encrypt rate limits: 5 failures/hour)
```

### 3.4 Emergency: Serve Without TLS

**Last resort** if certs cannot be renewed and service must be restored immediately:

```bash
# Edit docker-compose.yml: remove TLS labels from Authentik server
# Add direct port mapping:
#   ports:
#     - "9000:9000"
# Access via http://<vm-ip>:9000 temporarily

# WARNING: This exposes authentication traffic in plaintext.
# Only use for emergency admin access from a trusted network.
# Restore TLS as soon as possible.
```

---

## 4. Google OAuth Upstream Outage

**Scenario**: Google's OAuth endpoints are unreachable. Users cannot log in via Google.

### 4.1 Impact Assessment

- Users who have **existing Authentik sessions** are NOT affected (session cookie is valid)
- Users who need to **log in fresh** via Google are affected
- Users with **local Authentik passwords** can still log in directly
- OIDC tokens already issued to downstream apps remain valid until expiry

### 4.2 Verify Google Outage

```bash
# Check Google OAuth endpoints
curl -sf https://accounts.google.com/.well-known/openid-configuration > /dev/null && echo "Google OIDC: UP" || echo "Google OIDC: DOWN"
curl -sf https://oauth2.googleapis.com/token > /dev/null && echo "Google Token: UP" || echo "Google Token: DOWN"

# Check Google status page
# https://www.google.com/appsstatus/dashboard/
```

### 4.3 Mitigation: Enable Local Password Login

If Google is down and users need access:

```bash
# Ensure the admin account has a local password set
docker exec -it authentik-server \
    ak shell -c "
from authentik.core.models import User
user = User.objects.get(username='akadmin')
print(f'Has usable password: {user.has_usable_password()}')
"

# If no local password, set one
docker exec -it authentik-server \
    ak shell -c "
from authentik.core.models import User
user = User.objects.get(username='akadmin')
user.set_password('<temporary-password>')
user.save()
"
```

**For regular users during Google outage**:

1. Log in as admin (local password)
2. Navigate to **Directory > Users**
3. For critical users, set a temporary password
4. Notify users to use **username/password** login instead of "Log in with Google"
5. After Google recovers, advise users to remove temporary passwords

### 4.4 Extend Session Duration During Outage

To prevent existing users from being logged out during an extended Google outage:

1. Log in as admin
2. Navigate to **System > Tenants > Default**
3. Increase **Session Duration** temporarily (e.g., 7 days)
4. Revert after Google recovers

---

## 5. Service Health Monitoring

### 5.1 Health Check Commands

```bash
# Full service status
docker compose -f /opt/authentik/docker-compose.yml ps

# Authentik server health
curl -sf http://localhost:9000/-/health/live/ && echo "Server: HEALTHY" || echo "Server: UNHEALTHY"
curl -sf http://localhost:9000/-/health/ready/ && echo "Server: READY" || echo "Server: NOT READY"

# PostgreSQL
docker exec authentik-postgres pg_isready -U authentik && echo "Postgres: READY" || echo "Postgres: NOT READY"

# Redis
docker exec authentik-redis redis-cli ping | grep PONG && echo "Redis: READY" || echo "Redis: NOT READY"

# Traefik
curl -sf http://localhost:8080/ping 2>/dev/null && echo "Traefik: READY" || echo "Traefik: NOT READY (dashboard disabled, expected)"
```

### 5.2 Log Locations

| Service | Log Command |
|---------|-------------|
| Authentik server | `docker logs authentik-server --tail 100` |
| Authentik worker | `docker logs authentik-worker --tail 100` |
| PostgreSQL | `docker logs authentik-postgres --tail 100` |
| Redis | `docker logs authentik-redis --tail 100` |
| Traefik | `docker logs authentik-traefik --tail 100` |
| Traefik access log | `/var/log/traefik/access.log` |

### 5.3 Common Failure Patterns

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| 502 Bad Gateway | Authentik server crashed | `docker logs authentik-server` |
| Login page loads but submit hangs | Database connection issue | `docker logs authentik-postgres` |
| "Worker not running" in admin | Worker crashed or OOM | `docker logs authentik-worker`, `docker stats` |
| Slow login | Redis full or PostgreSQL slow queries | `docker exec authentik-redis redis-cli info memory` |
| All services down | VM crashed or Docker daemon stopped | SSH to VM, `systemctl status docker` |

---

## 6. Restart Procedures

### 6.1 Restart Single Service

```bash
docker compose -f /opt/authentik/docker-compose.yml restart server
docker compose -f /opt/authentik/docker-compose.yml restart worker
docker compose -f /opt/authentik/docker-compose.yml restart postgresql
docker compose -f /opt/authentik/docker-compose.yml restart redis
```

### 6.2 Full Stack Restart

```bash
cd /opt/authentik
docker compose down
docker compose up -d
# Wait for health checks
sleep 30
docker compose ps
```

### 6.3 Nuclear Option (Full Rebuild)

```bash
cd /opt/authentik
docker compose down
docker system prune -f
docker compose pull
docker compose up -d
```

**Note**: This does NOT destroy volumes. Data in PostgreSQL, Redis, and Authentik media persists.

---

## 7. Downstream App Impact Matrix

When Authentik is down, the impact on downstream apps depends on their OIDC configuration:

| App | Impact When Authentik Down | Recovery |
|-----|---------------------------|----------|
| Devtron | New logins fail; existing sessions work until token expiry | Automatic when Authentik recovers |
| Grafana | New logins fail; existing sessions work (session cookie based) | Automatic |
| n8n | New logins fail; workflows continue running (no auth needed per-execution) | Automatic |
| ForwardAuth-protected apps | All requests fail (ForwardAuth checks every request) | Automatic |

**Critical**: Apps using Traefik ForwardAuth middleware are fully blocked during Authentik downtime. Consider implementing a ForwardAuth bypass for critical internal services if Authentik availability is insufficient.
