#!/bin/bash
# pre-tool-use-spec-freeze.sh — Warn on edits to shipped specs
# Hook: PreToolUse (matcher: Edit, Write)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | json_val '.tool_name')
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

case "$FILE_PATH" in
  */spec/shipped/*)
    { log_metric "{\"ts\":\"$(date -u +%FT%TZ)\",\"event\":\"spec_freeze_warning\",\"file\":\"$FILE_PATH\"}" ; } 2>/dev/null
    echo "WARNING: Editing shipped spec — consider writing a new spec instead." >&2
    exit 0
    ;;
esac

exit 0
