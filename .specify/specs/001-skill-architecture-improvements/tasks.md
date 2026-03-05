# Tasks — Skill Architecture Improvements

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Phase 1: Description Confusability Audit (P0)

- [x] **T-01: Audit and strengthen python-expert / spark-expert descriptions** — Edit frontmatter of both skills to add symmetric cross-references. python-expert must exclude PySpark/DataFrames/distributed processing. spark-expert must exclude pure Python scripting/typing/pytest/ruff/mypy/packaging.
  - Files: `.claude/skills/python-expert/SKILL.md`, `.claude/skills/spark-expert/SKILL.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Audit and strengthen python-expert / airflow-expert descriptions** — Edit frontmatter of both skills. python-expert must exclude DAG authoring/Airflow operators/scheduling. airflow-expert must exclude pure Python concerns/typing/testing/packaging.
  - Files: `.claude/skills/python-expert/SKILL.md`, `.claude/skills/airflow-expert/SKILL.md`
  - Agent: implementer
  - Depends on: T-01 (python-expert touched in both)

- [x] **T-03: Audit and strengthen aws-expert / terraform-expert descriptions** — Edit frontmatter of both skills. aws-expert must exclude HCL syntax/modules/state files/plan-apply workflows. terraform-expert must exclude AWS service configuration/architecture/IAM/cost optimization.
  - Files: `.claude/skills/aws-expert/SKILL.md`, `.claude/skills/terraform-expert/SKILL.md`
  - Agent: implementer
  - Depends on: none (parallel with T-01)

- [x] **T-04: Audit and strengthen dbt-expert / snowflake-expert descriptions** — Edit frontmatter of both skills. dbt-expert must exclude warehouse administration/DDL/RBAC/query optimization. snowflake-expert must exclude dbt model structure/Jinja macros/ref-vs-source/staging conventions.
  - Files: `.claude/skills/dbt-expert/SKILL.md`, `.claude/skills/snowflake-expert/SKILL.md`
  - Agent: implementer
  - Depends on: none (parallel with T-01)

- [x] **T-05: Audit and strengthen remaining skill descriptions** — Review docs-expert/diagram-expert pair and sdd-plan/sdd-tasks pair. Strengthen "Do NOT" clauses. Review docker-expert, git-expert, checklist-runner, sdd-constitution, sdd-specify for canonical pattern compliance.
  - Files: `.claude/skills/docs-expert/SKILL.md`, `.claude/skills/diagram-expert/SKILL.md`, `.claude/skills/sdd-plan/SKILL.md`, `.claude/skills/sdd-tasks/SKILL.md`, `.claude/skills/docker-expert/SKILL.md`, `.claude/skills/git-expert/SKILL.md`, `.claude/skills/checklist-runner/SKILL.md`, `.claude/skills/sdd-constitution/SKILL.md`, `.claude/skills/sdd-specify/SKILL.md`
  - Agent: implementer
  - Depends on: none (parallel with T-01)

- [x] **T-06: Validate description budget after audit** — Run python3 script to verify all descriptions < 1024 chars individually and total < 16,000 chars. Report results.
  - Files: all 16 SKILL.md (read-only)
  - Agent: tester
  - Depends on: T-01, T-02, T-03, T-04, T-05

- [x] **T-07: Review Phase 1 changes** — Review all description edits for consistency, canonical pattern compliance, and absence of behavioral instructions in description fields.
  - Files: all 16 SKILL.md (read-only via git diff)
  - Agent: reviewer
  - Depends on: T-06

## Phase 2a: Skill Body Refactoring (P1)

- [x] **T-08: Refactor diagram-expert into SKILL.md + references/** — Split 394-line skill into ~100-line dispatch body + reference files. Maintain all 7 mandatory sections in body. Move detailed D2 syntax and diagram type documentation to references/.
  - Files: `.claude/skills/diagram-expert/SKILL.md`, `.claude/skills/diagram-expert/references/d2-syntax.md` (new), `.claude/skills/diagram-expert/references/diagram-types.md` (new)
  - Agent: implementer
  - Depends on: T-07

- [x] **T-09: Refactor airflow-expert into SKILL.md + references/** — Split 263-line skill into ~100-line dispatch body + reference files. Move operator details and TaskFlow API patterns to references/.
  - Files: `.claude/skills/airflow-expert/SKILL.md`, `.claude/skills/airflow-expert/references/operators.md` (new), `.claude/skills/airflow-expert/references/taskflow.md` (new)
  - Agent: implementer
  - Depends on: T-08 (sequential to maintain consistent refactoring style)

- [x] **T-10: Refactor spark-expert into SKILL.md + references/** — Split 192-line skill into ~100-line dispatch body + reference files. Move optimization and tuning content to references/.
  - Files: `.claude/skills/spark-expert/SKILL.md`, `.claude/skills/spark-expert/references/optimization.md` (new)
  - Agent: implementer
  - Depends on: T-09

- [x] **T-11: Refactor python-expert into SKILL.md + references/** — Split 190-line skill into ~100-line dispatch body + reference files. Move toolchain details (uv, ruff, mypy, pytest config) to references/.
  - Files: `.claude/skills/python-expert/SKILL.md`, `.claude/skills/python-expert/references/toolchain.md` (new)
  - Agent: implementer
  - Depends on: T-10

- [x] **T-12: Refactor terraform-expert, snowflake-expert, dbt-expert, docker-expert** — Split remaining 4 skills (184-187 lines each) into dispatch body + references/. These are close to the 150-line threshold so may require less restructuring.
  - Files: `.claude/skills/terraform-expert/SKILL.md`, `.claude/skills/terraform-expert/references/patterns.md` (new), `.claude/skills/snowflake-expert/SKILL.md`, `.claude/skills/snowflake-expert/references/optimization.md` (new), `.claude/skills/dbt-expert/SKILL.md`, `.claude/skills/dbt-expert/references/modeling.md` (new), `.claude/skills/docker-expert/SKILL.md`, `.claude/skills/docker-expert/references/best-practices.md` (new)
  - Agent: implementer
  - Depends on: T-11

- [x] **T-13: Validate content preservation after refactoring** — For each refactored skill, verify total line count (SKILL.md + references/*.md) >= original. Verify 7 mandatory sections present in each SKILL.md body.
  - Files: all 8 refactored skills (read-only)
  - Agent: tester
  - Depends on: T-12

- [x] **T-14: Review Phase 2a changes** — Review all refactored skills for structural consistency, correct conditional routing pointers, and no content loss.
  - Files: all 8 refactored skills + references/ (read-only via git diff)
  - Agent: reviewer
  - Depends on: T-13

## Phase 2b: Routing Eval Framework (P1, parallel with Phase 2a)

- [x] **T-15: Create eval scenarios for confusability pairs** — Write JSON scenario files for the 5 confusability pairs (10 skills). Each file has 6+ scenarios (3 positive, 3 negative targeting closest competitor).
  - Files: `.claude/skills/eval/scenarios/python-expert.json` (new), `.claude/skills/eval/scenarios/spark-expert.json` (new), `.claude/skills/eval/scenarios/airflow-expert.json` (new), `.claude/skills/eval/scenarios/aws-expert.json` (new), `.claude/skills/eval/scenarios/terraform-expert.json` (new), `.claude/skills/eval/scenarios/dbt-expert.json` (new), `.claude/skills/eval/scenarios/snowflake-expert.json` (new), `.claude/skills/eval/scenarios/docs-expert.json` (new), `.claude/skills/eval/scenarios/diagram-expert.json` (new), `.claude/skills/eval/scenarios/git-expert.json` (new)
  - Agent: implementer
  - Depends on: T-07 (descriptions finalized)

- [x] **T-16: Create eval scenarios for remaining skills** — Write JSON scenario files for the 6 non-pair skills (docker-expert, checklist-runner, sdd-constitution, sdd-specify, sdd-plan, sdd-tasks). Each file has 6+ scenarios.
  - Files: `.claude/skills/eval/scenarios/docker-expert.json` (new), `.claude/skills/eval/scenarios/checklist-runner.json` (new), `.claude/skills/eval/scenarios/sdd-constitution.json` (new), `.claude/skills/eval/scenarios/sdd-specify.json` (new), `.claude/skills/eval/scenarios/sdd-plan.json` (new), `.claude/skills/eval/scenarios/sdd-tasks.json` (new)
  - Agent: implementer
  - Depends on: T-07

- [x] **T-17: Create validate-skills.py script** — Python script that validates all SKILL.md files: name format (lowercase, hyphens, max 64), description present and < 1024 chars, required frontmatter fields per rules/skills.md (name, user-invocable, description, tools, metadata with author/version/category).
  - Files: `.claude/skills/eval/validate-skills.py` (new)
  - Agent: implementer
  - Depends on: none (parallel with T-15)

- [x] **T-18: Run validate-skills.py against all skills** — Execute the validation script. All 16 skills must pass with zero errors.
  - Files: `.claude/skills/eval/validate-skills.py` (execute), all 16 SKILL.md (read-only)
  - Agent: tester
  - Depends on: T-17, T-14 (after refactoring complete)

## Phase 3: Agent Optimization (P1)

- [x] **T-19: Add skills preloading to implementer, reviewer, tester agents** — Add `skills:` field to 3 AGENT.md files. Verify each preloaded skill is knowledge-only (no Agent tool usage, no delegation instructions). implementer: python-expert. reviewer: python-expert, git-expert. tester: python-expert.
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/agents/reviewer/AGENT.md`, `.claude/agents/tester/AGENT.md`
  - Agent: implementer
  - Depends on: T-14 (refactored skills stable)

- [x] **T-20: Update researcher memory to project scope** — Change researcher agent from `memory: user` to `memory: project` for shared institutional knowledge across sessions.
  - Files: `.claude/agents/researcher/AGENT.md`
  - Agent: implementer
  - Depends on: none (parallel with T-19)

- [x] **T-21: Optimize all agent descriptions** — Strengthen "Use for / Does NOT" patterns in all 5 agent descriptions. Ensure no semantic overlap between agents (implementer vs reviewer, tester vs reviewer).
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/agents/reviewer/AGENT.md`, `.claude/agents/tester/AGENT.md`, `.claude/agents/researcher/AGENT.md`, `.claude/agents/security/AGENT.md`
  - Agent: implementer
  - Depends on: none (parallel with T-19)

- [x] **T-22: Validate agent preload safety** — Grep each preloaded skill body for "Agent tool", "delegate", "subagent", "Agent(" — must return zero matches. Verify agents function correctly with preloaded skills.
  - Files: preloaded skill SKILL.md files (read-only), 3 AGENT.md files (read-only)
  - Agent: tester
  - Depends on: T-19

- [x] **T-23: Review Phase 3 changes** — Review all agent modifications for compliance with rules/agents.md, correct skills preloading, and description quality.
  - Files: all 5 AGENT.md files (read-only via git diff)
  - Agent: reviewer
  - Depends on: T-22

## Phase 4: Scale Preparation Documents (P2)

- [x] **T-24: Create scaling rules document** — Write `.claude/rules/scaling.md` with: hierarchical routing taxonomy (5 categories), activation criteria (monitor at 30, plan at 40, activate at 50), and new-skill-addition checklist (confusability check, "Does NOT" clause, eval scenarios, budget verification).
  - Files: `.claude/rules/scaling.md` (new)
  - Agent: implementer
  - Depends on: T-18, T-23 (references eval framework and completed audit)

- [x] **T-25: Review scaling rules document** — Review for completeness, accuracy of thresholds (grounded in research), and actionability of the checklist.
  - Files: `.claude/rules/scaling.md` (read-only)
  - Agent: reviewer
  - Depends on: T-24

## Final Validation

- [x] **T-26: End-to-end routing smoke test** — Manually invoke 5 ambiguous queries across confusability pairs and verify correct skill activation. Document results.
  - Files: none (manual testing)
  - Agent: tester
  - Depends on: T-25

## Acceptance Criteria

- [x] All 16 skill descriptions follow canonical pattern with symmetric "Do NOT" cross-references (F-01, F-02, F-03)
- [x] All descriptions < 1024 chars, total budget < 16,000 chars (NFR-01, NFR-02)
- [x] 8 skills refactored to SKILL.md + references/, each body <= 150 lines (F-04, F-05)
- [x] Content preservation verified: refactored total lines >= original (NFR-03)
- [x] 7 mandatory sections present in every refactored SKILL.md body
- [x] 16 eval scenario JSON files created with 6+ scenarios each (F-06)
- [x] validate-skills.py passes on all 16 skills with zero errors (F-07)
- [x] 3 agents have skills preloading with knowledge-only skills verified (F-08, NFR-04)
- [x] Researcher agent uses `memory: project` (F-09)
- [x] 5 agent descriptions optimized with "Use for / Does NOT" pattern (F-10)
- [x] `.claude/rules/scaling.md` created with taxonomy, criteria, and checklist (F-11, F-12, F-13)
- [x] All changes backward-compatible (NFR-05)
- [x] Reviewer agent approved changes at each phase
