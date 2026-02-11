---
name: spec
description: Start an OpenSpec Spec-Driven Development workflow
disable-model-invocation: true
argument-hint: "[feature or change description]"
---

# Spec-Driven Development (OpenSpec)

Feature: $ARGUMENTS

## Overview

This skill implements a structured development workflow inspired by OpenSpec/SDD.
Every non-trivial change goes through: **Propose → Specify → Implement → Verify → Archive**.

## Phase 1: Proposal

Create the proposal documents:

**`changes/proposal.md`:**
```markdown
# Proposal: <Feature Name>

## What
[Clear description of what will be built/changed]

## Why
[Business/technical motivation]

## Scope
- In scope: [what's included]
- Out of scope: [what's explicitly excluded]

## Approach
[High-level technical approach]

## Risks
- [Risk 1 and mitigation]
- [Risk 2 and mitigation]

## Status: DRAFT | APPROVED | IMPLEMENTING | DONE
```

**`changes/design.md`:**
```markdown
# Design: <Feature Name>

## Architecture
[How this fits into the existing system]

## Data Model Changes
[New tables, columns, relationships — if any]

## API Changes
[New endpoints, modified signatures — if any]

## Dependencies
[New libraries, services, infrastructure — if any]

## Trade-offs
| Decision | Option A | Option B | Chosen | Why |
|----------|----------|----------|--------|-----|
```

**`changes/tasks.md`:**
```markdown
# Tasks: <Feature Name>

Atomic implementation checklist. Each task should be completable independently.

- [ ] Task 1: [Description] — [files affected]
- [ ] Task 2: [Description] — [files affected]
- [ ] Task 3: [Description] — [files affected]
- [ ] Task N: Write/update tests
- [ ] Task N+1: Run verification
```

Present the proposal to the user for review before proceeding.

## Phase 2: Specification

For each requirement, write behavioral specs in `changes/specs/`:

**`changes/specs/<feature-name>.spec.md`:**
```markdown
# Spec: <Feature Name>

## Scenario 1: <Description>
GIVEN [initial context/state]
WHEN [action is performed]
THEN [expected outcome]
AND [additional expectations]

## Scenario 2: <Description>
GIVEN [context]
WHEN [action]
THEN [outcome]

## Edge Cases

## Scenario E1: <Edge case>
GIVEN [unusual context]
WHEN [action]
THEN [graceful handling]
```

Each scenario should be:
- **Testable** — can be verified by a test or manual check
- **Specific** — no ambiguity in expected behavior
- **Independent** — doesn't depend on other scenarios running first

## Phase 3: Implementation

Execute each task from `changes/tasks.md`:

1. Pick the next unchecked task
2. Delegate to the **coder** agent for implementation
3. After implementation, run the **verifier** agent
4. If verification passes, check off the task in `changes/tasks.md`
5. If verification fails, fix issues before moving to the next task
6. Repeat until all tasks are done

Update `changes/proposal.md` status to `IMPLEMENTING` when you start.

## Phase 4: Archive

Once all tasks are verified:

1. Move specs from `changes/specs/` to `specs/` (permanent record)
2. Update `changes/proposal.md` status to `DONE`
3. Clean up `changes/` directory (or keep for reference)
4. Summarize what was built and any deviations from the original proposal

## Notes

- Always get user approval after Phase 1 before proceeding
- Each phase should leave artifacts in the filesystem (not just in chat)
- The `changes/` directory is the working area; `specs/` is the permanent archive
- If requirements change mid-implementation, update the specs first, then adjust tasks
