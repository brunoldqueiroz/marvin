#!/bin/bash
# session-persist.sh — Persist session state on stop (Orient→Work→Persist cycle)
# Hook: Stop (matcher: "")
#
# Captures a lightweight session summary to changes/session-log.md so the next
# session can orient quickly. Runs alongside stop-quality-gate.sh.

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Skip if no project directory
[ -z "$CLAUDE_PROJECT_DIR" ] && exit 0

CHANGES_DIR="$CLAUDE_PROJECT_DIR/changes"
LOG_FILE="$CHANGES_DIR/session-log.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Gather git state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | head -20)
RECENT_COMMITS=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 --since="8 hours ago" 2>/dev/null)

# Gather task state (if changes/tasks.md exists)
TASKS_FILE="$CLAUDE_PROJECT_DIR/changes/tasks.md"
PENDING=""
DONE=""
if [ -f "$TASKS_FILE" ]; then
  PENDING=$(grep -c '^\- \[ \]' "$TASKS_FILE" 2>/dev/null || echo "0")
  DONE=$(grep -c '^\- \[x\]' "$TASKS_FILE" 2>/dev/null || echo "0")
fi

# Build session entry
ENTRY="## Session: $TIMESTAMP (branch: $BRANCH)

### Commits This Session
${RECENT_COMMITS:-No commits in the last 8 hours.}
"

if [ -f "$TASKS_FILE" ]; then
  ENTRY="$ENTRY
### Task Progress
- Done: $DONE
- Pending: $PENDING
"
fi

if [ -n "$DIRTY" ]; then
  ENTRY="$ENTRY
### Uncommitted Changes
\`\`\`
$DIRTY
\`\`\`
"
fi

ENTRY="$ENTRY---
"

# Write to log (create changes/ dir if needed)
mkdir -p "$CHANGES_DIR"

if [ -f "$LOG_FILE" ]; then
  # Prepend new entry (most recent first)
  EXISTING=$(cat "$LOG_FILE")
  printf '%s\n\n%s\n' "# Session Log" "$ENTRY" > "$LOG_FILE"
  # Append previous entries (skip the old header)
  echo "$EXISTING" | sed '1{/^# Session Log$/d;}' | sed '/^$/N;/^\n$/d' >> "$LOG_FILE"
else
  printf '%s\n\n%s\n' "# Session Log" "$ENTRY" > "$LOG_FILE"
fi

# Keep only the last 10 sessions to prevent unbounded growth
if [ -f "$LOG_FILE" ]; then
  SESSION_COUNT=$(grep -c '^## Session:' "$LOG_FILE" 2>/dev/null || echo "0")
  if [ "$SESSION_COUNT" -gt 10 ]; then
    # Keep header + first 10 session blocks
    python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
count = 0
cutoff = None
for i, line in enumerate(lines):
    if line.startswith('## Session:'):
        count += 1
        if count > 10:
            cutoff = i
            break
if cutoff:
    with open(sys.argv[1], 'w') as f:
        f.writelines(lines[:cutoff])
" "$LOG_FILE" 2>/dev/null
  fi
fi

exit 0
