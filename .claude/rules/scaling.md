---
paths:
  - ".claude/skills/**/SKILL.md"
---

# Skill Library Scaling Rules

## Hierarchical Routing Taxonomy

When the skill library grows beyond flat selection capacity, organize skills
into these 6 categories for two-stage routing (category → skill):

| Category | Skills |
|----------|--------|
| Data Engineering | dbt-expert, snowflake-expert, spark-expert, airflow-expert |
| Cloud/Infrastructure | aws-expert, terraform-expert, docker-expert |
| Development | python-expert, git-expert |
| Documentation | docs-expert, diagram-expert |
| Cognitive | memory-manager, deliberation, self-consistency |
| Workflow | sdd-constitution, sdd-specify, sdd-plan, sdd-tasks, checklist-runner |

## Activation Criteria

Based on arXiv:2601.04748 phase transition research (kappa ~83-92 for GPT-4o,
inflection starts at ~30):

| Skill Count | Action |
|-------------|--------|
| < 30 | Flat selection is optimal. No action needed. |
| 30 | **Monitor**: Run confusability audit quarterly. Track routing accuracy. |
| 40 | **Plan**: Design hierarchical routing implementation. Test category taxonomy. |
| 50 | **Activate**: Switch to two-stage routing (category → skill). |

Current count: 19 skills. Flat selection is optimal.

## New Skill Addition Checklist

Before adding any new skill to the library:

- [ ] **Confusability check**: No existing skill has >60% description term
      overlap with the new skill. Compare trigger phrases and "Use when" clauses.
- [ ] **"Does NOT" clause**: The new skill's description explicitly names all
      semantically adjacent skills in its "Do NOT use for" section.
- [ ] **Symmetric cross-references**: Every named adjacent skill has been
      updated to exclude the new skill's territory.
- [ ] **Eval scenarios**: Created `eval/scenarios/<skill-name>.json` with 6+
      scenarios (3 positive, 3 negative targeting closest competitor).
- [ ] **Validation passes**: `python3 .claude/skills/eval/validate-skills.py`
      exits with code 0 after adding the new skill.
- [ ] **Description budget**: Total description chars remain under 16,000.
      Individual description under 1,024 chars.
- [ ] **Body structure**: Advisory skills include all 7 mandatory sections.
      Skills > 150 lines use `references/` sub-directory pattern.
- [ ] **Skill count tracked**: Update this document's "Current count" after
      adding. Check against activation criteria thresholds.
