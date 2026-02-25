#!/bin/bash
# compact-reinject.sh — Re-inject Marvin context after compaction
# Hook: SessionStart (matcher: compact)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
CLAUDE_DIR="$CLAUDE_PROJECT_DIR/.claude"

# Extract session metadata from hook input
MODEL=$(echo "$INPUT" | json_val '.model')
SESSION_ID=$(echo "$INPUT" | json_val '.session_id')

CONTEXT="POST-COMPACTION CONTEXT RECOVERY
Re-read .claude/CLAUDE.md now for your full instructions."

# Session metadata
if [ -n "$MODEL" ] || [ -n "$SESSION_ID" ]; then
  CONTEXT="${CONTEXT}
Session: model=${MODEL:-unknown}, id=${SESSION_ID:-unknown}
"
fi

# Append pre-compaction state if saved by pre-compact-save.sh
if [ -f "$CLAUDE_DIR/.pre-compact-state.json" ]; then
  CONTEXT="${CONTEXT}
PRE-COMPACTION STATE (saved before compaction):
$(cat "$CLAUDE_DIR/.pre-compact-state.json")"
fi

# Output JSON (jq preferred, python fallback)
if command -v jq &> /dev/null; then
  jq -n --arg ctx "$CONTEXT" --arg msg "Context compacted — Marvin memory restored." \
    '{additionalContext: $ctx, systemMessage: $msg}'
else
  python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1], 'systemMessage': sys.argv[2]}))" \
    "$CONTEXT" "Context compacted — Marvin memory restored."
fi

exit 0
