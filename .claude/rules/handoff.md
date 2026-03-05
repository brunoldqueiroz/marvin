---
paths:
  - ".claude/CLAUDE.md"
  - ".claude/agents/**/AGENT.md"
---

# Structured Handoff Protocol

For multi-agent workflows (e.g., implementer -> reviewer -> tester), use this
structured format when passing context between sequential agents.

## Handoff Block Format (max 500 tokens)

```
## Handoff
- Task: [ID or one-line description]
- Branch: [current branch]
- Decisions: [max 3 bullets with key decisions]
- Files Modified: [list of paths]
- Blockers: [unresolved issues or "none"]
- Next Action: [what the receiving agent should do]
```

## Rules

- Max 3 handoffs retained in a workflow chain (FIFO — drop oldest)
- MUST NOT include file content in the handoff — only paths
- Each handoff block MUST fit within 500 tokens
- The receiving agent MUST read referenced files directly, not rely on
  summaries from the handoff
