#!/bin/bash
# subagent-quality-gate.sh — Validate subagent output before accepting
# Hook: SubagentStop (matcher: "")
# Exit 2 = block (reason on stderr is fed to Claude)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

LAST_MSG=$(echo "$INPUT" | json_val '.last_assistant_message')

# If empty or very short output, block
if [ -z "$LAST_MSG" ] || [ "${#LAST_MSG}" -lt 20 ]; then
  echo "Subagent returned empty or insufficient output. Retry with clearer instructions." >&2
  exit 2
fi

# Check for explicit failure signals
if echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|failed to\|error occurred\|no results found"; then
  echo "Subagent reported failure. Review the error and retry with adjusted parameters." >&2
  exit 2
fi

exit 0
