#!/bin/bash
# ralph.sh — Run Marvin in Ralph Loop mode for long-running autonomous tasks
#
# The Ralph Loop enables tasks that exceed a single context window by:
# 1. Writing all progress to the filesystem (not relying on context)
# 2. Running Claude in a bash loop with --continue
# 3. Each iteration picks up from filesystem state
# 4. The task self-terminates when .ralph-complete is created
#
# Usage:
#   ./ralph.sh                              # Default: prompts/PROMPT.md, 10 iterations
#   ./ralph.sh prompts/my-task.md           # Custom prompt file
#   ./ralph.sh prompts/my-task.md 20        # Custom prompt + max iterations
#   ./ralph.sh --help                       # Show help

set -euo pipefail

# --- Configuration ---
PROMPT_FILE="${1:-prompts/PROMPT.md}"
MAX_ITERATIONS="${2:-10}"
MAX_TURNS="${RALPH_MAX_TURNS:-30}"
SLEEP_BETWEEN="${RALPH_SLEEP:-2}"
LOG_DIR=".ralph-logs"

# --- Help ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "ralph.sh — Ralph Loop runner for Marvin"
  echo ""
  echo "Usage:"
  echo "  ./ralph.sh [prompt-file] [max-iterations]"
  echo ""
  echo "Arguments:"
  echo "  prompt-file      Path to the prompt file (default: prompts/PROMPT.md)"
  echo "  max-iterations   Maximum loop iterations (default: 10)"
  echo ""
  echo "Environment variables:"
  echo "  RALPH_MAX_TURNS  Max turns per iteration (default: 30)"
  echo "  RALPH_SLEEP      Seconds between iterations (default: 2)"
  echo ""
  echo "Signal files:"
  echo "  .ralph-complete  Create this to signal task completion"
  echo "  .ralph-status    Write WARN or ROTATE for status signals"
  echo "  .ralph-stop      Create this to gracefully stop the loop"
  echo ""
  echo "Examples:"
  echo "  ./ralph.sh prompts/refactor.md 15"
  echo "  RALPH_MAX_TURNS=50 ./ralph.sh prompts/migration.md 20"
  exit 0
fi

# --- Validation ---
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Prompt file not found: $PROMPT_FILE"
  echo ""
  echo "Create a prompt file first. Example:"
  echo "  mkdir -p prompts"
  echo "  cat > prompts/PROMPT.md << 'EOF'"
  echo "  # Task: Your Task Name"
  echo "  ## Objective"
  echo "  [What needs to be done]"
  echo "  ## Completion Criteria"
  echo "  - [ ] Criterion 1"
  echo "  - [ ] Criterion 2"
  echo "  ## Instructions"
  echo "  1. Read changes/tasks.md for progress"
  echo "  2. Pick next unchecked task"
  echo "  3. Implement and test"
  echo "  4. Check off completed task"
  echo "  5. Create .ralph-complete when ALL criteria are met"
  echo "  EOF"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  echo "ERROR: 'claude' command not found. Install Claude Code first."
  exit 1
fi

# --- Setup ---
mkdir -p "$LOG_DIR"
rm -f .ralph-complete .ralph-stop .ralph-status
iteration=0
start_time=$(date +%s)

echo "================================================"
echo "  RALPH LOOP — Autonomous Task Runner"
echo "================================================"
echo ""
echo "Prompt:         $PROMPT_FILE"
echo "Max iterations: $MAX_ITERATIONS"
echo "Max turns:      $MAX_TURNS per iteration"
echo "Logs:           $LOG_DIR/"
echo ""
echo "Signal files:"
echo "  .ralph-complete → task is done (auto-created by agent)"
echo "  .ralph-stop     → gracefully stop the loop (create manually)"
echo ""
echo "Starting in 3 seconds... (Ctrl+C to cancel)"
sleep 3
echo ""

# --- Main Loop ---
while [ $iteration -lt $MAX_ITERATIONS ]; do
  iteration=$((iteration + 1))
  iter_start=$(date +%s)

  echo "--- Iteration $iteration/$MAX_ITERATIONS [$(date '+%H:%M:%S')] ---"

  # Check for manual stop signal
  if [ -f ".ralph-stop" ]; then
    rm -f .ralph-stop
    echo ""
    echo "Stop signal received. Halting loop."
    break
  fi

  # Run Claude
  log_file="$LOG_DIR/iteration-$iteration.md"

  claude -p "$(cat "$PROMPT_FILE")" \
    --continue \
    --allowedTools "Read,Edit,Write,Bash(python *),Bash(python3 *),Bash(pytest *),Bash(git add *),Bash(git commit *),Bash(git status*),Bash(git diff*),Bash(ruff *),Bash(dbt *),Grep,Glob" \
    --max-turns "$MAX_TURNS" \
    --output-format json 2>/dev/null | jq -r '.result // "No output"' > "$log_file" 2>/dev/null || true

  iter_end=$(date +%s)
  iter_duration=$((iter_end - iter_start))
  echo "  Duration: ${iter_duration}s | Log: $log_file"

  # Check for completion signal
  if [ -f ".ralph-complete" ]; then
    rm -f .ralph-complete .ralph-status
    total_time=$(( $(date +%s) - start_time ))
    echo ""
    echo "================================================"
    echo "  TASK COMPLETED after $iteration iteration(s)"
    echo "  Total time: $((total_time / 60))m $((total_time % 60))s"
    echo "================================================"
    exit 0
  fi

  # Check status signals
  if [ -f ".ralph-status" ]; then
    status=$(cat .ralph-status)
    echo "  Status signal: $status"
    rm -f .ralph-status

    if [ "$status" = "ROTATE" ]; then
      echo "  Context rotation requested — next iteration starts fresh"
    fi
  fi

  # Pause between iterations
  if [ $iteration -lt $MAX_ITERATIONS ]; then
    sleep "$SLEEP_BETWEEN"
  fi
done

# --- Max iterations reached ---
total_time=$(( $(date +%s) - start_time ))
echo ""
echo "================================================"
echo "  MAX ITERATIONS REACHED ($MAX_ITERATIONS)"
echo "  Total time: $((total_time / 60))m $((total_time % 60))s"
echo "================================================"
echo ""
echo "The task may not be complete. Check progress:"
echo "  - changes/tasks.md (task checklist)"
echo "  - $LOG_DIR/ (iteration logs)"
echo "  - git log (commits made during execution)"
echo ""
echo "To continue, run again:"
echo "  ./ralph.sh $PROMPT_FILE $MAX_ITERATIONS"
