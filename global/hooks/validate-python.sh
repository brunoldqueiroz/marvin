#!/bin/bash
# validate-python.sh — Auto-format Python files on write/edit
# Hook: PostToolUse (matcher: Write|Edit)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.py ]]; then
  if command -v ruff &> /dev/null; then
    ruff format "$FILE_PATH" 2>/dev/null
    ruff check --fix "$FILE_PATH" 2>/dev/null
  elif command -v black &> /dev/null; then
    black --quiet "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
