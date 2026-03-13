#!/bin/bash
# pre-tool-use-block-claude-config.sh — Block writes to .claude/ config without approval
# Hook: PreToolUse (matcher: Write, Edit)
# Philosophy: fail-closed
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | json_val '.tool_name')
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

# Only check Write and Edit tools
case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

# No file path — nothing to check
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Protected paths inside .claude/
PROTECTED_PATTERNS=(
  "agents/*/AGENT.md"
  "hooks/*.sh"
  "settings*.json"
  "rules/*.md"
)

# Normalize to relative path inside .claude/
REL_PATH=""
if echo "$FILE_PATH" | grep -q '\.claude/'; then
  REL_PATH=$(echo "$FILE_PATH" | sed 's|.*\.claude/||')
fi

# Not inside .claude/ — allow
if [ -z "$REL_PATH" ]; then
  exit 0
fi

# CLAUDE.md itself is allowed (we edit it regularly)
case "$REL_PATH" in
  CLAUDE.md) exit 0 ;;
esac

# Check against protected patterns
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  case "$REL_PATH" in
    $pattern)
      echo "BLOCKED: Writing to .claude/$REL_PATH requires explicit user approval. Consult @docs/development-standard.md before modifying agents, hooks, rules, or settings." >&2
      exit 2
      ;;
  esac
done

exit 0
