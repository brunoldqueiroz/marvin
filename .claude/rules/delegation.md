---
paths:
  - ".claude/CLAUDE.md"
  - ".claude/agents/**/AGENT.md"
  - ".claude/skills/**/SKILL.md"
---

# Delegation Rules

## IDS Protocol (Inspect-Decide-Search)

Before creating any new file, function, or abstraction, follow IDS:

**1. INSPECT** — Glob + Grep the codebase for existing implementations with the
same purpose. Search by function name, class name, and semantic intent.

**2. DECIDE** — Choose exactly one action with a one-line justification:
- **REUSE** — existing code covers the need as-is
- **ADAPT** — existing code covers >60% of the need; modify it
- **CREATE** — nothing similar found; new code is justified

PREFER ADAPT over CREATE when existing code covers >60% of the need.

**3. LOG** — Record the decision in the agent's output artifact:
`IDS: [REUSE|ADAPT|CREATE] — [one-line justification]`

Exceptions: test files, configuration files, and single-line utility additions
are exempt from IDS.

## Structured Handoff Protocol

For multi-agent workflows (e.g., implementer → reviewer → tester), use this
format when passing context between sequential agents (max 500 tokens):

```
## Handoff
- Task: [ID or one-line description]
- Branch: [current branch]
- Decisions: [max 3 bullets with key decisions]
- Files Modified: [list of paths]
- Blockers: [unresolved issues or "none"]
- Next Action: [what the receiving agent should do]
```

Rules:
- Max 3 handoffs retained in a workflow chain (FIFO — drop oldest)
- MUST NOT include file content in the handoff — only paths
- The receiving agent MUST read referenced files directly

## Skill Library Scaling

Skills are organized into 6 categories for future hierarchical routing:

| Category | Skills |
|----------|--------|
| Data Engineering | dbt-expert, snowflake-expert, spark-expert, airflow-expert |
| Cloud/Infrastructure | aws-expert, terraform-expert, docker-expert |
| Development | python-expert, git-expert |
| Documentation | docs-expert, diagram-expert |
| Cognitive | memory-manager, deliberation, self-consistency, reflect |
| Workflow | sdd-constitution, sdd-specify, sdd-plan, sdd-tasks, checklist-runner |

Current count: 20 skills. Flat selection is optimal (activate hierarchical
routing at 50 skills).

### New Skill Addition Checklist

- [ ] Confusability check: no existing skill has >60% description term overlap
- [ ] "Does NOT" clause names all semantically adjacent skills
- [ ] Symmetric cross-references updated in adjacent skills
- [ ] Eval scenarios created: `eval/scenarios/<skill-name>.json` (6+ scenarios)
- [ ] Validation passes: `python3 .claude/skills/eval/validate-skills.py`
- [ ] Description budget: total < 16,000 chars; individual < 1,024 chars
- [ ] Body structure: advisory skills include all 7 mandatory sections
- [ ] Skill count updated in this document
