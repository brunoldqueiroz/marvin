---
name: checklist-runner
user-invocable: true
description: >
  Generic checklist executor. Load proactively when user wants to validate work against a
  checklist. Use when: user wants to run, verify, or score a Markdown checklist
  against the current project state.
  Triggers: "run checklist", "verify checklist", "score this", "check against",
  "validate checklist", "run quality check", "checklist report".
  Do NOT use for: writing new checklists (sdd-tasks), code review with
  judgment (reviewer agent), or security vulnerability audits (security agent).
tools:
  - Read
  - Glob
  - Grep
  - "Bash(pytest*)"
  - "Bash(ruff*)"
  - "Bash(mypy*)"
  - "Bash(git diff*)"
  - "Bash(git status*)"
  - Write
  - Edit
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# Checklist Runner

Execute and score any Markdown checklist file against the current project state.

## Modes

- **yolo** (default) — run all items autonomously, report at the end
- **interactive** — pause after each section for user confirmation

Determine mode from the user's prompt. Default to `yolo` unless the user says
"interactive", "step by step", or "one at a time".

## Workflow

1. **Read** the checklist file (path from user prompt or auto-detect via Glob)
2. **Parse** all checklist items (`- [ ]` lines) grouped by section (`##` headers)
3. **Evaluate** each item:
   - Run relevant commands (pytest, ruff, mypy, git diff) to verify claims
   - Read files to confirm existence or content
   - Grep for patterns mentioned in the item
4. **Assign verdict** per item:
   - **PASS** — item fully satisfied
   - **FAIL** — item not satisfied (include reason)
   - **PARTIAL** — item partially satisfied (explain what's missing)
   - **N/A** — item not applicable to current context (explain why)
5. **Calculate score**: `(PASS + 0.5 * PARTIAL) / (total - N/A) * 100`
6. **Determine threshold**:
   - >= 90% — **APPROVED**
   - 70-89% — **NEEDS_WORK**
   - < 70% — **FAIL**
7. **Generate report** (print to stdout or write to file if user specifies)

## Output Format

```markdown
# Checklist Report: [name]

## Score: [N]% — [APPROVED|NEEDS_WORK|FAIL]

## Results

- [x] PASS: [item text]
- [ ] FAIL: [item text] — [reason]
- [~] PARTIAL: [item text] — [what's missing]
- [-] N/A: [item text] — [why]

## Summary

Total: N | Pass: N | Fail: N | Partial: N | N/A: N
```

## Rules

- MUST read the checklist file fully before evaluating any item
- MUST run actual commands to verify — never assume an item passes
- MUST NOT modify the original checklist file unless explicitly asked
- If a checklist item is ambiguous, evaluate conservatively (PARTIAL over PASS)
- If no checklist path is provided, search for `.md` files with `- [ ]` items
