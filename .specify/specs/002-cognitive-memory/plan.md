# Plan — Cognitive Memory System

> Implementation strategy derived from spec 002. Reviewable checkpoint before
> writing code.

## Approach

Implement a 4-layer cognitive memory system using Qdrant (already connected via
MCP) as the vector store and structured Markdown files as the human-readable
layer. Each layer is independently valuable — we ship Layer 1 first and iterate.
The system integrates into Marvin's existing workflow through skills and
CLAUDE.md rules, not through code changes to agents.

### Research-Informed Refinements

The researcher agent surveyed 14+ sources (2025-2026). Key findings that
shaped this plan:

1. **Markdown-first is validated**: Letta's filesystem scores 74% on LoCoMo
   benchmark, beating specialized memory libraries. We use markdown as the
   primary layer, Qdrant for cross-session semantic search only.
2. **Single Qdrant collection confirmed**: Official Qdrant guidance recommends
   tenant isolation via payload index, not separate collections.
3. **SaMuLe's 3-level reflection** (AWS AI Labs, arXiv:2509.20562): micro
   (per-session), meso (per-task), macro (cross-task) — adopted for error
   pattern extraction in Layer 2.
4. **Devil's Advocate > Tree of Thoughts**: Full ToT is too complex for CLI
   agents. A 3-round DA review reduced high-severity issues by 89% in
   production (zenn.dev, Feb 2026). Adopted for Layer 3.
5. **Cost reality check**: Blake Crosley's 10-agent deliberation panel killed
   a 200-400h memory retrieval project that would save $5/month. Our plan
   avoids this trap — we use existing Qdrant MCP (zero new infra), markdown
   files (zero cost), and deliberation only for high-stakes decisions.
6. **Claude Diary pattern** (Lance Martin, Dec 2025): diary → reflect →
   CLAUDE.md update. Adopted as the feedback loop for error patterns.

Full research: [research.md](./research.md)

## Components

### C1 — Qdrant Schema & Memory Skill (Foundation)

- **What**: Define the Qdrant collection schema and create a `memory-manager`
  skill that provides prompt patterns for storing and retrieving memories. This
  is the infrastructure all other layers depend on.
- **Files to create**:
  - `.claude/skills/memory-manager/SKILL.md` — skill with store/retrieve
    patterns, schema documentation, and integration instructions
  - `.claude/rules/memory.md` — rules for when and how to log memories
    (loaded automatically via path matching)
- **Dependencies**: None — uses existing `qdrant-store` and `qdrant-find` MCP
  tools.
- **Schema design** (refined by research — see research.md §3):
  ```
  Collection: marvin-memory

  Each record:
  - content (embedded): synthesized summary for retrieval (2-3 sentences)
    Chunk sizes: 256 tokens for facts/patterns, 512 for session summaries
  - metadata (payload, indexed for fast filtering):
    - type: "decision" | "error-pattern" | "knowledge" | "deliberation"
    - project: project identifier (from git remote or directory name)
    - domain: free-text domain tags (e.g., "python", "architecture", "testing")
    - timestamp: ISO-8601
    - confidence: float 0.0-1.0 (increases with confirmation)
    - session_id: session identifier for traceability
    - files_affected: list of file paths involved
    - outcome: "success" | "failure" | "pending" | "unknown"
  ```
  Note: Qdrant MCP handles embedding automatically — we pass text via
  `qdrant-store`, no separate embedding pipeline needed.

### C2 — Decision Log (Layer 1)

- **What**: Integrate decision logging into Marvin's workflow. After significant
  decisions, store a structured record. Before new decisions, retrieve relevant
  history.
- **Files to create/modify**:
  - `.claude/rules/memory.md` (extend with decision logging triggers)
  - `.claude/skills/memory-manager/SKILL.md` (add decision record template)
- **Dependencies**: C1 (schema must exist first).
- **Decision record template**:
  ```markdown
  ## Decision Record
  - **Context**: [what problem was being solved]
  - **Decision**: [what was chosen]
  - **Alternatives**: [what else was considered]
  - **Rationale**: [why this option won]
  - **Domain**: [architecture | tooling | design | convention]
  - **Project**: [project identifier]
  ```
- **Integration points**:
  - CLAUDE.md rule: "After architectural decisions affecting 2+ files, log
    to memory using the memory-manager skill pattern"
  - Pre-decision retrieval: "Before choosing an approach for non-trivial
    changes, query memory for similar past decisions"

### C3 — Error Pattern Extraction (Layer 2)

- **What**: When users correct Marvin, extract the error class and store it
  as a retrievable anti-pattern. Before acting, query for relevant anti-patterns.
- **Files to create/modify**:
  - `.claude/skills/memory-manager/SKILL.md` (add error pattern template)
  - `.claude/rules/memory.md` (add error extraction triggers)
- **Dependencies**: C1 (schema), C2 (builds on same workflow pattern).
- **Error pattern template**:
  ```markdown
  ## Error Pattern
  - **Trigger**: [what kind of task triggers this error]
  - **Symptom**: [what the error looks like]
  - **Root cause**: [why it happens — the class, not the instance]
  - **Correct approach**: [what to do instead]
  - **Domain**: [python | architecture | testing | ...]
  - **Confidence**: [0.0-1.0, increases with reconfirmation]
  ```
- **Extraction heuristic** (informed by SaMuLe 3-level reflection):
  - **Micro** (per-session): When user corrects output → extract immediate
    error pattern and store
  - **Meso** (per-task): After completing a multi-step task → reflect on
    what went well/badly across the task's steps
  - **Macro** (cross-task): Periodic reflect pass (manual `/reflect` trigger)
    → analyze stored micro/meso patterns → distill cross-cutting insights
    → propose CLAUDE.md rule updates for user approval
- **Confidence escalation**: If a similar error pattern already exists in
  Qdrant (similarity > 0.85), increment confidence instead of creating a
  duplicate. Threshold: 2 occurrences = pattern, 3+ = strong pattern
  (from Generative Agents / Claude Diary research).

### C4 — Structured Deliberation Skill (Layer 3)

- **What**: A loadable skill that implements structured "slow thinking" for
  high-stakes decisions. Integrates with the decision log — deliberation
  outputs become rich decision records.
- **Files to create**:
  - `.claude/skills/deliberation/SKILL.md` — the deliberation skill with:
    - When to use (heuristics: 3+ files, new dependency, public API change)
    - Process: generate alternatives → devil's advocate → pre-mortem → decide
    - Output format: structured deliberation record
    - Integration: auto-stores result in decision log via memory-manager
- **Dependencies**: C1 (schema), C2 (decision log for storage).
- **Deliberation process** (synthesized from Devil's Advocate research
  [EMNLP 2024], Crosley's 10-agent panel, and Klein's pre-mortem):
  ```
  1. FRAME      — State the decision clearly in one sentence
  2. GENERATE   — List 2-3 viable approaches (not just the obvious one)
  3. ATTACK     — For each approach: devil's advocate objection
                  (explicit "no sycophancy" — challenge the premise)
  4. COST CHECK — "What does building this actually cost?" (time, tokens,
                  complexity, maintenance burden) — the most underrated step
  5. PREMORTEM  — For the leading approach: "It's 6 months later and this
                  failed. What went wrong?" (Klein's technique)
  6. DECIDE     — Choose with explicit confidence level (HIGH/MED/LOW)
  7. LOG        — Store as decision record with full deliberation trace
  ```
- **When NOT to deliberate** (from Bezos Type 1/Type 2 framework):
  - NEVER: docs fixes, variable renames, test fixtures, log messages
  - SKIP: behind feature flag, single file, low reversal cost
  - DELIBERATE: irreversible (schema, public API), 3+ files, new dependency,
    confidence < 0.70, outside primary expertise

### C5 — Project Knowledge Map (Layer 4)

- **What**: A persistent, human-editable file that captures project structure,
  key modules, dependencies, and architectural invariants. Updated
  incrementally, consulted on session start.
- **Files to create**:
  - `.claude/memory/knowledge-map.md` — the knowledge map itself
  - `.claude/rules/memory.md` (extend with knowledge map update triggers)
- **Dependencies**: C1 (can store knowledge entries in Qdrant too), but
  primarily uses local files.
- **Knowledge map structure**:
  ```markdown
  # Project Knowledge Map
  <!-- Auto-updated by Marvin. Human-editable. -->

  ## Modules
  - `.claude/skills/` — skill library (16 skills, advisory pattern)
  - `.claude/agents/` — specialist agents (5 agents, delegated execution)
  - `.specify/` — SDD specs and templates

  ## Key Dependencies
  - Qdrant MCP — vector memory for research and cognitive memory
  - Context7 MCP — library documentation lookup
  - Exa MCP — web search and deep research

  ## Architectural Invariants
  - CLAUDE.md > Skills > Agents hierarchy (never bypass)
  - Skills are knowledge-only; agents are execution-only
  - SDD pipeline: constitution → specify → plan → tasks → implement

  ## Active Conventions
  - [populated incrementally as patterns are confirmed]
  ```
- **Update triggers**: After implementing a feature that adds modules, changes
  dependencies, or establishes new conventions → update knowledge map.
- **Session integration**: The SessionStart hook or CLAUDE.md orientation
  section references the knowledge map for immediate project awareness.

### C6 — Integration & Testing

- **What**: Wire all layers together. Update CLAUDE.md with memory rules.
  Test the full workflow end-to-end.
- **Files to modify**:
  - `.claude/CLAUDE.md` — add memory section referencing `.claude/rules/memory.md`
  - Session orientation section — reference knowledge map
- **Dependencies**: C1-C5 all complete.
- **Validation**:
  - Store a test decision → retrieve it → verify schema correctness
  - Store a test error pattern → query with similar context → verify retrieval
  - Run deliberation skill on a sample decision → verify output format
  - Check knowledge map is readable and accurate

## Execution Order

```
Phase 1 (Foundation):   C1 — Qdrant Schema & Memory Skill
                          ↓
Phase 2 (Core Memory):  C2 — Decision Log  ║  C3 — Error Patterns
                        (parallel — independent record types)
                          ↓
Phase 3 (Reasoning):    C4 — Deliberation Skill
                          ↓
Phase 4 (Awareness):    C5 — Knowledge Map
                          ↓
Phase 5 (Integration):  C6 — Wire together & test
```

- **C1 first**: All layers depend on the schema and memory skill.
- **C2 ∥ C3**: Decision log and error patterns are independent record types
  sharing the same infrastructure. Can be developed in parallel.
- **C4 after C2**: Deliberation stores results as decision records — needs
  the decision log pattern established first.
- **C5 after C3**: Knowledge map benefits from error pattern infrastructure
  but is mostly file-based. Placed here to avoid overloading Phase 2.
- **C6 last**: Integration requires all layers functional.

### Delegation Strategy

- **C1**: Main Marvin context — schema design is an architectural decision
  that benefits from full conversation history.
- **C2 + C3**: Implementer agents (parallel, worktree isolation) — each
  creates/modifies specific files with clear specs.
- **C4**: Implementer agent — skill creation following established patterns
  from spec 001.
- **C5**: Main Marvin context — knowledge map seeding requires understanding
  the full project.
- **C6**: Main Marvin context — integration and testing.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Qdrant MCP latency slows down interactions | High | Keep queries lightweight (short summaries, metadata filters). Never block on Qdrant for simple tasks — only query for non-trivial decisions. |
| Memory pollution — storing low-value records that add noise | High | Strict trigger heuristics: only log decisions affecting 2+ files or introducing new patterns. Error patterns require explicit user correction, not self-detected issues. |
| Stale memories — old decisions retrieved for changed context | Medium | Include project version/date in metadata. Retrieval favors recent records. Implement decay: records not retrieved in 90 days get lower ranking. |
| Qdrant unavailable (MCP disconnected) | Medium | NFR-04: graceful degradation. Memory skill checks availability first. Falls back to local MEMORY.md patterns. |
| Over-deliberation — invoking full process for trivial decisions | Medium | Clear heuristics in skill: deliberation only for 3+ files, new deps, public API changes, or explicit user request. Quick decisions explicitly excluded. |
| Knowledge map becomes stale/inaccurate | Medium | Human-editable + update triggers. Reviewer agent checks knowledge map accuracy as part of post-implementation review. |
| Circular skill loading — memory-manager references other skills | Low | Memory-manager is self-contained. Does not load or delegate to other skills. No Agent tool usage in the skill. |

## Testing Strategy

- **Schema validation**: Store and retrieve one record of each type (decision,
  error-pattern, knowledge, deliberation). Verify metadata filtering works.
- **Decision log E2E**: Make an architectural decision in a test session →
  start a new session → verify the decision is retrieved when facing a
  similar choice.
- **Error pattern E2E**: Simulate a user correction → verify pattern is
  extracted and stored → query with similar task context → verify retrieval.
- **Deliberation E2E**: Invoke `/deliberation` on a sample architecture
  question → verify the 5-step process completes → verify result is stored
  as a decision record.
- **Knowledge map E2E**: Seed the knowledge map → modify project structure →
  verify the map is updated → start new session → verify orientation uses
  the map.
- **Degradation test**: Disconnect Qdrant MCP → verify Marvin continues to
  function with local-only memory → reconnect → verify sync.
- **Reviewer**: Run reviewer agent on full diff after each phase.

## Alternatives Considered

| Alternative | Why rejected |
|-------------|-------------|
| SQLite instead of Qdrant | Qdrant is already connected via MCP. SQLite would require new infrastructure. Vector search is essential for semantic retrieval — SQLite would need additional embedding pipeline. |
| Full graph database (Neo4j) for knowledge map | Overkill for current project size. Structured Markdown is sufficient, human-editable, and git-friendly. Revisit if project grows beyond 50 modules. |
| Automated deliberation triggering via LLM classifier | Adds complexity and latency. Rule-based heuristics (file count, dependency changes) are simpler, predictable, and sufficient for v1. |
| Store memories in local JSON files only | Loses semantic retrieval — can only do exact or keyword matching. The whole point of cognitive memory is finding *similar* past experiences, not identical ones. |
| Separate Qdrant collections per memory type | Adds operational complexity. Single collection with metadata filtering is simpler and Qdrant handles it efficiently. Revisit if collection exceeds 10K records. |
| Integrate memory into agent AGENT.md files directly | Violates scope constraint — AGENT.md structural changes are out of scope. Skills and rules are the correct integration layer. |
