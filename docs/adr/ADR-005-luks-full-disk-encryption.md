# ADR-005: LUKS Full Disk Encryption with dracut-sshd Remote Unlock

## TLDR

Encrypt all Hetzner VPS root volumes with LUKS, using dracut-sshd for remote key injection during boot. No cloud KMS dependency.

**Status**: Accepted

**Decision date**: 2026-03-23

---

## Context

Helix Stax infrastructure runs on Hetzner Cloud VPS instances. Hetzner provides physical datacenter security (ISO 27001 certified), but does not offer managed disk encryption or a cloud KMS. If a physical disk is decommissioned, cloned, or accessed by a rogue datacenter operator, unencrypted data is exposed. SOC 2 CC6.7 and HIPAA 164.312(a)(2)(iv) require encryption of data at rest, including the underlying storage layer.

Remote servers present a challenge for full disk encryption: someone must enter the LUKS passphrase at boot time. For headless VPS nodes, this means either accepting unencrypted disks, using a cloud KMS for auto-unseal (unavailable on Hetzner), or providing a remote unlock mechanism. dracut-sshd embeds an SSH server into the initramfs, allowing the operator to SSH into the pre-boot environment and supply the LUKS passphrase remotely.

---

## Options Considered

| Option | Description | Pros | Cons | Compliance Impact |
|--------|-------------|------|------|-------------------|
| **Option A**: LUKS + dracut-sshd | FDE with SSH-based remote unlock | No cloud dependency, strong at-rest encryption, operator-controlled keys | Manual unlock required on every reboot | Satisfies SOC 2 CC6.7, HIPAA 164.312(a)(2)(iv) |
| **Option B**: No disk encryption | Rely on Hetzner physical security | Zero operational overhead | Data exposed if disk decommissioned or accessed physically | Fails at-rest encryption requirements |
| **Option C**: Cloud KMS auto-unseal | Use cloud provider KMS for automatic LUKS unlock | Fully automatic boot | Hetzner has no KMS; would require external dependency (AWS KMS) | Satisfies requirements but adds external dependency |
| **Option D**: Clevis + Tang | Network-bound disk encryption | Automatic unlock when Tang server reachable | Requires separate Tang server infrastructure | Satisfies requirements but adds infrastructure |

---

## Decision

We will encrypt all VPS root volumes with LUKS and use dracut-sshd for remote key injection during boot.

**Implementation details:**
- LUKS encryption applied to root partition on both heart and helix-worker-1
- dracut-sshd embeds a minimal SSH daemon into the initramfs
- Operator SSH keys stored in `/etc/dracut-sshd/authorized_keys`
- GRUB configured with `rd.neednet=1 ip=dhcp` for network availability in initramfs
- Boot process pauses at LUKS prompt; operator SSHs to initramfs and enters passphrase
- Hetzner web console available as fallback for unlock

**Setup procedure:**
```bash
dnf install epel-release -y
dnf install dracut-network dracut-sshd -y
mkdir -p /etc/dracut-sshd
cat ~/.ssh/id_ed25519_helix_admin.pub >> /etc/dracut-sshd/authorized_keys
chmod 600 /etc/dracut-sshd/authorized_keys
# Add to GRUB_CMDLINE_LINUX: rd.neednet=1 ip=dhcp
grub2-mkconfig -o /boot/grub2/grub.cfg
dracut -f -v
```

---

## Rationale

LUKS is the standard Linux FDE solution with broad tooling support and auditor recognition. dracut-sshd provides remote unlock without introducing external dependencies (no cloud KMS, no additional servers). The manual unlock step on reboot is an acceptable trade-off for a 2-node cluster with infrequent reboots (primarily during maintenance windows with the rolling patch strategy: drain, patch, reboot, uncordon). Hetzner's web console provides a secondary unlock path if SSH is unavailable.

---

## Consequences

### Positive

- Full disk encryption at rest with no cloud provider dependency
- Operator retains sole control of encryption keys
- Auditor-friendly -- LUKS is universally recognized for at-rest encryption
- dracut-sshd uses existing SSH key infrastructure (no new credentials)
- Hetzner Rescue System available as emergency access if unlock fails

### Negative

- Every reboot requires manual SSH-based unlock (automated via OpenBao transit unseal for the application layer, but LUKS remains manual)
- Rolling patch strategy extends maintenance windows by unlock time per node
- If both operator SSH key and Hetzner console access are lost, data is irrecoverable
- initramfs SSH daemon is a minimal environment -- limited debugging capability during unlock

### Follow-on Work Required

| Action | Owner | Target Date | ClickUp Task |
|--------|-------|-------------|-------------|
| Apply LUKS encryption to heart root volume | Wakeem Williams | 2026-04-20 | TBD |
| Apply LUKS encryption to helix-worker-1 root volume | Wakeem Williams | 2026-04-20 | TBD |
| Configure dracut-sshd on both nodes | Wakeem Williams | 2026-04-20 | TBD |
| Document LUKS unlock in maintenance window runbook | Wakeem Williams | 2026-04-27 | TBD |
| Test Hetzner Rescue System fallback unlock | Wakeem Williams | 2026-04-27 | TBD |

---

## Affected Components

| Component | Impact |
|-----------|--------|
| AlmaLinux root volumes | LUKS encryption applied |
| Boot process | dracut-sshd added to initramfs |
| GRUB configuration | Network boot parameters added |
| Maintenance windows | Unlock step added to rolling patch procedure |
| PostgreSQL (CloudNativePG) | Inherits LUKS encryption via underlying PersistentVolumes |
| MinIO | Inherits LUKS encryption; additionally uses SSE-KMS via OpenBao |

---

## Compliance Mapping

| Framework | Control ID | Requirement | How This ADR Satisfies It |
|-----------|-----------|-------------|---------------------------|
| SOC 2 | CC6.7 | Restrict data at rest | LUKS AES-256 encryption on all volumes |
| ISO 27001 | A.8.24 | Use of cryptography | Full disk encryption with operator-controlled keys |
| NIST CSF 2.0 | PR.DS-1 | Data-at-rest protected | LUKS encryption protects against physical disk access |
| HIPAA | 164.312(a)(2)(iv) | Encryption and decryption | LUKS FDE satisfies addressable encryption requirement |
| CIS Controls v8.1 | 3.11 | Encrypt sensitive data at rest | Full disk encryption covers all data on volume |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Cass Whitfield (System Architect) |
| **Date** | 2026-03-23 |
| **Classification** | Internal |
| **Version** | 1.0 |
