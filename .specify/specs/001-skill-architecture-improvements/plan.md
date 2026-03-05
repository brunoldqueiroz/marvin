# Plan — Skill Architecture Improvements

> Implementation strategy derived from spec 001. Reviewable checkpoint before
> writing code.

## Approach

Implement improvements in 4 sequential phases matching the spec's priority
levels: P0 description audit first (highest impact, zero risk), then P1 skill
body refactoring and eval framework in parallel, then P1 agent optimization,
and finally P2 design documents. Each phase produces independently-valuable
output — we can stop after any phase and still have improved the system.

## Components

### C1 — Description Confusability Audit (P0, F-01/F-02/F-03)

- **What**: Edit the YAML frontmatter `description` field of all 16 skills to
  maximize semantic differentiation. Strengthen "Do NOT use for" clauses in
  the 5 identified confusability pairs. Ensure all descriptions follow the
  canonical pattern defined in `.claude/rules/skills.md`.
- **Files to modify**:
  - `.claude/skills/python-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/spark-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/airflow-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/aws-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/terraform-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/dbt-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/snowflake-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/docs-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/diagram-expert/SKILL.md` (frontmatter only)
  - `.claude/skills/sdd-plan/SKILL.md` (frontmatter only)
  - `.claude/skills/sdd-tasks/SKILL.md` (frontmatter only)
  - Remaining 5 skills: review only, edit if needed
- **Dependencies**: None — can start immediately.
- **Strategy**: For each confusability pair, add symmetric cross-references.
  Each skill in a pair must name the other's territory as excluded. Focus on
  differentiating **verbs and nouns**, not just adding "Do NOT" boilerplate.
  Examples:
  - python-expert: "Do NOT use for PySpark jobs, Spark DataFrames, or
    distributed processing (spark-expert)" — not just "Do NOT use for Spark"
  - spark-expert: "Do NOT use for pure Python scripts, typing, pytest, ruff,
    mypy, or packaging (python-expert)" — emphasizes Python-only toolchain
- **Validation**: After edits, run `python3` to verify all descriptions remain
  under 1024 chars and total budget stays under 16,000 chars (currently at
  8,724 = 54.5%).

### C2 — Skill Body Refactoring (P1, F-04/F-05)

- **What**: Split 8 advisory skills exceeding 150 lines into a dispatch
  SKILL.md body (~80-100 lines) plus `references/` sub-directory with
  domain-specific files. The SKILL.md body retains the 7 mandatory sections
  from `rules/skills.md` (Tool Selection, Core Principles, Best Practices,
  Anti-Patterns, Examples, Troubleshooting, Review Checklist) but moves
  detailed reference content into separate files.
- **Files to modify/create**:
  - `.claude/skills/diagram-expert/SKILL.md` (394 → ~100 lines)
  - `.claude/skills/diagram-expert/references/d2-syntax.md` (new)
  - `.claude/skills/diagram-expert/references/diagram-types.md` (new)
  - `.claude/skills/airflow-expert/SKILL.md` (263 → ~100 lines)
  - `.claude/skills/airflow-expert/references/operators.md` (new)
  - `.claude/skills/airflow-expert/references/taskflow.md` (new)
  - `.claude/skills/spark-expert/SKILL.md` (192 → ~100 lines)
  - `.claude/skills/spark-expert/references/optimization.md` (new)
  - `.claude/skills/python-expert/SKILL.md` (190 → ~100 lines)
  - `.claude/skills/python-expert/references/toolchain.md` (new)
  - `.claude/skills/terraform-expert/SKILL.md` (187 → ~100 lines)
  - `.claude/skills/terraform-expert/references/patterns.md` (new)
  - `.claude/skills/snowflake-expert/SKILL.md` (186 → ~100 lines)
  - `.claude/skills/snowflake-expert/references/optimization.md` (new)
  - `.claude/skills/dbt-expert/SKILL.md` (185 → ~100 lines)
  - `.claude/skills/dbt-expert/references/modeling.md` (new)
  - `.claude/skills/docker-expert/SKILL.md` (184 → ~100 lines)
  - `.claude/skills/docker-expert/references/best-practices.md` (new)
- **Dependencies**: C1 must be complete (descriptions finalized before
  touching the body).
- **Strategy**: For each skill:
  1. Read the full SKILL.md body
  2. Identify content that is reference/detail (long examples, configuration
     tables, extended troubleshooting) vs core (principles, anti-patterns,
     checklist)
  3. Move reference content to `references/<topic>.md`
  4. Replace moved content in SKILL.md with conditional routing pointers:
     `For [topic], read references/<topic>.md`
  5. Verify the 7 mandatory sections from `rules/skills.md` remain in the body
- **Constraint**: NFR-03 — behavior must be identical. No content may be
  deleted, only relocated.

### C3 — Routing Eval Framework (P1, F-06/F-07)

- **What**: Create JSON scenario files per skill for routing validation, plus
  a Python script that validates SKILL.md format against agentskills.io rules.
- **Files to create**:
  - `.claude/skills/eval/` directory (new)
  - `.claude/skills/eval/scenarios/python-expert.json` (new)
  - `.claude/skills/eval/scenarios/spark-expert.json` (new)
  - `.claude/skills/eval/scenarios/airflow-expert.json` (new)
  - `.claude/skills/eval/scenarios/aws-expert.json` (new)
  - `.claude/skills/eval/scenarios/terraform-expert.json` (new)
  - `.claude/skills/eval/scenarios/dbt-expert.json` (new)
  - `.claude/skills/eval/scenarios/snowflake-expert.json` (new)
  - `.claude/skills/eval/scenarios/docker-expert.json` (new)
  - `.claude/skills/eval/scenarios/docs-expert.json` (new)
  - `.claude/skills/eval/scenarios/diagram-expert.json` (new)
  - `.claude/skills/eval/scenarios/git-expert.json` (new)
  - `.claude/skills/eval/scenarios/checklist-runner.json` (new)
  - `.claude/skills/eval/scenarios/sdd-constitution.json` (new)
  - `.claude/skills/eval/scenarios/sdd-specify.json` (new)
  - `.claude/skills/eval/scenarios/sdd-plan.json` (new)
  - `.claude/skills/eval/scenarios/sdd-tasks.json` (new)
  - `.claude/skills/eval/validate-skills.py` (new)
- **Dependencies**: C1 must be complete (scenarios reference the finalized
  descriptions).
- **Strategy**: For each skill, craft 6+ scenarios (3 positive, 3 negative).
  Negative scenarios MUST target the closest semantic competitor:
  - python-expert negatives → spark-expert, airflow-expert territory
  - aws-expert negatives → terraform-expert territory
  - dbt-expert negatives → snowflake-expert territory
  The validation script checks: name format (lowercase, hyphens, max 64),
  description present and under 1024 chars, required frontmatter fields per
  `rules/skills.md`.
- **Note**: No automated routing runner — scenarios are documentation that
  enables future automation and serves as a human-reviewable specification
  of routing boundaries.

### C4 — Agent Optimization (P1, F-08/F-09/F-10)

- **What**: Add `skills:` preloading to 3 agents, evaluate memory config,
  and improve agent descriptions.
- **Files to modify**:
  - `.claude/agents/implementer/AGENT.md` (add `skills:`, improve description)
  - `.claude/agents/reviewer/AGENT.md` (add `skills:`, improve description)
  - `.claude/agents/tester/AGENT.md` (add `skills:`, improve description)
  - `.claude/agents/researcher/AGENT.md` (memory evaluation, improve description)
  - `.claude/agents/security/AGENT.md` (improve description only)
- **Dependencies**: C2 must be complete — skill preloading requires
  knowledge-only skills, and the refactored skills must be validated first.
- **Strategy**:
  - `skills:` preloading — inject ONLY knowledge-only advisory skills.
    The skill body will be loaded at startup (not lazily). Verify no skill
    contains Agent tool delegation instructions before adding to preload list.
  - `memory:` — change researcher from `memory: user` to `memory: project`
    as recommended in spec open question 1. Leave others as `memory: user`.
  - Descriptions — apply the "Use for / Does NOT" pattern from
    `rules/agents.md`. Current descriptions already use this pattern but
    can be made more specific about boundaries between agents (e.g.,
    implementer vs reviewer, tester vs reviewer).

### C5 — Scale Preparation Documents (P2, F-11/F-12/F-13)

- **What**: Create design documents for hierarchical routing and a
  new-skill-addition checklist. No code changes — pure documentation.
- **Files to create**:
  - `.claude/rules/scaling.md` (new — hierarchical routing design + activation
    criteria + confusability checklist)
- **Dependencies**: C1 complete (confusability pairs documented). C3 complete
  (eval framework referenced by checklist).
- **Strategy**: Single document covering:
  1. Hierarchical routing taxonomy (5 categories from spec F-11)
  2. Activation criteria (monitor at 30, plan at 40, activate at 50)
  3. New skill addition checklist (confusability check, "Does NOT" clause,
     eval scenarios, budget verification)
  The document follows the existing rules/ convention — it's automatically
  applied when editing skills due to the `paths:` frontmatter pattern.

## Execution Order

```
Phase 1 (P0):  C1 — Description Audit
                 ↓
Phase 2 (P1):  C2 — Skill Body Refactoring  ║  C3 — Eval Framework
               (sequential, 1 skill at a time)  (parallel with C2)
                 ↓
Phase 3 (P1):  C4 — Agent Optimization
                 ↓
Phase 4 (P2):  C5 — Scale Preparation Docs
```

- **C1 first**: Descriptions must be finalized before any other component
  touches the SKILL.md files. Prevents merge conflicts and rework.
- **C2 ∥ C3**: Body refactoring and eval scenarios are independent — they
  touch different parts of the file system (SKILL.md body vs eval/ directory).
  Can be parallelized across agents.
- **C4 after C2**: Agent skill preloading requires the refactored skills to
  be stable. Preloading a skill that's mid-refactoring risks inconsistency.
- **C5 last**: Design documents reference completed work from all prior phases.

### Delegation Strategy

- **C1**: Implementer agent — edit frontmatter of 16 SKILL.md files.
  Single agent, sequential per file.
- **C2**: Implementer agent — read each skill body, split into SKILL.md +
  references/. One skill at a time to maintain coherence. Could use
  parallel agents with worktree isolation but not recommended (too many
  interdependent style decisions).
- **C3**: Implementer agent (eval scenarios) + implementer agent
  (validation script). Can run in parallel.
- **C4**: Implementer agent — edit 5 AGENT.md files sequentially.
- **C5**: Main Marvin context — design document benefits from full
  conversation context of all prior phases.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Description edits break existing routing that works | High | Read each skill's full body before editing description. Verify trigger phrases in description match actual body content. Test with `/context` after all edits. |
| Skill body refactoring loses content | High | NFR-03: diff every refactored SKILL.md + references/ against original. Total line count must be >= original. Use reviewer agent after each refactoring. |
| Agent skill preloading causes circular delegation | High | NFR-04: Only preload skills that do NOT contain Agent tool usage or delegation instructions. Verify by grepping preloaded skill bodies for "Agent" and "delegate". |
| Eval scenarios don't reflect real routing behavior | Medium | Include edge cases in scenarios (ambiguous queries that could go either way). Mark these as "boundary" scenarios for human review. |
| Description budget exceeded after strengthening | Low | Current usage is 54.5% (8,724/16,000). Even doubling average description size stays within budget. Monitor with python3 script after C1. |
| references/ files not discovered by Claude Code | Low | Claude Code auto-discovers subdirectories within skill directories. Verified by official docs. Test with one skill first (diagram-expert) before proceeding to others. |

## Testing Strategy

- **Format validation**: Run `validate-skills.py` (created in C3) against
  all 16 skills after C1 and C2. Must pass with zero errors.
- **Budget verification**: Run the python3 description length counter after
  C1. Total must stay under 16,000 chars. All individual descriptions must
  stay under 1,024 chars.
- **Content preservation**: After C2, for each refactored skill:
  `wc -l SKILL.md references/*.md` total must be >= original line count.
- **Agent preload safety**: After C4, grep each preloaded skill for
  "Agent tool", "delegate", "subagent" — must return zero matches.
- **Routing smoke test**: After all phases, manually invoke 3-5 ambiguous
  queries across confusability pairs and verify correct skill activation.
- **Reviewer agent**: Run reviewer on the full diff after each phase to
  catch regressions.

## Alternatives Considered

| Alternative | Why rejected |
|-------------|-------------|
| Automated routing eval runner (LLM-as-judge) | No production-ready framework exists. Building one is a separate project. JSON scenarios provide the specification without the complexity. |
| Plugin/namespace system (cc-skills pattern) | Premature at 16 skills. The phase transition threshold is ~83-92. Namespacing adds installation/versioning overhead that's not justified. Revisit at 40+ skills. |
| Merge confusable skill pairs (e.g., dbt + snowflake → data-warehouse-expert) | Violates SkillsBench finding: focused skills (2-3 modules) outperform comprehensive. Merging increases per-skill scope. Better to differentiate descriptions. |
| Use `context: fork` for all advisory skills | Unnecessary overhead — advisory skills are knowledge injection, not execution. Forking creates isolated context when the whole point is to inform the main conversation. |
| Implement hierarchical routing now | Wasteful at 16 skills. Research shows flat selection is optimal when |S| < 30. Design now, implement when the library grows. |
| Move all reference content to CLAUDE.md | CLAUDE.md should stay under 200 lines (project rule). Moving reference content there bloats the always-on context. Skills with references/ are the correct layer. |
