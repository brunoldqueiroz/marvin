#!/bin/bash
# session-context.sh — Inject project context on session start
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
SESSION_LOG="$CLAUDE_PROJECT_DIR/.claude/dev/session-log.md"
if [ -f "$SESSION_LOG" ]; then
  # Extract the most recent session entry (between first and second ## Session:)
  LAST_SESSION=$(sed -n '/^## Session:/,/^## Session:/{ /^## Session:/!{/^## Session:/!p}; }' "$SESSION_LOG" | head -20)
  if [ -n "$LAST_SESSION" ]; then
    CONTEXT="${CONTEXT}

Previous session:
${LAST_SESSION}"
  fi
fi

# Save model to shared state for session-persist.sh to read at Stop
if [ -n "$MODEL" ] && [ -n "$CLAUDE_PROJECT_DIR" ]; then
  mkdir -p "$CLAUDE_PROJECT_DIR/.claude/dev" 2>/dev/null
  echo "$MODEL" > "$CLAUDE_PROJECT_DIR/.claude/dev/.session-model" 2>/dev/null
fi

# Log session_start metric
{
  PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')
  log_metric "$(printf '{"ts":"%s","event":"session_start","session":"%s","model":"%s","source":"%s","permission_mode":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$MODEL" "${SOURCE:-startup}" "$PERM_MODE")"
} 2>/dev/null

if [ -n "$CONTEXT" ]; then
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
  else
    python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$CONTEXT"
  fi
fi

exit 0
