#!/bin/bash
# session-context.sh — Inject project context on session start
# Hook: SessionStart (matcher: startup)

CONTEXT=""

# Git context
if command -v git &> /dev/null && git -C "$CLAUDE_PROJECT_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
  BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)
  RECENT=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 2>/dev/null)
  DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  CONTEXT="Git: branch=${BRANCH}, ${DIRTY} uncommitted files
Recent commits:
${RECENT}"
fi

if [ -n "$CONTEXT" ]; then
  # Output JSON (jq preferred, python fallback)
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
  else
    python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$CONTEXT"
  fi
fi

exit 0
