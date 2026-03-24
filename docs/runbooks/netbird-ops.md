# NetBird Operations Runbook

**Author**: Wakeem Williams
**Date**: 2026-03-05
**Status**: PROPOSED

---

## 1. Adding New Admin Devices

### Interactive (OIDC login -- recommended for admin laptops)

```bash
# Install NetBird
# macOS: brew install netbirdio/tap/netbird
# Linux: see scripts/netbird/install-client.sh
# Windows: winget install NetBird.NetBird

# Activate -- opens browser for Authentik login
netbird up

# Verify
netbird status
```

The device is automatically added to the correct group based on Authentik group mapping.

### Headless (setup key -- for scripted enrollment)

```bash
# Get a one-time admin setup key from NetBird Dashboard
# Dashboard -> Setup Keys -> Create (type: one-time, group: admins, expiry: 7 days)

netbird up --setup-key "YOUR_ADMIN_SETUP_KEY"
netbird status
```

### Post-enrollment checklist

- [ ] Device appears in NetBird Dashboard -> Peers
- [ ] Device is in the `admins` group
- [ ] Can ping a server overlay IP: `ping 100.x.y.2`
- [ ] Can SSH to server: `ssh root@100.x.y.2`

---

## 2. Adding New Server Nodes

Use the onboarding script:

```bash
# On the new server (as root):
# Get a reusable server setup key from Dashboard
# Dashboard -> Setup Keys (type: reusable, group: servers, expiry: 30 days)

curl -sL https://raw.githubusercontent.com/KeemWilliams/helix-stax-infra/main/scripts/netbird/onboard-node.sh | \
  bash -s -- --setup-key "YOUR_SERVER_SETUP_KEY" --hostname "new-node-name"

# Or if repo is cloned:
sudo bash scripts/netbird/onboard-node.sh \
  --setup-key "YOUR_SERVER_SETUP_KEY" \
  --hostname "new-node-name"
```

### Post-onboarding checklist

- [ ] Node appears in Dashboard -> Peers
- [ ] Node is in `servers` group
- [ ] Node can reach other servers: `ping <other-server-overlay-ip>`
- [ ] Admin can SSH to node via overlay: `ssh root@<new-node-overlay-ip>`

---

## 3. Revoking Lost or Compromised Devices

### Immediate revocation (takes effect instantly)

1. Go to **NetBird Dashboard -> Peers**
2. Find the compromised device
3. Click **Delete** (removes peer and revokes all tunnel access immediately)

### If the device used OIDC login (admin device):

1. Revoke peer in NetBird Dashboard (step above)
2. **Also** disable the user in Authentik:
   - Authentik Admin -> Directory -> Users -> Find user -> Deactivate
   - This prevents re-enrollment via OIDC

### If the device used a setup key (server):

1. Revoke peer in NetBird Dashboard
2. Revoke the setup key if it's still valid:
   - Dashboard -> Setup Keys -> Delete the compromised key
3. Create a new setup key for legitimate re-enrollments

### Verification after revocation

```bash
# From another peer, confirm the revoked device is gone:
netbird status --detail
# The revoked peer should not appear in the peer list
```

---

## 4. Key Rotation Procedure

### WireGuard keys (automatic)

NetBird automatically rotates WireGuard keys. No manual action required. The management server coordinates key exchange. Verify rotation is working:

```bash
# On any peer:
netbird status --detail
# Check "Last handshake" timestamp -- should be recent
```

### Setup keys (manual, monthly)

1. Go to **NetBird Dashboard -> Setup Keys**
2. Note all active keys and their expiry dates
3. Create new keys with the same configuration (name, type, groups, expiry)
4. Update OpenBao with new key values:
   ```bash
   bao kv put secret/netbird/setup-keys/server key="NEW_SERVER_KEY"
   ```
5. Delete old keys from Dashboard after confirming new keys work
6. Update any automation scripts that reference the old keys

### OIDC client secret rotation

1. In Authentik: Navigate to the NetBird provider and regenerate the client secret
2. Update NetBird Cloud settings with the new client secret
3. Update OpenBao:
   ```bash
   bao kv put secret/netbird/oidc-client-secret value="NEW_SECRET"
   ```
4. Test: `netbird down && netbird up` on an admin device -- should trigger new OIDC login

---

## 5. Troubleshooting

### 5.1 Peer cannot connect

```bash
# Check NetBird status
netbird status
netbird status --detail

# Check if the service is running
systemctl status netbird

# Check logs
journalctl -u netbird -f --no-pager -n 50

# Restart the service
sudo systemctl restart netbird
sudo netbird up
```

**Common causes**:
- Setup key expired -> Create new key in Dashboard
- OIDC token expired -> Run `netbird down && netbird up` to re-authenticate
- Firewall blocking UDP 51820 -> Check `firewall-cmd --list-all`
- DNS resolution failure -> Check `/etc/resolv.conf` and `dig api.netbird.io`

### 5.2 Peers connected but cannot reach each other

```bash
# Check if WireGuard interface exists
ip link show wt0

# Check WireGuard configuration
wg show

# Check routing table for overlay IPs
ip route | grep 100.

# Ping overlay IP directly
ping -c 3 100.x.y.z

# Check if connection is relayed or direct
netbird status --detail
# Look for "Direct" vs "Relayed" in peer connections
```

**If connection is relayed (slow)**:
- Both peers have public IPs -> Should be direct. Check firewalls.
- One peer behind NAT -> Relay is expected. Coturn handles this.
- STUN/TURN server unreachable -> Check `netbird status` for relay errors.

### 5.3 OIDC login fails

```bash
# Check Authentik availability
curl -s https://auth.helixstax.net/application/o/netbird/.well-known/openid-configuration | jq .

# Common issues:
# - Authentik down -> Check Authentik pod status
# - Wrong redirect URI -> Verify in Authentik provider settings
# - Clock skew -> Ensure NTP is synced: timedatectl status
# - Certificate issues -> Check TLS cert validity
```

### 5.4 NetBird service won't start

```bash
# Check for configuration issues
netbird status
cat /etc/netbird/config.json

# Reset configuration
sudo netbird down
sudo rm -f /etc/netbird/config.json
sudo netbird up --setup-key "KEY"  # Re-enroll

# Check system requirements
uname -r  # Kernel version (WireGuard needs 5.6+ or wireguard-dkms)
modprobe wireguard && echo "WireGuard module loaded"
```

### 5.5 High latency between peers

```bash
# Check if traffic is relayed
netbird status --detail
# Direct connections should have <5ms latency in same DC

# If relayed, check STUN/TURN
# NetBird Cloud: Check https://status.netbird.io
# Self-hosted: Check coturn container logs

# Measure raw latency (bypass overlay)
ping -c 10 138.201.131.157  # Direct public IP

# Compare overlay latency
ping -c 10 100.x.y.2  # Overlay IP
```

---

## 6. Emergency Access (NetBird Down)

If NetBird management server is unreachable, existing WireGuard tunnels persist for a while. But if tunnels drop:

### Option 1: Direct SSH (if firewall allows)

```bash
# SSH via public IP (requires port 22 open for your IP)
ssh root@138.201.131.157          # helix-cp-1
ssh root@<worker-public-ip>       # helix-worker-1
```

**Prerequisite**: Firewall must have SSH allowed for at least one static admin IP. This is configured during Phase 1 as a fallback:

```bash
# On helix-cp-1 (if firewalld is active):
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="{{ADMIN_STATIC_IP}}/32" port port="22" protocol="tcp" accept'
firewall-cmd --reload
```

### Option 2: Hetzner Cloud Console

1. Log in to https://console.hetzner.cloud
2. Navigate to the project -> Servers -> helix-cp-1
3. Click **Console** (browser-based VNC)
4. Log in with root credentials

### Option 3: Hetzner Robot KVM (for dedicated server)

1. Log in to https://robot.hetzner.com
2. Navigate to Servers -> helix-worker-1
3. Click **KVM Console** or **Reset -> Rescue System**

### After recovering access

1. Check NetBird service: `systemctl status netbird`
2. Check NetBird Cloud status: https://status.netbird.io
3. Restart NetBird: `systemctl restart netbird`
4. If management server was down temporarily, tunnels re-establish automatically
5. If switching to self-hosted: deploy `manifests/netbird/docker-compose.yml`

---

## 7. Monitoring

### Health checks

```bash
# Quick status from any peer
netbird status

# Detailed peer list
netbird status --detail

# Service health
systemctl is-active netbird
```

### Prometheus metrics (future)

NetBird exposes metrics at `http://localhost:33080/metrics` when configured. Integration with the existing kube-prometheus-stack is a future task.

### Alerts to set up (future)

| Alert | Condition | Severity |
|-------|-----------|----------|
| NetBird peer disconnected | Peer not seen for >5 min | Warning |
| NetBird service down | systemctl status != active | Critical |
| All peers relayed | No direct connections | Warning |
| Setup key expiring | Key expires in <7 days | Info |

---

## 8. Common Operations Quick Reference

| Task | Command |
|------|---------|
| Check status | `netbird status` |
| Detailed peer info | `netbird status --detail` |
| Connect/reconnect | `netbird up` |
| Disconnect | `netbird down` |
| View logs | `journalctl -u netbird -f` |
| Restart service | `sudo systemctl restart netbird` |
| Show WireGuard config | `wg show` |
| Show overlay routes | `ip route \| grep 100.` |
| Version | `netbird version` |
| Reset config | `netbird down && rm /etc/netbird/config.json && netbird up --setup-key KEY` |
