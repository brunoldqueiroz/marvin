---
name: spec
user-invocable: true
description: >
  Design spec generator for SDD workflow. Use when: user wants to design a
  feature before writing a PRD, needs architectural decisions documented.
  Triggers: "/spec", "create spec", "design spec", "write design doc".
  Do NOT use for creating PRDs (prd), converting to JSON (ralph),
  validating (spec-check), or implementing features.
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

# Spec Generator (OpenSpec)

You generate design specs for the SDD workflow. A spec captures architectural
decisions, scope, and design rules **before** implementation begins.

Feature: $ARGUMENTS

## Tier Selection

Assess the request and select a tier:

| Tier | When | Action |
|------|------|--------|
| Lightweight | Bug fix, single-file change, trivial tweak | Skip `/spec` — suggest `/prd` directly |
| Standard | Feature, refactor, multi-file change | Quick codebase scan → generate spec |
| Comprehensive | Migration, new system, cross-cutting concern | Deep research → generate spec |

Announce the selected tier to the user. The user can override.

If **Lightweight**: tell the user this task doesn't need a spec and suggest
going directly to `/prd`. Stop here unless the user insists.

---

## Phase 0: Research

Skip this phase for Lightweight tier.

### Standard Tier
1. Use Glob to find files related to the feature
2. Use Grep to search for relevant patterns, imports, and interfaces
3. Use Read on key files to understand current architecture
4. Note existing patterns, conventions, and potential conflicts

### Comprehensive Tier
1. Perform the Standard scan above
2. Delegate to parallel `researcher` agents for independent sub-questions:
   - Each writes to `.artifacts/researcher-{n}.md`
   - Synthesize findings after all complete
   - Clean up `.artifacts/researcher-*.md`
3. Review related specs in `spec/draft/` and `spec/shipped/` for overlap

---

## Phase 1: Propose

### Step 1: Check for Existing Specs

Search `spec/draft/` and `spec/shipped/` for specs that overlap with this
feature. If overlap exists, inform the user and ask how to proceed:
- Extend existing spec (if draft)
- Write new spec with cross-reference (if shipped)
- Proceed as new spec (if no meaningful overlap)

### Step 2: Ask Clarifying Questions

Ask 3–5 clarifying questions covering:

1. **Scope boundaries** — What's in vs. out?
2. **Constraints** — Hard requirements, forbidden patterns, strong preferences?
3. **Prior art** — Existing code to build on? Related specs?
4. **Integration points** — What systems/modules does this touch?
5. **Success criteria** — How do we know it's done?

Present each question with options (A/B/C/D) plus a free-text option.
Wait for answers before proceeding.

### Step 3: Scan Codebase

Use Glob and Grep to identify:
- Files that will be created
- Files that will be modified
- Files that should NOT be created (with rationale)

This populates the Change Table.

### Step 4: Generate Spec

1. Read `spec/template.md` for the canonical template structure
2. Generate the spec following the template exactly
3. Apply these quality rules:

**Context section:**
- MUST cite evidence (metrics, user reports, prior specs, code references)
- MUST NOT just restate the What section in different words
- MUST explain WHY this change is needed

**Change Table:**
- MUST include at least one CREATE or MODIFY entry
- MUST include at least one NOT CREATE entry with rationale
- Paths MUST be real paths found during codebase scan (never invented)

**Design Rules:**
- MUST have at least 2 rules
- MUST use MUST / MUST NOT / PREFER language
- Each rule MUST have a rationale

**Scenarios:**
- MUST be testable and specific
- MUST use GIVEN/WHEN/THEN format
- MUST include at least 1 edge case
- Scenarios MUST be independent of each other

**Open Questions:**
- Use `[NEEDS CLARIFICATION: ...]` for any ambiguity
- NEVER guess when uncertain — mark it and move on

### Step 5: Write Spec

Derive a kebab-case name from the feature (e.g., `user-auth`, `csv-export`).
Write to `spec/draft/{feature-name}.md`.

### Step 6: Present for Approval

Display the full spec to the user. State clearly:

> "Review the spec above. I will NOT proceed until you approve it.
> You can request changes, ask questions, or approve as-is."

**DO NOT proceed to Phase 2 until the user explicitly approves.**

---

## Phase 2: Handoff

After user approval:

1. Confirm spec is saved at `spec/draft/{feature-name}.md`
2. Suggest next steps:

> **Next steps:**
> - Run `/spec-check` to validate spec quality (optional)
> - Run `/prd` to generate implementation stories from this spec
>
> **How the spec flows into PRD:**
> - Change Table → story scope
> - Design Rules → constitution (MUST/MUST NOT/PREFER)
> - Scenarios → acceptance criteria structure
> - Scope → non-goals section

---

## Examples

### Example 1: Standard Tier

User says: `/spec add CSV export to reports`

1. Tier: **Standard** (multi-file feature)
2. Phase 0: Scan for report-related files, existing export code
3. Phase 1: Ask about format, filtering, file size limits, auth
4. Generate spec with Change Table showing new exporter module, modified
   report controller, NOT CREATE separate download service
5. Write to `spec/draft/csv-export.md`
6. Wait for approval → suggest `/prd`

### Example 2: Comprehensive Tier

User says: `/spec migrate from SQLite to PostgreSQL`

1. Tier: **Comprehensive** (migration, cross-cutting)
2. Phase 0: Deep scan of all DB access patterns, delegate researchers
   for connection pooling and migration tooling
3. Phase 1: Ask about downtime tolerance, data volume, rollback strategy
4. Generate spec with extensive Change Table, migration-specific scenarios
5. Write to `spec/draft/sqlite-to-postgres.md`
6. Wait for approval → suggest `/spec-check` then `/prd`

### Example 3: Lightweight (skip)

User says: `/spec fix typo in error message`

1. Tier: **Lightweight** (single-file bug fix)
2. Response: "This is a single-file fix that doesn't need a design spec.
   I recommend going directly to `/prd` or just fixing it."
