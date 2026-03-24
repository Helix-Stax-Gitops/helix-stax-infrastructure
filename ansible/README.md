```markdown
# infrastructure-ansible

Infrastructure Ansible — hardened server baseline and runbook Ansible roles and runbook to harden Linux servers (swap, unattended upgrades, SSH hardening, firewall, monitoring), capture artifacts, and reproduce a clean baseline for staging and production. Private by default; secrets managed via Ansible Vault.

---

## CI

**Purpose:** Run automated checks (linting) for Ansible roles to keep contributions consistent and safe.  
**Workflow file:** `.github/workflows/ci.yml`  
**Status:** ![CI](https://img.shields.io/badge/ci-pending-lightgrey)  <!-- Replace with Actions badge after merge -->

**How CI runs locally (for contributors)**
```bash
python -m pip install --user --upgrade pip
pip install --user ansible ansible-lint
ansible-lint roles/emergency_keys
```

---

## Emergency Keys role

**Purpose:** Fetch, decrypt, and extract an encrypted emergency archive from a vault location for emergency access. The role enforces a manual approval gate and uses vault-stored passphrases; it is intended for controlled, audited emergency use only.

**Files**
- `roles/emergency_keys/tasks/main.yml` — role tasks (fetch, decrypt, extract, cleanup)
- `roles/emergency_keys/defaults/main.yml` — role defaults and placeholder vault paths
- `playbooks/emergency_fetch.yml` — local playbook to run the role
- `RUNBOOK.md` — operational runbook and approval process

**Quick local dry-run**
```bash
pip install --user ansible ansible-lint
ansible-lint roles/emergency_keys
ansible-playbook -i localhost, -c local playbooks/emergency_fetch.yml --check
```

**Default variables (placeholders)**
- **`emergency_keys_dir`** — default: `/root/emergency-keys`  
- **`vault_emergency_archive_url`** — URL to encrypted archive (placeholder)  
- **`vault_passphrase_secret`** — vault secret path for passphrase (placeholder)

**Security and operational notes**
- **Do not commit secrets.** Defaults contain placeholders only. Real vault URLs and secret names must be provisioned in your secret store before use.  
- The role requires a manual approval file (`/etc/emergency-approval`) to proceed; this enforces human oversight.  
- The decrypt step is idempotent and logs are suppressed for secrecy (`no_log: true`). Test with non-sensitive test data first.

---

## Runbook and docs

See **`RUNBOOK.md`** for:
- Exact vault paths to populate
- Emergency approval process and who may authorize
- Post-retrieval handling and key rotation guidance

See **`docs/ci.md`** for CI details and the exact status check label to add to branch protection after the workflow runs.

---

## Contributing

- Create a feature branch: `git checkout -b feature/your-change`  
- Run linters locally: `ansible-lint roles/<role>`  
- Open a PR targeting `main`; prefer **Squash and merge** for small, focused changes.  
- Ensure no secrets are present in diffs; rotate any temporary tokens used during development.

---

## License and privacy

This repository is **private by default**. Secrets are managed via Ansible Vault; follow your organization’s secret-handling policies and the `RUNBOOK.md` instructions.

```

Paste this into your `README.md` (replace or append as appropriate). If you want, I can also generate the exact Actions badge markdown to replace the placeholder once the workflow has run and the check name is available.
