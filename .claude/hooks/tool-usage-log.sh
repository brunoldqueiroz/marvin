#!/usr/bin/env bash
# tool-usage-log.sh — Log tool usage events as JSONL
# Hook: PostToolUse (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

TOOL=$(echo "$INPUT" | json_val '.tool_name')
SESSION=$(echo "$INPUT" | json_val '.session_id')

[ -z "$TOOL" ] && exit 0

TOOL_ID=$(echo "$INPUT" | json_val '.tool_use_id')

# Extract tool-specific fields
FILE=""
CMD=""
SKILL=""
case "$TOOL" in
  Write|Edit|Read)
    FILE=$(echo "$INPUT" | json_val '.tool_input.file_path')
    ;;
  Bash)
    CMD=$(echo "$INPUT" | json_val '.tool_input.command' | head -c 100 | tr '"' "'")
    ;;
  Skill)
    SKILL=$(echo "$INPUT" | json_val '.tool_input.skill')
    ;;
esac

{
  log_metric "$(printf '{"ts":"%s","event":"tool_use","session":"%s","tool":"%s","tool_id":"%s","file":"%s","cmd":"%s","skill":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$TOOL" "$TOOL_ID" "$FILE" "$CMD" "$SKILL")"
} 2>/dev/null
