#!/bin/bash
# session-persist.sh — Persist session state on stop (Orient→Work→Persist cycle)
# Hook: Stop (matcher: "")
#
# Reads the session transcript JSONL to extract a structured summary:
# user prompts, tools used, files modified, git commits.
# Writes to changes/session-log.md for the next session's Orient phase.

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

# Skip if no project directory
[ -z "$CLAUDE_PROJECT_DIR" ] && exit 0

CHANGES_DIR="$CLAUDE_PROJECT_DIR/changes"
LOG_FILE="$CHANGES_DIR/session-log.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Extract transcript path and session ID from hook input
TRANSCRIPT_PATH=$(echo "$INPUT" | json_val '.transcript_path')
SESSION_ID=$(echo "$INPUT" | json_val '.session_id')

# Git state
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | head -20)
RECENT_COMMITS=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 --since="8 hours ago" 2>/dev/null)

# Task state
TASKS_FILE="$CLAUDE_PROJECT_DIR/changes/tasks.md"
TASK_SUMMARY=""
if [ -f "$TASKS_FILE" ]; then
  PENDING=$(grep -c '^\- \[ \]' "$TASKS_FILE" 2>/dev/null || echo "0")
  DONE=$(grep -c '^\- \[x\]' "$TASKS_FILE" 2>/dev/null || echo "0")
  TASK_SUMMARY="- Done: $DONE | Pending: $PENDING"
fi

# Parse transcript if available
USER_PROMPTS=""
TOOL_SUMMARY=""
FILES_TOUCHED=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_DATA=$(TRANSCRIPT_FILE="$TRANSCRIPT_PATH" python3 << 'PYEOF' 2>/dev/null
import json, os
from collections import Counter

transcript_path = os.environ["TRANSCRIPT_FILE"]
user_prompts = []
tool_counts = Counter()
files_written = set()
files_read = set()

with open(transcript_path) as f:
    for line in f:
        try:
            obj = json.loads(line.strip())
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type", "")
        msg = obj.get("message", {})

        # Extract user prompts (skip tool_result messages)
        if msg_type == "user":
            content = msg if isinstance(msg, str) else msg.get("content", "")
            if isinstance(content, str) and len(content.strip()) > 5:
                # Truncate long prompts
                text = content.strip().split("\n")[0][:120]
                user_prompts.append(text)
            elif isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "text":
                        text = c["text"].strip()
                        if len(text) > 5:
                            user_prompts.append(text.split("\n")[0][:120])

        # Extract tool usage and file paths
        if msg_type == "assistant" and isinstance(msg, dict):
            content = msg.get("content", [])
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "tool_use":
                        tool_name = c.get("name", "")
                        tool_counts[tool_name] += 1
                        inp = c.get("input", {})
                        fp = inp.get("file_path", "")
                        if fp:
                            if tool_name in ("Write", "Edit"):
                                files_written.add(fp)
                            elif tool_name == "Read":
                                files_read.add(fp)

output = []

# User prompts
if user_prompts:
    output.append("### User Prompts")
    for i, p in enumerate(user_prompts, 1):
        output.append(f"{i}. {p}")
    output.append("")

# Tool usage
if tool_counts:
    output.append("### Tools Used")
    for tool, count in tool_counts.most_common():
        output.append(f"- {tool}: {count}x")
    output.append("")

# Files modified
if files_written:
    output.append("### Files Modified")
    # Show paths relative to project dir if possible
    for fp in sorted(files_written):
        output.append(f"- {fp}")
    output.append("")

print("\n".join(output))
PYEOF
)
fi

# Build session entry
ENTRY="## Session: $TIMESTAMP (branch: $BRANCH)
"

if [ -n "$SESSION_ID" ]; then
  ENTRY="${ENTRY}
Session ID: \`${SESSION_ID}\`
"
fi

if [ -n "$TRANSCRIPT_DATA" ]; then
  ENTRY="${ENTRY}
${TRANSCRIPT_DATA}"
fi

if [ -n "$RECENT_COMMITS" ]; then
  ENTRY="${ENTRY}
### Commits
${RECENT_COMMITS}
"
fi

if [ -n "$TASK_SUMMARY" ]; then
  ENTRY="${ENTRY}
### Tasks
${TASK_SUMMARY}
"
fi

if [ -n "$DIRTY" ]; then
  ENTRY="${ENTRY}
### Uncommitted Changes
\`\`\`
${DIRTY}
\`\`\`
"
fi

ENTRY="${ENTRY}---
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
SESSION_COUNT=$(grep -c '^## Session:' "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$SESSION_COUNT" -gt 10 ]; then
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

exit 0
