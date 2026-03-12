---
name: sdd-tasks
user-invocable: true
description: >
  SDD workflow — generate actionable task checklist from plan. Use when: user
  invokes /sdd-tasks, a plan.md exists and needs to be broken into delegatable
  tasks, or the user wants an agent-ready checklist before implementation.
  Triggers: "/sdd-tasks", "create tasks from plan", "generate checklist",
  "break plan into tasks", "task checklist".
  Do NOT use for project constitution (sdd-constitution), writing feature specs
  (sdd-specify), or creating implementation strategy (sdd-plan). This skill
  produces task checklists, not strategy documents.
tools:
  - Read
  - Glob
  - Write
  - Edit
  - AskUserQuestion
metadata:
  author: bruno
  version: 1.2.0
  category: workflow
---

# SDD Tasks

You generate an actionable task checklist from an existing plan — each task is
a discrete, delegatable unit of work with clear ownership and dependencies.

## Workflow

1. **Find the plan**: If the user specifies a spec ID or slug, read that plan.
   Otherwise, list `.specify/specs/` and ask which plan to use.
2. **Read context**:
   - `.specify/specs/{id}-{slug}/plan.md` (required — abort if missing)
   - `.specify/specs/{id}-{slug}/spec.md` (for acceptance criteria)
   - `.specify/memory/constitution.md` (for quality constraints)
3. **Read template**: Read `.specify/templates/tasks.md` for structure.
4. **Generate tasks**: For each component in the plan, create tasks that:
   - Have a clear, imperative title (e.g., "Add auth middleware to API router")
   - Specify which files to touch
   - Assign the appropriate agent (implementer, reviewer, tester, security)
   - Declare dependencies on other tasks
   - Are small enough to be completed in one agent delegation

   If the plan contains a "Sub-Specs" section, check each listed sub-spec and
   emit one task per sub-spec with type `[SUB-SPEC]`:

   > `**T-XX: [SUB-SPEC] {sub-spec name}** — Full SDD cycle for {description}. Blocks: {downstream task IDs}.`

   Sub-spec tasks represent the complete SDD lifecycle (specify → plan → tasks →
   implement → review → test) and are driven by the user, not assigned to a
   single agent. They MUST be placed before any downstream tasks that depend on
   their output.
4b. **Validate dependency graph**: Before writing tasks.md, walk the full
    dependency graph and check for:

    (a) **Cycle detection**: For each task, walk the `Depends on:` chain
        transitively using DFS. If a task ID appears in the current DFS path
        (not just the globally visited set), a cycle exists — report an error
        listing the full chain (e.g., "Cycle detected: T-01 → T-03 → T-01").
        Errors block writing.
    (b) **Missing reference**: If a task declares `Depends on: T-XX` but T-XX
        does not exist in the task list, report an error. Errors block writing.
    (c) **Self-reference**: If a task's `Depends on:` includes its own ID,
        report an error. Errors block writing.
    (d) **Isolated task warning**: If a task has `Depends on: none` AND no
        other task depends on it, emit an info-level note (not blocking). This
        may indicate a missing dependency but could also be intentional (e.g.,
        a standalone documentation task).

    If any errors are found, present them to the user and abort. Fix the
    tasks before retrying. Info-level notes are displayed but do not block.
4c. **TDD note**: For tasks involving complex logic, public APIs, bug fixes,
    or data transformations, consider suggesting a test-first approach (write
    test → implement → verify) during the confirmation step (step 7). This is
    advisory — the user decides whether to adopt it.

5. **Add acceptance criteria**: Derive from the spec's requirements and the
   constitution's quality standards.
6. **Write tasks**: Create `.specify/specs/{id}-{slug}/tasks.md`.
7. **Confirm**: Show the user the task list and ask for approval.

## Output

- File: `.specify/specs/{id}-{slug}/tasks.md`
- Format: Markdown checklist following the template structure

## Constraints

- MUST have a plan.md before creating tasks — abort with a clear message
  if plan.md does not exist for the given ID
- MUST respect execution order from the plan — task dependencies must reflect
  the plan's sequencing
- MUST assign an agent to each task (implementer | reviewer | tester | security)
- MUST keep tasks atomic — one task should map to one agent delegation
- MUST include acceptance criteria derived from the spec
- MUST NOT include implementation details — tasks describe what, not how
- MUST ask the user for approval before finalizing
- MUST emit a `[SUB-SPEC]` task for each sub-spec listed in the plan's
  "Sub-Specs" section — do not flatten sub-spec work into regular tasks
- Sub-spec tasks MUST list the IDs of all downstream tasks they block
- Sub-spec tasks MUST NOT be assigned to a single agent — they represent the
  full SDD lifecycle driven by the user
- MUST validate the dependency graph (step 4b) before writing tasks.md —
  cycle, missing-reference, and self-reference errors block writing; isolated
  task warnings are reported but do not block
- TDD suggestions are advisory — the user decides during confirmation (step 7)
