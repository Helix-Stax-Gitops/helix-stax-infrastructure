#!/usr/bin/env bash
# =============================================================================
# Cloudflare Zero Trust — Step 2 & 3 Setup
# Sets up GitHub IdP, Access Group, Access Applications, and policies
#
# Prerequisites:
#   1. GitHub OAuth App created at https://github.com/settings/developers
#      - App name: "Helix Stax Cloudflare Access"
#      - Homepage URL: https://helixstax.com
#      - Callback URL: https://helix-hub-tunnel.cloudflareaccess.com/cdn-cgi/access/callback
#   2. Cloudflare API key available
#
# Usage:
#   GITHUB_OAUTH_CLIENT_ID=xxx GITHUB_OAUTH_CLIENT_SECRET=yyy bash cloudflare-zero-trust-setup.sh
#
# Or run interactively (will prompt for credentials)
# =============================================================================

set -euo pipefail

# --- Configuration ---
CF_ACCOUNT_ID="57046d4890f574ed90c545f51acb67d8"
CF_EMAIL="contact@wakeemwilliams.com"
CF_API_KEY="${CF_API_KEY:-4d517afe4af727e03b389e3ad07c37686d2a9}"
CF_API="https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access"
TEAM_DOMAIN="helix-hub-tunnel"
GITHUB_USERNAME="KeemWilliams"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; exit 1; }

cf_curl() {
  local method="$1" endpoint="$2" data="${3:-}"
  local args=(-s -X "$method" "${CF_API}${endpoint}" \
    -H "X-Auth-Email: ${CF_EMAIL}" \
    -H "X-Auth-Key: ${CF_API_KEY}" \
    -H "Content-Type: application/json")
  [ -n "$data" ] && args+=(-d "$data")
  curl "${args[@]}"
}

check_success() {
  local response="$1" label="$2"
  local success
  success=$(echo "$response" | grep -o '"success":true' || true)
  if [ -z "$success" ]; then
    echo "$response"
    err "Failed: ${label}"
  fi
}

extract_id() {
  local response="$1"
  echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# --- Get GitHub OAuth credentials ---
if [ -z "${GITHUB_OAUTH_CLIENT_ID:-}" ] || [ -z "${GITHUB_OAUTH_CLIENT_SECRET:-}" ]; then
  warn "GitHub OAuth App credentials not provided via environment."
  echo ""
  echo "Create a GitHub OAuth App first:"
  echo "  1. Go to https://github.com/settings/developers"
  echo "  2. Click 'New OAuth App'"
  echo "  3. Fill in:"
  echo "     - Application name: Helix Stax Cloudflare Access"
  echo "     - Homepage URL: https://helixstax.com"
  echo "     - Authorization callback URL: https://${TEAM_DOMAIN}.cloudflareaccess.com/cdn-cgi/access/callback"
  echo "  4. Click 'Register application'"
  echo "  5. Copy the Client ID"
  echo "  6. Click 'Generate a new client secret' and copy it"
  echo ""
  read -rp "GitHub OAuth Client ID: " GITHUB_OAUTH_CLIENT_ID
  read -rp "GitHub OAuth Client Secret: " GITHUB_OAUTH_CLIENT_SECRET
fi

[ -z "$GITHUB_OAUTH_CLIENT_ID" ] && err "Client ID is required"
[ -z "$GITHUB_OAUTH_CLIENT_SECRET" ] && err "Client Secret is required"

echo ""
echo "=============================="
echo " Cloudflare Zero Trust Setup"
echo "=============================="
echo ""

# =============================================================================
# STEP 2: GitHub Identity Provider
# =============================================================================
log "Creating GitHub Identity Provider..."

IDP_RESPONSE=$(cf_curl POST "/identity_providers" "{
  \"type\": \"github\",
  \"name\": \"GitHub\",
  \"config\": {
    \"client_id\": \"${GITHUB_OAUTH_CLIENT_ID}\",
    \"client_secret\": \"${GITHUB_OAUTH_CLIENT_SECRET}\"
  }
}")
check_success "$IDP_RESPONSE" "GitHub IdP creation"
IDP_ID=$(extract_id "$IDP_RESPONSE")
log "GitHub IdP created: ${IDP_ID}"

# =============================================================================
# STEP 3a: Access Group — Helix Admin
# =============================================================================
log "Creating Access Group: Helix Admin..."

GROUP_RESPONSE=$(cf_curl POST "/groups" "{
  \"name\": \"Helix Admin\",
  \"include\": [
    {
      \"github\": {
        \"identity_provider_id\": \"${IDP_ID}\",
        \"name\": \"${GITHUB_USERNAME}\"
      }
    }
  ]
}")
check_success "$GROUP_RESPONSE" "Access Group creation"
GROUP_ID=$(extract_id "$GROUP_RESPONSE")
log "Access Group 'Helix Admin' created: ${GROUP_ID}"

# =============================================================================
# STEP 3b: Access Applications + Policies
# =============================================================================

# Application definitions: name|hostname|session_duration
APPS=(
  "Vaultwarden|vault.helixstax.net|1h"
  "OpenBao|bao.helixstax.net|1h"
  "Harbor|harbor.helixstax.net|24h"
  "MinIO Console|minio.helixstax.net|24h"
  "Postal UI|postal.helixstax.net|24h"
  "SSH Browser|ssh-vps.helixstax.net|1h"
)

declare -A APP_IDS

for app_def in "${APPS[@]}"; do
  IFS='|' read -r app_name app_hostname app_session <<< "$app_def"

  log "Creating Access Application: ${app_name} (${app_hostname})..."

  APP_RESPONSE=$(cf_curl POST "/apps" "{
    \"name\": \"${app_name}\",
    \"domain\": \"${app_hostname}\",
    \"type\": \"self_hosted\",
    \"session_duration\": \"${app_session}\",
    \"auto_redirect_to_identity\": true,
    \"allowed_idps\": [\"${IDP_ID}\"],
    \"app_launcher_visible\": true
  }")
  check_success "$APP_RESPONSE" "App creation: ${app_name}"
  APP_ID=$(extract_id "$APP_RESPONSE")
  APP_IDS["${app_name}"]="${APP_ID}"
  log "  App created: ${APP_ID}"

  # Create Allow policy for Helix Admin group
  log "  Creating Allow policy for ${app_name}..."
  POLICY_RESPONSE=$(cf_curl POST "/apps/${APP_ID}/policies" "{
    \"name\": \"Allow Helix Admin\",
    \"decision\": \"allow\",
    \"include\": [
      {
        \"group\": {
          \"id\": \"${GROUP_ID}\"
        }
      }
    ],
    \"precedence\": 1
  }")
  check_success "$POLICY_RESPONSE" "Policy creation for ${app_name}"
  POLICY_ID=$(extract_id "$POLICY_RESPONSE")
  log "  Policy created: ${POLICY_ID}"
done

# =============================================================================
# STEP 3c: Service Auth Policies (for service tokens)
# =============================================================================

# Harbor needs service auth for K3s image pulls
log "Creating Service Auth policy for Harbor (harbor-k3s-pull)..."
HARBOR_SVC_POLICY=$(cf_curl POST "/apps/${APP_IDS["Harbor"]}/policies" "{
  \"name\": \"K3s Image Pull (Service Token)\",
  \"decision\": \"non_identity\",
  \"include\": [
    {
      \"service_token\": {
        \"token_id\": \"5ddee19d-e0d9-4925-9ffe-4dc7cb65363e\"
      }
    }
  ],
  \"precedence\": 2
}")
check_success "$HARBOR_SVC_POLICY" "Harbor service auth policy"
log "  Harbor service auth policy created"

# MinIO needs service auth for K3s app access
log "Creating Service Auth policy for MinIO (minio-k3s-access)..."
MINIO_SVC_POLICY=$(cf_curl POST "/apps/${APP_IDS["MinIO Console"]}/policies" "{
  \"name\": \"K3s MinIO Access (Service Token)\",
  \"decision\": \"non_identity\",
  \"include\": [
    {
      \"service_token\": {
        \"token_id\": \"c10d94e7-b12f-468a-ae64-725f1962e891\"
      }
    }
  ],
  \"precedence\": 2
}")
check_success "$MINIO_SVC_POLICY" "MinIO service auth policy"
log "  MinIO service auth policy created"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================="
echo " Setup Complete!"
echo "=============================="
echo ""
echo "Team Domain: ${TEAM_DOMAIN}.cloudflareaccess.com"
echo "GitHub IdP ID: ${IDP_ID}"
echo "Access Group (Helix Admin): ${GROUP_ID}"
echo ""
echo "Access Applications:"
for app_def in "${APPS[@]}"; do
  IFS='|' read -r app_name app_hostname app_session <<< "$app_def"
  echo "  ${app_name} (${app_hostname}): ${APP_IDS[${app_name}]}"
done
echo ""
echo "Service Tokens (already created):"
echo "  harbor-k3s-pull: 770a92254a2642f4b1f28602c110fbf0.access"
echo "  minio-k3s-access: 5837ded8cade20c11975be0652e9f046.access"
echo ""
echo "Login URL: https://${TEAM_DOMAIN}.cloudflareaccess.com"
echo ""
echo "NOTE: DNS records still need to be configured (Wave 3)."
echo "      Services won't be reachable until DNS points to the tunnel."
