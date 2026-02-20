---
name: ralph
description: "Two-phase autonomous loop: initializer plans tasks as JSON, coder executes one per iteration with fresh context, circuit breaker, and git commits."
disable-model-invocation: true
argument-hint: "[task description]"
---

# Ralph Loop

Task: $ARGUMENTS

## What is the Ralph Loop?

The Ralph Loop enables Marvin to work on long-running tasks that exceed a single
context window. It works in two phases:

1. **Initializer** — Claude reads PROMPT.md and creates `.ralph/tasks.json` (structured plan)
2. **Coder Loop** — Each iteration picks ONE pending task, implements it, tests, and commits

Every iteration uses **fresh context** (no `--continue`). All state lives in the
filesystem (`.ralph/` directory).

## Setup

### 1. Define the Task

Create `prompts/PROMPT.md` with a clear task specification:

```markdown
# Task: <Clear Task Name>

## Objective
[What needs to be accomplished — be specific and measurable]

## Completion Criteria
- Criterion 1
- Criterion 2
- All tests pass
- Verification complete

## Context
- Project: [project description]
- Key files: [list relevant files]
- Constraints: [any limitations]
```

### 2. Start the Loop

```bash
# Basic usage (reads from prompts/PROMPT.md)
uv run ~/Projects/marvin/scripts/ralph.py

# Custom prompt file and max iterations
uv run ~/Projects/marvin/scripts/ralph.py prompts/my-task.md -n 15

# Initialize only (plan tasks without executing)
uv run ~/Projects/marvin/scripts/ralph.py --init-only prompts/PROMPT.md

# Skip init, resume from existing tasks.json
uv run ~/Projects/marvin/scripts/ralph.py --skip-init prompts/PROMPT.md

# Live dashboard
uv run ~/Projects/marvin/scripts/ralph.py --monitor prompts/PROMPT.md

# Dry run (shows what would happen)
uv run ~/Projects/marvin/scripts/ralph.py --dry-run prompts/PROMPT.md
```

### 3. Monitor Progress

While the loop runs:
- Watch `.ralph/tasks.json` for task status changes
- Check `.ralph/progress.md` for human-readable progress
- Check `.ralph/logs/` for per-iteration outputs
- Check git log for commits made during execution
- Use `--monitor` for a Rich live dashboard
- Create `.ralph/STOP` to gracefully stop the loop

## How It Works

### Phase 1: Initializer

Claude reads PROMPT.md and creates:
- `.ralph/tasks.json` — structured task list (JSON)
- `.ralph/progress.md` — human-readable progress tracker
- `.ralph/init.sh` — project setup script (idempotent)
- Git commit: `chore(ralph): initialize task list`

Claude does NOT implement any tasks in this phase.

### Phase 2: Coder Loop

Each iteration (always fresh context):
1. Read `.ralph/tasks.json` and `.ralph/progress.md`
2. Pick the highest-priority pending task
3. Implement it, run tests
4. Update `tasks.json` status to "complete"
5. Git commit the changes
6. When all tasks are done, write `.ralph/STATUS` with `EXIT_SIGNAL: true`

### Task JSON Format (`.ralph/tasks.json`)

```json
{
  "schema_version": "1",
  "task": "Task name",
  "created_at": "2026-02-20T14:30:00Z",
  "completion_criteria": ["pytest passes", "ruff check clean"],
  "features": [
    {
      "id": "T001",
      "title": "Short title",
      "description": "What to do",
      "priority": 1,
      "status": "pending",
      "completed_at": null
    }
  ]
}
```

### RALPH_STATUS Protocol (`.ralph/STATUS`)

Written by Claude when all tasks are complete:

```
RALPH_STATUS:
STATUS: COMPLETE
EXIT_SIGNAL: true
COMPLETED_TASKS: 8
FAILED_TASKS: 0
```

The loop exits only when BOTH conditions are met:
1. `EXIT_SIGNAL: true` in `.ralph/STATUS`
2. Zero pending tasks in `.ralph/tasks.json`

## Safety Features

### Circuit Breaker
- **3 consecutive iterations with no file changes** → loop stops
- **5 iterations with the same error** → loop stops
- State tracked in `.ralph/state.json`

### Rate Limiting
- Sliding window: max N calls per hour (default: 40)
- Configurable via `RALPH_RATE_LIMIT` env var or `--rate-limit`

### Manual Stop
- Create `.ralph/STOP` file to gracefully halt the loop

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_MAX_ITER` | 20 | Max coder iterations |
| `RALPH_MAX_TURNS` | 30 | Turns per claude invocation |
| `RALPH_SLEEP` | 2 | Seconds between iterations |
| `RALPH_RATE_LIMIT` | 40 | Max API calls per hour |
| `RALPH_TOOLS` | (auto) | Override allowedTools |

## Best Practices

- **Atomic tasks** — Each task in tasks.json should be independently completable
- **Filesystem is the API** — All progress must be in files, not in context
- **Git frequently** — Commit after each completed task for safety
- **Clear completion criteria** — The prompt must unambiguously define "done"
- **Limit iterations** — Set a reasonable max to prevent runaway loops
- **Scoped tools** — Auto-detected by project type, override with `RALPH_TOOLS`

## When to Use

- Refactoring across many files
- Implementing a feature with 10+ subtasks
- Code migrations (e.g., Python 2→3, framework upgrades)
- Writing comprehensive test suites
- Any task that would exceed a single context window
