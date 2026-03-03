---
name: spec-check
user-invocable: true
description: >
  PRD and spec readiness validator. Use when: user wants to validate prd.json
  quality before running ralph.sh, or validate a design spec before PRD
  generation.
  Triggers: "/spec-check", "check prd", "validate specs", "is prd ready",
  "check spec", "validate spec", "is spec ready".
  Do NOT use for creating PRDs (prd), creating specs (spec), converting PRDs
  to JSON (ralph), or running the loop (scripts/ralph.sh).
tools:
  - Read
  - Glob
  - Grep
metadata:
  author: bruno
  version: 1.1.0
  category: workflow
---

# Spec Check — PRD & Spec Readiness Validator

You validate `prd.json` files and design specs against quality checks. This
prevents wasted autonomous iterations on under-specified or poorly structured
requirements.

## Workflow

### Step 0: Detect Mode

Determine which mode to run based on user input:

- **Spec mode**: User says "check spec", "validate spec", provides a spec path,
  or there is no `prd.json` but specs exist in `spec/draft/`
- **PRD mode** (default): User says "check prd", or no spec-related trigger

If ambiguous, ask the user which they want to validate.

For **spec mode**, jump to [Spec Mode Checks](#spec-mode-checks).
For **PRD mode**, continue to Step 1 below.

---

## PRD Mode

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

---

## Spec Mode Checks

### Step 1: Load Spec

1. If the user provided a specific spec path, read that file
2. Otherwise, search `spec/draft/*.md` for specs
3. If multiple specs exist, ask the user which one to check
4. If no spec found, tell the user: "No spec found. Run `/spec` first to
   create a design spec."

### Step 2: Run Spec Checks

Run all 6 checks. Each scores 0–2 points (except checks 5–6 which are 0–1).

#### Check S1: Context Quality (0–2 pts)

Evaluate the Context section.

| Condition | Score |
|-----------|-------|
| Has substance: cites evidence, metrics, or prior art | 2 |
| Present but generic or restates the What section | 1 |
| Missing or placeholder text | 0 |

Report: quote key evidence found or note what's missing.

#### Check S2: Change Table (0–2 pts)

Evaluate the Change Table section.

| Condition | Score |
|-----------|-------|
| Has CREATE/MODIFY entries AND at least one NOT CREATE entry | 2 |
| Has CREATE/MODIFY entries but no NOT CREATE entry | 1 |
| Missing, empty, or only placeholder rows | 0 |

Report: count of CREATE, MODIFY, NOT CREATE entries.

#### Check S3: Design Rules (0–2 pts)

Evaluate the Design Rules section.

| Condition | Score |
|-----------|-------|
| >= 2 rules using MUST/MUST NOT/PREFER with rationale | 2 |
| 1 rule or rules lack rationale | 1 |
| Missing or no rules | 0 |

Report: count of rules by type (MUST/MUST NOT/PREFER).

#### Check S4: Scope (0–2 pts)

Evaluate the Scope section.

| Condition | Score |
|-----------|-------|
| Has both "In scope" and "Out of scope" with specific items | 2 |
| Has one of the two, or items are vague | 1 |
| Missing or placeholder | 0 |

Report: summarize scope boundaries.

#### Check S5: Scenarios (0–1 pt)

Evaluate the Scenarios section.

| Condition | Score |
|-----------|-------|
| >= 1 scenario in GIVEN/WHEN/THEN format | 1 |
| Missing or not in GIVEN/WHEN/THEN format | 0 |

Report: count of scenarios and edge cases.

#### Check S6: Open Questions (0–1 pt)

Check for unresolved `[NEEDS CLARIFICATION]` markers.

| Condition | Score |
|-----------|-------|
| No unresolved [NEEDS CLARIFICATION] markers | 1 |
| Has unresolved [NEEDS CLARIFICATION] markers | 0 |

Report: list any unresolved questions.

### Step 3: Score and Verdict

Sum all check scores. Maximum = 10.

| Score | Verdict | Action |
|-------|---------|--------|
| 8–10 | READY | "Spec is ready for `/prd` generation" |
| 5–7 | REVIEW | "Spec needs attention on flagged items before proceeding to `/prd`" |
| 0–4 | BLOCK | "Spec is not ready. Fix flagged issues and re-run `/spec-check`" |

### Step 4: Display Spec Report

Output a structured report:

```
## Spec Check Report

| # | Check | Score | Details |
|---|-------|-------|---------|
| S1 | Context quality | 2/2 | Cites metrics and prior spec |
| S2 | Change table | 2/2 | 3 CREATE, 2 MODIFY, 1 NOT CREATE |
| S3 | Design rules | 2/2 | 2 MUST, 1 MUST NOT, 1 PREFER |
| S4 | Scope | 2/2 | Both in-scope and out-of-scope defined |
| S5 | Scenarios | 1/1 | 2 scenarios, 1 edge case |
| S6 | Open questions | 1/1 | No unresolved questions |

**Total: 10/10 — READY**

Run `/prd` to generate implementation stories from this spec.
```

If verdict is REVIEW or BLOCK, add a "Recommendations" section listing specific
fixes for each failing check.
