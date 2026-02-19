#!/bin/bash
# validate-dockerfile.sh — Lint Dockerfiles on write/edit
# Hook: PostToolUse (matcher: Write|Edit) — used by docker-expert agent

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

BASENAME=$(basename "$FILE_PATH")
if [[ "$BASENAME" == Dockerfile* ]] || [[ "$BASENAME" == *.dockerfile ]]; then
  if command -v hadolint &> /dev/null; then
    hadolint "$FILE_PATH" 2>/dev/null || true
  fi
fi
exit 0
