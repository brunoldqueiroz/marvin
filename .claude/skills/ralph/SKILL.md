---
name: ralph
user-invocable: true
description: >
  PRD to JSON converter for Ralph loop. Use when: user has a markdown PRD and
  wants to prepare it for autonomous execution.
  Triggers: "/ralph", "convert PRD", "create prd.json", "prepare for ralph".
  Do NOT use for creating PRDs (prd), running the loop (scripts/ralph.sh), or
  implementing features directly.
tools:
  - Read
  - Write
  - Glob
  - Grep
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# PRD to JSON Converter

You convert a markdown PRD (from `tasks/prd-*.md`) into a structured
`prd.json` file for the Ralph Loop autonomous implementation workflow.

## Workflow

### Step 1: Find the PRD

1. Search for PRD files: `tasks/prd-*.md`
2. If multiple PRDs exist, list them and ask the user which one to convert
3. If no PRDs exist, tell the user to run `/prd` first
4. Read the selected PRD file

### Step 2: Convert to JSON

Transform the markdown PRD into this JSON structure:

```json
{
  "project": "<project-name>",
  "branchName": "ralph/<feature-name>",
  "description": "<one-line feature summary>",
  "userStories": [
    {
      "id": "US-001",
      "title": "<brief title>",
      "description": "As a [role], I want [feature] so that [value]",
      "acceptanceCriteria": [
        "Specific, testable requirement",
        "Quality gate: ruff/mypy/pytest passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Field rules:
- `project`: derive from the repository name or PRD title
- `branchName`: always prefix with `ralph/`, use kebab-case feature name
- `priority`: 1 = highest (implement first); preserve dependency order from PRD
- `passes`: always `false` — the loop drives these to `true`
- `notes`: always empty string — the loop populates this across iterations
- `acceptanceCriteria`: copy verbatim from PRD; ensure each is testable

### Step 3: Validate

Before writing, validate the conversion:

1. **Story size** — Each story must fit in one Claude Code context window. If a
   story has more than 8 acceptance criteria or describes multiple independent
   changes, flag it and suggest decomposition.

2. **Dependency order** — Stories must be ordered so that dependencies come
   first. Verify: schema/models → backend logic → API endpoints → UI components.
   If out of order, reorder and adjust priority numbers.

3. **Testable criteria** — Every acceptance criterion must be verifiable by
   automated tools or explicit checks. Flag vague criteria like "works
   correctly", "is fast", "handles errors properly" and suggest specific
   replacements.

4. **Quality gates** — Every story must include at least one quality gate
   criterion (e.g., "ruff check passes", "pytest passes").

### Step 4: Handle existing prd.json

If `prd.json` already exists in the project root:

1. Read it and check the `branchName`
2. If the branch name differs from the new PRD's branch:
   - Warn the user: "An existing prd.json targets branch `{old-branch}`. The
     new PRD targets `ralph/{new-feature}`."
   - Suggest: "Archive the current run first by moving prd.json and
     progress.txt to `archive/YYYY-MM-DD-{feature}/`, or the ralph.sh script
     will handle this automatically on the next run."
   - Ask the user whether to overwrite or abort
3. If the branch name matches, ask whether to reset all stories to
   `passes: false` or keep current progress

### Step 5: Write and summarize

1. Write `prd.json` to the project root
2. Display a summary table:

```
| ID     | Title                      | Priority | Criteria |
|--------|----------------------------|----------|----------|
| US-001 | User registration endpoint | 1        | 6        |
| US-002 | User login endpoint        | 2        | 6        |
```

3. Show total story count and next step:
   "Created prd.json with {N} stories. Run `./scripts/ralph.sh` to start
   autonomous implementation."

## Validation Examples

### Good acceptance criterion
- "POST /api/users returns 201 with JSON body containing `id` and `email`"
- "ruff check passes with no violations"
- "pytest passes with >= 2 tests covering the endpoint"

### Bad acceptance criterion (flag these)
- "Works correctly" → Suggest: "Returns expected output for valid input"
- "Is performant" → Suggest: "Response time < 500ms for 1000 records"
- "Handles errors" → Suggest: "Returns 400 with error message for invalid input"

## Error Handling

- If the PRD has no user stories section, tell the user: "This PRD has no user
  stories. Run `/prd` to generate a properly structured PRD."
- If a story has no acceptance criteria, flag it: "Story US-NNN has no
  acceptance criteria. Each story needs at least one testable criterion."
- If the PRD describes a single massive feature with no decomposition, suggest
  running `/prd` again with a narrower scope.
