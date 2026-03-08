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
