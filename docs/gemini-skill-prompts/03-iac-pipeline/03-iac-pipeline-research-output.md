Of course. This is an excellent project for a Gemini Deep Research document. The detailed request provides a clear blueprint for creating a comprehensive and actionable knowledge base for your AI agents.

Here is the research, structured as requested.

***

# OpenTofu

## SKILL.md Content

### Core Workflow

The primary workflow couples OpenTofu and Ansible. Never run one without the other for new infrastructure.

1.  **Provision:** `tofu apply` creates/updates cloud resources (servers, DNS, firewalls).
2.  **Export:** `tofu output -json > infra.json` saves the resulting IPs and metadata.
3.  **Configure:** `ansible-playbook -i hcloud.yml -e @infra.json site.yml` consumes the outputs to configure the servers.

### CLI Quick Reference

**Initialize Project** (run once per new checkout or provider change)
`tofu init -backend-config="access_key=<MINIO_KEY>" -backend-config="secret_key=<MINIO_SECRET>"`

**Format Code** (run before commit)
`tofu fmt -recursive`

**Validate Syntax**
`tofu validate`

**Plan Changes** (dry-run)
`tofu plan -var-file="secrets.tfvars"`

**Apply Changes** (execute the plan)
`tofu apply -var-file="secrets.tfvars"`
`tofu apply -auto-approve # Use in CI/CD only`
`tofu apply -replace="hcloud_server.heart" # Force-recreate a specific resource`

**Destroy Infrastructure** (use with extreme caution)
`tofu destroy`
`tofu destroy -target="hcloud_server.helix-stax-vps"`

**Read Outputs**
`tofu output # Human-readable`
`tofu output -json # For scripting`
`tofu output control_plane_ip`

**State Management**
`tofu state list # See all resources in state`
`tofu state show 'hcloud_server.heart' # Show details for one resource`
`tofu state mv 'hcloud_server.worker_old' 'hcloud_server.worker_new' # Rename resource in state`
`tofu state rm 'hcloud_server.decommissioned' # Remove resource from state (does not delete resource)`

### Configuration Snippets

**MinIO S3 Backend (`backend.tf`)**
```hcl
terraform {
  backend "s3" {
    endpoint                    = "minio.helixstax.net" // Your MinIO endpoint
    bucket                      = "opentofu-state"
    key                         = "global/k3s/terraform.tfstate"
    region                      = "us-east-1" // MinIO doesn't use regions, but the field is required
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}
```

**Hetzner Provider (`providers.tf`)**
```hcl
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.46"
    }
  }
}

provider "hcloud" {
  # Token is supplied via HCLOUD_TOKEN environment variable
}
```

**Cloudflare Provider (`providers.tf`)**
```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.30"
    }
  }
}

provider "cloudflare" {
  # Token is supplied via CLOUDFLARE_API_TOKEN environment variable
}
```

### Troubleshooting Decision Tree

*   **Symptom:** `Error: "Could not lock state"`
    *   **Cause:** Another `tofu` process is running, or a previous run crashed without releasing the lock. MinIO connectivity might be down.
    *   **Fix:**
        1.  Ensure no other team member or CI job is running `tofu apply`.
        2.  Verify you can reach the MinIO endpoint.
        3.  If a crash occurred, you may need to manually delete the lock file in the MinIO bucket (use with caution).
*   **Symptom:** `Plan shows resource will be replaced, but no config changed.`
    *   **Cause:** Upstream resource (like a Hetzner image) was deleted/changed, or a sensitive value used in a non-sensitive field changed.
    *   **Fix:**
        1.  Run `tofu plan -refresh-only` to sync state with reality and get more info.
        2.  Inspect the plan output carefully to see *why* it wants to replace the resource. Update your HCL if an image name or ID has changed.
*   **Symptom:** `401 Unauthorized` errors from a provider.
    *   **Cause:** Missing or incorrect API token environment variable.
    *   **Fix:**
        1.  Ensure `HCLOUD_TOKEN` and/or `CLOUDFLARE_API_TOKEN` are exported in your shell.
        2.  Check that the tokens have the correct read/write permissions in their respective dashboards.
*   **Symptom:** `tofu init` fails with provider errors.
    *   **Cause:** Corrupt `.terraform/` or `.opentofu/` directory, or lock file issues.
    *   **Fix:**
        1.  Run `rm -rf .terraform/ .opentofu/ .terraform.lock.hcl .opentofu.lock.hcl`.
        2.  Run `tofu init` again.

## reference.md Content

### OT-1. CLI Reference

*   `tofu init`: Initializes a working directory.
    *   `-backend-config="key=value"`: Configure backend settings from CLI. Essential for passing secrets without saving them in the main config.
    *   `-reconfigure`: Forces re-initialization of the backend, discarding any existing configuration.
    *   `-upgrade`: Upgrades provider versions to the latest allowed by version constraints.
*   `tofu plan`: Creates an execution plan.
    *   `-out=tfplan`: Saves the plan to a file to be executed later by `tofu apply "tfplan"`.
    *   `-target=resource_type.name`: Creates a plan for a specific resource, ignoring others. Use for targeted fixes.
    *   `-var 'key=value'`: Sets an input variable from the CLI.
    *   `-var-file="filename.tfvars"`: Loads variables from a specified file.
    *   `-refresh-only`: Updates the state file with real-world infrastructure without planning any changes.
    *   `-destroy`: Creates a plan to destroy all managed resources.
*   `tofu apply`: Executes a plan.
    *   `[plan_file]`: Applies a saved plan file. If not provided, generates and applies a new plan.
    *   `-auto-approve`: Skips interactive approval. **DANGEROUS** outside of CI/CD.
    *   `-target=resource_type.name`: Applies changes to a specific resource only. Can cause drift if used improperly.
    *   `-parallelism=n`: Number of concurrent operations. Default is 10.
    *   `-replace=resource_address`: Instructs Tofu to replace a specific resource, even if no configuration changes require it.
*   `tofu state`: Advanced state management.
    *   `list [options]`: Lists resources in the state.
    *   `show [options] address`: Shows attributes of a single resource in state.
    *   `mv [options] source destination`: Moves an item in the state. Useful for renaming resources (`tofu state mv hcloud_server.old hcloud_server.new`).
    *   `rm [options] address...`: Removes an item from the state. Does not destroy the resource itself. Useful when Tofu gets confused and you need to re-import.
    *   `pull`: Dumps the entire remote state to stdout as JSON. `tofu state pull > state.json.backup`
    *   `push path`: Pushes a local state file to remote state. `tofu state push state.json.edited`
*   `tofu import [options] address id`: Imports an existing resource into the state.
    *   `address`: The resource address in your HCL (e.g., `hcloud_server.heart`).
    *   `id`: The provider-specific ID of the resource (e.g., the Hetzner server ID).
    *   Example: `tofu import hcloud_server.heart 1234567`
    *   Example: `tofu import 'cloudflare_record.www' a_zone_id/a_record_id`
*   `tofu output [options] [name]`: Reads an output value.
    *   `-json`: Outputs all values in JSON format.
    *   `-raw`: Outputs a single value in raw string format.
*   `tofu workspace`: Manages workspaces for environments.
    *   `new <NAME>`: Creates a new workspace.
    *   `list`: Lists existing workspaces.
    *   `select <NAME>`: Selects a workspace.
    *   `delete <NAME>`: Deletes a workspace.
*   `tofu test`: Runs module tests defined in `.tftest.hcl` files.
*   **Differences from `terraform`:**
    *   Binary is `tofu`, not `terraform`.
    *   Default registry is `registry.opentofu.org`. It does not automatically fall back to `registry.terraform.io`.
    *   The lock file is `.opentofu.lock.hcl`. Tofu can read `.terraform.lock.hcl` but will generate its own.
    *   Native state encryption and `tofu test` are OpenTofu-specific features.

### OT-2. Provider Ecosystem

*   **Registry:** The primary source for providers is `registry.opentofu.org`.
*   **Terraform Registry Providers:** To use a provider that only exists on the Terraform Registry, you must explicitly declare its source address.
    ```hcl
    terraform {
      required_providers {
        // This provider is on the OpenTofu registry
        hcloud = {
          source  = "hetznercloud/hcloud"
          version = "1.46.1"
        }
        // This provider is pinned to the Terraform registry
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "2.29.0"
        }
      }
    }
    ```
    (Note: `hashicorp` providers like `kubernetes` and `helm` are mirrored to the OpenTofu registry, so a source override is often not needed, but this is the mechanism if you find one that isn't).
*   **Provider Lock File:** `tofu init` generates `.opentofu.lock.hcl`, which records the exact provider versions and hashes. This file **must be committed to git**.
*   **Provider Caching:** Use the `TF_PLUGIN_CACHE_DIR` environment variable (OpenTofu maintains compatibility with this name). Set `export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"` in your shell profile.
*   **Multi-Provider Config (Aliasing):**
    ```hcl
    # Main Cloudflare account
    provider "cloudflare" {
      alias = "primary"
      # ... creds ...
    }

    # Secondary Cloudflare account
    provider "cloudflare" {
      alias = "secondary"
      # ... other creds ...
    }

    resource "cloudflare_record" "primary_rec" {
      provider = cloudflare.primary
      # ...
    }

    resource "cloudflare_record" "secondary_rec" {
      provider = cloudflare.secondary
      # ...
    }
    ```
*   **Provider Versions:**
    *   **Hetzner Cloud (`hetznercloud/hcloud`):** Use latest `1.x`. Auth: `HCLOUD_TOKEN` env var.
    *   **Cloudflare (`cloudflare/cloudflare`):** Use latest `4.x`. Auth: `CLOUDFLARE_API_TOKEN` env var.
    *   **Kubernetes (`hashicorp/kubernetes`):** Auth via `~/.kube/config` by default.
    *   **Helm (`hashicorp/helm`):** Auth via `~/.kube/config` by default.
    *   **GitHub (`integrations/github`):** Auth via `GITHUB_TOKEN` env var.

### OT-3. State Management with MinIO

*   **Complete `backend "s3"` block for MinIO:**
    ```hcl
    terraform {
      backend "s3" {
        endpoint                      = "minio.k8s.helixstax.net" // Use your actual MinIO endpoint
        bucket                        = "opentofu-state"
        key                           = "k3s-cluster/prod/main.tfstate" // Path within the bucket
        region                        = "us-east-1" // Required but ignored by MinIO
        access_key                    = "your-access-key" // Pass via -backend-config
        secret_key                    = "your-secret-key" // Pass via -backend-config
        skip_credentials_validation   = true
        skip_metadata_api_check       = true
        force_path_style              = true // VERY IMPORTANT for MinIO
        // lock_table                  = "opentofu-locks" // Not used, see below
      }
    }
    ```
*   **State Locking:** The S3 backend supports native locking. When `tofu plan/apply` starts, it attempts to write a lock object to the bucket. MinIO supports the necessary S3 APIs for this to work out-of-the-box. **You do not need a DynamoDB-compatible solution.**
*   **State Encryption (OpenTofu Native):** OpenTofu can encrypt the state file *before* sending it to the backend. This is stronger than S3 Server-Side Encryption.
    ```hcl
    terraform {
      backend "s3" {
        // ... other s3 config ...
        encrypt        = true
        kms_key_id     = "age:age1...your...public...key" // Public key of your 'age' keypair
        // Tofu will use the corresponding private key (from env var or file) to decrypt
      }
    }
    // Set env var: export TF_ENCRYPTION_AGE_KEY="AGE-SECRET-KEY-1..."
    ```
*   **Workspaces vs. State Files:**
    *   **Workspaces:** Use for different environments (dev, staging, prod) of the *same* infrastructure configuration. They share the same code but have different variable values and state files. Tofu appends the workspace name to the state `key` path (e.g., `env:/prod/k3s-cluster/prod/main.tfstate`).
    *   **Separate State Files (via `key`):** Use for logically distinct infrastructure components (e.g., one state for Hetzner servers, one for Cloudflare DNS, one for the K8s cluster config). This is our recommended pattern.
*   **State Backup:** Your MinIO bucket backup strategy (Velero, daily snapshots) is your state backup strategy. `Velero -> backs up MinIO PV -> backs up state bucket`.
*   **Corrupted State Recovery:**
    1.  `tofu state pull > state.backup.json` (Try to get a backup first)
    2.  Manually edit the JSON file to fix the corruption (e.g., remove a malformed resource block).
    3.  `tofu state push state.edited.json`
    4.  Run `tofu plan` to verify the fix.
*   **State Migration:** Use `tofu state mv`. Example: moving a server from a temporary file to a new module structure.
    `tofu state mv 'hcloud_server.temp_worker' 'module.k8s_nodes.hcloud_server.worker[0]'`
*   **Remote State Data Source:** `terraform_remote_state` (name is kept for compatibility) is used to read outputs from other state files.
    ```hcl
    data "terraform_remote_state" "network" {
      backend = "s3"
      config = {
        // ... same MinIO config as your backend ...
        key = "global/network/terraform.tfstate"
      }
    }

    resource "hcloud_server" "app_server" {
      // Use an output from the network state file
      network_id = data.terraform_remote_state.network.outputs.private_network_id
    }
    ```

### OT-4. Module Development

*   **Directory Structure:**
    ```
    modules/
    └── my-hetzner-node/
        ├── main.tf        # Main logic, resources
        ├── variables.tf   # Input variables
        ├── outputs.tf     # Output values
        ├── versions.tf    # Provider and Tofu version requirements
        └── README.md
    ```
*   **Module Composition:**
    ```hcl
    // In root main.tf
    module "k8s_nodes" {
      source      = "./modules/hetzner-node"
      count       = 2
      server_name = "helix-worker-${count.index}"
      // ... other inputs ...
    }

    module "k8s_dns" {
      source  = "./modules/cloudflare-dns"
      zone_id = var.cloudflare_zone_id
      records = [
        { name = "worker-0", value = module.k8s_nodes[0].ipv4_address, type = "A" },
        { name = "worker-1", value = module.k8s_nodes[1].ipv4_address, type = "A" }
      ]
    }
    ```
*   **Module Versioning:**
    *   **Local:** `source = "./modules/my-module"`
    *   **Git:** `source = "git@github.com:helix-stax/opentofu-modules.git//hetzner-node?ref=v1.2.0"`
*   **`moved` block:** Safely refactor code without resource destruction. If you move a resource from the root into a module:
    ```hcl
    // In root main.tf
    moved {
      from = hcloud_server.worker
      to   = module.k8s_nodes.hcloud_server.worker
    }
    ```
*   **`check` block:** Post-apply assertions.
    ```hcl
    resource "hcloud_server" "helix-stax-cp" { /* ... */ }

    check "cp_is_running" {
      data "hcloud_server" "cp_check" {
        id = hcloud_server.helix-stax-cp.id
      }
      assert {
        condition     = data.hcloud_server.cp_check.status == "running"
        error_message = "Hetzner server 'helix-stax-cp' is not in a running state after apply."
      }
    }
    ```
*   **`precondition` / `postcondition`:**
    ```hcl
    resource "hcloud_server" "worker" {
      image = var.image_name

      lifecycle {
        precondition {
          condition     = can(regex("^almalinux", var.image_name))
          error_message = "Server image must be an AlmaLinux image."
        }
        postcondition {
          condition     = self.status == "running"
          error_message = "Server failed to start."
        }
      }
    }
    ```
*   **Module Testing with `tofu test`:**
    ```hcl
    // in modules/my-hetzner-node/main.tftest.hcl
    variable "server_name_test" {
      type    = string
      default = "tofu-test-server"
    }

    // Mock provider to avoid real API calls
    provider "hcloud" {
      token = "mock-token"
    }

    run "test_server_creation" {
      command = apply

      module {
        source = "./" // Test the current module
        server_name = var.server_name_test
        // ... other inputs
      }

      assert {
        condition     = contains(module.output_server_name, "tofu-test-server")
        error_message = "Server name output is incorrect."
      }
    }
    ```

### OT-5 to OT-12: See `examples.md` for concrete implementations of Hetzner, Cloudflare, Kubernetes, Secrets, Workspaces, and Ansible Integration.

### Best Practices & Anti-Patterns

*   **Top 10 Best Practices:**
    1.  Always use a remote backend (MinIO) with locking.
    2.  Commit `.opentofu.lock.hcl` to git.
    3.  Encrypt secrets using SOPS+age for `.tfvars` files. Never commit plaintext secrets.
    4.  Use separate state files (different root modules/keys) for distinct infrastructure components (network, k8s-cluster, apps).
    5.  Use workspaces only for different environments (dev/prod) of the *same* component.
    6.  Keep modules small and focused on one task (e.g., a module for a server, a module for a firewall).
    7.  Use `terraform_remote_state` to share outputs between components instead of duplicating declarations.
    8.  Always run `tofu fmt -recursive` and `tofu validate` before committing.
    9.  Tag resources with `owner`, `project`, and `environment` for cost tracking and management.
    10. Use the `tofu apply -> output -> ansible` handoff. Do not use `remote-exec` or `local-exec` to run Ansible from Tofu.
*   **Common Mistakes (Ranked by Severity):**
    1.  **Critical:** Storing state locally (`.tfstate` file) in a team environment. Leads to conflicts and data loss.
    2.  **Critical:** Committing plaintext secrets (`.tfvars`, provider tokens) to git.
    3.  **High:** Using `tofu apply -target` for routine operations. It can lead to state drift, as untargeted resources are ignored.
    4.  **High:** Manually editing resources in the cloud console. This creates drift that Tofu will try to "fix" on the next run. Use `tofu import` or HCL changes instead.
    5.  **Medium:** Not pinning provider versions (`version = "~> 1.46"`). A minor provider update could break your configuration.
    6.  **Medium:** Using `remote-exec` provisioner. It makes Tofu stateful and brittle. It's an anti-pattern; configuration belongs in Ansible.
    7.  **Low:** Creating monolithic state files. They become slow and risky to apply. Break them up.
*   **Defaults to Avoid in Production:**
    *   Never rely on the default local backend.
    *   Do not leave `sensitive = false` on variables containing secrets.
    *   Hetzner `hcloud_server`: Don't omit the `ssh_keys` argument, or you may be unable to log in.
    *   Cloudflare `cloudflare_record`: Be mindful of the default `proxied = false`. Set it explicitly to `true` to enable Cloudflare's security and performance features.

## examples.md Content

### Project Structure
```
.
├── opentofu/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── secrets.tfvars.enc     # Encrypted with SOPS+age
│   └── ansible_inventory.yml  # Generated by `tofu apply`
└── ansible/
    ├── site.yml
    ├── hcloud.yml             # Dynamic inventory config
    └── ... (playbooks, roles)
```

### Decrypting Secrets Workflow
```bash
# one-time setup
# brew install sops age

# Key is stored in OpenBao or 1Password. For local use:
# export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Decrypt to use with tofu CLI
sops -d opentofu/secrets.tfvars.enc > opentofu/secrets.tfvars
tofu plan -var-file="opentofu/secrets.tfvars"

# Clean up plaintext file immediately
rm opentofu/secrets.tfvars
```

### `opentofu/main.tf`
```hcl
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for helixstax.com"
  type        = string
}

resource "hcloud_ssh_key" "default" {
  name       = "helix-stax-admin-key"
  public_key = file("~/.ssh/id_ed25519.pub") // Your admin public key
}

resource "hcloud_server" "helix-stax-cp" {
  name        = "helix-stax-cp"
  server_type = "cpx31" // e.g., 4 vCPU, 8 GB RAM
  image       = "almalinux-9"
  location    = "ash" // Ashburn, VA
  ssh_keys    = [hcloud_ssh_key.default.name]
  labels = {
    "role"    = "k3s_control_plane"
    "project" = "helix-stax"
    "env"     = "prod"
  }
}

resource "hcloud_server" "helix-stax-vps" {
  name        = "helix-stax-vps"
  server_type = "cpx31" // e.g., 4 vCPU, 8 GB RAM
  image       = "almalinux-9"
  location    = "ash"
  ssh_keys    = [hcloud_ssh_key.default.name]
  labels = {
    "role"    = "k3s_worker"
    "project" = "helix-stax"
    "env"     = "prod"
  }
}

resource "cloudflare_record" "helix-stax-cp" {
  zone_id = var.cloudflare_zone_id
  name    = "helix-stax-cp"
  value   = hcloud_server.helix-stax-cp.ipv4_address
  type    = "A"
  ttl     = 3600
  proxied = false // Not proxied for SSH access
}

resource "cloudflare_record" "k8s_api" {
  zone_id = var.cloudflare_zone_id
  name    = "k8s.api" // e.g., k8s.api.helixstax.com
  value   = hcloud_server.helix-stax-cp.ipv4_address
  type    = "A"
  ttl     = 300
  proxied = true // Proxied for security
}

resource "cloudflare_record" "vps" {
  zone_id = var.cloudflare_zone_id
  name    = "helix-stax-vps"
  value   = hcloud_server.helix-stax-vps.ipv4_address
  type    = "A"
  ttl     = 3600
  proxied = false
}

# The Ansible Handoff: Generate inventory file from outputs
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    control_plane_ip = hcloud_server.helix-stax-cp.ipv4_address,
    workers = [
      {
        name = hcloud_server.helix-stax-vps.name,
        ip   = hcloud_server.helix-stax-vps.ipv4_address
      }
    ]
  })
  filename = "${path.root}/../ansible/inventory.yml"
}
```

### `opentofu/outputs.tf`
```hcl
output "control_plane_ip" {
  value = hcloud_server.heart.ipv4_address
}

output "control_plane_id" {
  value = hcloud_server.heart.id
}

output "worker_ips" {
  value = {
    for server in [hcloud_server.helix-stax-vps] : server.name => server.ipv4_address
  }
}

output "all_server_info" {
  value = {
    "helix-stax-cp" = {
      ip     = hcloud_server.helix-stax-cp.ipv4_address,
      id     = hcloud_server.helix-stax-cp.id,
      labels = hcloud_server.helix-stax-cp.labels
    },
    "helix-stax-vps" = {
      ip     = hcloud_server.helix-stax-vps.ipv4_address,
      id     = hcloud_server.helix-stax-vps.id,
      labels = hcloud_server.helix-stax-vps.labels
    }
  }
}
```

### `opentofu/inventory.tpl` (Template for Ansible)
```yaml
# This file is managed by OpenTofu. Do not edit manually.
---
all:
  hosts:
    heart:
      ansible_host: ${control_plane_ip}
      ansible_user: root
    %{ for worker in workers ~}
    ${worker.name}:
      ansible_host: ${worker.ip}
      ansible_user: root
    %{ endfor ~}

  children:
    k3s_cluster:
      children:
        control_plane:
          hosts:
            heart:
        workers:
          hosts:
            %{ for worker in workers ~}
            ${worker.name}:
            %{ endfor ~}
```

### Runbook: Importing an Existing Server
Let's say `helix-stax-cp` (ID `987654`) was created manually.
1.  **Write the HCL:** Add the `resource "hcloud_server" "helix-stax-cp"` block to `main.tf` as shown above.
2.  **Run Import Command:**
    ```bash
    tofu import hcloud_server.heart 987654
    ```
3.  **Plan to Verify:**
    ```bash
    tofu plan
    ```
    The output should say `No changes. Your infrastructure matches the configuration.` If it shows changes, it means your HCL doesn't perfectly match the server's actual state. Adjust your HCL (e.g., add the correct `labels`, `server_type`) until the plan is clean.

---
---

# Ansible

## SKILL.md Content

### Core Workflow

Ansible configures servers provisioned by OpenTofu.

1.  **Prerequisite:** `tofu apply` has been run and `ansible/inventory.yml` (static) or the Hetzner API (for dynamic inventory) is up-to-date.
2.  **Check Connection:** `ansible -i hcloud.yml all -m ping`
3.  **Dry-Run Playbook:** `ansible-playbook -i hcloud.yml site.yml --check --diff`
4.  **Run Playbook:** `ansible-playbook -i hcloud.yml site.yml`
5.  **Run Specific Tags:** `ansible-playbook -i hcloud.yml site.yml --tags security`
6.  **Target Specific Host:** `ansible-playbook -i hcloud.yml site.yml --limit heart`

### CLI Quick Reference

**Run a Playbook**
`ansible-playbook -i <inventory_file> <playbook.yml> [flags]`

*   `-i hcloud.yml`: Use Hetzner dynamic inventory.
*   `--limit heart`: Run only against the `heart` host.
*   `--tags crowdsec,k3s`: Run only tasks with these tags.
*   `--skip-tags security`: Run all tasks except those tagged `security`.
*   `--check`: Dry-run mode. See what would change.
*   `--diff`: Show differences in file content (e.g., template changes).
*   `-v, -vv, -vvv`: Increase verbosity for debugging.
*   `-e @infra.json`: Load extra variables from a JSON file (the output from Tofu).

**Ad-Hoc Commands** (for quick tasks/debugging)
```bash
# Check SSH connection to all hosts in the k3s_cluster group
ansible -i hcloud.yml k3s_cluster -m ping

# Check uptime on workers
ansible -i hcloud.yml workers -a "uptime"

# Check k3s service status on the control plane (requires sudo)
ansible -i hcloud.yml control_plane -a "systemctl status k3s" --become

# Copy a file to all nodes
ansible -i hcloud.yml all -m copy -a "src=/local/path/file dest=/remote/path/file"
```

**Vault Management**
`ansible-vault <command> [filename]`

*   `ansible-vault create secrets.yml`: Create a new encrypted file.
*   `ansible-vault edit secrets.yml`: Edit an encrypted file.
*   `ansible-vault view secrets.yml`: Display the contents of an encrypted file.
*   `ansible-vault encrypt_string 'my_super_secret' --name 'db_password'`: Encrypt a string to paste into a regular YAML file.

### Configuration Snippets

**`ansible.cfg`**
```ini
[defaults]
inventory = ./hcloud.yml             # Default inventory file
remote_user = ansible                # Default user to SSH as
private_key_file = ~/.ssh/id_ed25519 # Default SSH key
host_key_checking = False            # WARNING: Only acceptable for initial provisioning. Set to True after first connection and store host keys.
pipelining = True                    # Speeds up execution by reducing SSH operations
forks = 10                           # Number of parallel tasks
vault_password_file = ~/.ansible/vault_pass.sh # Script to get vault password

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

**`hcloud.yml` (Dynamic Inventory)**
```yaml
# filename: hcloud.yml
plugin: hetzner.hcloud.hcloud
# HCLOUD_TOKEN environment variable is used for auth
# Map server labels to ansible groups
keyed_groups:
  - key: labels.role
    prefix: ""
# Example: a server with label 'role: k3s_control_plane' will be in the 'k3s_control_plane' group
compose:
  # Create a 'k3s_cluster' group containing control plane and workers
  k3s_cluster: "k3s_control_plane or k3s_worker"
```

### Troubleshooting Decision Tree

*   **Symptom:** `UNREACHABLE!` or `Failed to connect to the host via ssh`
    *   **Cause 1: Network/Firewall:** The host is down or a firewall is blocking port 22.
    *   **Fix 1:** Ping the host IP. Check Hetzner/Cloudflare firewall rules.
    *   **Cause 2: SSH User/Key:** Wrong `ansible_user` or SSH key is not on the remote a `~/.ssh/authorized_keys`.
    *   **Fix 2:** Manually test `ssh ansible@<ip>`. If it fails, fix the user or key.
    *   **Cause 3: Host Key Changed:** The remote host's SSH key fingerprint has changed.
    *   **Fix 3:** If the change is expected, remove the old key from `~/.ssh/known_hosts`.
*   **Symptom:** `FAILED!` with `"msg": "Missing sudo password"`
    *   **Cause:** The `ansible_user` is not configured for passwordless `sudo`.
    *   **Fix:** Ensure the remote `/etc/sudoers.d/ansible` file contains `ansible ALL=(ALL) NOPASSWD: ALL`. This should be done by cloud-init or a bootstrapping playbook.
*   **Symptom:** `FAILED!` with "SELinux is preventing..." in `stderr`
    *   **Cause:** An Ansible task is trying to do something that violates the current SELinux policy.
    *   **Fix:**
        1.  Check `/var/log/audit/audit.log` on the target node for `avc: denied` messages.
        2.  Use `audit2allow` to generate a potential policy fix.
        3.  More likely, a standard SELinux boolean needs to be set. E.g., for web servers: `ansible -m seboolean -a "name=httpd_can_network_connect state=yes persistent=yes"` --become. For K3s, `container_manage_cgroup` is often needed.
*   **Symptom:** Playbook runs but nothing changes when it should.
    *   **Cause:** `--check` mode is on, or a `when:` condition is evaluating to false.
    *   **Fix:** Remove `--check`. Add `debug` tasks to print the variables used in the `when:` condition to see why it's failing.

## reference.md Content

### AN-1. CLI Reference
*   `ansible-playbook`:
    *   See `SKILL.md` for common flags.
    *   `--start-at-task <TASK_NAME>`: Begin execution at a specific named task.
*   `ansible`:
    *   `-m <module>`: Module to run (ping, shell, copy, service, dnf).
    *   `-a <args>`: Arguments for the module.
*   `ansible-galaxy`:
    *   `collection install -r requirements.yml`: Install collections from a file.
    *   `collection list`: List installed collections.
    *   `role init <role_name>`: Create a skeleton directory structure for a new role.
*   `ansible-vault`:
    *   All commands in `SKILL.md`.
    *   `rekey old.yml new.yml`: Re-encrypt a file with a new vault password.
*   `ansible-inventory`:
    *   `--list`: Display inventory as JSON, showing all hosts and group variables. Essential for debugging dynamic inventory.
    *   `--graph`: Show a visual graph of host groups.
    *   `--host <hostname>`: Display all variables applied to a single host.
*   `ansible-lint`: Run with `ansible-lint site.yml`. Highly recommended to have in CI.
*   `ansible-doc -s <module_name>`: Show documentation and examples for a module (e.g., `ansible-doc -s firewalld`).
*   **Environment Variables:**
    *   `ANSIBLE_CONFIG`: Path to `ansible.cfg` file.
    *   `ANSIBLE_ROLES_PATH`: Colon-separated list of paths to look for roles.
    *   `ANSIBLE_COLLECTIONS_PATHS`: Colon-separated list of paths for collections.
    *   `ANSIBLE_VAULT_PASSWORD_FILE`: Path to a script or file containing the vault password.
    *   `ANSIBLE_BECOME_PASS`: Password for `become` (sudo). Not recommended; use passwordless sudo.

### AN-2. Inventory Management
*   **Static Inventory (INI vs YAML):** YAML is preferred for its ability to represent complex data structures.
*   **Directory Structure:**
    ```
    ├── inventory.yml      # Static inventory if needed
    ├── hcloud.yml         # Dynamic inventory config
    └── group_vars/
        ├── all/
        │   ├── vars.yml
        │   └── vault.yml      # Encrypted variables
        ├── k3s_control_plane/
        │   └── k3s_config.yml
        └── k3s_worker/
            └── vars.yml
    └── host_vars/
        └── helix-stax-cp.yml  # Host-specific vars for 'helix-stax-cp'
    ```
*   **Combining Inventories:** `ansible-playbook -i inventory.yml -i hcloud.yml ...` Variables from the right-most inventory win in case of conflict.

### AN-3 to AN-12: See `examples.md` for complete playbooks and roles for Hardening, K3s, CrowdSec, User Management, etc.

### Best Practices & Anti-Patterns
*   **Top 10 Best Practices:**
    1.  Use dynamic inventory (`hcloud.yml`) based on OpenTofu-set labels. This is the core of the integration.
    2.  Structure everything in roles. Avoid putting logic directly in playbooks.
    3.  Use Ansible Vault for all secrets. Use `ansible-vault encrypt_string` for single values to keep context visible in git diffs.
    4.  Run `ansible-lint` in CI/pre-commit hooks.
    5.  Make all tasks idempotent. Use modules' built-in state management, not `command`/`shell` with `creates`.
    6.  Name all your tasks. `name: "Ensure firewalld is running and enabled"` is much better than no name.
    7.  Use `tags` liberally (`security`, `k3s`, `monitoring`, `users`).
    8.  Use `ansible.cfg` to define project-wide defaults.
    9.  Leverage collections (`community.general`, `kubernetes.core`) instead of reinventing the wheel.
    10. Test roles with Molecule before deploying to production.
*   **Common Mistakes (Ranked by Severity):**
    1.  **Critical:** Using `command` or `shell` when a dedicated module exists. Example: using `shell: "firewall-cmd --add-port=..."` instead of the `firewalld` module. This is not idempotent and error-prone.
    2.  **Critical:** Storing secrets in plaintext in `group_vars` or `host_vars`.
    3.  **High:** Not using `become: true`. Tasks will fail with permission errors.
    4.  **Medium:** Using `changed_when: false` to suppress changed status. This should be a last resort. Figure out why the task is not idempotent.
    5.  **Medium:** Hardcoding IP addresses. Use `inventory_hostname` and variables from inventory.
    6.  **Low:** Forgetting to use Fully Qualified Collection Names (FQCN) like `ansible.posix.firewalld`. It can lead to ambiguity if multiple collections provide a module with the same name.

### Decision Matrix
*   **Ansible Vault vs. OpenBao Lookup:**
    *   **If:** The secret is needed for Ansible to *run* (e.g., SSH private keys, API tokens for Ansible modules).
    *   **Use:** Ansible Vault. It's designed for this and works "offline."
    *   **Because:** The playbook cannot even start without these secrets.
    *   **If:** The secret is for the *target application* to use at runtime (e.g., a database password for a K8s deployment).
    *   **Use:** OpenBao lookup (`community.hashi_vault.hashi_vault_kv2_get`).
    *   **Because:** This keeps a single source of truth for runtime secrets and allows for easier rotation without re-running Ansible.
*   **Static vs. Dynamic Inventory:**
    *   **If:** Your infrastructure is static and rarely changes.
    *   **Use:** Static `inventory.yml` file generated by OpenTofu's `local_file` resource.
    *   **Because:** It's simple and has no external dependencies at runtime.
    *   **If:** Your infrastructure scales or changes frequently (our case).
    *   **Use:** Hetzner Cloud dynamic inventory plugin (`hcloud.yml`).
    *   **Because:** It automatically discovers new nodes created by OpenTofu based on labels. It's the most robust integration pattern.

## examples.md Content

### `ansible/requirements.yml`
```yaml
---
collections:
  - name: hetzner.hcloud
    version: 1.10.0
  - name: community.general
    version: 9.2.0
  - name: ansible.posix
    version: 1.5.4
  - name: kubernetes.core
    version: 2.4.0
  - name: community.crypto # For SOPS integration if needed
    version: 2.17.0
```
**Installation:** `ansible-galaxy collection install -r ansible/requirements.yml`

### `ansible/site.yml` (Main Playbook)
```yaml
---
- name: 1. Harden all nodes
  hosts: k3s_cluster
  become: true
  roles:
    - role: hardening

- name: 2. Install K3s Cluster
  hosts: k3s_cluster
  become: true
  roles:
    - role: k3s

- name: 3. Deploy CrowdSec
  hosts: k3s_cluster
  become: true
  roles:
    - role: crowdsec
```

### Role: `ansible/roles/hardening/tasks/main.yml`
```yaml
- name: Harden AlmaLinux
  tags: [hardening, security]
  block:
    - name: Ensure required packages are installed
      ansible.builtin.dnf:
        name:
          - firewalld
          - python3-libselinux
          - chrony
          - audit
        state: present

    - name: Configure firewalld
      ansible.posix.firewalld:
        service: "{{ item }}"
        permanent: true
        state: enabled
        immediate: true
      loop:
        - ssh
        - http
        - https

    - name: Remove unwanted services from firewalld
      ansible.posix.firewalld:
        service: "{{ item }}"
        permanent: true
        state: disabled
        immediate: true
      loop:
        - cockpit
        - dhcpv6-client

    - name: Harden sshd_config
      ansible.builtin.template:
        src: sshd_config.j2
        dest: /etc/ssh/sshd_config
        owner: root
        group: root
        mode: '0600'
      notify: restart sshd

    - name: Ensure SELinux is in enforcing mode
      community.general.selinux:
        policy: targeted
        state: enforcing

    - name: Apply kernel parameters for K3s and security
      ansible.posix.sysctl:
        name: "{{ item.key }}"
        value: "{{ item.value }}"
        sysctl_file: /etc/sysctl.d/99-helixstax.conf
        state: present
        reload: true
      loop:
        - { key: 'net.ipv4.ip_forward', value: '1' }
        - { key: 'net.bridge.bridge-nf-call-iptables', value: '1' }
        - { key: 'fs.suid_dumpable', value: '0' }

    - name: Create ansible user
      ansible.builtin.user:
        name: ansible
        comment: "Ansible Service User"
        shell: /bin/bash
        groups: wheel
        append: true

    - name: Setup passwordless sudo for ansible user
      ansible.builtin.lineinfile:
        path: /etc/sudoers.d/ansible
        line: "ansible ALL=(ALL) NOPASSWD: ALL"
        create: true
        validate: 'visudo -cf %s'
        mode: '0440'

handlers:
  - name: restart sshd
    ansible.builtin.service:
      name: sshd
      state: restarted
```

### Role: `ansible/roles/k3s/tasks/main.yml`
```yaml
- name: Set SELinux boolean for container management
  community.general.seboolean:
    name: container_manage_cgroup
    state: true
    persistent: true

- name: Add K3s firewall rules on control plane
  when: inventory_hostname in groups['k3s_control_plane']
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: true
    state: enabled
    immediate: true
  loop:
    - 6443/tcp   # Kubernetes API Server
    - 8472/udp   # Flannel VXLAN
    - 51820/udp  # Flannel WireGuard (if used)
    - 10250/tcp  # Kubelet API

- name: Add K3s firewall rules on workers
  when: inventory_hostname in groups['k3s_worker']
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: true
    state: enabled
    immediate: true
  loop:
    - 8472/udp   # Flannel VXLAN
    - 51820/udp  # Flannel WireGuard (if used)
    - 10250/tcp  # Kubelet API

- name: Install K3s on control plane node
  when: inventory_hostname in groups['k3s_control_plane']
  ansible.builtin.shell:
    cmd: "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--disable=traefik --flannel-backend=vxlan' sh -"
    creates: /usr/local/bin/k3s

- name: Get K3s token from control plane
  when: inventory_hostname in groups['k3s_control_plane']
  ansible.builtin.command: cat /var/lib/rancher/k3s/server/node-token
  register: k3s_token_raw
  changed_when: false

- name: Store K3s token
  set_fact:
    k3s_token: "{{ k3s_token_raw.stdout }}"
  when: k3s_token_raw.stdout is defined

- name: Install K3s on worker nodes
  when: inventory_hostname in groups['k3s_worker']
  ansible.builtin.shell:
    cmd: "curl -sfL https://get.k3s.io | K3S_URL=https://{{ hostvars['helix-stax-cp'].ansible_host }}:6443 K3S_TOKEN={{ hostvars['helix-stax-cp'].k3s_token }} sh -"
    creates: /usr/local/bin/k3s

- name: Fetch kubeconfig from control plane
  when: inventory_hostname in groups['k3s_control_plane']
  ansible.builtin.fetch:
    src: /etc/rancher/k3s/k3s.yaml
    dest: "fetched/k3s.yaml"
    flat: yes

- name: Correct kubeconfig IP and save locally
  delegate_to: localhost
  ansible.builtin.replace:
    path: "fetched/k3s.yaml"
    regexp: '127\.0\.0\.1'
    replace: "{{ hostvars['helix-stax-cp'].ansible_host }}"
  run_once: true
```

### Runbook: Troubleshooting a `FAILED!` Task
**Symptom:** Ansible fails on the "Harden sshd_config" task with a permission error.

1.  **Read the Error:** The output says `Permission denied` when trying to write to `/etc/ssh/sshd_config`. The user is `ansible`.
2.  **Analyze:** The `ansible` user is not `root`. To write to `/etc/`, it needs to use `sudo`.
3.  **Check the Playbook:** Look at the playbook and host/group vars. Is `become: true` set for this play?
    ```yaml
    - name: 1. Harden all nodes
      hosts: k3s_cluster
      become: true # This is the key. Is it here?
      roles:
        - role: hardening
    ```
4.  **Check Sudoers on Target:** If `become: true` is set, the problem is with the sudo configuration on the remote machine.
    *   Run ad-hoc command: `ansible heart -a "cat /etc/sudoers.d/ansible"`
    *   **If it fails:** The file doesn't exist. Your user bootstrapping task failed.
    *   **If it succeeds:** Check the contents. It should a line like `ansible ALL=(ALL) NOPASSWD: ALL`. A typo here will cause failures.
5.  **Fix and Re-run:** Correct the sudoers setup task or the playbook's `become` setting, then re-run the playbook: `ansible-playbook -i hcloud.yml site.yml --tags hardening`. The `tags` flag a faster feedback loop.
