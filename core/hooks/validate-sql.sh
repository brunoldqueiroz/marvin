#!/bin/bash
# validate-sql.sh — Auto-lint and fix SQL files on write/edit
# Hook: PostToolUse (matcher: Write|Edit)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

if [[ "$FILE_PATH" == *.sql ]]; then
  if command -v sqlfluff &> /dev/null; then
    sqlfluff fix --force --no-color "$FILE_PATH" 2>/dev/null
  elif command -v sqlfmt &> /dev/null; then
    sqlfmt "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
