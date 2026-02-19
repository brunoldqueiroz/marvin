#!/bin/bash
# tool-failure-context.sh — Provide remediation context on tool failures
# Hook: PostToolUseFailure (matcher: "")
#
# Cannot block (tool already failed). Injects helpful context so Claude
# can recover instead of retrying blindly.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
ERROR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error',''))" 2>/dev/null)

CONTEXT=""

case "$TOOL_NAME" in
  Bash)
    if echo "$ERROR" | grep -qi "command not found"; then
      CONTEXT="A command was not found. Check if the tool is installed or use an alternative approach."
    elif echo "$ERROR" | grep -qi "permission denied"; then
      CONTEXT="Permission denied. Check file permissions or if sudo is needed (but avoid sudo in hooks)."
    elif echo "$ERROR" | grep -qi "No such file or directory"; then
      CONTEXT="File or directory not found. Verify the path exists before retrying."
    fi
    ;;
  Edit|Write)
    if echo "$ERROR" | grep -qi "not unique"; then
      CONTEXT="Edit failed: old_string not unique. Provide more surrounding context to make the match unique."
    elif echo "$ERROR" | grep -qi "not found"; then
      CONTEXT="Edit failed: old_string not found in file. Re-read the file to get current content before editing."
    fi
    ;;
esac

# Only output if we have useful context
if [ -n "$CONTEXT" ]; then
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$CONTEXT" '{hookSpecificOutput: {hookEventName: "PostToolUseFailure", additionalContext: $ctx}}'
  else
    python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUseFailure', 'additionalContext': sys.argv[1]}}))" "$CONTEXT"
  fi
fi

exit 0
