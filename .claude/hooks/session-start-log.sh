#!/bin/bash
# session-start-log.sh — Record session start metrics
# Hook: SessionStart (matcher: startup)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Extract session metadata
MODEL=$(echo "$INPUT" | json_val '.model')
SOURCE=$(echo "$INPUT" | json_val '.source')
SESSION_ID=$(echo "$INPUT" | json_val '.session_id')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')

# Log session_start metric
{
  log_metric "$(printf '{"ts":"%s","event":"session_start","session":"%s","model":"%s","source":"%s","permission_mode":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$MODEL" "${SOURCE:-startup}" "$PERM_MODE")"
} 2>/dev/null

exit 0
