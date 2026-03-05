#!/bin/bash
# session-start-reinject.sh — Re-inject Marvin context after compaction
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
  STATE_FILE="$CLAUDE_DIR/.pre-compact-state.json"

  # Extract fields for human-readable format
  S_BRANCH=$(cat "$STATE_FILE" | json_val '.git_branch')
  S_DIRTY=$(cat "$STATE_FILE" | json_val '.dirty_files')
  S_DIRTY_LIST=$(cat "$STATE_FILE" | json_val '.dirty_list' 2>/dev/null)
  S_COMMITS=$(cat "$STATE_FILE" | json_val '.recent_commits' 2>/dev/null)
  S_SPEC=$(cat "$STATE_FILE" | json_val '.active_spec' 2>/dev/null)
  S_FILES=$(cat "$STATE_FILE" | json_val '.recent_files' 2>/dev/null)
  S_TOOLS=$(cat "$STATE_FILE" | json_val '.recent_tools' 2>/dev/null)

  STATE_TEXT="PRE-COMPACTION STATE:
Branch: ${S_BRANCH:-unknown} (${S_DIRTY:-0} dirty"
  [ -n "$S_DIRTY_LIST" ] && [ "$S_DIRTY_LIST" != "null" ] && STATE_TEXT="${STATE_TEXT}: ${S_DIRTY_LIST}"
  STATE_TEXT="${STATE_TEXT})"
  [ -n "$S_COMMITS" ] && [ "$S_COMMITS" != "null" ] && STATE_TEXT="${STATE_TEXT}
Recent commits: ${S_COMMITS}"
  [ -n "$S_SPEC" ] && [ "$S_SPEC" != "null" ] && [ -n "$S_SPEC" ] && STATE_TEXT="${STATE_TEXT}
Working on: spec ${S_SPEC}"
  [ -n "$S_FILES" ] && [ "$S_FILES" != "null" ] && STATE_TEXT="${STATE_TEXT}
Recently editing: ${S_FILES}"
  [ -n "$S_TOOLS" ] && [ "$S_TOOLS" != "null" ] && STATE_TEXT="${STATE_TEXT}
Recent tools: ${S_TOOLS}"

  CONTEXT="${CONTEXT}
${STATE_TEXT}"
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
