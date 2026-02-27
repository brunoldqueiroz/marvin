#!/bin/bash
# block-secrets.sh — Prevent commands that might expose secrets
# Hook: PreToolUse (matcher: Bash)
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | json_val '.tool_input.command')

PATTERNS=(
  "cat.*\.env"
  "cat.*credentials"
  "cat.*\.pem"
  "echo.*API_KEY"
  "echo.*SECRET"
  "echo.*PASSWORD"
  "echo.*TOKEN"
  "curl.*token="
  "curl.*password="
  "printenv.*KEY"
  "printenv.*SECRET"
  "printenv.*TOKEN"
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: Command may expose secrets — '$COMMAND'" >&2
    exit 2
  fi
done
exit 0
