---
title: Ansible K3s Installation Playbook Specification
author: Wakeem Williams
co_author: Kit Morrow
created: 2026-03-23
status: draft
category: automation
tags: [ansible, k3s, kubernetes, installation, hardening, almalinux]
source: gemini-output-server-hardening-security-automation.md
---

# Ansible K3s Installation Playbook Specification

## 1. Overview

This document specifies the Ansible playbook for installing K3s on AlmaLinux 9.7 with security hardening flags enabled from the initial deployment. The playbook handles control plane installation, worker node joining, sysctl prerequisites, and post-install hardening verification.

**Target OS:** AlmaLinux 9.7 (`ansible_os_family == "RedHat"`)

**K3s Configuration:**
- Flannel CNI with WireGuard backend (node-to-node encryption)
- Secrets encryption at rest
- API server audit logging enabled
- Anonymous authentication disabled
- Kernel defaults protection enabled

**Cluster Topology:**
- Control Plane: `helix-stax-cp` (178.156.233.12)
- Worker: `helix-stax-vps` (138.201.131.157)

## 2. Sysctl Prerequisites

K3s requires specific kernel parameters and modules. These MUST be configured before installation.

### Required Kernel Modules

```yaml
- name: Load required kernel modules
  community.general.modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - br_netfilter
    - overlay

- name: Persist kernel modules across reboots
  ansible.builtin.copy:
    dest: /etc/modules-load.d/k3s.conf
    content: |
      br_netfilter
      overlay
    owner: root
    group: root
    mode: "0644"
```

### Required Sysctl Parameters

```yaml
- name: Configure sysctl for K3s
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/99-k3s.conf
    reload: true
    state: present
  loop:
    - { key: "net.ipv4.ip_forward", value: "1" }
    - { key: "net.bridge.bridge-nf-call-iptables", value: "1" }
    - { key: "net.bridge.bridge-nf-call-ip6tables", value: "1" }
```

### Verification

```bash
# Verify modules loaded
lsmod | grep br_netfilter
lsmod | grep overlay

# Verify sysctl
sysctl net.ipv4.ip_forward                  # Expected: 1
sysctl net.bridge.bridge-nf-call-iptables   # Expected: 1
sysctl net.bridge.bridge-nf-call-ip6tables  # Expected: 1
```

## 3. Control Plane Installation

### Install Command with Hardening Flags

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --protect-kernel-defaults \
  --secrets-encryption \
  --flannel-backend=wireguard-native \
  --kube-apiserver-arg='anonymous-auth=false' \
  --kube-apiserver-arg='audit-log-path=/var/log/k3s-audit.log' \
  --kube-apiserver-arg='audit-log-maxage=30' \
  --kube-apiserver-arg='audit-log-maxbackup=10' \
  --kube-apiserver-arg='audit-log-maxsize=100'" sh -
```

### Hardening Flags Explained

| Flag | Purpose | Compliance |
|------|---------|------------|
| `--protect-kernel-defaults` | Fails if sysctl values don't match K3s requirements (prevents silent misconfiguration) | CIS 4.1 |
| `--secrets-encryption` | Encrypts Kubernetes secrets at rest using AES-CBC | SOC 2 CC6.7, HIPAA 164.312(a)(2)(iv) |
| `--flannel-backend=wireguard-native` | Node-to-node encryption for all pod traffic via WireGuard | SOC 2 CC6.7, ISO A.8.24 |
| `--kube-apiserver-arg='anonymous-auth=false'` | Disables unauthenticated API access | CIS 1.2.1, SOC 2 CC6.1 |
| `--kube-apiserver-arg='audit-log-path=...'` | Enables API server audit logging | CIS 1.2.22, SOC 2 CC7.2, ISO A.8.15 |
| `--kube-apiserver-arg='audit-log-maxage=30'` | Retain audit logs for 30 days on disk | SOC 2 CC7.2 |
| `--kube-apiserver-arg='audit-log-maxbackup=10'` | Keep 10 rotated audit log files | SOC 2 CC7.2 |
| `--kube-apiserver-arg='audit-log-maxsize=100'` | Rotate audit logs at 100MB | SOC 2 CC7.2 |

### Ansible Task: Control Plane Install

```yaml
- name: Install K3s Control Plane with hardening flags
  hosts: control_plane
  become: true

  tasks:
    - name: Download K3s install script
      ansible.builtin.get_url:
        url: https://get.k3s.io
        dest: /tmp/k3s-install.sh
        mode: "0755"

    - name: Create K3s audit log directory
      ansible.builtin.file:
        path: /var/log
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Execute K3s server install
      ansible.builtin.shell: |
        /tmp/k3s-install.sh
      environment:
        INSTALL_K3S_EXEC: >-
          server
          --protect-kernel-defaults
          --secrets-encryption
          --flannel-backend=wireguard-native
          --kube-apiserver-arg=anonymous-auth=false
          --kube-apiserver-arg=audit-log-path=/var/log/k3s-audit.log
          --kube-apiserver-arg=audit-log-maxage=30
          --kube-apiserver-arg=audit-log-maxbackup=10
          --kube-apiserver-arg=audit-log-maxsize=100
      args:
        creates: /usr/local/bin/k3s
      register: k3s_install

    - name: Wait for K3s to be ready
      ansible.builtin.command: k3s kubectl get nodes
      register: k3s_ready
      retries: 30
      delay: 10
      until: k3s_ready.rc == 0
      changed_when: false

    - name: Retrieve node token for worker join
      ansible.builtin.slurp:
        src: /var/lib/rancher/k3s/server/node-token
      register: k3s_token

    - name: Store token as fact
      ansible.builtin.set_fact:
        k3s_node_token: "{{ k3s_token.content | b64decode | trim }}"
```

## 4. Worker Node Installation

### Join Command

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://178.156.233.12:6443 \
  K3S_TOKEN=<node-token> \
  INSTALL_K3S_EXEC="agent --protect-kernel-defaults" sh -
```

### Ansible Task: Worker Join

```yaml
- name: Join Worker Node to K3s Cluster
  hosts: workers
  become: true

  tasks:
    - name: Download K3s install script
      ansible.builtin.get_url:
        url: https://get.k3s.io
        dest: /tmp/k3s-install.sh
        mode: "0755"

    - name: Execute K3s agent install
      ansible.builtin.shell: |
        /tmp/k3s-install.sh
      environment:
        K3S_URL: "https://{{ hostvars[groups['control_plane'][0]]['ansible_host'] }}:6443"
        K3S_TOKEN: "{{ hostvars[groups['control_plane'][0]]['k3s_node_token'] }}"
        INSTALL_K3S_EXEC: "agent --protect-kernel-defaults"
      args:
        creates: /usr/local/bin/k3s
      register: k3s_agent_install

    - name: Wait for agent to register with cluster
      ansible.builtin.command: >
        k3s kubectl get node {{ inventory_hostname }}
      delegate_to: "{{ groups['control_plane'][0] }}"
      register: worker_ready
      retries: 30
      delay: 10
      until: worker_ready.rc == 0
      changed_when: false
```

## 5. Post-Install Hardening Tasks

These tasks run after K3s installation to lock down file permissions and verify security features.

### 5.1 TLS Certificate Permissions

```yaml
- name: Restrict TLS certificate permissions (CP only)
  hosts: control_plane
  become: true

  tasks:
    - name: Find K3s TLS certificates
      ansible.builtin.find:
        paths: /var/lib/rancher/k3s/server/tls
        patterns: "*.crt"
      register: tls_certs

    - name: Set certificates to 600
      ansible.builtin.file:
        path: "{{ item.path }}"
        mode: "0600"
        owner: root
        group: root
      loop: "{{ tls_certs.files }}"
      loop_control:
        label: "{{ item.path | basename }}"

    - name: Find K3s TLS keys
      ansible.builtin.find:
        paths: /var/lib/rancher/k3s/server/tls
        patterns: "*.key"
      register: tls_keys

    - name: Set keys to 600
      ansible.builtin.file:
        path: "{{ item.path }}"
        mode: "0600"
        owner: root
        group: root
      loop: "{{ tls_keys.files }}"
      loop_control:
        label: "{{ item.path | basename }}"
```

### 5.2 Verify Audit Logging

```yaml
- name: Verify API server audit logging is active
  hosts: control_plane
  become: true

  tasks:
    - name: Check audit log file exists
      ansible.builtin.stat:
        path: /var/log/k3s-audit.log
      register: audit_log

    - name: Fail if audit log not created
      ansible.builtin.fail:
        msg: >
          Audit log file /var/log/k3s-audit.log does not exist.
          K3s API server audit logging may not be configured correctly.
      when: not audit_log.stat.exists

    - name: Verify audit log is being written to
      ansible.builtin.command: wc -l /var/log/k3s-audit.log
      register: audit_log_lines
      changed_when: false
      failed_when: audit_log_lines.stdout.split()[0] | int == 0
```

### 5.3 Verify WireGuard Encryption

```yaml
- name: Verify WireGuard encryption is active
  hosts: k3s_cluster
  become: true

  tasks:
    - name: Check WireGuard kernel module loaded
      community.general.modprobe:
        name: wireguard
        state: present
      check_mode: true
      register: wg_module

    - name: Verify WireGuard interface exists
      ansible.builtin.command: ip link show flannel-wg
      register: wg_interface
      changed_when: false
      failed_when: wg_interface.rc != 0

    - name: Display WireGuard peer information
      ansible.builtin.command: wg show
      register: wg_status
      changed_when: false

    - name: Fail if no WireGuard peers
      ansible.builtin.fail:
        msg: "WireGuard has no peers configured. Flannel WireGuard backend may not be functioning."
      when: "'peer' not in wg_status.stdout"
```

### 5.4 Run kube-bench

```yaml
- name: Run CIS Kubernetes Benchmark (kube-bench)
  hosts: control_plane
  become: true

  tasks:
    - name: Download kube-bench
      ansible.builtin.get_url:
        url: https://github.com/aquasecurity/kube-bench/releases/download/v0.8.0/kube-bench_0.8.0_linux_amd64.rpm
        dest: /tmp/kube-bench.rpm
        mode: "0644"

    - name: Install kube-bench
      ansible.builtin.dnf:
        name: /tmp/kube-bench.rpm
        state: present
        disable_gpg_check: true

    - name: Run kube-bench for K3s
      ansible.builtin.command: >
        kube-bench run --config-dir /etc/kube-bench/cfg
        --benchmark k3s-cis-1.24
        --json
      register: kube_bench_output
      changed_when: false
      ignore_errors: true

    - name: Save kube-bench results
      ansible.builtin.copy:
        content: "{{ kube_bench_output.stdout }}"
        dest: "/var/log/compliance/kube-bench-{{ ansible_date_time.date }}.json"
        owner: root
        group: root
        mode: "0600"

    - name: Archive kube-bench results to MinIO
      ansible.builtin.command: >
        mc cp "/var/log/compliance/kube-bench-{{ ansible_date_time.date }}.json"
        helix-minio/compliance-evidence/kube-bench/
      changed_when: true
```

## 6. Combined Playbook

### playbooks/k3s-install.yml

```yaml
---
# ==============================================================================
# K3s Installation Playbook -- AlmaLinux 9.7
# Installs K3s with hardening flags, joins workers, hardens post-install.
# ==============================================================================

- name: "Phase 1: Sysctl Prerequisites (All Nodes)"
  hosts: k3s_cluster
  become: true
  tasks:
    - name: Load br_netfilter module
      community.general.modprobe:
        name: br_netfilter
        state: present

    - name: Load overlay module
      community.general.modprobe:
        name: overlay
        state: present

    - name: Persist kernel modules
      ansible.builtin.copy:
        dest: /etc/modules-load.d/k3s.conf
        content: |
          br_netfilter
          overlay
        owner: root
        group: root
        mode: "0644"

    - name: Configure sysctl for K3s
      ansible.posix.sysctl:
        name: "{{ item.key }}"
        value: "{{ item.value }}"
        sysctl_file: /etc/sysctl.d/99-k3s.conf
        reload: true
        state: present
      loop:
        - { key: "net.ipv4.ip_forward", value: "1" }
        - { key: "net.bridge.bridge-nf-call-iptables", value: "1" }
        - { key: "net.bridge.bridge-nf-call-ip6tables", value: "1" }

    - name: Install WireGuard tools
      ansible.builtin.dnf:
        name: wireguard-tools
        state: present

- name: "Phase 2: Install K3s Control Plane"
  hosts: control_plane
  become: true
  tasks:
    - name: Create audit log directory
      ansible.builtin.file:
        path: /var/log
        state: directory
        mode: "0755"

    - name: Download K3s install script
      ansible.builtin.get_url:
        url: https://get.k3s.io
        dest: /tmp/k3s-install.sh
        mode: "0755"

    - name: Install K3s server with hardening flags
      ansible.builtin.shell: /tmp/k3s-install.sh
      environment:
        INSTALL_K3S_EXEC: >-
          server
          --protect-kernel-defaults
          --secrets-encryption
          --flannel-backend=wireguard-native
          --kube-apiserver-arg=anonymous-auth=false
          --kube-apiserver-arg=audit-log-path=/var/log/k3s-audit.log
          --kube-apiserver-arg=audit-log-maxage=30
          --kube-apiserver-arg=audit-log-maxbackup=10
          --kube-apiserver-arg=audit-log-maxsize=100
      args:
        creates: /usr/local/bin/k3s

    - name: Wait for K3s API server
      ansible.builtin.command: k3s kubectl get nodes
      register: k3s_ready
      retries: 30
      delay: 10
      until: k3s_ready.rc == 0
      changed_when: false

    - name: Retrieve node token
      ansible.builtin.slurp:
        src: /var/lib/rancher/k3s/server/node-token
      register: k3s_token

    - name: Store token as fact
      ansible.builtin.set_fact:
        k3s_node_token: "{{ k3s_token.content | b64decode | trim }}"

- name: "Phase 3: Join Worker Nodes"
  hosts: workers
  become: true
  tasks:
    - name: Download K3s install script
      ansible.builtin.get_url:
        url: https://get.k3s.io
        dest: /tmp/k3s-install.sh
        mode: "0755"

    - name: Join worker to cluster
      ansible.builtin.shell: /tmp/k3s-install.sh
      environment:
        K3S_URL: "https://{{ hostvars[groups['control_plane'][0]]['ansible_host'] }}:6443"
        K3S_TOKEN: "{{ hostvars[groups['control_plane'][0]]['k3s_node_token'] }}"
        INSTALL_K3S_EXEC: "agent --protect-kernel-defaults"
      args:
        creates: /usr/local/bin/k3s

- name: "Phase 4: Post-Install Hardening"
  hosts: control_plane
  become: true
  tasks:
    - name: Find TLS certificates
      ansible.builtin.find:
        paths: /var/lib/rancher/k3s/server/tls
        patterns: "*.crt,*.key"
      register: tls_files

    - name: Restrict TLS file permissions to 600
      ansible.builtin.file:
        path: "{{ item.path }}"
        mode: "0600"
        owner: root
        group: root
      loop: "{{ tls_files.files }}"
      loop_control:
        label: "{{ item.path | basename }}"

    - name: Verify audit log exists and is active
      ansible.builtin.stat:
        path: /var/log/k3s-audit.log
      register: audit_log
      failed_when: not audit_log.stat.exists

- name: "Phase 5: Verify WireGuard Encryption (All Nodes)"
  hosts: k3s_cluster
  become: true
  tasks:
    - name: Verify WireGuard module loaded
      ansible.builtin.command: lsmod | grep wireguard
      register: wg_check
      changed_when: false
      failed_when: wg_check.rc != 0

    - name: Display WireGuard status
      ansible.builtin.command: wg show
      register: wg_status
      changed_when: false

    - name: Assert WireGuard has peers
      ansible.builtin.assert:
        that: "'peer' in wg_status.stdout"
        fail_msg: "WireGuard has no peers. Flannel WireGuard backend may not be functioning."

## 7. Smoke Tests

After installation, run these smoke tests to verify cluster health.

### 7.1 Node Status

```bash
# All nodes must be Ready
kubectl get nodes -o wide
# Expected:
# NAME             STATUS   ROLES                  AGE   VERSION
# helix-stax-cp    Ready    control-plane,master   Xm    v1.xx.x+k3s1
# helix-stax-vps   Ready    <none>                 Xm    v1.xx.x+k3s1
```

### 7.2 Pod Scheduling

```yaml
- name: "Smoke Test: Deploy test pod"
  hosts: control_plane
  become: true
  tasks:
    - name: Create test deployment
      ansible.builtin.command: >
        k3s kubectl run smoke-test
        --image=busybox
        --restart=Never
        --command -- sleep 30
      changed_when: true

    - name: Wait for pod to be running
      ansible.builtin.command: >
        k3s kubectl get pod smoke-test -o jsonpath='{.status.phase}'
      register: pod_status
      retries: 12
      delay: 5
      until: pod_status.stdout == "Running"
      changed_when: false

    - name: Clean up test pod
      ansible.builtin.command: k3s kubectl delete pod smoke-test --wait=false
      changed_when: true
```

### 7.3 Inter-Node Pod Communication

```yaml
- name: "Smoke Test: Inter-node pod communication"
  hosts: control_plane
  become: true
  tasks:
    - name: Deploy ping-server on worker
      ansible.builtin.shell: |
        k3s kubectl apply -f - <<'EOF'
        apiVersion: v1
        kind: Pod
        metadata:
          name: ping-server
        spec:
          nodeSelector:
            kubernetes.io/hostname: helix-stax-vps
          containers:
            - name: nginx
              image: nginx:alpine
              ports:
                - containerPort: 80
        EOF
      changed_when: true

    - name: Wait for ping-server
      ansible.builtin.command: >
        k3s kubectl get pod ping-server -o jsonpath='{.status.phase}'
      register: server_status
      retries: 24
      delay: 5
      until: server_status.stdout == "Running"
      changed_when: false

    - name: Get ping-server IP
      ansible.builtin.command: >
        k3s kubectl get pod ping-server -o jsonpath='{.status.podIP}'
      register: server_ip
      changed_when: false

    - name: Deploy ping-client on CP and curl server
      ansible.builtin.shell: |
        k3s kubectl run ping-client \
          --image=curlimages/curl \
          --restart=Never \
          --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"helix-stax-cp"}}}' \
          --command -- curl -s -o /dev/null -w "%{http_code}" http://{{ server_ip.stdout }}
      register: curl_result
      changed_when: true

    - name: Wait for client pod to complete
      ansible.builtin.command: >
        k3s kubectl get pod ping-client -o jsonpath='{.status.phase}'
      register: client_status
      retries: 12
      delay: 5
      until: client_status.stdout in ["Succeeded", "Failed"]
      changed_when: false

    - name: Check client logs
      ansible.builtin.command: k3s kubectl logs ping-client
      register: client_logs
      changed_when: false
      failed_when: "'200' not in client_logs.stdout"

    - name: Clean up test pods
      ansible.builtin.shell: |
        k3s kubectl delete pod ping-server ping-client --wait=false
      changed_when: true
```

### 7.4 Secrets Encryption Verification

```bash
# Verify secrets are encrypted at rest
k3s secrets-encrypt status
# Expected: Encryption Status: Enabled

# Verify encryption config exists
ls -la /var/lib/rancher/k3s/server/cred/encryption-config.json
```

## 8. Rollback Procedure

If K3s installation fails or causes issues:

### Uninstall K3s Server (CP)

```bash
/usr/local/bin/k3s-uninstall.sh
```

### Uninstall K3s Agent (Worker)

```bash
/usr/local/bin/k3s-agent-uninstall.sh
```

### Clean Sysctl (if reverting fully)

```bash
rm -f /etc/sysctl.d/99-k3s.conf
rm -f /etc/modules-load.d/k3s.conf
sysctl --system
```
