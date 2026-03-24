---
title: Rolling Patch Strategy -- Standard Operating Procedure
author: Wakeem Williams
co_author: Kit Morrow
created: 2026-03-23
status: draft
category: automation
tags: [patching, sop, k3s, almalinux, luks, compliance, soc2]
source: gemini-output-server-hardening-security-automation.md
---

# Rolling Patch Strategy -- Standard Operating Procedure

## 1. Overview

This SOP defines the rolling patch procedure for the Helix Stax K3s cluster running on AlmaLinux 9.7. The strategy patches one node at a time, draining workloads before updates and verifying cluster health before proceeding to the next node.

**Cluster Topology:**

| Node | Role | IP | K3s Service |
|------|------|----|-------------|
| helix-stax-cp | Control Plane | 178.156.233.12 | k3s (server) |
| helix-stax-vps | Worker | 138.201.131.157 | k3s-agent |

**Patch Order:** Worker first, then Control Plane. This ensures the API server remains available to manage drain/uncordon operations throughout the process.

## 2. SLA Requirements

Patch timelines are driven by SOC 2 CC7.1 (System Change Management) and ISO 27001 A.8.8 (Technical Vulnerability Management).

| Severity | SLA | Compliance Mapping |
|----------|-----|--------------------|
| Critical CVE (CVSS 9.0+) | Within 48 hours | SOC 2 CC7.1, ISO A.8.8 |
| High CVE (CVSS 7.0-8.9) | Within 14 days | SOC 2 CC7.1, ISO A.8.8 |
| Medium CVE (CVSS 4.0-6.9) | Next maintenance window | SOC 2 CC7.1 |
| Low CVE (CVSS 0.1-3.9) | Quarterly batch | SOC 2 CC7.1 |

## 3. Maintenance Window

| Item | Value |
|------|-------|
| Scheduled window | Sundays 02:00-06:00 UTC |
| Emergency window | As needed for Critical CVE |
| Communication | Rocket.Chat #maintenance + calendar event |
| Approval required | Wakeem Williams (owner) |
| Duration estimate | 45-60 minutes per node |

### Pre-Window Notification Template (Rocket.Chat)

```
[Maintenance] Scheduled Patching -- {DATE}
Window: Sunday 02:00-06:00 UTC
Nodes: helix-stax-vps, helix-stax-cp (sequential)
Scope: Security patches (dnf update --security)
Expected impact: Brief pod rescheduling during node drain
```

## 4. Pre-Patch Checklist

Run these checks BEFORE starting the patch procedure. If any check fails, do not proceed.

### 4.1 Verify Cluster Health

```bash
# All nodes must be Ready
kubectl get nodes
# Expected: All nodes STATUS = Ready

# All system pods running
kubectl get pods -n kube-system
# Expected: All pods Running or Completed

# No pods in error state
kubectl get pods -A --field-selector status.phase!=Running,status.phase!=Succeeded
# Expected: No results (or only expected short-lived jobs)
```

### 4.2 Check for In-Progress Deployments

```bash
# No active rollouts
kubectl rollout status deployment -A --timeout=10s 2>&1 | grep -v "successfully rolled out"
# Expected: No output (all deployments stable)

# No pending Helm releases
helm list -A --pending
# Expected: No pending releases
```

### 4.3 Check for Active CI/CD Jobs

```bash
# Verify no active Devtron deployments
# Check Devtron UI or API for active workflows

# Verify no active ArgoCD syncs
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.status.sync.status}{"\n"}{end}'
# Expected: All applications "Synced"
```

### 4.4 Verify Backup Status

```bash
# Confirm recent Velero backup exists
velero backup get --selector velero.io/schedule-name=daily-backup | head -5
# Expected: Recent backup with status "Completed"

# Verify etcd snapshot exists (CP only)
ls -la /var/lib/rancher/k3s/server/db/snapshots/
# Expected: Recent snapshot file
```

### 4.5 Check Available Updates

```bash
# Preview security updates (run on target node)
ssh helix-admin@<node-ip> "sudo dnf check-update --security"
```

## 5. Patch Procedure

### Overview (Per Node)

```
Step 1: Drain node (evict pods)
    |
Step 2: Apply security patches (dnf update --security)
    |
Step 3: Reboot
    |
Step 4: LUKS unlock via dracut-sshd
    |
Step 5: Verify K3s health
    |
Step 6: Uncordon node
    |
Step 7: Repeat for next node
```

---

### Step 1: Drain Node

Evict all non-DaemonSet pods from the target node. Pods with PodDisruptionBudgets will be respected.

```bash
# For worker node:
kubectl drain helix-stax-vps \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=300s

# For CP node:
kubectl drain helix-stax-cp \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=300s
```

**Verification:**

```bash
# Confirm node is cordoned
kubectl get node <node-name>
# Expected: STATUS = Ready,SchedulingDisabled

# Confirm pods evacuated (only DaemonSets remain)
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>
# Expected: Only DaemonSet pods (flannel, kube-proxy, etc.)
```

**Troubleshooting:**

| Issue | Resolution |
|-------|------------|
| Drain times out | Check PDB constraints; increase timeout or use `--force` |
| Pod stuck in Terminating | `kubectl delete pod <name> --grace-period=0 --force` |
| Local storage pods won't drain | Verify `--delete-emptydir-data` flag is set |

---

### Step 2: Apply Security Patches

```bash
# SSH to the drained node
ssh helix-admin@<node-ip>

# Apply security-only updates
sudo dnf update -y --security

# Review what was updated
sudo dnf history info last

# Check if reboot is required
sudo needs-restarting -r
# Exit code 1 = reboot required
# Exit code 0 = no reboot needed
```

**If no reboot required:** Skip Steps 3-4, proceed to Step 5.

---

### Step 3: Reboot

```bash
sudo systemctl reboot
```

The node will go offline. Connection will drop.

---

### Step 4: LUKS Unlock via dracut-sshd

The node uses LUKS Full Disk Encryption. After reboot, the node pauses at the LUKS unlock prompt. Remote unlock is performed via dracut-sshd on port 2222.

```bash
# Wait for dracut-sshd to become available (usually 30-60 seconds after reboot)
# SSH to port 2222 with the unlock key
ssh -p 2222 root@<node-ip>

# At the dracut prompt, unlock the LUKS volume
cryptroot-unlock
# Enter the LUKS passphrase when prompted

# The system will continue booting automatically after unlock
# The SSH session on port 2222 will disconnect
```

**Verification:**

```bash
# Wait 60-90 seconds for full boot, then verify SSH on standard port
ssh helix-admin@<node-ip> "uptime"
# Expected: System is up, uptime shows recent boot
```

**Troubleshooting:**

| Issue | Resolution |
|-------|------------|
| Port 2222 not responding | Wait longer (up to 2 minutes); verify firewall allows 2222/tcp |
| `cryptroot-unlock` not found | dracut-sshd may not be installed; boot into rescue mode |
| Wrong passphrase | Re-enter; after 3 failures, reboot and retry |
| System does not continue booting | Check dracut logs; may need Hetzner rescue console |

---

### Step 5: Verify K3s Health

After the node finishes booting, verify K3s comes back healthy.

```bash
# Check K3s service is running
ssh helix-admin@<node-ip> "sudo systemctl status k3s"     # CP
ssh helix-admin@<node-ip> "sudo systemctl status k3s-agent" # Worker

# Verify node rejoins cluster (run from CP or local kubectl)
kubectl get nodes
# Expected: Patched node shows STATUS = Ready,SchedulingDisabled

# Verify system pods on the node are running
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>
# Expected: DaemonSet pods are Running

# Verify WireGuard re-establishes
ssh helix-admin@<node-ip> "sudo wg show"
# Expected: Peer entries visible with recent handshake
```

**Wait for node to be fully Ready before proceeding.** This may take 1-3 minutes.

---

### Step 6: Uncordon Node

Allow pod scheduling to resume on the patched node.

```bash
kubectl uncordon <node-name>
```

**Verification:**

```bash
# Confirm node is schedulable
kubectl get node <node-name>
# Expected: STATUS = Ready (no SchedulingDisabled)

# Verify pods are rescheduling to the node
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>
# Expected: Pods starting to schedule on this node
```

---

### Step 7: Repeat for Next Node

After verifying the first node is fully healthy and serving traffic:

1. Wait 5 minutes for pod stabilization
2. Run the pre-patch health checks again (Section 4.1)
3. Repeat Steps 1-6 for the next node

**Patch order:**
1. `helix-stax-vps` (worker) -- patches while CP manages the cluster
2. `helix-stax-cp` (control plane) -- patches last, worker handles workloads

## 6. Post-Patch Verification

After ALL nodes are patched and uncordoned:

```bash
# Full cluster health check
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify no pods stuck
kubectl get pods -A --field-selector status.phase=Pending

# Verify services accessible
curl -s -o /dev/null -w "%{http_code}" https://helixstax.com
# Expected: 200

# Run OpenSCAP scan for compliance evidence
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
  --tailoring-file /etc/security/scap/helix-stax-k3s-tailoring.xml \
  --results-arf /var/log/compliance/arf-results-$(date +%F).xml \
  --report /var/log/compliance/report-$(date +%F).html \
  /usr/share/xml/scap/ssg/content/ssg-almalinux9-ds.xml

# Archive evidence to MinIO
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mc cp /var/log/compliance/arf-results-$(date +%F).xml \
  helix-minio/compliance-evidence/scap/post-patch-${TIMESTAMP}.xml
```

## 7. Rollback Procedure

If a patch breaks services and the node cannot recover:

### 7.1 Immediate Rollback (dnf history)

```bash
# View recent dnf transactions
sudo dnf history list --reverse | tail -5

# Identify the patch transaction ID
sudo dnf history info <transaction-id>

# Undo the transaction
sudo dnf history undo <transaction-id> -y

# Reboot if kernel was reverted
sudo systemctl reboot
# (LUKS unlock required -- see Step 4)
```

### 7.2 Kernel Rollback (GRUB)

If a kernel update causes boot failure:

```bash
# Access via Hetzner rescue console or dracut-sshd
# At GRUB menu, select previous kernel version
# Or set default kernel:
sudo grubby --set-default /boot/vmlinuz-<previous-version>
sudo systemctl reboot
```

### 7.3 Full Node Recovery (Hetzner Snapshot)

If all else fails:

```bash
# Restore from pre-patch Hetzner snapshot (via Hetzner Cloud Console or API)
hcloud server rebuild <server-id> --image <snapshot-id>

# After restore, rejoin K3s cluster
# Worker: systemctl start k3s-agent
# CP: systemctl start k3s (may need etcd recovery)
```

### 7.4 Post-Rollback Actions

1. Uncordon the rolled-back node: `kubectl uncordon <node-name>`
2. Verify cluster health (Section 4.1)
3. Document the failure in Rocket.Chat #incidents
4. Create a GitHub issue for the failed patch
5. Investigate root cause before reattempting

## 8. Ansible Automation

### playbooks/patch.yml

```yaml
---
# ==============================================================================
# Rolling Patch Playbook -- AlmaLinux 9.7
# Patches one node at a time with drain/uncordon workflow.
# LUKS unlock is manual (requires operator for passphrase entry).
# ==============================================================================

- name: "Rolling Patch: Worker Node"
  hosts: workers
  become: true
  serial: 1

  tasks:
    - name: Pre-patch -- Verify cluster health
      ansible.builtin.command: kubectl get nodes
      delegate_to: "{{ groups['control_plane'][0] }}"
      register: cluster_health
      changed_when: false
      failed_when: "'NotReady' in cluster_health.stdout"

    - name: Drain worker node
      ansible.builtin.command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets
        --delete-emptydir-data
        --timeout=300s
      delegate_to: "{{ groups['control_plane'][0] }}"
      changed_when: true

    - name: Apply security patches
      ansible.builtin.dnf:
        name: "*"
        state: latest
        security: true
        update_cache: true

    - name: Check if reboot required
      ansible.builtin.command: needs-restarting -r
      register: reboot_required
      changed_when: false
      failed_when: false

    - name: Reboot if required
      ansible.builtin.reboot:
        msg: "Patch reboot"
        reboot_timeout: 600
      when: reboot_required.rc == 1

    - name: Pause for LUKS unlock
      ansible.builtin.pause:
        prompt: >
          NODE {{ inventory_hostname }} HAS REBOOTED.
          Perform LUKS unlock now:
            ssh -p 2222 root@{{ ansible_host }}
            cryptroot-unlock
          Press ENTER when unlock is complete.
      when: reboot_required.rc == 1

    - name: Wait for node to come back online
      ansible.builtin.wait_for_connection:
        delay: 30
        timeout: 300

    - name: Verify K3s agent is running
      ansible.builtin.systemd:
        name: k3s-agent
        state: started
      register: k3s_status

    - name: Wait for node Ready status
      ansible.builtin.command: >
        kubectl get node {{ inventory_hostname }} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
      delegate_to: "{{ groups['control_plane'][0] }}"
      register: node_ready
      retries: 30
      delay: 10
      until: node_ready.stdout == "True"
      changed_when: false

    - name: Uncordon worker node
      ansible.builtin.command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: "{{ groups['control_plane'][0] }}"
      changed_when: true

    - name: Wait for pod stabilization
      ansible.builtin.pause:
        seconds: 300

- name: "Rolling Patch: Control Plane"
  hosts: control_plane
  become: true
  serial: 1

  tasks:
    - name: Pre-patch -- Verify worker is healthy
      ansible.builtin.command: kubectl get nodes
      register: cluster_health
      changed_when: false
      failed_when: "'NotReady' in cluster_health.stdout"

    - name: Drain control plane node
      ansible.builtin.command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets
        --delete-emptydir-data
        --timeout=300s
      changed_when: true

    - name: Create etcd snapshot before patching
      ansible.builtin.command: >
        k3s etcd-snapshot save --name pre-patch-{{ ansible_date_time.date }}
      changed_when: true

    - name: Apply security patches
      ansible.builtin.dnf:
        name: "*"
        state: latest
        security: true
        update_cache: true

    - name: Check if reboot required
      ansible.builtin.command: needs-restarting -r
      register: reboot_required
      changed_when: false
      failed_when: false

    - name: Reboot if required
      ansible.builtin.reboot:
        msg: "Patch reboot"
        reboot_timeout: 600
      when: reboot_required.rc == 1

    - name: Pause for LUKS unlock
      ansible.builtin.pause:
        prompt: >
          NODE {{ inventory_hostname }} (CONTROL PLANE) HAS REBOOTED.
          Perform LUKS unlock now:
            ssh -p 2222 root@{{ ansible_host }}
            cryptroot-unlock
          Press ENTER when unlock is complete.
      when: reboot_required.rc == 1

    - name: Wait for node to come back online
      ansible.builtin.wait_for_connection:
        delay: 30
        timeout: 300

    - name: Verify K3s server is running
      ansible.builtin.systemd:
        name: k3s
        state: started

    - name: Wait for API server
      ansible.builtin.command: kubectl get nodes
      register: api_ready
      retries: 30
      delay: 10
      until: api_ready.rc == 0
      changed_when: false

    - name: Uncordon control plane
      ansible.builtin.command: kubectl uncordon {{ inventory_hostname }}
      changed_when: true

- name: "Post-Patch: Final Verification"
  hosts: control_plane
  become: true

  tasks:
    - name: Final cluster health check
      ansible.builtin.command: kubectl get nodes -o wide
      register: final_health
      changed_when: false

    - name: Display cluster status
      ansible.builtin.debug:
        var: final_health.stdout_lines

    - name: Check for unhealthy pods
      ansible.builtin.command: >
        kubectl get pods -A --field-selector status.phase!=Running,status.phase!=Succeeded
      register: unhealthy_pods
      changed_when: false
      failed_when: unhealthy_pods.stdout_lines | length > 1
```

## 9. Compliance Evidence

Every patch event produces the following evidence for auditors:

| Artifact | Location | Purpose |
|----------|----------|---------|
| dnf history output | MinIO `compliance-evidence/patching/` | Proof of timely patching |
| Pre/post OpenSCAP report | MinIO `compliance-evidence/scap/` | Compliance state verification |
| Ansible run log | MinIO `compliance-evidence/ansible/` | Change management audit trail |
| etcd snapshot (CP) | `/var/lib/rancher/k3s/server/db/snapshots/` | Rollback capability |
| Rocket.Chat notification | Rocket.Chat #maintenance | Communication evidence |

### SOC 2 CC7.1 Mapping

| CC7.1 Requirement | Evidence |
|--------------------|----------|
| Changes are authorized | Maintenance window approval in Rocket.Chat |
| Changes are documented | dnf history + Ansible logs in MinIO |
| Changes are tested | Post-patch verification steps |
| Changes are approved before implementation | Pre-patch checklist sign-off |

## 10. Emergency Patching (Critical CVE)

For Critical CVEs (CVSS 9.0+) outside the maintenance window:

1. **Notify:** Post in Rocket.Chat #security-alerts with CVE details
2. **Assess:** Determine if the CVE affects Helix Stax (check installed packages)
3. **Approve:** Get Wakeem's go-ahead (Rocket.Chat or direct message)
4. **Execute:** Follow the standard patch procedure (Steps 1-7)
5. **Document:** Create GitHub issue with CVE reference and patch evidence
6. **Verify:** Run OpenSCAP scan post-patch

**Do NOT wait for the next maintenance window for Critical CVEs.** The 48-hour SLA is a hard requirement.
