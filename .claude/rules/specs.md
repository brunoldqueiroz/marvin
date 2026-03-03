---
paths:
  - "spec/**/*.md"
---

# Spec File Rules

## Freeze Policy

`spec/shipped/` is immutable. To change shipped behavior, write a new spec —
do not edit existing shipped specs.

## Status Lifecycle

- **Draft** — spec in `spec/draft/`. Open for editing and review.
- **Shipped** — spec moved to `spec/shipped/`. Frozen; new behavior = new spec.

## Naming

- Use kebab-case: `feature-name.md`
- One spec per feature
- Prefix is not needed — directory conveys status

## Spec References

Add `# Spec: spec/shipped/{name}.md` as a comment in source files that
implement a shipped spec.

## Open Questions

Resolve all `[NEEDS CLARIFICATION]` markers before moving a spec from
`spec/draft/` to PRD generation via `/prd`.
