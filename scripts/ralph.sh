#!/usr/bin/env bash
# ralph.sh — Autonomous implementation loop
# Spawns fresh Claude Code sessions to implement user stories from prd.json
# Usage: ./scripts/ralph.sh [max_iterations]
set -euo pipefail

MAX_ITERATIONS="${1:-10}"
PRD_FILE="prd.json"
PROGRESS_FILE="progress.txt"
LAST_BRANCH_FILE=".last-branch"
ARCHIVE_DIR="archive"

# --- Pre-flight checks ---

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is required but not installed." >&2
    exit 1
  fi
}

check_dependency claude
check_dependency jq

if [[ ! -f "$PRD_FILE" ]]; then
  echo "ERROR: $PRD_FILE not found. Run /ralph skill first to create it." >&2
  exit 1
fi

# Validate JSON
if ! jq empty "$PRD_FILE" 2>/dev/null; then
  echo "ERROR: $PRD_FILE is not valid JSON." >&2
  exit 1
fi

# --- Branch change detection and archival ---

BRANCH_NAME=$(jq -r '.branchName' "$PRD_FILE")
if [[ -f "$LAST_BRANCH_FILE" ]]; then
  PREVIOUS_BRANCH=$(cat "$LAST_BRANCH_FILE")
  if [[ "$PREVIOUS_BRANCH" != "$BRANCH_NAME" ]]; then
    ARCHIVE_SUBDIR="$ARCHIVE_DIR/$(date +%Y-%m-%d)-${PREVIOUS_BRANCH##*/}"
    echo "Branch changed: $PREVIOUS_BRANCH -> $BRANCH_NAME"
    echo "Archiving previous run to $ARCHIVE_SUBDIR/"
    mkdir -p "$ARCHIVE_SUBDIR"
    [[ -f "$PROGRESS_FILE" ]] && mv "$PROGRESS_FILE" "$ARCHIVE_SUBDIR/"
    echo "Archive complete."
  fi
fi
echo "$BRANCH_NAME" > "$LAST_BRANCH_FILE"

# --- Build iteration prompt ---

build_prompt() {
  cat <<'PROMPT'
You are Marvin, running inside a Ralph Loop iteration. Your job is to implement
exactly ONE user story from prd.json per iteration.

## Instructions

1. Read `prd.json` to understand the full project and all user stories.
2. Read `progress.txt` if it exists — absorb learnings from prior iterations.
3. Check if the git branch from `prd.json.branchName` exists:
   - If not, create it from the current HEAD: `git checkout -b <branchName>`
   - If it exists, switch to it: `git checkout <branchName>`
4. Select the highest-priority user story where `passes` is `false`
   (lowest priority number = highest priority).
5. Implement ONLY that single story:
   - Follow existing code patterns — do not introduce new conventions
   - Make minimal, focused changes
   - Write tests that verify the acceptance criteria
6. Run quality checks appropriate to the project:
   - Python: `ruff check .`, `mypy .`, `pytest`
   - Node: `npm test`, `npm run lint`
   - Check the project's pyproject.toml or package.json for available commands
7. If ALL checks pass:
   - Stage and commit with message: "feat(ralph): US-NNN — <story title>"
   - Update `prd.json`: set the story's `passes` to `true`
   - Append to `progress.txt`:
     ```
     ## Iteration — <timestamp>
     ### US-NNN: <title>
     - Files changed: <list>
     - Patterns discovered: <any>
     - Gotchas: <any>
     ```
8. If checks FAIL:
   - Debug and fix — do NOT commit failing code
   - If you cannot fix after reasonable effort, add notes to the story's
     `notes` field in prd.json explaining what blocked you, then move on
9. After processing the story, check if ALL stories in prd.json have
   `passes: true`. If yes, output exactly:
   <promise>COMPLETE</promise>

## Rules
- Implement ONE story per iteration — never more
- NEVER commit code that fails quality checks
- NEVER modify stories you are not currently implementing
- ALWAYS update prd.json and progress.txt before finishing
- If stuck on a story for the entire iteration, set its notes and exit
  so the next iteration gets fresh context
PROMPT
}

# --- Main loop ---

echo "=== Ralph Loop ==="
echo "Project: $(jq -r '.project' "$PRD_FILE")"
echo "Branch:  $BRANCH_NAME"
echo "Stories: $(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE") remaining"
echo "Max iterations: $MAX_ITERATIONS"
echo ""

for i in $(seq 1 "$MAX_ITERATIONS"); do
  # Check if all stories already pass
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
  if [[ "$REMAINING" -eq 0 ]]; then
    echo "All stories pass. Done!"
    exit 0
  fi

  echo "--- Iteration $i/$MAX_ITERATIONS ($REMAINING stories remaining) ---"

  PROMPT=$(build_prompt)

  # Spawn a fresh Claude Code session
  OUTPUT=$(claude --dangerously-skip-permissions -p "$PROMPT" 2>&1) || true

  # Check for completion signal
  if echo "$OUTPUT" | grep -q '<promise>COMPLETE</promise>'; then
    echo ""
    echo "=== COMPLETE ==="
    echo "All stories implemented successfully in $i iteration(s)."
    exit 0
  fi

  echo "Iteration $i finished. Checking progress..."
  jq -r '.userStories[] | "\(.id) \(.title): \(if .passes then "PASS" else "PENDING" end)"' "$PRD_FILE"
  echo ""
done

echo "=== MAX ITERATIONS REACHED ==="
echo "Completed $MAX_ITERATIONS iterations without finishing all stories."
echo "Check progress.txt for details on what was accomplished."
echo "Remaining stories:"
jq -r '.userStories[] | select(.passes == false) | "  - \(.id): \(.title)"' "$PRD_FILE"
exit 1
