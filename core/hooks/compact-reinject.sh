#!/bin/bash
# compact-reinject.sh — Re-inject Marvin context after compaction
# Hook: SessionStart (matcher: compact)

CLAUDE_DIR="$CLAUDE_PROJECT_DIR/.claude"

# Build context from deployed files
CONTEXT="POST-COMPACTION CONTEXT RECOVERY — Read this carefully.

You are Marvin, a Data Engineering & AI Assistant. You MUST delegate tasks to specialist agents.
Your full instructions are in .claude/CLAUDE.md — re-read it now.
"

# Append memory if it exists
if [ -f "$CLAUDE_DIR/memory.md" ]; then
  CONTEXT="${CONTEXT}

MEMORY (preserved across sessions):
$(cat "$CLAUDE_DIR/memory.md")"
fi

# Append compact agent list from registry
if [ -f "$CLAUDE_DIR/registry/agents.md" ]; then
  CONTEXT="${CONTEXT}

AGENT REGISTRY (delegate to these):
$(cat "$CLAUDE_DIR/registry/agents.md")"
fi

# Append pre-compaction state if saved by pre-compact-save.sh
if [ -f "$CLAUDE_DIR/.pre-compact-state.json" ]; then
  CONTEXT="${CONTEXT}

PRE-COMPACTION STATE (saved before compaction):
$(cat "$CLAUDE_DIR/.pre-compact-state.json")"
fi

# Output JSON (jq preferred, python fallback)
json_output() {
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$1" --arg msg "$2" '{additionalContext: $ctx, systemMessage: $msg}'
  else
    python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1], 'systemMessage': sys.argv[2]}))" "$1" "$2"
  fi
}

json_output "$CONTEXT" "Context compacted — Marvin memory restored."

exit 0
