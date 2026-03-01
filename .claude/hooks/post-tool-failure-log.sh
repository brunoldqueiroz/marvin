#!/usr/bin/env bash
# post-tool-failure-log.sh — Log tool failure events
# Hook: PostToolUseFailure (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

TOOL=$(echo "$INPUT" | json_val '.tool_name')
SESSION=$(echo "$INPUT" | json_val '.session_id')
TOOL_ID=$(echo "$INPUT" | json_val '.tool_use_id')
ERROR=$(echo "$INPUT" | json_val '.error')
IS_INTERRUPT=$(echo "$INPUT" | json_val '.is_interrupt')

[ -z "$TOOL" ] && exit 0

# Sanitize error for JSON (escape quotes, truncate)
ERROR=$(printf '%s' "$ERROR" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g' | tr '"' "'" | head -c 200)
[ "$IS_INTERRUPT" != "true" ] && IS_INTERRUPT="false"

{
  log_metric "$(printf '{"ts":"%s","event":"tool_failure","session":"%s","tool":"%s","tool_id":"%s","error":"%s","is_interrupt":%s}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$TOOL" "$TOOL_ID" "$ERROR" "$IS_INTERRUPT")"
} 2>/dev/null

exit 0
