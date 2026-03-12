# Marvin Development Standard

> Before creating or modifying agents, skills, hooks, or settings — consult
> this document. It codifies empirically validated patterns for evolving
> AI-augmented development projects.

**Version:** 2.0 — March 2026
**Applies to:** all files under `.claude/` and project-level configuration.

---

## §1 Fundamental Principles

### 1.1 Layer Model

Marvin has five composable layers. Each solves a different problem — mixing
their purposes causes failures.

| Layer | Purpose | Determinism | Context cost |
|-------|---------|-------------|--------------|
| CLAUDE.md / rules | Preferences, routing hints | Probabilistic (~85% → <20% over session) | Fixed (loaded at start) |
| Hooks | Enforcement, observability | Deterministic (exit codes) | Zero (shell, not context) |
| Skills | Domain knowledge on demand | Probabilistic (loaded when routed) | On-demand |
| Agents | Task isolation, exclusive tools | Probabilistic (own context window) | Isolated |
| MCP servers | External capabilities | Deterministic (tool calls) | Per-call |

### 1.2 Core Axioms

1. **Context window is the primary constraint.** Every design decision serves
   to preserve context budget for actual work. (Most agent failures are context
   failures, not model failures — Anthropic, Sep 2025)
2. **`description` field is the routing signal.** Separate routing (when to
   call) from behavior (how to act). Never mix them.
3. **Filesystem handoff > conversational relay.** Write to `.artifacts/`, read
   back. Never copy large outputs through conversation history.
4. **Config-as-code.** CLAUDE.md, AGENT.md, hooks, and settings.json deserve
   the same rigor as production code: version control, review, testing.
5. **Probabilistic instructions need deterministic enforcement.** If a
   constraint matters after 10+ messages, back it with a hook.
6. **Start with the simplest approach.** Single LLM call > workflow > agent.
   Add orchestration layers only when simpler solutions demonstrably fail to
   meet quality or latency requirements.
7. **Prefer just-in-time over upfront context.** Load knowledge at the point
   of need (skills, `@path` imports) rather than in CLAUDE.md. Upfront context
   pays a fixed cost every turn. Just-in-time costs more per retrieval but
   preserves budget for the 90% of turns that don't need it.

   Progressive disclosure follows three layers: discovery (~100 tokens, always
   loaded) → activation (full instructions on relevance) → execution (examples
   and references on demand).

8. **Diversity beats quantity.** Two diverse agents outperform sixteen
   homogeneous ones. Optimize for reasoning diversity (different models,
   prompts, strategies), not agent count.

### 1.3 Evidence Base

| Claim | Source |
|-------|--------|
| Instructions degrade ~85% → <20% over context | arXiv:2511.12884 "context debt" |
| Middle-of-file rules get ~30% less attention | Lost in the Middle, TACL 2024 |
| LLM-generated CLAUDE.md reduces success 0.5–3% | arXiv:2602.11988, ETH Zurich 2026 |
| IFEval compliance drops beyond ~150 instructions | IFEval benchmark, 2025 |
| Multi-agent uses ~4x tokens (hub-spoke), ~15x (mesh) | Anthropic engineering blog, 2025 |
| MAS overhead ranges 58–515% over single-agent baseline | arXiv:2512.08296, Dec 2025 |
| Above 45% single-agent accuracy, adding agents degrades performance | arXiv:2512.08296, capability ceiling effect |
| Skill selection degrades sharply beyond ~50-100 skills | arXiv:2601.04748, phase transition, Jan 2026 |
| Single-agent + skills is competitive, not a degraded fallback | arXiv:2601.12307, Jan 2026 |
| Most agent failures are context failures, not model failures | Anthropic context engineering blog, Sep 2025 |
| 2 diverse agents outperform 16 homogeneous agents | arXiv:2602.03794, diversity scaling, Feb 2026 |
| Trajectory diversity yields larger gains than trajectory quantity | arXiv:2602.03219, TDScaling, Feb 2026 |
| LLMs do not naturally self-compress context; scaffolding required | arXiv:2601.07190, Focus agent, Jan 2026 |
| Memory poisoning: stale RAG entries corrupt future reasoning | arXiv:2601.11653, ACC framework, Jan 2026 |
| Observation masking equals LLM summarization at ~50% cost | JetBrains NeurIPS 2025 DL4C workshop |
| 98% per-step accuracy → &lt;67% success at 20 steps (compounding) | arXiv:2601.16649, LUMINA, Jan 2026 |
| LLM judges are systematically overconfident; ensemble +47% accuracy | arXiv:2508.06225, LLM-as-a-Fuser, Aug 2025 |
| Agentic faults traverse architectural boundaries (37 fault categories) | arXiv:2603.06847, fault taxonomy, Mar 2026 |
| Automated failure attribution: 53.5% agent, 14.2% step accuracy | arXiv:2505.00212, ICML 2025 Spotlight |

---

## §2 Change Lifecycle

### 2.1 The Refinement Cycle

```
Observe (metrics.jsonl)
    → Identify pattern (what's failing?)
    → Hypothesize (why? instruction decay? bad routing? wrong rubric?)
    → Implement
    → Validate (hooks + evals)
    → Observe
```

---

## §3 Configuration Patterns

### 3.1 CLAUDE.md

| Property | Guideline |
|----------|-----------|
| Budget | < 60 lines |
| Content | Non-inferable only. Ask per-line: "Would removing this cause mistakes?" |
| Format | MUST/MUST NOT at the top. Flat structure, no deep nesting. |
| Imports | Use `@path` for on-demand detail (max 5 hops) |
| Authorship | Human-written, pruned. Never LLM-generated. |
| HTML comments | `<!-- -->` invisible to Claude in auto-injection; use for maintenance annotations only |
| Attention | Critical rules at top AND bottom of file; middle content suffers ~30% attention loss (U-shaped) |

**Anti-patterns:**
- Kitchen-sink CLAUDE.md (> 100 lines) — middle rules get ignored
- Duplicating rules between CLAUDE.md and `.claude/rules/`
- Using CLAUDE.md for domain knowledge (use skills instead)
- Code style rules in CLAUDE.md (belong in linters + hooks)
- Code snippets in CLAUDE.md (become stale; use file:line pointers instead)

### 3.2 AGENT.md

**Frontmatter template:**

```yaml
---
name: <agent-name>
description: >
  <Role identifier>. Use for: <positive triggers>.
  Does NOT: <negative triggers>.
tools: <allowlist — no wildcards, each MCP tool listed individually>
model: <haiku|sonnet|opus|inherit>
memory: <user|project|local>
maxTurns: <10-30>
---
```

| Property | Guideline |
|----------|-----------|
| Body budget | < 100 lines |
| description | ~140 chars max, action-oriented. Lead with role. "Use for:" / "Does NOT:" pattern. |
| tools | Allowlist only. List each tool explicitly. |
| model | Match to task complexity (see §8). `haiku\|sonnet\|opus\|inherit`; full model IDs also accepted (e.g., `claude-opus-4-5`) |
| maxTurns | Start at 10-20; increase only with evidence. |
| Tool selection | Include a `Tool Selection` table mapping question types to tools when agent has 3+ tools |

**Anti-patterns:**
- Behavioral instructions in the description field (degrades routing)
- Missing "Does NOT:" (causes false-positive routing)
- Omitting tools allowlist (agent gets all tools by default)

**Tool design (Agent-Computer Interface):**

| Principle | Guideline |
|-----------|-----------|
| Self-contained | Each tool description includes usage, edge cases, input format — no external docs required |
| Minimal overlap | If two tools serve similar purposes, add clear "Use X for A, Y for B" routing |
| Token-efficient returns | Tools return only what the agent needs, not raw dumps. Format for LLM consumption |
| Poka-yoke | Prefer specific parameters over free-form strings. Return actionable error messages |

**Anti-pattern:** Tool description that says "Use this tool to do X" without
input format, constraints, or when NOT to use it.

**Tool permission tiers (community consensus):**

| Role | Recommended tools |
|------|-------------------|
| Read-only (reviewers, auditors) | Read, Grep, Glob |
| Research | Read, Grep, Glob, WebFetch, WebSearch |
| Writer (implementers) | Read, Write, Edit, Bash, Glob, Grep |
| Documentation | Read, Write, Edit, Glob, Grep, WebFetch, WebSearch |

### 3.3 SKILL.md

**Frontmatter template:**

```yaml
---
name: <skill-name>
user-invocable: <true|false>
description: >
  <What it does>. Use when: <trigger conditions>.
  Triggers: "<phrase1>", "<phrase2>", "<phrase3>".
  Do NOT use for <out-of-scope> (other-skill-name).
tools:
  - Read
  - Glob
  - Grep
  - Bash(<domain-tool>*)
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
  - mcp__exa__web_search_exa
  - mcp__exa__get_code_context_exa
  - mcp__exa__crawling_exa
  - mcp__qdrant__qdrant-find
  - mcp__qdrant__qdrant-store
metadata:
  author: <owner>
  version: <semver>
  category: <advisory|workflow|knowledge|orchestration>
---
```

| Property | Guideline |
|----------|-----------|
| Body budget | < 500 lines |
| user-invocable | `false` for advisory skills auto-routed by description; `true` for user-triggered workflows |
| description | "Use when:" + `Triggers:` quoted phrases + "Do NOT use for:" with cross-refs to sibling skills |
| tools | Explicit per-tool list. Use `Bash(pattern*)` for scoped shell access. List each MCP tool individually |
| metadata | `author`, `version` (semver), `category` (`advisory` or `workflow`) |
| Side effects | Add `disable-model-invocation` for skills with side effects |
| Routing | Cause of phase transition is semantic confusability, not raw count |
| Scaling | Beyond 30 skills, adopt hierarchical namespacing to recover 37-40% routing accuracy |
| Category values | `advisory` (best practices), `workflow` (user-triggered), `knowledge` (safe in agent `skills:` field), `orchestration` (NOT safe in agent `skills:` field — circular delegation risk) |

**Body structure (advisory skills):**

| Section | Purpose |
|---------|---------|
| Tool Selection | Table mapping needs → tools (see §3.2 tool selection guideline) |
| Core Principles | 7-10 numbered, opinionated principles for the domain |
| Best Practices | 10 numbered actionable practices with detail |
| Anti-Patterns | 10 numbered mistakes to avoid |
| Examples | 3 worked scenarios: "User says → Actions → Result" |
| Troubleshooting | 3-4 error scenarios: "Error → Cause → Solution" |
| Review Checklist | 10 checkbox items reflecting principles and practices |

**Anti-patterns:**
- Orchestration logic in a skill (circular delegation risk)
- Skill that needs exclusive tools (should be an agent)
- `Triggers:` phrases too generic (causes false-positive routing across skills)
- Missing "Do NOT use for:" boundary (overlaps with sibling skills)

### 3.4 Hooks

| Property | Guideline |
|----------|-----------|
| Language | Shell script sourcing `_lib.sh` for JSON parsing |
| Exit codes | 0 = proceed, 2 = block with message, other = fail-open |
| Observability | Always fail-open: wrap in `{ ... } 2>/dev/null` blocks |
| Testing | `echo '{}' \| bash hook.sh` must not block |
| Timeout | 10 minutes (extended from 60s in v2.1.3) — supports long-running validation hooks |

**Lifecycle events (12 total):**

| Event | Since | Can block? | Notes |
|-------|-------|------------|-------|
| PreToolUse | Original | Yes | Matcher-scoped; use `hookSpecificOutput.permissionDecision` |
| PostToolUse | Original | No | Matcher-scoped; prefer `async: true` for observability |
| Stop | Original | No | Fires when Claude finishes |
| SubagentStop | Original | No | Fires when subagent finishes |
| SessionStart | Original | No | Fields: source, model, agent_type |
| SessionEnd | Original | No | Field: reason |
| PreCompact | Original | No | Fields: trigger, custom_instructions |
| Notification | Original | No | System notifications |
| SubagentStart | v2.0+ | No | Can inject additionalContext |
| UserPromptSubmit | v2.0+ | No | stdout added as Claude-visible context |
| PermissionRequest | v2.0.45+ | Yes | Auto-approve/deny permission dialogs |
| Setup | v2.1.10+ | No | Triggered by --init, --maintenance |

**Async hooks:** Add `"async": true` for PostToolUse observability hooks
(logging, metrics). Async hooks run in background without blocking Claude.
Do NOT use async for hooks that block or inject context.

**HTTP hooks:** `"type": "http"` hooks POST JSON to a URL instead of running
shell commands. Non-2xx = non-blocking error; 2xx + JSON body = parsed same
as command hooks.

**Deprecated output format:** Top-level `decision`/`reason` fields are
deprecated. Use `hookSpecificOutput.permissionDecision` and
`hookSpecificOutput.permissionDecisionReason` for PreToolUse blocking.

**Hook lifecycle for new constraints:**

1. Observe a recurring violation in metrics
2. Start as **warning** (exit 0 with logged message)
3. Promote to **hard gate** (exit 2) after confirming accuracy
4. Validate with metrics — confirm block rate drops

**Hook escalation ladder:**

| Level | Pattern | Risk |
|-------|---------|------|
| 1 | Auto-format on save (PostToolUse) | None |
| 2 | Block dangerous commands (PreToolUse) | Low |
| 3 | Block protected file edits (PreToolUse) | Low |
| 4 | Prompt enhancement (UserPromptSubmit) | Medium |
| 5 | AI review gate (PostToolUse subagent) | High |

**Anti-patterns:**
- Constraint without hook (< 20% compliance after 10 messages)
- Hook that blocks on monitoring failure (fail-closed observability)

### 3.5 Rubrics

**Template:**

```json
{
  "agent": "<agent-name>",
  "llm_judge": true,
  "judge_threshold": 3.0,
  "min_output_length": 200,
  "required_sections": ["Summary", "Sources"],
  "criteria": {
    "<criterion>": "<description> (1=<worst>, 5=<best>)"
  }
}
```

| Property | Guideline |
|----------|-----------|
| Criteria count | 3-5 per agent (more dilutes signal) |
| Anchors | Behavioral examples at 1 and 5 |
| Threshold | 3.0 default; 4.0 for security/compliance agents |
| Judge model | Always cheaper than evaluated agent (Haiku judges Sonnet) |

**Judge reliability:** LLM judges are systematically overconfident; scoring
confidence exceeds accuracy. Consider ensemble judging (LLM-as-a-Fuser) for
high-stakes evaluation.

**Two-tier evaluation:**

| Tier | Type | Examples |
|------|------|----------|
| 1 | Rule-based (deterministic) | Tool validity, schema compliance, file existence, test pass/fail |
| 2 | LLM-as-judge (probabilistic) | Planning quality, task completion, reasoning coherence |

Target 0.80+ Spearman correlation with human judgment for Tier 2 rubrics.

### 3.6 settings.json

| Property | Guideline |
|----------|-----------|
| Permissions | Deny > allow. Least privilege. |
| Wildcards | Never allow destructive wildcards (`rm -rf *`) |
| Env vars | Feature flags for experimental behavior |

### 3.7 Workflow Composition Patterns

Choose the simplest pattern that meets the task requirements.

| Pattern | When to use | Marvin mapping |
|---------|-------------|----------------|
| Single LLM call | Task is self-contained, no tools needed | Direct response (no delegation) |
| Prompt Chaining | Fixed sequence, each step depends on prior output | Sequential delegations via `.artifacts/` handoff |
| Routing | Input falls into distinct categories | `description` field routing to agents/skills |
| Parallelization | Independent subtasks with no shared state | Multiple parallel agent calls; sectioning or voting |
| Orchestrator-Workers | Subtask count unknown until runtime | Orchestrator dynamically spawning sub-agents |
| Evaluator-Optimizer | Output needs iterative refinement against criteria | Agent + rubric loop (generate → judge → refine) |
| Initializer + Coder | Task spans multiple context windows | Initializer writes TODO.md + progress log; Coder reads and advances incrementally |

**Decision rule:** Start at the top. Move down only when the pattern above
cannot meet quality, latency, or complexity requirements.

**Anti-pattern:** Jumping to Orchestrator-Workers for a task that prompt
chaining would solve. Each layer adds ~4x token cost.

> **Scaling insight:** Diversity of reasoning, not agent count, determines MAS
> effectiveness. Two agents with different models/strategies outperform sixteen
> homogeneous agents (arXiv:2602.03794).

### 3.8 Long-Horizon Strategies

For tasks that approach or exceed the context window:

| Strategy | Mechanism | When to use |
|----------|-----------|-------------|
| Compaction | Pre-compact hooks save state; post-compact hooks reinject | Session exceeds 64-75% context (auto-triggered) |
| Structured notes | Write progress and decisions to `.artifacts/` | Multi-step task where losing intermediate state is costly |
| Sub-agent decomposition | Delegate bounded subtasks with isolated context | Clear decomposition points; main context is saturated |
| Checkpoint files | Periodic writes with completed/remaining items | Long implementation tasks (10+ files) |
| Observation masking | Strip environment observations; preserve action + reasoning history | Prefer over LLM summarization: same efficacy, reversible, lower cost |

**Decision rule:** Use compaction hooks (already automated) as baseline.
Add structured notes when task state is non-trivial. Decompose into sub-agents
when a single context window cannot hold all relevant files simultaneously.

**Anti-pattern:** Continuing a long session without compaction or notes,
relying on the model to "remember" — compliance drops below 20% after context fills.

> **Error compounding warning:** 98% per-step accuracy compounds to &lt;67% success
> at 20 steps (LUMINA, arXiv:2601.16649). For specs with 5+ tasks, write a
> `claude-progress.txt` updated after each task to prevent redundant work on
> session restart.

### 3.9 Context Engineering Framework

Every piece of information in an agent's context belongs to one of four buckets.
Audit context by bucket to identify waste and gaps.

| Bucket | Definition | Marvin primitives |
|--------|-----------|-------------------|
| **Write** | Save information outside the context window | `.artifacts/` handoff, checkpoint files, `claude-progress.txt` |
| **Select** | Pull relevant information into context | Skills (on-demand), `@path` imports, Qdrant `qdrant-find` |
| **Compress** | Reduce tokens while preserving semantics | PreCompact hooks, observation masking, auto-compact |
| **Isolate** | Split context across agents/sessions | Subagent delegation, worktree isolation, `context: fork` |

**Decision rule:** Default to Write (reversible, zero information loss). Use
Select for retrieval. Use Compress only when Write + Select are insufficient.
Use Isolate when a single context window cannot hold all relevant files.

**Progressive disclosure (3-layer pattern):**

| Layer | What loads | Token cost | When |
|-------|-----------|------------|------|
| Discovery | name + description | ~100 tokens | Always (routing) |
| Activation | Full skill/rule body | 1-5K tokens | On relevance match |
| Execution | Examples, reference files | Variable | On demand |

---

## §4 Necessity Tests

Before creating any new artifact, answer these questions **in order**.

### 4.1 For any artifact

1. Has the pattern repeated **3+ times**?
2. Does it need **exclusive tools** or **context isolation**?
3. Is there a **simpler alternative** that already exists?

If all answers are NO → do not create the artifact.

### 4.2 For hooks specifically

4. Does the violation cause **real damage** (bad output, lost work, cost
   overrun)?
   - If NO → keep it as an instruction, not a hook.

### 4.3 Agent vs. Skill Decision

**Core distinction:** Skills are passive procedural knowledge that extends a
single agent's capabilities. Agents isolate context and execute with autonomous
judgment and dedicated tooling.

**Three-question litmus test (apply in order):**

| # | Question | If YES → |
|---|----------|----------|
| 1 | Does the domain require **exclusive tools** other agents don't need? | Agent (skills cannot add tools) |
| 2 | Does the prompt need **> 3-5K chars** of domain depth (DSL, decision trees, strategies)? | Agent (dedicated prompt body) |
| 3 | Does the orchestrator route **entire tasks** to this domain? | Agent (full-task routing signal) |

**Rule:** Q1 = YES → Agent. Q2 + Q3 both YES → Agent. Otherwise → Skill.

**Default:** When in doubt, start as a Skill. Skills are easier to promote to
agents than agents are to decompose back.

**Use-case guidance:**

| Use case | Recommendation | Rationale |
|----------|----------------|-----------|
| Coding conventions, style, anti-patterns | Skill (reference) | Fits in 2-3K chars; contextual; no exclusive tools |
| Deep domain with CLI (dbt, terraform, spark) | Agent | Exclusive CLI tools; DSL depth; full-task routing |
| Commit/deploy/release workflows | Skill (task, `disable-model-invocation`) | User-controlled side effects |
| Research / codebase exploration | Skill (`context: fork`) or Agent | Either works; skill is simpler if no exclusive tools |
| Security audit, compliance review | Agent | Exclusive tooling; deep domain; full-task routing |

**Architecture tiers (evidence-based):**

| Tier | When | Token cost |
|------|------|------------|
| Single-agent + skills | Skill library < 50; no exclusive tooling; tasks are sequential | Baseline (1x) |
| Single-agent + skills + domain agents | Deep domains need exclusive tools or prompt depth | ~4x per delegation |
| Agent Teams (experimental) | Parallel, decomposable, independent workloads only | ~15x; avoid for sequential tasks |

---

## §5 Quality Assurance

Three layers, from cheapest to most expensive.

### 5.1 Layer 1 — Structural (zero cost)

Run before every commit. Automated in pre-commit or manually:

```bash
# Hooks syntax
bash -n .claude/hooks/*.sh

# Settings JSON
python3 -c "import json; json.load(open('.claude/settings.json'))"

# Agent frontmatter
head -1 .claude/agents/*/AGENT.md   # Must start with ---
```

### 5.2 Layer 2 — Behavioral (~$0.002/eval)

Per-agent quality gate via `subagent-stop-gate.sh`:

1. **Mechanical checks first:** artifact presence, output length, failure
   phrase detection.
2. **LLM-as-judge second:** Haiku scores against per-agent rubric.
3. **Fail-open:** grading errors never block the pipeline.

Every new agent MUST have a rubric in `.claude/evals/rubrics/<name>.json`.

### 5.3 Layer 3 — Observational (zero cost)

Periodic scan of `metrics.jsonl` for trends:

| Metric | Signal | Threshold |
|--------|--------|-----------|
| Agent block rate | Invocation quality | > 20% → review prompt |
| LLM grade average | Output quality trend | Dropping → review rubric |
| `has_artifact` rate | Handoff adherence | < 80% → enforce protocol |
| Output length P10 | Task completion | < 100 chars → task too vague |
| Tool call spikes | Runaway loops | Sudden 3x → investigate |

---

## §6 Versioning

### 6.1 Semver Semantics for Config

| Level | When |
|-------|------|
| **MAJOR** | Remove agent/hook/skill; change invocation interface |
| **MINOR** | New agent/skill/hook; new MCP server integration |
| **PATCH** | Improve prompt; adjust threshold; fix bug |

### 6.2 Changelog Format

Use Keep-a-Changelog. Each entry lists the modified file:

```markdown
## [0.2.0]

### Added
- `skills/commit/SKILL.md` — commit workflow skill

### Changed
- `agents/researcher/AGENT.md`: memory: project, maxTurns: 20

### Fixed
- `hooks/subagent-stop-gate.sh`: add Exa usage verification
```

---

## §7 Anti-Patterns

| Anti-pattern | Why it fails | Alternative |
|-------------|--------------|-------------|
| CLAUDE.md > 100 lines | Lost-in-the-middle degrades compliance ~30% | `.claude/rules/*.md` for path-scoped rules |
| LLM-generated CLAUDE.md | -0.5 to -3% task success (ETH Zurich 2026) | Human-authored, pruned regularly |
| Agent registry file | Dual source of truth; drifts from actual agents | `description` field IS the routing |
| Skill with orchestration | Circular delegation; skills can't spawn agents | Knowledge-only skills |
| Constraint without hook | < 20% compliance after 10 messages | Hook for deterministic enforcement |
| Infinite retry | Context grows with each retry; compounds errors | Max 2 retries, then escalate to user |
| Conversational relay | Copies tokens into context; information loss | Filesystem handoff via `.artifacts/` |
| Overly broad tools allowlist | Agent can do unintended damage | Explicit allowlist per agent |
| Judge model = evaluated model | Self-assessment bias | Always use cheaper judge (Haiku → Sonnet) |
| Premature multi-agent | Above 45% single-agent accuracy, agents degrade performance | Exhaust single-agent + skills first |
| Skill library sprawl (> 50 skills) | Selection accuracy degrades sharply (phase transition) | Curate; promote overloaded areas to agents |
| Context pollution in subagents | Injecting orchestrator context defeats isolation purpose | Subagent value comes from clean, bounded context |
| Memory poisoning via stale RAG | Stale/incorrect memories accumulate and corrupt future reasoning | Periodic `/reflect` audits; confidence decay; fresh session + enriched context |
| Homogeneous agent teams | Correlated outputs = one effective reasoning channel regardless of count | Ensure diversity: different models, prompts, or strategies per agent |
| Uncalibrated LLM-as-judge | Overconfident scoring; false early termination in eval loops | Ensemble judging; 0.80+ Spearman correlation target with human judgment |
| Code style rules in CLAUDE.md | Expensive, slow, wastes context; linters are deterministic and free | Move to hooks (PostToolUse formatters/linters) |
| Infinite retry without session reset | Failed attempts contaminate context; error compounds each iteration | Max 2 retries, then `/clear` or fresh session with enriched context |

---

## §8 Model Selection

| Model | When to use | Example tasks |
|-------|-------------|---------------|
| `haiku` | Read-only, classification, grading, status checks | Quality gate scoring, file search, status skill |
| `sonnet` | General implementation, research, analysis | Feature implementation, researcher agent |
| `opus` | Architecture, complex reasoning, ambiguity resolution | Plan mode, multi-domain orchestration |
| `inherit` | No reason to override session default | Most cases — only override with evidence |

**Cost awareness:** Multi-agent hub-spoke uses ~4x tokens vs. single chat.
Agent teams (experimental) use ~15x. Always justify model upgrades with
measurable quality improvement.

---

## §9 Pre-Commit Checklist

Before committing changes to any `.claude/` file:

- [ ] `bash -n .claude/hooks/*.sh` — all hooks parse
- [ ] `python3 -c "import json; json.load(open('.claude/settings.json'))"` — valid JSON
- [ ] `head -1 .claude/agents/*/AGENT.md` — frontmatter starts with `---`
- [ ] New agent → rubric created in `.claude/evals/rubrics/<name>.json`
- [ ] Changed `description` → no conflicts with other agents' routing
- [ ] Changed hook → `echo '{}' | bash hook.sh` does not block (exit 0)
- [ ] CHANGELOG.md entry added with affected file paths
- [ ] If new artifact → §4 necessity test answers documented

---

## References

- [Anthropic: Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents) — canonical orchestration patterns
- [Anthropic: Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — context management strategies
- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Initializer + Coder pattern
- [Anthropic: Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — evaluation strategies
- arXiv:2511.12884 — "Context debt" and instruction decay empirics
- arXiv:2602.11988 — ETH Zurich study on LLM-generated instruction files
- Lost in the Middle (TACL 2024) — positional attention bias in LLMs
- IFEval (2025) — instruction-following evaluation benchmark
- MT-Bench — LLM-as-judge methodology and chain-of-thought scoring
- [Anthropic: Equipping Agents with Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) — skills as capability extensions vs agents as autonomous entities
- arXiv:2512.08296 — MAS scaling science; 58–515% overhead; capability ceiling at 45%
- arXiv:2601.04748 — single-agent + skills vs MAS; phase transition at ~50-100 skills
- arXiv:2601.12307 — single-agent + skills competitive with multi-agent workflows
- arXiv:2503.13657 — MAS failure modes; context pollution as primary failure cause
- arXiv:2602.03794 — agent scaling via diversity; 2 diverse > 16 homogeneous
- arXiv:2602.03219 — trajectory diversity scaling for code agents
- arXiv:2601.07190 — active context compression; scaffolded compaction
- arXiv:2601.11653 — memory poisoning as distinct failure mode
- arXiv:2601.16649 — LUMINA; error compounding in long-horizon tasks
- arXiv:2508.06225 — LLM-as-judge overconfidence; ensemble +47% accuracy
- arXiv:2603.06847 — agentic fault taxonomy; 37 categories across boundaries
- arXiv:2505.00212 — failure attribution in MAS; ICML 2025 Spotlight
- [JetBrains: Efficient Context Management](https://blog.jetbrains.com/research/2025/12/efficient-context-management/) — observation masking, NeurIPS 2025
- [Phil Schmid: Context Engineering](https://www.philschmid.de/context-engineering) — 4-bucket taxonomy
