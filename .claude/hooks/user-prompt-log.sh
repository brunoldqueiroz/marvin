#!/usr/bin/env bash
# user-prompt-log.sh — Log user prompt submissions
# Hook: UserPromptSubmit (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

SESSION=$(echo "$INPUT" | json_val '.session_id')
PROMPT=$(echo "$INPUT" | json_val '.prompt')

[ -z "$PROMPT" ] && exit 0

# Sanitize and truncate for JSON embedding
PROMPT=$(printf '%s' "$PROMPT" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g' | tr '"' "'" | head -c 200)
PROMPT_LEN=${#PROMPT}

{
  log_metric "$(printf '{"ts":"%s","event":"user_prompt","session":"%s","prompt":"%s","prompt_len":%d}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$PROMPT" "$PROMPT_LEN")"
} 2>/dev/null

exit 0
