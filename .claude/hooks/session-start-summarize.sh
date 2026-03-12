#!/bin/bash
# session-start-summarize.sh — Summarize session history for Qdrant persistence
# Hook: SessionStart (matcher: startup)
# Philosophy: advisory (degrades gracefully — returns empty if conditions not met)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

THRESHOLD="${MARVIN_SUMMARIZE_INTERVAL:-5}"
SESSION_LOGS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/dev/session_logs"
MARKER="${CLAUDE_PROJECT_DIR:-.}/.claude/dev/.last-summarized"

# Bail out if session_logs directory does not exist
if [ ! -d "$SESSION_LOGS_DIR" ]; then
  exit 0
fi

# Count .log files (bounded — avoid reading every file at this stage)
LOG_COUNT=$(ls "$SESSION_LOGS_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')

if [ "$LOG_COUNT" -lt "$THRESHOLD" ]; then
  exit 0
fi

# Find the Nth-oldest log file (where N = THRESHOLD) to use as the batch boundary
# ls -t sorts newest-first; tail -n +N gives us from the Nth file onwards;
# head -1 takes the oldest in that set — the boundary of the current batch.
NTH_OLDEST=$(ls -t "$SESSION_LOGS_DIR"/*.log 2>/dev/null | tail -n +"$THRESHOLD" | head -1)

if [ -z "$NTH_OLDEST" ]; then
  exit 0
fi

# If the marker exists and is newer than the Nth-oldest log, this batch is
# already summarized — skip.
if [ -f "$MARKER" ] && [ "$MARKER" -nt "$NTH_OLDEST" ]; then
  exit 0
fi

# Collect data from all log files (sorted by name = chronological order)
ALL_LOGS=$(ls "$SESSION_LOGS_DIR"/*.log 2>/dev/null | sort)

# Extract unique branches (bounded head per file to avoid large reads)
BRANCHES=$(for f in $ALL_LOGS; do head -5 "$f" 2>/dev/null | grep '^branch:' | sed 's/^branch:[[:space:]]*//'; done | sort -u | tr '\n' ', ' | sed 's/,$//')

# Extract specs referenced (lines starting with working-on:)
SPECS=$(for f in $ALL_LOGS; do head -20 "$f" 2>/dev/null | grep '^working-on:' | sed 's/^working-on:[[:space:]]*//'; done | sort -u | tr '\n' ', ' | sed 's/,$//')

# Extract outcomes (lines starting with outcome:)
OUTCOMES=$(for f in $ALL_LOGS; do head -20 "$f" 2>/dev/null | grep '^outcome:' | sed 's/^outcome:[[:space:]]*//'; done | tr '\n' ', ' | sed 's/,$//')

# Count completed vs interrupted outcomes
COMPLETED=$(for f in $ALL_LOGS; do head -20 "$f" 2>/dev/null | grep '^outcome:' | grep -c 'completed\|done\|success' 2>/dev/null || true; done | awk '{s+=$1} END {print s+0}')
INTERRUPTED=$(for f in $ALL_LOGS; do head -20 "$f" 2>/dev/null | grep '^outcome:' | grep -c 'interrupted\|partial\|blocked' 2>/dev/null || true; done | awk '{s+=$1} END {print s+0}')

# Build the summary text
BRANCH_TEXT="${BRANCHES:-unknown}"
SPEC_TEXT="${SPECS:-none referenced}"

OUTCOME_TEXT=""
if [ "$COMPLETED" -gt 0 ] || [ "$INTERRUPTED" -gt 0 ]; then
  OUTCOME_TEXT=" Outcomes: ${COMPLETED} completed, ${INTERRUPTED} interrupted."
elif [ -n "$OUTCOMES" ]; then
  OUTCOME_TEXT=" Outcomes: ${OUTCOMES}."
fi

SUMMARY="SESSION HISTORY SUMMARY (last ${LOG_COUNT} sessions):
Worked on branch(es): ${BRANCH_TEXT}. Specs: ${SPEC_TEXT}.${OUTCOME_TEXT} Total sessions: ${LOG_COUNT}.

ACTION REQUIRED: Store this summary to Qdrant using qdrant-store with metadata: type=knowledge, domain=session-history, project=marvin, confidence=0.7"

# Output additionalContext JSON (same pattern as session-start-context.sh)
if command -v jq &> /dev/null; then
  jq -n --arg ctx "$SUMMARY" '{additionalContext: $ctx}'
else
  python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$SUMMARY"
fi

# Write the marker so we don't re-summarize this batch on the next startup
date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER" 2>/dev/null

exit 0
