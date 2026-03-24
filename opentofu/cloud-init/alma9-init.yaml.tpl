#cloud-config
# Helix Stax — AlmaLinux 9 bootstrap
#
# Minimal: creates the admin user with SSH access only.
# Ansible handles all hardening after the server is reachable:
#   - SSH hardening (port 2222, key-only, no root)
#   - firewalld configuration
#   - SELinux enforcement
#   - CrowdSec IDS installation
#   - Package installation
#   - K3s installation

users:
  - name: ${admin_user}
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}
