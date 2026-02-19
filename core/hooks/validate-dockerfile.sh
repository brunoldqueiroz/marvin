#!/bin/bash
# validate-dockerfile.sh — Lint Dockerfiles on write/edit
# Hook: PostToolUse (matcher: Write|Edit) — used by docker-expert agent

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

BASENAME=$(basename "$FILE_PATH")
if [[ "$BASENAME" == Dockerfile* ]] || [[ "$BASENAME" == *.dockerfile ]]; then
  if command -v hadolint &> /dev/null; then
    hadolint "$FILE_PATH" 2>/dev/null || true
  fi
fi
exit 0
