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

## Directory Structure

```
.specify/
├── memory/
│   └── constitution.md          # project principles (created by /sdd-constitution)
├── specs/
│   ├── 001-feature-name/
│   │   ├── spec.md              # what + why
│   │   ├── research.md          # optional: pre-spec research
│   │   ├── plan.md              # how (implementation strategy)
│   │   └── tasks.md             # actionable checklist
│   └── 002-another-feature/
│       └── ...
└── templates/                   # templates used by /sdd-* skills
    ├── constitution.md
    ├── research.md
    ├── spec.md
    ├── plan.md
    └── tasks.md
```
