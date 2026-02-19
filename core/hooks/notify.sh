#!/bin/bash
# notify.sh — Desktop notification when Claude needs attention
# Hook: Notification

source "$(dirname "$0")/_lib.sh"

MESSAGE=$(cat | json_val '.message')
[ -z "$MESSAGE" ] && MESSAGE="Marvin needs your attention"

if command -v notify-send &> /dev/null; then
  # Linux
  notify-send "Marvin" "$MESSAGE" --icon=dialog-information 2>/dev/null
elif command -v osascript &> /dev/null; then
  # macOS
  osascript -e "display notification \"$MESSAGE\" with title \"Marvin\"" 2>/dev/null
elif command -v powershell.exe &> /dev/null; then
  # WSL/Windows
  powershell.exe -Command "[System.Windows.Forms.MessageBox]::Show('$MESSAGE','Marvin')" 2>/dev/null
fi
exit 0
