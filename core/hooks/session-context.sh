#!/bin/bash
# session-context.sh — Inject project context on session start
# Hook: SessionStart (matcher: startup)

CONTEXT=""

# Git context
if command -v git &> /dev/null && git -C "$CLAUDE_PROJECT_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
  BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)
  RECENT=$(git -C "$CLAUDE_PROJECT_DIR" log --oneline -5 2>/dev/null)
  DIRTY=$(git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  CONTEXT="Git: branch=${BRANCH}, ${DIRTY} uncommitted files
Recent commits:
${RECENT}"

  # Worktree detection
  GIT_DIR=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-dir 2>/dev/null)
  GIT_COMMON=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
  if [ "$GIT_DIR" != "$GIT_COMMON" ]; then
    # We are inside a linked worktree
    MAIN_WORKTREE=$(git -C "$CLAUDE_PROJECT_DIR" worktree list --porcelain | head -1 | sed 's/^worktree //')
    WORKTREE_COUNT=$(git -C "$CLAUDE_PROJECT_DIR" worktree list --porcelain | grep -c '^worktree ')
    SIBLING_LIST=$(git -C "$CLAUDE_PROJECT_DIR" worktree list --porcelain | grep '^worktree ' | sed 's/^worktree //' | grep -v "^${CLAUDE_PROJECT_DIR}$" | grep -v "^${MAIN_WORKTREE}$")

    CONTEXT="${CONTEXT}

Worktree: ${CLAUDE_PROJECT_DIR} (branch: ${BRANCH})
Main worktree: ${MAIN_WORKTREE}
Active worktrees: ${WORKTREE_COUNT}"
    if [ -n "$SIBLING_LIST" ]; then
      CONTEXT="${CONTEXT}
Sibling worktrees:
${SIBLING_LIST}"
    fi
  fi
fi

# Previous session context (Orient phase of Orient→Work→Persist)
SESSION_LOG="$CLAUDE_PROJECT_DIR/.claude/dev/session-log.md"
if [ -f "$SESSION_LOG" ]; then
  # Extract the most recent session entry (between first and second ## Session:)
  LAST_SESSION=$(sed -n '/^## Session:/,/^## Session:/{ /^## Session:/!{/^## Session:/!p}; }' "$SESSION_LOG" | head -20)
  if [ -n "$LAST_SESSION" ]; then
    CONTEXT="${CONTEXT}

Previous session:
${LAST_SESSION}"
  fi
fi

if [ -n "$CONTEXT" ]; then
  # Output JSON (jq preferred, python fallback)
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
  else
    python3 -c "import json,sys; print(json.dumps({'additionalContext': sys.argv[1]}))" "$CONTEXT"
  fi
fi

exit 0
