#!/bin/bash
# validate-sql.sh — Auto-lint and fix SQL files on write/edit
# Hook: PostToolUse (matcher: Write|Edit)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.sql ]]; then
  if command -v sqlfluff &> /dev/null; then
    sqlfluff fix --force --no-color "$FILE_PATH" 2>/dev/null
  elif command -v sqlfmt &> /dev/null; then
    sqlfmt "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
