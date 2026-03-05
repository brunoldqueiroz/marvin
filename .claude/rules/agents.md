---
paths:
  - ".claude/agents/**/AGENT.md"
---

# Agent Authoring Rules

## Frontmatter

- MUST include all required fields: `name`, `description`, `tools`, `model`,
  `memory`, `maxTurns`.
- `description` MUST follow this pattern:
  1. Role statement ("Research specialist", "Code reviewer")
  2. `Use for:` with positive triggers
  3. `Does NOT:` with explicit exclusions
- `tools` is an ALLOWLIST — list each tool explicitly, no wildcards.
  Omitting this field gives the agent access to all tools.
- `model`: use `sonnet` as default. Use `haiku` for classification/triage,
  `opus` for architecture decisions. Document the reasoning.
- `maxTurns`: start conservative (10-15), increase with evidence.
  Research agents need 15-20; classifiers need 3-5.

## Body Structure

- MUST include a **Tool Selection** table when agent has 3+ tools
  (maps question types → specific tools).
- MUST specify **Output Format** — what to return or where to write
  (e.g., markdown template, `.artifacts/` path).
- MUST include procedural workflow ("How You Work" steps).
- Body budget: < 100 lines.

## Completion Signal

Every agent MUST end its final message with exactly one signal on its own line:

```
SIGNAL:DONE    — task completed successfully
SIGNAL:BLOCKED — task could not be completed (explain above)
SIGNAL:PARTIAL — task partially completed (explain what remains above)
```

The signal MUST be the last non-empty line of the agent's final message.

## Constraints

- MUST NOT put behavioral/procedural instructions in `description` —
  that field is for routing only; how-to belongs in the body.
- MUST NOT use tool wildcards — explicit allowlists prevent confusion
  and limit blast radius.
