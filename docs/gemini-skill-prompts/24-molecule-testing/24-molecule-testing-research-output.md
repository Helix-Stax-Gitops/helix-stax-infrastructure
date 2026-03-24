# Molecule Testing

## SKILL.md Content
### Molecule CLI Quick Reference

The most common commands for a test-driven development loop.

| Command | Action | Use Case |
|---|---|---|
| `molecule test` | Runs the full lifecycle: create, converge, idempotence, verify, destroy. | CI runs, full validation. |
| `molecule test --scenario-name <name>` | Runs the full lifecycle for a specific scenario. | Testing a role variant (e.g., K3s vs. non-K3s). |
| `molecule create` | Creates test instance(s) by running `create.yml`. | Start a fresh test environment. |
| `molecule converge` | Applies the role by running `converge.yml`. | Apply changes, iterate on the role. |
| `molecule idempotence` | Runs `converge.yml` again and fails if any tasks report `changed`. | The most important quality check. |
| `molecule verify` | Runs `verify.yml` to check the system's state. | Assert that the role produced the correct result. |
| `molecule login` | SSH into the test instance. | Manual debugging and inspection. |
| `molecule destroy` | Destroys the test instance(s) by running `destroy.yml`. | Clean up the environment. |

- **Keep instance on failure:** `molecule test --destroy=never`
- **Run a single step:** `molecule converge`
- **Run multiple steps sequentially:** `molecule converge && molecule verify`
- **Increase verbosity:** `molecule test -vvv`

### Delegated Driver Configuration Cheat Sheet

This driver connects to a pre-existing server. Molecule does **not** create or destroy the server itself.

**File: `molecule/default/molecule.yml`**
```yaml
---
driver:
  name: delegated
platforms:
  # The IP is templated from an environment variable
  - name: helix-stax-test
    address: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
    user: wakeem
    port: 2222
provisioner:
  name: ansible
  options:
    # Handle new SSH host keys from ephemeral test servers
    ssh_common_args: "-o StrictHostKeyChecking=accept-new"
  inventory:
    host_vars:
      helix-stax-test:
        ansible_host: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
        ansible_user: wakeem
        ansible_port: 2222
        ansible_ssh_private_key_file: '~/.ssh/id_ed25519' # Local developer key
        # Use python3 on AlmaLinux 9
        ansible_python_interpreter: /usr/bin/python3
verifier:
  name: ansible
lint:
  name: ansible-lint
```

### Ansible Verify Task Patterns

Use these patterns in `verify.yml` to assert system state without writing Python.

**SELinux is Enforcing**
```yaml
- name: Verify SELinux is enforcing
  ansible.builtin.command: getenforce
  register: selinux_status
  changed_when: false
- name: Assert SELinux is enforcing
  ansible.builtin.assert:
    that: selinux_status.stdout == "Enforcing"
    fail_msg: "SELinux is not 'Enforcing', it is '{{ selinux_status.stdout }}'"
```

**SSH Configuration**
```yaml
- name: Check sshd config for PermitRootLogin
  ansible.builtin.command: sshd -T | grep -i '^permitrootlogin'
  register: sshd_root_login
  changed_when: false
- name: Assert PermitRootLogin is no
  ansible.builtin.assert:
    that: sshd_root_login.stdout == "permitrootlogin no"
    success_msg: "PermitRootLogin is correctly set to 'no'."
```

**Firewalld Rules**
```yaml
- name: Get list of open firewalld ports
  ansible.builtin.command: firewall-cmd --list-ports
  register: firewalld_ports
  changed_when: false
- name: Assert SSH port (2222) is open
  ansible.builtin.assert:
    that: "'2222/tcp' in firewalld_ports.stdout.split()"
    fail_msg: "Port 2222/tcp not found in firewalld rules. Open ports: {{ firewalld_ports.stdout }}"
```

**Systemd Service State**
```yaml
- name: Populate service facts
  ansible.builtin.service_facts:
- name: Assert cups service is disabled
  ansible.builtin.assert:
    that: "services['cups.service'].state == 'stopped' and services['cups.service'].status == 'disabled'"
    fail_msg: "cups.service state is '{{ services['cups.service'].state }}' and status is '{{ services['cups.service'].status }}'"
```

**Sysctl Kernel Parameter**
```yaml
- name: Check kernel.randomize_va_space value
  ansible.posix.sysctl:
    name: kernel.randomize_va_space
  register: aslr_status
- name: Assert ASLR is enabled (value is 2)
  ansible.builtin.assert:
    that: aslr_status.value == '2'
```

**File Permissions**
```yaml
- name: Stat /etc/ssh/sshd_config
  ansible.builtin.stat:
    path: /etc/ssh/sshd_config
  register: sshd_config_stat
- name: Assert /etc/ssh/sshd_config has correct permissions
  ansible.builtin.assert:
    that:
      - sshd_config_stat.stat.exists
      - sshd_config_stat.stat.mode == '0600'
      - sshd_config_stat.stat.pw_name == 'root'
      - sshd_config_stat.stat.gr_name == 'root'
```

### Idempotency Debugging

If `molecule idempotence` fails, it means a task reported `changed` on the second run.

1.  Run `molecule converge` twice: `molecule converge && molecule converge`
2.  Inspect the output of the second run. Find the task with `changed`.
3.  **Common Fixes:**
    *   **`command` / `shell`:** Add `changed_when`, `creates`, or `removes` to make the result checkable.
        ```yaml
        - name: Run K3s install script (idempotent)
          ansible.builtin.command: "curl -sfL https://get.k3s.io | sh -"
          args:
            creates: /usr/local/bin/k3s # Don't run if k3s binary exists
          changed_when: false # The script itself doesn't report change state well
        ```
    *   **Templates:** Ensure the `ansible_managed` comment is consistent. Small whitespace changes can cause a `changed` state.
    *   **Handlers:** Ensure the task that notifies a handler only reports `changed` when a file *actually* changes. Diff the before/after state if needed.

### Core Integration Points

-   **Hetzner Server:** Provisioned via OpenTofu. Tofu outputs the IP address.
-   **OpenTofu -> Molecule:** The server IP is passed from Tofu to Molecule via a GitHub Actions environment variable (`HETZNER_TEST_IP`).
-   **GitHub Actions:** Orchestrates the entire flow: `checkout -> setup python -> install deps -> tofu apply -> molecule test -> tofu destroy`.
-   **ansible-lint:** Runs automatically as the `lint` step in `molecule test`. Configure in `.ansible-lint` at the project root.

## reference.md Content
### Complete `molecule.yml` for Delegated Driver

This configuration is the blueprint for our setup. It uses environment variables for dynamic IP injection and configures all necessary components.

**File: `molecule/<scenario-name>/molecule.yml`**
```yaml
---
# Molecule configuration for testing against a pre-existing server (delegated driver).
# This file assumes the test server's IP is provided via the HETZNER_TEST_IP environment variable.

driver:
  # The delegated driver tells Molecule not to manage the lifecycle of the test instance.
  # It delegates creation/destruction to external tools (like OpenTofu or hcloud CLI).
  name: delegated

# The platforms section describes the test instances Molecule will connect to.
platforms:
  - name: helix-stax-test
    # These fields are used by Molecule internally and to generate `instance_config.yml`.
    # They are also used for `molecule login`.
    address: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
    user: wakeem
    port: 2222
    identity_file: "{{ lookup('env', 'HOME') + '/.ssh/id_ed25519' }}"

provisioner:
  # Use Ansible as the provisioner to run the role.
  name: ansible
  # Set environment variables available to Ansible during converge.
  # Useful for passing dynamic configuration into plays/roles.
  env:
    ANSIBLE_COLLECTIONS_PATH: ~/.ansible/collections:../../
  options:
    # Pass extra arguments to ansible-playbook.
    # We use this to automatically accept new SSH host keys from ephemeral test servers.
    ssh_common_args: "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
    # Set a default become method if not specified in the play.
    # become_method: sudo
  # Defines inventory for Ansible. This is separate from `platforms`.
  # This is how you tell Ansible how to connect to the hosts defined in `platforms`.
  inventory:
    host_vars:
      # This key must match a `platforms.name`.
      helix-stax-test:
        # Standard Ansible connection variables.
        ansible_host: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
        ansible_user: "wakeem"
        ansible_port: 2222
        ansible_ssh_private_key_file: "{{ lookup('env', 'HOME') + '/.ssh/id_ed25519' }}"
        # For CI, you might override this with a path to a key provided by a secret.
        # ansible_ssh_private_key_file: "{{ lookup('env', 'SSH_PRIVATE_KEY_PATH') }}"
        # Specify the Python interpreter on the remote host. AlmaLinux 9 uses python3.
        ansible_python_interpreter: /usr/bin/python3

verifier:
  # Use Ansible (assert tasks) for verification.
  name: ansible
  # Path to the linter configuration file.
  # It defaults to <project-root>/.ansible-lint, so this is often not needed.
  lint:
    name: ansible-lint
    options:
      c: .ansible-lint
```

### `create.yml` and `destroy.yml` for Delegated Driver

With the delegated driver, these files can either be stubs (for CI) or include actual provisioning commands (for local development).

#### Minimal Stub Version (for CI)

In CI, OpenTofu handles provisioning. These files just need to inform Molecule of the instance details by creating `instance_config.yml`.

**File: `molecule/default/create.yml`**
```yaml
---
# In CI, the server is created by OpenTofu. This playbook's only job is to
# create the instance_config.yml file that Molecule needs to connect.
- name: Create
  hosts: localhost
  gather_facts: false
  tasks:
    # The delegated driver requires this file to exist.
    # It reads connection details from `platforms` in molecule.yml and writes them here.
    - name: Write instance config
      ansible.builtin.include_role:
        name: "molecule_instance"
        tasks_from: "create"
```

**File: `molecule/default/destroy.yml`**
```yaml
---
# In CI, the server is destroyed by OpenTofu. This playbook just cleans up
# Molecule's local cache files.
- name: Destroy
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Destroy molecule instance(s)
      ansible.builtin.include_role:
        name: "molecule_instance"
        tasks_from: "destroy"
```

#### Full Version with `hcloud` CLI (for Local Dev)

This allows a developer to create/destroy the test server locally without using OpenTofu.

**File: `molecule/local-dev/create.yml`**
```yaml
---
- name: Create Hetzner test server for local development
  hosts: localhost
  gather_facts: false
  vars:
    server_name: helix-stax-test-local
  tasks:
    - name: Create Hetzner CX22 server
      ansible.builtin.command: >
        hcloud server create --name {{ server_name }} --image almalinux-9 --type cx22
      register: hcloud_create
      changed_when: true

    - name: Parse server IP from JSON output
      ansible.builtin.set_fact:
        server_ip: "{{ (hcloud_create.stdout | from_json).server.public_net.ipv4.ip }}"

    # This is critical: Update the `HETZNER_TEST_IP` env var for subsequent Molecule steps.
    - name: Set environment variable for Molecule
      ansible.builtin.set_fact:
        molecule_environment:
          HETZNER_TEST_IP: "{{ server_ip }}"

    - name: Wait for SSH to be available
      ansible.builtin.wait_for:
        host: "{{ server_ip }}"
        port: 22
        delay: 10
        timeout: 180

    # This task creates instance_config.yml using the IP we just got.
    - name: Write instance config
      ansible.builtin.include_role:
        name: "molecule_instance"
        tasks_from: "create"
```

### Format of `instance_config.yml`

This file is automatically generated during the `create` step and is read by subsequent Molecule steps. It is located in `~/.cache/molecule/<role>/<scenario>/instance_config.yml`. You should not edit it manually.

```yaml
# ~/.cache/molecule/my-role/default/instance_config.yml
---
# This file is managed by Molecule.
# The content is generated from the `platforms` section of molecule.yml
instance: helix-stax-test # The `name` from platforms
address: 192.0.2.100      # Resolved IP address
user: wakeem
port: 2222
identity_file: /home/user/.ssh/id_ed25519
# Optional fields if set:
become_method: sudo
become_pass: ...
```

### Complete `verify.yml` Template for CIS Hardening

This playbook includes multiple verification blocks. Using `block/rescue/always` ensures all tests run and failures are aggregated.

**File: `molecule/default/verify.yml`**
```yaml
---
- name: Verify
  hosts: all
  become: true
  gather_facts: false
  vars:
    failed_assertions: []
  tasks:
    - name: "BLOCK: Run all verification tasks"
      block:
        - name: Include SELinux verification
          ansible.builtin.include_tasks: "verify_selinux.yml"
        - name: Include SSHD verification
          ansible.builtin.include_tasks: "verify_sshd.yml"
        - name: Include Firewalld verification
          ansible.builtin.include_tasks: "verify_firewalld.yml"
        - name: Include Sysctl verification
          ansible.builtin.include_tasks: "verify_sysctl.yml"
        - name: Include Service state verification
          ansible.builtin.include_tasks: "verify_services.yml"
        - name: Include File permission verification
          ansible.builtin.include_tasks: "verify_files.yml"

      rescue:
        - name: Record assertion failure
          ansible.builtin.set_fact:
            failed_assertions: "{{ failed_assertions + [ansible_failed_result] }}"
          # You can add more debugging info here if needed

      always:
        - name: Report all failures
          ansible.builtin.fail:
            msg: |
              The following {{ failed_assertions | length }} assertions failed:
              {% for failure in failed_assertions %}
              - Task '{{ failure.task }}': {{ failure.msg | default(failure.reason) }}
              {% endfor %}
          when: failed_assertions | length > 0
```
*(Note: Each `verify_*.yml` would contain the specific task patterns shown in the SKILL.md section).*

### Complete `.ansible-lint` Configuration

Place this file in the root of your Ansible project.

**File: `.ansible-lint`**
```yaml
---
# Opt-in to new rules that are not yet default.
enable_list:
  - 'var-spacing'

# These rules are too noisy or not applicable for our infrastructure roles.
skip_list:
  - 'galaxy'                 # We manage collections manually.
  - 'experimental'           # Avoid rules that may change.
  - 'risky-file-permissions' # Hardening roles intentionally set strict permissions.
  - 'fqcn-builtins'          # Using `command` instead of `ansible.builtin.command` is fine.

# Allow specific exceptions, e.g., for the K3s install script.
warn_list:
  # Using command/shell is sometimes necessary. We review these manually.
  - 'command-instead-of-module'
  - 'command-instead-of-shell'
  # The K3s install script uses a pipe. We accept this risk from the official source.
  - 'risky-shell-pipe'

# Enforce YAML formatting rules
yaml:
  line-length: 120
  document-start: true
  indentation: 2

# Linting rules configuration.
rules:
  # Require role names to be in snake_case.
  rolename:
    pattern: '^[a-z_]+$'
```

### GitHub Actions Workflow Template

**File: `.github/workflows/molecule-test.yml`**
```yaml
name: Molecule Test

on:
  push:
    branches: [ "main" ]
    paths:
      - 'ansible/roles/**'
  pull_request:
    paths:
      - 'ansible/roles/**'

jobs:
  test:
    name: "Molecule Test: ${{ matrix.role }}"
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        # Define the roles you want to test.
        # This will create a parallel job for each role.
        role: [ 'cis-hardening', 'k3s-install' ]
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies (Ansible, Molecule, Hetzner CLI)
        run: |
          python -m pip install --upgrade pip
          pip install ansible molecule molecule-plugins ansible-lint
          # Install OpenTofu or Terraform
          # Example for OpenTofu:
          # ...
          # Install Hetzner CLI
          sudo apt-get update && sudo apt-get install -y hcloud-cli

      - name: Provision Hetzner test server with OpenTofu
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
        run: |
          cd terraform # Assuming your Tofu files are in a 'terraform' directory
          tofu init
          tofu apply -auto-approve -var="create_test_server=true"

      - name: Export test server IP to environment
        id: tofu_output
        run: |
          cd terraform
          echo "HETZNER_TEST_IP=$(tofu output -raw test_server_ip)" >> $GITHUB_ENV

      - name: Setup SSH Key
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
        run: |
          mkdir -p ~/.ssh
          echo "${SSH_PRIVATE_KEY}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          # Add public key to known_hosts if needed, but molecule.yml handles it.

      - name: Run Molecule test
        # The working directory should be the parent of the role being tested.
        working-directory: ./ansible/roles/${{ matrix.role }}
        env:
          HETZNER_TEST_IP: ${{ env.HETZNER_TEST_IP }}
        run: molecule test

      - name: Destroy test server (always runs)
        if: always()
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
        run: |
          cd terraform
          tofu destroy -auto-approve -var="create_test_server=true"
```

## examples.md Content
### Real-World Example: `cis-hardening` Role for Helix Stax

This shows the exact files and directory structure for testing our `cis-hardening` role against a temporary Hetzner server.

#### Directory Structure

```
ansible-roles/
└── cis-hardening/
    ├── molecule/
    │   └── default/
    │       ├── converge.yml
    │       ├── create.yml
    │       ├── destroy.yml
    │       ├── molecule.yml
    │       ├── prepare.yml
    │       └── verify.yml
    ├── tasks/
    │   └── main.yml
    └── ... (other role files)
```

#### `molecule/default/molecule.yml`

This file is configured for our specific setup, reading the IP from `HETZNER_TEST_IP`.

```yaml
---
driver:
  name: delegated
platforms:
  - name: helix-stax-test
    address: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
    user: wakeem
    port: 2222
provisioner:
  name: ansible
  options:
    # Handle new SSH keys from ephemeral servers without manual intervention.
    ssh_common_args: "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
  inventory:
    host_vars:
      helix-stax-test:
        ansible_host: "{{ lookup('env', 'HETZNER_TEST_IP') }}"
        ansible_user: "wakeem"
        ansible_port: 2222
        # Use a CI-specific key path, or a dev key path.
        ansible_ssh_private_key_file: "{{ lookup('env', 'SSH_PRIVATE_KEY_PATH', default='~/.ssh/id_ed25519') }}"
        ansible_python_interpreter: /usr/bin/python3
verifier:
  name: ansible
lint:
  name: ansible-lint
```

#### `molecule/default/prepare.yml`

This playbook runs before `converge`. It's perfect for waiting for the server to be ready.

```yaml
---
- name: Prepare
  hosts: all
  gather_facts: false
  become: false # No sudo needed for this
  tasks:
    - name: Wait for SSH connection to become available
      ansible.builtin.wait_for_connection:
        delay: 5
        timeout: 120
      vars:
        # Override connection vars as become isn't used here.
        ansible_user: wakeem
        ansible_port: 2222
```

#### `molecule/default/converge.yml`

This applies the `cis-hardening` role, overriding variables to make it compatible with a K3s node.

```yaml
---
- name: Converge
  hosts: all
  become: true
  # Define vars to skip certain CIS controls that conflict with K3s
  # or are not applicable in a cloud environment.
  vars:
    # Example: K3s requires some modules that CIS might disable.
    cis_skip_k3s_conflicts: true
    # Example: GRUB password isn't applicable on a cloud VM.
    cis_skip_bootloader_password: true
    # Ensure our custom SSH port is configured correctly by the role.
    sshd_port: 2222
  roles:
    - role: ansible-roles-cis-hardening # Assumes role name matches directory
```

#### `molecule/default/verify.yml` (CIS Hardening)

A concrete example asserting the state of a hardened server.

```yaml
---
- name: Verify Hardened State
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Verify SELinux is enforcing
      ansible.builtin.command: getenforce
      register: selinux_status
      changed_when: false

    - name: Assert SELinux is enforcing
      ansible.builtin.assert:
        that: selinux_status.stdout == "Enforcing"
        fail_msg: "SELinux is not enforcing: {{ selinux_status.stdout }}"
        success_msg: "SELinux is correctly enforcing."

    - name: Check sshd config for our specific port and settings
      ansible.builtin.command: sshd -T
      register: sshd_config
      changed_when: false

    - name: Assert SSH daemon settings
      ansible.builtin.assert:
        that:
          - "'port 2222' in sshd_config.stdout_lines"
          - "'permitrootlogin no' in sshd_config.stdout_lines"
          - "'passwordauthentication no' in sshd_config.stdout_lines"
        fail_msg: "SSHD configuration is not compliant."
        success_msg: "SSHD configuration is hardened as expected."

    - name: Check firewalld for allowed services
      ansible.builtin.command: firewall-cmd --list-services
      register: fw_services
      changed_when: false

    - name: Assert only ssh is listed as an allowed service
      ansible.builtin.assert:
        that: fw_services.stdout == "ssh " # Note the trailing space
        fail_msg: "Firewalld allowed services are incorrect: {{ fw_services.stdout }}"
        success_msg: "Firewalld correctly allows only 'ssh' service."

    - name: Check if CUPS service is disabled
      ansible.builtin.systemd:
        name: cups.service
      register: cups_service
      ignore_errors: true # Service might not exist, which is a pass

    - name: Assert CUPS is not active
      ansible.builtin.assert:
        that: not cups_service.status.ActiveState == 'active'
        fail_msg: "CUPS service is still active."
        success_msg: "CUPS service is correctly disabled."
```

#### `molecule/default/verify.yml` (K3s Install Role)

A different `verify.yml` for testing our K3s installation role.

```yaml
---
- name: Verify K3s Installation
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Verify k3s service is active and running
      ansible.builtin.service_facts:
      register: service_state

    - name: Assert K3s service is running
      ansible.builtin.assert:
        that: "service_state.ansible_facts.services['k3s.service'].state == 'running'"
        fail_msg: "K3s service is not running."
        success_msg: "K3s service is active."

    - name: Wait a moment for node to become ready
      ansible.builtin.pause:
        seconds: 15

    - name: Check node status with k3s kubectl
      ansible.builtin.command: /usr/local/bin/k3s kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'
      register: node_status
      changed_when: false

    - name: Assert node is in Ready state
      ansible.builtin.assert:
        that: node_status.stdout == "True"
        fail_msg: "K3s node is not in 'Ready' state. Current state: {{ node_status.stdout }}"
        success_msg: "K3s node is Ready."

    - name: Check core pods (flannel, coredns) are running
      ansible.builtin.command: /usr/local/bin/k3s kubectl get pods -n kube-system --field-selector=status.phase=Running
      register: running_pods
      changed_when: false

    - name: Assert core pods are present
      ansible.builtin.assert:
        that:
          - "'coredns' in running_pods.stdout"
          - "'flannel' in running_pods.stdout"
        fail_msg: "Core system pods are not in Running state."
        success_msg: "CoreDNS and Flannel pods are running."
```

### Shell Script: Cleanup Orphaned Test Servers

This script uses the `hcloud` CLI and `jq` to find and delete test servers older than 2 hours, preventing cost overruns from failed CI jobs. It relies on servers being created with the label `purpose=molecule-test`.

**File: `scripts/cleanup-orphaned-test-servers.sh`**
```bash
#!/bin/bash

set -euo pipefail

# Find servers with the label 'purpose=molecule-test'
# Filter for servers created more than 2 hours ago
# Get their IDs and delete them.

# Current time in Unix timestamp
NOW=$(date +%s)
# 2 hours in seconds
TWO_HOURS_AGO=$((NOW - 7200))

echo "Searching for orphaned test servers (older than 2 hours)..."

# Get servers, filter by label, parse JSON. Use jq to filter by creation time and get ID.
SERVER_IDS_TO_DELETE=$(hcloud server list --selector purpose=molecule-test -o json | \
  jq -r --argjson cutoff "$TWO_HOURS_AGO" \
  '.[] | select((.created | fromdateiso8601) < $cutoff) | .id')

if [ -z "$SERVER_IDS_TO_DELETE" ]; then
  echo "No orphaned test servers found."
  exit 0
fi

echo "Found the following orphaned server IDs to delete:"
echo "$SERVER_IDS_TO_DELETE"
echo ""

# xargs will feed the IDs one by one to hcloud server delete
# The --no-header is optional but cleaner for script output
echo "$SERVER_IDS_TO_DELETE" | xargs -n1 hcloud server delete

echo "Cleanup complete."
```
