#!/bin/bash
# pre-tool-use-block-partial-read.sh — Block partial reads of critical config files
# Hook: PreToolUse (matcher: Read)
# Philosophy: fail-closed
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')
OFFSET=$(echo "$INPUT" | json_val '.tool_input.offset')
LIMIT=$(echo "$INPUT" | json_val '.tool_input.limit')

# Only check if offset or limit are set (partial read)
if [ -z "$OFFSET" ] && [ -z "$LIMIT" ]; then
  exit 0
fi

# Protected patterns (relative to project root)
PROTECTED_PATTERNS=(
  "CLAUDE.md"
  "rules/*.md"
  "settings*.json"
  "agents/*/AGENT.md"
  "skills/*/SKILL.md"
)

# Normalize file path to be relative to .claude/
REL_PATH=""
if echo "$FILE_PATH" | grep -q '\.claude/'; then
  REL_PATH=$(echo "$FILE_PATH" | sed 's|.*\.claude/||')
elif echo "$FILE_PATH" | grep -q '\.claude$'; then
  REL_PATH=$(basename "$FILE_PATH")
fi

# No match if not inside .claude/
if [ -z "$REL_PATH" ]; then
  exit 0
fi

# Check against protected patterns
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # Use bash pattern matching with fnmatch-style via case
  case "$REL_PATH" in
    $pattern)
      echo "Partial read (offset=$OFFSET, limit=$LIMIT) blocked for critical file: $REL_PATH. Read the full file to avoid editing with incomplete context." >&2
      exit 2
      ;;
  esac
done

exit 0
