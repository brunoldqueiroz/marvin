#!/usr/bin/env bash
# subagent-start-log.sh — Log subagent spawn events
# Hook: SubagentStart (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

SESSION=$(echo "$INPUT" | json_val '.session_id')
AGENT_TYPE=$(echo "$INPUT" | json_val '.agent_type')
AGENT_ID=$(echo "$INPUT" | json_val '.agent_id')
CWD=$(echo "$INPUT" | json_val '.cwd')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')

[ -z "$AGENT_TYPE" ] && AGENT_TYPE="unknown"

{
  log_metric "$(printf '{"ts":"%s","event":"subagent_start","session":"%s","agent":"%s","agent_id":"%s","cwd":"%s","permission_mode":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$AGENT_TYPE" "$AGENT_ID" "$CWD" "$PERM_MODE")"
} 2>/dev/null

exit 0
