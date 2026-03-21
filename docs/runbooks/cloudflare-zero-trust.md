# Cloudflare Zero Trust — Operations Runbook

**Status**: Active
**VPS**: 5.78.145.30 (Hetzner, Debian 12)
**Tunnel**: helix-vps (3f35aa77-f385-43fa-aa23-5aa29ec88b37)
**Team Domain**: helix-hub-tunnel.cloudflareaccess.com
**Last Updated**: 2026-03-18

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [Tunnel Management](#2-tunnel-management)
3. [Adding a Service](#3-adding-a-service)
4. [Removing a Service](#4-removing-a-service)
5. [Access Policy Management](#5-access-policy-management)
6. [DNS Management](#6-dns-management)
7. [Caddy Management](#7-caddy-management)
8. [Firewall State](#8-firewall-state)
9. [Rollback Procedure](#9-rollback-procedure)
10. [Troubleshooting](#10-troubleshooting)
11. [Security Notes](#11-security-notes)
12. [Future Work](#12-future-work)

---

## 1. Architecture

### Traffic Flow

```
                        Internet
                           |
              +------------+------------+
              |                         |
      Cloudflare Edge              Direct A Record
      (Zero Trust)                 (Public Services)
              |                         |
     +--------+--------+          +-----+-----+
     | CF Access Policy |          |           |
     | (GitHub IdP)     |          |           |
     +--------+--------+     track.helixstax.net
              |               rp.helixstax.net
     +--------+--------+          |
     | cloudflared      |    +----+----+
     | (helix-vps       |    |  Caddy  |
     |  tunnel)         |    | :80/443 |
     +--------+--------+    +----+----+
              |                   |
     +--------+--------+    +----+----+
     |  Local Services  |    | Postal  |
     |  (see table)     |    | (click  |
     |                  |    |  track  |
     +------------------+    |  + rp)  |
                             +---------+

    VPS 5.78.145.30
```

### Tunneled Services

| Service | Hostname | Local Port | Access Session |
|---|---|---|---|
| Vaultwarden | vault.helixstax.net | 8088 | 1h |
| Harbor | harbor.helixstax.net | 8080 | 24h |
| MinIO Console | minio.helixstax.net | 9003 | 24h |
| MinIO API | s3.helixstax.net | 9002 | 24h |
| OpenBao | bao.helixstax.net | 8200 | 1h |
| Postal UI | postal.helixstax.net | 5000 | 24h |
| SSH Browser | ssh-vps.helixstax.net | 2222 | 1h |
| Auth (reserved) | auth.helixstax.net | N/A (503) | N/A |

### Public Services (NOT Tunneled)

These bypass the tunnel and hit the VPS directly via A records:

| Service | Hostname | Reverse Proxy | Backend |
|---|---|---|---|
| Click tracking | track.helixstax.net | Caddy | Postal |
| Return path | rp.helixstax.net | Caddy | Postal |
| SMTP relay | port 587 | — | Postal |

### Two-Tunnel Strategy (Future)

The current architecture uses a single tunnel on the VPS. The planned end state is:

| Tunnel | Host | Services |
|---|---|---|
| helix-vps | 5.78.145.30 | Vaultwarden, Harbor, MinIO, OpenBao, Postal, SSH |
| helix-k3s (future) | K3s cluster | Application workloads, Grafana, n8n, Devtron |

---

## 2. Tunnel Management

### Key Paths

| Item | Path |
|---|---|
| Config | `/etc/cloudflared/config.yml` |
| Credentials | `/root/.cloudflared/3f35aa77-f385-43fa-aa23-5aa29ec88b37.json` |
| Service | `cloudflared.service` (systemd) |
| Binary | `/usr/bin/cloudflared` |

### Start / Stop / Restart

```bash
# Check status
systemctl status cloudflared

# Restart (after config changes)
systemctl restart cloudflared

# Stop (services go offline — tunnel only, Caddy unaffected)
systemctl stop cloudflared

# Start
systemctl start cloudflared

# View logs
journalctl -u cloudflared -f --no-pager -n 100
```

### Health Check

```bash
# Tunnel status via Cloudflare API (requires token from OpenBao)
cloudflared tunnel info helix-vps

# Quick connectivity test from local machine
curl -I https://vault.helixstax.net
# Expected: 302 redirect to cloudflareaccess.com (if not authenticated)

# Check tunnel metrics
curl -s http://localhost:2000/metrics | head -20
```

### Config File Structure

The ingress rules in `/etc/cloudflared/config.yml` follow this pattern:

```yaml
tunnel: 3f35aa77-f385-43fa-aa23-5aa29ec88b37
credentials-file: /root/.cloudflared/3f35aa77-f385-43fa-aa23-5aa29ec88b37.json

ingress:
  - hostname: vault.helixstax.net
    service: http://localhost:8088
  - hostname: harbor.helixstax.net
    service: http://localhost:8080
  # ... more services ...
  - hostname: auth.helixstax.net
    service: http_status:503
  - service: http_status:404    # catch-all (required)
```

The catch-all rule at the bottom is **required** by cloudflared. It handles any request that does not match a hostname.

---

## 3. Adding a Service

When adding a new service to the tunnel, three things need to happen:

### Step 1: Add Ingress Rule

Edit `/etc/cloudflared/config.yml` on the VPS. Add a new entry **above** the catch-all rule:

```yaml
  - hostname: newservice.helixstax.net
    service: http://localhost:<PORT>
```

Restart the tunnel:

```bash
systemctl restart cloudflared
```

### Step 2: Create DNS CNAME

In Cloudflare DNS for `helixstax.net`, add:

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | newservice | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Proxied (orange cloud) |

### Step 3: Create Access Application

In the Cloudflare Zero Trust dashboard:

1. Go to **Access > Applications > Add an application**
2. Type: **Self-hosted**
3. Application domain: `newservice.helixstax.net`
4. Session duration: Choose based on sensitivity (1h for secrets, 24h for dev tools)
5. Add policy: **Allow** if in **Helix Admin** group
6. Save

### Verify

```bash
# From any machine — should get 302 to CF Access login
curl -I https://newservice.helixstax.net

# After authenticating in browser, should get 200
curl -I https://newservice.helixstax.net -H "Cookie: <CF_Authorization cookie>"
```

---

## 4. Removing a Service

### Step 1: Remove Access Application

In Cloudflare Zero Trust dashboard: **Access > Applications** > find the app > **Delete**.

### Step 2: Remove DNS Record

In Cloudflare DNS for `helixstax.net`: delete the CNAME record for the hostname.

### Step 3: Remove Ingress Rule

Edit `/etc/cloudflared/config.yml`, remove the hostname entry. Restart:

```bash
systemctl restart cloudflared
```

Order matters: remove Access app and DNS first so there is no window where the service is exposed without a policy.

---

## 5. Access Policy Management

### Identity Provider

GitHub OAuth is the sole IdP. Team domain: `helix-hub-tunnel.cloudflareaccess.com`.

### Access Group: Helix Admin

The "Helix Admin" group is the primary policy gate. Current members:

| Member | Criteria |
|---|---|
| KeemWilliams | GitHub username |

### Adding a User

1. Go to **Access > Access Groups > Helix Admin**
2. Add an **Include** rule (e.g., GitHub username, email, etc.)
3. Save — applies to all applications using this group immediately

### Changing Session Duration

Per-application setting:

1. **Access > Applications** > select the app
2. Edit **Session Duration**
3. Save

Guidelines:
- **1 hour**: Secrets managers (Vaultwarden, OpenBao), SSH
- **24 hours**: Dev tools (Harbor, MinIO, Postal UI)

### Service Tokens

Service tokens allow machine-to-machine access without browser auth. Current tokens:

| Token Name | Purpose |
|---|---|
| harbor-k3s-pull | K3s pulling container images from Harbor |
| minio-k3s-access | K3s accessing MinIO object storage |

Token values are stored in OpenBao at `secret/cloudflare-service-tokens`.

#### Creating a New Service Token

1. **Access > Service Auth > Service Tokens > Create**
2. Name it descriptively (e.g., `service-purpose`)
3. Copy the Client ID and Client Secret — **shown only once**
4. Store in OpenBao:
   ```bash
   bao kv put secret/cloudflare-service-tokens/<token-name> \
     client_id="<CLIENT_ID>" \
     client_secret="<CLIENT_SECRET>"
   ```
5. Create an Access policy for the target application that allows the service token

#### Using a Service Token

```bash
# Retrieve token from OpenBao
CLIENT_ID=$(bao kv get -field=client_id secret/cloudflare-service-tokens/harbor-k3s-pull)
CLIENT_SECRET=$(bao kv get -field=client_secret secret/cloudflare-service-tokens/harbor-k3s-pull)

# Authenticate with service token headers
curl -H "CF-Access-Client-Id: ${CLIENT_ID}" \
     -H "CF-Access-Client-Secret: ${CLIENT_SECRET}" \
     https://harbor.helixstax.net/api/v2.0/health
```

---

## 6. DNS Management

### Record Types

All DNS is in Cloudflare, zone: `helixstax.net`.

| Pattern | Record Type | Target | Use |
|---|---|---|---|
| Tunneled services | CNAME | `3f35aa77-...cfargotunnel.com` | All Zero Trust-protected services |
| Public services | A | `5.78.145.30` | track, rp (Caddy-fronted, no tunnel) |
| Email records | Various | Various | SPF, DKIM, MX (see postal runbook) |

### Current DNS Records (Zero Trust Related)

| Name | Type | Target | Proxied |
|---|---|---|---|
| vault | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| harbor | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| minio | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| s3 | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| bao | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| postal | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| ssh-vps | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| auth | CNAME | 3f35aa77-f385-43fa-aa23-5aa29ec88b37.cfargotunnel.com | Yes |
| track | A | 5.78.145.30 | No |
| rp | A | 5.78.145.30 | No |

### Adding/Changing DNS

For tunneled services: always use CNAME to the tunnel ID with Cloudflare proxy enabled (orange cloud).

For public services: use A record pointing to VPS IP, proxy off (grey cloud) so TLS terminates at Caddy.

---

## 7. Caddy Management

Caddy handles TLS and reverse proxying for the two public-facing hostnames that cannot go through the tunnel (email click tracking and return path need direct HTTP access from mail clients).

### Config Location

```
/opt/helix-stax/caddy/Caddyfile
```

### Expected Caddyfile

```
track.helixstax.net {
    reverse_proxy localhost:5000
}

rp.helixstax.net {
    reverse_proxy localhost:5000
}
```

Both proxy to Postal's web service on port 5000.

### Commands

```bash
# Check status
systemctl status caddy

# Reload after config change (zero-downtime)
systemctl reload caddy

# Restart
systemctl restart caddy

# Validate config
caddy validate --config /opt/helix-stax/caddy/Caddyfile

# Check certificate status
caddy certs
```

### TLS

Caddy handles ACME certificate provisioning automatically via Let's Encrypt. Ports 80 and 443 must remain open on the VPS for these two hostnames. The Hetzner firewall allows this traffic.

If certs fail to renew, check:
1. DNS A records still point to `5.78.145.30`
2. Ports 80/443 open in Hetzner firewall
3. `journalctl -u caddy` for ACME errors

---

## 8. Firewall State

### Hetzner Firewall Rules

After the Zero Trust migration, the firewall is tightened:

| Port | Protocol | Status | Reason |
|---|---|---|---|
| 22 | TCP | Open | SSH (direct access, key-only) |
| 25 | TCP | Open | SMTP inbound (Postal bounce handling) |
| 80 | TCP | Open | Caddy ACME challenges + HTTP→HTTPS redirect |
| 443 | TCP | Open | Caddy TLS for track/rp hostnames |
| 587 | TCP | Open | SMTP relay (Postal outbound submission) |
| 2222 | TCP | **Closed** | SSH via browser now through tunnel |
| 5000 | TCP | **Closed** | Postal UI now through tunnel |
| 8080 | TCP | **Closed** | Harbor now through tunnel |
| 8088 | TCP | **Closed** | Vaultwarden now through tunnel |
| 8200 | TCP | **Closed** | OpenBao now through tunnel |
| 9002-9003 | TCP | **Closed** | MinIO now through tunnel |

### Why Ports Stay Open

- **22**: Direct SSH is the last-resort access path if the tunnel goes down.
- **25**: Postal needs direct SMTP for bounce/inbound email processing.
- **80/443**: Caddy needs these for track/rp hostnames and ACME cert renewal.
- **587**: SMTP submission port for relay clients (e.g., Mautic, apps sending through Postal).

### Modifying Firewall

Use Hetzner Cloud Console or `hcloud` CLI:

```bash
# List firewall rules
hcloud firewall describe <firewall-name>

# Add a rule (example: open port 8443)
hcloud firewall add-rule <firewall-name> --direction in --protocol tcp --port 8443 --source-ips 0.0.0.0/0 --source-ips ::/0

# Remove a rule
hcloud firewall remove-rule <firewall-name> --direction in --protocol tcp --port 8443 --source-ips 0.0.0.0/0 --source-ips ::/0
```

---

## 9. Rollback Procedure

If the tunnel is broken and services need to be restored immediately. **Estimated time: <5 minutes + DNS TTL.**

### Step 1: Switch DNS Records

In Cloudflare DNS for `helixstax.net`, change each tunneled service from CNAME to A record:

| Name | Change From | Change To |
|---|---|---|
| vault | CNAME → tunnel | A → 5.78.145.30 |
| harbor | CNAME → tunnel | A → 5.78.145.30 |
| minio | CNAME → tunnel | A → 5.78.145.30 |
| s3 | CNAME → tunnel | A → 5.78.145.30 |
| bao | CNAME → tunnel | A → 5.78.145.30 |
| postal | CNAME → tunnel | A → 5.78.145.30 |
| ssh-vps | CNAME → tunnel | A → 5.78.145.30 |

Set Cloudflare proxy to **off** (grey cloud) so traffic goes direct.

### Step 2: Open Firewall Ports

```bash
# Open ports that were closed during migration
hcloud firewall add-rule <firewall-name> --direction in --protocol tcp --port 80 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule <firewall-name> --direction in --protocol tcp --port 443 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall add-rule <firewall-name> --direction in --protocol tcp --port 2222 --source-ips 0.0.0.0/0 --source-ips ::/0
```

Note: 80/443 may already be open for Caddy. Verify with `hcloud firewall describe`.

### Step 3: Restart Traefik

Traefik config is preserved at `/opt/helix-stax/traefik/`.

```bash
cd /opt/helix-stax/traefik/
docker compose up -d
```

Traefik will handle TLS termination and routing for all services, replacing both the tunnel and Caddy.

### Step 4: Stop cloudflared

```bash
systemctl stop cloudflared
# Leave installed — do not uninstall
```

### Step 5: Stop Caddy (if Traefik takes over track/rp)

```bash
systemctl stop caddy
```

Only stop Caddy if Traefik is configured to handle track and rp hostnames. If Traefik config does not include them, leave Caddy running.

### Verify Rollback

```bash
# Test each service (should get 200 or redirect, no CF Access gate)
curl -I https://vault.helixstax.net
curl -I https://harbor.helixstax.net
curl -I https://postal.helixstax.net
```

---

## 10. Troubleshooting

### Tunnel Won't Start

```bash
# Check logs
journalctl -u cloudflared -n 50 --no-pager

# Validate config
cloudflared tunnel ingress validate --config /etc/cloudflared/config.yml

# Common issues:
# - Missing catch-all rule at end of ingress
# - YAML indentation errors
# - Credentials file missing or wrong path
```

### Tunnel Running But Service Unreachable

```bash
# Is the local service actually running?
curl -I http://localhost:<PORT>

# Is cloudflared routing to it?
journalctl -u cloudflared | grep "hostname"

# Is DNS pointing to the tunnel?
dig +short vault.helixstax.net
# Should return Cloudflare IPs, not 5.78.145.30
```

### Access Login Loop (302 Redirect Loop)

1. Clear browser cookies for `*.helixstax.net` and `cloudflareaccess.com`
2. Check that the Access application domain matches the ingress hostname exactly
3. Verify the GitHub IdP is still configured in **Settings > Authentication**
4. Check Access audit logs: **Logs > Access** in Zero Trust dashboard

### "No Policy Match" Error After Login

The user authenticated via GitHub but does not match any Access policy.

1. Confirm the GitHub username is in the **Helix Admin** access group
2. Check the Access application policy includes the **Helix Admin** group
3. If using a new GitHub account, update the group membership

### Service Token Authentication Fails

```bash
# Verify token headers are correct
curl -v -H "CF-Access-Client-Id: <ID>" \
       -H "CF-Access-Client-Secret: <SECRET>" \
       https://harbor.helixstax.net/api/v2.0/health

# Check if token is expired — service tokens have configurable expiry
# Regenerate in Access > Service Auth > Service Tokens if needed
```

### Caddy Certificate Renewal Fails

```bash
# Check Caddy logs
journalctl -u caddy -n 50 --no-pager

# Verify DNS
dig +short track.helixstax.net
# Must return 5.78.145.30 (A record, not CNAME to tunnel)

# Verify port 80 is open (ACME HTTP-01 challenge)
# From another machine:
nc -zv 5.78.145.30 80

# Force renewal
caddy reload --config /opt/helix-stax/caddy/Caddyfile
```

### cloudflared Update

```bash
# Check current version
cloudflared --version

# Update (Debian)
apt update && apt install --only-upgrade cloudflared

# Restart after update
systemctl restart cloudflared
```

---

## 11. Security Notes

### Session Durations

Session durations are set per-application based on sensitivity:

| Duration | Use For | Rationale |
|---|---|---|
| 1 hour | Vaultwarden, OpenBao, SSH | Secrets and shell access — short sessions limit exposure |
| 24 hours | Harbor, MinIO, Postal UI | Dev tools — frequent access, lower sensitivity |

Review session durations quarterly. Tighten if a service gains higher-sensitivity data.

### Audit Logs

Cloudflare Access logs all authentication events. View at:

- **Zero Trust Dashboard > Logs > Access**
- Includes: who authenticated, when, which application, success/failure

### Stored IDs and Secrets

All Cloudflare Zero Trust IDs (tunnel ID, application IDs, policy IDs) are stored in OpenBao:

```bash
bao kv get secret/cloudflare-zero-trust
```

Service token credentials:

```bash
bao kv get secret/cloudflare-service-tokens/<token-name>
```

### TODO: Scoped API Token

The current Cloudflare configuration may use the Global API Key. This should be replaced with a scoped API token that has only the permissions needed:

- **Zone:DNS:Edit** (for the helixstax.net zone)
- **Account:Cloudflare Tunnel:Edit**
- **Account:Access:Edit**

Create a scoped token in **My Profile > API Tokens > Create Token** and store in OpenBao.

---

## 12. Future Work

### K3s Tunnel (helix-k3s)

A second tunnel will run on the K3s cluster for application workloads:

- Tunnel name: `helix-k3s`
- Host: K3s control plane (138.201.131.157) or dedicated ingress node
- Services: Grafana, n8n, Devtron, application endpoints
- cloudflared deployed as a Kubernetes Deployment (not systemd)

This keeps VPS infrastructure services and K3s application services on separate tunnels with independent lifecycle management.

### Authelia on auth.helixstax.net

The `auth.helixstax.net` hostname is reserved (currently returns 503). Planned use:

- Authelia as a self-hosted authentication portal
- Provides 2FA, SSO, and fine-grained access control beyond what CF Access offers
- Can serve as an additional auth layer for internal services

### Firewall Hardening

Once the K3s tunnel is established:

- Close port 22 on Hetzner firewall (SSH via tunnel only)
- Restrict port 587 to known source IPs if possible
- Consider Cloudflare WAF rules for additional protection on public endpoints
