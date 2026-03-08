# Spec — TDD Guidance in Pipeline

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

The SDD pipeline treats testing as a final phase: implement → review → test.
This ordering works for configuration changes and documentation updates, but
for tasks involving complex logic, algorithmic code, or behavioral contracts,
writing tests first would catch design issues earlier and produce better
interfaces.

Currently, nothing in the pipeline suggests or supports a test-first workflow.
The `sdd-tasks` skill always generates tasks in implement-then-test order, and
`specs.md` Implementation Rule hardcodes the sequence as step 4 (implementer)
→ step 5 (reviewer) → step 6 (tester). An agent following these rules has no
guidance on when test-first would be more effective.

The problem is not that test-after is wrong — it's that the pipeline has no
mechanism to suggest the more appropriate ordering based on task characteristics.

## Desired Outcome

After implementation:

1. The `sdd-tasks` skill can generate test-first task patterns when
   appropriate: `write test → implement → verify test passes`.
2. `specs.md` Implementation Rule acknowledges that tester agents may be
   dispatched before or alongside implementer agents for test-first tasks.
3. Clear guidance exists on when TDD is appropriate vs when test-after is
   fine, based on task characteristics (not developer preference).
4. The guidance is advisory, not enforced — the pipeline suggests TDD when
   appropriate but does not block non-TDD workflows.
5. Existing pipeline behavior is unchanged for tasks where test-after is
   appropriate (config, docs, rules-only changes).

## Requirements

### Functional

1. **FR-01: TDD applicability heuristic** — Define criteria for when a task
   should use test-first ordering:
   - Complex logic: algorithmic code, state machines, parsers, validators
   - Behavioral contracts: public APIs, interface implementations
   - Bug fixes: regression tests should be written before the fix
   - Data transformations: ETL logic, data pipeline steps
   When none of these apply (config changes, documentation, rule edits,
   skill/agent metadata), test-after is the default.

2. **FR-02: Test-first task pattern in sdd-tasks** — Update the `sdd-tasks`
   skill to recognize test-first candidates and generate a 3-task sequence:
   (a) `T-XX: [TEST-FIRST] Write test` — tester agent writes failing tests
   that define the expected behavior.
   (b) `T-YY: Implement` — implementer agent writes code to make tests pass.
   (c) `T-ZZ: Verify` — tester agent runs the full test suite to confirm.
   The `[TEST-FIRST]` annotation signals the pattern to the executor.

3. **FR-03: Updated Implementation Rule** — Add a note to `specs.md` Task
   Execution that when a task has a `[TEST-FIRST]` annotation, the tester
   agent is dispatched first (to write tests), then the implementer, then
   the tester again (to verify). The existing sequential dispatch handles
   this naturally via dependencies.

4. **FR-04: Advisory, not enforced** — The TDD heuristic is a suggestion.
   The `sdd-tasks` skill should note when it recommends test-first but allow
   the user to override during the confirmation step. Non-TDD workflows
   remain the default for tasks that don't match the heuristic.

### Non-Functional

1. **NFR-01: No new files or skills** — Changes are contained within
   `specs.md` and `sdd-tasks/SKILL.md`.

2. **NFR-02: Backward compatible** — Existing task patterns (implement →
   review → test) continue to work unchanged. The `[TEST-FIRST]` annotation
   is additive.

3. **NFR-03: sdd-tasks SKILL.md budget** — Must remain under 500 lines
   after changes.

4. **NFR-04: Minimal pipeline overhead** — The TDD heuristic should add
   zero overhead for tasks that don't match (no extra prompts, no extra
   agent dispatches). Only test-first candidates incur the 3-task pattern.

## Scope

### In Scope

- TDD applicability heuristic (when to suggest test-first)
- Test-first task pattern (`[TEST-FIRST]` annotation) in sdd-tasks
- Updated Implementation Rule in specs.md to handle test-first dispatch
- Advisory guidance (suggest, don't enforce)

### Out of Scope

- Changes to the tester agent itself (it already writes and runs tests)
- Changes to the implementer agent
- Changes to the reviewer agent or review phase ordering
- Automated test coverage measurement or enforcement
- Language-specific testing frameworks or conventions
- Changes to the sdd-plan or sdd-specify skills

## Constraints

- sdd-tasks SKILL.md must stay under 500 lines (currently ~103 lines)
- specs.md must stay under 170 lines (currently ~159 lines)
- The 7-step Implementation Rule sequence (1–7) is unchanged — TDD
  guidance is an annotation within Task Execution, not a new step
- The `[TEST-FIRST]` pattern uses the existing dependency mechanism
  (tester task → implementer task → verify task) — no new execution logic

## Open Questions

- Should the `[TEST-FIRST]` annotation be applied automatically by
  sdd-tasks based on the heuristic, or should it always require user
  confirmation? Recommendation: apply automatically, but show in the
  confirmation step so the user can remove it.

## References

- `.claude/skills/sdd-tasks/SKILL.md` — current task generation (103 lines)
- `.claude/rules/specs.md` — Implementation Rule and Task Execution
  (lines 32–94)
- `.specify/templates/tasks.md` — task template structure
