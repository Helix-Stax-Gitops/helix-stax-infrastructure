# Gemini Deep Research: Molecule Testing for Ansible Roles — Delegated Driver

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

Molecule is the standard testing framework for Ansible roles. It provides a lifecycle for testing roles: creating a test instance, running the role (converge), verifying the role produced the correct state, and destroying the instance. The result is automated, repeatable proof that an Ansible role works correctly before it is used against production infrastructure.

Most Molecule tutorials show Docker as the test driver — you run a container, converge, verify, destroy. But Docker containers are not real servers. They cannot accurately test:
- SELinux enforcing mode
- Firewalld rules
- systemd services
- Kernel parameters (sysctl)
- K3s installation
- CrowdSec installation

For Helix Stax, we test against **real servers** — specifically, a temporary Hetzner Cloud cx22 instance (`helix-stax-test`) that is provisioned by OpenTofu, used as the Molecule test target, then destroyed. This "delegated driver" pattern means Molecule connects via SSH to a pre-existing server rather than creating its own container or VM.

Understanding the full Molecule lifecycle with the delegated driver, how to write effective verify tasks, and how to integrate into CI with real Hetzner servers is essential for confident infrastructure automation.

## Our Specific Setup

- **Molecule version**: Latest stable (molecule 6.x / molecule-plugins)
- **Driver**: `delegated` (SSH to pre-existing server — NOT Docker, NOT Vagrant, NOT EC2)
- **Test target**: helix-stax-test (Hetzner Cloud cx22, temporary, provisioned by OpenTofu)
- **OS on test server**: AlmaLinux 9.7 (matching production)
- **SSH port**: 2222 (non-standard — must be reflected in Molecule inventory)
- **Admin user**: `wakeem`
- **Ansible version**: Latest stable (2.16+)
- **Roles under test**: CIS hardening role, K3s install role, CrowdSec role, firewalld role
- **Verification strategy**: Ansible assert tasks (NOT Testinfra/Python) — agents write Ansible, not Python test code
- **CI**: GitHub Actions with a real Hetzner test server (provisioned and destroyed per run)
- **Idempotency**: Every role must pass the idempotence check (zero changed tasks on second converge run)

---

## What I Need Researched

---

### MOL-1. Molecule Architecture and Lifecycle

Explain the full Molecule architecture so an Ansible author understands what they're controlling:

**Core concepts:**
- Molecule scenario: what a scenario is, where it lives in a role's directory structure (`molecule/<scenario-name>/`)
- Default scenario: what happens when you run `molecule test` without specifying a scenario
- Multiple scenarios: testing the same role with different configurations (e.g., `molecule/default/` for standard test, `molecule/cilium/` for K3s+Cilium variant)
- Molecule configuration files: `molecule.yml`, `converge.yml`, `verify.yml`, `create.yml`, `destroy.yml`, `prepare.yml`

**Full test lifecycle (in order):**
1. `dependency` — install Ansible Galaxy dependencies listed in `requirements.yml`
2. `lint` — run `ansible-lint` on the role
3. `cleanup` (pre-create) — clean up any leftover state from previous failed runs
4. `destroy` — destroy any existing test instances (idempotent — safe to run even if nothing exists)
5. `syntax` — `ansible-playbook --syntax-check` on converge.yml
6. `create` — provision the test instance (with delegated driver: this is a no-op or pre-checks)
7. `prepare` — run prepare.yml (optional: install Python, set up pre-conditions)
8. `converge` — run the role under test against the instance
9. `idempotence` — run converge again, assert zero changed tasks
10. `side_effect` — optional: trigger state changes to test role's response
11. `verify` — run verify.yml to assert post-converge state
12. `cleanup` (post-verify) — optional cleanup
13. `destroy` — destroy test instances

**Selective execution:**
- Running only specific steps: `molecule converge`, `molecule verify`, `molecule idempotence`
- Skipping steps: `MOLECULE_NO_LOG`, `--destroy=never` to keep instance after failure
- Running a single scenario: `molecule test --scenario-name cilium`

---

### MOL-2. Delegated Driver Configuration

The delegated driver is the key to our pattern. Document it exhaustively:

**What "delegated" means:**
- With delegated driver, Molecule does NOT create or destroy instances itself
- Molecule expects the instance to already exist and be SSH-accessible
- `create.yml` and `destroy.yml` are either empty or contain our own OpenTofu/hcloud commands
- The `molecule.yml` `platforms` section describes the pre-existing instance(s)

**molecule.yml for delegated driver:**
```yaml
driver:
  name: delegated

platforms:
  - name: helix-stax-test
    address: <IP>  # filled by CI from OpenTofu output
    user: wakeem
    port: 2222
    identity_file: ~/.ssh/id_ed25519

provisioner:
  name: ansible
  inventory:
    host_vars:
      helix-stax-test:
        ansible_host: <IP>
        ansible_user: wakeem
        ansible_port: 2222
        ansible_ssh_private_key_file: ~/.ssh/id_ed25519
        ansible_python_interpreter: /usr/bin/python3
```

Provide the complete `molecule.yml` configuration for our setup with:
- All required fields for delegated driver
- SSH configuration matching our setup (port 2222, user wakeem)
- How to pass the test server IP dynamically (from OpenTofu output or environment variable)
- `provisioner.inventory` configuration for direct SSH without an inventory file
- `provisioner.env` for passing Ansible environment variables
- `verifier.name: ansible` (using Ansible tasks for verification, not Testinfra)
- `lint.name: ansible-lint` configuration

**create.yml for delegated driver:**
- With delegated driver, `create.yml` can be a stub (just write a `localhost_data` file) OR call `hcloud server create`
- What the delegated driver expects from `create.yml`: writing to `~/.cache/molecule/<role>/<scenario>/instance_config.yml`
- `instance_config.yml` format: what fields Molecule reads from it (instance, address, user, port, identity_file, become_method, become_pass)
- Minimal `create.yml` stub when server already exists (provisioned by OpenTofu in CI)
- Full `create.yml` that calls `hcloud` CLI to create a server (for local developer use)

**destroy.yml for delegated driver:**
- Minimal stub for CI (OpenTofu destroys the server, Molecule just cleans up cache)
- Full `destroy.yml` that calls `hcloud server delete` (for local developer use)

---

### MOL-3. Using Hetzner Test Server as Molecule Target

Our test pattern:

1. OpenTofu provisions `helix-stax-test` (cx22, AlmaLinux 9.7) in CI
2. OpenTofu outputs the server IP
3. Molecule reads the IP and connects via SSH
4. Molecule runs the role
5. Molecule verifies
6. OpenTofu destroys `helix-stax-test`

Document:
- How to pass the Hetzner server IP from OpenTofu output to Molecule (environment variable pattern)
- Molecule inventory templating: using `{{ lookup('env', 'HETZNER_TEST_IP') }}` in molecule.yml
- Alternatively: writing an `instance_config.yml` file from OpenTofu `local_file` resource that Molecule reads
- SSH known_hosts: how to handle the case where the test server's SSH host key is new (add to known_hosts, or `StrictHostKeyChecking=accept-new`)
- Wait for SSH to become available: Molecule `prepare.yml` with `wait_for_connection` task
- Pre-install Python on AlmaLinux 9: does AlmaLinux 9 cloud image have Python 3 pre-installed? If not, `prepare.yml` bootstraps it.

**Hetzner Cloud driver (alternative):**
- Is there a `molecule-hetznercloud` driver plugin? If yes: version, installation, configuration
- Does it support AlmaLinux 9 images?
- How does it compare to the delegated driver for our use case?
- Recommendation: delegated vs molecule-hetznercloud — which should we use?

---

### MOL-4. converge.yml — Running the Role Under Test

`converge.yml` is the playbook that applies the role to the test instance:

**Standard converge.yml structure:**
```yaml
---
- name: Converge
  hosts: all
  become: true
  roles:
    - role: <role_name>
      vars:
        <override_vars>
```

Document:
- When to use `become: true` in converge.yml (almost always for infrastructure roles)
- Passing role variables to override defaults for testing (e.g., disabling certain CIS controls that conflict with test environment)
- Testing roles that have dependencies: how to include dependent roles in converge.yml
- Pre-tasks in converge.yml: tasks that must run before the role (e.g., ensure dnf cache is fresh)
- Post-tasks: assertions that should run as part of converge (vs verify.yml)
- Running only specific tags: `molecule converge -- --tags ssh_hardening` for faster iteration

**Testing our CIS hardening role:**
- Which CIS controls to skip in test (molecule test server doesn't need GRUB password)
- Variable overrides for test environment (different SSH port in test? same port 2222)
- How to test K3s-conflicting controls safely: does the test server have K3s installed? Or test hardening standalone?

---

### MOL-5. verify.yml — Writing Assertions

`verify.yml` is where we assert the role produced the correct state. We use Ansible tasks (not Testinfra) for verification:

**Ansible verification patterns:**

For each category of controls in our roles, provide Ansible assert tasks:

**SELinux verification:**
```yaml
- name: Verify SELinux is enforcing
  ansible.builtin.command: getenforce
  register: selinux_status
  changed_when: false

- name: Assert SELinux is enforcing
  ansible.builtin.assert:
    that:
      - selinux_status.stdout == "Enforcing"
    fail_msg: "SELinux is not enforcing: {{ selinux_status.stdout }}"
```

**SSH hardening verification:**
- Checking `sshd_config` values: `sshd -T | grep <directive>`
- Using `ansible.builtin.command` + `register` + `assert` pattern
- Checking SSH port is 2222
- Verifying PermitRootLogin is "no"

**Firewalld verification:**
- `firewall-cmd --list-ports` expected output
- `firewall-cmd --list-services` expected output
- Asserting specific ports are open

**Sysctl verification:**
- `sysctl net.ipv4.ip_forward` — asserting value
- `sysctl kernel.randomize_va_space` — asserting ASLR is enabled

**Service disabling verification:**
- Asserting `cups.service` is not running and not enabled: `systemctl is-enabled cups` returns `disabled` or `not-found`
- `ansible.builtin.service_facts` module: how to use it to assert service states

**File permission verification:**
- Asserting `/etc/ssh/sshd_config` is 0600 owned by root
- `ansible.builtin.stat` module + assert

**K3s verification (for k3s-install role):**
- K3s service is running: `systemctl is-active k3s`
- kubectl works: `k3s kubectl get nodes` returns node in Ready state
- Flannel pod is running: `k3s kubectl get pods -n kube-system` includes Flannel

**Complete verify.yml patterns:**
- How to structure verify.yml as a proper Ansible play
- Using `ansible.builtin.assert` with `success_msg` and `fail_msg` for clear output
- Using `block/rescue` to capture all failures rather than stopping at first failure
- Goss as an alternative to Ansible verify tasks: what it is, how to integrate with Molecule, pros/cons vs Ansible tasks

---

### MOL-6. Idempotence Testing

The idempotence check is the most important quality gate for Ansible roles:

**What Molecule checks:**
- Runs converge.yml a second time
- Counts tasks with `changed` status
- Fails if any tasks report `changed` (they should all be `ok` on second run)

**Common idempotency failures and fixes:**
- `command:` or `shell:` tasks always reporting changed — fix: `changed_when: false` or `creates:`/`removes:`
- Template tasks reporting changed due to whitespace differences — fix: use `ansible.builtin.template` with correct `ansible_managed` comment
- Service tasks that restart due to handler firing every time — fix: handlers should only notify when config actually changed
- `dnf install` tasks — are they idempotent? (Yes — `dnf` module is idempotent by default)
- `sysctl` tasks — are they idempotent? (Yes — `ansible.posix.sysctl` checks current value)
- SELinux boolean tasks — are they idempotent? (Yes — `community.general.seboolean` checks current value)
- `lineinfile` tasks that append vs replace — common source of idempotency bugs

**Idempotence for K3s install:**
- The K3s install script: if run twice, does it report changed? How to make it idempotent.
- Using `stat /usr/local/bin/k3s` as a pre-check before running the install script
- `ansible.builtin.stat` + `when: not k3s_binary.stat.exists` pattern

---

### MOL-7. Testing CIS Hardening Role

Specific guidance for testing our CIS hardening Ansible role with Molecule:

**Test scenarios to define:**
1. `default`: Full CIS Level 1 hardening test on a fresh AlmaLinux 9.7 VM
2. `k3s-node`: CIS hardening with K3s exceptions enabled (some controls skipped/modified)
3. `minimal`: Only SSH hardening and firewalld — fastest test for iterating on those controls

**What the test server state should be:**
- Fresh AlmaLinux 9.7 with cloud-init from Hetzner — what packages are pre-installed?
- Does the Hetzner AlmaLinux 9 image have SELinux enforcing by default? (Critical — confirm this)
- Does it have `firewalld` installed and running by default?
- Python 3.x version pre-installed? (`python3 --version`)
- Any cloud-init scripts from Hetzner that might conflict with hardening?

**Controls that need special handling in test:**
- GRUB password (1.4.x): not testable on cloud VMs — skip with `when` condition or test-override variable
- Physical media controls: not applicable — skip
- `/tmp` remounting: may require a reboot in test — how to handle reboots in Molecule (delegated driver)
- Reboot handling in Molecule: after applying a control that requires reboot (e.g., SELinux mode change), how to wait for the server to come back up

**Reboot-safe testing:**
- Using `ansible.builtin.reboot` module in converge.yml when a reboot is triggered
- Molecule's `wait_for_connection` after reboot
- Delegated driver and reboots: does Molecule handle SSH reconnection automatically after reboot?

---

### MOL-8. CI Integration with GitHub Actions

Running Molecule tests in GitHub Actions against a real Hetzner server:

**Workflow structure:**
```yaml
name: Molecule Test
on:
  push:
    paths:
      - 'ansible/roles/**'
  pull_request:
    paths:
      - 'ansible/roles/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install Molecule and dependencies
        run: pip install molecule molecule-plugins ansible-lint
      - name: Provision test server
        run: tofu apply -auto-approve -var="create_test_server=true"
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
      - name: Get test server IP
        run: echo "HETZNER_TEST_IP=$(tofu output -raw test_server_ip)" >> $GITHUB_ENV
      - name: Run Molecule
        run: molecule test
        env:
          HETZNER_TEST_IP: ${{ env.HETZNER_TEST_IP }}
      - name: Destroy test server (always run)
        if: always()
        run: tofu destroy -auto-approve -var="create_test_server=true"
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
```

Document:
- The `if: always()` pattern for destroy step — ensuring cleanup even on failure
- Secrets needed in GitHub Actions: `HCLOUD_TOKEN`, SSH private key
- SSH private key in CI: generating a CI-specific key pair, adding public key to Hetzner via OpenTofu, injecting private key in Actions
- Matrix testing: running the same Molecule scenario against multiple AlmaLinux versions or K3s versions
- Caching Python packages in GitHub Actions to speed up `pip install`
- Parallelizing Molecule scenarios in CI: separate jobs for each scenario
- Preventing concurrent CI runs from interfering (if two PRs both provision test servers at once)
- Cost consideration: cx22 is ~$3.30/month — cost per CI run is minimal (~$0.005/hour), but define max run time

**Testing multiple roles:**
- How to structure the repo so each role's molecule tests run only when that role changes
- Using `paths` filter in GitHub Actions to trigger per-role
- Parallel jobs for multiple roles: `strategy.matrix` with role names

---

### MOL-9. Parallel Molecule Scenarios

Running multiple Molecule scenarios simultaneously for faster feedback:

- Molecule `--parallel` flag: running all scenarios in parallel
- Process isolation: each scenario gets its own tmpdir — no conflicts
- When parallel testing breaks: scenarios that share state (e.g., both installing K3s on the same server)
- Recommended: parallel scenarios only if each has its own test server
- Using GitHub Actions matrix for true parallel CI runs

---

### MOL-10. ansible-lint Integration

Molecule runs `ansible-lint` as the first step. Document:

- `.ansible-lint` configuration file: location, key settings
- `warn_list` vs `skip_list`: which rules to skip for infrastructure roles
- Rules commonly triggered by hardening roles:
  - `no-free-form`: shell module usage in K3s install (must use `cmd:`)
  - `command-instead-of-module`: using `command: sysctl -w` instead of `ansible.posix.sysctl`
  - `risky-shell-pipe`: K3s install script with `curl | sh`
  - `galaxy`: role metadata warnings
- How to mark a task as intentionally non-module with `# noqa` comments
- `ansible-lint --fix`: auto-remediation of common lint issues
- Pre-commit hooks: integrating `ansible-lint` as a pre-commit hook alongside `molecule test`

---

### MOL-11. Debugging Failed Molecule Runs

What to do when `molecule test` fails:

**Keeping the instance alive after failure:**
- `molecule test --destroy=never`: keeps the test server running for manual investigation
- `molecule login`: SSH into the test instance from Molecule
- With delegated driver: just SSH directly with `ssh -p 2222 wakeem@<IP>`

**Reading Molecule output:**
- Verbose mode: `molecule test -vvv` for full Ansible output
- Which file in `~/.cache/molecule/` contains state
- Understanding the task output format during idempotence check

**Common failure categories:**
- Connection refused: firewalld blocking SSH during hardening (hardening role locks out Molecule)
  - How to avoid: always add Molecule control node's IP to SSH allowlist before hardening
- AVC denial during K3s install: how to extract from Molecule output
- Idempotence failure: how to identify which task is always-changed in Molecule output
- Python not found: `ansible_python_interpreter` not set correctly
- Privilege escalation failure: `become: true` not configured

**The "locked out" scenario:**
If the hardening role sets `AllowUsers wakeem` and the Ansible connection user is different, Molecule is locked out. Prevention strategy: ensure Ansible and Molecule always connect as `wakeem`.

---

### MOL-12. Molecule destroy — Cleanup and Test Isolation

Ensuring test servers are properly cleaned up:

- `molecule destroy`: runs `destroy.yml`, removes instance from Molecule's state
- With delegated driver: `destroy.yml` must call `hcloud server delete` or mark server for OpenTofu destroy
- Orphaned servers: if CI job is cancelled mid-run, the test server may not be destroyed
  - Detection: Hetzner server with label `purpose=molecule-test` that's more than 2 hours old
  - Automated cleanup: OpenTofu or shell script that finds and destroys orphaned test servers
  - Hetzner server labels in OpenTofu: `labels = { purpose = "molecule-test", created_by = "ci" }`
  - Cleanup script: `hcloud server list --selector purpose=molecule-test -o json | jq '.[].id' | xargs hcloud server delete`
- Test isolation between molecule runs: fresh server per test ensures no state bleed
- Cost guardrails: GitHub Actions `timeout-minutes: 30` to prevent runaway test servers

---

### Best Practices & Anti-Patterns

- What are the top 10 Molecule testing best practices for infrastructure roles (not application roles)?
- What are the most common mistakes when using Molecule with delegated driver? Rank by severity.
- What Molecule configurations look correct but silently skip important tests (e.g., verify.yml never actually asserts)?
- When should you use Docker driver vs delegated driver? Clear decision criteria.
- What are the anti-patterns in verify.yml that give false confidence (passing tests on a non-compliant system)?
- How many assertions is "enough" for a CIS hardening role verification? Rule of thumb.

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| Docker driver vs delegated | Testing application logic, not OS state | Docker | Faster, cheaper, no Hetzner cost |
| Docker driver vs delegated | Testing SELinux, firewalld, systemd | Delegated (real server) | Docker can't test these accurately |
| Testinfra vs Ansible verify | Team knows Python | Testinfra | More expressive, pytest output |
| Testinfra vs Ansible verify | Team knows only Ansible | Ansible verify tasks | Lower learning curve, same language |
| Goss vs Ansible verify | Need fast standalone verification | Goss | Single binary, YAML assertions, very fast |
| Single scenario vs multiple | Role has one deployment profile | Single default scenario | Simpler |
| Single scenario vs multiple | Role supports different configs (K3s vs non-K3s) | Multiple scenarios | Test each variant |
| `molecule test` vs `molecule converge` + `molecule verify` | CI pipeline | `molecule test` (full lifecycle) | Complete quality gate |
| `molecule test` vs `molecule converge` + `molecule verify` | Local development iteration | `molecule converge && molecule verify` | Faster — keeps instance alive |
| Parallel scenarios vs sequential | Independent scenarios, separate servers | Parallel (`--parallel`) | Faster CI |

### Common Pitfalls

- Using Docker driver for SELinux/firewalld testing: containers can't test these — always false positive
- verify.yml with no assertions: an empty verify.yml will always pass — must have actual `assert` tasks
- Not testing idempotence: role works once but breaks on second run in production — always run `molecule idempotence`
- SSH host key verification blocking Molecule: newly provisioned server has unknown host key — handle with `StrictHostKeyChecking=accept-new`
- Test server being hardened with `AllowUsers` that doesn't match Ansible connection user: self-lockout
- Forgetting `if: always()` on destroy step in CI: test servers accumulate, billing surprise
- Long-running tests without timeout: CI test server runs for hours if job hangs — set `timeout-minutes`
- Testing with root user instead of `wakeem`: role may work as root but fail for non-root user in production
- `molecule test` defaults to `--destroy=always` — use `--destroy=never` while developing verify tasks

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- Molecule CLI quick reference (`molecule test`, `molecule converge`, `molecule verify`, `molecule destroy`, `molecule login`)
- Delegated driver configuration cheat sheet
- Ansible verify task patterns (SELinux, firewalld, sysctl, services, files)
- Idempotency debugging: how to find the non-idempotent task
- Integration points: Hetzner, OpenTofu, GitHub Actions, ansible-lint
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete `molecule.yml` for delegated driver with all options documented
- Complete `create.yml` and `destroy.yml` stubs and full versions
- Complete `instance_config.yml` format
- Complete `verify.yml` template for CIS hardening role
- Complete `.ansible-lint` configuration for infrastructure roles
- GitHub Actions workflow template for Molecule with Hetzner

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our servers (178.156.233.12 as control, helix-stax-test as target), port 2222, user `wakeem`
- Complete molecule directory structure for our `cis-hardening` role
- Complete `molecule.yml` that reads `HETZNER_TEST_IP` from environment
- Complete `converge.yml` for CIS hardening role with K3s exception variables
- Complete `verify.yml` for CIS hardening role (SSH, SELinux, firewalld, sysctl assertions)
- Complete `verify.yml` for K3s install role (service running, nodes ready, pods healthy)
- Complete GitHub Actions workflow: provision test server → molecule test → destroy
- Shell script: `cleanup-orphaned-test-servers.sh` using hcloud CLI

Use `# Molecule Testing` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual molecule.yml configurations, actual verify.yml assertion tasks, actual GitHub Actions YAML, and actual hcloud CLI commands. Do NOT give theory — give copy-paste-ready Molecule configurations for testing AlmaLinux 9 Ansible roles against Hetzner Cloud test servers.
