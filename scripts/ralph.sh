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
VERIFIED_FILE=".verified-stories"

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

# --- Verification function ---

verify_story() {
  local story_id="$1"
  local story_index="$2"

  echo "  Verifying $story_id..."

  local criteria_count
  criteria_count=$(jq -r ".userStories[$story_index].acceptanceCriteria | length" "$PRD_FILE")

  local all_passed=true
  for ci in $(seq 0 $((criteria_count - 1))); do
    local criterion_type
    criterion_type=$(jq -r ".userStories[$story_index].acceptanceCriteria[$ci] | type" "$PRD_FILE")

    local verify_cmd=""
    local scenario=""

    if [[ "$criterion_type" == "object" ]]; then
      verify_cmd=$(jq -r ".userStories[$story_index].acceptanceCriteria[$ci].verify // \"manual\"" "$PRD_FILE")
      scenario=$(jq -r ".userStories[$story_index].acceptanceCriteria[$ci].scenario // \"criterion $ci\"" "$PRD_FILE")
    else
      # Flat string criterion — skip verification
      verify_cmd="manual"
      scenario="criterion $ci"
    fi

    if [[ "$verify_cmd" == "manual" || "$verify_cmd" == "null" || -z "$verify_cmd" ]]; then
      echo "    [$scenario] skip (manual)"
      continue
    fi

    echo "    [$scenario] running: $verify_cmd"
    if eval "$verify_cmd" >/dev/null 2>&1; then
      echo "    [$scenario] PASS"
    else
      echo "    [$scenario] FAIL"
      all_passed=false
    fi
  done

  if [[ "$all_passed" == "true" ]]; then
    echo "  $story_id: all verify commands passed"
    echo "$story_id" >> "$VERIFIED_FILE"
    return 0
  else
    echo "  $story_id: verification failed — reverting passes to false"
    local tmp
    tmp=$(jq ".userStories[$story_index].passes = false" "$PRD_FILE")
    echo "$tmp" > "$PRD_FILE"
    return 1
  fi
}

# --- Archive function ---

archive_run() {
  local feature_name="${BRANCH_NAME##*/}"
  local archive_subdir="$ARCHIVE_DIR/${feature_name}-$(date +%Y-%m-%d)"

  echo "Archiving run to $archive_subdir/"
  mkdir -p "$archive_subdir"
  cp "$PRD_FILE" "$archive_subdir/"
  [[ -f "$PROGRESS_FILE" ]] && cp "$PROGRESS_FILE" "$archive_subdir/"
  [[ -f "$VERIFIED_FILE" ]] && rm -f "$VERIFIED_FILE"

  echo "Archive complete."
  echo ""
  echo "TIP: Consider extracting lessons learned from this run."
  echo "     Use the researcher agent to analyze $archive_subdir/progress.txt"
  echo "     for patterns and improvements."
}

# --- Build iteration prompt ---

build_prompt() {
  local constitution_block=""

  # Inject constitution if present in prd.json
  if jq -e '.constitution' "$PRD_FILE" >/dev/null 2>&1; then
    local must must_not prefer
    must=$(jq -r '(.constitution.must // []) | map("- MUST: " + .) | join("\n")' "$PRD_FILE")
    must_not=$(jq -r '(.constitution.must_not // []) | map("- MUST NOT: " + .) | join("\n")' "$PRD_FILE")
    prefer=$(jq -r '(.constitution.prefer // []) | map("- PREFER: " + .) | join("\n")' "$PRD_FILE")

    if [[ -n "$must" || -n "$must_not" || -n "$prefer" ]]; then
      constitution_block="
## Constitution (project-wide constraints)

These constraints apply to ALL code you write in this iteration. Violating a
MUST or MUST NOT rule is a blocking failure — do not mark the story as passing.

${must}
${must_not}
${prefer}
"
    fi
  fi

  cat <<PROMPT
You are Marvin, running inside a Ralph Loop iteration. Your job is to implement
exactly ONE user story from prd.json per iteration.
${constitution_block}
## Instructions

1. Read \`prd.json\` to understand the full project and all user stories.
2. Read \`progress.txt\` if it exists — absorb learnings from prior iterations.
3. Check if the git branch from \`prd.json.branchName\` exists:
   - If not, create it from the current HEAD: \`git checkout -b <branchName>\`
   - If it exists, switch to it: \`git checkout <branchName>\`
4. Select the highest-priority user story where \`passes\` is \`false\`
   (lowest priority number = highest priority).
5. Implement ONLY that single story:
   - Follow existing code patterns — do not introduce new conventions
   - Make minimal, focused changes
   - Write tests that verify the acceptance criteria
6. Run quality checks appropriate to the project:
   - Python: \`ruff check .\`, \`mypy .\`, \`pytest\`
   - Node: \`npm test\`, \`npm run lint\`
   - Check the project's pyproject.toml or package.json for available commands
7. If ALL checks pass:
   - Stage and commit with message: "feat(ralph): US-NNN — <story title>"
   - Update \`prd.json\`: set the story's \`passes\` to \`true\`
   - Append to \`progress.txt\`:
     \`\`\`
     ## Iteration — <timestamp>
     ### US-NNN: <title>
     - Files changed: <list>
     - Patterns discovered: <any>
     - Gotchas: <any>
     \`\`\`
8. If checks FAIL:
   - Debug and fix — do NOT commit failing code
   - If you cannot fix after reasonable effort, add notes to the story's
     \`notes\` field in prd.json explaining what blocked you, then move on
9. After processing the story, check if ALL stories in prd.json have
   \`passes: true\`. If yes, output exactly:
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

# Show constitution summary if present
if jq -e '.constitution' "$PRD_FILE" >/dev/null 2>&1; then
  c_must=$(jq '.constitution.must // [] | length' "$PRD_FILE")
  c_must_not=$(jq '.constitution.must_not // [] | length' "$PRD_FILE")
  c_prefer=$(jq '.constitution.prefer // [] | length' "$PRD_FILE")
  echo "Constitution: ${c_must} must, ${c_must_not} must_not, ${c_prefer} prefer"
fi
echo ""

# Initialize verified stories tracking
: > "$VERIFIED_FILE"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  # Check if all stories already pass
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
  if [[ "$REMAINING" -eq 0 ]]; then
    echo "All stories pass. Running post-iteration verification..."
    echo ""

    # Post-iteration verification loop
    VERIFICATION_FAILED=false
    STORY_COUNT=$(jq '.userStories | length' "$PRD_FILE")
    for si in $(seq 0 $((STORY_COUNT - 1))); do
      SID=$(jq -r ".userStories[$si].id" "$PRD_FILE")

      # Skip already verified stories
      if grep -qx "$SID" "$VERIFIED_FILE" 2>/dev/null; then
        echo "  $SID: already verified, skipping"
        continue
      fi

      if ! verify_story "$SID" "$si"; then
        VERIFICATION_FAILED=true
      fi
    done

    if [[ "$VERIFICATION_FAILED" == "true" ]]; then
      echo ""
      echo "Verification failed for some stories. Continuing loop..."
      echo ""
      continue
    fi

    echo ""
    echo "=== COMPLETE ==="
    echo "All stories implemented and verified."
    archive_run
    exit 0
  fi

  echo "--- Iteration $i/$MAX_ITERATIONS ($REMAINING stories remaining) ---"

  PROMPT=$(build_prompt)

  # Spawn a fresh Claude Code session
  OUTPUT=$(claude --dangerously-skip-permissions -p "$PROMPT" 2>&1) || true

  # Check for completion signal
  if echo "$OUTPUT" | grep -q '<promise>COMPLETE</promise>'; then
    echo ""
    echo "Completion signal received. Running verification..."

    # Verify all stories that claim to pass
    VERIFICATION_FAILED=false
    STORY_COUNT=$(jq '.userStories | length' "$PRD_FILE")
    for si in $(seq 0 $((STORY_COUNT - 1))); do
      SID=$(jq -r ".userStories[$si].id" "$PRD_FILE")
      PASSES=$(jq -r ".userStories[$si].passes" "$PRD_FILE")

      if [[ "$PASSES" != "true" ]]; then
        continue
      fi

      # Skip already verified stories
      if grep -qx "$SID" "$VERIFIED_FILE" 2>/dev/null; then
        echo "  $SID: already verified, skipping"
        continue
      fi

      if ! verify_story "$SID" "$si"; then
        VERIFICATION_FAILED=true
      fi
    done

    if [[ "$VERIFICATION_FAILED" == "true" ]]; then
      echo "Verification reverted some stories. Continuing loop..."
      echo ""
      continue
    fi

    echo ""
    echo "=== COMPLETE ==="
    echo "All stories implemented and verified in $i iteration(s)."
    archive_run
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
