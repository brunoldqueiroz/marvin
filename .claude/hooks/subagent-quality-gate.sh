#!/bin/bash
# subagent-quality-gate.sh — Validate subagent output before accepting
# Hook: SubagentStop (matcher: "")
# Exit 2 = block (reason on stderr is fed to Claude)

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

LAST_MSG=$(echo "$INPUT" | json_val '.last_assistant_message')
AGENT_NAME=$(echo "$INPUT" | json_val '.agent_type' 2>/dev/null || echo "unknown")
AGENT_ID=$(echo "$INPUT" | json_val '.agent_id')
AGENT_TRANSCRIPT=$(echo "$INPUT" | json_val '.agent_transcript_path')
PERM_MODE=$(echo "$INPUT" | json_val '.permission_mode')

# --- Check for .artifacts/ output (filesystem handoff protocol) ---
HAS_ARTIFACT=false
ARTIFACT_DIR="${CLAUDE_PROJECT_DIR:-.}/.artifacts"
if [ -d "$ARTIFACT_DIR" ]; then
  RECENT=$(find "$ARTIFACT_DIR" -name "*.md" -mmin -5 2>/dev/null | head -1)
  [ -n "$RECENT" ] && HAS_ARTIFACT=true
fi

# --- Determine status for metrics ---
STATUS="pass"
if [ "$HAS_ARTIFACT" = false ]; then
  if [ -z "$LAST_MSG" ] || [ "${#LAST_MSG}" -lt 20 ]; then
    STATUS="blocked"
  elif echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|failed to\|error occurred\|no results found"; then
    STATUS="blocked"
  fi
else
  # Agent wrote artifact — only block on explicit failure signals
  if [ -n "$LAST_MSG" ] && echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|failed to\|error occurred\|no results found"; then
    STATUS="blocked"
  fi
fi

# --- Metrics logging (best-effort, never blocks) ---
{
  METRICS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/dev"
  mkdir -p "$METRICS_DIR" 2>/dev/null
  SESSION=$(echo "$INPUT" | json_val '.session_id' 2>/dev/null || echo "")
  OUTPUT_LEN=${#LAST_MSG}
  printf '{"ts":"%s","event":"subagent_stop","agent":"%s","agent_id":"%s","session":"%s","status":"%s","output_len":%d,"has_artifact":%s,"permission_mode":"%s","transcript":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT_NAME" "$AGENT_ID" "$SESSION" "$STATUS" "$OUTPUT_LEN" "$HAS_ARTIFACT" "$PERM_MODE" "$AGENT_TRANSCRIPT" \
    >> "$METRICS_DIR/metrics.jsonl"

  # Rotate: keep last 500 lines when exceeding 1000
  METRICS_FILE="$METRICS_DIR/metrics.jsonl"
  if [ -f "$METRICS_FILE" ]; then
    LINE_COUNT=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -gt 1000 ]; then
      tail -500 "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
    fi
  fi
} 2>/dev/null

# --- Quality gate ---
if [ "$STATUS" = "blocked" ]; then
  if [ -z "$LAST_MSG" ] || [ "${#LAST_MSG}" -lt 20 ]; then
    echo "Subagent returned empty or insufficient output. Retry with clearer instructions." >&2
  else
    echo "Subagent reported failure. Review the error and retry with adjusted parameters." >&2
  fi
  exit 2
fi

exit 0
