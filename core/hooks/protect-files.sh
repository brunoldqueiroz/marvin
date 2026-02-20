#!/bin/bash
# protect-files.sh — Block edits to sensitive files
# Hook: PreToolUse (matcher: Edit|Write)
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

PROTECTED=(
  ".env"
  ".env.local"
  ".env.production"
  "credentials"
  ".pem"
  ".key"
  "package-lock.json"
  "yarn.lock"
  "uv.lock"
  "poetry.lock"
)

for pattern in "${PROTECTED[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    # Allow .example template files (they contain placeholders, not real secrets)
    if [[ "$FILE_PATH" == *.example ]]; then
      continue
    fi
    echo "BLOCKED: Cannot edit protected file '$FILE_PATH' (matched '$pattern')" >&2
    exit 2
  fi
done

exit 0
