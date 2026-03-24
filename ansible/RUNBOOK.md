# Operations Runbook: Emergency Recovery

## Secure Vault References

Sensitive credentials and passphrases are stored in the enterprise vault. Access these objects using the following pointers:

| Secret Name | Vault Object ID | Description |
| :--- | :--- | :--- |
| `EMERGENCY_ARCHIVE_PASSPHRASE` | `secret:emergency-keys-pass` | Passphrase for the `.zip.enc` credential archive. |
| `ROOT_EMERGENCY_KEY_PASSPHRASE` | `secret:root-emergency-pass` | Passphrase for the GPG-encrypted root emergency key. |
| `HEART_RESCUE_PASSWORD` | `secret:heart-rescue-pwd` | Temporary rescue mode password for the `heart` server. |

## Emergency Keys Inventory

This inventory documents all high-sensitivity credentials and keys required for infrastructure recovery.

### 1. SSH Keys (`~/.ssh/`)
| Key Name | Purpose | Target Systems |
| :--- | :--- | :--- |
| `helixstax_key` | Primary Administrative Key | `genome`, `heart`, `muscle` |
| `id_ed25519` | Standard Personal Identity | Generic developer access |
| `keemgithub` | Dedicated Source Control Key | GitHub (`git@github.com`) |
| `root-emergency` | Emergency Rescue Break-glass | `heart` (Rescue Mode) |
| `coolify_key` | Application Deployment | Coolify/Docker nodes |
| `emergency_key` | Limited Scope Emergency Access | Maintenance fallback (Expiry: 90 days) |

## Emergency Keys Location

| Asset | Storage Location | Notes |
| :--- | :--- | :--- |
| `emergency-keys-*.zip.enc` | `vault:blob/emergency-archive` | Uploaded to enterprise object store. |
| **Hetzner Backup Bucket** | `s3://hearts/` | Primary offsite backup (Helsinki: `hel1`). |

### Backup Verification Command
To verify your offsite storage connectivity locally:
```powershell
& "C:\Users\MSI LAPTOP\AppData\Roaming\Python\Python314\Scripts\aws.cmd" --endpoint-url https://hel1.your-objectstorage.com s3 ls s3://hearts
```

## Backup Security & Operations
- **Encryption-First**: All backups MUST be encrypted locally via OpenSSL (AES-256-CBC) before upload.
- **Vault Integrity**: Passphrases and S3 Service Account keys must reside in **Ansible Vault**. NEVER commit plaintext credentials.
- **Least Privilege**: Use dedicated S3 credentials scoped strictly to the `hearts` bucket.
- **Data Durability**:
  - **Object Versioning**: Enabled on the bucket to prevent accidental data loss.
  - **Object Lock**: Use for immutable storage if compliance requires.
- **Validation & Restoration**:
  - **Checksums**: Verify archive integrity before and after upload.
  - **Sandbox Restores**: Perform quarterly restore tests to a non-production environment.
- **Monitoring**: Set up alerts for failed backup jobs or unexpected spikes in archive size.

## Automated Backup Pipeline (Step 6)

### Scheduling & Orchestration
| Runner | Type | Schedule | Trigger |
| :--- | :--- | :--- | :--- |
| **GitHub Actions** | Remote | Daily 02:00 UTC | `schedule` / `dispatch` |

### Retention & Lifecycle Policy
- **Hot Storage**: 30 days (Immediate availability in `s3://hearts`).
- **Cold Storage**: 90 days (Moved to cold/archive class via S3 Lifecycle Rules).
- **Cleanup**: Automatic deletion after 120 days unless **Object Lock** is active.

### Restore Drilling Protocol (Quarterly)
1. **Selection**: Pick a random archive from the last 30 days.
2. **Integrity**: Verify the `.sha256` checksum matching.
3. **Decryption**: Ensure the local GPG/Vault key can decrypt the AES-256 payload.
4. **Validation**: Restore a database dump to a sandbox container and verify row counts.
5. **Logging**: Record the drill status and duration in `docs/recovery_drills.md`.

## AI & Operations Logging
| `emergency_key` (Private) | `vault:secret/emergency-key-private` | Primary private key for fallback access. |
| `emergency_key` (Public) | `docs/emergency_key.pub` | Public key for authorized_keys placement. |

## Expiry & Rotation Policy

1. **Emergency Key**: Valid for 90 days. Rotation required on 2026-05-16.
2. **GPG Identity**: Annual review of subkeys required.
3. **Archive**: Re-generate archive after every major infrastructure change or key rotation.

### 2. GPG Keys (`~/.gnupg/`)
- **Primary Identity**: `keemwilliams <careers@wakeemwilliams.com>`
- **KeyID**: `0158C8CDC201ABD6` (ED25519)
- **Usage**: Git commit signing and secure file encryption.

### 3. Remote Backups (on `heart`)
- `/root/ssh-preserve-*`: Snapshot of original SSH configuration before enterprise hardening.

## Recovery Procedures

### Restoring Local Credentials
In the event of a local machine failure, restore the `emergency-keys` archive:
1. Retrieve `EMERGENCY_ARCHIVE_PASSPHRASE` from the vault.
2. Decrypt the archive:
   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 -in emergency-keys-2026-02-15.zip.enc -out emergency-keys.zip
   ```
3. Extract contents to `~/.ssh/` and `~/.gnupg/`.
4. Fix permissions: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*`.
5. Import GPG keys: `gpg --import path/to/exported-keys.asc`.
