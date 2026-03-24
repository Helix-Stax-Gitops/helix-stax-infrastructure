Here is the comprehensive research document formatted for your AI agents, based on the detailed requirements for the Helix Stax infrastructure.

***

# AlmaLinux 9.7 — systemd

### ## SKILL.md Content
```markdown
# systemd Quick Reference

## Service Management
- **Start/Stop:** `systemctl start <unit>`, `systemctl stop <unit>`
- **Enable/Disable on boot:** `systemctl enable <unit>`, `systemctl disable <unit>`
- **Restart:** `systemctl restart <unit>`
- **Reload config without restart:** `systemctl reload <unit>`
- **Apply changes to unit files:** `systemctl daemon-reload`
- **Mask (prevent start):** `systemctl mask <unit>`
- **Unmask:** `systemctl unmask <unit>`

## Status and Introspection
- **Check service status:** `systemctl status <unit>`
- **Check if enabled:** `systemctl is-enabled <unit>`
- **Show all properties:** `systemctl show <unit>`
- **List all running units:** `systemctl list-units --type=service --state=running`
- **List all timers:** `systemctl list-timers --all`

## Journal (Logs)
- **View logs for a unit:** `journalctl -u <unit>`
- **Follow logs in real-time:** `journalctl -f -u <unit>`
- **Show last 100 lines:** `journalctl -n 100 -u <unit>`
- **Show errors and worse:** `journalctl -p err -u <unit>`
- **Show logs since a time:** `journalctl --since "1 hour ago"`
- **Disable pager for scripting:** `journalctl --no-pager`
- **Show extra details:** `journalctl -x`

## Unit File Basics
- **Location:** System units are in `/usr/lib/systemd/system/`. Custom/override units are in `/etc/systemd/system/`.
- **Drop-in override:** Create `/etc/systemd/system/<unit.service>.d/override.conf`.
- **Example Drop-in:**
  ```ini
  # /etc/systemd/system/k3s.service.d/override.conf
  [Service]
  # Security: Use EnvironmentFile=/etc/k3s/token (chmod 600) instead of inline Environment=
  EnvironmentFile=/etc/k3s/token
  CPUQuota=80%
  ```
- After creating/editing a unit or drop-in, always run `systemctl daemon-reload`.

## Troubleshooting Flow
1.  **Symptom:** Service fails to start.
2.  **`systemctl status <unit.service>`:** Check for an immediate error message.
3.  **`journalctl -u <unit.service> -n 200 --no-pager`:** Look for specific errors from the service binary.
4.  **`systemctl show <unit.service>`:** Check loaded properties. Is `ExecStart` correct? Are permissions right?
5.  **Check Dependencies:** Is a `Requires=` or `After=` service also failing?
6.  **Failed State:**
    - Examine logs for exit codes.
    - Validate configuration files used by the service.
    - Check SELinux denials: `journalctl -p err | grep "AVC"`
    - Check file paths and permissions defined in the unit.
7.  **Activating State (Stuck):**
    - The service's readiness protocol (`Type=notify`) might not be sending the "ready" signal.
    - A dependency is stuck in `activating`. Check the status of units listed in `Wants=` and `Requires=`.
```

### ## reference.md Content
```markdown
# systemd Deep Reference

## Unit File Anatomy

### `[Unit]` Section
- `Description=`: Human-readable description.
- `Documentation=`: URIs to documentation.
- `After=`: This unit will start *after* the listed units have finished starting. Does not imply a dependency.
- `Before=`: Inverse of `After=`.
- `Wants=`: A weaker dependency. If a wanted unit fails to start, this unit will continue.
- `Requires=`: A strong dependency. If a required unit fails, this unit is also stopped. If this unit is started, the required unit is also started.
- `PartOf=`: Binds two units together. Stopping or restarting one will do the same to the other.
- `BindsTo=`: Stronger version of `Requires=`. If the bound unit disappears (e.g., unplugged USB), this unit is stopped.

### `[Service]` Section
- `Type=`: `simple` (default), `forking`, `oneshot`, `dbus`, `notify`, `idle`. `notify` is common for daemons that signal readiness.
- `ExecStart=`: The command to run to start the service.
- `ExecStartPre=`, `ExecStartPost=`: Commands run before/after `ExecStart`.
- `ExecReload=`: Command to run for `systemctl reload`.
- `ExecStop=`: Command to run to stop the service.
- `Restart=`: `no`, `on-success`, `on-failure`, `on-abnormal`, `on-watchdog`, `always`.
- `RestartSec=`: Seconds to wait before restarting.
- `User=`, `Group=`: Run the service as this user/group.
- `WorkingDirectory=`: Change to this directory before executing.
- `Environment=`: `KEY=value`. Set environment variables.
- `EnvironmentFile=`: Path to a file containing environment variables.

#### Resource Control (cgroup v2)
- `CPUQuota=`: Percentage of CPU time limit (e.g., `50%` for half a core).
- `MemoryLimit=`: Memory limit (e.g., `500M`, `1G`).
- `IOWeight=`: I/O weight for block devices (10-1000).

#### Security Hardening
- `NoNewPrivileges=true`: Prevents the service and its children from gaining new privileges (e.g., via `suid`).
- `PrivateTmp=true`: Mounts a private `/tmp` and `/var/tmp` for the service, non-visible to other processes.
- `ProtectSystem=full`: Mounts `/usr`, `/boot`, `/etc` as read-only. `strict` adds `/` as well.
- `ReadOnlyPaths=`: Specifies additional paths to mount as read-only.
- `ReadWritePaths=`: Specifies paths to keep writable even with `ProtectSystem` or `ReadOnlyPaths`.
- `ProtectHome=true`: Makes home directories inaccessible.
- `DevicePolicy=strict`: Only allows access to standard devices like `/dev/null`, `/dev/zero`, `/dev/random`.

### `[Install]` Section
- `WantedBy=`: Declares which target should "want" this unit. For services, this is typically `multi-user.target`. Enables the unit with `systemctl enable`.
- `RequiredBy=`: Similar to `WantedBy`, but for `Requires=` dependencies.

## Timers (`.timer` units)
- Replaces cron jobs. A `.timer` unit controls a `.service` unit of the same name.
- Example: `backup.timer` triggers `backup.service`.

### `[Timer]` Section
- `OnCalendar=`: Defines a calendar event. Syntax: `DayOfWeek Year-Month-Day Hour:Minute:Second`. `*` is a wildcard.
  - `*-*-* 02:00:00`: Every day at 2 AM.
  - `hourly`: Once per hour.
  - `Mon *-*-1..7 03:00:00`: The first Monday of every month at 3 AM.
- `Persistent=true`: If the machine was off when the timer should have run, it will run as soon as possible after boot.
- `RandomizedDelaySec=`: Wait a random time up to this value before starting. Spreads load.

## Drop-in Overrides vs. Editing
- **Use Drop-ins (`/etc/systemd/system/<unit>.d/override.conf`) when:**
  - You are modifying a unit file provided by a package (`k3s.service`). This prevents your changes from being overwritten on package updates.
  - You only need to add or change a few directives.
- **Edit the full unit file (`/etc/systemd/system/<unit.service>`) when:**
  - You are creating a completely new custom service.
  - You need to remove directives, which drop-ins cannot easily do (requires setting the directive to an empty value, e.g., `ExecStart=`).

## Troubleshooting
- **Circular Dependencies:** `systemd-analyze verify default.target` can help detect loops. Logs will often mention the dependency cycle.
- **journalctl Vacuuming:**
  - Check usage: `journalctl --disk-usage`
  - Vacuum to a size: `journalctl --vacuum-size=500M`
  - Vacuum to a time: `journalctl --vacuum-time=2d`
```

### ## examples.md Content
```markdown
# systemd Examples for Helix Stax

## Example 1: Create a Custom System Service
We need a simple service to continuously `ping` Cloudflare's DNS for health checking.

**1. Create the service unit file:**
```bash
sudo nano /etc/systemd/system/cloudflare-pinger.service
```

**File content:**
```ini
# /etc/systemd/system/cloudflare-pinger.service
[Unit]
Description=Continuously pings Cloudflare DNS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=nobody
Group=nobody
ExecStart=/usr/bin/ping 1.1.1.1
Restart=on-failure
RestartSec=5s

# Security Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
DevicePolicy=strict

[Install]
WantedBy=multi-user.target
```

**2. Manage the service:**
```bash
# Reload systemd to read the new file
sudo systemctl daemon-reload

# Start the service
sudo systemctl start cloudflare-pinger.service

# Check its status
sudo systemctl status cloudflare-pinger.service

# View its logs
journalctl -f -u cloudflare-pinger.service

# Enable it to start on boot
sudo systemctl enable cloudflare-pinger.service
```

## Example 2: Create a Timer to Run a Daily Backup Script
Let's create a timer to run a script every night at 3:05 AM.

**1. Create the service file (what the timer will run):**
```bash
sudo nano /etc/systemd/system/daily-backup.service
```
```ini
# /etc/systemd/system/daily-backup.service
[Unit]
Description=Daily Backup Script for Helix Stax
# This service is triggered by a timer, not enabled directly

[Service]
Type=oneshot
ExecStart=/usr/local/bin/run-backup.sh
```

**2. Create the timer file:**
```bash
sudo nano /etc/systemd/system/daily-backup.timer
```
```ini
# /etc/systemd/system/daily-backup.timer
[Unit]
Description=Run Daily Backup Script every day at 3:05 AM

[Timer]
OnCalendar=*-*-* 03:05:00
RandomizedDelaySec=60s
Persistent=true

[Install]
WantedBy=timers.target
```

**3. Enable and start the timer:**
```bash
sudo systemctl daemon-reload

# Enable the timer (NOT the service)
sudo systemctl enable daily-backup.timer

# Start the timer
sudo systemctl start daily-backup.timer

# Check the status of all timers
sudo systemctl list-timers
# NEXT                        LEFT          LAST                         PASSED       UNIT                ACTIVATES
# Wed 2023-10-25 03:05:00 UTC 8h left       n/a                          n/a          daily-backup.timer  daily-backup.service
```

## Example 3: Add a Resource Limit to K3s via a Drop-in
Let's limit the K3s server process to 75% of the total CPU capacity on the `helix-stax-cp` node to reserve resources for other agents.

**1. Create the drop-in directory and file:**
```bash
sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo nano /etc/systemd/system/k3s.service.d/resource-limits.conf
```

**File content:**
```ini
# /etc/systemd/system/k3s.service.d/resource-limits.conf
[Service]
# On a CX32 with 4 vCPUs, this limits K3s server to 3 vCPUs worth of time.
CPUQuota=300%
MemoryLimit=4G
```

**2. Apply the changes:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart k3s.service
```

**3. Verify the change:**
```bash
sudo systemctl show k3s | grep -E "CPUQuota|MemoryLimit"
# CPUQuotaPerSecUSec=3000000
# MemoryLimit=4294967296
```
---

# AlmaLinux 9.7 — SELinux

### ## SKILL.md Content
```markdown
# SELinux Quick Reference

## Core Commands
- **Check current mode:** `getenforce` (returns `Enforcing`, `Permissive`, or `Disabled`)
- **Get detailed status:** `sestatus`
- **Temporarily set to Permissive:** `sudo setenforce 0`  # CRITICAL: Always re-enable enforcing mode after troubleshooting: setenforce 1
- **Temporarily set to Enforcing:** `sudo setenforce 1`
- **Permanently set mode:** Edit `/etc/selinux/config` and set `SELINUX=enforcing` (requires reboot).

## Context Inspection
- **Files/Directories:** `ls -Z /path/to/file`
- **Processes:** `ps auxZ | grep <process_name>`
- **Sockets:** `ss -Z`
- **Current user:** `id -Z`

## Managing Contexts
- **Temporarily change a context:** `chcon -t <type> /path/to/file` (will be reset by `restorecon` or on relabel).
- **Permanently define a context:**
  `sudo semanage fcontext -a -t <type> "/path/to/item(/.*)?"`
- **Apply defined contexts:** `sudo restorecon -Rv /path`

## Troubleshooting AVC Denials
1.  **Symptom:** Application fails with "Permission Denied" but file permissions are correct.
2.  **Check Audit Log:** `sudo journalctl -p err --since "10 minutes ago" | grep "AVC avc:  denied"`
    - Or look in `sudo grep "AVC" /var/log/audit/audit.log`
3.  **Translate denial:** Pipe the denial log into `audit2why`.
    `sudo grep "AVC" /var/log/audit/audit.log | tail -1 | audit2why`
4.  **Fix with a boolean:** `audit2allow` often suggests a boolean.
    - List relevant booleans: `getsebool -a | grep <name>`
    - Set boolean permanently: `sudo setsebool -P <boolean_name> on`
5.  **Fix with a new policy module (if no boolean exists):**
   ```bash
   # Generate type enforcement (.te) and file context (.fc) files
   sudo grep "AVC" /var/log/audit/audit.log | audit2allow -M my_custom_policy

   # Inspect generated files
   cat my_custom_policy.te

   # Compile and install the policy package (.pp)
   sudo semodule -i my_custom_policy.pp
   ```
6.  **Fix a port binding issue:**
    `sudo semanage port -a -t <port_type> -p tcp <port_number>`
    - Example: `sudo semanage port -a -t http_port_t -p tcp 8080`

## Which Context Tool to Use
- **`chcon`**: For quick, temporary tests. **Don't use in production configs.**
- **`restorecon`**: To apply the *correct*, permanent policy to files. Run after `semanage fcontext`.
- **`semanage fcontext`**: To *define* the permanent policy for a file or directory path. This is the correct way.
```

### ## reference.md Content
```markdown
# SELinux Deep Reference

## Core Concepts
- **Mode**:
  - `Enforcing`: Policy is enforced. Denials are logged and access is blocked.
  - `Permissive`: Policy is not enforced. Denials are logged, but access is **not** blocked. Useful for debugging.
  - `Disabled`: SELinux kernel module is not loaded. Requires reboot to change. **Do not use.**
- **Context**: A label attached to every object (file, process, port). Format: `user:role:type:level`. The `type` is the most important part for type enforcement (TE).
- **Domain**: The `type` of a process context (e.g., `httpd_t`).
- **Type**: The `type` of an object context (e.g., `httpd_sys_content_t`).
- **Policy**: A set of rules defining which domains can access which types. (e.g., `allow httpd_t httpd_sys_content_t:file { read getattr open };`)
- **Booleans**: On/off switches in the policy that allow/disallow certain behaviors without writing custom policy.

## `semanage` Reference
- **File Contexts**:
  - `semanage fcontext -l`: List all file context definitions.
  - `semanage fcontext -a -t <type> "/path/spec"`: Add a new definition.
  - `semanage fcontext -d "/path/spec"`: Delete a definition.
  - `semanage fcontext -m -t <type> "/path/spec"`: Modify a definition.
- **Ports**:
  - `semanage port -l`: List all port type definitions.
  - `semanage port -a -t <type> -p <proto> <port_or_range>`: Add a port definition.
  - `semanage port -d -p <proto> <port_or_range>`: Delete a port definition.
- **Booleans**:
  - `semanage boolean -l`: List booleans and their current/default state.
  - `getsebool -a`: Another way to list all booleans.
  - `setsebool [-P] <name> <on|off>`: Set a boolean. `-P` makes it persistent across reboots.

## Policy Module Development
1.  **Get the denial:** `grep "comm=<process>" /var/log/audit/audit.log`
2.  **Generate base module:** `audit2allow -M <module_name>`
3.  **Structure**:
    - `<module_name>.te`: Type Enforcement rules. This is what `audit2allow` generates.
    - `<module_name>.fc`: Optional File Context definitions.
    - `<module_name>.if`: Optional Interface file for calling from other modules.
4.  **Compilation**:
    - Requires `selinux-policy-devel` package.
    - `make -f /usr/share/selinux/devel/Makefile <module_name>.pp`
5.  **Installation**:
    - `semodule -i <module_name>.pp`
6.  **Removal**:
    - `semodule -r <module_name>`

## Decision Matrix: When to set Permissive
| Condition                                       | Action                                   | Reason                                                                          |
| ----------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| New application install, expecting many denials | `semanage permissive -a <domain_t>`       | Confines permissiveness to one domain, letting the rest of the system be protected. |
| Critical but broken app, no time to debug       | `setenforce 0` (and open a ticket)         | A temporary stop-gap. Less secure but keeps service running. Re-enforce ASAP.     |
| Debugging a complex, multi-domain interaction   | `setenforce 0`                           | Makes it easier to see *all* denials without services crashing midway.              |
| Development or test environment setup           | `setenforce 0` initially, then build policy | Set to permissive, run tests, gather all AVCs, build one comprehensive module.  |

## Common Booleans for Container Stack
- `container_manage_cgroup`: Allows container managers to manage cgroups. **Required for K3s/containerd.**
- `virt_use_fusefs`: Allows virtualized guests (and containers) to use FUSE filesystems.
- `httpd_can_network_connect`: Allows httpd (and processes running as `httpd_t`, like Traefik) to make outbound network connections.

## SELinux and Hetzner Volumes
When a Hetzner volume is attached and formatted, it is typically mounted with a generic file context like `unlabeled_t` or `nfs_t`. K3s/containerd (running as `container_t`) cannot write to these contexts.
- **Symptom:** Pods using a PersistentVolume on a Hetzner volume fail to start. `kubectl describe pod` shows "permission denied" on volume mount.
- **Fix:** Define the correct context for the mount point and recursively restore it.
  ```bash
  # Example: Volume mounted at /mnt/data/k3s-vols
  sudo semanage fcontext -a -t container_file_t "/mnt/data/k3s-vols(/.*)?"
  sudo restorecon -Rv /mnt/data/k3s-vols
  ```
```

### ## examples.md Content
```markdown
# SELinux Examples for Helix Stax

## Scenario 1: Traefik Cannot Bind to Host Port 8080 for an IngressRoute
Let's say you've configured a Traefik middleware to expose a service on a host port 8080. The pod fails to start.

**1. Find the AVC Denial:**
```bash
sudo journalctl -t setroubleshootd

# Or search audit.log
sudo grep traefik /var/log/audit/audit.log | grep AVC
# type=AVC msg=audit(1666616616.616:161): avc:  denied  { name_bind } for  pid=12345 comm="traefik" src=8080 scontext=system_u:system_r:container_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```
This says the process `traefik` (running as `container_t`) was denied binding to port 8080 (which has the type `unreserved_port_t`).

**2. Translate with `audit2why`:**
```bash
sudo grep "denied.*traefik.*8080" /var/log/audit/audit.log | tail -1 | audit2why
# The kernel denied the traefik process, running with the container_t context,
# from binding to a TCP socket, port 8080, which has the unreserved_port_t context.
# To allow this, you need to tell SELinux that the port should be treated as a HTTP port.
# You can do this by running:
# # semanage port -a -t http_port_t -p tcp 8080
```

**3. Fix using `semanage port`:**
The error tells us exactly what to do. The correct context for a web server port is `http_port_t`.
```bash
sudo semanage port -a -t http_port_t -p tcp 8080
```
After this, restart the Traefik pod. It should now be able to bind successfully.

## Scenario 2: Fix Context on a New Hetzner Volume for K3s Storage
You've created and attached a 40GB Hetzner volume to `helix-stax-cp`, formatted it with `xfs`, and mounted it at `/mnt/data-pg`. You want to use it for the CloudNativePG database.

**1. Mount the volume (in `/etc/fstab`):**
```
/dev/disk/by-id/scsi-0HC_Volume_12345 /mnt/data-pg xfs defaults 0 0
```
`sudo mount /mnt/data-pg`

**2. Check the initial context:**
```bash
ls -ldZ /mnt/data-pg
# drwxr-xr-x. 2 root root system_u:object_r:default_t:s0 /mnt/data-pg
```
`default_t` is a problem. The K3s container runtime (`container_t`) will not be able to write here.

**3. Define the correct, persistent context:**
We need `container_file_t` for general container R/W-able storage.
```bash
sudo semanage fcontext -a -t container_file_t "/mnt/data-pg(/.*)?"
```
The `(/.*)?` is crucial. It applies the context to the directory itself and everything inside it.

**4. Apply the new context:**
```bash
sudo restorecon -Rv /mnt/data-pg
# Relabeled /mnt/data-pg from system_u:object_r:default_t:s0 to system_u:object_r:container_file_t:s0
```
Now, when K3s tries to create PersistentVolumes in subdirectories of `/mnt/data-pg` (e.g., using the `local-path` provisioner), it will have the correct permissions.

## Scenario 3: Create a Custom Policy for a Fictional Agent
A custom monitoring agent `helix-agent` needs to read config from `/etc/helix-agent` and write logs to `/var/log/helix-agent.log`. It runs as `helix_agent_t`.

**1. Create file contexts:**
```bash
# Executable
sudo semanage fcontext -a -t bin_t "/usr/sbin/helix-agent"
# Config dir
sudo semanage fcontext -a -t etc_t "/etc/helix-agent(/.*)?"
# Log file
sudo semanage fcontext -a -t var_log_t "/var/log/helix-agent.log"
# Apply
sudo restorecon -Rv /etc/helix-agent /usr/sbin/helix-agent /var/log/helix-agent.log
```

**2. Go permissive to gather denials:**
```bash
# Assuming the systemd unit file is set up to run the service
sudo semanage permissive -a helix_agent_t
sudo systemctl start helix-agent.service
# Run tests, let it try to do its job
```

**3. Generate and install the policy:**
```bash
sudo grep helix_agent_t /var/log/audit/audit.log | audit2allow -M helix-agent-policy
sudo semodule -i helix-agent-policy.pp
```

**4. Go back to enforcing:**
```bash
sudo semanage permissive -d helix_agent_t
```
---

# AlmaLinux 9.7 — firewalld

### ## SKILL.md Content
```markdown
# firewalld Quick Reference

## Basic Commands
- **List all rules for default zone:** `sudo firewall-cmd --list-all`
- **Reload firewall (apply permanent rules):** `sudo firewall-cmd --reload`
- **Add a service (temporary):** `sudo firewall-cmd --add-service=https`
- **Add a service (permanent):** `sudo firewall-cmd --permanent --add-service=https`
- **Add a port (permanent):** `sudo firewall-cmd --permanent --add-port=8080/tcp`
- **Remove a port (permanent):** `sudo firewall-cmd --permanent --remove-port=8080/tcp`
- **List all zones and their assigned interfaces:** `sudo firewall-cmd --get-active-zones`
- **Set interface for a zone:** `sudo firewall-cmd --zone=internal --change-interface=eth1` (use --permanent)

## K3s Essential Ports (Open on ALL NODES)
- **Flannel VXLAN:** `sudo firewall-cmd --permanent --zone=internal --add-port=8472/udp`
- **Kubelet (for metrics):** `sudo firewall-cmd --permanent --zone=internal --add-port=10250/tcp`
- **NodePort Range:** `sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp`

## K3s Essential Ports (Open on CONTROL PLANE nodes, e.g., `helix-stax-cp`)
- **K3s API Server:** `sudo firewall-cmd --permanent --zone=internal --add-port=6443/tcp`
- **Embedded etcd:** `sudo firewall-cmd --permanent --zone=internal --add-port=2379-2380/tcp`

*Note: Use `--zone=internal` if K3s nodes communicate over the private network. Adjust source IPs with rich rules for better security.*

## Rich Rules
- **Allow IP
  `10.0.0.3` to access port 6443:**
  ```bash
  sudo firewall-cmd --permanent --zone=internal --add-rich-rule='rule family="ipv4" source address="10.0.0.3/32" port port="6443" protocol="tcp" accept'
  ```

## Masquerading (for K3s Pod Outbound Traffic)
- **Enable masquerading for the public-facing zone:**
  ```bash
  sudo firewall-cmd --permanent --zone=public --add-masquerade
  ```

## Troubleshooting Flow
1.  **Symptom:** Connection refused/timed out.
2.  **`sudo firewall-cmd --list-all`**: Is the port/service listed in the correct zone (`public` for external, `internal` for private IPs)?
3.  **`sudo firewall-cmd --get-active-zones`**: Is the correct network interface (`eth0`, `ens10`) assigned to the zone you configured? Your public IP should be on an interface in the `public` zone, and your private IP on an interface in `internal`/`trusted`.
4.  **Hetzner Firewall**: Did you also open the port in the Hetzner Cloud Console firewall? Both must be open.
5.  **Service Running?**: `ss -tlnp | grep <port>`. Is anything actually listening on that port?
6.  **After `--reload`**: If connectivity is lost after a reload, it means your temporary rules were working, but your permanent rules are wrong or missing. Re-add the rules with `--permanent` and reload again.
```

### ## reference.md Content
```markdown
# firewalld Deep Reference

## Zone Model
Firewalld assigns interfaces to zones. Each zone has its own set of rules. The default zone is `public`.
- **`trusted`**: All connections are accepted. Ideal for the private Hetzner network interface (`ens10`).
- **`internal`**: For internal networks. Default behavior is similar to `public`, but implies a more trusted environment. A good choice for the private network if you want to be more granular than `trusted`.
- **`public`**: For public-facing interfaces. Assumes an untrusted network.
- **`dmz`**: For isolated servers in a "demilitarized zone"; limited access to your internal network.
- **`block`**: All incoming connections are rejected with an `icmp-host-prohibited`.
- **`drop`**: All incoming connections are dropped with no reply.

## `firewall-cmd` Reference
- `--get-zones`: List all available zones.
- `--get-default-zone`: Get the default zone for interfaces not explicitly assigned.
- `--set-default-zone=<zone>`: Set the default zone.
- `--get-active-zones`: List active zones and their assigned interfaces.
- `--zone=<zone>`: Apply a command to a specific zone. If omitted, uses the default zone.
- `--permanent`: Make a change persistent. Requires `--reload` to become active.
- `--reload`: Discards temporary config and applies permanent config.

### Rule Management
- `--list-all`: List all configurations for a zone.
- `--add-port=<port>/<proto>`: Open a port.
- `--add-service=<service>`: Open a service (pre-defined set of ports/protocols).
- `--add-rich-rule='<rule>'`: Add a complex rule.
- `--add-masquerade`: Enable IP masquerading.
- `--query-port`, `--query-service`, etc: Check if a rule exists.
- `--remove-*`: The counterpart to `--add-*`.

## Rich Rule Syntax
`rule [family="<family>"] [source address="<address>"] [destination address="<address>"] <element> [log [prefix="<prefix>"] [level="<level>"]] [audit] <action>`

- **`element`**: Can be `service name="<name>"`, `port port="<port>" protocol="<tcp|udp>"`, `forward-port ...`.
- **`action`**: `accept`, `reject [type="<type>"]`, `drop`.
- **Example**: Log and reject traffic from `192.168.1.0/24` to port 22.
  `--add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="22" protocol="tcp" log prefix="SSH_REJECT " reject'`

## Port Forwarding
```bash
# Forward traffic from public port 80 to internal IP 10.0.0.10 on port 8080
firewall-cmd --permanent --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=10.0.0.10
```
**Note:** Masquerading must be enabled on the zone for forwarding to work.

## Custom Services
Define custom services in `/etc/firewalld/services/`.
- **Example: `/etc/firewalld/services/my-app.xml`**
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <service>
    <short>My App</short>
    <description>Service definition for my custom application.</description>
    <port protocol="tcp" port="9000"/>
    <port protocol="udp" port="9001-9003"/>
  </service>
  ```
- Then use `firewall-cmd --add-service=my-app`.

## Direct Rules (nftables backend)
When to use: For complex scenarios not covered by firewalld's abstractions, like specific `mangle` operations or complex NAT configurations. **This is a last resort.**

```bash
# Example: Add a raw nftables rule to the firewalld INPUT chain
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -s 1.2.3.4 -j DROP
```
This bypasses the zone logic and is harder to manage. Prefer rich rules.

## Hetzner Firewall vs. firewalld
This is a defense-in-depth strategy.
| Layer            | Role                                                                | Best For                                                                     |
| ---------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **Hetzner FW**   | Cloud network edge firewall. First line of defense.                 | Blocking broad traffic. Rules for stable services (SSH, K3s API). Low overhead. |
| **firewalld**    | OS-level firewall on the node itself.                               | Granular rules (e.g., per-interface), rich rules, K3s pod traffic, logging.    |

Always configure both. Hetzner blocks traffic before it even hits your server's network card. `firewalld` provides protection if the Hetzner firewall is misconfigured and controls inter-process communication on the node.
```

### ## examples.md Content
```markdown
# firewalld Examples for Helix Stax

Our setup has a public interface (`eth0`) and a private one (`ens10`).
- `helix-stax-cp`: Public `178.156.233.12`, Private `10.0.0.2` (assumed)
- `helix-stax-vps`: Public `5.78.145.30`, Private `10.0.0.3` (assumed)
- Private Network CIDR: `10.0.0.0/16`

## Initial Setup on ALL K3s Nodes

**1. Assign Interfaces to Zones**
```bash
# eth0 is the public interface
sudo firewall-cmd --permanent --zone=public --change-interface=eth0

# ens10 is the Hetzner private network interface. 'trusted' allows all traffic from other nodes on the private net.
sudo firewall-cmd --permanent --zone=trusted --change-interface=ens10

sudo firewall-cmd --reload
sudo firewall-cmd --get-active-zones
# Expected Output:
# public
#   interfaces: eth0
# trusted
#   interfaces: ens10
```

**2. Enable Masquerading for Pods**
This allows pods (e.g., `10.42.0.5`) to reach the internet. Traffic from the pods goes out the node's public IP.
```bash
# Add to the zone with the public interface
sudo firewall-cmd --permanent --zone=public --add-masquerade
```

## Firewall Rules for `helix-stax-cp` (Control Plane)

```bash
# --- Permanent Rules for helix-stax-cp (178.156.233.12 / 10.0.0.2) ---

# Allow SSH only from specific trusted IPs to the public interface
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="YOUR_OFFICE_IP/32" port port="22" protocol="tcp" accept'
sudo firewall-cmd --permanent --zone=public --remove-service=ssh # Remove the default broad rule

# Allow K3s API server access ONLY from other nodes on the private network
sudo firewall-cmd --permanent --zone=trusted --add-port=6443/tcp

# Allow etcd access ONLY from other control-plane nodes on the private network
# For a single control plane, this isn't strictly needed for other nodes to connect.
# But it's required for multi-master setups.
sudo firewall-cmd --permanent --zone=trusted --add-port=2379-2380/tcp

# All nodes need these for K3s to function
sudo firewall-cmd --permanent --zone=trusted --add-port=8472/udp   # Flannel VXLAN
sudo firewall-cmd --permanent --zone=trusted --add-port=10250/tcp  # Kubelet API
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp # NodePort TCP
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/udp # NodePort UDP

# Allow Traefik Ingress ports on the public interface
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https

# Apply all the rules
sudo firewall-cmd --reload
```

## Firewall Rules for `helix-stax-vps` (Worker Node)

```bash
# --- Permanent Rules for helix-stax-vps (5.78.145.30 / 10.0.0.3) ---

# Same SSH hardening as control plane
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="YOUR_OFFICE_IP/32" port port="22" protocol="tcp" accept'
sudo firewall-cmd --permanent --zone=public --remove-service=ssh

# All nodes need these for K3s to function
sudo firewall-cmd --permanent --zone=trusted --add-port=8472/udp   # Flannel VXLAN
sudo firewall-cmd --permanent --zone=trusted --add-port=10250/tcp  # Kubelet API
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp # NodePort TCP
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/udp # NodePort UDP

# Allow Traefik Ingress ports on the public interface (assuming Traefik may run here)
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=httpss

# Apply all the rules
sudo firewall-cmd --reload
```
**Verification Command:**
After configuring, run `sudo firewall-cmd --zone=<zone> --list-all` on both nodes for `public` and `trusted` zones to verify the rules are active.
Example on `helix-stax-cp`:
```bash
sudo firewall-cmd --zone=trusted --list-all
# trusted (active)
#   interfaces: ens10
#   services:
#   ports: 6443/tcp 2379-2380/tcp 8472/udp 10250/tcp
#   ...
```

This ensures K3s internal traffic flows freely on the private `trusted` network, while the `public` internet-facing side is tightly controlled.

This is a fraction of the full response. Due to the massive length, I will stop here. I can continue generating the remaining sections (`dnf`, `System Tuning`, `Networking`, `Hetzner Cloud`, etc.) if you'd like. Please let me know how you want to proceed.
