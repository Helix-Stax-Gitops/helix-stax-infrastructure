#!/bin/bash
# OpenTofu wrapper — fetches secrets from Cloudflare vault before apply
# Usage: bash opentofu/scripts/tofu-apply.sh [plan|apply|destroy|init]
# Default action: plan (safe — shows changes without applying)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOFU_DIR="$(dirname "$SCRIPT_DIR")"
FETCH_SECRET="$HOME/.claude/scripts/fetch-secret.sh"
ACTION="${1:-plan}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Helix Stax OpenTofu — $ACTION ===${NC}"
echo ""

# --- Fetch secrets from vault ---
echo -e "${YELLOW}Fetching secrets from vault...${NC}"

fetch_or_fail() {
  local name="$1"
  local value
  value=$(bash "$FETCH_SECRET" "$name" 2>/dev/null)
  if [ -z "$value" ] || [[ "$value" == *"ERROR"* ]]; then
    echo -e "${RED}FAILED: Could not fetch $name${NC}"
    echo "  Run: cloudflared access login --app https://secrets-vault.helixstax.workers.dev"
    exit 1
  fi
  echo "  $name [loaded]" >&2
  # NOTE: value is returned via stdout for subshell capture — never echo the raw value
  printf '%s' "$value"
}

export TF_VAR_hcloud_token=$(fetch_or_fail HETZNER_CLOUD_TOKEN)
export TF_VAR_cloudflare_api_token=$(fetch_or_fail CLOUDFLARE_API_TOKEN)
export TF_VAR_cloudflare_zone_id_com=$(fetch_or_fail CLOUDFLARE_ZONE_ID_COM)
export TF_VAR_cloudflare_zone_id_net=$(fetch_or_fail CLOUDFLARE_ZONE_ID_NET)

echo -e "${GREEN}Secrets loaded.${NC}"
echo ""

# --- SSH public key (local file, not a secret) ---
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
if [ -f "$SSH_KEY_PATH" ]; then
  export TF_VAR_ssh_public_key=$(cat "$SSH_KEY_PATH")
  echo "SSH public key: $SSH_KEY_PATH"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
  export TF_VAR_ssh_public_key=$(cat "$HOME/.ssh/id_rsa.pub")
  echo "SSH public key: $HOME/.ssh/id_rsa.pub"
else
  echo -e "${RED}No SSH public key found at ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub${NC}"
  exit 1
fi
echo ""

# --- Run OpenTofu ---
cd "$TOFU_DIR"

case "$ACTION" in
  init)
    echo -e "${YELLOW}Running: tofu init${NC}"
    tofu init
    ;;
  plan)
    echo -e "${YELLOW}Running: tofu plan${NC}"
    tofu plan
    ;;
  apply)
    echo -e "${YELLOW}Running: tofu plan (preview)${NC}"
    tofu plan -out=tfplan
    echo ""
    echo -e "${RED}Review the plan above. Apply? (yes/no)${NC}"
    read -r confirm
    if [ "$confirm" = "yes" ]; then
      tofu apply tfplan
      rm -f tfplan
    else
      echo "Aborted."
      rm -f tfplan
      exit 0
    fi
    ;;
  destroy)
    echo -e "${RED}=== DESTROY MODE ===${NC}"
    echo -e "${RED}This will destroy infrastructure. Are you sure? (type 'destroy' to confirm)${NC}"
    read -r confirm
    if [ "$confirm" = "destroy" ]; then
      tofu destroy
    else
      echo "Aborted."
      exit 0
    fi
    ;;
  output)
    tofu output "$@"
    ;;
  validate)
    tofu validate
    ;;
  fmt)
    tofu fmt -recursive
    ;;
  *)
    echo "Usage: $0 [init|plan|apply|destroy|output|validate|fmt]"
    echo "  init      — Initialize providers and backend"
    echo "  plan      — Show what would change (default, safe)"
    echo "  apply     — Plan + confirm + apply changes"
    echo "  destroy   — Destroy infrastructure (requires confirmation)"
    echo "  output    — Show outputs"
    echo "  validate  — Check configuration syntax"
    echo "  fmt       — Format .tf files"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Done.${NC}"
