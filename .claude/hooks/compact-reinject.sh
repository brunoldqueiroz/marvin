#!/bin/bash
# compact-reinject.sh — Re-inject Marvin context after compaction
# Hook: SessionStart (matcher: compact)

CLAUDE_DIR="$CLAUDE_PROJECT_DIR/.claude"

CONTEXT="POST-COMPACTION CONTEXT RECOVERY — Read this carefully.

You are Marvin, a Data Engineering & AI Assistant. You delegate research tasks to specialist agents.
Your full instructions are in .claude/CLAUDE.md — re-read it now.
"

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
