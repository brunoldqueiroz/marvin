# Spec — Skill Architecture Improvements

> Captures the intent (what + why) of improving Marvin's skill and agent
> architecture based on empirical research findings (arXiv:2601.04748,
> arXiv:2512.08296, SkillsBench, and industry best practices).

## Problem Statement

Marvin's skill library (16 skills, 5 agents) works well today, but has no
systematic defense against the empirically-proven failure modes that emerge
as skill libraries grow:

1. **Semantic confusability** between skill pairs (python/spark, aws/terraform,
   dbt/snowflake) risks mis-routing as the library expands. The paper
   arXiv:2601.04748 proves that even 1 semantic competitor per skill drops
   accuracy 7-30%.

2. **Large skill bodies** (diagram-expert: 394 lines, airflow-expert: 263
   lines) consume context budget on activation even when only a sub-domain
   is relevant. SkillsBench shows focused skills (2-3 modules) outperform
   comprehensive ones by +16.2pp.

3. **No routing validation** exists — there is no way to verify that a skill
   triggers for the right queries and does NOT trigger for queries belonging
   to a semantically similar skill.

4. **No preparation for scale** — the phase transition at kappa ~83-92 skills
   is sharp, not gradual. Without a hierarchical routing strategy designed
   in advance, hitting this threshold would cause abrupt quality degradation.

5. **Agent memory and skill preloading** are under-utilized — specialist
   agents that accumulate domain knowledge across sessions (researcher,
   implementer) would benefit from explicit skill injection and memory
   optimization.

## Desired Outcome

After implementation:

- Every skill description maximizes semantic differentiation from related
  skills, using empirically-validated patterns (Use when / Does NOT).
- Skills larger than 150 lines use the references/ sub-directory pattern,
  keeping the SKILL.md body as a focused dispatch document.
- A routing eval framework exists with test scenarios per skill that can
  detect confusability regressions.
- A documented hierarchical routing strategy is ready to activate when the
  library approaches 40+ skills.
- Agents have optimized skill preloading and memory configuration.
- The architecture follows Anthropic's official hierarchy: CLAUDE.md (always-on)
  > Skills (on-demand knowledge) > Agents (isolated execution).

## Requirements

### Functional

#### P0 — Semantic Confusability Audit (Do Now)

1. **F-01**: Audit all 16 skill descriptions for semantic overlap. For each
   confusability pair (python/spark, python/airflow, aws/terraform,
   dbt/snowflake, sdd-plan/sdd-tasks, docs/diagram), strengthen the "Does
   NOT" clause with specific, differentiating terms.

2. **F-02**: Ensure every advisory skill description follows the canonical
   pattern:
   ```
   {Role} expert advisor. Load proactively when {trigger context}.
   Use when: {specific triggers with domain terms}.
   Triggers: {keyword list for auto-discovery}.
   Do NOT use for {specific competing skills with names}.
   ```

3. **F-03**: Add cross-references in competing skill pairs — each skill in
   a pair must explicitly name the other as "not this skill" territory.

#### P1 — Skill Body Refactoring (Do Soon)

4. **F-04**: Refactor skills exceeding 150 lines into SKILL.md (dispatch,
   ~80-100 lines) + references/ sub-directory (domain-specific docs).
   Target skills: diagram-expert (394), airflow-expert (263), spark-expert
   (192), python-expert (190), terraform-expert (187), snowflake-expert (186),
   dbt-expert (185), docker-expert (184).

5. **F-05**: For each refactored skill, the SKILL.md body must act as a
   table of contents with conditional routing to reference files:
   ```markdown
   ## Optimization
   For performance tuning, partitioning, and memory management:
   → Read references/optimization.md

   ## Deployment
   For spark-submit patterns and cluster configuration:
   → Read references/deployment.md
   ```

6. **F-06**: Create a routing eval framework with test scenario files per
   skill. Format:
   ```json
   {
     "skill": "python-expert",
     "version": "1.0.0",
     "scenarios": [
       {"query": "add type hints to this function", "expected": true},
       {"query": "write a Spark job to process CSV files", "expected": false},
       {"query": "fix this mypy error in models.py", "expected": true},
       {"query": "create an Airflow DAG", "expected": false},
       {"query": "refactor this Python class", "expected": true},
       {"query": "deploy to AWS Lambda", "expected": false}
     ]
   }
   ```
   Minimum 6 scenarios per skill (3 positive, 3 negative targeting the
   closest semantic competitor).

7. **F-07**: Create a validation script that checks all SKILL.md files
   against the agentskills.io format requirements (name constraints,
   description length, required fields).

#### P1 — Agent Optimization (Do Soon)

8. **F-08**: Audit agent `skills:` preloading. For each agent, determine
   which knowledge-only skills should be injected at startup:
   - `implementer`: preload python-expert (most common implementation domain)
   - `reviewer`: preload python-expert, git-expert
   - `tester`: preload python-expert
   - `researcher`: no skill preloading (domain-agnostic)
   - `security`: no skill preloading (uses own specialized prompts)

9. **F-09**: Review agent `memory:` configuration. All agents currently use
   `memory: user`. Evaluate switching high-frequency agents (implementer,
   researcher) to `memory: project` for shared institutional knowledge.

10. **F-10**: Optimize agent descriptions using the same "Use for / Does NOT"
    pattern validated for skills. Ensure no semantic overlap between agent
    descriptions.

#### P2 — Scale Preparation (Plan Ahead)

11. **F-11**: Design a hierarchical routing taxonomy for when the skill
    library exceeds 40 skills. Define category groups:
    - Data Engineering: dbt, snowflake, spark, airflow
    - Cloud/Infrastructure: aws, terraform, docker
    - Development: python, git
    - Documentation: docs, diagram
    - Workflow: sdd-*, checklist-runner

12. **F-12**: Document the activation criteria for hierarchical routing —
    when to switch from flat to hierarchical, based on the phase transition
    research (kappa ~83-92, but inflection starts earlier at ~30).

13. **F-13**: Create a skill confusability monitoring checklist that runs
    before adding any new skill. The checklist must verify:
    - No existing skill has >60% description term overlap with the new skill
    - The new skill's "Does NOT" clause names all semantically adjacent skills
    - Total skill count is tracked against the phase transition threshold
    - The skill has eval scenarios covering its closest competitors

### Non-Functional

1. **NFR-01**: No skill description should exceed 1024 characters (agentskills.io
   spec limit).
2. **NFR-02**: Total description token budget must stay within 2% of context
   window (~16,000 chars default). Monitor with `/context`.
3. **NFR-03**: Refactored skills must maintain identical behavior — the
   refactoring is structural, not functional.
4. **NFR-04**: Agent skill preloading must only use knowledge-only skills.
   Skills with orchestration instructions (delegation, Agent tool usage)
   MUST NOT be preloaded into agents to avoid circular delegation.
5. **NFR-05**: All changes must be backward-compatible — no breaking changes
   to existing skill invocation patterns.

## Scope

### In Scope

- All 16 SKILL.md files (description audit + body refactoring)
- All 5 AGENT.md files (description audit + skills preloading + memory config)
- Routing eval framework (scenario files + validation script)
- Hierarchical routing design document (not implementation)
- Skill addition checklist document
- research.md with full paper analysis (already completed)

### Out of Scope

- Implementing hierarchical routing (P2 is design only — activate when needed)
- Building an automated routing eval runner (no production-ready framework
  exists; we create the scenarios, not the runner)
- Creating new skills or agents
- Modifying CLAUDE.md or hooks
- Changing the SDD workflow skills (sdd-*) beyond description improvements
- Context compression implementation (separate spec)
- Plugin/namespace system (premature at 16 skills)

## Constraints

- MUST follow the agentskills.io open standard for SKILL.md format
- MUST follow Anthropic's official hierarchy: CLAUDE.md > Skills > Agents
- MUST NOT preload orchestration skills into agents (causes circular delegation)
- MUST preserve existing skill invocation behavior (no functional changes)
- MUST keep descriptions under 1024 characters per agentskills.io spec
- PREFER descriptions that emphasize unique characteristics over generic ones
  (paper finding: "skill descriptors should emphasize unique characteristics")
- PREFER focused skills (2-3 modules) over comprehensive documentation
  (SkillsBench finding: +16.2pp for focused)

## Open Questions

1. Should `memory: project` be used for implementer/researcher agents?
   Trade-off: shared knowledge vs potential stale context across sessions.
   **Recommendation**: Start with `memory: project` for researcher only
   (most likely to build reusable domain context). Evaluate after 10 sessions.

2. Should eval scenarios be YAML or JSON? JSON is the Anthropic-recommended
   format, but YAML is more readable and consistent with SKILL.md frontmatter.
   **Recommendation**: JSON — aligns with Anthropic eval pattern and is
   machine-parseable for future automation.

3. What is the right threshold to activate hierarchical routing? The paper
   shows kappa ~83-92, but the inflection point starts at ~30. With 16
   skills, flat is clearly optimal. At what count do we switch?
   **Recommendation**: Monitor at 30, plan at 40, activate at 50. Document
   this as a decision in the hierarchical routing design.

## References

- [research.md](./research.md) — Full paper analysis and Marvin audit
- [arXiv:2601.04748](https://arxiv.org/abs/2601.04748) — Phase transition
  in skill selection, semantic confusability, hierarchical routing
- [arXiv:2512.08296](https://arxiv.org/abs/2512.08296) — Scaling laws for
  agent systems, 45% rule, topology error amplification
- [arXiv:2602.12670](https://arxiv.org/abs/2602.12670) — SkillsBench:
  focused skills > comprehensive, +16.2pp with curated skills
- [agentskills.io](https://agentskills.io/specification) — Open standard spec
- [Anthropic best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) — Skill description patterns
- [terrylica/cc-skills](https://github.com/terrylica/cc-skills) — Real-world
  50+ skill organization with plugins
