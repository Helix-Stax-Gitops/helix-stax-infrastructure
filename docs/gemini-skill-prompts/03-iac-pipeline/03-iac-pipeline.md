# Gemini Deep Research: IaC Pipeline (OpenTofu + Ansible)

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

OpenTofu and Ansible form the IaC pipeline that builds and configures the foundation everything else runs on:

- **OpenTofu** provisions infrastructure. It is the BSL-free fork of Terraform maintained by the Linux Foundation. We use it to create and manage cloud resources on Hetzner Cloud (servers, firewalls, networks, volumes), DNS records and security rules on Cloudflare, and Kubernetes-level resources on K3s. It declares *what* infrastructure exists.
- **Ansible** configures infrastructure. After OpenTofu provisions Hetzner Cloud servers, Ansible hardens the AlmaLinux 9.7 OS, installs K3s, deploys CrowdSec agents, and codifies all node-level configuration as reusable roles. It is agentless — it connects via SSH and executes tasks remotely. It declares *how* the OS and nodes are configured.

These two tools are tightly coupled in sequence: OpenTofu runs first and produces outputs (server IPs, metadata, labels); Ansible consumes those outputs as inventory and variables to configure the servers OpenTofu just created. Understanding the handoff between them is essential — the workflow is: `tofu apply` -> `tofu output -json > infra.json` -> `ansible-playbook -e @infra.json`. Neither tool is optional; skipping OpenTofu means manual server creation; skipping Ansible means an unhardened, unconfigured OS that K3s cannot safely run on.

## Our Specific Setup

### OpenTofu
- **OpenTofu version**: Latest stable (NOT Terraform — different binary, different registry at registry.opentofu.org)
- **State backend**: MinIO on K3s (S3-compatible) for remote state storage
- **Providers**: Hetzner Cloud, Cloudflare, Kubernetes, Helm, GitHub
- **Secrets**: SOPS+age encrypts sensitive `.tfvars` files in git; OpenBao stores runtime secrets
- **Cluster target**: K3s on AlmaLinux 9.7, Hetzner Cloud (heart: 178.156.233.12, helix-worker-1: 138.201.131.157)
- **Cloudflare integration**: DNS records, WAF rules, Access policies, Tunnel configs all managed via OpenTofu
- **CI/CD**: ArgoCD/Devtron do not run OpenTofu — we run it manually or via n8n workflow triggers
- **Module storage**: Local modules in `opentofu/modules/`, no external module registry

### Ansible
- **OS target**: AlmaLinux 9.7 (RHEL-compatible, NOT Ubuntu/Debian)
- **Nodes**: heart (CP, 178.156.233.12) and helix-worker-1 (worker, 138.201.131.157) on Hetzner Cloud
- **Ansible control node**: our local workstation or a bastion (NOT inside K3s)
- **Inventory source**: Hetzner Cloud dynamic inventory via `hetzner.hcloud` collection
- **OpenTofu integration**: OpenTofu provisions servers, Ansible consumes OpenTofu outputs as inventory/vars
- **K3s installation**: Ansible installs K3s on hardened AlmaLinux nodes
- **Security**: SELinux enforcing, firewalld, SSH hardening, CIS Benchmark compliance
- **Secrets**: Ansible Vault for sensitive vars; age-encrypted vaults for git storage; OpenBao as runtime secret store
- **CrowdSec**: IDS/IPS deployed via Ansible to all nodes
- **Collections**: `community.general`, `kubernetes.core`, `hetzner.hcloud`

---

## What I Need Researched

---

# OpenTofu Research Areas

### OT-1. CLI Reference
- Full `tofu` CLI command reference: `init`, `plan`, `apply`, `destroy`, `import`, `state`, `output`, `validate`, `fmt`
- `tofu init` flags: `-backend-config`, `-reconfigure`, `-upgrade` — when each is needed
- `tofu plan` flags: `-out`, `-target`, `-var`, `-var-file`, `-refresh-only`, `-destroy`
- `tofu apply` flags: `-auto-approve`, `-target`, `-parallelism`, `-replace`
- `tofu state` subcommands: `list`, `show`, `mv`, `rm`, `pull`, `push` — with real examples
- `tofu import` syntax: importing existing Hetzner servers, Cloudflare records into state
- `tofu output` — reading outputs from CLI and in scripts
- `tofu workspace` — `new`, `list`, `select`, `delete` for dev/staging/prod environments
- `tofu test` — writing `.tftest.hcl` files, running unit and integration tests
- Differences from `terraform` CLI: what changed, what broke, registry redirects

### OT-2. Provider Ecosystem
- OpenTofu registry vs Terraform registry: `registry.opentofu.org` vs `registry.terraform.io` — provider source addresses
- How to declare providers that still live in Terraform registry (using `required_providers` source overrides)
- Provider version locking: `.terraform.lock.hcl` equivalent in OpenTofu (`.opentofu.lock.hcl`?)
- Provider caching: `TF_PLUGIN_CACHE_DIR` equivalent for OpenTofu in CI environments
- Multi-provider configurations: aliasing providers for multi-region or multi-account setups
- Hetzner Cloud provider: `hetznercloud/hcloud` — current version, authentication via `HCLOUD_TOKEN`
- Cloudflare provider: `cloudflare/cloudflare` — authentication via `CLOUDFLARE_API_TOKEN`
- Kubernetes provider: `hashicorp/kubernetes` — kubeconfig auth for K3s
- Helm provider: `hashicorp/helm` — Helm release management from OpenTofu
- GitHub provider: `integrations/github` — repo and team management

### OT-3. State Management with MinIO
- S3-compatible backend configuration for MinIO: `endpoint`, `bucket`, `key`, `region`, `access_key`, `secret_key`, `skip_credentials_validation`, `skip_metadata_api_check`, `force_path_style`
- Complete `backend "s3"` block for MinIO as state backend
- State locking with MinIO: does MinIO support DynamoDB-compatible locking? Alternative locking strategies
- State encryption: OpenTofu native state encryption (new feature vs Terraform) — how to enable with age/SOPS
- Multiple state files: one per environment (`dev.tfstate`, `staging.tfstate`, `prod.tfstate`) vs workspaces
- State file backup strategy: Velero backing up MinIO bucket that contains state
- Recovering from corrupted state: `tofu state pull`, manual JSON editing, `tofu state push`
- State migration: moving resources between state files without destroying them
- Remote state data sources: `terraform_remote_state` equivalent in OpenTofu for reading cross-module outputs

### OT-4. Module Development
- Module directory structure: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` — conventions
- Module composition: calling child modules from root module, passing outputs as inputs
- Writing a Hetzner node module: inputs (server_type, location, image, ssh_keys), outputs (ip, id)
- Writing a K3s cluster module: depends on node module, outputs kubeconfig
- Writing a Cloudflare DNS module: inputs (zone_id, records list), creates A/CNAME/TXT records
- Module versioning: local path references vs git source with `ref=` for production modules
- `moved` block: safely refactoring module structure without destroying resources
- `check` block: post-apply assertions to verify infrastructure state
- `precondition` and `postcondition` in resources and outputs
- Module testing with `tofu test`: mock providers, assert outputs

### OT-5. Hetzner Cloud Provider
- Provider authentication: `HCLOUD_TOKEN` env var, token scopes needed (read+write)
- `hcloud_server`: `server_type` options (cx22, cx32, cx42 for our budget), `image` (AlmaLinux 9), `location` (ash for Ashburn)
- `hcloud_server` user_data: cloud-init for initial setup, SSH key injection
- `hcloud_ssh_key`: managing SSH public keys in Hetzner
- `hcloud_network` and `hcloud_network_subnet`: private networking between nodes
- `hcloud_firewall` and `hcloud_firewall_attachment`: ingress/egress rules for K3s cluster
- `hcloud_volume` and `hcloud_volume_attachment`: persistent block storage
- `hcloud_load_balancer`: load balancer in front of K3s worker nodes (future-proofing)
- `hcloud_placement_group`: ensuring CP and worker are on different physical hosts
- Importing existing Hetzner resources: `tofu import hcloud_server.heart <server_id>`
- Data sources: `data "hcloud_server"`, `data "hcloud_image"` for dynamic lookups

### OT-6. Cloudflare Provider
- Provider authentication: `CLOUDFLARE_API_TOKEN` (preferred) vs `CLOUDFLARE_API_KEY` + email
- API token scopes needed: Zone:DNS:Edit, Zone:Firewall:Edit, Access:Apps+Policies:Edit
- `cloudflare_record`: A, CNAME, TXT, MX records — `proxied` flag behavior
- Managing all DNS records for helixstax.com and helixstax.net from OpenTofu
- `cloudflare_zone_settings_override`: security level, SSL mode, HTTP/3, cache rules
- `cloudflare_ruleset`: WAF custom rules, rate limiting rules, transform rules
- `cloudflare_access_application`: creating Access applications for internal services
- `cloudflare_access_policy`: OIDC group conditions, service token conditions
- `cloudflare_tunnel` and `cloudflare_tunnel_config`: Zero Trust tunnel management
- `cloudflare_tunnel_route`: routing tunnel traffic to K3s services
- Importing existing Cloudflare resources: zone ID lookup, record ID lookup

### OT-7. Kubernetes and Helm Providers
- Kubernetes provider auth: `config_path` (local kubeconfig) vs in-cluster service account
- K3s kubeconfig location: `/etc/rancher/k3s/k3s.yaml` — how to reference from OpenTofu
- `kubernetes_namespace`: creating namespaces with labels and annotations
- `kubernetes_config_map` and `kubernetes_secret`: managing K8s config from OpenTofu (vs ArgoCD)
- `kubernetes_cluster_role` and `kubernetes_cluster_role_binding`: RBAC from OpenTofu
- Helm provider: `helm_release` for deploying charts to K3s
- `helm_release` with Harbor OCI: `repository = "oci://harbor.helixstax.net/charts"`
- Values override in `helm_release`: inline `values` block vs `values_files`
- When to use Helm provider vs ArgoCD for chart deployment: clear boundary recommendation
- Avoiding drift: OpenTofu Helm releases vs ArgoCD managing the same namespace

### OT-8. Secrets in OpenTofu
- The core problem: provider credentials and sensitive variables must not be in plaintext in git
- SOPS+age for `.tfvars` files: encrypting `terraform.tfvars`, decrypting before `tofu apply`
- `sops -d terraform.tfvars.enc > terraform.tfvars && tofu apply` — workflow
- `sensitive = true` in variable definitions: what it does, what it doesn't do (still in state!)
- State file encryption: OpenTofu native encryption with AES-GCM or age — configuration block
- OpenBao integration: using `vault_generic_secret` data source to pull secrets from OpenBao at plan time
- Environment variables as secrets: `TF_VAR_*` pattern for injecting without files
- `.gitignore` requirements: `*.tfvars`, `*.tfstate`, `.terraform/` — minimum required entries
- Secret rotation: updating credentials in OpenBao, re-running `tofu apply` to pick up changes

### OT-9. Workspaces
- Workspace vs separate state files: when to use which pattern
- `tofu workspace new dev`, `tofu workspace select prod`
- `terraform.workspace` interpolation in resource names: `"${var.app_name}-${terraform.workspace}"`
- Workspace-aware variable files: loading `dev.tfvars` when in `dev` workspace automatically
- Workspace isolation in MinIO backend: how workspace names affect state key paths
- Limitations of workspaces: same provider config, same module code — when to use separate root modules instead
- Our recommended pattern: separate root modules per major domain (hetzner/, cloudflare/, k8s/) + workspaces for envs

### OT-10. Testing and Validation
- `tofu validate`: what it checks (syntax + type system), what it misses (provider API responses)
- `tofu fmt -recursive`: formatting enforcement, CI check pattern
- `tofu plan -detailed-exitcode`: exit code 2 means changes pending — CI integration pattern
- `tofu test` framework: `.tftest.hcl` file syntax, `run` blocks, `assert` conditions
- Mock providers in `tofu test`: testing module logic without real API calls
- Checkov or tfsec for static analysis: which works with OpenTofu, how to run
- Pre-commit hooks: `tofu fmt`, `tofu validate`, Checkov — `.pre-commit-config.yaml`
- Integration testing: using `tofu apply` against a real dev environment and asserting outputs

### OT-11. Migration from Terraform
- Binary differences: `terraform` vs `tofu` — same HCL, different binary
- Registry redirect: `registry.terraform.io` -> `registry.opentofu.org` — not automatic, need `required_providers` update
- State file compatibility: OpenTofu reads Terraform state files directly — migration steps
- `.terraform.lock.hcl` vs OpenTofu's lock file: format differences, regeneration
- Features in OpenTofu not in Terraform: native state encryption, `tofu test`, `import` blocks improvements
- Features in Terraform not in OpenTofu: stacks, HCP integration — alternatives
- Providers that haven't been mirrored to OpenTofu registry: how to use `terraform.io/providers/` source override

### OT-12. Ansible Integration
- OpenTofu provisions, Ansible configures: the handoff pattern
- Reading OpenTofu outputs in Ansible: `tofu output -json | jq` piped to Ansible extra vars
- Ansible dynamic inventory from Hetzner: `hetzner.hcloud` collection's inventory plugin reading Hetzner API
- Terraform/OpenTofu output to Ansible inventory: generating `inventory.ini` or `inventory.yaml` from `tofu output`
- Using `local_file` resource to write Ansible inventory from OpenTofu outputs
- Null resource + `local-exec` provisioner: running Ansible playbooks from OpenTofu (anti-pattern or acceptable?)
- Recommended workflow: `tofu apply` -> capture outputs -> `ansible-playbook -i <dynamic_inventory>` — step by step

---

# Ansible Research Areas

### AN-1. CLI Reference
- `ansible-playbook` flags: `-i`, `--limit`, `--tags`, `--skip-tags`, `--check`, `--diff`, `-v/-vvv`, `--extra-vars`, `--become`, `--become-user`
- `ansible` ad-hoc commands: ping, shell, copy, service — real examples against AlmaLinux nodes
- `ansible-galaxy` collection management: `install`, `list`, `init` for role scaffolding
- `ansible-galaxy role install` vs `requirements.yml` — which to use in a team environment
- `ansible-vault` commands: `create`, `edit`, `encrypt`, `decrypt`, `encrypt_string`, `view`, `rekey`
- `ansible-inventory` commands: `--list`, `--graph`, `--host` for debugging inventory
- `ansible-lint` — running linting on playbooks and roles, config options
- `ansible-doc` — looking up module documentation from CLI
- Environment variables: `ANSIBLE_CONFIG`, `ANSIBLE_ROLES_PATH`, `ANSIBLE_COLLECTIONS_PATHS`, `ANSIBLE_VAULT_PASSWORD_FILE`
- `ansible.cfg` key settings: `host_key_checking`, `remote_user`, `private_key_file`, `forks`, `timeout`

### AN-2. Inventory Management
- Static inventory: INI format and YAML format — `[control_plane]`, `[workers]`, `[k3s_cluster:children]` groups
- Group variables: `group_vars/all.yml`, `group_vars/control_plane.yml`, `host_vars/heart.yml`
- Hetzner Cloud dynamic inventory: `hetzner.hcloud` collection's `hcloud.py` inventory plugin
- Dynamic inventory configuration file: `hcloud.yml` — `token`, `group_by` (server_type, labels), `filters`
- Combining static and dynamic inventory: `ansible-playbook -i static.ini -i hcloud.yml`
- Inventory plugin: `ansible-inventory --list -i hcloud.yml` for verifying dynamic inventory
- Hetzner server labels: using labels as Ansible groups (`k3s_role=control_plane`, `k3s_role=worker`)
- Host variables from OpenTofu outputs: injecting Hetzner IPs and metadata into inventory
- `add_host` module: dynamically adding hosts to inventory during playbook execution
- Inventory encryption: encrypting `host_vars/` files with Ansible Vault

### AN-3. AlmaLinux 9.7 Hardening Playbooks
- SELinux: ensuring `enforcing` mode, installing `python3-libselinux`, setting booleans with `seboolean`
- `firewalld`: removing unused services, adding K3s ports (6443, 10250, 8472/UDP for Flannel, 51820/UDP WireGuard)
- SSH hardening: `sshd_config` — PermitRootLogin no, PasswordAuthentication no, AllowUsers, MaxAuthTries
- `fail2ban` or `sshguard`: brute-force SSH protection on AlmaLinux
- System updates: `dnf update` idempotently, `dnf install` for required packages
- Kernel parameters: `sysctl` settings for K3s (net.ipv4.ip_forward, net.bridge.bridge-nf-call-iptables)
- CIS Benchmark for AlmaLinux 9: Level 1 controls implementable via Ansible — which modules, which sysctl values
- Chrony/NTP: time synchronization configuration
- Auditd: enabling audit logging, basic rules for compliance
- User management: creating `ansible` service user, distributing SSH keys, sudoers entry
- Disabling unnecessary services: `postfix`, `cups`, etc. via `ansible.builtin.service`
- GRUB hardening: password protection, kernel parameter hardening

### AN-4. Role Development
- Role directory structure: `tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `files/`, `meta/`
- `meta/main.yml`: dependencies, platforms, galaxy info
- `defaults/main.yml` vs `vars/main.yml`: precedence rules, when to use which
- Handler patterns: `notify: restart sshd`, handler names, `flush_handlers` usage
- Template best practices: Jinja2 in `.j2` files, `ansible_managed` comment, conditionals in templates
- Task tagging: `tags: [security, ssh]` for selective execution
- Role dependencies in `meta/main.yml`: declaring upstream roles
- Role testing with Molecule: `molecule init`, `molecule test`, `molecule converge`, Docker driver vs Hetzner driver
- Writing idempotent tasks: `changed_when`, `failed_when`, `creates`, `removes` parameters
- Block/rescue/always: structured error handling in tasks

### AN-5. K3s Installation Playbook
- Pre-flight checks: verifying AlmaLinux version, SELinux mode, firewalld state
- K3s install script: `curl -sfL https://get.k3s.io | sh -` vs offline installation
- Ansible-controlled K3s install: using `ansible.builtin.shell` with environment variables
- K3s server (CP) config: `--disable=traefik` (we deploy our own), `--flannel-backend=vxlan`, `--write-kubeconfig-mode=644`
- K3s agent (worker) config: `K3S_URL`, `K3S_TOKEN` from CP node
- Token retrieval: reading `/var/lib/rancher/k3s/server/node-token` from CP and registering as var
- Kubeconfig: fetching from `/etc/rancher/k3s/k3s.yaml`, replacing `127.0.0.1` with CP IP, saving locally
- Firewall rules for K3s: exact ports needed for Flannel VXLAN, etcd, API server, kubelet
- SELinux and K3s: known issues, required booleans, `container_manage_cgroup` boolean
- Post-install verification: `kubectl get nodes` via `kubernetes.core.k8s_info` or shell task
- K3s upgrades: using `system-upgrade-controller` vs re-running Ansible playbook

### AN-6. OpenTofu Integration
- Reading OpenTofu outputs: `tofu output -json` piped to file, Ansible reads with `vars_files`
- `local_file` OpenTofu resource: generating `inventory.yml` from server IPs after `tofu apply`
- `hcloud.yml` dynamic inventory: reading Hetzner API (populated by OpenTofu provisioning)
- Passing OpenTofu outputs as `--extra-vars`: `ansible-playbook -e @tofu_outputs.json`
- Workflow sequence: `tofu apply` -> `tofu output -json > infra.json` -> `ansible-playbook -e @infra.json`
- Avoiding chicken-and-egg: when SSH access isn't available yet, using cloud-init for initial user creation
- Infrastructure metadata: using Hetzner server labels (set by OpenTofu) as Ansible inventory groups

### AN-7. Ansible Vault
- Vault password file: `~/.ansible/vault_pass` — permissions (0600), `.gitignore` entry
- `ansible.cfg` vault configuration: `vault_password_file = ~/.ansible/vault_pass`
- Encrypting entire files: `ansible-vault encrypt group_vars/all/secrets.yml`
- Encrypting individual strings: `ansible-vault encrypt_string 'mysecret' --name 'db_password'`
- Multiple vault IDs: `--vault-id dev@~/.vault_pass_dev --vault-id prod@~/.vault_pass_prod`
- age integration: encrypting vault password file itself with age for git storage
- SOPS alternative: using SOPS+age directly on `group_vars/` files instead of Ansible Vault
- OpenBao as vault backend: using `community.hashi_vault.hashi_vault_kv2_get` to pull secrets at runtime
- When Ansible Vault vs OpenBao: Vault for Ansible-internal secrets (SSH keys, API tokens); OpenBao for app runtime secrets
- Rekeying: `ansible-vault rekey` when rotating vault password

### AN-8. Collections Reference
- `community.general`: `ufw`, `sysctl`, `seboolean`, `selinux`, `cronvar` — which modules we use
- `kubernetes.core`: `k8s`, `k8s_info`, `k8s_exec`, `helm` — deploying K8s resources from Ansible
- `hetzner.hcloud`: `hcloud_server_info`, `hcloud_firewall`, `hcloud_network_info` — inventory + management
- `community.hashi_vault`: `hashi_vault_kv2_get` for OpenBao secret retrieval
- `ansible.posix`: `authorized_key`, `mount`, `sysctl`, `firewalld` — POSIX-specific modules
- Installing collections from `requirements.yml`: format, `ansible-galaxy collection install -r requirements.yml`
- Collection namespacing: fully qualified module names (`ansible.builtin.copy` vs `copy`)
- Offline collection installation: downloading to `~/.ansible/collections/` for air-gapped environments

### AN-9. Idempotency Patterns and Molecule Testing
- Idempotent patterns: `creates` on `command`, `stat` before file write, `changed_when: false` for info tasks
- `register` + `when`: conditional task execution based on previous task results
- `ansible_facts`: OS detection (`ansible_distribution`, `ansible_os_family`), interface facts, disk facts
- Molecule framework: `molecule init role`, `molecule.yml` configuration, `converge.yml` playbook
- Docker driver for Molecule: fast local testing with AlmaLinux container image
- Hetzner driver (or delegated driver): testing against real Hetzner VMs
- Molecule test sequence: `lint` -> `create` -> `converge` -> `idempotence` -> `verify` -> `destroy`
- `verify.yml`: writing Testinfra or Ansible Verify tasks to assert post-converge state
- Idempotence test: running `converge` twice and asserting zero changes on second run
- CI integration: running `molecule test` in GitHub Actions

### AN-10. CrowdSec Deployment
- CrowdSec architecture: Security Engine (agent on each node) + Local API (LAPI) + Console
- Installing CrowdSec on AlmaLinux 9.7: `dnf` repo setup, package install, `cscli` configuration
- CrowdSec Ansible role: using existing community role or writing custom tasks
- LAPI setup: one node runs LAPI (heart CP), all nodes register as Security Engines
- Bouncers: `firewall-bouncer` integration with `firewalld` on AlmaLinux
- CrowdSec hub: installing collections (`crowdsecurity/linux`, `crowdsecurity/http-dos`, `crowdsecurity/sshd`)
- Configuration: `config.yaml`, acquis.yaml for log sources (K3s logs, SSH logs, Traefik access logs)
- Console enrollment: `cscli console enroll <key>` for cloud dashboard (optional)
- Ansible idempotency for CrowdSec: checking service state, avoiding re-enrollment
- Firewall integration: CrowdSec bouncer modifying `firewalld` rich rules dynamically

### AN-11. User Management
- Service accounts: `ansible` user with sudo NOPASSWD for automation, no password login
- SSH key management: `ansible.posix.authorized_key` module, deploying team public keys
- Sudoers file management: `community.general.sudoers` module or template-based approach
- User expiry and locking: managing temporary access for contractors
- SSH known_hosts management: `ansible.builtin.known_hosts` for preventing host key errors
- Key rotation workflow: deploying new key, verifying access, removing old key — in one playbook
- `root` account: locking password, allowing only SSH key login, disabling direct root SSH

### AN-12. Troubleshooting
- Connection issues: `ansible -m ping all -vvv` — decoding SSH errors, timeout vs refused
- `become` / `sudo` issues: `sudo: a password is required`, missing sudoers entry — fix steps
- SELinux denials: `audit2allow` workflow, identifying AVC denials from Ansible tasks
- Task failures: reading `FAILED!` output, `rc`, `stdout`, `stderr` fields
- Idempotency failures: tasks reporting `changed` every run — diagnosis patterns
- Handler not firing: `notify` name mismatch, `--check` mode suppressing handlers
- Vault decryption errors: wrong password, vault ID mismatch — systematic debugging
- Python interpreter issues: `ansible_python_interpreter`, AlmaLinux 9 using Python 3.9
- Fact gathering failures: `gather_facts: false` workaround, manual `setup` module invocation
- Slow playbooks: `forks` setting, `pipelining = True` in `ansible.cfg`, async tasks

---

## Required Output Format

Structure your response using the following top-level `#` headers — one per tool — so the output can be split into two separate skill files:

```markdown
# OpenTofu

## Overview
[2-3 sentence description of what OpenTofu does and why we use it instead of Terraform]

## CLI Reference
### Core Commands
[tofu init/plan/apply/destroy with important flags]
### State Management Commands
[tofu state list/show/mv/rm/pull/push]
### Import
[tofu import syntax with Hetzner and Cloudflare examples]
### Workspace Commands
[tofu workspace new/select/list]
### Testing and Validation
[tofu validate, tofu fmt, tofu test]
### Terraform vs OpenTofu CLI Differences
[What changed, registry redirects]

## State Management with MinIO
### Backend Configuration
[Complete backend "s3" block for MinIO]
### State Locking
[Locking strategy for MinIO]
### State Encryption
[OpenTofu native encryption config]
### State Recovery
[Corrupted state recovery procedure]

## Module Development
### Directory Structure
[Conventions, file layout]
### Hetzner Node Module
[Complete example module]
### Cloudflare DNS Module
[Record management module]
### Testing Modules
[tofu test example]

## Hetzner Cloud Provider
### Provider Configuration
[Auth, required scopes]
### Server Resources
[hcloud_server, hcloud_ssh_key with examples]
### Networking
[hcloud_network, hcloud_firewall examples]
### Storage
[hcloud_volume examples]
### Importing Existing Resources
[tofu import examples for Hetzner]

## Cloudflare Provider
### Provider Configuration
[API token, required scopes]
### DNS Management
[cloudflare_record examples for helixstax.com and .net]
### WAF and Security Rules
[cloudflare_ruleset examples]
### Zero Trust
[cloudflare_access_application, cloudflare_tunnel examples]

## Kubernetes and Helm Providers
### K3s Authentication
[kubeconfig path, in-cluster vs external]
### Kubernetes Resources
[namespaces, RBAC, configmaps from OpenTofu]
### Helm Releases
[helm_release with Harbor OCI, values override]
### When OpenTofu vs ArgoCD
[Clear boundary recommendation]

## Secrets
### SOPS+age for .tfvars
[Encrypt/decrypt workflow]
### OpenTofu Native State Encryption
[Configuration block, age key setup]
### OpenBao Integration
[vault_generic_secret data source]
### .gitignore Requirements
[Minimum required entries]

## Workspaces
### Pattern: Workspaces vs Separate Root Modules
[Recommendation for our setup]
### Workspace-Aware Variables
[Loading per-workspace .tfvars]

## Ansible Integration
### The Handoff Pattern
[tofu apply -> outputs -> ansible-playbook]
### Dynamic Inventory from Hetzner
[hcloud inventory plugin config]
### Generating Ansible Inventory from OpenTofu Outputs
[local_file resource example]

## Troubleshooting
### State Drift
[Detecting and fixing drift, tofu refresh]
### Provider Auth Failures
[Hetzner token, Cloudflare token debugging]
### Lock File Issues
[Regenerating .opentofu.lock.hcl]
### Import Conflicts
[Resolving "already in state" errors]

## Gotchas
[Registry differences, state encryption gotchas, MinIO S3 path-style, Helm provider drift]

---

# Ansible

## Overview
[2-3 sentence description of what Ansible does and why we use it]

## CLI Reference
### ansible-playbook
[Key flags with real examples]
### ansible ad-hoc
[Common ad-hoc commands against AlmaLinux nodes]
### ansible-galaxy
[Collection and role management]
### ansible-vault
[Create, encrypt, decrypt, encrypt_string examples]
### ansible-inventory
[Debugging inventory with --list, --graph]
### ansible.cfg Key Settings
[host_key_checking, remote_user, forks, vault_password_file]

## Inventory Management
### Static Inventory
[INI and YAML format examples with our node groups]
### Hetzner Cloud Dynamic Inventory
[hcloud.yml configuration, group_by labels]
### Combining Static and Dynamic
[Multi -i flag usage]
### Group and Host Variables
[group_vars/ and host_vars/ structure]

## AlmaLinux 9.7 Hardening
### SELinux
[Enforcing mode, booleans, libselinux]
### Firewalld
[K3s required ports, removing unused services]
### SSH Hardening
[sshd_config template, PermitRootLogin, key-only auth]
### Kernel Parameters
[sysctl settings for K3s, CIS Benchmark values]
### CIS Benchmark Level 1
[Ansible tasks for key CIS controls on AlmaLinux 9]
### System Services
[Disabling postfix, cups, other unused services]

## Role Development
### Directory Structure
[Complete role skeleton with descriptions]
### Defaults vs Vars
[Precedence rules, when to use which]
### Handlers
[notify pattern, flush_handlers]
### Templates
[Jinja2 .j2 best practices, ansible_managed]
### Idempotency Patterns
[changed_when, failed_when, stat before write]
### Block/Rescue/Always
[Error handling example]

## K3s Installation
### Pre-flight Checks
[Verify OS, SELinux, firewalld]
### Server (Control Plane) Installation
[Shell task with environment vars, --disable=traefik]
### Agent (Worker) Installation
[Token retrieval from CP, K3S_URL and K3S_TOKEN]
### Kubeconfig Retrieval
[Fetch, replace 127.0.0.1, save locally]
### Firewall Rules
[Exact ports for Flannel VXLAN, API server, kubelet]
### Post-install Verification
[kubectl get nodes via Ansible]

## OpenTofu Integration
### The Handoff Pattern
[tofu output -json -> ansible-playbook workflow]
### Dynamic Inventory from Hetzner Labels
[Labels set by OpenTofu, consumed by hcloud.yml]
### Passing OpenTofu Outputs as Extra Vars
[--extra-vars @infra.json pattern]

## Ansible Vault
### Basic Usage
[encrypt, decrypt, edit, view]
### Encrypted Strings in Vars
[encrypt_string usage]
### Multiple Vault IDs
[dev/prod vault password management]
### age and SOPS Integration
[Encrypting vault password file with age]
### OpenBao as Runtime Backend
[hashi_vault_kv2_get module example]

## Collections Reference
### community.general
[Key modules: sysctl, seboolean, sudoers]
### kubernetes.core
[k8s, k8s_info, helm examples]
### hetzner.hcloud
[Inventory plugin, server_info]
### community.hashi_vault
[OpenBao secret retrieval]
### ansible.posix
[authorized_key, firewalld, mount]
### requirements.yml
[Format, install command]

## CrowdSec Deployment
### Architecture on Our Cluster
[LAPI on heart, agents on all nodes]
### Installation on AlmaLinux 9.7
[dnf repo, package install, cscli setup]
### Bouncer Configuration
[firewall-bouncer with firewalld]
### Hub Collections
[Installing crowdsecurity/linux, sshd, http-dos]
### Ansible Idempotency
[Service state checks, avoiding re-enrollment]

## User Management
### Service Account Creation
[ansible user, sudo NOPASSWD, no password login]
### SSH Key Distribution
[authorized_key module, team key deployment]
### Key Rotation Workflow
[Deploy new, verify, remove old — single playbook]

## Molecule Testing
### Setup
[molecule init, molecule.yml for Docker driver]
### Test Sequence
[lint, create, converge, idempotence, verify, destroy]
### verify.yml
[Testinfra assertions vs Ansible Verify tasks]
### CI Integration
[GitHub Actions molecule test job]

## Troubleshooting
### Connection Failures
[SSH errors, -vvv output decoding]
### become / sudo Issues
[Missing sudoers, password required]
### SELinux Denials
[audit2allow workflow, AVC denial reading]
### Vault Errors
[Wrong password, vault ID mismatch]
### Idempotency Failures
[Tasks always reporting changed — diagnosis]
### Python Interpreter
[ansible_python_interpreter for AlmaLinux 9]

## Gotchas
[SELinux and K3s, AlmaLinux vs RHEL differences, dnf vs yum, firewalld zone gotchas, handler pitfalls]
```

Be thorough, opinionated, and practical. Include actual HCL code blocks, actual CLI commands with real flag combinations, actual backend configurations for MinIO, actual playbook YAML, actual `ansible.cfg` settings, actual `hcloud.yml` inventory config, and actual CrowdSec task examples. Do NOT give me theory — give me copy-paste-ready OpenTofu code and Ansible playbooks for managing Hetzner Cloud servers, Cloudflare DNS, K3s provisioning, and AlmaLinux 9.7 hardening on a two-node Hetzner Cloud cluster.
