#!/bin/bash
# pre-compact-save.sh — Save critical context before compaction
# Hook: PreCompact (matcher: "")
#
# Cannot block compaction. Saves a snapshot of the current session state
# so compact-reinject.sh can restore it after compaction.

INPUT=$(cat)
CLAUDE_DIR="$CLAUDE_PROJECT_DIR/.claude"
SAVE_FILE="$CLAUDE_DIR/.pre-compact-state.json"

TRIGGER=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('trigger','unknown'))" 2>/dev/null)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Gather current state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Save state for post-compaction recovery
if command -v jq &> /dev/null; then
  jq -n \
    --arg ts "$TIMESTAMP" \
    --arg trigger "$TRIGGER" \
    --arg branch "$BRANCH" \
    --arg dirty "$DIRTY" \
    '{
      saved_at: $ts,
      trigger: $trigger,
      git_branch: $branch,
      dirty_files: ($dirty | tonumber)
    }' > "$SAVE_FILE"
else
  python3 -c "
import json, sys
state = {
    'saved_at': sys.argv[1],
    'trigger': sys.argv[2],
    'git_branch': sys.argv[3],
    'dirty_files': int(sys.argv[4])
}
with open(sys.argv[5], 'w') as f:
    json.dump(state, f, indent=2)
" "$TIMESTAMP" "$TRIGGER" "$BRANCH" "$DIRTY" "$SAVE_FILE"
fi

exit 0
