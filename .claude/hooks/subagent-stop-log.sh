#!/bin/bash
# subagent-stop-log.sh — Log subagent stop metrics
# Hook: SubagentStop (matcher: "")

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

LAST_MSG=$(echo "$INPUT" | json_val '.last_assistant_message')
AGENT_NAME=$(echo "$INPUT" | json_val '.agent_type' 2>/dev/null || echo "unknown")
AGENT_ID=$(echo "$INPUT" | json_val '.agent_id')
AGENT_TRANSCRIPT=$(echo "$INPUT" | json_val '.agent_transcript_path')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')

# Determine status (mirrors gate logic for accurate metrics)
HAS_ARTIFACT=false
ARTIFACT_DIR="${CLAUDE_PROJECT_DIR:-.}/.artifacts"
if [ -d "$ARTIFACT_DIR" ]; then
  RECENT=$(find "$ARTIFACT_DIR" -name "*.md" -mmin -5 2>/dev/null | head -1)
  [ -n "$RECENT" ] && HAS_ARTIFACT=true
fi

STATUS="pass"
if [ "$HAS_ARTIFACT" = false ]; then
  if [ -z "$LAST_MSG" ] || [ "${#LAST_MSG}" -lt 20 ]; then
    STATUS="blocked"
  elif echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|failed to\|error occurred\|no results found"; then
    STATUS="blocked"
  fi
else
  if [ -n "$LAST_MSG" ] && echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|failed to\|error occurred\|no results found"; then
    STATUS="blocked"
  fi
fi

# Log metrics (best-effort, never blocks)
{
  SESSION=$(echo "$INPUT" | json_val '.session_id' 2>/dev/null || echo "")
  OUTPUT_LEN=${#LAST_MSG}
  CWD=$(echo "$INPUT" | json_val '.cwd' 2>/dev/null || echo "")
  log_metric "$(printf '{"ts":"%s","event":"subagent_stop","agent":"%s","agent_id":"%s","session":"%s","status":"%s","output_len":%d,"has_artifact":%s,"cwd":"%s","permission_mode":"%s","transcript":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT_NAME" "$AGENT_ID" "$SESSION" "$STATUS" "$OUTPUT_LEN" "$HAS_ARTIFACT" "$CWD" "$PERM_MODE" "$AGENT_TRANSCRIPT")"
} 2>/dev/null

exit 0
