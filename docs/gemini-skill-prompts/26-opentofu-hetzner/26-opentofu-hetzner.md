# Gemini Deep Research: OpenTofu + Hetzner Cloud Provider — Patterns and Workflows

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

This prompt covers OpenTofu specifically as it applies to Hetzner Cloud provisioning. It is a focused companion to prompt 03 (IaC Pipeline), which covers OpenTofu and Ansible broadly. Where prompt 03 covers the full OpenTofu CLI, state management, module development, and Ansible integration, this prompt drills into the `hetznercloud/hcloud` provider specifically: resource schemas, patterns, workflows, and Hetzner-specific gotchas.

The `hetznercloud/hcloud` provider is the OpenTofu/Terraform provider maintained by Hetzner Cloud. It covers the complete Hetzner Cloud API surface: servers, firewalls, networks, SSH keys, volumes, images, placement groups, and load balancers. We use it to provision all Helix Stax infrastructure declaratively, with state stored in MinIO and secrets managed via SOPS+age.

Key distinction: This prompt is about Hetzner-specific OpenTofu patterns. For general OpenTofu CLI usage, state management, workspaces, and module development, refer to prompt 03.

## Our Specific Setup

### OpenTofu
- **OpenTofu version**: Latest stable (NOT Terraform — different binary, `tofu` not `terraform`)
- **Registry**: `registry.opentofu.org` (NOT `registry.terraform.io`)
- **State backend**: MinIO on K3s (S3-compatible), bucket `tofu-state`
- **Secrets**: SOPS+age for `.tfvars` files, OpenBao for runtime secrets
- **Module location**: `helix-stax-infrastructure/opentofu/`

### Hetzner Cloud
- **Locations used**: ash-dc1 (Ashburn, VA) and hil-dc1 (Hillsboro, OR) — US region only
- **Production servers**:
  - helix-stax-cp: cpx31, ash-dc1 — 178.156.233.12 — Control Plane
  - helix-stax-vps: cpx31, hil-dc1 — 5.78.145.30 — Worker/secondary role
- **Test server**: helix-stax-test: cx22, ash-dc1 — temporary, created and destroyed per CI run
- **OS**: AlmaLinux 9.7 on all servers
- **SSH key**: `wakeem-helix` (our admin key, already registered in Hetzner)
- **DNS**: Cloudflare (NOT Hetzner DNS — we do NOT use Hetzner's DNS product)
- **Authentication**: `HCLOUD_TOKEN` environment variable

### Repository Structure
```
helix-stax-infrastructure/
  opentofu/
    modules/
      hetzner-server/     # Reusable server module
      hetzner-firewall/   # Reusable firewall module
      hetzner-network/    # Private network module
    environments/
      prod/               # Production infrastructure
        main.tf
        variables.tf
        outputs.tf
        terraform.tfvars.enc  # SOPS-encrypted
      test/               # Test server (ephemeral)
        main.tf
        variables.tf
        outputs.tf
```

---

## What I Need Researched

---

### HCT-1. Provider Configuration

**Required providers block:**
```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}
```

Document:
- Current stable version of `hetznercloud/hcloud` provider (as of research date)
- Source address: `hetznercloud/hcloud` — does this resolve correctly from `registry.opentofu.org`? Is there a mirror or is the provider directly available from OpenTofu registry?
- Version constraints: `~> 1.49` vs `>= 1.49, < 2.0` — which is better for production pinning?
- Provider block configuration:
  ```hcl
  provider "hcloud" {
    token = var.hcloud_token
  }
  ```
- Environment variable alternative: `HCLOUD_TOKEN` env var (no `token` in provider block needed)
- Multi-provider aliases: if we ever need two Hetzner accounts (prod + staging projects), how to use `alias`
- Lock file: `.opentofu.lock.hcl` — the hcloud provider entry format, how to regenerate with `tofu providers lock`

---

### HCT-2. hcloud_server Resource

The primary resource for all our servers. Document the complete schema:

**Required arguments:**
- `name` — server name (must be unique in project)
- `server_type` — type string: `cx22`, `cpx31`, `ccx13`, etc.
- `image` — image name or ID: `"alma-9"`, `"ubuntu-24.04"`, etc.

**Optional arguments:**
- `location` — datacenter name: `"ash"`, `"hil"`, `"nbg1"`, `"fsn1"`, `"hel1"` — note: `ash` not `ash-dc1` in OpenTofu
- `datacenter` — alternative to location (more specific)
- `ssh_keys` — list of SSH key names or IDs: `["wakeem-helix"]`
- `user_data` — cloud-init string (use `templatefile()` for dynamic content)
- `firewall_ids` — list of firewall IDs to attach at creation
- `network` block — for attaching to private networks
- `labels` — map of string labels
- `placement_group_id` — ID of placement group (for spreading VMs across hosts)
- `keep_disk` — prevent disk resize when changing server type (default false)
- `iso` — attach ISO for installation (not relevant for our use case)
- `rescue` — boot into rescue mode
- `public_net` block — control IPv4/IPv6 assignment
- `backups` — enable Hetzner automated backups (paid feature, we use Velero instead)
- `ignore_remote_actual_size` — suppress diff when actual disk size differs

**Computed attributes (read after apply):**
- `id` — server ID
- `ipv4_address` — public IPv4 (what we use for Ansible/SSH)
- `ipv6_address` — public IPv6
- `ipv6_network` — IPv6 /64 prefix
- `status` — server status
- `backup_window` — backup window if enabled

**Lifecycle rules:**
- `prevent_destroy = true` — for production servers that must not be accidentally deleted
- `create_before_destroy` — for server replacement (rarely needed with servers)
- `ignore_changes = [user_data]` — prevent replacement when user_data changes after creation (cloud-init runs only once anyway)

**The user_data cloud-init pattern:**
```hcl
resource "hcloud_server" "cp" {
  name        = "helix-stax-cp"
  server_type = "cpx31"
  image       = "alma-9"
  location    = "ash"
  ssh_keys    = [hcloud_ssh_key.wakeem.id]
  labels      = {
    role        = "control-plane"
    environment = "prod"
    managed-by  = "opentofu"
  }
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_user   = var.admin_user
    ssh_pub_key  = var.ssh_public_key
  })
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [user_data]
  }
}
```

Provide the complete annotated resource with all our production server settings.

---

### HCT-3. hcloud_firewall Resource

Hetzner Cloud firewalls are stateful, applied at the hypervisor level (NOT inside the VM). They complement `firewalld` inside the VM — both should be configured.

**Firewall vs VM-level firewalld:**
- Hetzner firewall: hypervisor-level, filters traffic before it reaches the VM
- VM firewalld: OS-level, filters traffic inside the VM
- Both should be configured — defense in depth
- Hetzner firewall is the first line of defense

**hcloud_firewall resource schema:**
```hcl
resource "hcloud_firewall" "k3s_nodes" {
  name = "k3s-nodes"
  labels = {
    managed-by = "opentofu"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2222"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "SSH"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]  # or restrict to management IPs
    description = "K3s API server"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "8472"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Flannel VXLAN"
  }
}
```

Document:
- Complete `rule` block schema: `direction` (in/out), `protocol` (tcp/udp/icmp/gre/esp), `port`, `source_ips`, `destination_ips`, `description`
- Port ranges: `"80-443"` format for port ranges
- ICMP rules: no `port` field, just `protocol = "icmp"`
- Egress rules: `direction = "out"` with `destination_ips`
- Default egress policy: is all outbound allowed by default on Hetzner firewalls? (Important — unlike AWS Security Groups, Hetzner firewalls may be inbound-only)
- Attaching firewall to server: two methods
  - Method 1: `firewall_ids` in `hcloud_server` resource
  - Method 2: `hcloud_firewall_attachment` resource (allows attaching existing firewalls to existing servers)
- `hcloud_firewall_attachment` resource: `firewall_id`, `server_ids` — when to use vs `firewall_ids` in server resource
- Label selectors on firewalls: can a Hetzner firewall be applied to all servers with a label? (Label-based attachment)

**Our complete firewall configuration:**
Provide the complete OpenTofu configuration for our production firewall rules (all K3s ports, SSH on 2222).

---

### HCT-4. hcloud_ssh_key Resource

Managing SSH keys in Hetzner:

```hcl
resource "hcloud_ssh_key" "wakeem" {
  name       = "wakeem-helix"
  public_key = var.ssh_public_key  # from SOPS-encrypted tfvars
  labels = {
    managed-by = "opentofu"
  }
}
```

Document:
- `name` — must be unique in project
- `public_key` — the full public key string (`ssh-ed25519 AAAA... wakeem@helix`)
- `fingerprint` — computed attribute, useful for verification
- Importing an existing SSH key: `tofu import hcloud_ssh_key.wakeem <key_id>`
- Data source: `data "hcloud_ssh_key" "wakeem"` — look up existing key by name without managing it

**SSH key security:**
- Storing the public key: safe to commit (it's a public key) — but we store it in SOPS-encrypted tfvars for consistency
- Key rotation: creating a new `hcloud_ssh_key` resource with new key name, updating server resources to reference new key, verifying access, removing old resource

---

### HCT-5. hcloud_network and hcloud_network_subnet

Private networking for inter-node communication:

```hcl
resource "hcloud_network" "cluster" {
  name     = "helix-cluster-network"
  ip_range = "10.0.0.0/8"
  labels = {
    managed-by = "opentofu"
  }
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.cluster.id
  type         = "server"
  network_zone = "us-east"  # for ash-dc1
  ip_range     = "10.10.0.0/24"
}
```

Document:
- `hcloud_network`: `name`, `ip_range`, `labels`
- `hcloud_network_subnet`: `network_id`, `type` (`"server"` or `"cloud"`), `network_zone`, `ip_range`
- Network zones for US datacenters: `ash-dc1` = `"us-east"`, `hil-dc1` = `"us-west"` — confirm correct zone names
- Can a single network span both US datacenters (ash and hil)? Or must you create separate networks per location?
- Attaching a server to the network: `network` block inside `hcloud_server`, or separate `hcloud_server_network` resource
- `hcloud_server_network` resource: `server_id`, `network_id`, `ip` (static assignment), `alias_ips`
- Private IP assignment: how to get the private IP (`hcloud_server_network.nodes.ip`)
- Using private IPs for Flannel: K3s `--flannel-iface` should reference the private network interface (not eth0)
- Private network interface name on AlmaLinux 9: what interface name Hetzner assigns for private networks (typically `enp7s0` or `eth1`)

---

### HCT-6. hcloud_volume and hcloud_volume_attachment

Persistent block storage:

```hcl
resource "hcloud_volume" "minio" {
  name      = "helix-minio-storage"
  size      = 100  # GB
  location  = "ash"
  format    = "xfs"
  labels = {
    managed-by = "opentofu"
    purpose    = "minio"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_volume_attachment" "minio" {
  volume_id = hcloud_volume.minio.id
  server_id = hcloud_server.cp.id
  automount = false  # we mount manually via Ansible
}
```

Document:
- `hcloud_volume`: `name`, `size`, `location`, `format` (`"ext4"` or `"xfs"`), `server_id` (optional, attach at creation)
- `hcloud_volume_attachment`: `volume_id`, `server_id`, `automount`
- `automount = false` vs `true`: always use false — Ansible manages the mount point (`/etc/fstab` entry)
- `linux_device` computed attribute: the device path (e.g., `/dev/sdb`) — output this for Ansible to use
- Computed `linux_device` in output: how to make it available for Ansible to format and mount
- Volume resizing: increasing size (never decrease) — `tofu apply` after changing `size`
- `prevent_destroy = true` is mandatory for volumes with data — a destroyed volume loses all data permanently

---

### HCT-7. hcloud_placement_group

Ensuring servers are on different physical hosts:

```hcl
resource "hcloud_placement_group" "cluster" {
  name   = "helix-cluster-spread"
  type   = "spread"
  labels = {
    managed-by = "opentofu"
  }
}
```

- `type = "spread"`: ensures servers in the group are on different physical machines
- Attaching servers: `placement_group_id = hcloud_placement_group.cluster.id` in `hcloud_server`
- Limitation: maximum 10 servers per placement group
- Why this matters: if helix-stax-cp and helix-stax-vps are on the same physical host, a hardware failure takes both down

---

### HCT-8. Importing Existing Hetzner Resources

We have existing servers (helix-stax-cp, helix-stax-vps) that were created manually or by a previous OpenTofu run. Importing them into state:

**Import commands:**
```bash
# Server
tofu import hcloud_server.cp <server_id>

# SSH key
tofu import hcloud_ssh_key.wakeem <ssh_key_id>

# Firewall
tofu import hcloud_firewall.k3s_nodes <firewall_id>

# Network
tofu import hcloud_network.cluster <network_id>

# Volume
tofu import hcloud_volume.minio <volume_id>
```

**Finding resource IDs:**
- `hcloud server list -o json | jq '.[] | {name: .name, id: .id}'`
- `hcloud ssh-key list -o json | jq '.[] | {name: .name, id: .id}'`
- API: `GET /servers`, `GET /ssh_keys`, etc.

**Import blocks (OpenTofu 1.6+ native import):**
```hcl
import {
  to = hcloud_server.cp
  id = "12345678"  # server ID
}
```
- This approach creates a plan for the import rather than running it immediately
- How to use `tofu plan -generate-config-out=generated.tf` to auto-generate resource HCL from the existing server
- Caveats: generated HCL may include attributes that force replacement on first apply — review carefully

---

### HCT-9. Module Patterns: hetzner-server Module

We have (or will have) a reusable `opentofu/modules/hetzner-server/` module. Document the ideal structure:

**Module inputs (`variables.tf`):**
```hcl
variable "server_name"        { type = string }
variable "server_type"        { type = string, default = "cpx31" }
variable "location"           { type = string, default = "ash" }
variable "image"              { type = string, default = "alma-9" }
variable "ssh_key_ids"        { type = list(string) }
variable "firewall_ids"       { type = list(string), default = [] }
variable "network_id"         { type = string, default = null }
variable "private_ip"         { type = string, default = null }
variable "user_data"          { type = string, default = "" }
variable "labels"             { type = map(string), default = {} }
variable "placement_group_id" { type = string, default = null }
variable "prevent_destroy"    { type = bool, default = false }
```

**Module outputs (`outputs.tf`):**
```hcl
output "id"           { value = hcloud_server.this.id }
output "ipv4_address" { value = hcloud_server.this.ipv4_address }
output "name"         { value = hcloud_server.this.name }
output "status"       { value = hcloud_server.this.status }
```

**Module usage:**
```hcl
module "cp" {
  source = "../modules/hetzner-server"

  server_name        = "helix-stax-cp"
  server_type        = "cpx31"
  location           = "ash"
  image              = "alma-9"
  ssh_key_ids        = [hcloud_ssh_key.wakeem.id]
  firewall_ids       = [hcloud_firewall.k3s_nodes.id]
  network_id         = hcloud_network.cluster.id
  labels             = { role = "control-plane", environment = "prod" }
  placement_group_id = hcloud_placement_group.cluster.id
  prevent_destroy    = true
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_user  = var.admin_user
    ssh_pub_key = var.ssh_public_key
  })
}
```

Provide the complete module `main.tf` with all conditional logic (optional network attachment, optional placement group).

---

### HCT-10. Cloud-init Templates with OpenTofu

Using `templatefile()` for dynamic cloud-init:

**Template file (`templates/cloud-init.yml.tpl`):**
```yaml
#cloud-config
users:
  - name: ${admin_user}
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_pub_key}
    shell: /bin/bash
package_update: true
packages:
  - python3
  - git
  - curl
write_files:
  - path: /etc/ssh/sshd_config.d/99-harden.conf
    content: |
      Port 2222
      PermitRootLogin no
      PasswordAuthentication no
runcmd:
  - systemctl restart sshd
  - setenforce 1
```

Document:
- `templatefile()` function: `templatefile("${path.module}/templates/cloud-init.yml.tpl", { ... })`
- Escaping in templates: how to escape `${}` in cloud-init YAML that isn't a template variable
- AlmaLinux 9 cloud-init differences from Ubuntu:
  - No `apt` — cloud-init uses `dnf` module
  - AlmaLinux cloud image may already have Python 3 — verify before adding to packages list
  - SELinux: does `runcmd: setenforce 1` work during cloud-init? Or is it already enforcing?
- `user_data` and `ignore_changes`: why you should `ignore_changes = [user_data]` after first apply
- Testing cloud-init before applying to production: using helix-stax-test to validate the template
- cloud-init status check in Ansible: `cloud-init status --wait` — confirming cloud-init completed before running Ansible

---

### HCT-11. Dynamic Ansible Inventory from OpenTofu Outputs

After `tofu apply`, we need Ansible to know the server IPs and metadata. Two approaches:

**Approach 1: OpenTofu outputs → JSON → Ansible extra vars**
```hcl
# outputs.tf
output "cp_ip" {
  value = module.cp.ipv4_address
}
output "vps_ip" {
  value = module.vps.ipv4_address
}
output "test_ip" {
  value = module.test[0].ipv4_address
  # count = 0 when not creating test server
}
```

```bash
# After tofu apply:
tofu output -json > infra.json
ansible-playbook -e @infra.json site.yml
```

**Approach 2: Hetzner dynamic inventory plugin**
The `hetzner.hcloud` Ansible collection has an inventory plugin that queries the Hetzner API directly and groups servers by labels:

```yaml
# hcloud.yml
plugin: hetzner.hcloud.hcloud
token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"
groups:
  control_plane:
    filters:
      label:
        role: control-plane
  workers:
    filters:
      label:
        role: worker
```

Document both approaches:
- Approach 1: complete `outputs.tf`, the `tofu output -json` pipeline, and Ansible `--extra-vars @infra.json`
- Approach 2: `hcloud.yml` inventory plugin configuration, `ansible-inventory --list -i hcloud.yml` command, label-to-group mapping
- When to use Approach 1 vs 2:
  - Approach 1: better for CI pipelines (deterministic, doesn't require live Hetzner API call during Ansible run)
  - Approach 2: better for ongoing operations (always reflects current server state)
- Combining both: using Approach 2 for connection details and Approach 1 for specific variable values (IPs, IDs)

**`local_file` resource for generating inventory:**
```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yml.tpl", {
    cp_ip  = module.cp.ipv4_address
    vps_ip = module.vps.ipv4_address
  })
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"
}
```

---

### HCT-12. Test Server Pattern

The ephemeral test server (helix-stax-test) pattern for CI:

**OpenTofu `test/` environment:**
```hcl
# opentofu/environments/test/main.tf

variable "create_test_server" {
  type    = bool
  default = false
}

resource "hcloud_server" "test" {
  count       = var.create_test_server ? 1 : 0
  name        = "helix-stax-test"
  server_type = "cx22"
  image       = "alma-9"
  location    = "ash"
  ssh_keys    = [data.hcloud_ssh_key.wakeem.id]
  labels = {
    purpose    = "molecule-test"
    created-by = "ci"
    managed-by = "opentofu"
  }
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_user  = "wakeem"
    ssh_pub_key = var.ssh_public_key
  })
}

output "test_server_ip" {
  value = var.create_test_server ? hcloud_server.test[0].ipv4_address : ""
}
```

Document:
- The `count = var.create_test_server ? 1 : 0` pattern for conditional server creation
- Why use a separate `test/` environment instead of a module flag: isolated state file, no risk to prod state
- GitHub Actions integration: `tofu apply -auto-approve -var="create_test_server=true"` then `tofu output -raw test_server_ip`
- Cleanup: `tofu destroy -auto-approve` after test (destroy entire test environment — no risk since prod is in separate state)
- SSH key for CI: a CI-specific SSH key pair generated per workflow run (or a long-lived CI key stored as GitHub secret)
- Wait for SSH: using `nc` or a shell loop to wait for port 2222 to become accessible before running Molecule

---

### HCT-13. State Management for Hetzner Resources

State considerations specific to Hetzner resources:

**State file structure:**
- Each environment (`prod/`, `test/`) has its own state file in MinIO
- Bucket: `tofu-state`, keys: `prod/terraform.tfstate`, `test/terraform.tfstate`
- Never mix prod and test in the same state file

**Drift detection:**
- `tofu plan -refresh-only`: detect configuration drift (e.g., someone changed a firewall rule via hcloud CLI)
- Common drift sources: manual hcloud CLI changes during incidents, Hetzner auto-updates to images
- `ignore_changes`: when to suppress drift detection (`user_data` is the primary case for servers)

**Resource replacement (forces new resource):**
- Changes that REPLACE a server (cause downtime): `server_type` change (resize), `image` change (rebuild), `location` change, `placement_group_id` change
- Changes that do NOT replace: `name`, `labels`, `firewall_ids` (usually), `user_data` (with `ignore_changes`)
- `tofu plan` output: "forces replacement" warning — always review before applying server changes
- `tofu apply -replace=hcloud_server.cp`: intentionally replace a server (e.g., forced rebuild)

**Protecting production resources:**
- `prevent_destroy = true` on all production servers and volumes: prevents `tofu destroy` from deleting them
- `tofu state rm`: removing a resource from state without deleting it (for migrating to new resource definition)
- State lock: MinIO-backed state does NOT support DynamoDB locking — document the manual lock workaround or use workspace isolation

---

### HCT-14. Server Rebuild Workflow

When we need to rebuild a server (fresh OS install):

**Option A: tofu destroy + tofu apply**
- Destroys the server permanently, creates a new one
- Gets a new IP address (unless using a floating IP)
- DNS must be updated

**Option B: hcloud server rebuild**
- Rebuilds the OS in-place without changing the IP
- Done outside OpenTofu via hcloud CLI (then `tofu apply` to update state if image changes)
- `hcloud server rebuild <server_id> --image alma-9`
- Does not change IP, SSH host key changes (need to remove from known_hosts)

**Option C: tofu apply -replace**
- `tofu apply -replace=hcloud_server.cp`
- OpenTofu creates new server, then destroys old (or destroy then create, depending on resource)
- For servers without floating IP, IP changes — DNS must be updated

**Recommendation for our setup:**
- During initial build (before production): destroy + apply (clean slate)
- During production (IP matters): `hcloud server rebuild` to preserve IP, then run Ansible to re-provision

**Step-by-step runbook:** "Rebuild helix-stax-cp with fresh AlmaLinux 9.7 without changing its IP"

---

### HCT-15. Cost Estimation

**Hetzner pricing for our setup:**
- helix-stax-cp (cpx31): ~$12.99/month
- helix-stax-vps (cpx31): ~$12.99/month
- helix-stax-test (cx22): ~$5.99/month when running; destroy when not in use
- Volumes: ~$0.054/GB/month (100GB volume = ~$5.40/month)
- IPv4 addresses: included with server (verify current policy — Hetzner has changed pricing on IPs)
- Backups: 20% of server price per month — we do NOT use Hetzner backups (use Velero instead)

**CI test server cost:**
- cx22 at $5.99/month = ~$0.0082/hour
- A 30-minute Molecule test run = ~$0.004 per run
- 100 CI runs/month = ~$0.41 in test server costs — negligible

**Pricing API:**
- `GET https://api.hetzner.cloud/v1/pricing` — returns current pricing for all resources
- Use in a shell script to calculate estimated monthly cost before provisioning

---

### Best Practices & Anti-Patterns

- What are the top 10 best practices for using OpenTofu with Hetzner Cloud in production?
- What are the most common mistakes with the hcloud provider? Rank by severity (critical → low).
- What OpenTofu configurations look correct but silently cause problems with Hetzner (eventual consistency, firewall timing, etc.)?
- What defaults should NEVER be used in production (e.g., not setting `prevent_destroy`, not using placement groups)?
- What are the performance anti-patterns that slow down `tofu apply` for Hetzner resources?
- When should you use `tofu apply -target=hcloud_server.cp` vs a full apply?

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| `firewall_ids` vs `hcloud_firewall_attachment` | Firewall and server created together | `firewall_ids` in server resource | Simpler, atomic |
| `firewall_ids` vs `hcloud_firewall_attachment` | Attaching existing firewall to existing server | `hcloud_firewall_attachment` | No replacement required |
| `count` vs `for_each` for multiple servers | Simple list of similar servers | `count` | Simpler |
| `count` vs `for_each` for diverse servers | Each server has unique attributes | `for_each` | Cleaner state keys, easier to add/remove |
| `local_file` inventory vs `hcloud.yml` dynamic | CI pipeline | `local_file` (from outputs) | Deterministic, no live API call |
| `local_file` inventory vs `hcloud.yml` dynamic | Day-to-day operations | `hcloud.yml` dynamic | Always current |
| `tofu destroy` + `tofu apply` vs rebuild | IP can change | Destroy + apply | Cleaner state |
| `tofu destroy` + `tofu apply` vs rebuild | IP must stay same | `hcloud server rebuild` | Preserves IP |
| Prod and test in same state | Never | Never | Risk of `tofu destroy` deleting prod |
| Prod and test in same state | Separate environments | Separate state files | Isolation |
| `prevent_destroy` on servers | Production servers | Always | Prevents accidental deletion |
| `prevent_destroy` on servers | Test servers | Never | Must be destroyable for cleanup |
| Private network | Single server (no inter-node comms) | Skip | Unnecessary overhead |
| Private network | Multi-node K3s cluster | Add private network | Keep node-to-node off public internet |

### Common Pitfalls

- Not setting `ignore_changes = [user_data]`: cloud-init changes trigger server replacement — always ignore user_data after first apply
- `prevent_destroy = false` on production servers: `tofu destroy` in CI or a typo can delete the CP server
- Server replacement unexpected: changing `server_type` causes replacement and downtime — always review plan for "forces replacement"
- hcloud provider not available in OpenTofu registry: verify `registry.opentofu.org/hetznercloud/hcloud` exists before writing code
- State lock with MinIO: MinIO doesn't support DynamoDB-compatible locking — document team protocol for state access (one operator at a time)
- Wrong location string: OpenTofu uses short location names (`ash`, `hil`) but hcloud CLI uses `ash-dc1`, `hil-dc1` — don't confuse them
- Firewall attachment timing: firewall is attached but takes a few seconds to propagate — don't run SSH immediately after `tofu apply`
- Volume attachment and `automount`: `automount = true` will mount the volume at a random path — always use `false` and let Ansible manage mounts
- Mixing prod and test in same state file: `tofu destroy -target=hcloud_server.test` accidentally can destroy other resources
- Not outputting server IPs: forgetting `output "cp_ip"` means Ansible can't get the IP from `tofu output`

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- hcloud provider version and required_providers block
- Key resource types quick reference (server, firewall, ssh_key, network, volume)
- Common lifecycle rules and when to use them
- Output patterns for Ansible integration
- Troubleshooting decision tree (plan fails → diagnosis → fix; provider not found; state drift)
- Integration points: SOPS+age, MinIO state, hcloud CLI, Ansible
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete `hcloud_server` resource schema with all arguments and computed attributes
- Complete `hcloud_firewall` rule schema
- Complete `hcloud_network` + `hcloud_network_subnet` schema
- Complete `hcloud_volume` + `hcloud_volume_attachment` schema
- Required providers block with current version
- Import commands for all resource types
- Location strings: OpenTofu vs hcloud CLI naming differences
- Server type reference table with pricing

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our servers (helix-stax-cp at 178.156.233.12, helix-stax-vps at 5.78.145.30, helix-stax-test as temp), locations (ash, hil), user `wakeem`
- Complete `opentofu/environments/prod/main.tf` defining helix-stax-cp and helix-stax-vps with all resources
- Complete `opentofu/modules/hetzner-server/` module (main.tf, variables.tf, outputs.tf)
- Complete `opentofu/environments/test/main.tf` for ephemeral test server
- Complete `cloud-init.yml.tpl` template for AlmaLinux 9 with `wakeem` user setup
- Complete `outputs.tf` for Ansible integration (IP addresses, IDs)
- Complete Ansible `hcloud.yml` dynamic inventory for our label scheme
- `local_file` resource generating `ansible/inventory/hosts.yml`
- Step-by-step runbook: "Rebuild helix-stax-cp with fresh OS without changing IP"
- Step-by-step runbook: "Import manually-created Hetzner server into OpenTofu state"
- GitHub Actions job: `tofu apply` → capture outputs → pass to Molecule → `tofu destroy`

Use `# OpenTofu Hetzner Provider` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual HCL resource blocks, actual `templatefile()` usage, actual module interfaces, and actual import commands. Do NOT give theory — give copy-paste-ready OpenTofu configurations for managing Hetzner Cloud servers running AlmaLinux 9.7 for a K3s cluster.
