# Project Invariants

Drift prevention rules for this project. These constraints are MORE important
than requirements — violating an invariant is always wrong, even if the code
"works".

## Architecture Style

<!-- Describe the architectural pattern: monolith, microservices, modular monolith,
     event-driven, layered, etc. This anchors all structural decisions. -->
{{ARCHITECTURE_STYLE}}

## Non-Negotiable Patterns

These patterns MUST be followed in all code. Deviating requires an ADR.

{{NON_NEGOTIABLE_PATTERNS}}

## Forbidden Patterns

These patterns MUST NEVER appear in the codebase.

{{FORBIDDEN_PATTERNS}}

## Terminology

Canonical vocabulary for this project. Use these terms consistently — never
use synonyms that could cause confusion across sessions.

| Term | Definition | Never Call It |
|------|-----------|---------------|
{{TERMINOLOGY}}
