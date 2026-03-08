# Spec — Task Dependency Graph

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin's SDD pipeline generates tasks with dependency metadata (`Depends on:`
fields, ASCII dependency graphs, parallelization notes) but nothing in the
orchestration layer **consumes** this information. The agent executing a spec's
tasks treats the checklist as a linear sequence — processing top to bottom,
never parallelizing independent tasks, and never detecting blocked tasks before
attempting them.

This means:
1. **Wasted time**: tasks that could run in parallel (e.g., 4 independent file
   edits) execute sequentially, multiplying wall-clock time by N.
2. **Silent blockers**: if task T-05 depends on T-01 through T-04 but T-03
   fails, the agent may still attempt T-05 without realizing it's blocked.
3. **Manual orchestration**: the human must read the dependency graph and
   manually decide "run T-01 through T-04 in parallel, then T-05." The metadata
   exists but the agent ignores it.

The dependency data is already being **produced** (tasks template has
`Depends on:`, spec 004's tasks.md includes a full DAG and parallelization
section). The gap is entirely in **consumption** — the rules and workflows
that tell the agent how to interpret and act on dependency information.

## Desired Outcome

After implementation:

1. A new rule file (or extension to `specs.md`) defines how the orchestrating
   agent should parse and act on task dependencies during spec implementation.
2. When executing a spec's tasks, the agent:
   - Identifies tasks with no unmet dependencies ("ready" tasks)
   - Launches independent ready tasks in parallel via Agent calls
   - Waits for blocking dependencies to complete before starting dependent tasks
   - Reports blocked tasks and the specific dependency that blocks them
3. The `sdd-tasks` skill validates the dependency graph when generating tasks:
   - Detects circular dependencies (A → B → A)
   - Identifies orphan dependencies (depends on a task ID that doesn't exist)
   - Identifies isolated tasks (no dependencies, not depended upon — flagged as
     info, not error)
4. Tasks without a `Depends on:` field are treated as having no dependencies
   (backward compatible with existing specs 001–005).
5. The tasks template is enhanced with a standardized dependency graph section
   that uses a consistent, parseable format.

## Requirements

### Functional

1. **FR-01: Orchestration rules** — Create rules that define the task execution
   algorithm:
   (a) Parse all tasks and build an in-memory dependency graph.
   (b) Identify "ready" tasks: tasks whose dependencies are all completed
   (marked `[x]`).
   (c) Group ready tasks by agent type for parallel dispatch.
   (d) After each batch completes, re-evaluate ready tasks.
   (e) If no tasks are ready and uncompleted tasks remain, report a deadlock
   (circular dependency or failed prerequisite).

2. **FR-02: Parallel dispatch guidance** — Rules must specify:
   (a) Independent tasks assigned to the same agent type CAN be dispatched in
   parallel via multiple Agent calls.
   (b) Maximum parallel agents per batch: 4 (to control token cost).
   (c) Tasks modifying the same file MUST NOT run in parallel (conflict risk).
   (d) After parallel batch completes, mark all completed tasks in tasks.md
   before starting the next batch.

3. **FR-03: Dependency validation in sdd-tasks** — Extend the sdd-tasks skill
   to validate the generated dependency graph:
   (a) Cycle detection: error if A depends on B depends on A (direct or
   transitive).
   (b) Missing reference: error if a task declares `Depends on: T-99` but T-99
   doesn't exist.
   (c) Self-reference: error if a task depends on itself.
   (d) Isolated task warning: info-level note if a task has no dependencies and
   nothing depends on it (may indicate a missing dependency).

4. **FR-04: Standardized dependency graph format** — Define a consistent format
   for the dependency graph section in tasks.md:
   (a) Each task has a stable ID (T-01, T-02, ...).
   (b) The `Depends on:` field uses task IDs, comma-separated for multiple
   dependencies (e.g., `Depends on: T-01, T-03`).
   (c) `Depends on: none` explicitly marks tasks with no dependencies.
   (d) The dependency graph section uses ASCII format (not Mermaid — tasks.md
   is consumed by agents, not rendered visually).

5. **FR-05: Blocked task reporting** — When a task cannot be started because
   its dependency failed or was skipped:
   (a) Report which task is blocked and which dependency is unmet.
   (b) Ask the user whether to skip the blocked task, retry the failed
   dependency, or abort the spec execution.
   (c) Mark skipped tasks with `[-]` (distinct from `[ ]` uncompleted and
   `[x]` completed).

6. **FR-06: Execution phases** — The orchestration rules should produce
   execution phases from the dependency graph:
   (a) Phase 1: all tasks with `Depends on: none`.
   (b) Phase N: tasks whose dependencies are all in phases 1 through N-1.
   (c) Within each phase, tasks are independent and can run in parallel
   (subject to FR-02 constraints).
   (d) Log the phase plan before execution begins so the user can review it.

### Non-Functional

1. **NFR-01: Backward compatibility** — Existing tasks.md files (specs 001–005)
   without dependency metadata remain valid. Tasks missing `Depends on:` are
   treated as `Depends on: none`.

2. **NFR-02: No code dependencies** — The orchestration logic lives in rules
   and skill instructions, not in Python scripts. The agent interprets the
   dependency graph at execution time using its reasoning capabilities.

3. **NFR-03: Token cost awareness** — Parallel dispatch is capped at 4
   concurrent agents per batch. The rules should note that parallelization
   trades token cost for wall-clock time and the user may prefer sequential
   execution for cost-sensitive work.

4. **NFR-04: Graceful degradation** — If dependency parsing fails (malformed
   tasks.md), fall back to sequential top-to-bottom execution with a warning.
   Never block on a parse error.

## Scope

### In Scope

- Orchestration rules for dependency-aware task execution
- Parallel dispatch guidance with constraints
- Dependency validation in sdd-tasks skill
- Standardized dependency graph format in tasks template
- Blocked task reporting with user decision points
- Execution phase derivation from dependency graph

### Out of Scope

- Python tooling or scripts for DAG parsing (NFR-02)
- Automated retry of failed tasks (user decides)
- Cross-spec dependencies (tasks depending on tasks in other specs)
- Changes to the sdd-plan Mermaid dependency graph (that's component-level,
  this is task-level)
- Migration of existing specs 001–005 (NFR-01 — graceful fallback instead)
- Visual rendering of the task DAG (ASCII is sufficient for agent consumption)

## Constraints

- Must follow skill authoring rules (7 mandatory sections if sdd-tasks body
  changes significantly)
- sdd-tasks SKILL.md must remain under 500 lines and description under 1024
  chars
- New rules must integrate with the existing spec implementation flow in
  specs.md (the "Implementation Rule" section)
- The `[-]` skipped marker must not break existing checklist parsing that
  looks for `[x]` and `[ ]`

## Open Questions

- Should the execution phase plan be written to a file (e.g.,
  `execution-plan.md`) or only displayed in conversation? Recommendation:
  conversation only — it's ephemeral and session-specific.
- Should the max parallel agents (4) be configurable per spec?
  Recommendation: no — keep it fixed for simplicity. 4 is a reasonable
  default that balances cost and speed.

## References

- `.specify/templates/tasks.md` — current template with `Depends on:` field
- `.specify/specs/004-recursive-decomposition/tasks.md` — example of existing
  dependency graph and parallelization notes
- `.claude/rules/specs.md` — "Implementation Rule" section that governs spec
  execution
- `.claude/skills/sdd-tasks/SKILL.md` — skill to be extended with validation
