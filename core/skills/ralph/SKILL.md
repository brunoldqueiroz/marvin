---
name: ralph
description: "Run a long autonomous task across multiple context windows using filesystem checkpointing. Use when a task has 10+ subtasks or would exceed a single context window."
disable-model-invocation: true
argument-hint: "[task description]"
---

# Ralph Loop

Task: $ARGUMENTS

## What is the Ralph Loop?

The Ralph Loop enables Marvin to work on long-running tasks that exceed a single
context window. It works by:
1. Writing all progress to the **filesystem** (not relying on context)
2. Running Claude in a bash loop with `--continue`
3. Each iteration picks up from filesystem state
4. The task self-terminates when completion criteria are met

## Setup

### 1. Define the Task

Create `prompts/PROMPT.md` with a clear task specification:

```markdown
# Task: <Clear Task Name>

## Objective
[What needs to be accomplished — be specific and measurable]

## Completion Criteria
[How to know when the task is done — checklist format]
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All tests pass
- [ ] Verification complete

## Current State
[Read changes/tasks.md for current progress]

## Context
- Project: [project description]
- Key files: [list relevant files]
- Constraints: [any limitations]

## Instructions
1. Read `changes/tasks.md` to see what's been done and what's next
2. Pick the next unchecked task
3. Implement it
4. Run tests to verify
5. Check off the completed task in `changes/tasks.md`
6. If all tasks are done AND all criteria are met:
   - Run the full test suite
   - Create the file `.ralph-complete`
7. If context is getting large, write progress to files and continue

## Signal System
- Create `.ralph-complete` when ALL completion criteria are met
- Write `WARN` to `.ralph-status` if you detect issues
- Progress is tracked in `changes/tasks.md` (checked items)
```

### 2. Create the Task Checklist

Create `changes/tasks.md` with atomic tasks:

```markdown
# Tasks: <Task Name>

- [ ] Task 1: [description]
- [ ] Task 2: [description]
- [ ] ...
- [ ] Final: Run full verification
```

### 3. Start the Loop

Run the Ralph Loop using the runner script:

```bash
# Basic usage (reads from prompts/PROMPT.md)
~/Projects/marvin/scripts/ralph.sh

# Custom prompt file and max iterations
~/Projects/marvin/scripts/ralph.sh prompts/my-task.md 15

# Or run manually:
while :; do
  claude -p "$(cat prompts/PROMPT.md)" \
    --continue \
    --allowedTools "Read,Edit,Write,Bash(python *),Bash(pytest *),Bash(git *),Grep,Glob" \
    --max-turns 30

  if [ -f ".ralph-complete" ]; then
    rm -f .ralph-complete
    echo "Task completed!"
    break
  fi

  sleep 2
done
```

### 4. Monitor Progress

While the loop runs:
- Watch `changes/tasks.md` for checked items
- Check `.ralph-status` for warnings
- Check git log for commits made during execution
- The loop auto-terminates when `.ralph-complete` is created

## Best Practices

- **Atomic tasks** — Each task in the checklist should be independently completable
- **Filesystem is the API** — All progress must be in files, not in context
- **Git frequently** — Commit after each completed task for safety
- **Clear completion criteria** — The prompt must unambiguously define "done"
- **Limit iterations** — Set a reasonable max to prevent runaway loops
- **Scoped tools** — Only allow the tools the task actually needs

## When to Use

- Refactoring across many files
- Implementing a feature with 10+ subtasks
- Code migrations (e.g., Python 2→3, framework upgrades)
- Writing comprehensive test suites
- Any task that would exceed a single context window
