#!/usr/bin/env bash
# =============================================================================
# Cloudflare Zero Trust — Finalize GitHub IdP (Step 2 completion)
#
# Run this AFTER creating the GitHub OAuth App manually.
# This script:
#   1. Creates the GitHub IdP in Cloudflare
#   2. Updates the Helix Admin group to use GitHub identity
#   3. Updates all apps to prefer GitHub login
#   4. Stores the IdP ID in OpenBao
#
# Usage:
#   GITHUB_OAUTH_CLIENT_ID=xxx GITHUB_OAUTH_CLIENT_SECRET=yyy \
#     bash cloudflare-finalize-github-idp.sh
# =============================================================================

set -euo pipefail

CF_ACCOUNT_ID="57046d4890f574ed90c545f51acb67d8"
CF_EMAIL="contact@wakeemwilliams.com"
CF_API_KEY="${CF_API_KEY:-4d517afe4af727e03b389e3ad07c37686d2a9}"
CF_API="https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access"
GROUP_ID="c882b341-c992-43e0-8fc7-e0fc535d2bcf"
GITHUB_USERNAME="KeemWilliams"

# App IDs
APP_IDS=(
  "15621520-f811-453b-bafd-9b5a319e171b"
  "810e0c62-1a65-4496-8d9f-fc4661ff15b9"
  "1c789bd2-a838-496b-a29c-2c0ddaf5bc39"
  "aae4fc4b-1ea2-4152-9f23-c6e5ec09981a"
  "74dbe868-b8dd-4b0f-a9d2-4533751563a5"
  "ce4391fa-75c3-47a0-b040-0cb381bc2d56"
)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $1"; }
err() { echo -e "${RED}[x]${NC} $1"; exit 1; }

if [ -z "${GITHUB_OAUTH_CLIENT_ID:-}" ] || [ -z "${GITHUB_OAUTH_CLIENT_SECRET:-}" ]; then
  echo "Create the OAuth App first:"
  echo "  https://github.com/settings/developers -> New OAuth App"
  echo "  Name: Helix Stax Cloudflare Access"
  echo "  Homepage: https://helixstax.com"
  echo "  Callback: https://helix-hub-tunnel.cloudflareaccess.com/cdn-cgi/access/callback"
  echo ""
  read -rp "GitHub OAuth Client ID: " GITHUB_OAUTH_CLIENT_ID
  read -rp "GitHub OAuth Client Secret: " GITHUB_OAUTH_CLIENT_SECRET
fi

[ -z "$GITHUB_OAUTH_CLIENT_ID" ] && err "Client ID required"
[ -z "$GITHUB_OAUTH_CLIENT_SECRET" ] && err "Client Secret required"

# 1. Create GitHub IdP
log "Creating GitHub Identity Provider..."
IDP_RESPONSE=$(curl -s -X POST "${CF_API}/identity_providers" \
  -H "X-Auth-Email: ${CF_EMAIL}" \
  -H "X-Auth-Key: ${CF_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"github\",
    \"name\": \"GitHub\",
    \"config\": {
      \"client_id\": \"${GITHUB_OAUTH_CLIENT_ID}\",
      \"client_secret\": \"${GITHUB_OAUTH_CLIENT_SECRET}\"
    }
  }")

echo "$IDP_RESPONSE" | grep -q '"success":true' || { echo "$IDP_RESPONSE"; err "IdP creation failed"; }
IDP_ID=$(echo "$IDP_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
log "GitHub IdP created: ${IDP_ID}"

# 2. Update Helix Admin group to use GitHub identity
log "Updating Helix Admin group to use GitHub identity..."
GROUP_RESPONSE=$(curl -s -X PUT "${CF_API}/groups/${GROUP_ID}" \
  -H "X-Auth-Email: ${CF_EMAIL}" \
  -H "X-Auth-Key: ${CF_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Helix Admin\",
    \"include\": [
      {
        \"github\": {
          \"identity_provider_id\": \"${IDP_ID}\",
          \"name\": \"${GITHUB_USERNAME}\"
        }
      },
      {
        \"email\": {
          \"email\": \"contact@wakeemwilliams.com\"
        }
      }
    ]
  }")
echo "$GROUP_RESPONSE" | grep -q '"success":true' || { echo "$GROUP_RESPONSE"; err "Group update failed"; }
log "Group updated with GitHub identity rule"

# 3. Update all apps to prefer GitHub IdP
log "Updating apps to prefer GitHub login..."
for APP_ID in "${APP_IDS[@]}"; do
  curl -s -X PUT "${CF_API}/apps/${APP_ID}" \
    -H "X-Auth-Email: ${CF_EMAIL}" \
    -H "X-Auth-Key: ${CF_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"allowed_idps\": [\"${IDP_ID}\"]}" > /dev/null
done
log "All apps updated"

# 4. Store in OpenBao
log "Storing IdP ID in OpenBao..."
ssh -i ~/.ssh/helixstax_key -p 2222 -o StrictHostKeyChecking=no root@5.78.145.30 "
docker exec -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN=s.a49U2pWMP1r2M49biFaJPmSG openbao bao kv patch secret/cloudflare-zero-trust \
  github_idp_id=\"${IDP_ID}\" \
  github_oauth_client_id=\"${GITHUB_OAUTH_CLIENT_ID}\" \
  idp_status=ACTIVE
" 2>/dev/null && log "Stored in OpenBao" || echo "(OpenBao storage skipped — update manually)"

echo ""
echo "Done! GitHub IdP is now active."
echo "IdP ID: ${IDP_ID}"
echo "Test login: https://helix-hub-tunnel.cloudflareaccess.com"
