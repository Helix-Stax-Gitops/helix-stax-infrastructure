# Authelia Break-Glass Access Procedure

**Purpose**: Restore service access if Authelia goes down and blocks routing through Cloudflare Tunnel.

**When to use**: Services behind Authelia are unreachable, Authelia container is crashed/unresponsive, or OIDC auth loop is broken.

---

## Procedure

### Step 1: SSH into VPS

```bash
ssh -p 2222 root@5.78.145.30
```

If SSH is also blocked (port 2222 firewalled at Hetzner):

```bash
# From local machine — open port 2222 via Hetzner API
curl -X POST "https://api.hetzner.cloud/v1/firewalls/10712312/actions/set_rules" \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rules": [
      {"direction":"in","source_ips":["0.0.0.0/0","::/0"],"protocol":"tcp","port":"80","description":"HTTP"},
      {"direction":"in","source_ips":["0.0.0.0/0","::/0"],"protocol":"tcp","port":"443","description":"HTTPS"},
      {"direction":"in","source_ips":["0.0.0.0/0","::/0"],"protocol":"tcp","port":"587","description":"SMTP-submission"},
      {"direction":"in","source_ips":["0.0.0.0/0","::/0"],"protocol":"tcp","port":"2222","description":"SSH-temp"}
    ]
  }'
```

HCLOUD_TOKEN is stored in `~/.claude/.env.secrets`.

### Step 2: Restore pre-Authelia cloudflared config

```bash
cp /opt/helix-stax/cloudflared/config.yml.bak /opt/helix-stax/cloudflared/config.yml
```

### Step 3: Restart cloudflared

```bash
docker restart cloudflared
```

### Step 4: Verify

Services should be back to direct routing (no Authelia middleware) within ~30 seconds.

```bash
# Verify cloudflared is running
docker ps | grep cloudflared

# Verify tunnel is healthy
docker logs --tail 20 cloudflared
```

---

## After Recovery

1. Investigate why Authelia failed (check `docker logs authelia`)
2. Fix the root cause before re-enabling Authelia
3. Restore the Authelia-enabled config: `cp /opt/helix-stax/cloudflared/config.yml.authelia /opt/helix-stax/cloudflared/config.yml`
4. Restart cloudflared: `docker restart cloudflared`
5. **Close SSH port** if it was opened: remove the port 2222 rule from Hetzner firewall

---

## Key Details

| Item | Value |
|------|-------|
| VPS IP | 5.78.145.30 |
| SSH Port | 2222 |
| Hetzner Firewall ID | 10712312 |
| cloudflared config | /opt/helix-stax/cloudflared/config.yml |
| Backup config | /opt/helix-stax/cloudflared/config.yml.bak |
| Recovery time | ~30 seconds after restart |
