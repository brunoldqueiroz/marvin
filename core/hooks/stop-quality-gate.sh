#!/bin/bash
# stop-quality-gate.sh — Quality gate: check delegation before stopping
# Hook: Stop (matcher: "")
# Exit 2 = block (reason on stderr is fed to Claude)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Prevent infinite loops: if hook already fired once, allow stop
HOOK_ACTIVE=$(echo "$INPUT" | json_val '.stop_hook_active')
if [ "$HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

LAST_MSG=$(echo "$INPUT" | json_val '.last_assistant_message')

# If message is short (greetings, confirmations), allow
if [ "${#LAST_MSG}" -lt 100 ]; then
  exit 0
fi

# Check if Task tool was used (delegation happened)
if echo "$LAST_MSG" | grep -qi "Task\|delegat\|handoff\|subagent"; then
  exit 0
fi

# Check for specialist domain keywords without delegation
DOMAINS="dbt\|spark\|airflow\|snowflake\|terraform\|docker\|pipeline\|DAG\|warehouse"
if echo "$LAST_MSG" | grep -qi "$DOMAINS"; then
  echo "Specialist domain detected without delegation. Use the Task tool to delegate to the appropriate agent." >&2
  exit 2
fi

exit 0
