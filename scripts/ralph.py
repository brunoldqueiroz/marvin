#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "typer>=0.12",
#     "rich>=13.0",
# ]
# ///
"""ralph.py — Ralph Loop v2: autonomous multi-iteration task runner for Claude Code.

Two-phase execution:
  Phase 1 (Initializer): Claude reads PROMPT.md and creates .ralph/tasks.json,
                         .ralph/progress.md, and .ralph/init.sh.
  Phase 2 (Coder Loop):  Each iteration picks ONE pending task, implements it,
                         commits, and updates tasks.json status.

Usage:
  uv run scripts/ralph.py [OPTIONS] [PROMPT_FILE]
  uv run scripts/ralph.py --init-only prompts/PROMPT.md
  uv run scripts/ralph.py --skip-init --monitor prompts/PROMPT.md
"""

from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

console = Console()


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class RalphConfig:
    """All runtime configuration for the ralph loop."""

    prompt_file: Path
    ralph_dir: Path
    max_iter: int
    max_turns: int
    sleep_between: int
    rate_limit: int
    tools: str | None
    no_git: bool
    skip_permissions: bool
    monitor: bool
    dry_run: bool


@dataclass
class Task:
    """A single task in the task list."""

    id: str
    title: str
    description: str
    priority: int
    status: str
    completed_at: str | None


@dataclass
class TaskFile:
    """Parsed representation of .ralph/tasks.json."""

    schema_version: str
    task: str
    created_at: str
    completion_criteria: list[str]
    features: list[Task]


@dataclass
class LoopState:
    """Persistent state across coder loop iterations."""

    iterations: int = 0
    consecutive_no_progress: int = 0
    last_error: str = ""
    same_error_count: int = 0
    call_timestamps: list[float] = field(default_factory=list)
    circuit_state: str = "closed"  # closed | open


# ---------------------------------------------------------------------------
# Project auto-detection
# ---------------------------------------------------------------------------

_GIT_TOOLS = "Bash(git add *),Bash(git commit *),Bash(git status*),Bash(git diff*)"
_BASE_TOOLS = f"Read,Edit,Write,Grep,Glob,{_GIT_TOOLS}"


def detect_project() -> tuple[str, str, str]:
    """Auto-detect project type from filesystem markers.

    Returns (project_type, tools_string, verify_cmd).
    """
    cwd = Path.cwd()

    is_python = any(
        (cwd / marker).exists()
        for marker in ("pyproject.toml", "setup.py", "requirements.txt")
    )
    is_ts = (cwd / "package.json").exists()
    is_dbt = (cwd / "dbt_project.yml").exists()
    is_rust = (cwd / "Cargo.toml").exists()
    is_go = (cwd / "go.mod").exists()

    if is_rust:
        tools = f"{_BASE_TOOLS},Bash(cargo *)"
        return "rust", tools, "cargo test"

    if is_go:
        tools = f"{_BASE_TOOLS},Bash(go *)"
        return "go", tools, "go test ./..."

    if is_ts and not is_python:
        tools = f"{_BASE_TOOLS},Bash(npm *),Bash(npx *)"
        return "typescript", tools, "npm test"

    if is_python:
        tools = (
            f"{_BASE_TOOLS},"
            "Bash(python *),Bash(python3 *),Bash(pytest *),Bash(ruff *),Bash(uv *)"
        )
        if is_dbt:
            tools += ",Bash(dbt *)"
            return "python+dbt", tools, "pytest && dbt test"
        return "python", tools, "pytest"

    if is_dbt:
        tools = f"{_BASE_TOOLS},Bash(dbt *)"
        return "dbt", tools, "dbt test"

    # Generic fallback
    return "unknown", _BASE_TOOLS, "echo 'No verify command configured'"


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

_TASKS_JSON_SCHEMA = """{
  "schema_version": "1",
  "task": "Human-readable task name",
  "created_at": "2026-02-20T14:30:00Z",
  "completion_criteria": ["criterion 1", "criterion 2"],
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
}"""


def build_initializer_prompt(prompt_content: str, project_type: str) -> str:
    """Build the Phase 1 initializer prompt.

    Instructs Claude to create the .ralph/ directory structure without
    implementing any tasks.
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"""You are the Ralph Loop Initializer. Your ONLY job is to analyze the
task and create a structured plan — do NOT implement anything yet.

Project type detected: {project_type}
Current time: {now}

## TASK DESCRIPTION

{prompt_content}

## YOUR INSTRUCTIONS

1. Read and understand the task description above.

2. Create the directory `.ralph/` if it does not exist.

3. Create `.ralph/tasks.json` — a structured task breakdown following this
   EXACT JSON schema:

{_TASKS_JSON_SCHEMA}

   Rules for tasks.json:
   - Break the work into small, independently implementable tasks (T001, T002…)
   - Order by priority (1 = highest)
   - Each task should be completable in a single Claude session
   - ALL statuses MUST be "pending"
   - completed_at MUST be null for all tasks
   - The JSON MUST be valid (no trailing commas, no comments)

4. Create `.ralph/progress.md` — a human-readable progress tracker:
   ```
   # Ralph Progress

   ## Task: <task name>
   ## Created: {now}
   ## Status: INITIALIZING

   ## Tasks
   - [ ] T001 - <title>
   - [ ] T002 - <title>
   ...

   ## Log
   - [{now}] Initialized task list
   ```

5. Create `.ralph/init.sh` — a setup script to run before the first coding
   iteration (install deps, create dirs, etc.). Make it idempotent.
   If no setup is needed, create an empty script with just `#!/bin/bash`.

6. Commit everything:
   ```
   git add .ralph/
   git commit -m "chore(ralph): initialize task list"
   ```

## CRITICAL CONSTRAINTS

- DO NOT implement any tasks. Planning only.
- DO NOT modify any source files outside .ralph/
- The tasks.json MUST be valid JSON
- Each task MUST have a unique id (T001, T002, …)
"""


def build_coder_prompt(
    prompt_content: str,
    tasks_json: str,
    progress: str,
    verify_cmd: str,
) -> str:
    """Build the prompt for a single Coder Loop iteration.

    Instructs Claude to pick ONE pending task, implement it, test it,
    and update tasks.json.
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"""You are the Ralph Loop Coder. Implement exactly ONE pending task per
session. Read the filesystem state, pick the highest-priority pending task,
implement it, and update the state files.

Current time: {now}

## ORIGINAL TASK DESCRIPTION

{prompt_content}

## CURRENT TASK LIST (.ralph/tasks.json)

{tasks_json}

## CURRENT PROGRESS (.ralph/progress.md)

{progress}

## YOUR INSTRUCTIONS

1. Read the task list above. Find the highest-priority task with status "pending".

2. If NO pending tasks remain:
   - Write `.ralph/STATUS` with the content below
   - Stop. Do not do any other work.

3. Otherwise, implement EXACTLY ONE pending task:
   a. Change its status to "in_progress" in .ralph/tasks.json (update the file)
   b. Implement the feature following existing code conventions
   c. Run tests: `{verify_cmd}` — fix any failures before committing
   d. Update .ralph/tasks.json: set status to "complete", set completed_at to "{now}"
   e. Update .ralph/progress.md: check off the completed task in the task list,
      add a log entry with timestamp and what was done
   f. Commit all changes:
      `git add -A && git commit -m "feat(ralph): implement <task-title> [T00X]"`

4. After completing a task, check if ALL features now have status "complete".
   If yes, write `.ralph/STATUS` with:

```
RALPH_STATUS:
STATUS: COMPLETE
EXIT_SIGNAL: true
COMPLETED_TASKS: <count of complete tasks>
FAILED_TASKS: <count of failed tasks>
```

   Then update .ralph/progress.md to reflect completion.

## CRITICAL CONSTRAINTS

- Implement EXACTLY ONE task per session — no more
- NEVER add features or changes not listed in tasks.json
- NEVER modify .ralph/tasks.json schema_version or created_at
- The tasks.json MUST remain valid JSON after your changes
- Always run the verify command before committing
- If a task fails, set its status to "failed" and report the error in progress.md
"""


# ---------------------------------------------------------------------------
# Claude invocation
# ---------------------------------------------------------------------------


def invoke_claude(
    prompt: str,
    tools: str,
    max_turns: int,
    skip_permissions: bool,
    dry_run: bool = False,
) -> str:
    """Run `claude -p <prompt>` and return the result text.

    Uses fresh context (no --continue) each invocation.
    Parses JSON output and returns the `.result` field.
    On error, returns an error description string.
    """
    if dry_run:
        return "[DRY RUN] Would invoke claude -p <prompt>"

    cmd = [
        "claude",
        "-p",
        prompt,
        "--output-format",
        "json",
        "--allowedTools",
        tools,
        "--max-turns",
        str(max_turns),
    ]
    if skip_permissions:
        cmd.append("--dangerously-skip-permissions")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=3600,
        )
    except FileNotFoundError:
        return "ERROR: 'claude' command not found. Install Claude Code first."
    except subprocess.TimeoutExpired:
        return "ERROR: claude invocation timed out after 3600s"
    except Exception as exc:
        return f"ERROR: unexpected error invoking claude: {exc}"

    raw = result.stdout.strip()
    if not raw:
        stderr = result.stderr.strip()
        return f"ERROR: no output from claude. stderr: {stderr}"

    try:
        data = json.loads(raw)
        return str(data.get("result", ""))
    except json.JSONDecodeError:
        return f"ERROR: could not parse claude JSON output. raw: {raw[:500]}"


# ---------------------------------------------------------------------------
# State persistence
# ---------------------------------------------------------------------------


def load_state(path: Path) -> LoopState:
    """Load loop state from JSON file, returning a fresh state if missing."""
    if not path.exists():
        return LoopState()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return LoopState(
            iterations=data.get("iterations", 0),
            consecutive_no_progress=data.get("consecutive_no_progress", 0),
            last_error=data.get("last_error", ""),
            same_error_count=data.get("same_error_count", 0),
            call_timestamps=data.get("call_timestamps", []),
            circuit_state=data.get("circuit_state", "closed"),
        )
    except (json.JSONDecodeError, KeyError):
        return LoopState()


def save_state(state: LoopState, path: Path) -> None:
    """Persist loop state to JSON file."""
    data = {
        "iterations": state.iterations,
        "consecutive_no_progress": state.consecutive_no_progress,
        "last_error": state.last_error,
        "same_error_count": state.same_error_count,
        "call_timestamps": state.call_timestamps,
        "circuit_state": state.circuit_state,
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# Task file loading
# ---------------------------------------------------------------------------


def load_tasks(path: Path) -> TaskFile | None:
    """Parse tasks.json into a TaskFile dataclass. Returns None on error."""
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        features = [
            Task(
                id=f.get("id", ""),
                title=f.get("title", ""),
                description=f.get("description", ""),
                priority=f.get("priority", 99),
                status=f.get("status", "pending"),
                completed_at=f.get("completed_at"),
            )
            for f in data.get("features", [])
        ]
        return TaskFile(
            schema_version=data.get("schema_version", "1"),
            task=data.get("task", ""),
            created_at=data.get("created_at", ""),
            completion_criteria=data.get("completion_criteria", []),
            features=features,
        )
    except (json.JSONDecodeError, KeyError):
        return None


# ---------------------------------------------------------------------------
# Circuit breaker
# ---------------------------------------------------------------------------


def check_circuit_breaker(state: LoopState) -> bool:
    """Return True if the circuit is open and the loop should stop.

    Opens if:
    - 3 consecutive iterations without any git changes
    - 5 iterations with the same error message
    """
    if state.consecutive_no_progress >= 3:
        console.print(
            "[red]CIRCUIT OPEN[/red] 3 consecutive iterations with no progress."
        )
        return True
    if state.same_error_count >= 5:
        console.print(
            f"[red]CIRCUIT OPEN[/red] Same error repeated 5 times: {state.last_error}"
        )
        return True
    return False


# ---------------------------------------------------------------------------
# Progress detection
# ---------------------------------------------------------------------------


def detect_progress() -> bool:
    """Return True if the last commit introduced file changes (git diff HEAD~1)."""
    try:
        result = subprocess.run(
            ["git", "diff", "--stat", "HEAD~1"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        return bool(result.stdout.strip())
    except Exception:
        # If git fails (no commits yet, etc.) assume progress to avoid false opens
        return True


# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------


def rate_limit_wait(state: LoopState, limit: int) -> None:
    """Enforce a sliding-window rate limit of `limit` calls per hour.

    Removes timestamps older than 3600s, then waits if at the limit.
    """
    now = time.time()
    window = 3600.0
    # Prune old timestamps
    state.call_timestamps = [t for t in state.call_timestamps if now - t < window]

    if len(state.call_timestamps) >= limit:
        oldest = state.call_timestamps[0]
        wait_secs = window - (now - oldest) + 1.0
        if wait_secs > 0:
            wait_until = datetime.fromtimestamp(oldest + window)
            console.print(
                f"[yellow]RATE LIMIT[/yellow] {len(state.call_timestamps)}/{limit} "
                f"calls/hr. Waiting {wait_secs:.0f}s until {wait_until:%H:%M:%S}…"
            )
            time.sleep(wait_secs)

    state.call_timestamps.append(time.time())


# ---------------------------------------------------------------------------
# Exit conditions
# ---------------------------------------------------------------------------


def check_exit_conditions(ralph_dir: Path) -> bool:
    """Return True only when BOTH exit conditions are met:

    1. .ralph/STATUS contains EXIT_SIGNAL: true
    2. tasks.json has zero pending tasks
    """
    status_file = ralph_dir / "STATUS"
    if not status_file.exists():
        return False

    content = status_file.read_text(encoding="utf-8")
    has_exit_signal = "EXIT_SIGNAL: true" in content

    tasks_file = ralph_dir / "tasks.json"
    task_data = load_tasks(tasks_file)
    if task_data is None:
        return False

    pending_count = sum(1 for t in task_data.features if t.status == "pending")
    return has_exit_signal and pending_count == 0


# ---------------------------------------------------------------------------
# Rich dashboard
# ---------------------------------------------------------------------------

_STATUS_STYLE = {
    "pending": "dim",
    "in_progress": "yellow",
    "complete": "green",
    "failed": "red",
}


def _task_table(ralph_dir: Path) -> Table:
    """Build a Rich table of tasks from tasks.json."""
    table = Table(show_header=True, header_style="bold", expand=True)
    table.add_column("ID", style="cyan", width=6)
    table.add_column("Status", width=12)
    table.add_column("Title")

    task_data = load_tasks(ralph_dir / "tasks.json")
    if task_data:
        for t in task_data.features:
            style = _STATUS_STYLE.get(t.status, "")
            status_cell = (
                f"[{style}]{t.status.upper()}[/{style}]" if style else t.status.upper()
            )
            table.add_row(t.id, status_cell, t.title)
    else:
        table.add_row("-", "[dim]No tasks[/dim]", "")

    return table


def _log_tail(ralph_dir: Path, iteration: int, n: int = 12) -> Text:
    """Return the last n lines of the current iteration log as Rich Text."""
    log_file = ralph_dir / "logs" / f"iteration-{iteration:03d}.md"
    if not log_file.exists():
        return Text("Waiting for output…", style="dim")
    lines = log_file.read_text(encoding="utf-8", errors="replace").splitlines()
    tail = lines[-n:] if len(lines) > n else lines
    return Text("\n".join(tail), overflow="fold")


def create_dashboard(
    ralph_dir: Path,
    iteration: int,
    max_iter: int,
    state: LoopState,
    rate_limit: int,
    start_time: float,
) -> Layout:
    """Build the Rich Live layout for the --monitor dashboard."""
    elapsed = int(time.time() - start_time)
    h, m, s = elapsed // 3600, (elapsed % 3600) // 60, elapsed % 60
    elapsed_str = f"{h:02d}:{m:02d}:{s:02d}"

    calls_hr = len([t for t in state.call_timestamps if time.time() - t < 3600])

    header_text = (
        f"[bold]RALPH LOOP[/bold] — Iteration {iteration}/{max_iter} — "
        f"{elapsed_str} elapsed"
    )
    footer_text = (
        f"Circuit: [{'green' if state.circuit_state == 'closed' else 'red'}]"
        f"{state.circuit_state}[/]  |  "
        f"Rate: {calls_hr}/{rate_limit}/hr  |  "
        f"No-progress streak: {state.consecutive_no_progress}"
    )

    task_panel = Panel(
        _task_table(ralph_dir),
        title="Tasks",
        border_style="blue",
    )
    log_panel = Panel(
        _log_tail(ralph_dir, iteration),
        title="Current Log",
        border_style="dim",
    )

    layout = Layout()
    layout.split_column(
        Layout(Panel(header_text, style="bold blue"), size=3),
        Layout(name="body"),
        Layout(Panel(footer_text, style="dim"), size=3),
    )
    layout["body"].split_row(
        Layout(task_panel, name="tasks"),
        Layout(log_panel, name="log"),
    )
    return layout


# ---------------------------------------------------------------------------
# Phase 1: Initializer
# ---------------------------------------------------------------------------


def run_initializer(cfg: RalphConfig) -> None:
    """Phase 1: ask Claude to analyze PROMPT.md and create .ralph/ structure."""
    console.print(Panel("[bold]RALPH LOOP — Phase 1: Initializer[/bold]", style="blue"))

    cfg.ralph_dir.mkdir(parents=True, exist_ok=True)
    (cfg.ralph_dir / "logs").mkdir(exist_ok=True)

    prompt_content = cfg.prompt_file.read_text(encoding="utf-8")
    project_type, auto_tools, _ = detect_project()
    tools = cfg.tools or auto_tools

    console.print(f"  Project type:  [cyan]{project_type}[/cyan]")
    console.print(f"  Prompt file:   [cyan]{cfg.prompt_file}[/cyan]")
    console.print(f"  Tools:         [dim]{tools[:80]}…[/dim]")
    console.print()

    prompt = build_initializer_prompt(prompt_content, project_type)

    if cfg.dry_run:
        console.print(
            "[yellow]DRY RUN[/yellow] Would invoke claude for initialization."
        )
        console.print(
            Panel(
                prompt[:800] + "\n[dim]… (truncated)[/dim]",
                title="Initializer Prompt Preview",
                style="dim",
            )
        )
        return

    console.print("[dim]Running initializer (this may take a moment)…[/dim]")
    result = invoke_claude(
        prompt=prompt,
        tools=tools,
        max_turns=cfg.max_turns,
        skip_permissions=cfg.skip_permissions,
        dry_run=False,
    )

    # Save initializer log
    log_path = cfg.ralph_dir / "logs" / "initializer.md"
    log_path.write_text(result, encoding="utf-8")

    # Validate tasks.json was created
    tasks_path = cfg.ralph_dir / "tasks.json"
    if not tasks_path.exists():
        console.print(
            "[red]ERROR[/red] Initializer did not create .ralph/tasks.json. "
            "Check logs/initializer.md for details."
        )
        raise typer.Exit(code=1)

    task_data = load_tasks(tasks_path)
    if task_data is None:
        console.print(
            "[red]ERROR[/red] .ralph/tasks.json is not valid JSON. "
            "Check logs/initializer.md for details."
        )
        raise typer.Exit(code=1)

    # Print summary of created tasks
    table = Table(title="Initialized Tasks", show_header=True, header_style="bold")
    table.add_column("ID", style="cyan", width=6)
    table.add_column("Priority", justify="center", width=8)
    table.add_column("Title")
    for t in task_data.features:
        table.add_row(t.id, str(t.priority), t.title)

    console.print()
    console.print(table)
    console.print()
    console.print(
        f"[green]Initialized[/green] {len(task_data.features)} tasks "
        f"for: [bold]{task_data.task}[/bold]"
    )


# ---------------------------------------------------------------------------
# Phase 2: Coder Loop
# ---------------------------------------------------------------------------


def _git_commit_if_needed(message: str) -> None:
    """Commit any staged/unstaged changes; silently skip if nothing to commit."""
    try:
        subprocess.run(["git", "add", "-A"], capture_output=True, timeout=30)
        result = subprocess.run(
            ["git", "commit", "-m", message],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode == 0:
            console.print(f"  [green]committed[/green] {message}")
    except Exception:
        pass  # Best-effort


def run_coder_loop(cfg: RalphConfig) -> None:
    """Phase 2: iterate, each time asking Claude to implement one pending task."""
    console.print(Panel("[bold]RALPH LOOP — Phase 2: Coder Loop[/bold]", style="blue"))

    state_path = cfg.ralph_dir / "state.json"
    tasks_path = cfg.ralph_dir / "tasks.json"
    logs_dir = cfg.ralph_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    state = load_state(state_path)
    prompt_content = cfg.prompt_file.read_text(encoding="utf-8")
    project_type, auto_tools, verify_cmd = detect_project()
    tools = cfg.tools or auto_tools

    start_time = time.time()

    console.print(f"  Max iterations: [cyan]{cfg.max_iter}[/cyan]")
    console.print(f"  Max turns:      [cyan]{cfg.max_turns}[/cyan]")
    console.print(f"  Rate limit:     [cyan]{cfg.rate_limit}[/cyan]/hr")
    console.print(f"  Project type:   [cyan]{project_type}[/cyan]")
    console.print(f"  Verify cmd:     [cyan]{verify_cmd}[/cyan]")
    console.print()

    if cfg.monitor:
        live_ctx: Live | None = Live(
            create_dashboard(
                cfg.ralph_dir, 0, cfg.max_iter, state, cfg.rate_limit, start_time
            ),
            refresh_per_second=2,
            console=console,
        )
        live_ctx.__enter__()
    else:
        live_ctx = None

    try:
        for iteration in range(
            state.iterations + 1, state.iterations + cfg.max_iter + 1
        ):
            # --- Manual stop ---
            stop_file = cfg.ralph_dir / "STOP"
            if stop_file.exists():
                stop_file.unlink()
                console.print("[yellow]STOP file detected — halting loop.[/yellow]")
                break

            # --- Circuit breaker ---
            if check_circuit_breaker(state):
                state.circuit_state = "open"
                save_state(state, state_path)
                break

            # --- Rate limit ---
            rate_limit_wait(state, cfg.rate_limit)

            if not cfg.monitor:
                elapsed = int(time.time() - start_time)
                console.print(
                    f"[bold blue][{iteration}/{cfg.max_iter}][/bold blue] "
                    f"elapsed: {elapsed}s | "
                    f"circuit: {state.circuit_state} | "
                    f"no-progress streak: {state.consecutive_no_progress}"
                )

            # --- Build prompt ---
            tasks_json = (
                tasks_path.read_text(encoding="utf-8") if tasks_path.exists() else "{}"
            )
            progress_path = cfg.ralph_dir / "progress.md"
            progress = (
                progress_path.read_text(encoding="utf-8")
                if progress_path.exists()
                else ""
            )
            prompt = build_coder_prompt(
                prompt_content, tasks_json, progress, verify_cmd
            )

            if cfg.dry_run:
                console.print(
                    f"  [yellow]DRY RUN[/yellow] Would invoke claude "
                    f"(iter {iteration}/{cfg.max_iter})"
                )
                time.sleep(1)
                state.iterations = iteration
                save_state(state, state_path)
                break

            # --- Invoke Claude ---
            result = invoke_claude(
                prompt=prompt,
                tools=tools,
                max_turns=cfg.max_turns,
                skip_permissions=cfg.skip_permissions,
                dry_run=False,
            )

            # --- Save iteration log ---
            log_file = logs_dir / f"iteration-{iteration:03d}.md"
            log_file.write_text(result, encoding="utf-8")

            # --- Update state ---
            state.iterations = iteration

            is_error = result.startswith("ERROR:")
            if is_error:
                if result == state.last_error:
                    state.same_error_count += 1
                else:
                    state.last_error = result
                    state.same_error_count = 1
                console.print(f"  [red]error:[/red] {result[:120]}")
            else:
                state.last_error = ""
                state.same_error_count = 0

            # Progress detection
            made_progress = detect_progress()
            if made_progress:
                state.consecutive_no_progress = 0
            else:
                state.consecutive_no_progress += 1
                if not cfg.monitor:
                    console.print(
                        f"  [yellow]no progress[/yellow] "
                        f"(streak: {state.consecutive_no_progress}/3)"
                    )

            save_state(state, state_path)

            # --- Optional git commit ---
            if not cfg.no_git and not is_error:
                _git_commit_if_needed(f"chore(ralph): end of iteration {iteration}")

            # --- Refresh dashboard ---
            if live_ctx is not None:
                live_ctx.update(
                    create_dashboard(
                        cfg.ralph_dir,
                        iteration,
                        cfg.max_iter,
                        state,
                        cfg.rate_limit,
                        start_time,
                    )
                )

            # --- Exit conditions ---
            if check_exit_conditions(cfg.ralph_dir):
                elapsed = int(time.time() - start_time)
                console.print()
                console.print(
                    Panel(
                        f"[green bold]TASK COMPLETE[/green bold] after {iteration} iteration(s)\n"
                        f"Total time: {elapsed // 60}m {elapsed % 60}s",
                        style="green",
                    )
                )
                break

            # --- Sleep between iterations ---
            if iteration < state.iterations + cfg.max_iter:
                time.sleep(cfg.sleep_between)

        else:
            # Max iterations exhausted
            elapsed = int(time.time() - start_time)
            console.print()
            console.print(
                Panel(
                    f"[yellow]MAX ITERATIONS REACHED ({cfg.max_iter})[/yellow]\n"
                    f"Total time: {elapsed // 60}m {elapsed % 60}s\n\n"
                    f"Check [cyan].ralph/[/cyan] for progress.\n"
                    f"Re-run with [dim]--skip-init[/dim] to continue.",
                    style="yellow",
                )
            )

    finally:
        if live_ctx is not None:
            live_ctx.__exit__(None, None, None)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

app = typer.Typer(
    name="ralph.py",
    help="Ralph Loop v2 — autonomous multi-iteration task runner for Claude Code.",
    add_completion=False,
)


@app.command()
def main(
    prompt_file: Annotated[
        Path,
        typer.Argument(
            help="Task prompt file",
            metavar="PROMPT_FILE",
        ),
    ] = Path("prompts/PROMPT.md"),
    max_iter: Annotated[
        int,
        typer.Option(
            "-n", "--max-iter", help="Max coder iterations", envvar="RALPH_MAX_ITER"
        ),
    ] = 20,
    init_only: Annotated[
        bool,
        typer.Option("--init-only", help="Run initializer only, then exit"),
    ] = False,
    skip_init: Annotated[
        bool,
        typer.Option(
            "--skip-init", help="Skip initializer, use existing .ralph/tasks.json"
        ),
    ] = False,
    monitor: Annotated[
        bool,
        typer.Option("--monitor", help="Show Rich live dashboard during coder loop"),
    ] = False,
    no_git: Annotated[
        bool,
        typer.Option("--no-git", help="Disable git commit per iteration"),
    ] = False,
    dangerously_skip_permissions: Annotated[
        bool,
        typer.Option(
            "--dangerously-skip-permissions",
            help="Pass --dangerously-skip-permissions to claude CLI",
        ),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Show what would happen without running claude"),
    ] = False,
    max_turns: Annotated[
        int,
        typer.Option(help="Max turns per claude invocation", envvar="RALPH_MAX_TURNS"),
    ] = 30,
    sleep_between: Annotated[
        int,
        typer.Option(
            help="Seconds to sleep between coder iterations", envvar="RALPH_SLEEP"
        ),
    ] = 2,
    rate_limit: Annotated[
        int,
        typer.Option(help="Max claude calls per hour", envvar="RALPH_RATE_LIMIT"),
    ] = 40,
    tools: Annotated[
        str | None,
        typer.Option(
            help="Override allowedTools (comma-separated)", envvar="RALPH_TOOLS"
        ),
    ] = None,
) -> None:
    """Run an autonomous multi-iteration task using Claude Code.

    Phase 1 (Initializer): Claude reads PROMPT_FILE and creates
    .ralph/tasks.json with a structured breakdown of work.

    Phase 2 (Coder Loop): Each iteration Claude picks ONE pending task,
    implements it, tests it, commits, and marks it complete.

    The loop exits when all tasks are complete or max iterations is reached.

    Environment variables:
      RALPH_MAX_ITER    Default for --max-iter
      RALPH_MAX_TURNS   Default for --max-turns
      RALPH_SLEEP       Default for --sleep-between
      RALPH_RATE_LIMIT  Default for --rate-limit
      RALPH_TOOLS       Default for --tools
    """
    # Validate prompt file
    if not prompt_file.is_file():
        console.print(f"[red]ERROR[/red] Prompt file not found: {prompt_file}")
        console.print()
        console.print("Create one first, e.g.:")
        console.print("  [dim]mkdir -p prompts[/dim]")
        console.print("  [dim]cat > prompts/PROMPT.md[/dim]")
        raise typer.Exit(code=1)

    # Validate claude is available (skip in dry-run)
    if not dry_run:
        if not any(
            (Path(p) / "claude").is_file()
            for p in os.environ.get("PATH", "").split(":")
        ):
            # subprocess.run is more reliable than PATH scanning
            probe = subprocess.run(["which", "claude"], capture_output=True, text=True)
            if probe.returncode != 0:
                console.print(
                    "[red]ERROR[/red] 'claude' command not found. "
                    "Install Claude Code first."
                )
                raise typer.Exit(code=1)

    ralph_dir = Path(".ralph")

    cfg = RalphConfig(
        prompt_file=prompt_file.resolve(),
        ralph_dir=ralph_dir,
        max_iter=max_iter,
        max_turns=max_turns,
        sleep_between=sleep_between,
        rate_limit=rate_limit,
        tools=tools,
        no_git=no_git,
        skip_permissions=dangerously_skip_permissions,
        monitor=monitor,
        dry_run=dry_run,
    )

    # Banner
    console.print(
        Panel(
            "[bold]RALPH LOOP v2[/bold] — Autonomous Task Runner\n\n"
            f"[dim]Prompt:[/dim]    {cfg.prompt_file}\n"
            f"[dim]Ralph dir:[/dim] {cfg.ralph_dir.resolve()}\n"
            f"[dim]Max iter:[/dim]  {cfg.max_iter}\n"
            f"[dim]Max turns:[/dim] {cfg.max_turns} per invocation"
            + (
                "\n[yellow]  DRY RUN — claude will not be invoked[/yellow]"
                if dry_run
                else ""
            ),
            style="bold blue",
            expand=False,
        )
    )
    console.print()

    # Phase 1
    if not skip_init:
        run_initializer(cfg)
        if init_only:
            return

    # Phase 2
    run_coder_loop(cfg)


if __name__ == "__main__":
    app()
