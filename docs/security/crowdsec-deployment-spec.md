---
title: CrowdSec Deployment Specification
author: Wakeem Williams
co_author: Ezra Raines
date: 2026-03-23
version: "1.0"
status: draft
scope: CrowdSec host daemon, K3s DaemonSet, Traefik bouncer, fail2ban migration
target_os: AlmaLinux 9.7
cluster: heart (CP), helix-worker-1 (worker)
compliance_mapping:
  soc2:
    - CC7.2  # System Monitoring
    - CC7.3  # Detection of Anomalies
  iso27001:
    - A.12.4.1  # Event logging
    - A.13.1.1  # Network controls
  nist_csf:
    - DE.CM-1  # Network monitoring
    - DE.AE-2  # Anomaly detection
    - RS.MI-1  # Incident mitigation
---

# CrowdSec Deployment Specification

## 1. Overview

CrowdSec replaces fail2ban as the intrusion prevention system for the Helix Stax infrastructure. It operates at two layers: a host-level daemon on each AlmaLinux node monitoring system logs, and a Kubernetes DaemonSet providing Traefik-integrated web application protection inside the K3s cluster. CrowdSec's consensus-based global threat intelligence network provides proactive blocking of known-malicious IPs.

## 2. Architecture

```
                    +--------------------------+
                    |   CrowdSec Console       |
                    |   (app.crowdsec.net)      |
                    +--------+-----------------+
                             |
                    Consensus Blocklists
                             |
          +------------------+------------------+
          |                                     |
+---------v---------+             +-------------v-----------+
|  Host: heart       |             |  Host: helix-worker-1   |
|  CrowdSec Agent    |             |  CrowdSec Agent         |
|  + nftables bouncer|             |  + nftables bouncer     |
+--------------------+             +-------------------------+
          |
+---------v---------------------------------------------+
|  K3s Cluster                                          |
|  +--------------------------------------------------+|
|  | CrowdSec DaemonSet (crowdsec namespace)          ||
|  |   - Log parsing from Traefik access logs         ||
|  |   - LAPI (Local API) for bouncer coordination    ||
|  +--------------------------------------------------+|
|  | Traefik Bouncer (middleware)                      ||
|  |   - Queries LAPI for IP decisions                ||
|  |   - Blocks/challenges at ingress                 ||
|  +--------------------------------------------------+|
+-------------------------------------------------------+
```

## 3. Host-Level Deployment

### 3.1 Installation

```bash
# Add CrowdSec repository
curl -s https://install.crowdsec.net | sudo bash

# Install CrowdSec agent
sudo dnf install -y crowdsec

# Install nftables bouncer
sudo dnf install -y crowdsec-firewall-bouncer-nftables
```

### 3.2 Collections

Collections bundle parsers and scenarios for specific log sources:

```bash
# SSH brute force detection
sudo cscli collections install crowdsecurity/sshd

# Linux system logs (pam, systemd, su)
sudo cscli collections install crowdsecurity/linux

# HTTP CVE exploit detection
sudo cscli collections install crowdsecurity/http-cve

# Firewalld log parsing
sudo cscli collections install crowdsecurity/firewalld

# Verify installed collections
sudo cscli collections list
```

| Collection | Purpose | Log Source |
|------------|---------|------------|
| `crowdsecurity/sshd` | SSH brute force, credential stuffing | `/var/log/secure` |
| `crowdsecurity/linux` | PAM failures, su/sudo abuse, systemd events | `/var/log/messages`, journal |
| `crowdsecurity/http-cve` | Known HTTP CVE exploit patterns | Web access logs |
| `crowdsecurity/firewalld` | Firewall rule violations | `/var/log/firewalld` |

### 3.3 Bouncer Configuration

The nftables bouncer creates firewall rules to block IPs flagged by the CrowdSec agent:

```yaml
# /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
mode: nftables
update_frequency: 10s
daemonize: true
log_mode: file
log_dir: /var/log/
log_level: info
log_compression: true
log_max_size: 100
log_max_backups: 3
log_max_age: 30
api_url: http://127.0.0.1:8080/
api_key: <generated-on-registration>
disable_ipv6: true
nftables:
  ipv4:
    enabled: true
    set-only: false
    table: crowdsec
    chain: crowdsec-chain
    priority: -10
  ipv6:
    enabled: false
```

Register the bouncer:

```bash
# Generate API key for the bouncer
sudo cscli bouncers add firewall-bouncer-nftables

# Copy the generated key to the bouncer config
sudo vi /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

# Start and enable
sudo systemctl enable --now crowdsec-firewall-bouncer
```

### 3.4 Agent Configuration

```yaml
# /etc/crowdsec/config.yaml (key sections)
common:
  daemonize: true
  log_media: file
  log_level: info
  log_dir: /var/log/
  log_max_size: 100
  log_max_files: 10
  log_max_age: 30

crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  parser_routines: 1
  buckets_routines: 1

db_config:
  type: sqlite
  db_path: /var/lib/crowdsec/data/crowdsec.db
  flush:
    max_items: 5000
    max_age: 7d

api:
  server:
    listen_uri: 127.0.0.1:8080
    profiles_path: /etc/crowdsec/profiles.yaml
```

### 3.5 Acquisition Configuration

```yaml
# /etc/crowdsec/acquis.yaml
---
filenames:
  - /var/log/secure
labels:
  type: syslog
---
filenames:
  - /var/log/messages
labels:
  type: syslog
---
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=sshd.service"
labels:
  type: syslog
---
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=firewalld.service"
labels:
  type: syslog
```

### 3.6 Decision Parameters

```yaml
# /etc/crowdsec/profiles.yaml
name: default_ip_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
  - type: ban
    duration: 4h
notifications:
  - http_rocketchat
on_success: break

---
name: repeat_offender
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip" && Alert.GetEventsCount() > 10
decisions:
  - type: ban
    duration: 24h
notifications:
  - http_rocketchat
on_success: break
```

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Default ban duration | 4 hours | Blocks automated attacks without permanent lockout |
| Repeat offender ban | 24 hours | Escalated for persistent attackers (>10 events) |
| Max retries (SSH) | 5 in 30s | Default scenario threshold in `crowdsecurity/sshd` |
| Consensus blocklists | Enabled | Proactive blocking of globally known-bad IPs |

## 4. Consensus Blocklists

### 4.1 Registration

```bash
# Register with CrowdSec Console (free tier)
sudo cscli console enroll <enrollment-key>

# Verify enrollment
sudo cscli console status
```

### 4.2 Blocklist Subscriptions

After enrollment at https://app.crowdsec.net, subscribe to:

| Blocklist | Description |
|-----------|-------------|
| Community Blocklist | IPs flagged by CrowdSec community consensus |

The free tier includes the community blocklist. Additional premium blocklists are available but not required for initial deployment.

## 5. K3s DaemonSet Deployment

### 5.1 Namespace

```bash
kubectl create namespace crowdsec
```

### 5.2 Helm Installation

```bash
# Add CrowdSec Helm repo
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update

# Install CrowdSec with values
helm install crowdsec crowdsec/crowdsec \
  --namespace crowdsec \
  --values /path/to/crowdsec-values.yaml
```

### 5.3 Helm Values

```yaml
# crowdsec-values.yaml
container_runtime: containerd

lapi:
  env:
    - name: ENROLL_KEY
      valueFrom:
        secretKeyRef:
          name: crowdsec-enrollment
          key: enroll-key
    - name: ENROLL_INSTANCE_NAME
      value: "helix-stax-k3s"

agent:
  acquisition:
    - namespace: traefik
      podName: traefik-*
      program: traefik
    - namespace: kube-system
      podName: "*"
      program: k3s
  env:
    - name: COLLECTIONS
      value: "crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/linux"

  resources:
    limits:
      memory: 256Mi
      cpu: 200m
    requests:
      memory: 128Mi
      cpu: 100m

  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule

  nodeSelector: {}

  # Run on all nodes
  updateStrategy:
    type: RollingUpdate
```

### 5.4 Traefik Bouncer Integration

Deploy the CrowdSec Traefik bouncer as a middleware plugin:

```yaml
# crowdsec-traefik-bouncer.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crowdsec-traefik-bouncer
  namespace: crowdsec
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crowdsec-traefik-bouncer
  template:
    metadata:
      labels:
        app: crowdsec-traefik-bouncer
    spec:
      containers:
        - name: bouncer
          image: fbonalair/traefik-crowdsec-bouncer:latest
          env:
            - name: CROWDSEC_BOUNCER_API_KEY
              valueFrom:
                secretKeyRef:
                  name: crowdsec-bouncer-key
                  key: api-key
            - name: CROWDSEC_AGENT_HOST
              value: "crowdsec-service.crowdsec.svc.cluster.local:8080"
            - name: GIN_MODE
              value: "release"
          ports:
            - containerPort: 8080
          resources:
            limits:
              memory: 128Mi
              cpu: 100m
---
apiVersion: v1
kind: Service
metadata:
  name: crowdsec-traefik-bouncer
  namespace: crowdsec
spec:
  selector:
    app: crowdsec-traefik-bouncer
  ports:
    - port: 8080
      targetPort: 8080
```

Traefik middleware configuration:

```yaml
# crowdsec-middleware.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: crowdsec-bouncer
  namespace: traefik
spec:
  forwardAuth:
    address: http://crowdsec-traefik-bouncer.crowdsec.svc.cluster.local:8080/api/v1/forwardAuth
    trustForwardHeader: true
```

Apply to IngressRoutes:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-ingress
  namespace: default
spec:
  routes:
    - match: Host(`app.helixstax.com`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
      services:
        - name: example-service
          port: 80
```

### 5.5 Register K3s Bouncer

```bash
# From inside the CrowdSec LAPI pod
kubectl exec -n crowdsec deploy/crowdsec-lapi -- \
  cscli bouncers add traefik-bouncer

# Create the secret with the generated key
kubectl create secret generic crowdsec-bouncer-key \
  --namespace crowdsec \
  --from-literal=api-key=<generated-key>
```

## 6. Monitoring

### 6.1 Prometheus Metrics

CrowdSec exposes a Prometheus metrics endpoint:

```yaml
# In crowdsec-values.yaml, add:
lapi:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

Host-level metrics (add to `/etc/crowdsec/config.yaml`):

```yaml
prometheus:
  enabled: true
  level: full
  listen_addr: 127.0.0.1
  listen_port: 6060
```

Expose to Prometheus via node_exporter textfile collector or direct scrape.

### 6.2 Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `cs_active_decisions` | Currently active bans/captchas | Info (dashboard) |
| `cs_alerts` | Total alerts triggered | > 100/hour triggers investigation |
| `cs_parsers_hits_total` | Log lines parsed | Drop to 0 = acquisition broken |
| `cs_bucket_overflow_total` | Scenario triggers | Trend analysis |
| `cs_lapi_decisions_total` | Decisions from LAPI | Correlation with external attacks |

### 6.3 Grafana Dashboard

Import the official CrowdSec Grafana dashboard:
- Dashboard ID: `11585` (CrowdSec Overview)
- Data source: Prometheus

### 6.4 Alerting

```yaml
# Prometheus alerting rule
groups:
  - name: crowdsec
    rules:
      - alert: CrowdSecHighAlertRate
        expr: rate(cs_alerts[5m]) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CrowdSec alert rate on {{ $labels.instance }}"
          description: "More than 1 alert/sec for 10 minutes. Possible active attack."

      - alert: CrowdSecParserDown
        expr: rate(cs_parsers_hits_total[5m]) == 0
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "CrowdSec parser stopped processing on {{ $labels.instance }}"
          description: "No log lines parsed in 15 minutes. Acquisition may be broken."
```

## 7. fail2ban Migration

### 7.1 Pre-Migration Checklist

```bash
# Document current fail2ban configuration
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Export ban list for reference
sudo fail2ban-client status sshd | grep "Banned IP list"

# Record jail configuration
sudo cat /etc/fail2ban/jail.local
```

### 7.2 Migration Steps

```bash
# Step 1: Install CrowdSec (already covered in Section 3.1)
sudo dnf install -y crowdsec crowdsec-firewall-bouncer-nftables

# Step 2: Install collections
sudo cscli collections install crowdsecurity/sshd
sudo cscli collections install crowdsecurity/linux
sudo cscli collections install crowdsecurity/firewalld

# Step 3: Register bouncer
sudo cscli bouncers add firewall-bouncer-nftables

# Step 4: Configure and start CrowdSec
sudo systemctl enable --now crowdsec
sudo systemctl enable --now crowdsec-firewall-bouncer

# Step 5: Verify CrowdSec is working (wait ~5 minutes for initial parsing)
sudo cscli metrics
sudo cscli decisions list

# Step 6: Stop and disable fail2ban
sudo systemctl stop fail2ban
sudo systemctl disable fail2ban

# Step 7: Remove fail2ban (optional, after verification period)
# Wait 7 days to confirm CrowdSec is stable before removing
# sudo dnf remove fail2ban fail2ban-firewalld
```

### 7.3 Post-Migration Verification

```bash
# Verify CrowdSec is running
sudo systemctl status crowdsec
sudo systemctl status crowdsec-firewall-bouncer

# Check parsers are processing logs
sudo cscli metrics | grep -A5 "Acquisition Metrics"

# Verify nftables rules are being created
sudo nft list ruleset | grep crowdsec

# Test SSH protection (from a test IP, not production)
# Attempt multiple failed SSH logins and verify ban
sudo cscli decisions list
# Expected: test IP should appear as banned

# Confirm fail2ban is fully stopped
sudo systemctl status fail2ban
# Expected: inactive (dead)
```

### 7.4 Rollback Plan

If CrowdSec fails during migration:

```bash
# Re-enable fail2ban
sudo systemctl enable --now fail2ban

# Stop CrowdSec
sudo systemctl stop crowdsec crowdsec-firewall-bouncer

# Investigate CrowdSec logs
sudo journalctl -u crowdsec --since "1 hour ago"
```

## 8. Operational Commands

### 8.1 Daily Operations

```bash
# View active decisions (bans)
sudo cscli decisions list

# View metrics summary
sudo cscli metrics

# Check alerts
sudo cscli alerts list

# Manually ban an IP
sudo cscli decisions add --ip 1.2.3.4 --duration 24h --reason "Manual ban"

# Manually unban an IP
sudo cscli decisions delete --ip 1.2.3.4

# Update hub (collections, parsers, scenarios)
sudo cscli hub update
sudo cscli hub upgrade
```

### 8.2 Troubleshooting

```bash
# Check acquisition status
sudo cscli machines list

# Test a log line against parsers
echo 'Failed password for root from 1.2.3.4 port 22 ssh2' | \
  sudo cscli explain --type syslog

# Validate configuration
sudo crowdsec -t

# Debug mode
sudo crowdsec -c /etc/crowdsec/config.yaml -debug
```

## 9. Compliance Mapping

### SOC 2

| Control | TSC Criteria | Implementation |
|---------|-------------|----------------|
| Intrusion detection | CC7.2 | CrowdSec agent monitoring sshd, firewalld, HTTP logs |
| Anomaly detection | CC7.3 | Behavioral scenarios, consensus blocklists, escalating bans |
| Incident response | CC7.4 | Automatic banning, Rocket.Chat notifications |

### NIST CSF

| Function | Category | Implementation |
|----------|----------|----------------|
| Detect | DE.CM-1 | Network monitoring via nftables bouncer + Traefik bouncer |
| Detect | DE.AE-2 | Scenario-based anomaly detection, community threat intelligence |
| Respond | RS.MI-1 | Automated mitigation via firewall bans |

### ISO 27001

| Control | Annex A | Implementation |
|---------|---------|----------------|
| Event logging | A.12.4.1 | All alerts and decisions logged, metrics to Prometheus |
| Network controls | A.13.1.1 | nftables bouncer, Traefik middleware, per-IP decisions |
