---
paths:
  - ".claude/agents/**/AGENT.md"
  - ".claude/skills/**/SKILL.md"
---

# IDS Protocol (Inspect-Decide-Search)

Before creating any new file, function, or abstraction, follow IDS:

## 1. INSPECT

Glob + Grep the codebase for existing implementations with the same purpose.

- Search by function name, class name, and semantic intent
- Check `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, and `src/`

## 2. DECIDE

Choose exactly one action with a one-line justification:

- **REUSE** — existing code covers the need as-is
- **ADAPT** — existing code covers >60% of the need; modify it
- **CREATE** — nothing similar found; new code is justified

PREFER ADAPT over CREATE when existing code covers >60% of the need.

## 3. LOG

Record the decision in the agent's output artifact:

```
IDS: [REUSE|ADAPT|CREATE] — [one-line justification]
```

## Exceptions

- Test files and configuration files are exempt from IDS
- Single-line utility additions (imports, constants) are exempt
