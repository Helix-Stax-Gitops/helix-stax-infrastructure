# Gemini Deep Research: Hetzner Cloud API — Server Provisioning and Management

## Who I Am

I run Helix Stax, a small IT consulting company. I use AI coding agents (Claude Code + Gemini CLI) to build and operate my infrastructure. My agents need a comprehensive reference document for every tool in my stack so they can configure, troubleshoot, and optimize without hallucinating. This research will become that reference document.

## What These Tools Are

The Hetzner Cloud API is the REST API that underpins all Hetzner Cloud operations — server creation, deletion, rebuilding, networking, firewall management, and more. We interact with it in two ways:

1. **hcloud CLI**: The official Hetzner Cloud command-line tool, used for ad-hoc operations, scripting, and CI workflows
2. **OpenTofu hcloud provider**: The Terraform-compatible provider used in our IaC pipeline for declarative server provisioning

Understanding the API directly is essential because:
- OpenTofu provider documentation sometimes omits API fields available directly via hcloud CLI
- CI scripts (GitHub Actions) use hcloud CLI directly to manage test servers outside of OpenTofu state
- Molecule cleanup scripts use hcloud CLI to find and destroy orphaned test servers
- Debugging OpenTofu provider behavior requires knowing the underlying API response

Hetzner Cloud API is straightforward, well-documented, and fast. It does NOT require complex authentication (just a bearer token). Rate limits are generous (3,600 requests per hour). The API is synchronous for most operations but uses action polling for long-running operations.

## Our Specific Setup

- **Hetzner Cloud account**: US region (Ashburn `ash-dc1` and Hillsboro `hil-dc1`)
- **Production servers**:
  - helix-stax-cp: cpx31, Ashburn (ash-dc1), AlmaLinux 9.7 — IP: 178.156.233.12
  - helix-stax-vps: cpx31, Hillsboro (hil-dc1), AlmaLinux 9.7 — IP: 5.78.145.30
- **Test server**: helix-stax-test, cx22, Ashburn (ash-dc1), AlmaLinux 9.7 — temporary, created and destroyed per CI run
- **SSH port**: 2222
- **Admin user**: `wakeem`
- **TLS**: Cloudflare Origin CA (15-year) — not using Hetzner certificates
- **DNS**: Cloudflare (NOT Hetzner DNS)
- **IaC**: OpenTofu with `hetznercloud/hcloud` provider
- **CI**: GitHub Actions — uses `HCLOUD_TOKEN` secret for hcloud CLI and OpenTofu
- **Hetzner Robot**: NOT used — we use Hetzner Cloud only (Robot is for dedicated servers with a different API)

---

## What I Need Researched

---

### HC-1. API Authentication

Everything starts with authentication. Document:

**API Token:**
- Where to create tokens: Hetzner Cloud Console → Project → Security → API Tokens
- Token types: Read-only vs Read+Write — which we need (Read+Write for all operations)
- Token scopes: Is there fine-grained scope control (like Cloudflare) or is it all-or-nothing? Document whatever Hetzner provides.
- `HCLOUD_TOKEN` environment variable: how hcloud CLI reads it, how OpenTofu provider reads it
- Using the token in API requests: `Authorization: Bearer <token>` header
- Token rotation: how to rotate a token without breaking running infrastructure
  - Create new token
  - Update all consumers (OpenTofu `~/.config/hcloud/cli.toml`, GitHub Actions secrets, Ansible Vault)
  - Delete old token
  - Ansible Vault and OpenBao storage for the token

**hcloud CLI authentication:**
- `hcloud context create <name>` — creating a named context with a token
- `hcloud context list` — listing saved contexts
- `hcloud context use <name>` — switching contexts
- Context file location: `~/.config/hcloud/cli.toml`
- CI authentication: using `HCLOUD_TOKEN` env var directly (no context file needed)
- Multiple projects: using separate contexts for separate Hetzner projects

---

### HC-2. hcloud CLI Reference

Complete reference for the hcloud CLI tool:

**Installation:**
- On macOS (Homebrew), Linux (download binary), and in GitHub Actions (install step)
- Version pinning in CI: how to install a specific version
- Verifying install: `hcloud version`

**Server commands:**
- `hcloud server list` — list all servers with status, IPs, types
  - Filtering by label: `hcloud server list --selector purpose=molecule-test`
  - Output formats: `-o json`, `-o table`, `-o noheader`
  - JSON output: exact fields returned (`id`, `name`, `status`, `public_net.ipv4.ip`, `server_type.name`, `location.name`, `image.name`, `labels`)
- `hcloud server create` — create a server
  - Required flags: `--name`, `--type`, `--image`, `--location`
  - Optional flags: `--ssh-key`, `--firewall`, `--network`, `--user-data`, `--label`, `--placement-group`
  - Output: server ID and IP
  - Wait for server to be running: does `hcloud server create` wait, or is it async?
- `hcloud server delete <id|name>` — delete a server permanently
- `hcloud server rebuild <id|name> --image <image>` — wipe and rebuild with fresh OS image
- `hcloud server reboot <id|name>` — graceful reboot
- `hcloud server poweroff <id|name>` — hard power off
- `hcloud server poweron <id|name>` — power on
- `hcloud server describe <id|name>` — full server details as JSON
- `hcloud server get-console <id|name>` — emergency VNC console URL
- `hcloud server change-type <id|name> --server-type <type>` — resize server
- `hcloud server enable-rescue <id|name> --ssh-key <key>` — boot into rescue mode

**SSH Key commands:**
- `hcloud ssh-key list` — list all SSH keys in project
- `hcloud ssh-key create --name <name> --public-key "$(cat ~/.ssh/id_ed25519.pub)"`
- `hcloud ssh-key delete <id|name>`
- `hcloud ssh-key describe <id|name>`

**Firewall commands:**
- `hcloud firewall list`
- `hcloud firewall create --name <name>`
- `hcloud firewall add-rule <id|name> --direction in --protocol tcp --port 2222 --source-ips 0.0.0.0/0,::0/0`
- `hcloud firewall apply-to-server <firewall_id> --server <server_id|name>`
- `hcloud firewall remove-from-server <firewall_id> --server <server_id|name>`
- `hcloud firewall describe <id|name>` — full firewall rules

**Network commands:**
- `hcloud network list`
- `hcloud network create --name <name> --ip-range 10.0.0.0/8`
- `hcloud network add-subnet <id|name> --network-zone eu-central --type server --ip-range 10.10.0.0/24`
- Attaching a server to a network: done at server create or via `hcloud server attach-to-network`

**Image and server type commands:**
- `hcloud image list --type system --architecture x86` — list available OS images
- `hcloud image describe <id|name>` — get image ID for AlmaLinux 9
- `hcloud server-type list` — list all server types with CPU, RAM, price
- `hcloud location list` — list all datacenters (ash, hil, etc.)

**Label management:**
- Adding labels: `hcloud server add-label <server> key=value`
- Removing labels: `hcloud server remove-label <server> key`
- Filtering by label: `--selector key=value` on list commands
- Label use cases: `purpose=molecule-test`, `role=control-plane`, `role=worker`, `environment=prod`

---

### HC-3. REST API Endpoints

Direct API reference for when hcloud CLI or OpenTofu isn't sufficient:

**Base URL**: `https://api.hetzner.cloud/v1`

**Authentication header**: `Authorization: Bearer $HCLOUD_TOKEN`

**Servers:**
- `GET /servers` — list servers (pagination, filtering by label selector, status)
  - Response schema: full field list for a server object
  - Pagination: `page`, `per_page` params; `meta.pagination` in response
- `POST /servers` — create server
  - Request body: complete JSON schema with all fields (`name`, `server_type`, `image`, `location`, `ssh_keys`, `firewalls`, `user_data`, `labels`, `networks`, `placement_group`, `start_after_create`, `automount`)
  - Response: `server` object + `action` object (poll action for completion)
- `GET /servers/{id}` — get server by ID
- `DELETE /servers/{id}` — delete server
- `GET /servers/{id}/actions` — list actions for a server
- `POST /servers/{id}/actions/rebuild` — rebuild with new image
- `POST /servers/{id}/actions/reboot`
- `POST /servers/{id}/actions/change_type` — resize

**Actions:**
- `GET /actions/{id}` — poll action status
  - `status`: `running` | `success` | `error`
  - How long to poll: typical server creation time (30-90 seconds)
  - Polling interval recommendation: 5 seconds

**Firewalls:**
- `GET /firewalls` — list
- `POST /firewalls` — create with rules
  - Rule format: `direction`, `protocol`, `port`, `source_ips` (for ingress), `destination_ips` (for egress)
- `POST /firewalls/{id}/actions/apply_to_resources` — attach to servers or labels
- `POST /firewalls/{id}/actions/set_rules` — replace ALL rules atomically

**SSH Keys:**
- `GET /ssh_keys`
- `POST /ssh_keys` — `{ "name": "...", "public_key": "ssh-ed25519 ..." }`
- `DELETE /ssh_keys/{id}`

**Images:**
- `GET /images?type=system&architecture=x86` — list system images (OS images)
- Image IDs for AlmaLinux 9: how to find the current image ID (changes over time as Hetzner updates images)
- Snapshot images: images you create from servers

**Server Types:**
- `GET /server-types` — all server types with CPU, memory, disk, pricing
- Response includes hourly and monthly pricing in EUR and USD
- Types we use: `cx22` ($5.99/mo, 2 vCPU, 4GB RAM), `cpx31` ($12.99/mo, 4 vCPU, 8GB RAM)

**Locations:**
- `GET /locations` — all datacenter locations
- `ash-dc1`: Ashburn, Virginia, USA (North America)
- `hil-dc1`: Hillsboro, Oregon, USA (North America)

**Networks:**
- `GET /networks`
- `POST /networks` — create private network
- Subnet configuration for private inter-server networking

**Volumes:**
- `GET /volumes`
- `POST /volumes` — create persistent block storage volume
- `POST /volumes/{id}/actions/attach` — attach to server
- `POST /volumes/{id}/actions/detach`

**Placement Groups:**
- `POST /placement_groups` — create placement group (`type: "spread"` ensures different physical hosts)
- Attach server to placement group at creation time via `placement_group` field in `POST /servers`

---

### HC-4. Cloud-init User Data

Hetzner supports cloud-init for initial server configuration:

**How user_data works:**
- Passed as a string in `POST /servers` body `user_data` field
- Must be valid cloud-init YAML (`#cloud-config` header) or a shell script (`#!/bin/bash` header)
- Size limit: 32KB
- Execution: runs once at first boot only (not on reboot)
- AlmaLinux 9 cloud-init support: which cloud-init modules are available? (`package_update`, `package_install`, `users`, `write_files`, `runcmd`, `ssh_authorized_keys`)

**Typical user_data for our setup:**
```yaml
#cloud-config
users:
  - name: wakeem
    groups: [wheel, sudo]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - <public_key>
    shell: /bin/bash
package_update: true
packages:
  - python3
  - git
runcmd:
  - setenforce 1
  - sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

Document:
- The exact `users:` cloud-init schema for creating `wakeem` with sudo and SSH key
- `package_update` and `packages` for installing Python 3 (required for Ansible)
- `runcmd` for any first-boot setup (SELinux, SSH port change)
- `ssh_authorized_keys` at root level vs under `users:` — which applies where
- Changing SSH port via cloud-init: is it reliable or does it cause cloud-init to fail before Ansible runs?
- Viewing cloud-init logs on AlmaLinux 9: `/var/log/cloud-init.log`, `cloud-init status`
- Debugging failed user_data: how to tell if cloud-init succeeded (`cloud-init status --wait`)
- OpenTofu `templatefile()` for user_data: how to render a YAML cloud-init template with variables

---

### HC-5. Server Labels

Labels are key-value pairs on Hetzner resources used for grouping, filtering, and Ansible inventory:

**Label format:**
- Keys: `[a-z0-9-_./]`, max 63 chars
- Values: `[a-z0-9-_.]`, max 63 chars, can be empty
- Max 255 labels per resource
- Reserved label prefixes (if any)

**Label use cases for our setup:**
- `role=control-plane` — marks helix-stax-cp
- `role=worker` — marks helix-stax-vps and future worker nodes
- `environment=prod` — marks production servers
- `environment=test` — marks helix-stax-test
- `purpose=molecule-test` — marks temporary test servers (for cleanup scripts)
- `k3s-version=v1.30.0` — marks K3s version installed
- `managed-by=opentofu` — marks servers managed by OpenTofu

**Labels in Ansible dynamic inventory:**
- The `hetzner.hcloud` Ansible collection inventory plugin reads labels
- `group_by` in `hcloud.yml`: grouping servers by label values
- `hcloud.yml` config for label-based groups: `groups.control_plane: "'role=control-plane' in labels"`
- Result: Ansible groups like `control_plane`, `worker` created dynamically from Hetzner labels

**Labels in OpenTofu:**
- Setting labels in `hcloud_server` resource: `labels = { role = "control-plane", environment = "prod" }`
- Labels survive server type changes and rebuilds — they're metadata, not OS state

**Label-based cleanup:**
- `hcloud server list --selector purpose=molecule-test -o json | jq '.[].id'` — find all test servers
- Combining with age check: servers older than 2 hours with `purpose=molecule-test` label — cleanup script

---

### HC-6. Server Types and Pricing

Complete reference for server type selection:

**CX series (shared vCPU, Intel/AMD):**
- cx22: 2 vCPU, 4GB RAM, 40GB NVMe — ~$5.99/month, ~$0.009/hour
- cx32: 4 vCPU, 8GB RAM, 80GB NVMe — ~$12.99/month, ~$0.019/hour
- cx42: 8 vCPU, 16GB RAM, 160GB NVMe
- cx52: 16 vCPU, 32GB RAM, 320GB NVMe

**CPX series (shared vCPU, AMD EPYC):**
- cpx11: 2 vCPU, 2GB RAM, 40GB NVMe
- cpx21: 3 vCPU, 4GB RAM, 80GB NVMe
- cpx31: 4 vCPU, 8GB RAM, 160GB NVMe — what we use for CP and VPS
- cpx41: 8 vCPU, 16GB RAM, 240GB NVMe
- cpx51: 16 vCPU, 32GB RAM, 360GB NVMe

**CCX series (dedicated vCPU):**
- ccx13, ccx23, ccx33, ccx43, ccx53, ccx63 — for high-performance workloads

**For our use case:**
- helix-stax-test (Molecule): `cx22` — cheapest option, sufficient for role testing
- helix-stax-cp (Control Plane): `cpx31` — 4 vCPU, 8GB RAM for K3s + control plane workloads
- helix-stax-vps (Worker): `cpx31` — same spec as CP

**Pricing API:**
- `GET /pricing` — returns current pricing for all resources including server types, volumes, IPs
- Using pricing API to estimate monthly cost before provisioning

---

### HC-7. Hetzner Networking Concepts

Private networking for internal cluster communication:

**Public IPs:**
- Every server gets a public IPv4 by default (IPv6 range also assigned)
- Public IPv4 cost: included in server price (confirm if this changed recently)
- IPv6: each server gets a /64 prefix — K3s nodes communicate over IPv4 or IPv6

**Private Networks:**
- Creating a private network with custom CIDR (e.g., `10.0.0.0/8`)
- Adding servers to the private network at creation or after creation
- Private network IPs: assigned from the subnet CIDR
- Use case for us: private communication between K3s CP and workers (avoiding public internet for node-to-node traffic)
- Does Flannel VXLAN use the public or private IP for VXLAN encapsulation? How to configure `--flannel-iface` to use the private interface.

**Hetzner Cloud Networks vs Cloudflare Tunnel:**
- For our setup (Cloudflare Tunnel for external access), do we need Hetzner private networking?
- Recommendation: use private network for K3s node-to-node communication, Cloudflare Tunnel for external access only

---

### HC-8. Rate Limits and Error Handling

**Rate limits:**
- Requests per hour: 3,600 per token
- Requests per second: what is the sustained rate limit?
- Response headers: `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` — how to read them
- HTTP 429 Too Many Requests: retry strategy (exponential backoff)
- OpenTofu provider: does it handle rate limiting automatically or do we need to set `max_retries`?
- GitHub Actions: if parallel jobs all run hcloud commands simultaneously, can they hit rate limits?

**Common error codes:**
- 400 Bad Request: invalid request body — how to debug (response body contains `code` and `message`)
- 401 Unauthorized: invalid or missing token
- 404 Not Found: server/resource doesn't exist
- 409 Conflict: server is in wrong state for requested action (e.g., resize while running)
- 422 Unprocessable Entity: valid JSON but logically invalid request
- 500 Internal Server Error: Hetzner-side issue — retry

**API eventual consistency:**
- After `POST /servers`, server is in `initializing` state — action must complete before SSH is available
- After firewall `apply_to_resources`, firewall is attached but takes ~5 seconds to take effect
- After `POST /servers/{id}/actions/rebuild`, server is unavailable until action completes
- How to wait for actions: poll `GET /actions/{id}` until `status == "success"`

---

### HC-9. Volumes (Persistent Block Storage)

**Volume basics:**
- Volumes are independent of servers — persist after server deletion
- MUST be in same location as the server they're attached to
- Can only be attached to ONE server at a time
- Filesystem: Hetzner formats with ext4 by default, or `filesystem_format: xfs`
- Size: minimum 10GB, maximum 10TB, increments of 1GB

**Volume use cases for our stack:**
- MinIO: persistent storage for object storage (if not using S3 directly)
- Harbor: container registry storage
- Velero: backup storage (though we use MinIO → B2 for this)
- PostgreSQL (CloudNativePG): persistent database storage

**hcloud CLI volume commands:**
- `hcloud volume create --name <name> --size <GB> --location <location>`
- `hcloud volume attach <volume_id> --server <server_id>`
- `hcloud volume detach <volume_id>`
- `hcloud volume list`
- `hcloud volume delete <volume_id>`

**API endpoints:**
- `POST /volumes` — create volume (response includes action to poll)
- `POST /volumes/{id}/actions/attach` — attach to server
- `POST /volumes/{id}/actions/format` — format filesystem (dangerous! data loss)

**OpenTofu `hcloud_volume` and `hcloud_volume_attachment`:**
- Complete resource configuration
- Lifecycle rules for preventing accidental deletion (`prevent_destroy = true`)

---

### HC-10. Hetzner Cloud vs Hetzner Robot

This is a critical distinction our agents must never confuse:

**Hetzner Cloud (what we use):**
- API: `api.hetzner.cloud/v1`
- Authentication: API Token (Bearer)
- Resources: Virtual machines (cx22, cpx31, etc.), managed with OpenTofu + hcloud CLI
- Location: Cloud datacenters (ash, hil, nbg, fsn, hel)
- Billing: Hourly, on-demand
- Our servers: helix-stax-cp, helix-stax-vps, helix-stax-test

**Hetzner Robot (NOT what we use):**
- API: `robot.hetzner.com/v1`
- Authentication: Username/password (NOT bearer token)
- Resources: Dedicated servers (physical hardware), Storagebox NAS
- Different API structure, different authentication, completely different resource types
- We do NOT use Robot — do not confuse the two APIs

**Key rule**: Any agent searching for "Hetzner API" must verify they are looking at the Cloud API, not Robot.

---

### HC-11. Snapshot Management

Creating server snapshots (OS images from running servers):

**Use cases:**
- Creating a pre-hardened AlmaLinux 9.7 snapshot to use as base image for future servers (faster provisioning)
- Backup before K3s upgrade or major changes

**hcloud CLI:**
- `hcloud server create-image <server_id> --type snapshot --description "AlmaLinux 9.7 CIS hardened 2026-03-23"`
- `hcloud image list --type snapshot`
- `hcloud image describe <snapshot_id>`
- `hcloud image delete <snapshot_id>`

**API:**
- `POST /servers/{id}/actions/create_image` — create snapshot from server
  - `type`: `"snapshot"` vs `"backup"` (scheduled backup is a paid feature)
  - `description`: human-readable label

**Using snapshots as base images:**
- Referencing snapshot by ID in `hcloud server create --image <snapshot_id>`
- In OpenTofu: `data "hcloud_image" "hardened_base" { with_selector = "snapshot-type=cis-hardened" }` — using labels on snapshots for dynamic lookup

**Snapshot rotation:**
- Keeping only the last N snapshots: cleanup script using hcloud CLI
- Snapshots are billed per GB — keep only what you need

---

### Best Practices & Anti-Patterns

- What are the top 10 best practices for using the Hetzner Cloud API in a production IaC workflow?
- What are the most common mistakes with Hetzner Cloud API? Rank by severity (critical → low).
- What API patterns look correct but silently cause problems (e.g., not polling actions, firewall timing)?
- What are the security anti-patterns for Hetzner API token management?
- What Hetzner Cloud limitations might we hit as the cluster grows (IP limits, volume limits, server limits per project)?

### Decision Matrix

| Decision | If | Use | Because |
|---|---|---|---|
| hcloud CLI vs API directly | One-off operations, scripting | hcloud CLI | Simpler, no JSON parsing needed |
| hcloud CLI vs API directly | Complex conditional logic, CI pipelines | API + curl/jq | More control |
| hcloud CLI vs OpenTofu | Resources managed as code, part of cluster | OpenTofu | State management, drift detection |
| hcloud CLI vs OpenTofu | Temporary resources (test servers, CI) | hcloud CLI | No state to maintain |
| Rebuild vs destroy+create | K3s version upgrade | Rebuild | Preserves IP, faster |
| Rebuild vs destroy+create | Complete OS change | Destroy + create | Cleaner, applies new labels |
| Private network vs public-only | Multi-node K3s cluster | Add private network | Node-to-node traffic stays internal |
| Snapshot base image vs fresh OS | Frequent server creation (CI/CD) | Snapshot | Faster boot, hardening pre-applied |
| Snapshot base image vs fresh OS | Infrequent, security-critical | Fresh OS + Ansible harden | Always latest OS patches |
| cx22 vs cpx31 for test server | Molecule testing only | cx22 | Half the cost, sufficient for testing |

### Common Pitfalls

- Not polling the action object after server creation: SSH may not be available yet even though the API returned 200
- Firewall rules not taking effect immediately: Hetzner firewall attachment has ~5 second propagation delay
- Using Hetzner Robot documentation instead of Cloud API documentation: completely different API
- Deleting a server that has a volume attached: volume persists but is no longer accessible until re-attached
- SSH key injection at creation time vs post-creation: keys can ONLY be injected via user_data or at creation time, NOT via API after server is running
- AlmaLinux 9 image ID changes: Hetzner updates images and the image ID changes — never hardcode image ID, always use name or data source lookup
- Creating servers in wrong datacenter (ash vs hil): volumes and private networks are location-specific — server, volume, and network must all be in same location
- Orphaned test servers: CI job cancelled mid-run leaves servers running — implement label-based cleanup
- Rate limiting in parallel CI jobs: multiple concurrent GitHub Actions runs all calling hcloud API can hit 3,600/hour limit

---

## Required Output Format

For each tool covered in this prompt, structure your output as THREE clearly separated sections using these exact headers:

### ## SKILL.md Content
Core reference that an AI agent needs daily:
- hcloud CLI quick reference (most-used commands with real examples)
- API quick reference (key endpoints with curl examples)
- Server types and pricing table (current pricing for cx22, cpx31, ccx)
- Label patterns for Helix Stax (standard labels our agents apply)
- Action polling pattern (how to wait for async operations)
- Troubleshooting decision tree (API errors → diagnosis → fix)
- Keep under 500 lines — concise, actionable, no theory

### ## reference.md Content
Deep specifications for complex tasks:
- Complete `POST /servers` request body schema with all fields
- Complete firewall rule format and API structure
- Complete server object response schema (all fields)
- All server types with current pricing
- Rate limit headers reference
- Cloud-init user_data schema for AlmaLinux 9
- Hetzner Cloud vs Robot: complete comparison table

### ## examples.md Content
Copy-paste-ready examples specific to Helix Stax:
- Real configurations using our IPs (178.156.233.12, 5.78.145.30), locations (ash, hil), user `wakeem`
- `hcloud server create` command for helix-stax-test (cx22, ash, AlmaLinux 9, SSH key, firewall, labels)
- `hcloud server create` command for a production server (cpx31, ash, AlmaLinux 9, all labels)
- Complete cloud-init user_data YAML for `wakeem` user with SSH key and Python 3
- Action polling script (bash loop: poll action until success or error)
- Label-based test server cleanup script (`cleanup-molecule-servers.sh`)
- Dynamic Ansible inventory via hcloud CLI: `hcloud server list --selector role=worker -o json | jq` to build inventory JSON
- Step-by-step runbook: "Provision a new worker node from scratch using hcloud CLI"
- `curl` examples for every API endpoint we use (create server, create firewall, attach firewall, list by label)

Use `# Hetzner Cloud API` as the top-level header for the output.

Be thorough, opinionated, and practical. Include actual curl commands with real header formats, actual hcloud CLI flags, actual cloud-init YAML, and actual jq expressions for parsing responses. Do NOT give theory — give copy-paste-ready commands for managing Hetzner Cloud servers running AlmaLinux 9.7 for a K3s cluster.
