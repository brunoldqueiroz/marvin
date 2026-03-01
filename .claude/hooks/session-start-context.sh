#!/bin/bash
# session-start-context.sh — Inject project context on session start
# Hook: SessionStart (matcher: startup)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Extract session metadata from hook input
MODEL=$(echo "$INPUT" | json_val '.model')
SOURCE=$(echo "$INPUT" | json_val '.source')
SESSION_ID=$(echo "$INPUT" | json_val '.session_id')

CONTEXT=""

# Session metadata
if [ -n "$MODEL" ] || [ -n "$SOURCE" ]; then
  CONTEXT="Session: source=${SOURCE:-startup}, model=${MODEL:-unknown}"
fi

# Git context
if command -v git &> /dev/null && git -C "$CLAUDE_PROJECT_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
  BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)
  RECENT=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 2>/dev/null)
  DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  CONTEXT="${CONTEXT}
Git: branch=${BRANCH}, ${DIRTY} uncommitted files
Recent commits:
${RECENT}"
fi

# Previous session context (Orient phase of Orient→Work→Persist)
SESSION_LOGS_DIR="$CLAUDE_PROJECT_DIR/.claude/dev/session_logs"
if [ -d "$SESSION_LOGS_DIR" ]; then
  LATEST_LOG=$(ls -t "$SESSION_LOGS_DIR"/*.log 2>/dev/null | head -1)
  if [ -n "$LATEST_LOG" ]; then
    LAST_SESSION=$(head -20 "$LATEST_LOG")
    if [ -n "$LAST_SESSION" ]; then
      CONTEXT="${CONTEXT}

Previous session:
${LAST_SESSION}"
    fi
  fi
fi

if [ -n "$CONTEXT" ]; then
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
  else
    python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$CONTEXT"
  fi
fi

exit 0
