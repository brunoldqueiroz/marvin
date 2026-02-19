---
name: tdd
description: "Enforce a RED-GREEN-REFACTOR test-driven development cycle. Use when building features where correctness is critical and tests should drive the design."
disable-model-invocation: true
argument-hint: "[feature or requirement to implement with TDD]"
---

# Test-Driven Development

Requirement: $ARGUMENTS

## Process

### 1. Understand

Analyze $ARGUMENTS to determine:
- What behavior needs to be implemented
- Which test framework is in use (detect from project: pytest, jest, go test, etc.)
- Existing test patterns and conventions (read a few test files for style)
- Where new tests and implementation should live

If requirements are ambiguous, ask the user before proceeding.

### 2. RED — Write Failing Tests

Delegate to the **python-expert** agent:
- Write test cases that describe the desired behavior
- Cover the happy path, edge cases, and error conditions
- Follow existing test conventions and naming patterns
- Tests MUST be complete and syntactically valid

Then delegate to the **verifier** agent:
- Run the new tests
- Confirm they ALL FAIL (red state)
- If any test passes, it's testing existing behavior — flag it and adjust

Do not proceed until the verifier confirms red state.

### 3. GREEN — Minimum Implementation

Delegate to the **python-expert** agent:
- Write the minimum code to make all failing tests pass
- No extra features, no premature optimization
- Focus on correctness, not elegance

Then delegate to the **verifier** agent:
- Run the full test suite (not just new tests)
- Confirm ALL tests pass (green state)
- If any test fails, return to python-expert to fix

Do not proceed until the verifier confirms green state.

### 4. REFACTOR — Improve the Code

Delegate to the **python-expert** agent:
- Improve code quality: reduce duplication, clarify naming, simplify logic
- Improve test quality: reduce duplication, improve assertions, add clarity
- Do NOT change behavior — tests must continue to pass unchanged

Then delegate to the **verifier** agent:
- Run the full test suite
- Confirm ALL tests still pass (still green)
- If any test fails, the refactor changed behavior — revert and retry

### 5. Summary

Present to the user:
- Tests written (count and what they cover)
- Implementation summary
- Refactoring changes made
- Full suite status (pass/fail count)

## Workflow Graph

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| understand | (direct) | — | Requirements + framework detected |
| red_write | python-expert | understand | Failing test files |
| red_verify | verifier | red_write | Confirmed red state |
| green_impl | python-expert | red_verify | Minimum implementation |
| green_verify | verifier | green_impl | Confirmed green state |
| refactor | python-expert | green_verify | Improved code + tests |
| refactor_verify | verifier | refactor | Confirmed still green |
| summary | (direct) | refactor_verify | User-facing summary |

All nodes are sequential — each verify step must confirm state before proceeding.

## Notes
- Never skip the RED phase — writing tests after implementation defeats TDD
- The GREEN phase implements the MINIMUM to pass, not the ideal solution
- Refactoring must not change behavior — if tests break, revert the refactor
- Run the FULL test suite at each verify step, not just the new tests
- If the user says "skip refactor", go directly from green_verify to summary
