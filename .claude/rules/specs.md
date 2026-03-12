# Spec-Driven Development (SDD)

## When to Use SDD

Use the SDD workflow (`/sdd-*` skills) when:

- Adding a **new feature** that touches 3+ files
- Requirements are **ambiguous** and need structured clarification
- The feature involves **architectural decisions** with trade-offs
- Multiple **valid approaches** exist and the choice matters

Do NOT use SDD for: single-file fixes, typos, dependency bumps, or tasks
where the user gives precise step-by-step instructions.

## Pipeline

```
/sdd-constitution → .specify/memory/constitution.md   (once per project)
/sdd-specify      → .specify/specs/{id}-{slug}/spec.md
/sdd-plan         → .specify/specs/{id}-{slug}/plan.md
/sdd-tasks        → .specify/specs/{id}-{slug}/tasks.md
```

## Spec Numbering

- `{id}` is zero-padded 3 digits: `001`, `002`, `003`, ...
- `{slug}` is kebab-case of the feature name: `user-auth`, `sdd-integration`
- Auto-increment: read `.specify/specs/` to find the next available ID
- Example: `.specify/specs/001-user-auth/spec.md`

## Implementation Rule

When the user requests implementation of a feature that has a `tasks.md` in
`.specify/specs/`:

1. **Read** `spec.md`, `plan.md`, and `tasks.md` for full context
2. **Read** `constitution.md` if it exists (project constraints)
3. **Read** `research.md` if it exists (research findings)
4. **Delegate** to `implementer` agent with spec context in the prompt
5. After implementation, **delegate** to `reviewer` agent
6. After review, **delegate** to `tester` agent
7. Mark completed tasks in `tasks.md`

MUST load the full spec context before delegating. MUST NOT skip the
reviewer or tester phases.

### Task Execution

After reading spec context (steps 1–3) and before delegating (step 4), parse
`tasks.md` and execute tasks dependency-aware:

**DAG parsing** — Read all tasks. Extract each task's `Depends on:` field.
Tasks without `Depends on:` are treated as `Depends on: none`. Build an
in-memory dependency map keyed by task ID (T-01, T-02, ...).

**Phase derivation** — Phase 1 = tasks with `Depends on: none`. Phase N =
tasks whose all dependencies are completed in prior phases. Log the full phase
plan in conversation before execution begins so the user can review it.

**Parallel dispatch** — Within each phase, launch ready tasks in parallel via
Agent calls. Constraints: max 4 agents per batch; tasks modifying the same
file MUST NOT run in parallel (conflict risk). PREFER batching tasks of the
same agent type together (per each task's `Agent:` field). Parallelization
trades token cost for wall-clock
time — if cost is a concern, ask the user before dispatching the first
parallel batch.

**Re-evaluation loop** — After each batch completes, edit `tasks.md` to mark
finished tasks `[x]`, then append `{task-id}: {one-line status}` to
`{spec-dir}/claude-progress.txt`. This file survives context resets and
prevents redundant work on session restart. Then derive the next batch of
ready tasks and repeat.

**Plan checkpoint** — Before deriving the next batch, check if any task in
the batch failed (`[-]`) or returned SIGNAL:BLOCKED. If all passed, continue
silently. If any failed, report what happened and ask the user: (a) continue
as-is, (b) adjust plan, or (c) abort.

**Blocked task handling** — If a task's dependency is marked `[-]` (skipped)
or failed, report which task is blocked and which dependency is unmet. Ask the
user: skip this task too (`[-]`), retry the failed dependency, or abort spec
execution. Never silently proceed past a blocked task.

**Deadlock detection** — If no tasks are ready but uncompleted tasks remain,
report a deadlock (likely circular dependency or failed prerequisite) and halt.

**Graceful fallback** — If `tasks.md` parsing fails (malformed format), fall
back to sequential top-to-bottom execution with a warning. Never block on a
parse error (NFR-04). Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped.

**Stage-1-only review** — For low-risk changes where ALL modified files are
Markdown (.md), config (.yml, .yaml, .json, .toml, .cfg), or documentation,
the orchestrator may dispatch the reviewer with `stage: 1` in the task prompt
to skip the deep review phase (Stage 2). Any .py or code file in the changeset
triggers a full two-stage review.

**Per-task commit convention** — The implementer agent uses the commit message
format `feat({spec-id}-T-{task-id}): <description>` when committing task work.
This enables `git log --grep="011-agent-hardening"` to find all commits for a
spec. The convention is advisory when agents run in worktree isolation (the
orchestrator handles final commit integration).

## Research Integration

When `/sdd-specify` identifies unknowns (unfamiliar technology, external APIs,
multiple viable approaches), delegate to the `researcher` agent following
`@.claude/rules/research.md`. Save research output to
`.specify/specs/{id}-{slug}/research.md`.

## Sub-Specs

Use sub-specs when a single task in a parent plan is itself complex enough to
warrant the full SDD cycle.

- Sub-spec path: `.specify/specs/{parent-id}-{slug}/{sub-id}-{sub-slug}/`
- Sub-spec IDs are zero-padded 3-digit, scoped to parent — e.g.,
  `004-recursive-decomposition/001-complexity-engine/`
- Sub-specs follow the full SDD cycle independently: specify → plan → tasks →
  implement → review → test
- When a sub-spec completes, the parent task that spawned it is marked done
- Parent plan references sub-spec outputs (not sub-spec internals)
- **Depth limit: max 2 levels** (parent → child → grandchild). If a grandchild
  spec is still too complex, escalate to a new top-level spec instead.

## Spike-First Pattern

Run a spike before planning when the approach is uncertain.

- **When to spike**: (a) new technology not used in the project, (b) uncertain
  feasibility, (c) performance-critical path needing validation
- Spikes are **time-boxed**: max 15 minutes of agent time
- Spike tasks use worktree isolation (`isolation: "worktree"`)
- Findings written to `.specify/specs/{id}-{slug}/spike-{component}.md`
- Findings format: feasibility (yes/no), approach validated, risks discovered,
  recommendation
- If spike invalidates the planned approach, plan **MUST** be updated before
  implementation proceeds
- If spike exceeds the time-box, report partial findings — user decides next step

## Directory Structure

```
.specify/
├── memory/
│   └── constitution.md              # project principles (created by /sdd-constitution)
├── specs/
│   ├── 001-feature-name/
│   │   ├── spec.md                  # what + why
│   │   ├── research.md              # optional: pre-spec research
│   │   ├── plan.md                  # how (implementation strategy)
│   │   ├── tasks.md                 # actionable checklist
│   │   ├── spike-{component}.md     # spike findings (optional)
│   │   └── 001-sub-feature/         # sub-spec (optional)
│   │       ├── spec.md
│   │       ├── plan.md
│   │       └── tasks.md
│   └── 002-another-feature/
│       └── ...
└── templates/                       # templates used by /sdd-* skills
    ├── constitution.md
    ├── research.md
    ├── spec.md
    ├── plan.md
    └── tasks.md
```
