#!/bin/bash
# Run Gemini research prompts via OpenRouter API (Gemini CLI quota exhausted)
# Uses secrets-vault Worker for API key (no hardcoded secrets)
# Usage: bash scripts/gemini-research-openrouter.sh
# Runs 1 at a time (OpenRouter rate limits differ from Gemini)

PROMPTS_DIR="C:/Users/MSI LAPTOP/HelixStax/helix-stax-infrastructure/docs/gemini-skill-prompts"
FETCH_SECRET="$HOME/.claude/scripts/fetch-secret.sh"
MODEL="google/gemini-2.5-pro-preview"

# Fetch API key from vault
OPENROUTER_API_KEY=$(bash "$FETCH_SECRET" OPENROUTER_API_KEY 2>/dev/null)
if [ -z "$OPENROUTER_API_KEY" ] || [[ "$OPENROUTER_API_KEY" == ERROR* ]]; then
  echo "ERROR: Could not fetch OPENROUTER_API_KEY from vault"
  echo "  Run: cloudflared access login --app https://secrets-vault.helixstax.workers.dev"
  exit 1
fi
echo "API key fetched from vault (${#OPENROUTER_API_KEY} chars)"

# All 26 prompts (21 original + 5 new) — full fresh run
PROMPTS=(
  "01-edge-ingress/01-edge-ingress"
  "02-gitops-cicd/02-gitops-cicd"
  "03-iac-pipeline/03-iac-pipeline"
  "04-postgresql-stack/04-postgresql-stack"
  "05-cache-queue/05-cache-queue"
  "06-storage-chain/06-storage-chain"
  "07-identity/07-identity"
  "08-security-stack/08-security-stack"
  "09-secrets-pipeline/09-secrets-pipeline"
  "10-observability-metrics/10-observability-metrics"
  "11-logging-pipeline/11-logging-pipeline"
  "12-tracing-pipeline/12-tracing-pipeline"
  "13-internal-portals/13-internal-portals"
  "14-communication/14-communication"
  "15-backup-dr/15-backup-dr"
  "16-k8s-fundamentals/16-k8s-fundamentals"
  "17-infrastructure-base/17-infrastructure-base"
  "18-container-supply-chain/18-container-supply-chain"
  "19-ai-ml-stack/19-ai-ml-stack"
  "20-automation-website/20-automation-website"
  "21-integration-capstone/21-integration-capstone"
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

  if [ ! -f "$input" ]; then
    echo "    SKIP: $name -- input file not found"
    return 1
  fi

  # Force re-run all prompts (no skip logic)

  echo ">>> Running: $name ($(wc -l < "$input") input lines)"

  local prompt_content
  prompt_content=$(cat "$input")

  # Call OpenRouter API via Python (jq not available on Windows)
  local content
  content=$(PYTHONUTF8=1 python3 -c "
import json, urllib.request, sys

prompt = open(sys.argv[1], 'r', encoding='utf-8').read()
payload = json.dumps({
    'model': sys.argv[2],
    'max_tokens': 16000,
    'messages': [{'role': 'user', 'content': prompt}]
}).encode()

req = urllib.request.Request(
    'https://openrouter.ai/api/v1/chat/completions',
    data=payload,
    headers={
        'Authorization': 'Bearer ' + sys.argv[3],
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://helixstax.com',
        'X-Title': 'Helix Stax Research'
    }
)

try:
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
        text = data.get('choices', [{}])[0].get('message', {}).get('content', '')
        if text:
            print(text)
        else:
            print('ERROR: ' + json.dumps(data.get('error', 'empty response')), file=sys.stderr)
            sys.exit(1)
except Exception as e:
    print('ERROR: ' + str(e), file=sys.stderr)
    sys.exit(1)
" "$input" "$MODEL" "$OPENROUTER_API_KEY" 2>/tmp/openrouter_err.txt)

  if [ $? -ne 0 ] || [ -z "$content" ]; then
    local error
    error=$(cat /tmp/openrouter_err.txt 2>/dev/null)
    echo "    FAIL: $name -- ${error:-unknown error}"
    return 1
  fi

  echo "$content" > "$output"
  local lines=$(wc -l < "$output" 2>/dev/null || echo 0)

  if [ "$lines" -gt 50 ]; then
    echo "    DONE: $name ($lines lines)"
  else
    echo "    WARN: $name -- only $lines lines (may be truncated)"
  fi
}

echo "=== Gemini Deep Research via OpenRouter ==="
echo "=== Model: $MODEL ==="
echo "=== $(date) ==="
echo "=== ${#PROMPTS[@]} prompts to process ==="
echo ""

DONE=0
FAIL=0
SKIP=0

for prompt_path in "${PROMPTS[@]}"; do
  run_prompt "$prompt_path"
  result=$?
  if [ $result -eq 0 ]; then
    ((DONE++))
  else
    ((FAIL++))
  fi
  # Brief pause between requests
  sleep 5
done

echo ""
echo "=== FINAL STATUS ==="
for prompt_path in "${PROMPTS[@]}"; do
  name=$(basename "$prompt_path")
  output="$PROMPTS_DIR/${prompt_path}-research-output.md"
  lines=$(wc -l < "$output" 2>/dev/null || echo 0)
  if [ "$lines" -gt 50 ]; then
    printf "  OK   %-40s %5d lines\n" "$name" "$lines"
  else
    printf "  FAIL %-40s %5d lines\n" "$name" "$lines"
  fi
done

echo ""
echo "=== Done: $DONE succeeded, $FAIL failed ==="
