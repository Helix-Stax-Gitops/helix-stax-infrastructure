---
title: Network Security Specification
author: Wakeem Williams
co_author: Ezra Raines
date: 2026-03-23
version: "1.0"
status: draft
scope: Firewalld zones, K3s inter-node rules, NetworkPolicy, Flannel WireGuard, Cloudflare origin pull
target_os: AlmaLinux 9.7
cluster: heart (CP, 178.156.233.12), helix-worker-1 (worker, 138.201.131.157)
compliance_mapping:
  soc2:
    - CC6.6  # Logical Access Security - Network Controls
    - CC6.1  # Logical and Physical Access Controls
  iso27001:
    - A.13.1.1  # Network controls
    - A.13.1.3  # Segregation in networks
  nist_csf:
    - PR.AC-5  # Network integrity is protected
    - PR.DS-2  # Data in transit is protected
---

# Network Security Specification

## 1. Overview

This document specifies the network security controls for the Helix Stax infrastructure, covering host-level firewalld configuration, Kubernetes NetworkPolicy, Flannel WireGuard encryption for east-west traffic, and Cloudflare origin pull authentication for north-south traffic. The goal is defense-in-depth: traffic is filtered at every layer from the edge (Cloudflare) through the host firewall (firewalld) into the cluster (NetworkPolicy) with all inter-node communication encrypted (WireGuard).

## 2. Firewalld Zone Configuration

### 2.1 Zone Architecture

| Zone | Interfaces | Purpose |
|------|-----------|---------|
| `public` (default) | `eth0` / `ens3` | External-facing. Minimal open ports. |
| `trusted` | `cni0`, `flannel.1` | K3s pod and overlay networking. All traffic permitted. |
| `drop` | (default for unknown) | Silently drops all unsolicited traffic. |

### 2.2 Assign K3s Interfaces to Trusted Zone

```bash
# Assign CNI bridge interface to trusted zone
sudo firewall-cmd --permanent --zone=trusted --add-interface=cni0

# Assign Flannel VXLAN/WireGuard interface to trusted zone
sudo firewall-cmd --permanent --zone=trusted --add-interface=flannel.1

# If using WireGuard, also trust the flannel-wg interface
sudo firewall-cmd --permanent --zone=trusted --add-interface=flannel-wg

# Reload
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --get-active-zones
```

Expected output:

```
public
  interfaces: eth0
trusted
  interfaces: cni0 flannel.1
```

### 2.3 Public Zone Configuration

Only expose the minimum required ports on the public interface:

```bash
# Default services (SSH only)
sudo firewall-cmd --permanent --zone=public --add-service=ssh

# HTTP/HTTPS for Cloudflare (if not tunneled)
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=443/tcp

# Remove any unnecessary services
sudo firewall-cmd --permanent --zone=public --remove-service=cockpit 2>/dev/null
sudo firewall-cmd --permanent --zone=public --remove-service=dhcpv6-client 2>/dev/null

# Reload
sudo firewall-cmd --reload

# List public zone rules
sudo firewall-cmd --zone=public --list-all
```

## 3. Rich Rules for Inter-Node Communication

### 3.1 K3s Required Ports

The following ports must be open between cluster nodes (heart <-> helix-worker-1) but NOT to the public internet:

| Port | Protocol | Service | Direction |
|------|----------|---------|-----------|
| 6443 | TCP | K3s API Server | Worker -> CP |
| 10250 | TCP | Kubelet API | CP <-> Worker |
| 8472 | UDP | Flannel VXLAN | CP <-> Worker |
| 51820 | UDP | Flannel WireGuard | CP <-> Worker |
| 2379-2380 | TCP | etcd (embedded) | CP only (loopback) |

### 3.2 Rich Rules on Control Plane (heart - 178.156.233.12)

```bash
# Allow K3s API from worker node only
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="138.201.131.157"
  port port="6443" protocol="tcp"
  accept'

# Allow Kubelet API from worker
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="138.201.131.157"
  port port="10250" protocol="tcp"
  accept'

# Allow Flannel VXLAN from worker
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="138.201.131.157"
  port port="8472" protocol="udp"
  accept'

# Allow Flannel WireGuard from worker
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="138.201.131.157"
  port port="51820" protocol="udp"
  accept'

# etcd: loopback only (default — no rule needed)
# Ports 2379-2380 should NOT be exposed on any interface

sudo firewall-cmd --reload
```

### 3.3 Rich Rules on Worker (helix-worker-1 - 138.201.131.157)

```bash
# Allow Kubelet API from control plane
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="178.156.233.12"
  port port="10250" protocol="tcp"
  accept'

# Allow Flannel VXLAN from control plane
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="178.156.233.12"
  port port="8472" protocol="udp"
  accept'

# Allow Flannel WireGuard from control plane
sudo firewall-cmd --permanent --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="178.156.233.12"
  port port="51820" protocol="udp"
  accept'

sudo firewall-cmd --reload
```

### 3.4 Verification

```bash
# List all rich rules
sudo firewall-cmd --zone=public --list-rich-rules

# Verify connectivity between nodes
# From heart:
nc -zv 138.201.131.157 10250  # Kubelet on worker

# From helix-worker-1:
nc -zv 178.156.233.12 6443    # API server on CP
nc -zv 178.156.233.12 10250   # Kubelet on CP

# Verify etcd is NOT externally accessible
nc -zv 178.156.233.12 2379    # Should FAIL from worker
nc -zv 178.156.233.12 2380    # Should FAIL from worker
```

## 4. Default-Deny NetworkPolicy

### 4.1 Template

Apply this NetworkPolicy to every application namespace to implement default-deny ingress and egress:

```yaml
# default-deny-networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <NAMESPACE>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 4.2 Automation Script

```bash
#!/bin/bash
# apply-default-deny.sh
# Apply default-deny NetworkPolicy to all non-system namespaces

EXCLUDED_NAMESPACES="kube-system kube-public kube-node-lease default"

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  if echo "$EXCLUDED_NAMESPACES" | grep -qw "$ns"; then
    echo "SKIP: $ns (system namespace)"
    continue
  fi

  echo "APPLY: default-deny-all to $ns"
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $ns
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
done
```

### 4.3 Allowing Required Traffic

After applying default-deny, explicitly allow required traffic per namespace:

```yaml
# Example: Allow ingress from Traefik to an application namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-traefik-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
      ports:
        - port: 8080
          protocol: TCP
```

```yaml
# Example: Allow DNS egress (required for all pods)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

### 4.4 Verification

```bash
# List NetworkPolicies across all namespaces
kubectl get networkpolicy -A

# Describe a specific policy
kubectl describe networkpolicy default-deny-all -n production

# Test connectivity (from a debug pod)
kubectl run nettest --image=busybox --restart=Never -n production -- sleep 3600
kubectl exec -n production nettest -- wget -qO- --timeout=3 http://some-service.other-ns.svc.cluster.local
# Expected: connection refused or timeout (blocked by default-deny)
kubectl delete pod nettest -n production
```

## 5. Flannel WireGuard Configuration

### 5.1 Enable WireGuard Backend

WireGuard encrypts all pod-to-pod traffic between nodes (east-west encryption). Configure in K3s:

```yaml
# /etc/rancher/k3s/config.yaml (control plane)
flannel-backend: wireguard-native
```

The `wireguard-native` backend uses the kernel-native WireGuard implementation (available in Linux 5.6+ / AlmaLinux 9 kernel).

### 5.2 Prerequisites

```bash
# Verify WireGuard kernel module is available
sudo modprobe wireguard
lsmod | grep wireguard

# Install wireguard-tools for debugging
sudo dnf install -y wireguard-tools

# Verify kernel version supports native WireGuard
uname -r
# Expected: 5.14+ (AlmaLinux 9 ships with 5.14)
```

### 5.3 Apply Configuration

```bash
# On control plane (heart):
# Add flannel-backend to config and restart
sudo systemctl restart k3s

# On worker (helix-worker-1):
# Worker inherits flannel config from server — just restart agent
sudo systemctl restart k3s-agent
```

### 5.4 Verification Commands

```bash
# Verify WireGuard interface exists
ip link show flannel-wg
# Expected: flannel-wg interface listed

# Verify WireGuard peers
sudo wg show
# Expected: Shows peer with endpoint matching the other node's IP

# Verify encryption is active
sudo wg show flannel-wg
# Expected output includes:
#   peer: <public-key>
#   endpoint: 138.201.131.157:51820 (or 178.156.233.12:51820)
#   latest handshake: <recent timestamp>
#   transfer: <bytes received>, <bytes sent>

# Test encrypted pod-to-pod communication
# Deploy test pods on different nodes:
kubectl run test-heart --image=busybox --overrides='{"spec":{"nodeName":"heart"}}' -- sleep 3600
kubectl run test-worker --image=busybox --overrides='{"spec":{"nodeName":"helix-worker-1"}}' -- sleep 3600

# Get pod IPs
HEART_POD_IP=$(kubectl get pod test-heart -o jsonpath='{.status.podIP}')
WORKER_POD_IP=$(kubectl get pod test-worker -o jsonpath='{.status.podIP}')

# Ping from one pod to the other
kubectl exec test-heart -- ping -c 3 $WORKER_POD_IP
# Expected: successful ping

# Verify traffic is encrypted by checking WireGuard counters
sudo wg show flannel-wg
# Expected: transfer counters should increase after the ping

# Capture traffic on the wire to verify encryption (should NOT see plaintext)
sudo tcpdump -i eth0 -c 20 udp port 51820
# Expected: encrypted UDP packets on port 51820

# Cleanup
kubectl delete pod test-heart test-worker
```

### 5.5 Fallback Verification

If `flannel-wg` interface does not appear:

```bash
# Check K3s logs for WireGuard errors
sudo journalctl -u k3s --since "10 minutes ago" | grep -i wireguard

# Verify flannel backend in running config
sudo cat /var/lib/rancher/k3s/agent/etc/flannel/net-conf.json
# Expected: "Backend": {"Type": "wireguard-native"}

# Check if WireGuard kernel module loaded
lsmod | grep wireguard
# If not loaded: sudo modprobe wireguard
```

## 6. Cloudflare Origin Pull Authentication

### 6.1 Purpose

Cloudflare Authenticated Origin Pulls ensure that only traffic originating from Cloudflare can reach the origin servers. This prevents attackers from bypassing Cloudflare's WAF/DDoS protection by connecting directly to the origin IP.

### 6.2 Configuration on Cloudflare

1. In Cloudflare Dashboard -> SSL/TLS -> Origin Server:
   - Enable "Authenticated Origin Pulls"
   - This causes Cloudflare to present a client certificate on every request to the origin

2. Alternatively via API:

```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/settings/tls_client_auth" \
  -H "Authorization: Bearer <CF_API_TOKEN>" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'
```

### 6.3 Traefik Configuration

Download the Cloudflare origin pull CA certificate and configure Traefik to require it:

```bash
# Download Cloudflare Authenticated Origin Pulls CA
curl -o /etc/traefik/certs/cloudflare-origin-pull-ca.pem \
  https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
```

Traefik TLS options (via K3s HelmChartConfig):

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--entrypoints.websecure.http.tls.options=cloudflare-origin@file"
    volumes:
      - name: cloudflare-ca
        mountPath: /etc/traefik/certs
        type: configMap
```

TLS options file (mounted as ConfigMap):

```yaml
# traefik-dynamic-config.yaml
tls:
  options:
    cloudflare-origin:
      clientAuth:
        caFiles:
          - /etc/traefik/certs/cloudflare-origin-pull-ca.pem
        clientAuthType: RequireAndVerifyClientCert
      minVersion: VersionTLS12
      sniStrict: true
```

### 6.4 ConfigMap for Cloudflare CA

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflare-ca
  namespace: kube-system
data:
  cloudflare-origin-pull-ca.pem: |
    -----BEGIN CERTIFICATE-----
    <Cloudflare Origin Pull CA certificate content>
    -----END CERTIFICATE-----
```

### 6.5 Verification

```bash
# Test direct connection (should FAIL — no client cert)
curl -vk https://178.156.233.12
# Expected: SSL handshake failure or 403

# Test via Cloudflare (should SUCCEED)
curl -v https://app.helixstax.com
# Expected: 200 OK

# Verify Traefik TLS options are active
kubectl exec -n kube-system deploy/traefik -- traefik version
kubectl logs -n kube-system deploy/traefik | grep -i "clientAuth"
```

### 6.6 Firewall Restriction (Additional Layer)

Restrict HTTP/HTTPS ports to Cloudflare IP ranges only:

```bash
# Download current Cloudflare IP ranges
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)

# Remove generic HTTP/HTTPS rules
sudo firewall-cmd --permanent --zone=public --remove-port=80/tcp
sudo firewall-cmd --permanent --zone=public --remove-port=443/tcp

# Add rich rules for each Cloudflare IP range
for ip in $CF_IPV4; do
  sudo firewall-cmd --permanent --zone=public --add-rich-rule="
    rule family='ipv4'
    source address='$ip'
    port port='80' protocol='tcp'
    accept"
  sudo firewall-cmd --permanent --zone=public --add-rich-rule="
    rule family='ipv4'
    source address='$ip'
    port port='443' protocol='tcp'
    accept"
done

sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --zone=public --list-rich-rules | grep -c "accept"
```

Create a script to update Cloudflare IPs periodically:

```bash
#!/bin/bash
# /usr/local/bin/update-cloudflare-firewall.sh
# Run weekly via cron to keep Cloudflare IP ranges current

set -euo pipefail

NEW_IPS=$(curl -sf https://www.cloudflare.com/ips-v4)
if [ -z "$NEW_IPS" ]; then
  echo "ERROR: Failed to fetch Cloudflare IPs" >&2
  exit 1
fi

# Remove existing Cloudflare rules
for rule in $(sudo firewall-cmd --zone=public --list-rich-rules | grep "port port='80'" | grep -oP "source address='\K[^']+"); do
  sudo firewall-cmd --permanent --zone=public --remove-rich-rule="
    rule family='ipv4' source address='$rule' port port='80' protocol='tcp' accept"
  sudo firewall-cmd --permanent --zone=public --remove-rich-rule="
    rule family='ipv4' source address='$rule' port port='443' protocol='tcp' accept"
done

# Add new rules
for ip in $NEW_IPS; do
  sudo firewall-cmd --permanent --zone=public --add-rich-rule="
    rule family='ipv4' source address='$ip' port port='80' protocol='tcp' accept"
  sudo firewall-cmd --permanent --zone=public --add-rich-rule="
    rule family='ipv4' source address='$ip' port port='443' protocol='tcp' accept"
done

sudo firewall-cmd --reload
echo "$(date): Updated Cloudflare firewall rules ($(echo "$NEW_IPS" | wc -l) ranges)"
```

## 7. Network Security Verification Checklist

```bash
# 1. Firewalld zones
sudo firewall-cmd --get-active-zones
# Expected: public (eth0), trusted (cni0, flannel.1)

# 2. K3s inter-node ports (from worker)
nc -zv 178.156.233.12 6443     # K3s API — should succeed
nc -zv 178.156.233.12 2379     # etcd — should FAIL
nc -zv 178.156.233.12 2380     # etcd — should FAIL

# 3. Default-deny NetworkPolicies
kubectl get networkpolicy -A | grep default-deny-all
# Expected: one per application namespace

# 4. WireGuard encryption
sudo wg show
# Expected: active peer with recent handshake

# 5. Cloudflare origin pull
curl -vk https://178.156.233.12 2>&1 | grep -i "ssl"
# Expected: handshake failure (no client cert)

# 6. No unexpected open ports
sudo ss -tlnp | grep -v "127.0.0.1"
# Review: only expected ports should be LISTEN on 0.0.0.0
```

## 8. Compliance Mapping

### SOC 2

| Control | TSC Criteria | Implementation |
|---------|-------------|----------------|
| Network segmentation | CC6.6 | Firewalld zones, NetworkPolicy default-deny, namespace isolation |
| Access restrictions | CC6.1 | Rich rules limiting inter-node ports, Cloudflare-only origin access |
| Encryption in transit | CC6.7 | Flannel WireGuard (east-west), TLS 1.2+ (north-south) |

### ISO 27001

| Control | Annex A | Implementation |
|---------|---------|----------------|
| Network controls | A.13.1.1 | Firewalld zone architecture, default-deny posture |
| Network segregation | A.13.1.3 | K3s namespace isolation via NetworkPolicy |
| Information transfer | A.13.2.1 | WireGuard encryption, Cloudflare TLS, origin pull auth |

### NIST CSF

| Function | Category | Implementation |
|----------|----------|----------------|
| Protect | PR.AC-5 | Network integrity via default-deny, zone segmentation, WireGuard |
| Protect | PR.DS-2 | Data in transit protected by WireGuard + TLS |
| Protect | PR.PT-4 | Network communications protected by Cloudflare WAF + origin pull |
