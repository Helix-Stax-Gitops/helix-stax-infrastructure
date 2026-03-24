#!/bin/bash
# Re-run Gemini deep research prompts (14 failed + 5 new = 19 total)
# Updated: 2026-03-23 — prompts 01,07,14,18,20 fixed; 22-26 added
# Usage: bash scripts/gemini-research-rerun.sh
# Runs 2 at a time with 30s delay between batches to avoid quota burnout

PROMPTS_DIR="C:/Users/MSI LAPTOP/HelixStax/helix-stax-infrastructure/docs/gemini-skill-prompts"

# 14 previously failed (empty/truncated output) + 5 new prompts
PROMPTS=(
  # --- Previously failed (fixed where needed) ---
  "01-edge-ingress/01-edge-ingress"
  "03-iac-pipeline/03-iac-pipeline"
  "07-identity/07-identity"
  "08-security-stack/08-security-stack"
  "09-secrets-pipeline/09-secrets-pipeline"
  "10-observability-metrics/10-observability-metrics"
  "12-tracing-pipeline/12-tracing-pipeline"
  "13-internal-portals/13-internal-portals"
  "14-communication/14-communication"
  "15-backup-dr/15-backup-dr"
  "18-container-supply-chain/18-container-supply-chain"
  "19-ai-ml-stack/19-ai-ml-stack"
  "20-automation-website/20-automation-website"
  "21-integration-capstone/21-integration-capstone"
  # --- New prompts (server rebuild + Ansible) ---
  "22-cis-almalinux9/22-cis-almalinux9"
  "23-k3s-almalinux9/23-k3s-almalinux9"
  "24-molecule-testing/24-molecule-testing"
  "25-hetzner-cloud-api/25-hetzner-cloud-api"
  "26-opentofu-hetzner/26-opentofu-hetzner"
)

run_prompt() {
  local prompt_path="$1"
  local name=$(basename "$prompt_path")
  local input="$PROMPTS_DIR/${prompt_path}.md"
  local output="$PROMPTS_DIR/${prompt_path}-research-output.md"

  echo ">>> Running: $name"
  cat "$input" | gemini -p "" -m gemini-2.5-pro -o text 2>/dev/null > "$output"
  local exit_code=$?
  local lines=$(wc -l < "$output" 2>/dev/null || echo 0)

  if [ $exit_code -eq 0 ] && [ "$lines" -gt 50 ]; then
    echo "    DONE: $name ($lines lines)"
  elif [ "$lines" -gt 50 ]; then
    echo "    WARN: $name exit=$exit_code but got $lines lines (likely OK)"
  else
    echo "    FAIL: $name exit=$exit_code ($lines lines) -- may need retry"
  fi
}

echo "=== Gemini Deep Research Re-run ==="
echo "=== $(date) ==="
echo "=== ${#PROMPTS[@]} prompts to process ==="
echo ""

# Run in pairs with delay between batches
for ((i=0; i<${#PROMPTS[@]}; i+=2)); do
  # Run up to 2 in parallel
  run_prompt "${PROMPTS[$i]}" &
  pid1=$!

  if [ $((i+1)) -lt ${#PROMPTS[@]} ]; then
    run_prompt "${PROMPTS[$((i+1))]}" &
    pid2=$!
    wait $pid1 $pid2
  else
    wait $pid1
  fi

  echo "--- Batch done. Waiting 30s before next batch ---"
  sleep 30
done

echo ""
echo "=== FINAL STATUS ==="
for prompt_path in "${PROMPTS[@]}"; do
  name=$(basename "$prompt_path")
  output="$PROMPTS_DIR/${prompt_path}-research-output.md"
  lines=$(wc -l < "$output" 2>/dev/null || echo 0)
  if [ "$lines" -gt 50 ]; then
    printf "  OK  %-35s %5d lines\n" "$name" "$lines"
  else
    printf "  FAIL %-35s %5d lines\n" "$name" "$lines"
  fi
done
