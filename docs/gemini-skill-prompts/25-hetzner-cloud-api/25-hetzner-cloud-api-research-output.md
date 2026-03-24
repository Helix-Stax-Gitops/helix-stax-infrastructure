# Hetzner Cloud API

This document provides a comprehensive guide to the Hetzner Cloud API, the `hcloud` CLI, and related concepts for use by Helix Stax's AI agents. It is tailored to our specific infrastructure and workflows.

---
---

### ## SKILL.md Content
This is the core quick-reference for daily operations.

#### **Quick Authentication Reference**

*   **hcloud CLI & OpenTofu**: Set the environment variable `HCLOUD_TOKEN`.
    ```bash
    export HCLOUD_TOKEN="your-api-token-here"
    ```
*   **Direct API**: Use the `Authorization` header.
    ```bash
    curl -H "Authorization: Bearer $HCLOUD_TOKEN" https://api.hetzner.cloud/v1/servers
    ```

#### **Core `hcloud` CLI Commands**

| Command | Example |
| :--- | :--- |
| **List Servers** | `hcloud server list -o noheader` |
| **List by Label** | `hcloud server list --selector environment=prod` |
| **Get Server IP** | `hcloud server ip helix-stax-cp` |
| **Create Test Server** | `hcloud server create --name helix-stax-test-$(openssl rand -hex 2) --type cx22 --image almalinux-9 --location ash --label purpose=molecule-test --label environment=test` |
| **Delete Server** | `hcloud server delete helix-stax-test-xyz` |
| **Get Server Details** | `hcloud server describe helix-stax-cp -o json` |
| **List Firewalls** | `hcloud firewall list` |
| **Add Firewall Rule** | `hcloud firewall add-rule prod-firewall --direction in --protocol tcp --port 2222 --source-ips 0.0.0.0/0,::/0` |
| **List SSH Keys**| `hcloud ssh-key list`                 |
| **List Locations**| `hcloud location list`               |
| **List Server Types**| `hcloud server-type list`            |

#### **Core REST API Endpoints**

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/servers` | List all servers. Filter with `?label_selector=key==value`. |
| `POST` | `/servers` | Create a new server. Asynchronous; returns an `action` object to poll. |
| `GET` | `/servers/{id}` | Get details for a single server. |
| `DELETE` | `/servers/{id}` | Permanently delete a server. |
| `GET` | `/actions/{id}` | Get the status of a long-running action (e.g., server create). |
| `POST` | `/firewalls/{id}/actions/set_rules` | Atomically replace all rules on a firewall. |

#### **Helix Stax Standard Labels**

Apply these labels to all servers via `hcloud server add-label <server> key=value` or at creation.

| Key | Example Value | Purpose |
| :--- | :--- | :--- |
| `environment` | `prod`, `test` | Segregates production and temporary resources. |
| `role` | `control-plane`, `worker` | Defines the server's function in the K3s cluster. |
| `purpose` | `molecule-test` | Marks ephemeral servers for automated cleanup. |
| `managed-by` | `opentofu`, `ci-script` | Identifies the provisioning tool. |
| `k3s-version`| `v1.30.0` | Tracks the installed Kubernetes version. |

#### **Action Polling Pattern (Bash)**

After creating a server, poll the action `id` until `status` is `success`.

```bash
# After `hcloud server create ...` or a POST /servers API call
ACTION_ID="12345" # Get this from the API response
while true; do
  STATUS=$(hcloud action status "$ACTION_ID")
  echo "Action $ACTION_ID status: $STATUS"
  if [[ "$STATUS" == "success" ]]; then
    break
  elif [[ "$STATUS" == "error" ]]; then
    echo "Action failed!" >&2
    exit 1
  fi
  sleep 5
done
```

#### **Server Types & Pricing (Our Usage)**

| Type | vCPU | RAM | Disk | Location | Approx. Monthly |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cx22` | 2 | 4 GB | 40 GB NVMe | `ash`, `hil` | $5.99 / €5.58 |
| `cpx31` | 4 | 8 GB | 160 GB NVMe | `ash`, `hil` | $12.99 / €12.49 |

#### **Troubleshooting Decision Tree**

1.  **Symptom: `401 Unauthorized`**
    *   **Diagnosis**: `HCLOUD_TOKEN` is missing, invalid, or revoked.
    *   **Fix**: Verify the token is set correctly and exists in the Hetzner Cloud Console. Regenerate if necessary.

2.  **Symptom: `404 Not Found`**
    *   **Diagnosis**: The resource ID or name is incorrect.
    *   **Fix**: Use `hcloud <resource> list` to verify the exact name or ID.

3.  **Symptom: `409 Conflict`**
    *   **Diagnosis**: Server is in a state incompatible with the action (e.g., resizing a running server).
    *   **Fix**: Power off the server (`hcloud server poweroff`) before attempting the action.

4.  **Symptom: SSH Connection Refused after create**
    *   **Diagnosis**: Script is not waiting for the server creation action to complete. The server is still `initializing`.
    *   **Fix**: Implement the Action Polling Pattern.

5.  **Symptom: Firewall rules not working**
    *   **Diagnosis**: Firewall attachment has a propagation delay (~5 seconds).
    *   **Fix**: Add a `sleep 5` or `sleep 10` after applying firewall rules before testing connectivity.

---
---

### ## reference.md Content
This is the deep reference manual with complete specifications.

#### **HC-1. API Authentication**

*   **API Token Generation**:
    1.  Log in to Hetzner Cloud Console: `console.hetzner.cloud`
    2.  Select your project.
    3.  Navigate to **Security** -> **API Tokens**.
    4.  Click **Generate API Token**.
    *   **Permissions**: Select **Read & Write**. We need write permissions for provisioning, deletion, and management.
    *   **Token Scopes**: Hetzner API tokens are **all-or-nothing** for the project (either Read-only or Read & Write). There are no fine-grained scopes per resource type like with Cloudflare.

*   **Token Consumption**:
    *   **`hcloud` CLI**:
        1.  **Environment Variable (preferred for CI/scripts)**: `export HCLOUD_TOKEN="<token>"`. This automatically authenticates all `hcloud` commands.
        2.  **Context File**: `hcloud context create helix-stax-prod` will prompt for a token. This stores the token in `~/.config/hcloud/cli.toml`. Use `hcloud context use <name>` to switch between projects.
    *   **OpenTofu Provider**: The provider checks for the `HCLOUD_TOKEN` environment variable first, then the `hcloud` context file.
    *   **Direct API Request**:
        ```
        Authorization: Bearer <token>
        ```

*   **Token Rotation Procedure**:
    1.  Generate a **new** Read & Write token in the Hetzner Cloud Console.
    2.  Update the token in all consumers:
        *   GitHub Actions: Update the `HCLOUD_TOKEN` repository or organization secret.
        *   OpenTofu: If using env vars, update where they are set. If using a vault, update the secret in Ansible Vault or OpenBao.
        *   Local `hcloud` CLI: Run `hcloud context create` with the same name to overwrite the old token, or create a new context.
    3.  Run `tofu plan` or a test `hcloud` command to verify the new token works.
    4.  **Delete** the old token from the Hetzner Cloud Console.

#### **HC-3. REST API Endpoints: Schemas**

*   **Base URL**: `https://api.hetzner.cloud/v1`

*   **`POST /servers` Request Body Schema**:
    ```json
    {
      "name": "string",                     // Required. Server name.
      "server_type": "string",              // Required. ID or name (e.g., "cpx31").
      "image": "string",                    // Required. ID or name (e.g., "almalinux-9").
      "location": "string",                 // Optional. Name of location (e.g., "ash").
      "start_after_create": true,           // Optional. Defaults to true.
      "ssh_keys": ["string" | "integer"],   // Optional. Array of SSH Key names or IDs.
      "firewalls": [{"firewall": "integer"}], // Optional. Array of firewall IDs to attach.
      "networks": ["integer"],              // Optional. Array of private network IDs to attach.
      "user_data": "string",                // Optional. Cloud-init script.
      "labels": { "key": "value" },         // Optional. Key-value labels.
      "automount": false,                   // Optional. Defaults to false. Auto-mount volumes.
      "volumes": ["integer"],               // Optional. Array of volume IDs to attach.
      "placement_group": "integer"          // Optional. ID of a placement group.
    }
    ```

*   **`GET /servers/{id}` Response Body Schema (Server Object)**:
    ```json
    {
      "id": 4711,
      "name": "helix-stax-cp",
      "status": "running", // initializing, starting, running, stopping, off, deleting, migrating, rebuilding, unknown
      "created": "2024-03-24T12:00:00Z",
      "public_net": {
        "ipv4": {
          "ip": "178.156.233.12",
          "blocked": false,
          "dns_ptr": "static.12.233.156.178.clients.your-server.de"
        },
        "ipv6": {
          "ip": "2a01:4f8:1c17:1a79::/64",
          "blocked": false
        },
        "floating_ips": []
      },
      "private_net": [ // Only present if attached to a network
        {
          "network": 4712,
          "ip": "10.0.1.2",
          "alias_ips": [],
          "mac_address": "86:00:00:27:71:02"
        }
      ],
      "server_type": {
        "id": 5, // cpx31
        "name": "cpx31",
        "description": "...",
        "cores": 4,
        "memory": 8.0,
        "disk": 160,
        "storage_type": "local", // or "network" for ceph-based types
        "cpu_type": "shared"
      },
      "datacenter": {
        "id": 4,
        "name": "ash-dc1",
        "description": "Ashburn, VA",
        "location": {
          "id": 3,
          "name": "ash",
          "description": "Ashburn, VA",
          "country": "US",
          "city": "Ashburn",
          "latitude": 39.0437,
          "longitude": -77.4875,
          "network_zone": "us-east"
        }
      },
      "image": {
        "id": 155126027,
        "type": "system",
        "status": "available",
        "name": "almalinux-9",
        "description": "AlmaLinux 9.4",
        "os_flavor": "almalinux",
        "os_version": "9.4",
        "architecture": "x86",
        "created": "..."
      },
      "iso": null,
      "rescue_enabled": false,
      "locked": false,
      "backup_window": null,
      "outgoing_traffic": 123456, // in bytes
      "ingoing_traffic": 12345, // in bytes
      "included_traffic": 21990232555520, // 20 TB
      "protection": {
        "delete": false,
        "rebuild": false
      },
      "labels": {
        "environment": "prod",
        "role": "control-plane"
      },
      "volumes": [],
      "primary_disk_size": 160
    }
    ```

*   **`POST /firewalls/{id}/actions/set_rules` Request Body Schema**:
    This action atomically replaces all existing rules. To add a rule, you must fetch existing rules and submit them along with the new one.
    ```json
    {
      "rules": [
        {
          "direction": "in",
          "protocol": "tcp",
          "port": "2222",
          "source_ips": ["0.0.0.0/0", "::/0"]
        },
        {
          "direction": "in",
          "protocol": "icmp",
          "source_ips": ["0.0.0.0/0", "::/0"]
        },
        {
          "direction": "out",
          "protocol": "any",
          "port": "any",
          "destination_ips": ["0.0.0.0/0", "::/0"]
        }
      ]
    }
    ```

#### **HC-4. Cloud-init User Data**

*   **Execution**: Cloud-init runs only on the very first boot of a new server. It is ignored on subsequent reboots. The `user_data` field accepts a string containing either a shell script (starts with `#!`) or YAML (starts with `#cloud-config`).
*   **AlmaLinux 9 Support**: AlmaLinux 9 has excellent cloud-init support. Modules like `users`, `ssh_authorized_keys`, `package_update`, `packages`, `write_files`, and `runcmd` are fully supported.
*   **Debugging**:
    *   Logs: `/var/log/cloud-init.log` and `/var/log/cloud-init-output.log`
    *   Status: `cloud-init status`
    *   Wait for completion: `cloud-init status --wait`
*   **SSH Keys**: `ssh_authorized_keys` under a `users` entry adds the key for that specific user. A top-level `ssh_authorized_keys` adds the key to the default user of the image (`root` for AlmaLinux). For our use case, we specify it per-user.
*   **SSH Port Change**: Changing the SSH port via `runcmd` is risky. If the command fails, or if the firewall isn't updated, you can lock yourself out before Ansible has a chance to connect. The best practice is to let Ansible manage `sshd_config` after it connects on the standard (or our standard `2222`) port.

#### **HC-6. Server Types & Pricing (Full List)**

*All prices are approximate and subject to change. Check `GET /pricing` for real-time data.*

**CX Series (Shared Intel/AMD)**
| Name | vCPU | Memory | Disk | Monthly Price (USD) |
|---|---|---|---|---|
| `cx11` | 1 | 2 GB | 20 GB | $4.49 |
| `cx21` | 2 | 4 GB | 40 GB | $6.49 |
| `cx22` | 2 | 4 GB | 40 GB NVMe | $5.99 |
| `cx31` | 2 | 8 GB | 80 GB | $11.49 |
| `cx32` | 2 | 8 GB | 80 GB NVMe | $11.49 |
| `cx41` | 4 | 16 GB | 160 GB | $21.49 |
| `cx42` | 4 | 16 GB | 160 GB NVMe | $21.99 |
| `cx51` | 8 | 32 GB | 240 GB | $42.49 |
| `cx52` | 8 | 32 GB | 240 GB NVMe | $43.99 |

**CPX Series (Shared AMD EPYC Performance)**
| Name | vCPU | Memory | Disk | Monthly Price (USD) |
|---|---|---|---|---|
| `cpx11` | 2 | 2 GB | 40 GB NVMe | $5.99 |
| `cpx21` | 3 | 4 GB | 80 GB NVMe | $9.49 |
| **`cpx31`** | **4** | **8 GB** | **160 GB NVMe** | **$12.99** |
| `cpx41` | 8 | 16 GB | 240 GB NVMe | $24.99 |
| `cpx51` | 16 | 32 GB | 360 GB NVMe | $48.49 |

**CCX Series (Dedicated vCPU AMD EPYC)**
| Name | vCPU | Memory | Disk | Monthly Price (USD) |
|---|---|---|---|---|
| `ccx13` | 2 | 8 GB | 80 GB NVMe | $36.99 |
| `ccx23` | 4 | 16 GB | 160 GB NVMe | $68.99 |
| `ccx33` | 8 | 32 GB | 240 GB NVMe | $130.99 |

#### **HC-8. Rate Limits & Error Handling**

*   **Limits**:
    *   **Global Limit**: 3,600 requests per project per hour, per token.
    *   **"Writer" Limit**: 1,800 write requests (POST, PUT, DELETE) per hour.
    *   **Sustained Rate**: The limit averages to 1 request/second. Bursts are allowed.
*   **Response Headers**:
    *   `RateLimit-Limit`: The total number of requests allowed in the time window (3600).
    *   `RateLimit-Remaining`: The number of requests left in the current window.
    *   `RateLimit-Reset`: A Unix timestamp indicating when the limit will reset.
*   **OpenTofu Provider**: The `hcloud` provider has built-in retry logic for rate limiting and other transient errors. It respects the rate-limit headers.
*   **GitHub Actions**: Parallel jobs share the same token and thus the same rate limit pool. For high-volume parallel runs, this could be an issue. A best practice is to use separate tokens for logically separate CI workflows if they run concurrently and are API-heavy.

#### **HC-10. Hetzner Cloud vs. Hetzner Robot**

| Feature | Hetzner Cloud (We Use This) | Hetzner Robot (We DO NOT Use) |
| :--- | :--- | :--- |
| **Service Type** | Virtual Cloud Servers (VMs) | Dedicated Physical Servers, Storage Boxes |
| **API Endpoint** | `https://api.hetzner.cloud/v1` | `https://robot-ws.your-server.de` |
| **Authentication** | API Token (`Authorization: Bearer ...`) | Username & Password (HTTP Basic Auth) |
| **Tooling** | `hcloud` CLI, OpenTofu `hcloud` provider | `hetzner-robot-cli`, various community tools |
| **Provisioning** | Instant, On-demand via API | Slower, sometimes manual setup via web UI |
| **Billing** | Hourly / Monthly | Monthly / Annually |
| **Resources** | `hcloud_server`, `hcloud_volume` | Bare-metal servers, storage boxes, failover IPs |
| **Our Servers**| `helix-stax-cp`, `helix-stax-vps` | None |
| **Agent Rule** | **ALWAYS use this API.** | **NEVER use this API or its documentation.** |

---
---

### ## examples.md Content
This file contains copy-paste-ready commands and scripts for the Helix Stax environment.

#### **`hcloud` CLI Examples**

**1. Create a Temporary Test Server**
This command creates a `cx22` server in Ashburn for a Molecule test run. It uses a random suffix to avoid name collisions and applies cleanup labels.
```bash
# Set SSH key name (as it appears in Hetzner Cloud Console)
HCLOUD_SSH_KEY_NAME="wakeem-ed25519-mbp"
# Set Firewall name
HCLOUD_FIREWALL_NAME="prod-vps-firewall" # Assuming a pre-existing firewall

hcloud server create \
  --name "helix-stax-test-$(openssl rand -hex 3)" \
  --type "cx22" \
  --image "almalinux-9" \
  --location "ash" \
  --ssh-key "$HCLOUD_SSH_KEY_NAME" \
  --firewall "$HCLOUD_FIREWALL_NAME" \
  --label "environment=test" \
  --label "purpose=molecule-test" \
  --label "managed-by=ci-script"
```

**2. Create a Production Worker Node**
This creates a `cpx31` server in Hillsboro to join the production cluster.
```bash
# These should be set in environment
HCLOUD_SSH_KEY_NAME="wakeem-ed25519-mbp"
HCLOUD_FIREWALL_NAME="prod-vps-firewall"
HCLOUD_NETWORK_NAME="prod-private-net"

hcloud server create \
  --name "helix-stax-worker-01" \
  --type "cpx31" \
  --image "almalinux-9" \
  --location "hil" \
  --ssh-key "$HCLOUD_SSH_KEY_NAME" \
  --firewall "$HCLOUD_FIREWALL_NAME" \
  --network "$HCLOUD_NETWORK_NAME" \
  --label "environment=prod" \
  --label "role=worker" \
  --label "managed-by=opentofu"
```

#### **Cloud-Init user_data for AlmaLinux 9**

This YAML file, passed in the `user_data` field, creates the `wakeem` admin user, installs necessary packages, and enables SELinux.

**File: `cloud-init.yaml`**
```yaml
#cloud-config
#
# Creates the 'wakeem' user with passwordless sudo and an authorized SSH key.
# Updates the system and installs baseline packages required for Ansible.
# Enforces SELinux.

users:
  - name: wakeem
    groups: [wheel, sudo]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    # IMPORTANT: Replace with the actual public key string
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxxxxxxxxxxxxxxxxxxxxxxxx wakeem@mbp"
    shell: /bin/bash

# Update all packages on first boot
package_update: true

# Install Python for Ansible, git for source control
packages:
  - python3
  - git

# Perform system commands on first boot
runcmd:
  # Enable SELinux at runtime
  - setenforce 1
  # Make SELinux enforcing persistent across reboots
  - sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

#### **Core `curl` API Examples**

**1. List all production servers using a label selector**
```bash
curl -X GET \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  'https://api.hetzner.cloud/v1/servers?label_selector=environment==prod'
```

**2. Create a new server (API equivalent of `hcloud create`)**
Note: This requires getting IDs for image, server_type, location, and ssh_key first.
```bash
# Data for the API call in JSON format
read -r -d '' SERVER_PAYLOAD << EOM
{
  "name": "api-test-server",
  "server_type": "cx22",
  "image": "almalinux-9",
  "location": "ash",
  "labels": {
    "managed-by": "api-curl",
    "purpose": "api-test"
  },
  "ssh_keys": ["wakeem-ed25519-mbp"],
  "user_data": "#cloud-config\npackage_update: true\npackages:\n  - htop"
}
EOM

curl -X POST \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$SERVER_PAYLOAD" \
  'https://api.hetzner.cloud/v1/servers'
```

**3. Poll an Action**
The `POST /servers` response contains an `action` object. Use its `id`.
```bash
ACTION_ID=$(... get id from previous response ...)
curl -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/actions/$ACTION_ID"
```

#### **Scripts for Automation**

**1. Action Polling Script (`poll-action.sh`)**
This script robustly waits for an action to complete.
```bash
#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <action-id>" >&2
  exit 1
fi
ACTION_ID="$1"

echo "Polling action $ACTION_ID..."

while true; do
  RESPONSE=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/actions/$ACTION_ID")
  STATUS=$(echo "$RESPONSE" | jq -r '.action.status')
  COMMAND=$(echo "$RESPONSE" | jq -r '.action.command')

  if [[ "$STATUS" == "success" ]]; then
    echo "Action '$COMMAND' ($ACTION_ID) completed successfully."
    exit 0
  elif [[ "$STATUS" == "error" ]]; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.action.error.message')
    echo "Error: Action '$COMMAND' ($ACTION_ID) failed: $ERROR_MSG" >&2
    exit 1
  else
    echo " -> Status: $STATUS..."
    sleep 5
  fi
done
```

**2. Orphaned Molecule Server Cleanup (`cleanup-molecule-servers.sh`)**
Finds and destroys all servers with the label `purpose=molecule-test` that are older than 2 hours.
```bash
#!/bin/bash
set -euo pipefail

# Get current time in UTC, minus 2 hours
CUTOFF_TIMESTAMP=$(date -u -v-2H +"%Y-%m-%dT%H:%M:%SZ")

echo "Searching for test servers created before $CUTOFF_TIMESTAMP..."

# Get list of servers with the molecule label, output as JSON
SERVERS_JSON=$(hcloud server list --selector purpose=molecule-test -o json)

# Filter servers older than the cutoff and get their IDs
ORPHAN_IDS=$(echo "$SERVERS_JSON" | jq -r ".[] | select(.created < \"$CUTOFF_TIMESTAMP\") | .id")

if [[ -z "$ORPHAN_IDS" ]]; then
  echo "No orphaned test servers found."
  exit 0
fi

echo "Found orphaned servers. The following will be deleted:"
for ID in $ORPHAN_IDS; do
  # Use hcloud describe to show name and ID for better logging
  hcloud server describe "$ID" -o '{{.Name}} (ID: {{.ID}})'
done

# Confirmation prompt
read -p "Proceed with deletion? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Deletion cancelled."
  exit 1
fi

# Delete the servers
for ID in $ORPHAN_IDS; do
  echo "Deleting server $ID..."
  hcloud server delete "$ID"
done

echo "Cleanup complete."
```

#### **Runbook: Provision a New K3s Worker Node**

**Goal**: Add a new worker node `helix-stax-worker-02` in Hillsboro (`hil`) to the cluster.

1.  **Set Environment Variables**:
    ```bash
    export HCLOUD_TOKEN="your-api-token"
    export HCLOUD_SSH_KEY_NAME="wakeem-ed25519-mbp"
    export HCLOUD_FIREWALL_NAME="prod-vps-firewall"
    export HCLOUD_NETWORK_NAME="prod-private-net"
    ```

2.  **Prepare Cloud-init File (`worker-cloud-init.yaml`)**: Copy the standard `cloud-init.yaml` from above, ensuring the `wakeem` user and SSH key are correct.

3.  **Create the Server using `hcloud` CLI**:
    ```bash
    echo "Creating server helix-stax-worker-02..."
    CREATE_OUTPUT=$(hcloud server create \
      --name "helix-stax-worker-02" \
      --type "cpx31" \
      --image "almalinux-9" \
      --location "hil" \
      --ssh-key "$HCLOUD_SSH_KEY_NAME" \
      --firewall "$HCLOUD_FIREWALL_NAME" \
      --network "$HCLOUD_NETWORK_NAME" \
      --user-data-from-file "./worker-cloud-init.yaml" \
      --label "environment=prod" \
      --label "role=worker" \
      --label "managed-by=cli-manual")

    ACTION_ID=$(echo "$CREATE_OUTPUT" | grep 'Action' | awk '{print $NF}')
    SERVER_IP=$(echo "$CREATE_OUTPUT" | grep 'IPv4' | awk '{print $2}')
    ```

4.  **Wait for Server to be Ready**: Use the polling script.
    ```bash
    ./poll-action.sh "$ACTION_ID"
    ```

5.  **Verify SSH Access**:
    ```bash
    echo "Waiting for SSH daemon to be ready..."
    sleep 20 # Give cloud-init and sshd a moment after action success
    ssh -p 2222 wakeem@"$SERVER_IP" 'echo "SSH connection successful"'
    ```

6.  **Run Ansible Playbook**: Now that the server is up and accessible, use Ansible to install K3s and configure it as a worker.
    ```bash
    # (Example command, depends on your Ansible setup)
    ansible-playbook -i "$SERVER_IP," --user wakeem --private-key ~/.ssh/id_ed25519 playbooks/k3s-worker.yml
    ```

7.  **Verify Node Joined Cluster**: On the control plane node (`helix-stax-cp`).
    ```bash
    kubectl get nodes -o wide
    # You should see helix-stax-worker-02 in the list with a 'Ready' status.
    ```
