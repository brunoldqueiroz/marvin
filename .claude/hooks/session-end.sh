#!/usr/bin/env bash
# session-end.sh — Log session_end event
# Hook: SessionEnd (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

SESSION=$(echo "$INPUT" | json_val '.session_id')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')

# Determine reason from available fields
REASON=$(echo "$INPUT" | json_val '.reason')
[ -z "$REASON" ] && REASON="other"

{
  log_metric "$(printf '{"ts":"%s","event":"session_end","session":"%s","reason":"%s","permission_mode":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$REASON" "$PERM_MODE")"
} 2>/dev/null

exit 0
