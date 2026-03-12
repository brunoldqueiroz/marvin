#!/bin/bash
# stop-persist.sh — Persist session state on stop (Orient→Work→Persist cycle)
# Hook: Stop (matcher: "")
# Failure philosophy: fail-open — every new extraction is guarded; log what
# we can and skip what we cannot.
#
# Writes a raw text log to .claude/dev/session_logs/{timestamp}.log
# for the next session's Orient phase. Fields written:
#   session, time, branch, mode, duration (FR-04), outcome (FR-05),
#   commits, uncommitted, working-on (FR-01), recent-files (FR-01).

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
STOP_REASON=$(echo "$INPUT" | json_val '.stop_reason')

# Git state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | head -20)
RECENT_COMMITS=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 --since="8 hours ago" 2>/dev/null)

# FR-04 — Session duration: find last session_start in metrics.jsonl
METRICS_FILE="$CLAUDE_PROJECT_DIR/.claude/dev/metrics.jsonl"
DURATION=""
if [ -f "$METRICS_FILE" ]; then
  SESSION_START_TS=$(grep '"event":"session_start"' "$METRICS_FILE" 2>/dev/null | tail -1 | grep -o '"ts":"[^"]*"' | sed 's/"ts":"//;s/"//')
  if [ -n "$SESSION_START_TS" ]; then
    START_EPOCH=$(date -d "$SESSION_START_TS" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SESSION_START_TS" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    if [ -n "$START_EPOCH" ] && [ -n "$NOW_EPOCH" ]; then
      DURATION_SECS=$(( NOW_EPOCH - START_EPOCH ))
      DURATION="$(( DURATION_SECS / 60 ))m"
    fi
  fi
fi

# FR-05 — Session outcome: classify stop_reason
OUTCOME="completed"
if [ -n "$STOP_REASON" ]; then
  case "$STOP_REASON" in
    *interrupt*|*cancel*)
      OUTCOME="interrupted"
      ;;
    *)
      OUTCOME="completed"
      ;;
  esac
fi

# FR-01 — Active spec detection: scan for recently modified tasks.md
WORKING_ON=""
if [ -d "$CLAUDE_PROJECT_DIR/.specify/specs" ]; then
  ACTIVE_TASKS=$(find "$CLAUDE_PROJECT_DIR/.specify/specs" -name "tasks.md" -mmin -60 2>/dev/null | head -1)
  if [ -n "$ACTIVE_TASKS" ]; then
    SPEC_ID=$(echo "$ACTIVE_TASKS" | sed 's|.*/specs/||;s|/tasks.md||')
    TASKS_DONE=$(grep -c '^\[x\]' "$ACTIVE_TASKS" 2>/dev/null || echo "0")
    TASKS_PENDING=$(grep -c '^\[ \]' "$ACTIVE_TASKS" 2>/dev/null || echo "0")
    TASKS_TOTAL=$(( TASKS_DONE + TASKS_PENDING ))
    if [ "$TASKS_TOTAL" -gt 0 ]; then
      WORKING_ON="${SPEC_ID} (${TASKS_DONE}/${TASKS_TOTAL} tasks done)"
    else
      WORKING_ON="${SPEC_ID}"
    fi
  fi
fi

# FR-01 — Recent files: extract from last 50 lines of metrics.jsonl
RECENT_FILES=""
if [ -f "$METRICS_FILE" ]; then
  RECENT_FILES=$(tail -50 "$METRICS_FILE" 2>/dev/null | grep -o '"file":"[^"]*"' | sed 's/"file":"//;s/"//' | sort -u | tr '\n' ',' | sed 's/,$//')
fi

# Write raw log
{
  echo "session: ${SESSION_ID}"
  echo "time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch: ${BRANCH}"
  echo "mode: ${PERM_MODE}"
  [ -n "$DURATION" ] && echo "duration: ${DURATION}"
  echo "outcome: ${OUTCOME}"
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

  [ -n "$WORKING_ON" ] && echo "working-on: ${WORKING_ON}" && echo ""
  [ -n "$RECENT_FILES" ] && echo "recent-files: ${RECENT_FILES}" && echo ""
} > "$LOG_FILE"

# Keep only the last 10 session logs
ls -t "$LOGS_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null

exit 0
