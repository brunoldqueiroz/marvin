---
name: spec-check
user-invocable: true
description: >
  PRD readiness validator for Ralph loop. Use when: user wants to validate
  prd.json quality before running ralph.sh.
  Triggers: "/spec-check", "check prd", "validate specs", "is prd ready".
  Do NOT use for creating PRDs (prd), converting PRDs to JSON (ralph), or
  running the loop (scripts/ralph.sh).
tools:
  - Read
  - Glob
  - Grep
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# Spec Check — PRD Readiness Validator

You validate a `prd.json` file against quality checks before it enters the
Ralph Loop. This prevents wasted autonomous iterations on under-specified or
poorly structured requirements.

## Workflow

### Step 1: Load prd.json

1. Read `prd.json` from the project root
2. If it doesn't exist, tell the user: "No prd.json found. Run `/ralph` first
   to convert a PRD to JSON."
3. Parse and validate it is valid JSON with a `userStories` array

### Step 2: Run Checks

Run all 6 checks. Each scores 0–2 points (except check 6 which is a bonus).

#### Check 1: Criteria Count (0–2 pts)

Count acceptance criteria per story.

| Condition | Score |
|-----------|-------|
| Every story has >= 2 criteria | 2 |
| At least one story has < 2 criteria | 1 |
| Any story has 0 criteria | 0 |

Report: list stories with criteria counts.

#### Check 2: Verify Coverage (0–2 pts)

Calculate the percentage of criteria with `verify` != `"manual"`.

Backward compatibility: if a criterion is a plain string (old format), count it
as `manual`.

| Condition | Score |
|-----------|-------|
| >= 70% automated verify | 2 |
| 50–69% automated verify | 1 |
| < 50% automated verify | 0 |

Report: `X/Y criteria have automated verify commands (Z%)`.

#### Check 3: Dependency Order (0–2 pts)

Verify stories are ordered by priority (ascending) and that the order makes
architectural sense: data models before logic, logic before API, API before UI.

| Condition | Score |
|-----------|-------|
| Priorities ascending, order makes sense | 2 |
| Priorities ascending but questionable order | 1 |
| Priorities not ascending or clear dependency violations | 0 |

Report: list stories in priority order with brief dependency assessment.

#### Check 4: Story Size (0–2 pts)

Check criteria count per story. Large stories risk exceeding context windows.

| Condition | Score |
|-----------|-------|
| All stories have <= 8 criteria | 2 |
| At least one story has 9–12 criteria | 1 |
| Any story has > 12 criteria | 0 |

Report: flag oversized stories with recommendation to decompose.

#### Check 5: Quality Gates (0–2 pts)

Check that every story has at least one criterion that verifies code quality
(linting, testing, type checking).

Quality gate patterns to look for in `verify` or `then` fields:
- `pytest`, `ruff`, `mypy`, `eslint`, `npm test`, `cargo test`

| Condition | Score |
|-----------|-------|
| Every story has >= 1 quality gate | 2 |
| At least one story missing quality gate | 1 |
| No stories have quality gates | 0 |

Report: list which stories have/lack quality gates.

#### Check 6: Constitution Presence (bonus, 0–1 pt)

Check if `prd.json` has a `constitution` field with at least one `must` entry.

| Condition | Score |
|-----------|-------|
| Constitution present with >= 1 must | 1 |
| No constitution or empty | 0 |

Report: list constitution rules count or note absence.

### Step 3: Score and Verdict

Sum all check scores. Maximum = 11 (10 base + 1 bonus).

| Score | Verdict | Action |
|-------|---------|--------|
| 9–11 | READY | "prd.json is ready for `./scripts/ralph.sh`" |
| 6–8 | REVIEW | "prd.json needs attention on flagged items before running ralph.sh" |
| 0–5 | BLOCK | "prd.json is not ready. Fix flagged issues and re-run `/spec-check`" |

### Step 4: Display Report

Output a structured report:

```
## Spec Check Report

| # | Check | Score | Details |
|---|-------|-------|---------|
| 1 | Criteria count | 2/2 | All stories have >= 2 criteria |
| 2 | Verify coverage | 1/2 | 8/12 criteria automated (67%) |
| 3 | Dependency order | 2/2 | Priorities ascending, order OK |
| 4 | Story size | 2/2 | Max 6 criteria per story |
| 5 | Quality gates | 2/2 | All stories have quality gates |
| 6 | Constitution | 1/1 | 2 must, 1 must_not, 1 prefer |

**Total: 10/11 — READY**

Run `./scripts/ralph.sh` to start autonomous implementation.
```

If verdict is REVIEW or BLOCK, add a "Recommendations" section listing specific
fixes for each failing check.
