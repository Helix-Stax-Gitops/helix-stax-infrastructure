Of course. This is an excellent project for AI agents. A structured, comprehensive, and opinionated reference is precisely what they need to operate effectively.

Here is the deep research on your secrets pipeline, formatted for your specifications.

***

# SOPS + age

## SKILL.md Content

### Overview
SOPS (Secrets OPerationS) is a file encryption tool that wraps structured files (YAML, JSON, ENV) and encrypts only their values, leaving keys intact. `age` is a simple, modern public-key encryption tool that we use as the encryption backend for SOPS.

- **Role:** Encrypting secrets-at-rest in Git (`values-secrets.yaml`, K8s `Secret` manifests for bootstrapping).
- **Workflow:** Developer (`sops --edit`) -> Commit to Git -> ArgoCD/KSOPS decrypts during deployment.

### Key Management
- **Generate Key:** `age-keygen -o ~/.config/sops/age/keys.txt`
- **Key Format:** The file contains the private key (`AGE-SECRET-KEY-1...`) and the public key (`age1...`).
- **Default Location:** SOPS automatically checks `~/.config/sops/age/keys.txt` on Linux/macOS and `%AppData%\sops\age\keys.txt` on Windows.
- **CI Key:** Store the CI `age` private key as a secret in your CI system (e.g., Devtron CI secret, ArgoCD secret) and load it into the `SOPS_AGE_KEY` environment variable.

### Core CLI Reference
_Assume a `.sops.yaml` is configured with keys._
- **Edit Encrypted File (Primary Workflow):**
  ```bash
  sops --edit secrets/my-app/values-secrets.yaml
  ```
- **Encrypt a file in-place:**
  ```bash
  sops --encrypt --in-place secrets/dev/db.env
  ```
- **Decrypt to standard output:**
  ```bash
  sops --decrypt secrets/my-app/values-secrets.yaml
  ```
- **Extract a single value:**
  ```bash
  # Extracts the value of 'password' from the 'database' key
  sops -d --extract '["database"]["password"]' secrets/my-app/values-secrets.yaml
  ```
- **Add/Remove a Master Key (e.g., add new dev, switch to OpenBao):**
  1. Update `.sops.yaml` with the new key(s).
  2. Run `sops updatekeys a-secret-file.yaml`. This requires access to at least one of the old keys.
- **Rotate the Data Key (DEK):**
  ```bash
  # Re-encrypts data with a new DEK, using the same master keys.
  sops --rotate --in-place a-secret-file.yaml
  ```

### Configuration (`.sops.yaml`)
Place this file in the root of your Git repository.
```yaml
# .sops.yaml
creation_rules:
  # Encrypt files for Production/Staging with OpenBao (for ArgoCD) and a CI age key (for Devtron)
  - path_regex: '^(secrets|helm)/.*/values-secrets\.yaml$'
    encrypted_regex: '^(data|stringData)$' # For K8s Secrets, encrypt only data/stringData
    hc_vault_transit_uri: "https://bao.helixstax.net/v1/transit/keys/sops-key"
    age: >-
      age1ciagerecipientpublickeygoeshere,
      age1devonepublickeygoeshere,
      age1devtwopublickeygoeshere

  # Encrypt local dev environment files with developer keys only
  - path_regex: '\.env\.dev\.sops$'
    age: >-
      age1devonepublickeygoeshere,
      age1devtwopublickeygoeshere
```

### Troubleshooting Decision Tree
- **Symptom:** `Error: Failed to get the data key...`
  - **Cause 1:** OpenBao Transit key is used, but OpenBao is unavailable/sealed.
    - **Fix:** Check OpenBao status: `bao status -address=https://bao.helixstax.net`. Unseal if necessary.
  - **Cause 2:** `BAO_ADDR` or `VAULT_ADDR` env var is not set, or is incorrect.
    - **Fix:** `export BAO_ADDR=https://bao.helixstax.net`
  - **Cause 3:** `BAO_TOKEN` is invalid/expired.
    - **Fix:** Re-authenticate: `bao login -method=oidc`
  - **Cause 4:** `age` key is used, but the private key is not found.
    - **Fix:** Ensure `~/.config/sops/age/keys.txt` exists and has the correct permissions (600), or `SOPS_AGE_KEY_FILE`/`SOPS_AGE_KEY` is set.

- **Symptom:** `MAC mismatch`
  - **Cause:** The encrypted file was modified by a tool other than `sops`.
  - **Fix:** `git checkout -- <file>` to revert the changes. Never edit an encrypted file directly. If you must recover, try `sops --decrypt --ignore-mac <file>`, but this is risky; you may be decrypting tampered data.

- **Symptom:** `Could not find a suitable key for decryption`
  - **Cause:** You do not possess any of the private keys (age) or tokens (OpenBao) corresponding to the recipients in the file header.
  - **Fix:** Get access to a valid key. Ask a team member to re-encrypt the file for you using `sops updatekeys`.

---
## reference.md Content

### A1. How SOPS and age Work Together
- **age vs GPG:** We chose `age` over GPG because it's significantly simpler. It has no complex keyrings, trust models, or key servers. It uses modern, misuse-resistant cryptography (X25519 for key exchange, ChaCha20-Poly1305 for encryption).
- **SOPS File Format:** SOPS acts as a wrapper. When you encrypt a file (`secrets.yaml`), SOPS:
    1.  Generates a fresh, random **Data Encryption Key (DEK)**.
    2.  Encrypts the *values* of your file with this DEK.
    3.  For each recipient defined in `.sops.yaml` (e.g., an `age` public key, an OpenBao transit key), it encrypts the DEK.
    4.  It stores the encrypted values and the list of encrypted DEKs in a `sops` metadata block within the file itself.
    To decrypt, SOPS uses your provided key (e.g., your `age` private key) to decrypt one of the DEKs, then uses that DEK to decrypt the file's values.
- **age Key Anatomy:**
    - **Private Key:** `AGE-SECRET-KEY-1...` A unique secret string that can decrypt data. **Keep this file secure (chmod 600).**
    - **Public Key:** `age1...` A publicly shareable string used to encrypt data *for* the corresponding private key. It's safe to commit this to `.sops.yaml`.

### A2. Key Management with age
- **Generating Keys:** `age-keygen -o key.txt` produces a file containing both the private key (prefixed with `# created: ...` and `AGE-SECRET-KEY...`) and the corresponding public key (prefixed with `# public key: ...`).
- **Storing Private Key:**
    - **Linux/macOS:** SOPS automatically looks for `$HOME/.config/sops/age/keys.txt`. This is the standard location for a user's primary key.
    - **Windows:** `%AppData%\sops\age\keys.txt` (e.g., `C:\Users\YourUser\AppData\Roaming\sops\age\keys.txt`).
    - **Environment Variable:** You can point to a key file with `export SOPS_AGE_KEY_FILE=/path/to/key.txt` or provide the key directly with `export SOPS_AGE_KEY="AGE-SECRET-KEY-..."`. The latter is used for CI.
- **Multiple Recipients:** To encrypt for a team and a CI server, list all their public keys in the `.sops.yaml` `age:` field, comma-separated.
- **Key Rotation:**
    1.  Generate a new key pair: `age-keygen -o new_key.txt`.
    2.  Add the new public key to the relevant `creation_rules` in `.sops.yaml`.
    3.  Run a script to update all relevant files: `find . -name "*.enc.yaml" -exec sops updatekeys --in-place {} \;`.
    4.  Verify decryption works with the new key and that CI pipelines succeed.
    5.  Remove the old public key from `.sops.yaml`.
    6.  Run `sops updatekeys` again on all files to remove the old recipient from the file headers.
    7.  Securely delete the old private key.
- **Backing Up Keys:** Store your `age` private key file in a secure location, like a password manager (1Password, Bitwarden) or, ironically, in a sealed OpenBao KV secret. Losing the private key means permanent loss of access to data encrypted with it.

### A3. SOPS CLI Reference
- `sops --encrypt (-e)`:
    - `sops -e -i secrets.yaml`: Encrypts `secrets.yaml` in-place.
    - `sops -e secrets.yaml`: Prints encrypted content to stdout.
    - Specify backend: `sops -e --age <pubkey> secrets.yaml` (overrides `.sops.yaml`).
- `sops --decrypt (-d)`:
    - `sops -d -i secrets.yaml`: Decrypts in-place (dangerous, avoid in Git repos).
    - `sops -d secrets.yaml`: Prints decrypted content to stdout.
    - `--output-type [binary|dotenv|json|yaml]`: Forces a specific output format.
    - `--extract '["path"][0]["key"]'`: JSONPath expression to extract a single value.
- `sops --edit`: The safest way to edit. It decrypts the file to a temporary location, opens it in `$EDITOR`, and automatically re-encrypts on save. If interrupted, the temp file is usually cleaned up, but the original encrypted file remains untouched.
- `sops --rotate (-r)`:
    - `sops -r -i secrets.yaml`: Generates a new DEK, re-encrypts the file's data, and encrypts the new DEK with the *same* master keys. Useful for regular compliance-driven rotation or after a non-critical potential exposure where master keys are not compromised.
- `sops --updatekeys (-u)`:
    - `sops -u secrets.yaml`: Re-encrypts the file's DEK using the *current* set of master keys defined in `.sops.yaml`. This is a critical command for adding/removing users or migrating KMS providers. You must be able to decrypt the file with an existing key to perform this operation.
- **Global Flags:**
    - `--config <path>`: Specify a path to a `.sops.yaml` file.
    - `--verbose`: Shows detailed step-by-step information during en/decryption.
    - `--ignore-mac`: Bypasses the Message Authentication Code check. **This is dangerous.** Only use it as a last resort to recover a file that was corrupted or manually edited after encryption. The data may have been tampered with.
- **Environment Variables:**
    - `SOPS_AGE_KEY_FILE`: Path to a file containing one or more age private keys.
    - `SOPS_AGE_KEY`: The age private key string itself.
    - `BAO_ADDR`/`VAULT_ADDR`: The URL of the OpenBao/Vault server. `BAO_ADDR` is preferred for clarity.
      # OpenBao accepts both VAULT_* and BAO_* env vars. Prefer BAO_* to avoid confusion with HashiCorp Vault.
    - `BAO_TOKEN`/`VAULT_TOKEN`: The authentication token. SOPS also respects standard AppRole and K8s auth env vars.
      # OpenBao accepts both VAULT_* and BAO_* env vars. Prefer BAO_* to avoid confusion with HashiCorp Vault.

### A4. OpenBao Transit Integration
- **OpenBao Setup:**
    1.  Enable engine: `bao secrets enable transit`
    2.  Create key: `bao write -f transit/keys/sops-key type=aes256-gcm96`
    3.  Create policy: SOPS needs `read` on the key and `update` (for encrypt/decrypt operations).
        ```hcl
        # sops-policy.hcl
        path "transit/encrypt/sops-key" {
          capabilities = ["update"]
        }
        path "transit/decrypt/sops-key" {
          capabilities = ["update"]
        }
        path "transit/keys/sops-key" {
           capabilities = ["read"]
        }
        ```
- **SOPS Configuration:** Add the transit URI to `.sops.yaml`.
  `hc_vault_transit_uri: "https://bao.helixstax.net/v1/transit/keys/sops-key"`
- **Authentication:** In CI/CD (ArgoCD), SOPS will use the Kubernetes Service Account token to authenticate against OpenBao's `kubernetes` auth backend. For local use, it uses the token from `~/.bao-token` or `BAO_TOKEN`, typically obtained via `bao login -method=oidc`.
- **How it Works:** SOPS does **not** send the plaintext to OpenBao. It performs envelope encryption locally:
    1.  SOPS generates a random DEK.
    2.  It sends *only the DEK* to OpenBao's `transit/encrypt/sops-key` endpoint.
    3.  OpenBao encrypts the DEK and returns the ciphertext.
    4.  SOPS stores this encrypted DEK in the file's metadata.
- **Key Rotation in OpenBao:** Running `bao write -f transit/keys/sops-key/rotate` creates a new version of the key *inside* OpenBao. This does **not** automatically re-encrypt your SOPS files. Old files can still be decrypted. To update them to use the new transit key version, you must run `sops --rotate --in-place <file>`.
- **OpenBao Unavailable:** If OpenBao is sealed or unreachable when you try to decrypt a file using the transit key, the operation will fail with an error like `Error: Failed to get the data key`. If you have an alternate key (like an `age` key) in the same file, SOPS can still succeed. This is why having both is a good pattern.

### A6. .sops.yaml Deep Dive
This file is the brain of SOPS. SOPS searches for it in the current directory and parent directories.
- **`creation_rules`:** An array of rules. The *first* rule with a `path_regex` that matches the file being created/encrypted is used.
- **`path_regex`:** A standard regular expression to match file paths.
- **`key_groups` & `keys`:** You can define reusable groups of keys, but the direct `age:` and `hc_vault_transit_uri:` fields are simpler for our use case.
- **`encrypted_regex`:** A powerful feature for partial encryption. It's a regex that matches the keys in your data structure whose values should be encrypted. For K8s Secrets, `^(data|stringData)$` is perfect because it encrypts the entire secret data block while leaving `metadata`, `apiVersion`, etc., as plaintext for tools like `kubectl` to read.

### A8. GitOps Workflow with ArgoCD
- **Recommendation: KSOPS.** For a Kustomize-heavy GitOps workflow like yours, `ksops` (Kustomize SOPS) is the most seamless approach. `helm-secrets` is excellent but adds another layer if you're not using Helm for everything. The ArgoCD native SOPS integration is also an option but KSOPS provides more flexibility.
- **KSOPS (Kustomize + SOPS):**
    - **What it is:** A Kustomize secret generator plugin. It reads a SOPS-encrypted file and outputs a valid Kubernetes `Secret` manifest during `kustomize build`.
    - **ArgoCD Setup:**
        1.  **Custom Image:** Build a custom ArgoCD repo-server image that includes the `ksops` and `sops` binaries.
        2.  **Plugin Config:** Configure the Kustomize plugin in the `argocd-cm` ConfigMap.
        3.  **K8s Auth:** Create an OpenBao policy granting ArgoCD's ServiceAccount access to the `sops-key` transit engine. Bind this policy to the SA via a K8s auth role in OpenBao. ArgoCD will then automatically use its pod SA token to authenticate to OpenBao for decryption.

### A9. Key Rotation Workflow (Automation)
Automating `sops updatekeys` is crucial for efficient key rotation.
```bash
#!/bin/bash
# run-sops-updatekeys.sh

# Find all files matching the patterns and run updatekeys
# Add any relevant file patterns here
find . -type f \( -name "values-secrets.yaml" -o -name "*.sops.yaml" -o -name "*.sops.env" \) -print0 | while IFS= read -r -d $'\0' file; do
    echo "Updating keys for $file..."
    sops updatekeys --in-place "$file"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to update keys for $file" >&2
        exit 1
    fi
done

echo "All files updated successfully."
```
- **Emergency Rotation (Compromised Key):**
    1.  **Revoke Access Immediately:** Delete the compromised public key from `.sops.yaml`. Delete the user/CI role in OpenBao/Zitadel.
    2.  **Generate a New Key:** Create a new key pair if needed.
    3.  **Run Update Script:** Execute the `sops updatekeys` script. This will fail for anyone using the old key but will succeed for everyone else, effectively removing the compromised key's access.
    4.  **Commit and Push:** Forcefully push the changes to ensure the compromised key is no longer in the repo's history for new clones.
    5.  **Audit:** Audit all secrets that may have been exposed.

---
## examples.md Content

### A2. Generating and Storing a Developer's age Key
```bash
# 1. Create the standard directory with secure permissions
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age

# 2. Generate the key directly into the default file
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 3. View the file content
cat ~/.config/sops/age/keys.txt
# Output will look like this:
# Created: 2023-10-27T10:00:00Z
# public key: age1zkerf5n0p2hxl5pa243f7vsvd4k068j5n40v7y3q8p8yjsq3z9wqhwhf8l
AGE-SECRET-KEY-1NAEVEXL3D8ZAFQZPJ07NJ4S5N88Z9QAYV533J3P89CF5GMM9J89S5RJPU2

# 4. Copy the public key (age1...) to add to .sops.yaml
```

### A6. Complete `.sops.yaml` for Helix Stax
This file should live at the root of your infrastructure repository.
```yaml
# .sops.yaml
# SOPS configuration for Helix Stax infrastructure repository.

creation_rules:
  # === PRODUCTION & STAGING RULES ===
  # Matches Kubernetes secrets and Helm secret values for applications.
  # Encrypted for ArgoCD (via OpenBao) and a CI runner key (for bootstrap/testing).
  - path_regex: 'kubernetes/.*/(secrets|values-secrets)\.yaml$'
    # Only encrypt the 'data' and 'stringData' fields in K8s Secret manifests.
    # For Helm values, this will encrypt all leaf nodes unless a more specific regex is provided.
    encrypted_regex: '^(data|stringData|adminPassword|secretKey|credentials|token|privateKey)$'
    # Recipient 1: OpenBao Transit Engine in the K3s cluster.
    # ArgoCD will use this via Kubernetes Auth.
    hc_vault_transit_uri: "https://bao.helixstax.net/v1/transit/keys/sops-key"
    # Recipient 2: A dedicated 'age' key for the CI system (e.g., Devtron).
    # Its private key is stored as a secret in the CI environment.
    age: >-
      age1ciagerecipientpublickeygoeshere,
      age1keemwilliamspublickeygoeshere

  # === LOCAL DEVELOPMENT RULES ===
  # Matches .env files intended for local development.
  # Encrypted only for human developers, not for CI or the cluster.
  - path_regex: 'local/dev/.*\.env\.sops$'
    age: >-
      age1keemwilliamspublickeygoeshere,
      age1otherdeveloperpublickeygoeshere

  # Fallback rule for any other file ending in .sops.yaml
  - path_regex: '\.sops\.yaml$'
    hc_vault_transit_uri: "https://bao.helixstax.net/v1/transit/keys/sops-key"
    age: age1ciagerecipientpublickeygoeshere,age1keemwilliamspublickeygoeshere
```

### A8. ArgoCD KSOPS Integration Example
**1. KSOPS Generator Manifest (`kustomization.yaml`)**
This tells Kustomize (and thus ArgoCD) to use `ksops` to generate a secret.

```yaml
# kubernetes/apps/monitoring/grafana/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - ingressroute.yaml
generators:
  # This will invoke ksops on the encrypted file
  - grafana-secrets.ksops.yaml
```

**2. The KSOPS Generator Config (`grafana-secrets.ksops.yaml`)**
This file points to the SOPS-encrypted source. The filename convention is not required, but helpful.

```yaml
# kubernetes/apps/monitoring/grafana/grafana-secrets.ksops.yaml
apiVersion: viaduct.ai/v1
kind: Ksops
metadata:
  name: grafana-secrets-generator
  namespace: monitoring
files:
  # Path to the SOPS-encrypted values file
  - secrets.enc.yaml
```

**3. The SOPS Encrypted Source (`secrets.enc.yaml`)**
This is what a developer would commit. It contains the encrypted data.

```yaml
# kubernetes/apps/monitoring/grafana/secrets.enc.yaml
apiVersion: v1
kind: Secret
metadata:
    name: grafana-admin-creds
    namespace: monitoring
stringData:
    admin_user: ENC[AES256_GCM,data:c3VwZXItYWRtaW4=,iv:...,tag:...,gcm_mac:...]
    admin_password: ENC[AES256_GCM,data:c2VjcmV0cGFzc3dvcmQxMjM=,iv:...,tag:...,gcm_mac:...]
sops:
    # ... SOPS metadata with encrypted DEKs for OpenBao and age recipients ...
```
When ArgoCD runs `kustomize build`, KSOPS will be called. It authenticates to `https://bao.helixstax.net`, decrypts the file, and outputs a standard `kind: Secret` manifest, which ArgoCD then applies to the cluster.

### A11. Useful Shell Aliases for Developers
```bash
# Add to your ~/.bashrc or ~/.zshrc
export BAO_ADDR="https://bao.helixstax.net"
# OpenBao accepts both VAULT_* and BAO_* env vars. Prefer BAO_* to avoid confusion with HashiCorp Vault.

alias se='sops --edit'
alias sv='sops --decrypt' # 'sv' for 'sops view'
alias se-dev='sops --edit local/dev/my-app.env.sops'
```

***

# OpenBao

## SKILL.md Content

### Overview
OpenBao is the central secrets management system at Helix Stax, running inside our K3s cluster. It is a community-driven fork of HashiCorp Vault. It provides secrets at runtime, including KV secrets, dynamic database credentials, and internal TLS certificates.

- **Role:** Central, secure, and auditable runtime secrets store.
- **Access:** Applications access it via Kubernetes Auth (through ESO). Humans access it via OIDC (Zitadel).

### Core CLI Reference (`bao`)
_Ensure `BAO_ADDR` and `BAO_TOKEN` are set._
- **Check Status:**
  ```bash
  bao status
  # Key: 'Sealed', Value: 'false' means OpenBao is operational.
  ```
- **Login (for Humans via Zitadel):**
  ```bash
ah
  bao login -method=oidc
  ```
- **Unseal (Manual):**
  ```bash
  bao operator unseal <unseal_key_1>
  bao operator unseal <unseal_key_2>
  # ... and so on
  ```
- **KV v2 Operations (Our standard path: `secret/data/...`):**
  ```bash
  # Write a secret for Grafana
  bao kv put secret/grafana/oidc client_secret=zita-client-secret-value

  # Read a secret
  bao kv get secret/grafana/oidc

  # List secrets in a path
  bao kv list secret/grafana/

  # Delete the latest version (soft delete)
  bao kv delete secret/grafana/oidc
  ```
- **Check Your Token's Capabilities on a Path:**
  ```bash
  bao token capabilities secret/data/grafana/oidc
  ```

### Key Paths & Policies
- **KV Secrets:** `secret/{app-name}/{secret-name}` (e.g., `secret/zitadel/postgres-dsn`) — KV v2 CLI omits the `data/` prefix; `data/` only appears in raw HTTP API paths
- **Dynamic DB Credentials:** `database/creds/{role-name}` (e.g., `database/creds/n8n-readwrite`)
- **SOPS Transit Key:** `transit/keys/sops-key`
- **PKI Issuance:** `pki_int/issue/{role-name}`
- **Policies:** Named `{app-name}-{access-level}` (e.g., `grafana-read`, `eso-read-all`).

### Troubleshooting Decision Tree
- **Symptom:** `Error making API request... permission denied`
  - **Cause:** Your token's policy does not grant access to the path.
  - **Fix:** Check your token's policies (`bao token lookup`). Use `bao token capabilities <path>` to verify. Request policy update from an admin.

- **Symptom:** OpenBao UI/API is unreachable or gives 5xx errors. `bao status` shows `Sealed: true`.
  - **Cause:** The OpenBao pod restarted and failed to auto-unseal.
  - **Fix:** Check the `openbao-0` pod logs (`kubectl logs openbao-0 -n openbao`). This indicates a problem with the unseal mechanism. Perform a manual unseal as a temporary fix and investigate the root cause.

- **Symptom:** Application pod fails to start with auth errors related to OpenBao.
  - **Cause 1:** The `ClusterSecretStore` in ESO has the wrong `role` for Kubernetes auth.
  - **Fix:** Verify the `role` in the `ClusterSecretStore` matches a role defined in OpenBao under `auth/kubernetes/role/...`.
  - **Cause 2:** The application's ServiceAccount is not bound to the role in OpenBao.
  - **Fix:** Check the `bound_service_account_names` and `bound_service_account_namespaces` for the role in OpenBao.

---
## reference.md Content

### B1. OpenBao vs HashiCorp Vault
- **License:** OpenBao is a fork of Vault created after HashiCorp switched to the Business Source License (BSL). OpenBao remains under the Mozilla Public License 2.0 (MPL-2.0), ensuring it stays open source.
- **API Compatibility:** OpenBao is a **drop-in replacement** for Vault. All clients, providers (like for Terraform/ESO), and tools that work with the Vault API work identically with OpenBao.
- **CLI/Env Vars:** The primary difference is the CLI binary name (`bao` vs `vault`). They share the same command structure. By convention, we use `BAO_` prefixed environment variables (`BAO_ADDR`, `BAO_TOKEN`), though OpenBao maintains compatibility with `VAULT_` prefixes for a seamless transition.

### B2. K3s Deployment (Helm + Raft HA)
- **Helm Chart:** Use the official OpenBao chart: `helm repo add openbao https://openbao.github.io/helm-charts`.
- **Raft Storage:** OpenBao has a built-in HA storage backend called Raft. It requires a quorum (majority of nodes) to function. On a 2-node K3s cluster, a 3-pod OpenBao statefulset (the default for HA) cannot achieve quorum if one pod goes down.
- **Recommendation for 2-Node Cluster:** For our setup, we have two options:
    1.  **Production (Recommended):** Deploy a 3-pod Raft cluster and add a third, very small, cheap "voter-only" K3s agent node to ensure quorum can be maintained.
    2.  **Simplified (Non-HA):** Deploy a single OpenBao pod (`ha.enabled=false`). This is simpler but creates a single point of failure. Given the importance of secrets, this is not recommended for production.
- **TLS:** The Helm chart can auto-generate self-signed certs, but for production we use Cloudflare Origin CA certificates stored as Kubernetes Secrets. Provide the cert via `extraVolumes` mounting a pre-created Secret — no cert-manager, no Let's Encrypt.
  # TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
- **Probes:** The readiness probe endpoint `/v1/sys/health` is critical. It correctly reports unready (but live) when OpenBao is sealed, preventing K3s from routing traffic to it while allowing it to be unsealed.

### B3. Auto-Unseal Strategy
Hetzner Cloud does not offer a native KMS, which is the typical backend for auto-unseal.
- **Recommended Approach: Transit Auto-Unseal.** This involves running a *second, tiny* OpenBao instance whose sole job is to provide its Transit engine as a KMS to auto-unseal the primary OpenBao cluster. This is the most secure and cloud-native approach, but adds complexity.
- **Pragmatic Alternative:** Use a Kubernetes `Job` that runs on startup, retrieves a sealed unseal key from a K8s secret, and uses it to unseal the service. The K8s secret itself can be encrypted at rest using K3s's built-in functionality. This is a "good enough" solution for a small-scale cluster.
- **Manual Unseal:** The fallback. The `operator init` command produces unseal keys. These must be stored securely (e.g., in 1Password) and used with `bao operator unseal` if automation fails.
- **Monitoring:** An Alertmanager rule `vault_core_sealed == 1` is **critical** to notify operators immediately if OpenBao becomes sealed.

### B4. Authentication Methods
- **Kubernetes (Primary for services):** The most secure method for in-cluster applications.
    - **How it works:** ESO (or any pod) presents its ServiceAccount's JWT to OpenBao. OpenBao validates the JWT against the K3s API server.
    - **Setup:** `bao auth enable kubernetes`. Configure it with the K3s API host and CA cert.
    - **Role:** A role ties a Kubernetes ServiceAccount (e.g., `external-secrets` in namespace `external-secrets`) to a set of OpenBao policies (e.g., `eso-read-all`).
- **OIDC (Primary for humans):** Uses Zitadel for UI and CLI login.
    - **Setup:** `bao auth enable oidc`. Configure it with the client ID, secret, and URLs from your Zitadel application.
    - **Role Mapping:** Map claims from the Zitadel ID token (like groups or roles) to OpenBao policies. E.g., a "helix-stax-admins" group in Zitadel gets the `admin` policy in OpenBao.
- **AppRole (Primary for CI/non-K8s):** For systems like Devtron that run outside the K8s pod identity system. It's a two-part credential (RoleID + SecretID) that is more secure than a static token.
- **Token (Bootstrap/Emergency only):** The root token generated at `operator init` should be used ONLY for initial setup and then revoked. Never use long-lived tokens in applications.

### B5. Secret Engines
- **KV v2 (`secret/`):** Our primary store for static secrets. The `v2` engine provides versioning and soft-deletes. Our path convention is `secret/{app}/{key}` (CLI) / `secret/data/{app}/{key}` (raw HTTP API only).
- **Database (`database/`):** Issues dynamic, short-lived credentials for CloudNativePG.
    - **Integration:** Configure the DB engine with a static, long-lived "root" PostgreSQL user that has permissions to create other users. OpenBao uses this user to create/revoke dynamic credentials on demand.
    - **Services:** n8n, Grafana, and other internal apps that need DB access should use dynamic credentials. ESO requests a credential from `database/creds/{role-name}` and injects it into the pod. The lease is automatically renewed by ESO and revoked by OpenBao when the lease expires.
- **PKI (`pki_int/`):** Acts as our internal Certificate Authority for `*.helixstax.net`.
    - **Setup:** We'll have a root CA (offline or heavily secured) and an intermediate CA in OpenBao. OpenBao signs CSRs from `cert-manager`.
    - **Integration:** The `cert-manager-issuer` for OpenBao allows `cert-manager` to treat OpenBao as an `Issuer` or `ClusterIssuer`, automating internal TLS certificate issuance.
- **Transit (`transit/`):** Provides encryption-as-a-service.
    - **Primary Use Case:** Acts as the KMS backend for `sops`, as described in the SOPS section. It encrypts the DEK for secrets stored in Git.
    - **Key Type:** For SOPS, `aes256-gcm96` is the standard and recommended key type.

### B9. Audit Logging, Backup & Recovery
- **Audit Logging:** Enable a file audit device that logs to a path on a shared volume.
  `bao audit enable file file_path=/bao/logs/audit.log`
  A Promtail sidecar container will tail this JSON-formatted log file and ship it to Loki. Indexing fields like `request.path`, `auth.display_name`, and `policy.names` allows for powerful security queries in Grafana/Loki.
- **Backup:**
    1.  **Raft Snapshot:** The authoritative backup method. A Kubernetes `CronJob` will run `bao operator raft snapshot save /path/to/snapshot` and then upload the snapshot file to a MinIO bucket.
    2.  **Velero:** Velero will back up the MinIO bucket (containing the Raft snapshot) to Backblaze B2 for off-site disaster recovery. Velero's PVC backup of the Raft data is a secondary, less reliable backup method.
- **Recovery:** To restore, you provision a new OpenBao cluster, and run `bao operator raft snapshot restore /path/to/snapshot`. The cluster will restart and come up in the state of the snapshot. **The cluster will be sealed after restore.** You will need the original unseal keys. This is why backing up the unseal keys is non-negotiable.

---
## examples.md Content

### B2. Helm `values.yaml` Snippet for OpenBao on K3s
```yaml
# values-openbao.yaml
server:
  # Using our internal domain, with TLS handled by Traefik/cert-manager
  ingress:
    enabled: false # We will manage with a dedicated Traefik IngressRoute

  ha:
    enabled: true
    replicas: 3 # Requires 3 K3s nodes (2 workers + 1 cp, or a dedicated voter) for HA
    raft:
      enabled: true
      # This configures the raft cluster peering
      config: |
        ui = true
        cluster_addr = "https://{{ .Release.Name }}-{{ .StatefulSet.PodName }}.{{ .Release.Name }}-internal:8201"
        api_addr = "https://{{ .Release.Name }}-{{ .StatefulSet.PodName }}.{{ .Release.Name }}-internal:8200"
        storage "raft" {
          path = "/bao/data"
          performance_multiplier = 1
        }
        listener "tcp" {
          address = "0.0.0.0:8200"
          cluster_address = "0.0.0.0:8201"
          tls_disable = "false"
          tls_cert_file = "/bao/userconfig/tls/tls.crt"
          tls_key_file = "/bao/userconfig/tls/tls.key"
        }

# TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
extraVolumes:
  - name: tls
    secret:
      secretName: bao-server-tls # Cloudflare Origin CA cert — no ACME/cert-manager

volumeMounts:
  - name: tls
    mountPath: "/bao/userconfig/tls"
    readOnly: true
```

### B2. Traefik `IngressRoute` for OpenBao
```yaml
# ingressroute-bao.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: openbao
  namespace: openbao
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`bao.helixstax.net`)
      kind: Rule
      services:
        - name: openbao # Name of the OpenBao service created by the Helm chart
          port: 8200
  tls:
    # TLS: Cloudflare Origin CA certificate stored as K8s Secret (managed via ESO/OpenBao)
    secretName: bao-origin-ca-tls # Cloudflare Origin CA cert — no ACME/cert-manager
```

### B6. Example HCL Policies
**1. `eso-read-all` Policy (for External Secrets Operator)**
```hcl
# Policy for ESO to read all KV v2 secrets and request dynamic DB credentials.
path "secret/data/*" {
  capabilities = ["read"]
}
path "database/creds/*" {
  capabilities = ["read"]
}
```

**2. `argocd-sops-decrypt` Policy (for ArgoCD KSOPS)**
```hcl
# Policy for ArgoCD's repo-server to use the transit key for SOPS decryption.
path "transit/decrypt/sops-key" {
  capabilities = ["update"]
}
```

**3. `n8n-app` Policy**
```hcl
# Policy for the n8n application.
# It can read its own static secrets AND request dynamic DB credentials.
path "secret/data/n8n/*" {
  capabilities = ["read"]
}
path "database/creds/n8n-readwrite" {
  capabilities = ["read"]
}
```

### B9. Kubernetes CronJob for Raft Snapshots
```yaml
# cronjob-bao-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bao-snapshot-backup
  namespace: openbao
spec:
  schedule: "0 2 * * *" # Run daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: bao-backup-sa # An SA with a role to exec into the bao pod
          containers:
            - name: bao-backup
              image: curlimages/curl:latest # Using a simple image with curl
              env:
                - name: BAO_ADDR
                  value: "https://openbao:8200"
                - name: BAO_SKIP_VERIFY
                  value: "true" # In-cluster only — never set for external connections
                - name: MINIO_ENDPOINT
                  value: "http://minio.storage.svc.cluster.local:9000"
                - name: MINIO_BUCKET
                  value: "bao-snapshots"
                - name: BAO_POD_NAME
                  value: "openbao-0"
              command:
                - "/bin/sh"
                - "-c"
                - |
                  set -ex
                  TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
                  SNAPSHOT_FILE="bao-snapshot-${TIMESTAMP}.snap"
                  
                  # 1. Exec into the OpenBao pod to take a snapshot
                  kubectl exec -n openbao ${BAO_POD_NAME} -- bao operator raft snapshot save /tmp/${SNAPSHOT_FILE}
                  
                  # 2. Copy the snapshot out of the pod
                  kubectl cp -n openbao ${BAO_POD_NAME}:/tmp/${SNAPSHOT_FILE} ./${SNAPSHOT_FILE}

                  # 3. Upload to MinIO (assuming mc is configured in a different image or using curl)
                  # This part needs adjustment based on your preferred upload tool.
                  # Example with curl's PUT:
                  curl -X PUT --upload-file ./${SNAPSHOT_FILE} ${MINIO_ENDPOINT}/${MINIO_BUCKET}/${SNAPSHOT_FILE}

                  # 4. Cleanup
                  rm ./${SNAPSHOT_FILE}
                  kubectl exec -n openbao ${BAO_POD_NAME} -- rm /tmp/${SNAPSHOT_FILE}
          restartPolicy: OnFailure
```

***

# External Secrets Operator (ESO)

## SKILL.md Content

### Overview
External Secrets Operator (ESO) is the bridge between OpenBao and our Kubernetes workloads. It reads secrets from OpenBao and synchronizes them as native Kubernetes `Secret` objects.

- **Role:** Safely injects runtime secrets into pods without sidecars or direct application logic.
- **Workflow:** `ExternalSecret` CRD created in Git -> ArgoCD applies CRD -> ESO reads from OpenBao -> ESO creates/updates a K8s `Secret` -> Pod mounts the K8s `Secret`.

### Core Resources
- **`ClusterSecretStore`:** A single, cluster-wide CRD that tells ESO how to connect and authenticate to our central OpenBao instance. We use one of these.
- **`ExternalSecret`:** A namespaced CRD that defines *what* secret to fetch from OpenBao and *where* to put it in a K8s `Secret`. This is the main object developers interact with.

### Creating an `ExternalSecret`
1.  Ensure the secret exists in OpenBao (e.g., `bao kv put secret/my-app/api-key value=123`).
2.  Create an `ExternalSecret` manifest.
3.  Commit and push to Git. ArgoCD syncs it.
4.  ESO will reconcile and create a `native-k8s-secret` in the `my-app` namespace.

```yaml
# external-secret-example.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-api-key
  namespace: my-app
spec:
  secretStoreRef:
    name: openbao-cluster-store # Reference our cluster-wide store
    kind: ClusterSecretStore
  refreshInterval: "1h" # How often to check for changes
  target:
    name: native-k8s-secret # Name of the K8s Secret to create
    creationPolicy: Owner # Creates the secret if it doesn't exist
  data:
    - secretKey: APP_API_KEY # Key in the K8s Secret
      remoteRef:
        key: secret/my-app/api-key # Path in OpenBao (KV v2 CLI format — no data/ prefix)
        property: value # The specific key within that OpenBao secret
```

### Troubleshooting Decision Tree
- **Symptom:** `ExternalSecret` has a status of `SecretSyncedError`.
  - **Check `kubectl describe externalsecret <name> -n <namespace>`:** Look at the `Status.Conditions.Message` field for the error.
  - **Cause 1:** "secret not found" or "permission denied".
    - **Fix:** Verify the path in `remoteRef.key` is correct. Verify the ESO policy in OpenBao allows reading that path.
  - **Cause 2:** "vault is sealed".
    - **Fix:** OpenBao is sealed. Unseal it.
  - **Cause 3:** Path format is wrong for KV v2.
    - **Fix:** KV v2 paths in ESO **must** start with the engine path (e.g., `secret/`), not just `data/`. The full path is required.

- **Symptom:** The K8s `Secret` is not updating after I changed the value in OpenBao.
  - **Cause 1:** `refreshInterval` has not elapsed yet.
    - **Fix:** Wait for the interval or force a refresh by deleting the `ExternalSecret` and letting ArgoCD re-create it.
  - **Cause 2:** The pod is not reloading the updated secret.
    - **Fix:** ESO only updates the K8s `Secret`. Pods that mount secrets as environment variables need to be restarted to see changes. Pods that mount secrets as volumes see updates eventually. Use a tool like **`stakater/reloader`** to automatically trigger a deployment rollout when a secret changes.

---
## reference.md Content

### C1. Architecture and How ESO Works
- **Components:**
    - **Operator Deployment:** The main controller that runs the reconciliation loop.
    - **CRDs:** `SecretStore`, `ClusterSecretStore`, `ExternalSecret`. These define the "what" and "how" of secret synchronization.
- **Reconciliation Loop:** The ESO controller watches all `ExternalSecret` resources. For each one, it periodically (`refreshInterval`):
    1.  Authenticates to the backing provider (OpenBao) using the credentials from the referenced `SecretStore`.
    2.  Fetches the remote secret data.
    3.  Gets the target Kubernetes `Secret`.
    4.  Compares the fetched data with the data in the K8s `Secret`.
    5.  If they differ, ESO updates the K8s `Secret`.
- **`SecretStore` vs. `ClusterSecretStore`:**
    - `SecretStore`: Namespaced. Defines a secret backend for a single namespace.
    - `ClusterSecretStore`: Cluster-wide. Defines a backend that can be referenced by `ExternalSecret`s in any namespace.
    - **Our Choice:** We use a single `ClusterSecretStore` because we have one central OpenBao instance for the entire cluster. This avoids configuration duplication.

### C2. `ClusterSecretStore` Configuration
This is a one-time setup for the cluster. It tells ESO how to talk to our OpenBao instance.
- **Authentication:** We use the Kubernetes auth provider. ESO's ServiceAccount is granted a role in OpenBao, and it presents its SA token to authenticate.
- **TLS:** Because our OpenBao uses a TLS certificate issued by our internal CA (or a non-public one), we must provide the CA certificate to the `ClusterSecretStore` so ESO can trust the connection.

### C3. `ExternalSecret` CRD Deep Dive
- **`spec.secretStoreRef`:** Points to the `ClusterSecretStore`.
- **`spec.refreshInterval`:** A `time.Duration` string (e.g., `15s`, `10m`, `1h`).
    - Recommendation for Static KV: `1h` is fine.
    - Recommendation for Dynamic DB creds: Set this to half the lease TTL from OpenBao (e.g., if TTL is 30m, set `refreshInterval` to `15m`).
- **`spec.target.name`:** The name of the `v1.Secret` that will be created/managed.
- **`spec.target.template`:** Allows you to add custom `metadata` (labels, annotations) to the managed K8s `Secret`. This is useful for `stakater/reloader`.
- **`spec.data`:** Array defining what to fetch.
    - `secretKey`: The key name in the resulting K8s `Secret`.
    - `remoteRef.key`: The full path to the secret in OpenBao (e.g., `secret/data/grafana/oauth` or `database/creds/n8n-readwrite`).
    - `remoteRef.property`: The specific key within the fetched data. For KV v2, this is the key of the key-value pair. For dynamic DB creds, this could be `username` or `password`.
- **`spec.dataFrom`:** Fetches all key-value pairs from a remote secret. Good for secrets with multiple keys.

### C4. Pod Secret Reload Strategies
ESO does its job by updating the `v1.Secret` object. Getting the pod to *use* the new values is a separate problem.
- **Environment Variables:** Are immutable. The pod **must be restarted** to get new values.
- **Volume Mounts:** The mounted files are eventually updated by kubelet. The application needs to be programmed to periodically re-read the file from disk.
- **Recommended Solution: `stakater/reloader`**. This is a simple controller that watches for changes in `ConfigMap`s and `Secret`s. When a secret is updated by ESO, `reloader` can trigger a rolling update of the `Deployment`, `StatefulSet`, or `DaemonSet` that uses it. This is the most reliable way to ensure pods use fresh secrets.
    - **Usage:** Add an annotation to your deployment: `reloader.stakater.com/auto: "true"`.

---
## examples.md Content

### C2. The `ClusterSecretStore` for Helix Stax
This manifest is applied once to the cluster to configure the connection to OpenBao.
```yaml
# clustersecretstore-openbao.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: openbao-cluster-store
spec:
  provider:
    vault:
      # Our OpenBao service URL
      server: "https://bao.helixstax.net"
      # Path to the KV v2 engine
      path: "secret"
      version: "v2"
      # CA certificate to trust our internal OpenBao TLS.
      # This assumes you have a secret named `bao-ca` with a `ca.crt` key.
      caBundle: |
        LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCekNDQWU2Z0F3SUJBZ0lCQVRBTkJna3Foa2lHOXcwQkFRc0ZBREFvTVNBd0hRWURWUVFERXhaRlV6...
        ...
        LS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
      auth:
        # Use Kubernetes Service Account Token authentication
        kubernetes:
          mountPath: "kubernetes" # The path where K8s auth is enabled in OpenBao
          # The role created in OpenBao that binds ESO's SA to a policy
          role: "external-secrets"
          # The service account that ESO is running as
          serviceAccountRef:
            name: "external-secrets" # default name
            namespace: "external-secrets" # default namespace
```

### C3. Example `ExternalSecret` Manifests

**1. Grafana OIDC Client Secret (Simple KV)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-oidc
  namespace: monitoring
spec:
  secretStoreRef:
    name: openbao-cluster-store
    kind: ClusterSecretStore
  refreshInterval: "8h"
  target:
    name: grafana-oidc-secret
    # Annotation for stakater/reloader to restart Grafana when this secret changes
    template:
      metadata:
        annotations:
          reloader.stakater.com/search: "true"
  data:
    - secretKey: client-secret # Key in the final K8s Secret
      remoteRef:
        key: secret/data/grafana/oidc # Path in OpenBao
        property: client_secret # Key under that path
```

**2. Zitadel Dynamic DB Credentials (from CloudNativePG)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: zitadel-db-creds
  namespace: zitadel
spec:
  secretStoreRef:
    name: openbao-cluster-store
    kind: ClusterSecretStore
  # Match the refresh interval to the lease TTL from OpenBao
  refreshInterval: "5m"
  target:
    name: zitadel-db-connection
    creationPolicy: Owner
  data:
    # OpenBao's database engine returns a full connection string
    - secretKey: DSN
      remoteRef:
        # Request a new credential from the 'zitadel-app' role
        key: database/creds/zitadel-app
        property: connection_string # Property not needed, it's the main data
    # OR, get individual components
    - secretKey: DB_USER
      remoteRef:
        key: database/creds/zitadel-app
        
