---
paths:
  - ".claude/skills/**/SKILL.md"
---

# Skill Authoring Rules

## Frontmatter

- MUST include all required fields: `name`, `user-invocable`, `description`,
  `tools`, `metadata` (author, version, category).
- `description` MUST follow this exact order:
  1. Role statement ("X expert advisor" or "X workflow")
  2. `Use when:` with trigger conditions
  3. `Triggers:` with 3+ quoted phrases (specific, not generic)
  4. `Do NOT use for` with cross-references to sibling skills
- `tools` MUST list each tool explicitly — no wildcards. Bash access uses
  `Bash(<command>*)` syntax (e.g., `Bash(ruff*)`).
- `metadata.category` MUST be `advisory` or `workflow`.

## Body Structure (advisory skills)

MUST include these sections in order:

1. **Tool Selection** — table mapping needs to tools (mandatory for 3+ tools)
2. **Core Principles** — 7-10 numbered opinionated rules
3. **Best Practices** — 10 numbered actionable practices
4. **Anti-Patterns** — 10 numbered mistakes with why + alternative
5. **Examples** — 3 scenarios: "User says → Actions → Result"
6. **Troubleshooting** — 3-4 entries: "Error → Cause → Solution"
7. **Review Checklist** — 10 checkbox items reflecting principles

## Constraints

- Body budget: < 500 lines.
- MUST NOT put behavioral instructions in the `description` field — use body.
- Trigger phrases MUST be specific enough to avoid false-positive routing
  (BAD: "python", GOOD: "ruff warning", "mypy error").
