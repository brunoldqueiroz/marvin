# Specification: Marvin v0.2.0

## Context

Two research efforts inform this spec:

1. **Instruction file efficacy** (ETH Zurich 2026, Lost in the Middle 2024,
   IFEval 2025) — CLAUDE.md instructions are soft guidance with ~85% compliance
   at session start, decaying to <20% after 10+ messages. LLM-generated files
   reduce task success. Hooks are the only deterministic enforcement.

2. **Agent/skill optimizations** (Anthropic, Google/MIT, community) —
   single-agent + skills is 54% cheaper than multi-agent up to ~50-100 skills.
   Skills inject knowledge without isolation. Agents isolate with exclusive tools.

### Guiding principle

> Instructions for what the model **should prefer**.
> Hooks for what the model **must not violate**.
> Skills for **on-demand** knowledge.
> Agents for **isolated execution with exclusive tools**.

---

## 1. CLAUDE.md

### Current state: 31 lines, 4 sections

The current CLAUDE.md is lean and focused. Research validates this approach —
short files with non-inferable content outperform long files with redundant
content.

### Changes

#### 1.1 Add Verify section

The most valuable content in instruction files (77.1% adoption per
arXiv:2509.14744) are build/test commands. Marvin is a configuration project,
but it still has verifications:

```markdown
## Verify

- Hooks: `bash -n .claude/hooks/*.sh` (syntax check)
- Settings: `python3 -c "import json; json.load(open('.claude/settings.json'))"`
- Agent YAML: `head -1 .claude/agents/*/AGENT.md` (verify frontmatter starts with ---)
```

**Rationale**: these commands are not inferable — they are specific to Marvin's
structure. They are the first candidates to survive attention decay.

#### 1.2 Remove duplication in compact-reinject.sh

The `compact-reinject.sh` hook hardcodes "You are Marvin..." on line 14. This
duplicates CLAUDE.md and creates context debt. Replace with:

```bash
CONTEXT="POST-COMPACTION CONTEXT RECOVERY
Re-read .claude/CLAUDE.md now for your full instructions."
```

No hardcoded identity — CLAUDE.md already covers this and will be reloaded.

#### 1.3 Consider `.claude/rules/` for conditional rules

If new skills or agents introduce path-scoped conventions, use
`.claude/rules/*.md` with `paths:` frontmatter instead of bloating CLAUDE.md.

**Note**: known bug (issues #16299, #16853) — path-scoped rules load globally
in some versions. Test before adopting.

#### 1.4 Final budget

| Section | Lines |
|---------|-------|
| Identity | 3 |
| Before Acting | 4 |
| Verify | 5 |
| Handoff Protocol | 10 |
| Failure Recovery | 4 |
| **Total** | **~26-30** |

Well within the ~300 line budget. Room to grow as the project gains complexity —
but only add what demonstrates impact.

---

## 2. Agents

### Current state: 1 agent (researcher, 76 lines, model: sonnet)

### 2.1 Researcher — fine-tuning

**Tool priority enforcement** (already implemented this session):
- `MUST use Exa and Context7` at the top of AGENT.md
- WebSearch as explicit fallback
- PreToolUse hook blocking WebSearch globally (implemented, removed by user
  for testing — re-enable when validated)

**Additional changes:**

| Field | Current | Proposed | Rationale |
|-------|---------|----------|-----------|
| `memory` | `user` | `project` | Research is project-specific, not user-global |
| `maxTurns` | 30 | 20 | ETH Zurich research: agents with context files over-explore. Limiting turns forces focus |

**Keep**: model: sonnet (research requires synthesis, not just lookup).

### 2.2 New agents — needs analysis

Research recommends: "single agent + skills is 54% cheaper up to ~50-100
skills." Marvin is a configuration project with few files. Multi-agent is
justified when:

1. Exclusive tools are needed
2. Isolation protects the main context
3. Tasks are genuinely parallelizable

**Conclusion**: do not create new custom agents now. Built-ins (Explore, Plan,
general-purpose) cover the remaining cases. Re-evaluate when the project grows
or when a delegation pattern repeats 3+ times.

### 2.3 Agent creation convention

When a new agent is needed, follow this convention:

#### File structure

```
.claude/agents/<agent-name>/AGENT.md
```

Lowercase name with hyphens. One directory per agent.

#### AGENT.md template

```yaml
---
name: <agent-name>
description: >
  <Role>. Use for: <trigger 1>, <trigger 2>, <trigger 3>.
  Does NOT: <anti-trigger 1>, <anti-trigger 2>.
tools: <allowlist — list ONLY required tools>
model: <haiku|sonnet|opus>
memory: project
maxTurns: <15-30>
---

# <Agent Name>

<One sentence: who this agent is.>

## Constraints

- MUST <mandatory constraint 1>
- MUST <mandatory constraint 2>
- MUST NOT <anti-pattern 1>
- PREFER <soft preference>

## How You Work

1. <Step 1>
2. <Step 2>
3. <Step 3>

## Output Format

Write results to `.artifacts/<agent-name>.md`:

\```markdown
# <Output template>
\```
```

#### Design rules

| Rule | Rationale |
|------|-----------|
| `description` with "Use for: / Does NOT:" pattern | Routing rate 72-90% vs 20% for generic |
| Tools as explicit allowlist, not inheritance | Least privilege principle; prevents unwanted access |
| `model: haiku` for read-only agents | 54% cheaper; sufficient for lookup and analysis |
| `model: sonnet` for agents that write | Cost/quality balance for generation |
| `model: opus` only for architectural reasoning | Reserve for complex multi-domain synthesis |
| `memory: project` for recurring agents | Accumulates cross-session knowledge |
| `maxTurns` between 15-30 | Avoids exploration paradox (ETH Zurich) |
| Constraints with MUST/MUST NOT at top of body | High-attention position (Lost in the Middle) |
| Output to `.artifacts/` | Filesystem handoff, not conversational summary |
| Body < 100 lines | Instruction budget ~150-200 total; agent system prompt consumes ~50 |

#### Necessity test (3 questions)

Before creating an agent, answer:

1. **Does it need exclusive tools?** If not, consider a skill
2. **Has the pattern repeated 3+ times?** If not, defer
3. **Does isolation protect the main context?** If not, do it inline

If all answers are "no" → do not create the agent.

#### Concrete example: code-reviewer (future)

```yaml
---
name: code-reviewer
description: >
  Code review specialist. Use for: reviewing diffs, identifying bugs, security
  issues, style violations, code quality assessment. Does NOT: implement fixes,
  run tests, modify files, refactor code.
tools: Read, Grep, Glob
model: haiku
memory: project
maxTurns: 15
---

# Code Reviewer

You review code for correctness, security, and maintainability.

## Constraints

- MUST read all changed files before giving feedback
- MUST categorize issues by severity (critical, warning, suggestion)
- MUST NOT suggest changes — only identify issues
- PREFER citing specific line numbers

## How You Work

1. Read the diff or files specified in the task
2. Analyze for: bugs, security issues, style violations, complexity
3. Categorize findings by severity
4. Write structured review to `.artifacts/code-reviewer.md`

## Output Format

Write results to `.artifacts/code-reviewer.md`:

\```markdown
# Code Review

## Critical
- [file:line] Issue description

## Warnings
- [file:line] Issue description

## Suggestions
- [file:line] Suggestion
\```
```

---

## 3. Skills

### Current state: 0 skills

### 3.1 When to create a skill vs an agent

| Question | If yes → |
|----------|----------|
| Needs exclusive tools or isolation? | Agent |
| Instructions > 3K chars AND full task routing? | Agent |
| Otherwise? | **Skill** |

Skills are lighter: they inject knowledge into the current session without a
subprocess, inherit tools from the parent, and use progressive disclosure
(~100 tokens at discovery, full content only when activated).

### 3.2 Skill creation convention

#### File structure

```
.claude/skills/<skill-name>/
├── SKILL.md           # Required — main instructions
├── references/        # Optional — technical docs (loaded on demand)
├── assets/            # Optional — static files by path
└── scripts/           # Optional — scripts Claude can execute
```

Lowercase name with hyphens. SKILL.md is the only required file.

#### SKILL.md template

```yaml
---
name: <skill-name>
description: >
  <What it does>. Use when: <trigger 1>, <trigger 2>, <trigger 3>.
user-invocable: <true|false>
disable-model-invocation: <true if it has side effects>
allowed-tools: <restrict if needed>
model: <haiku for read-only, omit to inherit>
---

## <Workflow Name>

<Step-by-step instructions in Markdown>
```

#### Design rules

| Rule | Rationale |
|------|-----------|
| `description` with "Use when:" pattern | Activation rate 72-90% vs 20% for generic |
| `disable-model-invocation: true` for side effects | Deploy, commit, push — user-only invocation |
| `user-invocable: false` for background knowledge | Conventions, patterns — Claude invokes automatically |
| SKILL.md < 500 lines | Extensive docs go in `references/` |
| `$ARGUMENTS` substitutions for dynamic input | Avoids hardcoding |
| `` !`command` `` for dynamic context injection | Git state, diffs, etc. |
| `context: fork` for long analyses | Protects the main context |
| `model: haiku` for read-only skills | Reduces cost without losing quality |

#### Invocation matrix

| Scenario | Frontmatter |
|----------|-------------|
| User and Claude can invoke (default) | no extra fields |
| User only (side effects: commit, deploy) | `disable-model-invocation: true` |
| Claude only (background knowledge) | `user-invocable: false` |

#### Description quality — empirical data

| Description type | Activation rate |
|------------------|-----------------|
| Generic ("helps with code") | ~20% |
| Clear keywords ("review, test, lint") | ~50% |
| With "Use when:" + triggers | **~72-90%** |

**Mandatory rule**: every description MUST include "Use when:" followed by
concrete examples of user phrases that activate the skill.

### 3.3 Skills to create

#### Skill 1: `/commit`

**Rationale**: commit is a side-effect action that needs a consistent workflow.
`disable-model-invocation: true` ensures only the user invokes it.

```yaml
---
name: commit
description: >
  Create a structured git commit. Use when: the user says "commit",
  "save changes", or asks to commit work.
disable-model-invocation: true
allowed-tools: Bash(git *)
---

## Commit Workflow

1. Run `git status` and `git diff --staged` to see changes
2. If nothing staged, ask user what to stage
3. Draft a commit message following conventional commits:
   - feat: new feature
   - fix: bug fix
   - refactor: code restructuring
   - docs: documentation
   - chore: maintenance
4. Show the message to the user before committing
5. Commit with the approved message
```

#### Skill 2: `/status`

**Rationale**: project state visibility — session log, metrics, git status.
Read-only, no side effects.

```yaml
---
name: status
description: >
  Show Marvin project status. Use when: the user asks for status, health check,
  or session history.
user-invocable: true
allowed-tools: Read, Bash(git *)
model: haiku
---

## Status Report

Read and summarize:
1. `git status` + `git log --oneline -10`
2. `.claude/dev/session-log.md` — last 3 sessions
3. `.claude/dev/metrics.jsonl` — agent usage stats (last 20 entries)

Present as a concise status report.
```

### 3.4 Skills NOT to create (and why)

| Idea | Why not |
|------|---------|
| `/research` | Redundant with researcher agent; evaluation pending |
| `/review-pr` | No PR workflow defined yet |
| `/deploy` | Marvin has no deploy |
| `/explain-code` | The model already does this well without a skill |
| `/refactor` | Better as agent if isolation is needed |

---

## 4. Hooks — Enforcement Strategy

### Current state: 5 hooks

| Hook | Trigger | Function |
|------|---------|----------|
| session-context.sh | SessionStart(startup) | Injects git + previous session |
| compact-reinject.sh | SessionStart(compact) | Recovers context post-compaction |
| pre-compact-save.sh | PreCompact | Snapshot before compaction |
| session-persist.sh | Stop | Transcript → session log |
| subagent-quality-gate.sh | SubagentStop | Validates output + metrics |

### 4.1 New hook: block-websearch.sh

**Already implemented** (removed for testing). When re-enabled:

```
PreToolUse(WebSearch) → exit 2 → "Use mcp__exa__web_search_exa instead"
```

**Classification**: hard enforcement — call intercepted before execution.

### 4.2 Improvement: subagent-quality-gate.sh

Add tool usage verification for the researcher:

```bash
# If agent_type contains "researcher", verify Exa was used
if echo "$AGENT_NAME" | grep -qi "researcher"; then
  if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
    EXA_USED=$(grep -c "mcp__exa__" "$AGENT_TRANSCRIPT" 2>/dev/null || echo "0")
    if [ "$EXA_USED" -eq 0 ]; then
      echo "Researcher did not use Exa tools. Retry with explicit instruction to use mcp__exa__web_search_exa." >&2
      exit 2
    fi
  fi
fi
```

### 4.3 Enforcement map

| Requirement | Instruction (soft) | Hook (hard) |
|-------------|-------------------|-------------|
| Commit style | skill /commit | — |
| Exa over WebSearch | AGENT.md MUST | PreToolUse block |
| Output in .artifacts/ | handoff protocol | SubagentStop check |
| Don't delete .env | — | permissions.deny |
| Output format | AGENT.md template | — |

**Principle**: if a violation causes real harm → hook. If it's a preference → instruction.

---

## 5. Change Summary

### Files to modify

| File | Change |
|------|--------|
| `.claude/CLAUDE.md` | Add Verify section (~5 lines) |
| `.claude/agents/researcher/AGENT.md` | `memory: project`, `maxTurns: 20` |
| `.claude/hooks/compact-reinject.sh` | Remove hardcoded identity |
| `.claude/hooks/subagent-quality-gate.sh` | Add Exa verification for researcher |
| `.claude/settings.json` | Add PreToolUse hook (when validated) |

### Files to create

| File | Type |
|------|------|
| `.claude/skills/commit/SKILL.md` | Skill — commit workflow |
| `.claude/skills/status/SKILL.md` | Skill — project status |
| `.claude/hooks/block-websearch.sh` | Hook — already created |

### Files NOT to create

| File | Reason |
|------|--------|
| New custom agents | Built-ins cover the need; 3+ repetition rule |
| `.claude/rules/*.md` | No path-scoped rules needed yet |
| `CLAUDE.local.md` | No divergent personal preferences |

### README/CHANGELOG version

- v0.2.0: "Add skills system, hook-based enforcement, CLAUDE.md optimization"
