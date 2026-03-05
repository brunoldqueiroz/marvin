#!/bin/bash
# subagent-stop-gate.sh — Validate subagent output before accepting
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

# --- Check for deterministic completion signal ---
LAST_LINE=$(echo "$LAST_MSG" | grep -v '^$' | tail -1)

if echo "$LAST_LINE" | grep -qE '^SIGNAL:(DONE|BLOCKED|PARTIAL)$'; then
  SIGNAL=$(echo "$LAST_LINE" | grep -oE 'SIGNAL:(DONE|BLOCKED|PARTIAL)')
  case "$SIGNAL" in
    SIGNAL:DONE)    exit 0 ;;
    SIGNAL:BLOCKED) echo "Agent reported: $SIGNAL" >&2; exit 2 ;;
    SIGNAL:PARTIAL) exit 0 ;;  # allow through, caller decides
  esac
fi

# --- Fallback: heuristic-based detection (backward compatibility) ---
STATUS="pass"
if [ "$HAS_ARTIFACT" = false ]; then
  if [ -z "$LAST_MSG" ] || [ "${#LAST_MSG}" -lt 20 ]; then
    STATUS="blocked"
  elif echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|no results found"; then
    STATUS="blocked"
  fi
else
  # Agent wrote artifact — only block on explicit failure signals
  if [ -n "$LAST_MSG" ] && echo "$LAST_MSG" | grep -qi "I could not\|I cannot\|I'm unable\|no results found"; then
    STATUS="blocked"
  fi
fi

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
