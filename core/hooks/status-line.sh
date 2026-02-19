#!/bin/bash
# status-line.sh — Custom status line for Claude Code terminal
# Shows Marvin branding and current git branch

BRANCH=""
if command -v git &> /dev/null && git -C "$CLAUDE_PROJECT_DIR" rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
  BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)
fi

if [ -n "$BRANCH" ]; then
  echo "Marvin | $BRANCH"
else
  echo "Marvin"
fi
