# Marvin Development Standard

> Before creating or modifying agents, skills, hooks, or settings — consult
> this document. It codifies empirically validated patterns for evolving
> AI-augmented development projects.

**Version:** 1.0 — February 2026
**Applies to:** all files under `.claude/`, `docs/spec-*.md`, and project-level
configuration.

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
   to preserve context budget for actual work.
2. **`description` field is the routing signal.** Separate routing (when to
   call) from behavior (how to act). Never mix them.
3. **Filesystem handoff > conversational relay.** Write to `.artifacts/`, read
   back. Never copy large outputs through conversation history.
4. **Config-as-code.** CLAUDE.md, AGENT.md, hooks, and settings.json deserve
   the same rigor as production code: version control, review, testing.
5. **Probabilistic instructions need deterministic enforcement.** If a
   constraint matters after 10+ messages, back it with a hook.

### 1.3 Evidence Base

| Claim | Source |
|-------|--------|
| Instructions degrade ~85% → <20% over context | arXiv:2511.12884 "context debt" |
| Middle-of-file rules get ~30% less attention | Lost in the Middle, TACL 2024 |
| LLM-generated CLAUDE.md reduces success 0.5–3% | arXiv:2602.11988, ETH Zurich 2026 |
| IFEval compliance drops beyond ~150 instructions | IFEval benchmark, 2025 |
| Multi-agent uses ~4x tokens (hub-spoke), ~15x (mesh) | Anthropic engineering blog, 2025 |

---

## §2 Change Lifecycle

### 2.1 The Refinement Cycle

```
Observe (metrics.jsonl)
    → Identify pattern (what's failing?)
    → Hypothesize (why? instruction decay? bad routing? wrong rubric?)
    → Write spec (docs/spec-vX.Y.md)
    → Implement
    → Validate (hooks + evals)
    → Observe
```

### 2.2 Spec Discipline

- Every non-trivial change starts with a spec in `docs/spec/spec-vX.Y.md`.
- Spec is committed **before** implementation begins.
- Specs are **frozen after shipping** — never update a shipped spec. Write a
  new one instead.
- Reference specs in artifact headers:
  ```bash
  # Spec: docs/spec/spec-v0.2.0.md §4.1
  ```

### 2.3 Spec Structure

A spec MUST include:

1. **Context** — research citations that motivated the change
2. **Guiding principle** — one memorable statement
3. **Change table** — files to create / modify / NOT create, with rationale
4. **Design rules** — `| Rule | Rationale |` format
5. **Necessity tests** — answers to §4 tests for every new artifact
6. **Implementation order** — phased rollout

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

**Anti-patterns:**
- Kitchen-sink CLAUDE.md (> 100 lines) — middle rules get ignored
- Duplicating rules between CLAUDE.md and `.claude/rules/`
- Using CLAUDE.md for domain knowledge (use skills instead)

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
| description | Lead with role. "Use for:" / "Does NOT:" pattern. |
| tools | Allowlist only. List each tool explicitly. |
| model | Match to task complexity (see §8). |
| maxTurns | Start at 10-20; increase only with evidence. |

**Anti-patterns:**
- Behavioral instructions in the description field (degrades routing)
- Missing "Does NOT:" (causes false-positive routing)
- Omitting tools allowlist (agent gets all tools by default)

### 3.3 SKILL.md

**Frontmatter template:**

```yaml
---
name: <skill-name>
description: >
  <What it does>. Use when: <trigger conditions>.
  Does NOT: <what it cannot do>.
tools: <allowlist>
---
```

| Property | Guideline |
|----------|-----------|
| Body budget | < 500 lines |
| description | "Use when:" trigger pattern |
| Side effects | Add `disable-model-invocation` for skills with side effects |

**Anti-patterns:**
- Orchestration logic in a skill (circular delegation risk)
- Skill that needs exclusive tools (should be an agent)

### 3.4 Hooks

| Property | Guideline |
|----------|-----------|
| Language | Shell script sourcing `_lib.sh` for JSON parsing |
| Exit codes | 0 = proceed, 2 = block with message, other = fail-open |
| Observability | Always fail-open: wrap in `{ ... } 2>/dev/null` blocks |
| Testing | `echo '{}' \| bash hook.sh` must not block |

**Hook lifecycle for new constraints:**

1. Observe a recurring violation in metrics
2. Start as **warning** (exit 0 with logged message)
3. Promote to **hard gate** (exit 2) after confirming accuracy
4. Validate with metrics — confirm block rate drops

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

### 3.6 settings.json

| Property | Guideline |
|----------|-----------|
| Permissions | Deny > allow. Least privilege. |
| Wildcards | Never allow destructive wildcards (`rm -rf *`) |
| Env vars | Feature flags for experimental behavior |

---

## §4 Necessity Tests

Before creating any new artifact, answer these questions **in order**.
Document the answers in the spec.

### 4.1 For any artifact

1. Has the pattern repeated **3+ times**?
2. Does it need **exclusive tools** or **context isolation**?
3. Is there a **simpler alternative** that already exists?

If all answers are NO → do not create the artifact.

### 4.2 For hooks specifically

4. Does the violation cause **real damage** (bad output, lost work, cost
   overrun)?
   - If NO → keep it as an instruction, not a hook.

### 4.3 Agent vs. Skill decision

5. Does the domain require **exclusive tools** other agents don't need?
   - If YES → Agent.
6. Does the prompt need **> 3K characters** AND require **full-task routing**?
   - If both YES → Agent.
   - Otherwise → Skill.

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

Per-agent quality gate via `subagent-quality-gate.sh`:

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
- `hooks/subagent-quality-gate.sh`: add Exa usage verification
```

### 6.3 Spec Immutability

- Shipped specs are frozen. Never retroactively update `docs/spec/spec-v0.1.0.md`.
- Corrections go in the next spec version.
- Link implementations back to specs via header comments.

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

Before committing changes to any `.claude/` file or `docs/spec-*.md`:

- [ ] `bash -n .claude/hooks/*.sh` — all hooks parse
- [ ] `python3 -c "import json; json.load(open('.claude/settings.json'))"` — valid JSON
- [ ] `head -1 .claude/agents/*/AGENT.md` — frontmatter starts with `---`
- [ ] New agent → rubric created in `.claude/evals/rubrics/<name>.json`
- [ ] Changed `description` → no conflicts with other agents' routing
- [ ] Changed hook → `echo '{}' | bash hook.sh` does not block (exit 0)
- [ ] CHANGELOG.md entry added with affected file paths
- [ ] If new artifact → §4 necessity test answers documented in spec

---

## References

- [Anthropic: Building Effective Agents](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/be-clear-and-direct) — canonical orchestration patterns
- arXiv:2511.12884 — "Context debt" and instruction decay empirics
- arXiv:2602.11988 — ETH Zurich study on LLM-generated instruction files
- Lost in the Middle (TACL 2024) — positional attention bias in LLMs
- IFEval (2025) — instruction-following evaluation benchmark
- MT-Bench — LLM-as-judge methodology and chain-of-thought scoring
