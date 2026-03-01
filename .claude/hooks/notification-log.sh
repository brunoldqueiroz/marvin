#!/usr/bin/env bash
# notification-log.sh — Log notification events (idle, permission prompts)
# Hook: Notification (matcher: "")
source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)

SESSION=$(echo "$INPUT" | json_val '.session_id')
NOTIF_TYPE=$(echo "$INPUT" | json_val '.notification_type')

[ -z "$NOTIF_TYPE" ] && NOTIF_TYPE="unknown"

{
  log_metric "$(printf '{"ts":"%s","event":"notification","session":"%s","notification_type":"%s"}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$NOTIF_TYPE")"
} 2>/dev/null

exit 0
