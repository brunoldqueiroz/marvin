#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

TOOL=$(echo "$INPUT" | json_val '.tool_name')
SESSION=$(echo "$INPUT" | json_val '.session_id')

[ -z "$TOOL" ] && exit 0

LOGDIR="${CLAUDE_PROJECT_DIR:-.}/.claude/dev/tool-logs"
mkdir -p "$LOGDIR"

echo "$(date -Iseconds) $TOOL" >> "$LOGDIR/${SESSION:-unknown}.log"
