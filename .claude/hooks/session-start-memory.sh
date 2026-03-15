#!/bin/bash
# session-start-memory.sh — Inject MEMORY.md index into session context
# Hook: SessionStart (matcher: startup)
# Philosophy: advisory (degrades gracefully — returns empty if file missing)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

MEMORY_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/MEMORY.md"

# Bail if MEMORY.md does not exist — fail-open
if [ ! -f "$MEMORY_FILE" ]; then
  exit 0
fi

# Read MEMORY.md content (cap at 200 lines per spec)
CONTENT=$(head -200 "$MEMORY_FILE" 2>/dev/null)

if [ -z "$CONTENT" ]; then
  exit 0
fi

# Output additionalContext JSON
if command -v jq &> /dev/null; then
  jq -n --arg ctx "$CONTENT" '{additionalContext: $ctx}'
else
  python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$CONTENT"
fi

exit 0
