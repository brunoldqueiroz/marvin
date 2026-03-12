#!/usr/bin/env bash
# post-tool-use-mcp-monitor.sh — PostToolUse hook that detects MCP tool errors and logs them.
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

TOOL=$(echo "$INPUT" | json_val '.tool_name')
RESULT=$(echo "$INPUT" | json_val '.tool_result')

# Only monitor MCP tools (prefixed mcp__)
[[ "$TOOL" != mcp__* ]] && exit 0

# Detect error patterns: HTTP status codes, connection errors, auth errors
ERROR_MATCH=""
if echo "$RESULT" | grep -qiE '(40[0-9]|5[0-9]{2}).*(error|failed|unauthorized|forbidden|payment required)'; then
  ERROR_MATCH=$(echo "$RESULT" | grep -oiE '(40[0-9]|5[0-9]{2})[^"]{0,80}' | head -1)
elif echo "$RESULT" | grep -qiE 'connection refused|timeout|ECONNREFUSED|ETIMEDOUT'; then
  ERROR_MATCH="connection_error"
elif echo "$RESULT" | grep -qiE 'invalid.*api.?key|authentication failed|unauthorized'; then
  ERROR_MATCH="auth_error"
fi

[ -z "$ERROR_MATCH" ] && exit 0

# Log to unified metrics
SESSION=$(echo "$INPUT" | json_val '.session_id')
SERVER=$(echo "$TOOL" | cut -d'_' -f3)
{
  log_metric "$(printf '{"ts":"%s","event":"mcp_error","session":"%s","tool":"%s","server":"%s","error":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$TOOL" "$SERVER" "$ERROR_MATCH")"
} 2>/dev/null

# Surface to Claude (and therefore to the user)
echo "MCP tool '$TOOL' (server: $SERVER) returned error: $ERROR_MATCH. Check API key/billing for '$SERVER'." >&2
exit 0
