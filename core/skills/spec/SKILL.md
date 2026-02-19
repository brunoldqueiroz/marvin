---
name: spec
description: "Plan, specify, implement, and verify features through structured phases with atomic commits. Use when building non-trivial features that benefit from upfront design."
disable-model-invocation: true
argument-hint: "[feature or change description]"
---

# Spec-Driven Development (OpenSpec)

Feature: $ARGUMENTS

## Tier Selection

Before starting, assess the task complexity and select the appropriate workflow tier.
The user can override by saying "use lightweight/standard/comprehensive".

| Tier | When to Use | Phases |
|------|-------------|--------|
| **Lightweight** | Bug fixes, small changes, single-file edits | 1 (minimal) → 3 → done |
| **Standard** | Features, refactors, multi-file changes | 0 (quick) → 1 → 2 → 3 → 4 → 5 |
| **Comprehensive** | Large migrations, new systems, cross-cutting changes | 0 (deep) → 1 → 2 → 3 → 4 → 5 |

Announce the selected tier to the user before proceeding:
> **Tier: [Standard]** — [one-line rationale]. Say "use [tier]" to override.

---

## Phase 0: Research (Standard: quick scan, Comprehensive: deep investigation)

**Skip for Lightweight tier.**

### Standard Tier — Quick Scan

Explore the codebase to understand the current state:
1. Use Glob and Grep to find affected files and patterns
2. Read key files to understand the existing architecture
3. Note relevant conventions, patterns, and potential conflicts

Summarize findings inline — no artifact needed for Standard tier.

### Comprehensive Tier — Deep Investigation

Delegate to parallel **researcher** subagents to investigate:
- How similar problems are solved in this codebase
- External references and best practices (Context7 → Exa → WebSearch)
- Edge cases, failure modes, and potential pitfalls

Output: **`changes/research.md`**
```markdown
# Research: <Feature Name>

## Codebase Analysis
[How similar things are currently done, relevant patterns found]

## External References
[Best practices, library docs, community solutions]

## Edge Cases & Risks
[Potential pitfalls discovered during research]

## Recommendations
[Synthesis — what approach the research supports]
```

Present research findings to the user before proceeding to Phase 1.

---

## Phase 1: Proposal (all tiers, depth varies)

### Lightweight Tier — Minimal Proposal

Present a brief inline proposal (no file needed):
- **What**: one sentence
- **Why**: one sentence
- **Tasks**: numbered list of steps

Get user approval, then jump to Phase 3.

### Standard + Comprehensive Tiers — Full Proposal

Create the following documents in `changes/`:

**`changes/proposal.md`:**
```markdown
# Proposal: <Feature Name>

## What
[Clear description of what will be built/changed]

## Why
[Business/technical motivation]

## Current Architecture
[What exists today — affected files, modules, data flow]
[Pain points or gaps that motivate this change]

## Scope
- In scope: [what's included]
- Out of scope: [what's explicitly excluded]

## Approach
[High-level technical approach]

## Constraints
Things that MUST NOT happen — these are more important than requirements:
- [Constraint 1: e.g., "Must not break existing API consumers"]
- [Constraint 2: e.g., "Must not add new runtime dependencies"]

## Boundaries
| Always Do | Ask First | Never Do |
|-----------|-----------|----------|
| [guaranteed behavior] | [needs user input] | [forbidden behavior] |

## Success Criteria
Measurable, testable outcomes — no vague language:
- [ ] [e.g., "All 23 existing tests pass"]
- [ ] [e.g., "New endpoint returns 200 with valid payload in < 100ms"]
- [ ] [e.g., "No new lint warnings introduced"]

## Risks
- [Risk 1 and mitigation]
- [Risk 2 and mitigation]

## Status: DRAFT | APPROVED | IMPLEMENTING | DONE
```

**`changes/tasks.md`:**
```markdown
# Tasks: <Feature Name>

Atomic implementation checklist. Each task = one logical change = one commit.

- [ ] Task 1: [Description] — [files affected]
- [ ] Task 2: [Description] — [files affected]
- [ ] Task 3: [Description] — [files affected]
- [ ] Task N: Write/update tests
- [ ] Task N+1: Run full verification
```

Present the proposal to the user for review. **Do not proceed until the user approves.**

---

## Phase 2: Specification (Standard + Comprehensive only)

**Skip for Lightweight tier.**

For each requirement, write behavioral specs in `changes/specs/`.

**`changes/specs/<feature-name>.spec.md`:**
```markdown
# Spec: <Feature Name>

## Success Criteria
[Copied from proposal for self-contained reference]
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Constraints
[Copied from proposal — what must NOT happen]
- [Constraint 1]
- [Constraint 2]

---

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

### Scenario E1: <Edge case>
GIVEN [unusual context]
WHEN [action]
THEN [graceful handling]
```

Each scenario should be:
- **Testable** — can be verified by a test or manual check
- **Specific** — no ambiguity in expected behavior
- **Independent** — doesn't depend on other scenarios running first

---

## Phase 3: Implementation (all tiers)

Update `changes/proposal.md` status to `IMPLEMENTING` (Standard/Comprehensive).

Execute each task from `changes/tasks.md`:

1. Pick the next unchecked task
2. Delegate to the **python-expert** agent for implementation
3. After implementation, delegate to the **verifier** agent for task-level checks
4. If verification passes:
   a. Check off the task in `changes/tasks.md`
   b. Delegate to the **git-expert** agent to create an atomic commit for this task
5. If verification fails, fix issues before moving to the next task
6. Repeat until all tasks are done

**One task = one commit.** This makes rollbacks trivial — any task can be reverted
independently without affecting others.

---

## Phase 4: Verification (Standard + Comprehensive only)

**Skip for Lightweight tier.**

After all tasks are complete, run a holistic verification pass:

1. Delegate to the **verifier** agent on the full changeset (not per-task, but end-to-end)
2. Walk through each spec scenario from `changes/specs/` and confirm it's satisfied
3. Check for **spec drift** — did the implementation diverge from the proposal?
   - Compare `changes/proposal.md` scope and approach against what was actually built
   - Flag any deviations for user review
4. Generate a brief compliance summary:

```markdown
## Verification Report

### Spec Compliance
- [x] Scenario 1: [pass/fail + note]
- [x] Scenario 2: [pass/fail + note]

### Success Criteria
- [x] [Criterion 1: met/unmet]
- [x] [Criterion 2: met/unmet]

### Constraint Violations
- None | [list any violations]

### Spec Drift
- None | [list deviations from proposal]
```

If issues are found, fix them before proceeding to Phase 5.

---

## Phase 5: Archive (Standard + Comprehensive only)

**Skip for Lightweight tier.**

Once verification passes:

1. Move specs from `changes/specs/` to `specs/` (permanent record)
2. Update `changes/proposal.md` status to `DONE`
3. Clean up `changes/` directory (or keep for reference)
4. Summarize what was built and any deviations from the original proposal

---

## Workflow Graph (Standard + Comprehensive Tiers)

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| research | researcher | — | changes/research.md |
| proposal | (direct) | research | changes/proposal.md + changes/tasks.md |
| spec_write | (direct) | proposal | changes/specs/*.spec.md |
| implement | python-expert (per task) | spec_write | Code changes + atomic commits |
| verify | verifier | implement | Verification report |
| archive | (direct) | verify | specs/ + DONE status |

Notes: Comprehensive Phase 0 spawns parallel researcher subagents. Implement
nodes are sequential (one task at a time, each committed atomically).

---

## Recovery

If a session fails mid-implementation (context limit, crash, interruption):

1. Start a new session
2. Point Claude at `changes/proposal.md` + `changes/tasks.md`
3. Claude reads the checked/unchecked tasks and resumes exactly where work stopped
4. All prior work is preserved because each completed task was committed atomically

**For Comprehensive tier**: consider using `/ralph` to run the remaining tasks in a
Ralph Loop. The `changes/tasks.md` file is already in the format Ralph expects —
create `prompts/PROMPT.md` pointing at the task list and let the loop handle the rest.

---

## Notes

- Always get user approval after Phase 1 before proceeding
- Each phase should leave artifacts in the filesystem (not just in chat)
- The `changes/` directory is the working area; `specs/` is the permanent archive
- If requirements change mid-implementation, update the specs first, then adjust tasks
- Atomic commits per task are mandatory — they enable safe rollbacks and clean history
