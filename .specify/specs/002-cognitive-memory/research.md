# Research: Persistent Cognitive Memory Systems for LLM-Based Agents (2025-2026)

## Executive Summary

- **Decision logging** is converging on ADR-style structured records (status/context/decision/consequences) combined with event logs; no single production schema dominates, but diary-pattern + CLAUDE.md-style commits are the most-implemented approach in coding agents.
- **Error pattern extraction** is moving from single-session reflection (Reflexion, 2023) toward multi-level hierarchical reflection (micro/meso/macro), with automated "reflect" hooks at session-end as the practical production pattern.
- **Qdrant for agent memory** works best with: hybrid dense+sparse collections, `text-embedding-3-small` or `voyage-3.5-lite` embeddings, 256–512 token chunks for semantic memory, and a payload schema that includes `agent_id`, `memory_type`, `timestamp`, `session_id`, and `importance_score`.
- **System 2 deliberation** has moved from research paper (ToT, 2023) to production practice: devil's advocate agents and multi-specialist deliberation panels are implementable today in Claude Code Agent Teams with measurable quality gains.
- **Knowledge graphs for codebases** are best implemented via LightRAG (entity/relationship extraction to JSON/local storage) or plain structured markdown — graph databases are overkill for most CLI agent use cases.

---

## Detailed Findings

### Sub-question 1: Decision Logging Patterns in Production Coding Agents

#### Production Agent Approaches

**Devin AI** documents reasoning and progress as part of its workflow, but the internal schema is proprietary. Public reports indicate it maintains a "scratchpad" of planning steps and tool calls, though the format is not publicly specified. (Source: Amplifi Labs comparison, Dec 2025)

**OpenHands** (68K GitHub stars, v1.4.0, Feb 2026) uses a structured event system — each agent action is logged as a typed event (IPythonRunCellAction, BrowseAction, MessageAction, etc.) with timestamp and metadata. This is a flight-recorder pattern, not a structured decision log. The events are accessible via the REST API but are session-scoped, not persistent across sessions.

**Claude Code / Claude Diary** (Lance Martin, LangChain, Dec 2025) implements the most widely-adopted decision logging pattern:
- `/diary` command: captures per-session structured entries including task summary, design decisions, user preferences, challenges, solutions, and code patterns
- Storage: `~/.claude/memory/diary/` as dated markdown files
- Schema per entry: date, task, work done, **design decisions** (explicitly separated), user preferences, code review feedback, challenges/solutions

**AI-assisted ADR generation** (Adolfi.dev, 2025): Using Claude Code to scan codebases and auto-generate Architecture Decision Records in the classic Nygard format:
```
# ADR-NNN: [Title]
Status: [Proposed/Accepted/Deprecated/Superseded]
Context: [Why this decision was needed]
Decision: [What was chosen]
Consequences: [What changes as a result]
```

#### Best Schema for Decision Logs

Synthesizing from multiple sources (AIS Practical Memory Patterns, Claude Diary, OpenHands event log):

```json
{
  "id": "uuid",
  "timestamp": "ISO-8601",
  "session_id": "string",
  "type": "decision|observation|error|preference",
  "context": "Why this arose",
  "decision": "What was chosen or observed",
  "alternatives_considered": ["option A", "option B"],
  "consequences": "What changed",
  "confidence": 0.0-1.0,
  "tags": ["architecture", "testing", "security"],
  "files_affected": ["path/to/file"],
  "outcome": "pending|success|failure|unknown"
}
```

The "Context Graph" framing from AIS (2025): decision logs should be treated as a living record of decision traces stitched across time — moving from Systems of Record (data) to Context Graphs (decisions).

#### Gap

No standardized cross-agent decision log format exists. Each tool (Claude Code, Cursor, Windsurf, Cline) uses different conventions. Community proposals for a shared standard are active but not converged as of March 2026.

---

### Sub-question 2: Error Pattern Extraction from User Corrections

#### Academic Foundations

**Reflexion** (Shinn et al., NeurIPS 2023, arXiv:2303.11366): The seminal paper. Verbal reinforcement learning — agents reflect on task feedback linguistically rather than through weight updates. Three components: Actor → Evaluator → Self-Reflection Model. Achieved 91% pass@1 on HumanEval vs GPT-4's 80%.

**SaMuLe** (AWS AI Labs, arXiv:2509.20562, Sept 2025): Multi-level reflection synthesis — the most advanced practical framework:
- **Micro-level** (Single-Trajectory): Detailed per-failure error correction
- **Meso-level** (Intra-Task): Error taxonomies across multiple trials of the same task
- **Macro-level** (Inter-Task): Transferable insights from same-typed errors across diverse failures
- Also adds **foresight-based reflection**: proactive comparison of predicted vs. actual user responses
- Tested on TravelPlanner, NATURAL PLAN, Tau-bench benchmarks — significantly outperforms reflection baselines

**Generative Agents** (Park et al., UIST 2023, arXiv:2304.03442): The diary architecture: Observations → Reflection → Planning. Pattern threshold: 2+ occurrences = pattern, 3+ = strong pattern.

#### Practical Production Implementations

**Claude Diary `/reflect` command** (rlancemartin, Dec 2025):
1. Session-end `/diary` captures structured observations
2. Later `/reflect` analyzes multiple diary entries for patterns
3. Uses `processed.log` to skip already-analyzed entries
4. Auto-updates CLAUDE.md with one-line imperative rule bullets
5. Threshold: 2 occurrences → pattern, 3 → strong pattern → CLAUDE.md commit

**claude-mem** (thedotmack, 24.3K stars, Feb 2026):
- 5 lifecycle hooks: SessionStart, UserPromptSubmit, PostToolUse, Stop, SessionEnd
- SQLite + ChromaDB for storage
- Automatic observation capture (no manual trigger required)
- Progressive disclosure: 3-layer retrieval (search index ~50-100 tokens, timeline view, detailed fetch ~500-1000 tokens)

**Constitutional feedback loops**: The `/remember` command in Claude Code (2026) analyzes patterns across session memory files, proposes additions to CLAUDE.local.md for user approval, and converts recurring corrections into permanent rules. This is the bridge between automatic session memory and deliberate CLAUDE.md configuration.

#### Key Tension

Manual vs. automatic reflection: Claude Diary keeps reflection manual (user reviews before CLAUDE.md update). claude-mem runs automatically. The trade-off is control vs. convenience. For safety-critical rule changes (CLAUDE.md), manual review is recommended.

---

### Sub-question 3: Vector DB for Agent Memory (Qdrant)

#### Collection Schema Best Practices

From Qdrant's official documentation, fast.io guide (2026), and the comprehensive spikelab gist (Feb 2026):

**Recommended collection structure for agent episodic memory:**
```python
{
  "vectors": {
    "size": 1536,  # text-embedding-3-small or voyage-3.5-lite
    "distance": "Cosine"
  },
  "sparse_vectors": {
    "text": {}  # BM25 for hybrid search
  }
}
```

**Payload schema per point:**
```json
{
  "agent_id": "researcher-agent",
  "memory_type": "episodic|semantic|procedural|decision",
  "session_id": "uuid",
  "timestamp": "ISO-8601",
  "importance_score": 0.0-1.0,
  "recency_score": 0.0-1.0,
  "content_preview": "First 100 chars for display",
  "tags": ["architecture", "error-pattern"],
  "project": "marvin",
  "outcome": "success|failure|unknown",
  "source_files": ["path/to/file"]
}
```

**Security pattern**: Create a payload index on `agent_id` (or `tenant_id`) so Qdrant can instantly filter before running the search. Never use separate collections per agent — single collection with tenant isolation scales to billions of entries, while billions of collections degrades performance.

#### Embedding Models (2026 Rankings)

| Model | Cost/1M tokens | Dims | Best For |
|-------|---------------|------|----------|
| `text-embedding-3-small` | $0.02 | 1,536 | Best value, most use cases |
| `voyage-3.5-lite` | ~$0.02 | 1,024 | Best accuracy-cost for RAG |
| `voyage-3` / `voyage-3.5` | $0.06 | 1,024 | 8.26% better than OpenAI large |
| Local ONNX (E5-large-v2) | Free | 1,024 | Zero API cost, ~10ms on CPU |

Source: spikelab cost analysis gist (Feb 2026)

#### Chunk Size Recommendations

From Qdrant's chunking course and Towards AI chunking guide (Nov 2025):

- **Semantic memory (facts, preferences)**: 128-256 tokens — short, focused, high-precision
- **Episodic memory (session summaries)**: 256-512 tokens — narrative chunks with context
- **Decision records**: 300-600 tokens — enough for full context/decision/consequence
- **Code patterns**: 512-1024 tokens — needs surrounding context

**Hierarchical parent-child**: Store both a 512-token parent and 128-token child chunks. Retrieve children for precision, return parent for context. This achieves 85–90% token reduction while maintaining accuracy.

#### Retrieval Strategies

- **Hybrid search** (dense + sparse BM25) is the recommended default — handles both semantic similarity AND exact-match queries (error codes, file names, function names)
- **Decay/recency boost**: Apply scoring bonus to recent memories during retrieval using timestamp metadata — do not delete old memories, just de-rank them
- **Re-ranking**: Cohere Rerank 3.5 ($2.00/1K searches) for production; skip for personal/low-volume use

#### Memory Layer Architecture (Production-Verified 4-Layer)

From claudefa.st (Feb 2026) and Claude Code official docs:
1. **Working Memory**: Active session context (context window)
2. **Episodic Memory**: Session summaries (Claude Code session memory / SQLite)
3. **Semantic Memory**: Distilled facts and patterns (MEMORY.md topic files / Qdrant)
4. **Procedural Memory**: Reusable workflows (CLAUDE.md / SKILL.md)

Qdrant is most valuable for layers 2 and 3. Layer 4 (procedural) is better stored as plain markdown.

#### Cost Reality Check

Full pipeline (embed + rerank + LLM) per query:
- Personal agent (~100 queries/day): **~$0.016/query = ~$48/month** with reranking
- Personal agent without reranking: **~$0.001/query = ~$3/month**
- Mem0 architecture: 90% token savings, 91% latency reduction vs. sending full history

---

### Sub-question 4: System 2 Deliberation for CLI Agents

#### Tree of Thoughts — Research to Practice Gap

ToT (Yao et al., 2022; Long, 2023) requires four components: thought decomposition, thought generation, state evaluation, and search (BFS/DFS). This is architecturally complex for a CLI context.

**NVIDIA TensorRT-LLM** (merged PR #7490, Sept 2025): Added production MCTS and ToT controllers to their Scaffolding layer with configurable depth, iterations, and thoughts-per-step. This is the closest to a production implementation, but requires the TRT-LLM infrastructure stack.

**Practical verdict**: Full ToT is expensive and operationally complex for interactive CLI agents. The multi-agent deliberation pattern achieves the same debiasing effect more cheaply.

#### Devil's Advocate Pattern (Most Practical System 2 Analog)

**EMNLP 2024 paper** ("Devil's Advocate: Anticipatory Reflection for LLM Agents", Wang et al., ACL Anthology): Three-fold introspective intervention:
1. Anticipatory reflection on potential failures BEFORE action execution
2. Post-action alignment with subtask objectives + backtracking
3. Comprehensive review upon plan completion for future strategy refinement
Result: 23.5% success rate on WebArena, +3.5% over existing zero-shot methods.

**Production implementation** (zenn.dev correlate article, Feb 2026): Devil's Advocate agent in Claude Code Agent Teams:
- Runs after all other agents complete (set `addBlockedBy` on DA task)
- Prompt includes explicit "no sycophancy" instruction
- 3-round review pattern: R1 (broad review) → R2 (fix verification) → R3 (final feasibility)
- Result: 9 high-importance issues at R2 reduced to 1 at R3 (-89%)
- GitHub: `richiethomas/claude-devils-advocate` — DA slash command for Claude Code

**10-Agent Deliberation Panel** (Blake Crosley, Feb 2026): Most sophisticated practical implementation:
```
Agents mapped to De Bono's Six Thinking Hats:
- Technical Architect (White: facts, feasibility)
- Cost Analyst (White: economics, break-even math)
- UX Advocate (Red: user feelings, friction)
- Security Analyst (Black: risks, vulnerabilities)
- Maintenance Pessimist (Black: technical debt via Munger inversion)
- Innovation Scout (Green: novel alternatives)
- Performance Engineer (Yellow: efficiency)
- Quality Guardian (Blue: process, observability)
+ Debate and Synthesis agents
```
Used Gary Klein's pre-mortem, Munger's inversion, and Tetlock's fox-thinking frameworks operationally. Key finding: the Cost Analyst ("what does this actually cost?") was the most valuable agent, killing a 200-400 hour project that would have saved $5/month.

#### Deliberation Trigger Rules (Practical Guide)

| Situation | Action |
|-----------|--------|
| Confidence < 0.70 on architectural decision | Full deliberation panel |
| Irreversible decision (schema change, public API) | Minimum: DA + Cost Analyst |
| Internal refactor, behind feature flag | Skip deliberation |
| Documentation fix, variable rename | Never deliberate |

The 10% of decisions that warrant deliberation produce 90% of the value. Deliberating everything produces analysis paralysis.

#### Minimum Viable Pattern for CLI Agents

For a CLI agent context, the minimum viable System 2 pattern:
```
1. BEFORE acting: Generate the plan as usual
2. SELF-CRITIQUE: "What could go wrong with this plan?"
3. COST CHECK: "What does building/doing this actually cost?"
4. PROCEED or REVISE
```
This is implementable as a prompt-level pattern without multi-agent overhead.

---

### Sub-question 5: Knowledge Graphs for Codebases (No Separate DB Required)

#### LightRAG — Best Lightweight Option

**LightRAG** (HKUDS, EMNLP 2025, 27.8K GitHub stars) is the standout finding for no-database knowledge graphs:
- Extracts entities (people, organizations, concepts, files, functions) and relationships from documents
- Stores graph as **local JSON/text files** — no graph database required
- Dual-level retrieval: local mode (specific entities) + global mode (broader relationships) + hybrid mode (recommended default)
- 6,000x cheaper than Microsoft GraphRAG
- Outperforms standard RAG on comprehensiveness (54.4% vs. 45.6%), diversity (77.2% vs. 22.8%)

For a codebase knowledge graph, LightRAG would extract: files → functions → classes → dependencies → decisions as a local file-backed graph.

#### Engram (Feb 2026)

`foramoment/engram-ai-memory` (GitHub, MIT): Zero-API-cost cognitive memory system for coding agents:
- Persistent semantic search + knowledge graph
- Ebbinghaus forgetting curve implementation
- Backend: **libsql (SQLite-compatible)** — no external DB
- Local inference via transformers.js (no API keys)
- Works with Claude, Cursor, Antigravity

#### MiniKG

`Black-Tusk-Data/minikg` (Python, v0.2.1, Apr 2025): Hackable GraphRAG over local documents. Example: knowledge graph over earnings call transcripts. Pure Python, no graph DB required.

#### Structured Markdown Pattern (Most Pragmatic)

The spikelab gist benchmark finding: **Letta's filesystem scores 74% on LoCoMo benchmark**, beating specialized memory libraries. Plain markdown is:
- LLM-native (models trained on markdown)
- Human-readable and inspectable
- Git-friendly (diffs, history, backup)
- Zero infrastructure overhead

**Recommended schema for a project knowledge graph in markdown:**

```markdown
# Project Knowledge Graph: [project-name]

## Entities

### Files
- `src/agents/researcher.py` — researcher agent, handles web search and synthesis
- `src/memory/qdrant.py` — Qdrant client wrapper, episodic memory layer

### Concepts
- **MemoryLayer**: 4-tier architecture (working/episodic/semantic/procedural)
- **SkillLoading**: Progressive disclosure, 3-layer (discovery/activation/execution)

### Decisions
- See `.specify/specs/*/spec.md` for full ADRs
- Key: Use markdown-first memory (not Qdrant) for procedural memory layer

## Relationships
- `researcher.py` USES `qdrant.py`
- **MemoryLayer** IMPLEMENTED_BY `qdrant.py` (episodic/semantic layers)
- **SkillLoading** DOCUMENTED_IN `.claude/agents/*/AGENT.md`

## Error Patterns
- [2026-03] Circular delegation when orchestration skills injected into subagents
  → Use knowledge-only skills for subagent injection
```

#### Graphiti / Zep (Heavyweight Option)

For projects requiring temporal awareness and complex relationship tracking:
- **Graphiti** (Zep's core, 20K+ GitHub stars, arXiv:2501.13956): Real-time, temporally-aware knowledge graph. Handles chat histories, structured JSON, and unstructured text simultaneously. Bi-temporal model (chronological + transactional ordering). 94.8% on DMR benchmark. Retrieval <200ms.
- Requires a running server, but Zep offers a managed service.

---

## Recommendations

### For Marvin specifically

1. **Decision logging**: Implement diary-pattern with session-end hook. Schema should capture `type`, `context`, `decision`, `alternatives_considered`, `files_affected`. Store in `.claude/agent-memory/researcher/decisions/` as dated markdown files.

2. **Error pattern extraction**: Use the reflect loop: session-end diary → periodic (weekly) reflect pass → auto-propose CLAUDE.md updates for user approval. Adopt the 3-tier pattern from SaMuLe: per-session correction (micro), per-task taxonomy (meso), cross-task insight (macro).

3. **Qdrant schema**: For the existing Qdrant MCP integration, use:
   - Single collection `marvin-memory`
   - `text-embedding-3-small` (1,536 dims, $0.02/1M tokens)
   - Payload fields: `agent_id`, `memory_type`, `session_id`, `timestamp`, `importance`, `project`, `tags`
   - Hybrid search (dense + sparse) enabled
   - Chunk size: 256 tokens for facts/patterns, 512 for session summaries
   - Create payload index on `agent_id` for fast multi-agent filtering

4. **System 2 deliberation**: Implement the minimum viable pattern (plan → self-critique → cost check) as a prompt-level pattern in the researcher and implementer agents. For architectural decisions, implement a 3-agent deliberation: Technical Architect + Devil's Advocate + Cost Analyst.

5. **Knowledge graph**: Use structured markdown (not a separate DB). Maintain `.claude/agent-memory/project-graph.md` with entities, relationships, and error patterns. LightRAG is a good option if you need automatic entity extraction from code.

### Trade-offs

| Approach | Simplicity | Capability | Cost |
|----------|-----------|-----------|------|
| Markdown files only | High | 74% on benchmarks | Free |
| Qdrant + embedding | Medium | ~85-90% | $3-48/month |
| Mem0 managed | Low | ~90%+ | $0.016/query |
| LightRAG graph | Medium | Relationship-aware | Free (local) |

For a personal CLI agent like Marvin, the **markdown-first + Qdrant for cross-session semantic search** combination likely captures 90%+ of value at low cost.

---

## Confidence

- **Decision logging patterns**: HIGH — Multiple converging sources (Claude Diary, ADR literature, OpenHands docs, AIS patterns). Production implementations documented.
- **Error pattern extraction**: HIGH — Backed by peer-reviewed papers (Reflexion NeurIPS 2023, SaMuLe arXiv Sept 2025) plus production implementations.
- **Qdrant schemas**: HIGH — Official Qdrant docs + independent practitioner guides. Cost data from verified pricing pages.
- **System 2 deliberation**: HIGH — Practical implementations documented with quantitative results (zenn.dev: 89% issue reduction; Crosley: 40 deliberations over 2 months).
- **Knowledge graphs**: MED — LightRAG is well-documented and benchmarked. No-DB approach validated by Letta benchmark. Engram is new (Feb 2026) with limited independent validation.

---

## Sources

- [SaMuLe: Multi-level Reflection (AWS AI Labs, arXiv:2509.20562)](https://arxiv.org/html/2509.20562v1) — Multi-level reflection framework, Sept 2025
- [Building Performant Agentic Vector Search with Qdrant](https://qdrant.tech/articles/agentic-builders-guide/) — Qdrant official guide, Oct 2025
- [Memory Systems for AI Agents (spikelab gist)](https://gist.github.com/spikelab/7551c6368e23caa06a4056350f6b2db3) — Comprehensive 60-source survey, updated Mar 2026
- [Memory in the Age of AI Agents: A Survey (arXiv:2512.13564)](https://arxiv.org/abs/2512.13564) — Primary survey, Dec 2025
- [How Adding a Devil's Advocate Dramatically Improved Quality (zenn.dev)](https://zenn.dev/correlate/articles/devils-advocate-ai-team?locale=en) — Production case study, Feb 2026
- [Thinking With Ten Brains (Blake Crosley)](https://blakecrosley.com/blog/thinking-with-ten-brains) — 10-agent deliberation practice, Feb 2026
- [AI Memory Layer Guide December 2025 (Mem0)](https://mem0.ai/blog/ai-memory-layer-guide) — Mem0 architecture and benchmarks, Dec 2025
- [LightRAG: Simple and Fast RAG (HKUDS, EMNLP2025)](https://github.com/HKUDS/LightRAG) — Graph+vector knowledge base, 27.8K stars
- [Devil's Advocate: Anticipatory Reflection for LLM Agents (ACL 2024)](https://aclanthology.org/2024.findings-emnlp.53/) — EMNLP 2024 Findings paper
- [Qdrant Text Chunking Strategies (Official Course)](https://qdrant.tech/course/essentials/day-1/chunking-strategies/) — Official chunking guidance
- [Engram: Cognitive Memory for AI Coding Agents](https://github.com/foramoment/engram-ai-memory) — Zero-API knowledge graph, Feb 2026
- [AI-assisted ADR generation (Adolfi.dev)](https://adolfi.dev/blog/ai-generated-adr/) — Claude Code ADR pattern, 2025
- [Claude Diary (rlancemartin, LangChain)](https://github.com/rlancemartin/claude-diary) — Reflect pattern implementation, Dec 2025
- [Rethinking Memory in LLM Agents (arXiv:2505.00675)](https://arxiv.org/abs/2505.00675) — Six core memory operations, May 2025
