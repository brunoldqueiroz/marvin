# Research — Skill Architecture Improvements

> Findings from parallel research conducted 2026-03-05. Full paper analysis
> of arXiv:2601.04748 + 8 supporting papers and industry sources.

## Key Papers

### arXiv:2601.04748 — "When Single-Agent with Skills Replace Multi-Agent Systems and When They Fail"
- **Author**: Xiaoxiao Li, UBC / Vector Institute, Jan 2026
- **Core finding**: Skill selection exhibits a phase transition, not gradual
  degradation. Accuracy stable up to capacity threshold kappa (~83-92 for
  GPT-4o/4o-mini), then drops sharply.
- **Confusability > Size**: Semantic overlap between skills — not library
  size — is the primary driver of selection errors.
- **Hierarchical routing**: Two-stage selection (category -> skill) recovers
  37-40% of accuracy lost at the phase transition.
- **Compilation results**: SAS matches MAS accuracy (+0.7% avg) with 53.7%
  fewer tokens and 49.5% less latency.
- **H3 null result**: Policy complexity (simple/medium/complex) does NOT
  affect selection accuracy — LLMs filter irrelevant detail efficiently.

### arXiv:2512.08296 — "Towards a Science of Scaling Agent Systems"
- **Authors**: Kim et al., Google/MIT, Dec 2025
- **45% Rule**: Multi-agent coordination yields negative returns when
  single-agent baseline exceeds ~45% success rate.
- **Error amplification**: Independent agents 17.2x, centralized 4.4x.
- **Task topology**: Sequential tasks always degrade with multi-agent
  (-39% to -70%). Parallelizable tasks benefit (+80.8%).

### arXiv:2602.12670 — SkillsBench
- **Scope**: 7,308 trajectories, 86 tasks, 11 domains, Feb 2026
- **Curated skills**: +16.2pp average pass rate improvement
- **Focused (2-3 modules) > comprehensive**: Narrower scope wins
- **Self-generated skills**: No benefit — models can't author their own
  procedural knowledge effectively
- **16 of 84 tasks show negative deltas**: Poorly scoped skills hurt

### arXiv:2602.19672 — SkillOrchestra
- Skill-aware orchestration via learned routing
- 22.5% improvement over SOTA RL routers at 700x lower learning cost
- Relevant for future hierarchical routing optimization

### Zylos Research — Context Compression (Feb 2026)
- Context drift causes 65% of enterprise AI failures
- Anchored iterative summarization: 4.04/5 vs 3.74 for full-reconstruction
- Compact trigger: 70% context utilization
- Performance degrades measurably beyond 30,000 tokens

### terrylica/cc-skills Repository
- 19 plugins, 50+ skills, actively maintained
- Plugin-as-namespace pattern for organization at scale
- Hook synchronization, dependency tracking, semantic-release

### agentskills.io Standard
- Open standard adopted by Claude Code, Codex, Cursor, Amp, GitHub Copilot
- Three-tier progressive disclosure: metadata -> body -> references
- `skills-ref validate` CLI for format validation

## Marvin Current State Audit

### Skills (16 total)
- **Advisory** (11): python, docker, aws, terraform, snowflake, dbt, spark,
  airflow, git, docs, diagram — all `user-invocable: false`
- **Workflow** (5): sdd-constitution, sdd-specify, sdd-plan, sdd-tasks,
  checklist-runner — all `user-invocable: true`

### Agents (5 total)
- researcher, reviewer, tester, security, implementer
- All use `model: sonnet`, `memory: user`

### Confusability Risk Pairs Identified
| Pair | Risk | Shared Terms |
|------|------|-------------|
| python-expert / spark-expert | Medium | "python", "dataframe" |
| python-expert / airflow-expert | Medium | "python", DAGs are Python code |
| aws-expert / terraform-expert | Medium | "cloud infrastructure", "provisioning" |
| dbt-expert / snowflake-expert | Medium | "SQL", "data warehouse", "data pipeline" |
| sdd-plan / sdd-tasks | Low | "plan" adjacent to "tasks" |

### Skill Sizes (lines)
- diagram-expert: 394 (needs refactor to references/)
- airflow-expert: 263 (candidate for references/)
- spark-expert: 192
- python-expert: 190
- terraform-expert: 187
- Average advisory skill: ~190 lines
- Average workflow skill: ~66 lines

## Sources

- https://arxiv.org/abs/2601.04748
- https://arxiv.org/abs/2512.08296
- https://arxiv.org/abs/2602.12670
- https://arxiv.org/abs/2602.19672
- https://agentskills.io/specification
- https://github.com/terrylica/cc-skills
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents
- https://zylos.ai/research/2026-02-28-ai-agent-context-compression-strategies
- https://www.anthropic.com/research/building-effective-agents
