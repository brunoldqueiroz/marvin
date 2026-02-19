---
name: adr
description: "Document architecture decisions in standard ADR format. Use when making a significant technical choice that future developers should understand."
disable-model-invocation: true
argument-hint: "[decision title, e.g. 'Use PostgreSQL for user data']"
---

# Architecture Decision Record

Decision: $ARGUMENTS

## Process

### 1. Clarify

Parse $ARGUMENTS to determine:
- **Decision title**: Clear, concise statement of what was decided
- **Status**: `proposed` (seeking approval) or `accepted` (already decided)

If the title is vague, ask the user to refine it before proceeding.

### 2. Gather Context

Scan the project for existing ADRs:
- Check `docs/decisions/`, `docs/adr/`, `adr/`, and `decisions/` directories
- If a directory exists, read existing ADRs to determine:
  - Numbering convention (e.g., `0001`, `001`, `1`)
  - Format conventions (any deviations from standard ADR template)
- Auto-increment the next ADR number
- If no ADR directory exists, create `docs/decisions/` and start at `0001`

Ask the user for context if not provided in $ARGUMENTS:
- What alternatives were considered?
- What constraints influenced the decision?
- What are the expected consequences?

### 3. Write

Delegate to the **docs-expert** agent:
- Create `docs/decisions/NNNN-<slug>.md` using this format:

```markdown
# NNNN. <Decision Title>

Date: YYYY-MM-DD

## Status

<proposed | accepted | deprecated | superseded by [NNNN]>

## Context

[What is the issue or situation that motivates this decision?
Include technical constraints, business requirements, and relevant history.]

## Decision

[What is the change that we're proposing and/or doing?
State the decision clearly and concisely.]

## Consequences

### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Trade-off 1]
- [Trade-off 2]

### Neutral
- [Side effect that is neither clearly positive nor negative]

## Alternatives Considered

### <Alternative 1>
[Description and why it was not chosen]

### <Alternative 2>
[Description and why it was not chosen]
```

- Slug should be kebab-case derived from the title
- Date should be today's date

### 4. Summary

Present to the user:
- ADR number and file path
- Decision title and status
- Suggested next steps (e.g., "Share with team for review", "Update status to accepted")

## Notes
- ADR numbering is sequential and never reused — deprecated ADRs keep their number
- Keep ADRs concise — they're decision records, not design documents
- Link to related ADRs when a new decision supersedes or relates to an older one
- The `proposed` status means the decision is open for discussion; `accepted` means finalized
