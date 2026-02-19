---
name: debug
description: "Systematic root cause analysis: reproduce, isolate, fix, verify. Use when a bug needs methodical investigation rather than a quick patch."
disable-model-invocation: true
argument-hint: "[bug description, error message, or failing test]"
---

# Systematic Debugging

Bug report: $ARGUMENTS

## Process

### 1. Reproduce

Delegate to the **python-expert** agent:
- Parse the bug report from $ARGUMENTS
- Find the relevant code and understand the expected vs actual behavior
- Create a minimal reproduction (test case, script, or steps)
- Document the reproduction in `changes/debug-repro.md`:

```markdown
# Bug Reproduction: <title>

## Symptom
[What the user observes]

## Expected Behavior
[What should happen]

## Reproduction Steps
1. [Step 1]
2. [Step 2]
3. [Observed failure]

## Environment
[Relevant versions, config, OS if applicable]
```

If the bug cannot be reproduced, report back to the user with findings before
proceeding.

### 2. Isolate

Delegate to the **python-expert** agent:
- Use binary search, log instrumentation, or test isolation to narrow the cause
- Identify the specific file, function, and line(s) responsible
- State a clear hypothesis: "The bug occurs because X when Y"
- Update `changes/debug-repro.md` with the isolation findings:

```markdown
## Root Cause Hypothesis
[Clear statement of why the bug occurs]

## Evidence
- [File:line — what's wrong]
- [Test or log output confirming the hypothesis]
```

### 3. Fix

Delegate to the **python-expert** agent:
- Fix the root cause (not just the symptom)
- Write a regression test that fails without the fix and passes with it
- Keep the fix minimal — do not refactor surrounding code

### 4. Verify

Delegate to the **verifier** agent:
- Run the new regression test — confirm it passes
- Run the full test suite — confirm no regressions
- Check lint and type errors
- Validate the fix against the original reproduction steps

### 5. Summary

Present to the user:
- **Root cause**: What was wrong and why
- **Fix**: What was changed (files and lines)
- **Regression test**: What test was added to prevent recurrence
- **Suite status**: Full test results

## Workflow Graph

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| reproduce | python-expert | — | changes/debug-repro.md + reproduction |
| isolate | python-expert | reproduce | Root cause hypothesis |
| fix | python-expert | isolate | Fix + regression test |
| verify | verifier | fix | Verification report |
| summary | (direct) | verify | User-facing summary |

All nodes are sequential — each step depends on the findings of the previous.

## Notes
- Always reproduce before fixing — never guess at a fix without evidence
- The regression test is mandatory — a fix without a test is incomplete
- Fix the root cause, not the symptom (e.g., fix the null source, not the NPE handler)
- Keep `changes/debug-repro.md` as a record of the investigation
- If the root cause spans multiple domains, delegate to the relevant specialist
