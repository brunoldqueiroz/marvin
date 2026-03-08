# Tasks — {Feature Name}

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [ ] **T-01: {task_1_title}** — {brief description}
  - Files: {files to touch}
  - Agent: {implementer | reviewer | tester | security}
  - Depends on: none

- [ ] **T-02: {task_2_title}** — {brief description}
  - Files: {files to touch}
  - Agent: {implementer | reviewer | tester | security}
  - Depends on: none

- [ ] **T-03: {task_3_title}** — {brief description}
  - Files: {files to touch}
  - Agent: {implementer | reviewer | tester | security}
  - Depends on: T-01, T-02

## Execution Phases

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | T-01, T-02 | Yes | No shared files |
| 2 | T-03 | No | Depends on phase 1 |

## Task Dependency Graph

```
T-01 ──┐
       ├──→ T-03
T-02 ──┘
```

## Acceptance Criteria

- [ ] All tasks completed
- [ ] Tests pass (`pytest`)
- [ ] Linter passes (`ruff check`)
- [ ] Type checker passes (`mypy`)
- [ ] Code reviewed (reviewer agent)
