#!/bin/bash
# pre-compact-save.sh — Save critical context before compaction
# Hook: PreCompact (matcher: "")
#
# Cannot block compaction. Saves a snapshot of the current session state
# so compact-reinject.sh can restore it after compaction.

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
CLAUDE_DIR="$CLAUDE_PROJECT_DIR/.claude"
SAVE_FILE="$CLAUDE_DIR/.pre-compact-state.json"

TRIGGER=$(echo "$INPUT" | json_val '.trigger')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Gather current state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
DIRTY_LIST=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | head -10 | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
RECENT_COMMITS=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 --since="2 hours ago" 2>/dev/null | tr '\n' '|' | sed 's/|$//')

# Collect recent tools and files from metrics
METRICS_FILE="$CLAUDE_DIR/dev/metrics.jsonl"
RECENT_TOOLS=""
RECENT_FILES=""
if [ -f "$METRICS_FILE" ]; then
  RECENT_TOOLS=$(tail -20 "$METRICS_FILE" 2>/dev/null | grep -o '"tool":"[^"]*"' | sed 's/"tool":"//;s/"//' | sort -u | tr '\n' ',' | sed 's/,$//')
  RECENT_FILES=$(tail -20 "$METRICS_FILE" 2>/dev/null | grep -o '"file":"[^"]*"' | sed 's/"file":"//;s/"//' | sort -u | tr '\n' ',' | sed 's/,$//')
fi

# Detect active spec
ACTIVE_SPEC=""
if [ -d "$CLAUDE_PROJECT_DIR/.specify/specs" ]; then
  ACTIVE_SPEC=$(find "$CLAUDE_PROJECT_DIR/.specify/specs" -name "tasks.md" -mmin -30 2>/dev/null | head -1 | sed 's|.*/specs/||;s|/tasks.md||')
fi

# Save state for post-compaction recovery
if command -v jq &> /dev/null; then
  jq -n \
    --arg ts "$TIMESTAMP" \
    --arg trigger "$TRIGGER" \
    --arg branch "$BRANCH" \
    --arg dirty "$DIRTY" \
    --arg dirty_list "$DIRTY_LIST" \
    --arg recent_commits "$RECENT_COMMITS" \
    --arg recent_tools "$RECENT_TOOLS" \
    --arg recent_files "$RECENT_FILES" \
    --arg active_spec "$ACTIVE_SPEC" \
    '{
      saved_at: $ts,
      trigger: $trigger,
      git_branch: $branch,
      dirty_files: ($dirty | tonumber),
      dirty_list: ($dirty_list | split(",")),
      recent_commits: ($recent_commits | split("|")),
      recent_tools: ($recent_tools | split(",")),
      recent_files: ($recent_files | split(",")),
      active_spec: $active_spec
    }' > "$SAVE_FILE"
else
  python3 -c "
import json, sys
state = {
    'saved_at': sys.argv[1],
    'trigger': sys.argv[2],
    'git_branch': sys.argv[3],
    'dirty_files': int(sys.argv[4]),
    'dirty_list': [x for x in sys.argv[5].split(',') if x],
    'recent_commits': [x for x in sys.argv[6].split('|') if x],
    'recent_tools': [x for x in sys.argv[7].split(',') if x],
    'recent_files': [x for x in sys.argv[8].split(',') if x],
    'active_spec': sys.argv[9]
}
with open(sys.argv[10], 'w') as f:
    json.dump(state, f, indent=2)
" "$TIMESTAMP" "$TRIGGER" "$BRANCH" "$DIRTY" "$DIRTY_LIST" "$RECENT_COMMITS" "$RECENT_TOOLS" "$RECENT_FILES" "$ACTIVE_SPEC" "$SAVE_FILE"
fi

exit 0
