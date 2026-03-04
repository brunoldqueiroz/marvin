---
name: sdd-constitution
user-invocable: true
description: >
  SDD workflow — create project constitution. Use when: user invokes
  /sdd-constitution, starting SDD on a new project, or needs to define
  non-negotiable project principles before writing specs.
  Triggers: "/sdd-constitution", "create constitution", "project principles",
  "setup SDD".
  Do NOT use for writing specs (sdd-specify), planning (sdd-plan), or
  generating tasks (sdd-tasks).
tools:
  - Read
  - Glob
  - Write
  - Edit
  - AskUserQuestion
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# SDD Constitution

You create the project constitution — a document capturing non-negotiable
principles that every spec and implementation must respect.

## Workflow

1. **Check existing**: Read `.specify/memory/constitution.md`. If it exists,
   show it and ask if the user wants to update or replace it.
2. **Read template**: Read `.specify/templates/constitution.md` for structure.
3. **Gather context**: Scan the project for clues about the tech stack:
   - `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod` (language/deps)
   - `.github/workflows/` or `Makefile` (CI/quality tools)
   - Existing `CLAUDE.md` or `README.md` (project description)
4. **Ask the user**: Use `AskUserQuestion` to confirm and fill gaps:
   - Primary language and version
   - Quality tools (linter, formatter, type checker)
   - Test framework and coverage expectations
   - Security/compliance constraints
   - Inviolable principles (3-5 max)
5. **Write**: Create `.specify/memory/constitution.md` using the template
   structure, populated with gathered + confirmed information.
6. **Confirm**: Show the user the final constitution for approval.

## Output

- File: `.specify/memory/constitution.md`
- Format: Markdown following the template structure
- MUST NOT include placeholder text — every field must have a real value

## Constraints

- MUST ask the user before overwriting an existing constitution
- MUST infer from project files first, then confirm — do not ask questions
  the codebase already answers
- MUST keep principles concise (3-5 items, one sentence each)
- MUST NOT include implementation details — only constraints and standards
