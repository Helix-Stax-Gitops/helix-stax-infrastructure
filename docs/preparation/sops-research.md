# SOPS Research: GitOps Secret Encryption for Helix Stax

**Date**: 2026-03-20
**Researcher**: Remy Alcazar (Research Analyst)
**Scope**: Evaluate SOPS for encrypting secrets in Git repos within our ArgoCD/K3s GitOps pipeline

---

## Executive Summary

SOPS (Secrets OPerationS) is a file-level encryption tool that solves a specific, well-defined problem: **secrets cannot be stored in plaintext in Git**. It does not replace OpenBao/HashiCorp Vault. It complements it. These two tools operate at different layers of the stack.

**Recommendation**: Adopt SOPS with `age` encryption as the GitOps secret encryption layer. Use OpenBao as the runtime key management backend. ESO (External Secrets Operator) remains the bridge between OpenBao and Kubernetes native secrets. SOPS handles the Git layer only.

---

## 1. What Is SOPS and How Does It Work

SOPS is an encrypted file editor. It supports YAML, JSON, ENV, INI, and binary formats. The key design principle is **partial encryption**: it encrypts only values, leaving keys (field names) in plaintext. This means encrypted files remain readable in diffs — you can see that a `database_password` key changed, but not what the new value is.

**Technical operation:**

1. On first encrypt, SOPS generates a random 256-bit data key.
2. Each leaf value is encrypted independently using AES-256-GCM with a unique 256-bit initialization vector.
3. The field name is used as Additional Authenticated Data (AAD), binding the value to its key name — this prevents value substitution attacks.
4. A Message Authentication Code (MAC) is computed over all values and stored encrypted in `sops.mac` — this detects file tampering.
5. The data key itself is encrypted by one or more master keys (age, PGP, AWS KMS, etc.) and stored in the file metadata under `sops.kms`, `sops.pgp`, etc.

The encrypted file stays in Git. Decryption requires access to the master key. Without the master key, the file is unreadable.

**Example: what an encrypted YAML looks like**

```yaml
database:
    password: ENC[AES256_GCM,data:6bC9mw==,iv:...,tag:...,type:str]
    username: ENC[AES256_GCM,data:dXNlcg==,iv:...,tag:...,type:str]
api_key: ENC[AES256_GCM,data:abc123==,iv:...,tag:...,type:str]
sops:
    age:
        - recipient: age1...
          enc: |
              -----BEGIN AGE ENCRYPTED FILE-----
              ...
    lastmodified: '2026-03-20T12:00:00Z'
    mac: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
    version: 3.9.4
```

---

## 2. License

**Mozilla Public License 2.0 (MPL-2.0)**. This is a weak copyleft license. Key points:

- Free to use commercially with no restrictions.
- Source files modified directly must be made available if distributed.
- Larger proprietary works that merely use SOPS do not need to be open-sourced.
- No usage fees, no licensing costs.
- SOPS is a CNCF Sandbox project (donated by Mozilla in 2023). CNCF governance provides long-term maintenance guarantees.

**Verdict**: Freely usable. No legal concerns for Helix Stax.

---

## 3. SOPS vs OpenBao: Different Problems, Different Layers

These tools are not competing alternatives. They solve different problems at different layers.

| Dimension | SOPS | OpenBao (Vault Fork) |
|-----------|------|---------------------|
| **What it does** | Encrypts files for storage in Git | Runtime secret storage and dynamic secret generation |
| **Where it operates** | At rest, in Git repositories | At runtime, in-cluster |
| **Interface** | CLI tool, file-based | HTTP API, Kubernetes auth |
| **Secret delivery** | Decrypts during deploy time | Pods read secrets at runtime via ESO or Vault Agent |
| **Dynamic secrets** | No | Yes (database creds, PKI, SSH) |
| **Audit logging** | No built-in audit trail | Full audit log per request |
| **RBAC** | Not applicable (key-based access) | Policies per path, per role, per entity |
| **Secret rotation** | Manual re-encryption | Built-in lease renewal and rotation |
| **GitOps fit** | Native — secrets live in Git | Requires out-of-band secret population |
| **Operational overhead** | Low (just a CLI binary) | High (stateful service, HA considerations, unsealing) |

**The gap SOPS fills**: In a pure OpenBao + ESO setup, you still need to answer "how do secrets get INTO OpenBao in the first place?" For most teams, that means someone manually `vault write`s them, or there's a separate bootstrap process. SOPS provides a Git-native path to store and version-control those initial secret values without exposing them in plaintext.

**SOPS does NOT replace OpenBao** if you need:
- Dynamic database credentials
- PKI and certificate lifecycle management
- Fine-grained per-pod access policies with audit trails
- Secret rotation with automatic lease renewal

---

## 4. Does SOPS Replace OpenBao or Complement It?

**It complements. Do not replace OpenBao with SOPS.**

The recommended architecture for Helix Stax:

```
Git repo (SOPS-encrypted secrets)
       |
       | ArgoCD sync / helm-secrets decrypt
       v
Kubernetes Secrets (native K8s)
       |
       | OR via ESO reading OpenBao
       v
OpenBao (runtime secrets, dynamic creds, PKI)
       |
       | ESO ExternalSecret CRD
       v
Kubernetes Secrets (consumed by pods)
```

SOPS operates at the Git-to-cluster boundary. OpenBao + ESO operates at the cluster runtime layer. They are not redundant — they address different threat models.

**When to use SOPS vs OpenBao:**

| Use Case | Use SOPS | Use OpenBao |
|----------|----------|-------------|
| Store initial DB credentials in Git | Yes | No (plaintext risk) |
| Bootstrap OpenBao itself (root token, unseal keys) | Yes | N/A |
| Helm values files with secrets | Yes | No |
| Ansible vault vars for provisioning | Yes | Consider |
| Dynamic DB credentials for pods | No | Yes |
| TLS certificate lifecycle | No | Yes |
| Per-service API keys that rotate | No | Yes |
| Audit trail of who read a secret | No | Yes |

---

## 5. Stack Integration

### 5.1 K3s / Kubernetes

SOPS does not create Kubernetes Secrets directly. There are three approaches to bridge SOPS to Kubernetes:

**Option A: sops-secrets-operator (Helm chart)**

A Kubernetes operator that watches `SopsSecret` CRDs in the cluster and creates native `Secret` objects from them. The CRD is a SOPS-encrypted file committed to Git. ArgoCD deploys the CRD; the operator decrypts and creates the K8s Secret.

- Helm chart: `isindir/sops-secrets-operator` on ArtifactHub
- Latest tested version: 0.13.1
- Install: `helm repo add sops https://isindir.github.io/sops-secrets-operator/`
- Works on K3s. Flannel CNI has no bearing on this.
- The operator needs access to the decryption key (age private key or KMS credentials) mounted as a K8s secret.

**Option B: helm-secrets plugin (decrypt at deploy time)**

The `jkroepke/helm-secrets` Helm plugin decrypts SOPS-encrypted values files on the fly during `helm upgrade`. The decrypted values are never written to disk.

- Works with ArgoCD via init container on `argocd-repo-server`
- Values files committed to Git as `values.secrets.yaml` (encrypted with SOPS)
- ArgoCD calls `helm secrets upgrade` instead of plain `helm upgrade`
- Does require patching the ArgoCD repo-server deployment

**Option C: GitOps decrypt in CI/CD pipeline**

GitHub Actions workflow decrypts secrets and writes them to K8s directly or passes them to Helm as `--set` values. Not recommended — secrets appear in CI logs or state.

**Recommendation for Helix Stax**: Option A (sops-secrets-operator) for secrets that need to exist as K8s Secrets. Option B (helm-secrets) for Helm values files with secrets. Use both where appropriate.

### 5.2 ArgoCD (GitOps)

ArgoCD's official position is that it prefers secrets managed on the destination cluster (not via manifest generation). However, the ecosystem provides two production-ready SOPS integration paths:

**Path 1: helm-secrets plugin for ArgoCD**

Modify `argocd-repo-server` to include helm-secrets and sops binaries. ArgoCD then transparently decrypts `secrets://` prefixed values files during sync.

Integration steps:
1. Add an init container to `argocd-repo-server` that installs `helm-secrets` and `sops`
2. Mount the age private key (or KMS credentials) into the repo-server pod
3. Set env vars: `HELM_PLUGINS`, `HELM_SECRETS_BACKEND=sops`, `HELM_SECRETS_WRAPPER_ENABLED=true`
4. Reference encrypted values files with `secrets://path/to/secrets.yaml` in ArgoCD Application spec

This is the most commonly used ArgoCD+SOPS pattern in the ecosystem as of 2025.

**Path 2: sops-secrets-operator**

No ArgoCD modification needed. ArgoCD deploys `SopsSecret` CRDs (which are SOPS-encrypted files in Git). The operator decrypts them server-side. Clean separation.

**Risk for Helix Stax**: ArgoCD's repo-server caches generated manifests in Redis. If using helm-secrets via manifest generation, decrypted secrets could temporarily appear in the Redis cache. The official mitigation is network policies restricting Redis access — which we already have as part of our compliance posture. Still, Option B (sops-secrets-operator) avoids this risk entirely.

### 5.3 OpenTofu (IaC)

The `carlpett/sops` provider is available on both the Terraform Registry and OpenTofu Registry. Version 1.2.0 is on the OpenTofu registry.

```hcl
terraform {
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.2"
    }
  }
}

data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

resource "something" "example" {
  password = data.sops_file.secrets.data["database_password"]
}
```

**Critical gotcha**: With standard `data` sources, decrypted values may be written to Terraform state. The `nobbs/sops` provider uses functions instead of data sources, avoiding state writes. For sensitive values, use `nobbs/sops` or use `ephemeral` resources (Terraform 1.11+ / OpenTofu equivalent).

This is directly relevant to our infra repo where we manage cluster resources with OpenTofu and need to reference secrets (Hetzner tokens, registry credentials, etc.).

### 5.4 Ansible

Official `community.sops` collection on Ansible Galaxy. Two integration modes:

**Mode 1: vars plugin** — SOPS-encrypted group_vars and host_vars files are transparently decrypted. Naming convention: `group_vars/all/secrets.sops.yaml`. Enable in `ansible.cfg`:

```ini
[defaults]
vars_plugins_enabled = community.sops.sops
```

**Mode 2: load_vars module** — Explicitly load a SOPS-encrypted vars file within a playbook task:

```yaml
- community.sops.load_vars:
    file: secrets.sops.yaml
```

**Comparison with Ansible Vault**: SOPS is superior for multi-operator setups because:
- Ansible Vault encrypts entire files (no meaningful diffs)
- SOPS encrypts values only (you can see which vars changed in Git diffs)
- SOPS supports multiple key backends (age, KMS) vs Ansible Vault's password-based approach
- Multiple operators can have their own keys with SOPS (via key groups)

**For Helix Stax**: Our Ansible playbooks for provisioning AlmaLinux nodes and configuring K3s should use SOPS-encrypted vars files instead of Ansible Vault or plaintext vars.

### 5.5 Helm (values files)

The `jkroepke/helm-secrets` plugin is the standard approach. Workflow:

```bash
# Encrypt a values file
sops --encrypt values.yaml > values.secrets.yaml

# Commit the encrypted file to Git
git add values.secrets.yaml
git commit -m "add encrypted helm values"

# Deploy (helm-secrets plugin decrypts on the fly)
helm secrets upgrade myapp ./myapp -f values.yaml -f secrets://values.secrets.yaml
```

The plugin supports the `secrets://` protocol handler as the recommended approach. It also supports `secrets+age-import://` for inline age key references.

---

## 6. SOPS and External Secrets Operator (ESO)

**ESO does NOT have a SOPS provider.** ESO's 40+ providers include OpenBao, HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, Kubernetes, and many others — but SOPS is not one of them.

This is the correct design separation:

- **SOPS** operates at the Git layer (before deployment)
- **ESO** operates at the runtime layer (in-cluster, reading from live secret stores)

They are not alternative paths to the same destination. The correct combined architecture:

```
SOPS (Git layer) → K8s Secrets (via sops-operator or helm-secrets)
OpenBao + ESO (runtime layer) → K8s Secrets (via ExternalSecret CRDs)
```

Some secrets may only need the SOPS path (bootstrap credentials, one-time configs). Others should be in OpenBao for dynamic generation and rotation.

---

## 7. Key Management Backends

| Backend | Self-Hosted | Cloud Required | Solo Operator Fit | Notes |
|---------|------------|----------------|------------------|-------|
| **age** | Yes | No | Excellent | Recommended. Modern crypto. Simple key files. |
| **PGP/GPG** | Yes | No | Good (backup) | Mature. Recommended as backup/DR key only. |
| **HashiCorp Vault / OpenBao Transit** | Yes | No | Good | Uses Vault's transit engine as KMS. Requires Vault running. |
| **AWS KMS** | No | AWS | N/A for self-hosted | Requires AWS account and key. |
| **GCP KMS** | No | GCP | N/A for self-hosted | Requires GCP project. |
| **Azure Key Vault** | No | Azure | N/A for self-hosted | Requires Azure subscription. |

For Helix Stax (self-hosted Hetzner, no cloud KMS), the relevant backends are age, PGP, and OpenBao Transit.

---

## 8. Best Key Management for Self-Hosted (No Cloud KMS)

The best approach for a self-hosted solo/small-team operator with no cloud KMS:

**Primary: age + OpenBao Transit (dual encryption)**

Configure SOPS to use BOTH age and OpenBao Transit as key groups. This means:
- Either key can decrypt (not Shamir — just two separate decryption paths)
- Normal operations use age keys (simpler, no network call)
- OpenBao Transit provides a backup decryption path and audit trail

`.sops.yaml` configuration:
```yaml
creation_rules:
  - path_regex: .*\.sops\.yaml$
    key_groups:
      - age:
          - age1yourpublickeyhere...
      - hc_vault_transit_uri: http://openbao.openbao.svc:8200/v1/sops/keys/main
```

**Fallback: age + offline PGP key**

For disaster recovery (OpenBao down, age key compromised):
- age key for normal operations
- PGP key stored offline (hardware key or encrypted USB) as emergency fallback

```yaml
creation_rules:
  - path_regex: .*\.sops\.yaml$
    age: age1yourpublickeyhere...
    pgp: YOUR_PGP_FINGERPRINT
```

**Key storage for age:**
- Private key stored at `~/.config/sops/age/keys.txt` on operator workstation
- Public key committed to `.sops.yaml` in the repo (safe to commit — it is public)
- Age private key backed up to offline storage (Bitwarden/1Password or encrypted USB)
- For CI/CD (GitHub Actions): age private key stored as GitHub Actions secret, injected as `SOPS_AGE_KEY` env var at runtime

**Kubernetes key access:**
- Age private key stored as a K8s Secret in the cluster (in a restricted namespace)
- sops-secrets-operator or argocd-repo-server mounts this secret to access the key at decrypt time

---

## 9. SOPS + age vs SOPS + PGP: Which Is Better

**Recommendation: Use age as primary, PGP as offline backup only.**

| Criteria | age | PGP/GPG |
|----------|-----|---------|
| **Cryptographic strength** | ChaCha20-Poly1305 + X25519 (modern) | RSA/AES (legacy, still secure but older) |
| **Key generation** | `age-keygen` — single command, simple output | `gpg --gen-key` — complex, many options |
| **Key format** | Small, readable public key string | Long fingerprint, keyring management |
| **Key distribution** | Paste the public key string | Export/import via keyservers or file |
| **SSH key support** | Yes — age can use existing ed25519 SSH keys | No |
| **Tooling complexity** | Minimal — one binary | Complex — gpg daemon, keyring, trust model |
| **CI/CD integration** | Simple env var (`SOPS_AGE_KEY`) | Must import GPG keyring and set trust level |
| **SOPS default order** | First in decryption order | Second |
| **Community direction** | Actively recommended by SOPS team | "Use as backup" |

**PGP advantages that still matter:**
- Widely understood in enterprise environments
- Useful as offline disaster recovery key (print to paper, store in safe)
- Subkey support allows separating signing and encryption keys

**For solo operator / small team (Helix Stax)**: age is the clear choice for operational keys. Add a PGP key only as a disaster recovery backup — store it offline, never use it in CI/CD.

---

## 10. Compliance Framework Considerations

### SOC 2

SOC 2 does not mandate specific encryption tools. It requires:
- Encryption at rest for sensitive data (CC6.1)
- Logical access controls (CC6.3)
- Encryption key management (CC6.7)

SOPS satisfies **encryption at rest** for secrets stored in Git — AES-256-GCM is a broadly accepted algorithm for this purpose. However, SOC 2 auditors will ask about **key management practices**: Who has access to the age private key? How is it rotated? Who is notified when a key is compromised? These are operational/process questions, not technical ones.

**SOPS alone is not sufficient for CC6.7 (key management)**. You need documented processes for:
- Key rotation schedule
- Key revocation procedure
- Key access review

OpenBao's audit logging helps answer auditor questions about secret access.

### FIPS 140-3

**SOPS uses AES-256-GCM**, which is an approved cryptographic algorithm under FIPS 140-2 Annex A and FIPS 140-3. The algorithm itself is FIPS-approved.

However: **SOPS is not a FIPS-validated cryptographic module**. There is no CMVP certificate for SOPS. If a client contract explicitly requires FIPS 140-3 validated modules for data at rest, SOPS does not satisfy that requirement — you would need a FIPS-validated module doing the encryption (e.g., using AlmaLinux in FIPS mode with OpenSSL FIPS provider).

For Helix Stax's current compliance posture (building FIPS-ready, not FIPS-certified), SOPS is appropriate. The algorithm is correct; the module validation gap only matters if a specific contract requires it.

**Note**: AlmaLinux 9 in FIPS mode enforces FIPS 140-3 approved algorithms at the kernel level. However, SOPS running on that system uses Go's crypto libraries — it would benefit from AlmaLinux FIPS mode for system-level calls but is not independently FIPS-validated.

### age and FIPS

age uses ChaCha20-Poly1305, which is **not** on the FIPS 140-2 approved algorithm list (though NIST is considering it for future standards). If FIPS compliance is a hard requirement for specific client work, use SOPS with AES-256-GCM (via OpenBao Transit or AWS KMS) rather than age as the encryption backend.

For Helix Stax internal infrastructure, age is fine. Flag this for any government or HIPAA client projects.

---

## 11. Key Risks and Gotchas

**Risk 1: Age key loss = data loss**
If the age private key is lost and there is no PGP backup key, encrypted files in Git are permanently unrecoverable. Mitigation: always configure a backup key, back up age keys to multiple secure locations.

**Risk 2: ArgoCD Redis cache exposure**
When using helm-secrets via manifest generation in ArgoCD, decrypted secrets may appear in the ArgoCD Redis cache (repo-server stores generated manifests). Mitigation: use sops-secrets-operator instead (CRD-based approach avoids this), or implement network policies restricting Redis access.

**Risk 3: Terraform state exposure**
The standard `carlpett/sops` Terraform provider writes decrypted values to Terraform state. Terraform state must then be secured (encrypted remote state backend). Mitigation: use `nobbs/sops` provider which uses functions instead of data sources, or mark values as sensitive and use encrypted state.

**Risk 4: Key rotation complexity**
Rotating SOPS keys requires re-encrypting every file that used the old key. The `sops updatekeys` command automates this, but it must be run across all repos. For a large number of encrypted files, this becomes a significant operation. Mitigation: minimize the number of encrypted files; prefer keeping secrets in OpenBao for anything that rotates frequently.

**Risk 5: CI/CD key exposure**
The age private key must be available to GitHub Actions for decrypt operations. This key is a GitHub Actions secret, which means it is accessible to anyone with write access to the repo. Mitigation: use repository environments with approval gates for production key access; use separate keys for dev/staging/prod environments.

**Risk 6: sops-secrets-operator maturity**
`isindir/sops-secrets-operator` is community-maintained, not a CNCF or major-vendor project. Latest version (0.13.1) has limited recent activity. Mitigation: pin to a tested version; have a fallback plan (helm-secrets approach); monitor the project's GitHub for maintenance status.

---

## 12. Deployment Pipeline Compatibility

| Question | Answer |
|----------|--------|
| Helm-chartable? | Yes — sops-secrets-operator available on ArtifactHub |
| Testable in vCluster? | Yes — age keys can be mounted as K8s Secrets in vCluster; full integration test possible |
| GitHub Actions workflow needed? | Yes — for encrypting/decrypting during CI; age key stored as GitHub Actions secret |
| AlmaLinux 9 compatible? | Yes — sops binary available as static Go binary; no OS-specific dependencies |
| Flannel CNI impact? | None — SOPS operates at file/CLI level, not network level |
| Traefik impact? | None |
| ArgoCD integration required? | For helm-secrets path: yes (repo-server modification); for sops-operator path: no |

---

## 13. Open Questions Requiring Input

1. **Key storage strategy**: Should the age private key be managed by OpenBao (stored as a Vault secret, retrieved at runtime) or kept as a standalone K8s Secret? The former adds a chicken-and-egg bootstrapping problem (need to decrypt SOPS to bootstrap OpenBao, but need OpenBao to decrypt SOPS).

2. **Scope of SOPS adoption**: Should SOPS be used for all repos (infra, app, Ansible) or only the infra/config repo? Keeping scope narrow reduces key management overhead.

3. **ArgoCD integration path**: Prefer sops-secrets-operator (CRD approach, no ArgoCD modification, avoids Redis exposure) or helm-secrets plugin (simpler for Helm-native workflows, requires patching argocd-repo-server)? This should be an architectural decision with Cass.

4. **Existing OpenBao bootstrap gap**: How are OpenBao unseal keys and root token currently stored/distributed? If in a Google Doc or password manager rather than Git, SOPS could formalize this.

5. **Client-facing usage**: If Helix Stax manages client infrastructure, does each client get their own age key? Key separation per client is important for access control.

---

## 14. Recommended Approach

**Phase 1: Infra repo only, age + OpenBao Transit**

1. Install `age` binary locally (static binary, no OS packages needed)
2. Generate an age keypair: `age-keygen -o ~/.config/sops/age/keys.txt`
3. Add `.sops.yaml` to the infra repo root with path-based creation rules
4. Encrypt all existing sensitive files in the infra repo (Hetzner tokens, secrets.yaml, etc.)
5. Store the age public key in `.sops.yaml` (safe to commit)
6. Store the age private key as a K8s Secret in the cluster (restricted namespace)
7. Deploy sops-secrets-operator via Helm for K8s secret injection

**Phase 2: ArgoCD integration**

1. Evaluate sops-secrets-operator approach (preferred) vs helm-secrets
2. If helm-secrets: patch argocd-repo-server with init container, mount age key
3. Update GitOps config repo to use SOPS-encrypted values files

**Phase 3: Ansible and OpenTofu**

1. Install `community.sops` Ansible collection
2. Rename sensitive group_vars files to `.sops.yaml` pattern, encrypt them
3. Add `nobbs/sops` or `carlpett/sops` provider to OpenTofu configs
4. Encrypt `.tfvars` files containing credentials

---

## References

- SOPS GitHub Repository: https://github.com/getsops/sops
- SOPS Official Documentation: https://getsops.io/docs/
- helm-secrets (ArgoCD integration wiki): https://github.com/jkroepke/helm-secrets/wiki/ArgoCD-Integration
- sops-secrets-operator Helm chart: https://artifacthub.io/packages/helm/sops-secrets-operator/sops-secrets-operator
- community.sops Ansible collection: https://docs.ansible.com/ansible/latest/collections/community/sops/docsite/guide.html
- carlpett/sops OpenTofu provider: https://search.opentofu.org/provider/carlpett/sops/v1.2.0
- FluxCD SOPS guide (reference for patterns): https://fluxcd.io/flux/guides/mozilla-sops/
- GitGuardian SOPS comprehensive guide: https://blog.gitguardian.com/a-comprehensive-guide-to-sops/
- SOPS vs Vault analysis: https://oteemo.com/blog/hashicorp-vault-is-overhyped-and-mozilla-sops-with-kms-and-git-is-massively-underrated/
