# OpenTofu Hetzner Provider

## SKILL.md Content
This is the core reference document for an AI agent to use daily. It contains concise, actionable information for managing Hetzner Cloud resources with OpenTofu.

### HCT-1. Provider Configuration

**Required `providers.tf` Block**
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49" # Allows patch updates, pins minor version
    }
  }
}
```

**State Backend (MinIO)**
```hcl
terraform {
  backend "s3" {
    bucket               = "tofu-state"
    key                  = "prod/terraform.tfstate" # "test/terraform.tfstate" for test env
    region               = "us-east-1" # S3 region is arbitrary for MinIO
    endpoint             = "https://minio.your-domain.com"
    access_key           = "your-minio-access-key" # Use env vars in production
    secret_key           = "your-minio-secret-key" # Use env vars in production
    skip_region_validation = true
    skip_credentials_validation = true
  }
}
```

**Authentication**
- The provider automatically uses the `HCLOUD_TOKEN` environment variable.
- Do NOT hardcode the token in the provider block.

### Key Resource Quick Reference

**Server (`hcloud_server`)**
```hcl
resource "hcloud_server" "cp" {
  name        = "helix-stax-cp"
  server_type = "cpx31"
  image       = "alma-9"
  location    = "ash"
  ssh_keys    = [data.hcloud_ssh_key.wakeem.id]
  firewall_ids = [hcloud_firewall.k3s_nodes.id]
  labels = {
    role = "control-plane",
    env  = "prod"
  }
  user_data = "..." # From templatefile()

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [user_data]
  }
}
```

**Firewall (`hcloud_firewall`)**
```hcl
resource "hcloud_firewall" "k3s_nodes" {
  name = "k3s-nodes"
  
  # Allow SSH on port 2222
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2222"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  
  # Allow K3s API
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Default egress is ALLOW ALL. No "out" rules needed for general internet access.
}
```

**SSH Key (Data Source for existing key)**
```hcl
data "hcloud_ssh_key" "wakeem" {
  name = "wakeem-helix"
}
```

**Private Network (`hcloud_network` + `hcloud_network_subnet`)**
```hcl
resource "hcloud_network" "cluster" {
  name     = "helix-cluster-network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "nodes_ash" {
  network_id   = hcloud_network.cluster.id
  type         = "server"
  network_zone = "us-east" # 'ash' is in us-east
  ip_range     = "10.10.1.0/24"
}
```
Attach to server with a `network` block:
```hcl
resource "hcloud_server" "cp" {
  # ...
  network {
    network_id = hcloud_network.cluster.id
    ip         = "10.10.1.10" # Optional static IP
  }
}
```

**Volume (`hcloud_volume` + `hcloud_volume_attachment`)**
```hcl
resource "hcloud_volume" "minio_data" {
  name     = "minio-data-vol"
  size     = 100 # GB
  location = "ash" # Must match server location
  format   = "xfs"

  lifecycle { prevent_destroy = true }
}

resource "hcloud_volume_attachment" "minio" {
  volume_id = hcloud_volume.minio_data.id
  server_id = hcloud_server.cp.id
  automount = false # Critical: let Ansible manage fstab
}
```

### Common Lifecycle Rules

- `prevent_destroy = true`: Use on all production servers (`hcloud_server`) and volumes (`hcloud_volume`) to prevent accidental deletion by `tofu destroy`.
- `ignore_changes = [user_data]`: Use on all servers. Cloud-init `user_data` only runs on the first boot. Ignoring subsequent changes prevents OpenTofu from trying to replace the server if the template changes.

### Ansible Integration

**Method 1: Generate Inventory with `local_file`**
- **Use Case:** CI/CD pipelines. Creates a static, deterministic inventory from the last `tofu apply`.
- **`outputs.tf`:**
  ```hcl
  output "ansible_inventory_hosts" {
    value = {
      control_plane = {
        hosts = {
          (module.cp.name) = {
            ansible_host = module.cp.ipv4_address
          }
        }
      }
      workers = {
        hosts = {
          (module.vps.name) = {
            ansible_host = module.vps.ipv4_address
          }
        }
      }
    }
  }
  ```
- **`main.tf`:**
  ```hcl
  resource "local_file" "ansible_inventory" {
    content  = yamlencode(output.ansible_inventory_hosts)
    filename = "${path.root}/../ansible/inventory/gen_hosts.yml"
  }
  ```

**Method 2: Dynamic Inventory Plugin**
- **Use Case:** Ad-hoc commands, daily operations. Always queries the live API state.
- **`ansible/inventory/hcloud.yml`:**
  ```yaml
  plugin: hetzner.hcloud.hcloud
  token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"
  groups:
    k3s_control_plane: 'role == "control-plane"'
    k3s_workers: 'role == "worker"'
  ```

### Troubleshooting

| Symptom | Diagnosis | Fix |
| :--- | :--- | :--- |
| `tofu plan` shows "forces replacement" for a server | You changed `image`, `server_type`, `location`, `placement_group_id`, or `network`. | This is expected behavior. If unintentional, revert the change. If intentional, prepare for downtime and IP change (unless using Floating IPs). |
| `tofu plan` shows changes to `user_data` | `ignore_changes = [user_data]` is missing from the server's `lifecycle` block. | Add `ignore_changes = [user_data]` to the `hcloud_server` resource's `lifecycle` block. |
| `tofu init` fails with "could not find provider" | The `source` address in `required_providers` is wrong or `registry.opentofu.org` is unreachable. | Confirm `source = "hetznercloud/hcloud"`. Check network connectivity. |
| `tofu plan` shows drift (e.g., firewall rule changed) | Someone modified a resource using the Hetzner web console or `hcloud` CLI. | This is drift. Run `tofu apply` to revert the resource to its state defined in code. Investigate the manual change. |
| State command fails: "state lock" error | Another process or user is running an OpenTofu command against the same state file. | MinIO does not support native state locking. Establish a team protocol: one operator applies at a time. Use a CI/CD queue to serialize `apply` jobs. |

---

## reference.md Content
This is the deep specification reference, containing complete schemas, tables, and commands for advanced use cases.

### HCT-1. Provider Configuration Details

- **Current Stable Version**: `~> 1.49` (as of May 2024, check `registry.opentofu.org` for the latest).
- **Source Address**: `hetznercloud/hcloud`. This resolves correctly from `registry.opentofu.org`, which acts as a proxy/mirror for major providers.
- **Version Constraints**: `~> 1.49` is preferred for production. It accepts patch releases (e.g., `1.49.1`) but not minor releases (`1.50.0`) that could introduce breaking changes.
- **Multi-Provider Alias**: To use multiple Hetzner projects/accounts:
  ```hcl
  provider "hcloud" {
    # Default provider, uses HCLOUD_TOKEN
  }

  provider "hcloud" {
    alias = "staging"
    token = var.hcloud_staging_token
  }

  resource "hcloud_server" "staging_server" {
    provider = hcloud.staging
    # ...
  }
  ```
- **Lock File (`.opentofu.lock.hcl`)**: This file locks the specific provider versions and their hashes. Regenerate it with:
  ```bash
  # For Linux amd64 (CI) and macOS arm64 (dev)
  tofu providers lock -platform=linux_amd64 -platform=darwin_arm64
  ```
  The entry for `hcloud` will look like this:
  ```hcl
  provider "registry.opentofu.org/hetznercloud/hcloud" {
    version     = "1.49.2"
    constraints = "~> 1.49"
    hashes = [
      "h1:...",
      "zh:...", # Hashes for different platforms
    ]
  }
  ```

### HCT-2. hcloud_server Resource Schema

| Argument | Type | Description |
| :--- | :--- | :--- |
| **`name`** (req) | `string` | Unique name for the server in your project. |
| **`server_type`** (req) | `string` | Server type, e.g., `cpx31`, `cx22`. |
| **`image`** (req) | `string` | Image name (`alma-9`, `ubuntu-24.04`) or ID. |
| `location` | `string` | Location short name (`ash`, `hil`). |
| `datacenter` | `string` | Datacenter name (`ash-dc1`, `hil-dc1`). `location` is preferred. |
| `ssh_keys` | `list(string)` | List of `hcloud_ssh_key` names or IDs. |
| `user_data` | `string` | Cloud-init configuration. |
| `firewall_ids` | `list(number)` | List of `hcloud_firewall` IDs to attach. |
| `network` | `list(block)` | Block to attach server to a private network. Contains `network_id`, `ip`, `alias_ips`. |
| `labels` | `map(string)` | Key-value labels for the server. |
| `placement_group_id`| `number` | ID of an `hcloud_placement_group`. |
| `keep_disk` | `bool` | If true, do not resize disk on downsacle. Default `false`. |
| `public_net` | `block` | Configure public networking. Contains `ipv4_enabled`, `ipv6_enabled`, `ipv4`, `ipv6`. |
| `backups` | `bool` | Enable Hetzner's paid backup service. Default `false`. |
| `ignore_remote_actual_size` |`bool` | Suppress diff on disk size drift. Default `false`. |

**Computed Attributes**
| Attribute | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Unique server ID. |
| `ipv4_address` | `string` | Public IPv4 address. |
| `ipv6_address` | `string` | Public IPv6 address. |
| `ipv6_network` | `string` | The /64
| `status` | `string` | Server status (`running`, `off`). |
| `private_net` | `list(object)`| List of private networks, each with `ip`, `mac_address`, `network_id`. |

### HCT-3. hcloud_firewall Resource Schema

| Argument | Type | Description |
| :--- | :--- | :--- |
| **`name`** (req) | `string` | Unique name for the firewall. |
| `rule` | `list(block)` | List of rule blocks defining traffic policy. |
| `apply_to` | `list(block)` | Apply firewall using label selectors instead of attaching to servers individually. |
| `labels` | `map(string)` | Key-value labels for the firewall. |

**`rule` Block Schema**
| Argument | Type | Description |
| :--- | :--- | :--- |
| **`direction`** (req) | `string` | `in` or `out`. |
| **`protocol`** (req) | `string` | `tcp`, `udp`, `icmp`, `esp`, `gre`. |
| `port` | `string` | Port number or range (`"22"`, `"80-443"`). Not used for `icmp`. |
| `source_ips` | `list(string)` | List of CIDRs. For `direction = "in"`. |
| `destination_ips`| `list(string)` | List of CIDRs. For `direction = "out"`. |
| `description` | `string` | Optional description for the rule. |

**Default Egress Policy**: If no `out` rules are defined, **all outbound traffic is allowed**. This is a critical distinction from AWS security groups.

### HCT-5. Network and Location Naming

| Datacenter (hcloud CLI) | Location (OpenTofu) | Network Zone (OpenTofu) |
| :--- | :--- | :--- |
| `ash-dc1` | `ash` | `us-east` |
| `hil-dc1` | `hil` | `us-west` |
| `fsn1-dc14` | `fsn1` | `eu-central` |
| `nbg1-dc3` | `nbg1` | `eu-central` |
| `hel1-dc2` | `hel1` | `eu-central` |

**Multi-Location Networks:** A single `hcloud_network` is a regional construct. Subnets must be created within that region's zones. A `us-east` network cannot have a `us-west` subnet. To connect servers in `ash` and `hil`, you must provision two separate networks and connect them with a VPN or other overlay.

### HCT-8. Importing Existing Resources

**Option 1: `tofu import` Command**
1. Get the resource ID from the `hcloud` CLI (`hcloud server list`, `hcloud firewall list`, etc).
2. Write the resource block in your `.tf` file as if you were creating it.
3. Run the import command.
   ```bash
   # Example for server
   HCLOUD_ID=$(hcloud server list -o json | jq -r '.[] | select(.name=="helix-stax-cp") | .id')
   tofu import hcloud_server.cp $HCLOUD_ID
   ```

**Option 2: `import` Block (OpenTofu 1.6+)**
This is the recommended, safer method.
1. Add an `import` block to your configuration.
   ```hcl
   # opentofu/environments/prod/imports.tf
   import {
     to = hcloud_server.cp
     id = "178051234" # Get from `hcloud server list`
   }
   ```
2. Run `tofu plan -generate-config-out=generated.tf`. OpenTofu will inspect the real resource and write its configuration to `generated.tf`.
3. Review `generated.tf`, copy the relevant attributes to your main resource block, and delete `generated.tf` and the `import` block. Be careful of read-only attributes that might cause replacement issues.
4. Run `tofu apply` to formally adopt the resource into the state.

### HCT-15. Server Type Reference (US Locations)

| Server Type | vCPU | RAM (GB) | Disk (GB) | Price/Month (USD, approx.) |
| :--- | :--- | :--- | :--- | :--- |
| `cx22` | 2 AMD | 4 | 40 | $6 |
| **`cpx31`** | **4 AMD** | **8** | **160** | **$13** |
| `cpx41` | 8 AMD | 16 | 240 | $25 |
| `cpx51` | 16 AMD | 32 | 360 | $50 |

*Prices as of May 2024. Check `https://api.hetzner.cloud/v1/pricing` for live data.*

---

## examples.md Content
Copy-paste-ready examples for the Helix Stax infrastructure.

### Complete `opentofu/environments/prod/main.tf`
Defines the production control plane and worker node.
```hcl
# opentofu/environments/prod/main.tf

# --- Provider and Backend Configuration ---
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
  backend "s3" {
    bucket                      = "tofu-state"
    key                         = "prod/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = var.minio_endpoint
    access_key                  = var.minio_access_key
    secret_key                  = var.minio_secret_key
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

# --- Data Sources ---
# Look up our admin SSH key, which is managed outside this state file
data "hcloud_ssh_key" "wakeem" {
  name = "wakeem-helix"
}

# --- Networking ---
resource "hcloud_network" "cluster" {
  name     = "helix-cluster-network"
  ip_range = "10.0.0.0/8"
  labels   = { "managed-by" = "opentofu" }
}

resource "hcloud_network_subnet" "ashburn_subnet" {
  network_id   = hcloud_network.cluster.id
  type         = "server"
  network_zone = "us-east" # For ash-dc1
  ip_range     = "10.10.1.0/24"
}

resource "hcloud_network_subnet" "hillsboro_subnet" {
  network_id   = hcloud_network.cluster.id
  type         = "server"
  network_zone = "us-west" # For hil-dc1
  ip_range     = "10.10.2.0/24"
}

# --- Security ---
resource "hcloud_firewall" "k3s_nodes" {
  name   = "k3s-nodes"
  labels = { "managed-by" = "opentofu" }

  # Allow SSH from anywhere (hardened via cloud-init to port 2222)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2222"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "SSH Access"
  }

  # Allow K3s API server from anywhere
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "K3s API Server"
  }

  # Allow Flannel VXLAN for inter-node communication
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "8472"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Flannel VXLAN"
  }
  
  # Allow all ICMP for ping/troubleshooting
  rule {
    direction = "in"
    protocol = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow ICMP"
  }
}

# --- High Availability ---
resource "hcloud_placement_group" "cluster_spread" {
  name   = "helix-cluster-spread"
  type   = "spread" # Ensures servers are on different physical hosts
  labels = { "managed-by" = "opentofu" }
}

# --- Servers ---
module "cp" {
  source = "../../modules/hetzner-server"

  server_name        = "helix-stax-cp"
  server_type        = "cpx31"
  location           = "ash"
  image              = "alma-9"
  ssh_key_ids        = [data.hcloud_ssh_key.wakeem.id]
  firewall_ids       = [hcloud_firewall.k3s_nodes.id]
  network_id         = hcloud_network.cluster.id
  private_ip         = "10.10.1.10"
  placement_group_id = hcloud_placement_group.cluster_spread.id
  labels             = { role = "control-plane", env = "prod", "managed-by" = "opentofu" }
  prevent_destroy    = true
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_user  = "wakeem"
    ssh_pub_key = var.ssh_public_key
  })
}

module "vps" {
  source = "../../modules/hetzner-server"

  server_name        = "helix-stax-vps"
  server_type        = "cpx31"
  location           = "hil"
  image              = "alma-9"
  ssh_key_ids        = [data.hcloud_ssh_key.wakeem.id]
  firewall_ids       = [hcloud_firewall.k3s_nodes.id]
  network_id         = hcloud_network.cluster.id
  private_ip         = "10.10.2.10"
  placement_group_id = hcloud_placement_group.cluster_spread.id
  labels             = { role = "worker", env = "prod", "managed-by" = "opentofu" }
  prevent_destroy    = true
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    admin_user  = "wakeem"
    ssh_pub_key = var.ssh_public_key
  })
}

# --- Storage for Control Plane ---
resource "hcloud_volume" "minio_storage" {
  name      = "helix-minio-storage"
  size      = 100 # GB
  location  = "ash" # Must match the control plane server's location
  format    = "xfs"
  labels = {
    "managed-by" = "opentofu"
    purpose      = "minio"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_volume_attachment" "minio_attach" {
  volume_id = hcloud_volume.minio_storage.id
  server_id = module.cp.id
  automount = false # Let Ansible manage mounting via fstab for predictability
}
```

### Complete `opentofu/modules/hetzner-server/` Module

**`main.tf`**
```hcl
resource "hcloud_server" "this" {
  name               = var.server_name
  server_type        = var.server_type
  image              = var.image
  location           = var.location
  ssh_keys           = var.ssh_key_ids
  firewall_ids       = var.firewall_ids
  placement_group_id = var.placement_group_id
  user_data          = var.user_data
  labels             = var.labels

  # Conditionally attach to a private network
  dynamic "network" {
    for_each = var.network_id != null ? [1] : []
    content {
      network_id = var.network_id
      ip         = var.private_ip
    }
  }

  lifecycle {
    prevent_destroy = var.prevent_destroy
    ignore_changes  = [user_data]
  }
}
```

**`variables.tf`**
```hcl
variable "server_name" {
  description = "Name of the server."
  type        = string
}

variable "server_type" {
  description = "Hetzner server type."
  type        = string
  default     = "cpx31"
}

variable "image" {
  description = "Operating system image for the server."
  type        = string
  default     = "alma-9"
}

variable "location" {
  description = "Datacenter location for the server."
  type        = string
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs to install on the server."
  type        = list(string)
}

variable "firewall_ids" {
  description = "List of firewall IDs to attach to the server."
  type        = list(number)
  default     = []
}

variable "network_id" {
  description = "The ID of the private network to attach."
  type        = string
  default     = null
}

variable "private_ip" {
  description = "The static private IP to assign within the network."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Cloud-init user data script."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Map of labels to apply to the server."
  type        = map(string)
  default     = {}
}

variable "placement_group_id" {
  description = "ID of the placement group."
  type        = string
  default     = null
}

variable "prevent_destroy" {
  description = "Set to true to prevent accidental destruction of the server."
  type        = bool
  default     = false
}
```

**`outputs.tf`**
```hcl
output "id" {
  description = "The ID of the server."
  value       = hcloud_server.this.id
}

output "name" {
  description = "The name of the server."
  value       = hcloud_server.this.name
}

output "ipv4_address" {
  description = "The public IPv4 address of the server."
  value       = hcloud_server.this.ipv4_address
}

output "private_ip" {
  description = "The private IP address of the server, if attached to a network."
  value       = hcloud_server.this.network[0].ip
}

output "status" {
  description = "The status of the server."
  value       = hcloud_server.this.status
}
```

### Complete `cloud-init.yml.tpl` Template for AlmaLinux 9
```yaml
#cloud-config
# Template for AlmaLinux 9.7 on Hetzner

# 1. User setup
# Create admin user, give it passwordless sudo, and add the SSH public key.
users:
  - name: ${admin_user}
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_pub_key}
    shell: /bin/bash

# 2. Package management
# Ensure the system is up-to-date and install core packages needed for Ansible/other tools.
package_update: true
packages:
  - python3
  - git
  - curl
  - firewalld

# 3. File and configuration writing
# Harden SSH configuration.
write_files:
  - path: /etc/ssh/sshd_config.d/99-helix-harden.conf
    permissions: '0644'
    content: |
      # Helix Stax SSH Hardening
      Port 2222
      PermitRootLogin no
      PasswordAuthentication no
      PubkeyAuthentication yes
      ChallengeResponseAuthentication no
      UsePAM no
      X11Forwarding no

# 4. Commands to run
# Apply changes and manage services.
runcmd:
  # Enable and start firewalld
  - [ systemctl, "enable", "firewalld", "--now" ]
  # Set SELinux to enforcing mode. The cloud image should already have this, but it's good to be explicit.
  - [ setenforce, "1" ]
  # Persist SELinux state change
  - [ sed, -i, 's/^SELINUX=.*/SELINUX=enforcing/g', /etc/selinux/config ]
  # Restart sshd to apply new port and config
  - [ systemctl, "restart", "sshd" ]
```

### Runbook: Rebuild `helix-stax-cp` with a fresh OS without changing its IP

This process uses the `hcloud` CLI to preserve the server's identity and IP address.

1.  **Isolate the Server:** If possible, drain workloads from `helix-stax-cp`.
2.  **Get Server ID**:
    ```bash
    hcloud server list --selector 'role==control-plane' -o json | jq -r '.[0].id'
    # Expected output: an integer ID like 178051234
    ```
3.  **Execute the Rebuild**: Using the `hcloud` CLI, issue the rebuild command. This is a destructive operation for that server's disk. The IP will be preserved.
    ```bash
    # Replace <server_id> with the ID from the previous step
    hcloud server rebuild <server_id> --image alma-9
    ```
4.  **Wait for Rebuild:** Monitor the server status in the Hetzner Cloud console or via `hcloud server describe <server_id>`. It will power off, rebuild, and power back on.
5.  **Clear SSH Host Key**: The server's SSH host key will have changed. Remove the old one from your `known_hosts` file.
    ```bash
    ssh-keygen -R 178.156.233.12
    ```
6.  **Verify Access**: Once the server is online, SSH into it to confirm cloud-init has completed and you can access it.
    ```bash
    ssh -p 2222 wakeem@178.156.233.12
    ```
7.  **Refresh OpenTofu State**: The `image` attribute in your OpenTofu state is now out of sync with reality. Run a refresh to update it without making changes.
    ```bash
    # In opentofu/environments/prod/
    tofu refresh
    # To confirm no changes, run a plan. It should report no changes are needed.
    tofu plan
    ```
8.  **Re-run Ansible**: The server is now a fresh slate. Run your Ansible playbooks to re-provision it completely.
    ```bash
    # In your ansible directory
    ansible-playbook -i inventory/gen_hosts.yml site.yml --limit helix-stax-cp
    ```

### GitHub Actions CI Job for Ephemeral Test Server

```yaml
# .github/workflows/test.yml
name: OpenTofu & Molecule Integration Test

on:
  pull_request:
    paths:
      - 'opentofu/**'
      - 'ansible/**'

jobs:
  molecule-test:
    name: Run Molecule Test on Ephemeral Server
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: latest

      - name: Provision Test Server
        id: provision
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
          TF_VAR_minio_endpoint: ${{ secrets.MINIO_ENDPOINT }}
          # ... other secrets for state backend ...
          TF_VAR_ssh_public_key: ${{ secrets.CI_SSH_PUBLIC_KEY }}
        run: |
          cd opentofu/environments/test
          tofu init
          tofu apply -auto-approve -var="create_test_server=true"
          echo "test_ip=$(tofu output -raw test_server_ip)" >> $GITHUB_OUTPUT

      - name: Wait for SSH
        run: |
          echo "Waiting for SSH on port 2222 at ${{ steps.provision.outputs.test_ip }}..."
          for i in {1..30}; do
            nc -z -w5 ${{ steps.provision.outputs.test_ip }} 2222 && break
            echo "Attempt $i failed, retrying..."
            sleep 5
          done

      # (Steps to set up Python and run Molecule tests would go here)
      - name: Run Ansible/Molecule Tests
        run: |
          echo "Running tests against ${{ steps.provision.outputs.test_ip }}"
          # Example: ansible-playbook -i "${{ steps.provision.outputs.test_ip }}," ...
          
      - name: Destroy Test Server
        if: always() # Always run cleanup, even if tests fail
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
          # ... other secrets for state backend ...
        run: |
          cd opentofu/environments/test
          tofu destroy -auto-approve
```
