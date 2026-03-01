#!/bin/bash
# stop-persist.sh — Persist session state on stop (Orient→Work→Persist cycle)
# Hook: Stop (matcher: "")
#
# Writes a raw text log to .claude/dev/session_logs/{timestamp}.log
# for the next session's Orient phase.

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Skip if no project directory
[ -z "$CLAUDE_PROJECT_DIR" ] && exit 0

LOGS_DIR="$CLAUDE_PROJECT_DIR/.claude/dev/session_logs"
mkdir -p "$LOGS_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOGS_DIR/${TIMESTAMP}.log"

# Extract fields from hook input
SESSION_ID=$(echo "$INPUT" | json_val '.session_id')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')
TRANSCRIPT_PATH=$(echo "$INPUT" | json_val '.transcript_path')

# Git state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | head -20)
RECENT_COMMITS=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 --since="8 hours ago" 2>/dev/null)

# Write raw log
{
  echo "session: ${SESSION_ID}"
  echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch: ${BRANCH}"
  echo "mode: ${PERM_MODE}"
  [ -n "$TRANSCRIPT_PATH" ] && echo "transcript: ${TRANSCRIPT_PATH}"
  echo ""

  if [ -n "$RECENT_COMMITS" ]; then
    echo "commits:"
    echo "$RECENT_COMMITS"
    echo ""
  fi

  if [ -n "$DIRTY" ]; then
    echo "uncommitted:"
    echo "$DIRTY"
    echo ""
  fi
} > "$LOG_FILE"

# Keep only the last 10 session logs
ls -t "$LOGS_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null

exit 0
