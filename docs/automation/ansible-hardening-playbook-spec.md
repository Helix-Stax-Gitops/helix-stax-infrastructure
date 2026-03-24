---
title: Ansible CIS Hardening Playbook Specification
author: Wakeem Williams
co_author: Kit Morrow
created: 2026-03-23
status: draft
category: automation
tags: [ansible, cis, hardening, almalinux, k3s, compliance]
source: gemini-output-server-hardening-security-automation.md
---

# Ansible CIS Hardening Playbook Specification

## 1. Overview

This document specifies the Ansible playbook architecture for applying CIS Level 1 Server hardening to all Helix Stax AlmaLinux 9.7 hosts. The playbook uses the `ansible-lockdown/RHEL9-CIS` role (v2.2.0) with K3s-specific exceptions to maintain cluster functionality while achieving compliance.

**Target Profile:** CIS Benchmark Level 1 - Server (`xccdf_org.ssgproject.content_profile_cis_server_l1`)

**Target OS:** AlmaLinux 9.7 (`ansible_os_family == "RedHat"`)

**Compliance Frameworks:** SOC 2 Type II, ISO 27001:2022, HIPAA (secondary)

## 2. Directory Structure

```
ansible/
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── hosts.yml
│   ├── group_vars/
│   │   └── all.yml
│   └── host_vars/
│       ├── helix-stax-cp.yml
│       └── helix-stax-vps.yml
├── playbooks/
│   ├── harden.yml
│   ├── k3s-install.yml
│   └── patch.yml
└── roles/
    └── (ansible-lockdown/RHEL9-CIS via requirements.yml)
```

## 3. Role Installation

### requirements.yml

```yaml
---
roles:
  - name: ansible-lockdown.RHEL9-CIS
    version: "2.2.0"
    src: https://github.com/ansible-lockdown/RHEL9-CIS.git
    scm: git
```

### Install Command

```bash
ansible-galaxy install -r requirements.yml --force
```

## 4. Inventory

### hosts.yml

```yaml
---
all:
  children:
    k3s_cluster:
      children:
        control_plane:
          hosts:
            helix-stax-cp:
              ansible_host: 178.156.233.12
              ansible_user: helix-admin
              ansible_ssh_private_key_file: ~/.ssh/id_ed25519_helix_admin
        workers:
          hosts:
            helix-stax-vps:
              ansible_host: 138.201.131.157
              ansible_user: helix-admin
              ansible_ssh_private_key_file: ~/.ssh/id_ed25519_helix_admin
```

## 5. K3s Exception Variables

K3s requires specific CIS rules to be disabled to maintain cluster networking functionality. These exceptions are documented and justified for auditor review.

### group_vars/all.yml

```yaml
---
# ==============================================================================
# CIS Benchmark: ansible-lockdown/RHEL9-CIS v2.2.0
# Profile: CIS Level 1 - Server
# Target OS: AlmaLinux 9.7
# ==============================================================================

# --- K3s Network Exceptions ---
# These rules MUST be disabled for K3s cluster networking.
# Flannel CNI requires IP forwarding, packet routing, and ICMP redirects.
# Justification documented for SOC 2 / ISO 27001 auditors.

rhel9cis_rule_3_1_1: false  # Allow IPv4 IP Forwarding (net.ipv4.ip_forward=1)
rhel9cis_rule_3_1_2: false  # Allow packet routing
rhel9cis_rule_3_2_2: false  # Allow ICMP Redirects (Flannel WireGuard)

# --- Firewalld K3s Exceptions ---
# K3s CNI requires dynamic iptables/firewalld rule manipulation.
# Trusted zones configured for CNI interfaces.
rhel9cis_firewall_allowed_zones:
  - trusted
  - drop

# --- Selective CIS Level 2 Adoptions ---
# These Level 2 controls add defense-in-depth without K3s conflicts.
rhel9cis_rule_disable_ipv6: true              # Disable IPv6 at kernel level
rhel9cis_rule_disable_dccp: true              # Blacklist DCCP protocol
rhel9cis_rule_disable_sctp: true              # Blacklist SCTP protocol
rhel9cis_rule_disable_rds: true               # Blacklist RDS protocol
rhel9cis_auditd_immutable: true               # auditd -e 2 (immutable rules)

# --- General Hardening ---
rhel9cis_selinux_state: enforcing
rhel9cis_selinux_policy: targeted
rhel9cis_time_synchronization: chrony
rhel9cis_sshd_allow_users: helix-admin
rhel9cis_sshd_max_auth_tries: 3
rhel9cis_password_min_length: 14
```

### host_vars/helix-stax-cp.yml

```yaml
---
# Control Plane specific overrides
k3s_role: server
k3s_is_control_plane: true

# CP runs API server -- additional audit logging
rhel9cis_audit_log_retention: 30
```

### host_vars/helix-stax-vps.yml

```yaml
---
# Worker node specific overrides
k3s_role: agent
k3s_is_control_plane: false
```

## 6. Hardening Playbook

### playbooks/harden.yml

```yaml
---
- name: Apply CIS Level 1 Hardening to AlmaLinux 9
  hosts: k3s_cluster
  become: true
  serial: 1  # Rolling application -- one node at a time

  pre_tasks:
    - name: Verify AlmaLinux 9 target
      ansible.builtin.assert:
        that:
          - ansible_os_family == "RedHat"
          - ansible_distribution == "AlmaLinux"
          - ansible_distribution_major_version == "9"
        fail_msg: "This playbook targets AlmaLinux 9 only."

    - name: Check K3s service status
      ansible.builtin.systemd:
        name: "{{ 'k3s' if k3s_role == 'server' else 'k3s-agent' }}"
      register: k3s_service
      ignore_errors: true

  roles:
    - role: ansible-lockdown.RHEL9-CIS

  post_tasks:
    - name: Verify K3s still running after hardening
      ansible.builtin.systemd:
        name: "{{ 'k3s' if k3s_role == 'server' else 'k3s-agent' }}"
        state: started
      when: k3s_service is defined and k3s_service.status is defined

    - name: Verify SELinux is enforcing
      ansible.builtin.command: getenforce
      register: selinux_status
      changed_when: false
      failed_when: selinux_status.stdout != "Enforcing"
```

## 7. Firewalld Trusted Zones for K3s

K3s CNI interfaces must be placed in trusted firewalld zones to allow pod-to-pod and pod-to-service communication.

### Required Zone Configuration

```yaml
# In harden.yml post_tasks or as a separate task file:

- name: Add cni0 interface to trusted zone
  ansible.posix.firewalld:
    zone: trusted
    interface: cni0
    permanent: true
    state: enabled
  notify: reload firewalld

- name: Add flannel.1 interface to trusted zone
  ansible.posix.firewalld:
    zone: trusted
    interface: flannel.1
    permanent: true
    state: enabled
  notify: reload firewalld

- name: Allow K3s API server port (CP only)
  ansible.posix.firewalld:
    zone: public
    port: 6443/tcp
    permanent: true
    state: enabled
  when: k3s_is_control_plane | default(false)
  notify: reload firewalld

- name: Allow K3s metrics port
  ansible.posix.firewalld:
    zone: public
    port: 10250/tcp
    permanent: true
    state: enabled
  notify: reload firewalld

- name: Allow WireGuard port for Flannel
  ansible.posix.firewalld:
    zone: public
    port: 51820/udp
    permanent: true
    state: enabled
  notify: reload firewalld
```

### Firewalld Ports Summary

| Port | Protocol | Purpose | Nodes |
|------|----------|---------|-------|
| 6443 | TCP | K3s API Server | CP only |
| 10250 | TCP | Kubelet metrics | All |
| 51820 | UDP | WireGuard (Flannel) | All |
| 2222 | TCP | dracut-sshd (LUKS unlock) | All |

## 8. Idempotency Requirements

The playbook MUST be fully idempotent. Running it multiple times produces no unnecessary changes.

| Requirement | Implementation |
|-------------|----------------|
| No unnecessary service restarts | Use `changed_when` and `notify` handlers properly |
| No redundant file writes | Use `ansible.builtin.template` with `backup: true` |
| Conditional execution | Use `when` clauses to skip already-compliant hosts |
| Handler deduplication | Group related changes under single handler notifications |
| Check mode safe | All tasks must support `--check` mode without side effects |

### Validation Command

```bash
# Dry run -- must show 0 changes on a compliant host
ansible-playbook -i inventory/hosts.yml playbooks/harden.yml --check --diff
```

## 9. Drift Detection

### Strategy

Run `ansible-playbook --check --diff` daily to detect configuration drift from the hardened baseline. Any detected drift triggers an alert through the notification pipeline.

### Drift Detection Pipeline

```
ansible-playbook --check --diff
        |
        v
   Changes detected?
        |
   Yes  |  No
   v    v
  Capture diff output    Exit cleanly
        |
        v
   POST diff to n8n webhook
        |
        v
   n8n formats message
        |
        v
   Rocket.Chat #security-alerts
```

### Cron Job (Interim)

```bash
# /etc/cron.d/helix-drift-detection
0 6 * * * helix-admin /opt/ansible/scripts/drift-check.sh >> /var/log/drift-detection.log 2>&1
```

### drift-check.sh

```bash
#!/bin/bash
set -euo pipefail

ANSIBLE_DIR="/opt/ansible"
WEBHOOK_URL="https://n8n.helixstax.net/webhook/drift-detection"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_FILE="/tmp/drift-${TIMESTAMP}.log"

cd "$ANSIBLE_DIR"

# Run check mode, capture output
ansible-playbook -i inventory/hosts.yml playbooks/harden.yml \
  --check --diff 2>&1 | tee "$LOG_FILE"

# Check for changes
CHANGED_COUNT=$(grep -c "changed=" "$LOG_FILE" | grep -v "changed=0" || echo "0")

if [ "$CHANGED_COUNT" -gt 0 ]; then
  # POST to n8n webhook
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"timestamp\": \"${TIMESTAMP}\",
      \"changed_count\": ${CHANGED_COUNT},
      \"diff_output\": $(jq -Rs . < "$LOG_FILE"),
      \"severity\": \"warning\"
    }"
fi

# Archive to MinIO for compliance evidence
HASH=$(sha256sum "$LOG_FILE" | awk '{print $1}')
mc cp "$LOG_FILE" "helix-minio/compliance-evidence/drift/${TIMESTAMP}-${HASH}.log"
```

### Airflow DAG (Target State)

Once Airflow is deployed on K3s, the drift detection cron job will be migrated to an Airflow DAG for:
- Immutable task-level audit logging
- Retry and backfill support
- Centralized scheduling visibility
- Integration with the compliance evidence pipeline

## 10. Reporting

### n8n Webhook Payload Schema

```json
{
  "timestamp": "2026-03-23T06:00:00Z",
  "changed_count": 3,
  "diff_output": "--- /etc/ssh/sshd_config\n+++ ...",
  "severity": "warning|critical",
  "source": "drift-detection",
  "hosts_affected": ["helix-stax-cp", "helix-stax-vps"]
}
```

### Rocket.Chat Message Format

```
[Drift Detection] 2026-03-23T06:00:00Z
Hosts affected: helix-stax-cp
Changed tasks: 3
Severity: WARNING

Changes detected:
- /etc/ssh/sshd_config: PermitRootLogin changed
- /etc/sysctl.d/99-k3s.conf: net.ipv4.ip_forward removed
- /etc/audit/rules.d/audit.rules: rules modified

Action required: Review drift and re-run hardening playbook.
```

## 11. Compliance Evidence

All drift detection and hardening runs produce evidence for SOC 2 / ISO 27001 audits:

| Artifact | Storage | Retention | Integrity |
|----------|---------|-----------|-----------|
| Ansible run logs | MinIO `compliance-evidence/ansible/` | 7 years | SHA-256 hash |
| Drift detection diffs | MinIO `compliance-evidence/drift/` | 7 years | SHA-256 hash |
| OpenSCAP ARF reports | MinIO `compliance-evidence/scap/` | 7 years | SHA-256 hash |

MinIO bucket uses S3 Object Lock (Compliance Mode) for tamper-evident storage.

## 12. Testing

### Pre-deployment Validation

```bash
# Syntax check
ansible-playbook -i inventory/hosts.yml playbooks/harden.yml --syntax-check

# Dry run with diff output
ansible-playbook -i inventory/hosts.yml playbooks/harden.yml --check --diff

# Limit to single host for initial testing
ansible-playbook -i inventory/hosts.yml playbooks/harden.yml --limit helix-stax-vps
```

### Post-hardening Verification

```bash
# Verify CIS compliance via OpenSCAP
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-$(date +%F).xml \
  --report /var/log/compliance/report-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml

# Verify K3s cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify SELinux
getenforce  # Must return "Enforcing"

# Verify firewalld zones
firewall-cmd --get-active-zones
firewall-cmd --zone=trusted --list-interfaces  # Must show cni0, flannel.1
```
