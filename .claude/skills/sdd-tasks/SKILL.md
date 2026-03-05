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
  version: 1.0.0
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
