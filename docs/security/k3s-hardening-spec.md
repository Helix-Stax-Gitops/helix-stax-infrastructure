---
title: K3s Cluster Hardening Specification
author: Wakeem Williams
co_author: Ezra Raines
date: 2026-03-23
version: "1.0"
status: draft
scope: K3s API server, etcd, PKI, RBAC, audit logging
target_os: AlmaLinux 9.7
cluster: heart (CP), helix-worker-1 (worker)
compliance_mapping:
  soc2:
    - CC6.1  # Logical and Physical Access Controls
    - CC7.2  # System Monitoring
  iso27001:
    - A.14.1.2  # Securing application services on public networks
    - A.14.1.3  # Protecting application services transactions
  nist_csf:
    - PR.AC-1  # Identities and credentials managed
    - PR.AC-4  # Access permissions managed
    - PR.AC-7  # Users, devices, assets authenticated
---

# K3s Cluster Hardening Specification

## 1. Overview

This document specifies the hardening requirements for the Helix Stax K3s cluster running on AlmaLinux 9.7. The cluster consists of a control plane node (`heart`, 178.156.233.12) and a worker node (`helix-worker-1`, 138.201.131.157). All controls align with the CIS Kubernetes Benchmark v1.8 and map to SOC 2 CC6.1/CC7.2, ISO 27001 A.14, and NIST CSF PR.AC requirements.

## 2. K3s Install Flags

### 2.1 Control Plane (heart)

The K3s server must be installed or reconfigured with the following flags in `/etc/rancher/k3s/config.yaml`:

```yaml
# /etc/rancher/k3s/config.yaml (control plane)
protect-kernel-defaults: true
secrets-encryption: true
kube-apiserver-arg:
  - "anonymous-auth=false"
  - "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"
  - "audit-policy-file=/var/lib/rancher/k3s/server/audit-policy.yaml"
  - "enable-admission-plugins=NodeRestriction,PodSecurityAdmission"
  - "request-timeout=300s"
  - "service-account-lookup=true"
  - "tls-min-version=VersionTLS12"
  - "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
kube-controller-manager-arg:
  - "terminated-pod-gc-threshold=10"
  - "use-service-account-credentials=true"
kubelet-arg:
  - "streaming-connection-idle-timeout=5m"
  - "make-iptables-util-chains=true"
  - "event-qps=0"
  - "read-only-port=0"
  - "anonymous-auth=false"
flannel-backend: wireguard-native
```

| Flag | Purpose | CIS Control |
|------|---------|-------------|
| `protect-kernel-defaults` | Ensures kubelet fails if kernel params don't match hardened defaults | CIS 4.2.6 |
| `secrets-encryption` | Enables encryption of Secrets at rest in etcd | CIS 1.2.29 |
| `anonymous-auth=false` | Disables anonymous API requests | CIS 1.2.1 |
| `audit-log-path` | Enables API server audit logging | CIS 1.2.18 |
| `audit-log-maxage=30` | Retains audit logs for 30 days | CIS 1.2.19 |
| `audit-log-maxbackup=10` | Keeps 10 rotated log files | CIS 1.2.20 |
| `audit-log-maxsize=100` | Limits log file to 100MB before rotation | CIS 1.2.21 |
| `NodeRestriction` | Limits kubelet API access to own node | CIS 1.2.13 |
| `service-account-lookup=true` | Validates service account tokens against etcd | CIS 1.2.22 |
| `read-only-port=0` | Disables unauthenticated kubelet read-only port | CIS 4.2.4 |

### 2.2 Worker Node (helix-worker-1)

```yaml
# /etc/rancher/k3s/config.yaml (worker)
protect-kernel-defaults: true
kubelet-arg:
  - "streaming-connection-idle-timeout=5m"
  - "make-iptables-util-chains=true"
  - "event-qps=0"
  - "read-only-port=0"
  - "anonymous-auth=false"
```

### 2.3 Required Kernel Parameters

These sysctl values must be set on all nodes before K3s starts (required by `--protect-kernel-defaults`):

```bash
# /etc/sysctl.d/90-k3s-hardened.conf
vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
kernel.keys.root_maxbytes=25000000
```

Apply and verify:

```bash
sudo sysctl --system
sudo sysctl vm.panic_on_oom vm.overcommit_memory kernel.panic kernel.panic_on_oops
```

## 3. Audit Policy

Create the audit policy file referenced by the API server flags:

```yaml
# /var/lib/rancher/k3s/server/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests to the Kubernetes API at the Metadata level
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  # Log authentication events at RequestResponse level
  - level: RequestResponse
    resources:
      - group: "authentication.k8s.io"
  # Log RBAC changes at RequestResponse level
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
  # Log namespace lifecycle at Metadata level
  - level: Metadata
    resources:
      - group: ""
        resources: ["namespaces"]
  # Default: log everything else at Request level
  - level: Request
```

## 4. etcd Encryption Configuration

### 4.1 Encryption at Rest

K3s with `--secrets-encryption` generates an encryption config at:
`/var/lib/rancher/k3s/server/cred/encryption-config.json`

Verify encryption is active:

```bash
# Check encryption config exists and uses aescbc or secretbox
sudo cat /var/lib/rancher/k3s/server/cred/encryption-config.json | python3 -m json.tool

# Verify secrets are actually encrypted in etcd
sudo k3s kubectl get secrets -A -o json | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{len(d[\"items\"])} secrets found')"

# Read raw etcd data to confirm encryption (should NOT be plaintext)
sudo k3s etcd-snapshot ls 2>/dev/null
```

### 4.2 Encryption Key Rotation

Rotate encryption keys periodically (quarterly minimum):

```bash
# Step 1: Prepare new encryption key
sudo k3s secrets-encrypt prepare

# Step 2: Restart K3s to pick up new key
sudo systemctl restart k3s

# Step 3: Rotate — re-encrypt all secrets with new key
sudo k3s secrets-encrypt rotate

# Step 4: Restart K3s again
sudo systemctl restart k3s

# Step 5: Reencrypt all secrets
sudo k3s secrets-encrypt reencrypt

# Step 6: Verify status
sudo k3s secrets-encrypt status
```

Expected output after rotation:

```
Encryption Status: Enabled
Current Rotation Stage: reencrypt_finished
```

## 5. PKI Permission Remediation

### 5.1 TLS Certificate Permissions

K3s stores TLS certificates at `/var/lib/rancher/k3s/server/tls/`. By default, some certificates may have overly permissive file modes. Remediate to satisfy CIS 1.1.19-1.1.21:

```bash
# Restrict all certificate files
sudo chmod 600 /var/lib/rancher/k3s/server/tls/*.crt
sudo chmod 600 /var/lib/rancher/k3s/server/tls/*.key
sudo chown root:root /var/lib/rancher/k3s/server/tls/*.crt
sudo chown root:root /var/lib/rancher/k3s/server/tls/*.key

# Verify permissions
sudo ls -la /var/lib/rancher/k3s/server/tls/
```

Expected output: all `.crt` and `.key` files show `-rw-------` with `root root` ownership.

### 5.2 Kubeconfig Permissions

```bash
# Restrict kubeconfig access
sudo chmod 600 /etc/rancher/k3s/k3s.yaml
sudo chown root:root /etc/rancher/k3s/k3s.yaml

# Restrict K3s server directory
sudo chmod 700 /var/lib/rancher/k3s/server/
```

### 5.3 Persistence Across Restarts

Add a systemd drop-in to enforce permissions after K3s restarts (K3s regenerates some certs on start):

```bash
sudo mkdir -p /etc/systemd/system/k3s.service.d/
sudo tee /etc/systemd/system/k3s.service.d/pki-permissions.conf << 'EOF'
[Service]
ExecStartPost=/bin/bash -c 'sleep 5 && chmod 600 /var/lib/rancher/k3s/server/tls/*.crt /var/lib/rancher/k3s/server/tls/*.key'
EOF
sudo systemctl daemon-reload
```

## 6. RBAC Hardening

### 6.1 Principles

- No workloads use the `default` service account
- All service accounts have explicitly scoped Roles (not ClusterRoles) where possible
- `cluster-admin` ClusterRoleBinding is limited to break-glass scenarios
- Every namespace has a deny-all NetworkPolicy (see network-security-spec.md)

### 6.2 Default Service Account Restriction

Apply to every namespace:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
automountServiceAccountToken: false
```

Automation command:

```bash
# Patch default service account in all namespaces
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  kubectl patch serviceaccount default -n "$ns" \
    -p '{"automountServiceAccountToken": false}'
done
```

### 6.3 ClusterRole Audit

Run regularly to identify overly permissive bindings:

```bash
# List all ClusterRoleBindings with cluster-admin
kubectl get clusterrolebinding -o json | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['items']:
    ref = item.get('roleRef', {})
    if ref.get('name') == 'cluster-admin':
        subjects = item.get('subjects', [])
        for s in subjects:
            print(f\"WARN: {s.get('kind')}/{s.get('name')} has cluster-admin via {item['metadata']['name']}\")
"
```

### 6.4 Pod Security Admission

Enforce Pod Security Standards per namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Namespaces that require privileged access (e.g., `kube-system`, monitoring DaemonSets) use:

```yaml
labels:
  pod-security.kubernetes.io/enforce: privileged
  pod-security.kubernetes.io/audit: baseline
  pod-security.kubernetes.io/warn: baseline
```

## 7. kube-bench Expected Results

### 7.1 Installation

```bash
# Install kube-bench on AlmaLinux 9
curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.8.0/kube-bench_0.8.0_linux_amd64.rpm \
  -o /tmp/kube-bench.rpm
sudo rpm -ivh /tmp/kube-bench.rpm
```

### 7.2 Running kube-bench

```bash
# Run against K3s (specify config directory)
sudo kube-bench run --targets=master,node \
  --config-dir=/etc/kube-bench/cfg \
  --benchmark cis-1.8 \
  --json > /var/log/compliance/kube-bench-$(date +%F).json

# Human-readable summary
sudo kube-bench run --targets=master,node \
  --config-dir=/etc/kube-bench/cfg \
  --benchmark cis-1.8
```

### 7.3 Expected Results After Hardening

| Section | Description | Expected PASS | Expected WARN | Expected FAIL |
|---------|-------------|:---:|:---:|:---:|
| 1.1 | Control Plane Configuration Files | 18 | 0 | 0 |
| 1.2 | API Server | 24 | 2 | 0 |
| 1.3 | Controller Manager | 7 | 0 | 0 |
| 1.4 | Scheduler | 2 | 0 | 0 |
| 2 | etcd | 7 | 0 | 0 |
| 3 | Control Plane Configuration | 4 | 0 | 0 |
| 4.1 | Worker Node Configuration Files | 10 | 0 | 0 |
| 4.2 | Kubelet | 13 | 0 | 0 |
| 5 | Policies | 16 | 10 | 0 |

Notes:
- Section 1.2 WARNs are for controls that require manual verification (e.g., encryption provider configuration review)
- Section 5 WARNs are for organizational policies that must be verified procedurally (e.g., namespace lifecycle, RBAC reviews)
- Zero FAILs is the target after all controls in this spec are implemented

### 7.4 Remediation Tracking

Any FAIL result from kube-bench must be:
1. Logged as a GitHub issue with label `security`
2. Remediated within 14 days (HIGH) or 7 days (CRITICAL)
3. Re-scanned to confirm remediation

## 8. Compliance Mapping

### SOC 2

| Control | TSC Criteria | Implementation |
|---------|-------------|----------------|
| API authentication | CC6.1 | `anonymous-auth=false`, service account restrictions |
| Audit logging | CC7.2 | `audit-log-path`, 30-day retention, MinIO archival |
| Encryption at rest | CC6.1 | `--secrets-encryption`, etcd encryption config |
| Access control | CC6.1 | RBAC, Pod Security Admission, default SA restriction |

### ISO 27001

| Control | Annex A | Implementation |
|---------|---------|----------------|
| Secure network services | A.14.1.2 | TLS 1.2+ cipher suites, WireGuard overlay |
| Protection of transactions | A.14.1.3 | Mutual TLS between components, audit trail |
| Access control policy | A.9.1.1 | RBAC, namespace isolation, least privilege |

### NIST CSF

| Function | Category | Implementation |
|----------|----------|----------------|
| Protect | PR.AC-1 | Identity and credential management via Zitadel + SA tokens |
| Protect | PR.AC-4 | RBAC, namespace scoping, least privilege |
| Protect | PR.AC-7 | `anonymous-auth=false`, service account lookup |
| Detect | DE.CM-3 | Audit logging, kube-bench scanning |

## 9. Verification Checklist

After applying all hardening controls, verify:

```bash
# 1. Verify K3s flags are active
sudo k3s check-config 2>&1 | head -20

# 2. Verify anonymous auth is disabled
curl -sk https://localhost:6443/api/v1/namespaces
# Expected: 401 Unauthorized

# 3. Verify secrets encryption
sudo k3s secrets-encrypt status
# Expected: Encryption Status: Enabled

# 4. Verify audit logs are being written
sudo ls -la /var/lib/rancher/k3s/server/logs/audit.log
# Expected: file exists and is growing

# 5. Verify PKI permissions
sudo stat -c '%a %U:%G %n' /var/lib/rancher/k3s/server/tls/*.crt
# Expected: 600 root:root for all files

# 6. Verify default SA is restricted
kubectl get sa default -n default -o jsonpath='{.automountServiceAccountToken}'
# Expected: false

# 7. Run kube-bench
sudo kube-bench run --targets=master --benchmark cis-1.8 2>&1 | tail -10
# Expected: 0 checks FAIL
```
