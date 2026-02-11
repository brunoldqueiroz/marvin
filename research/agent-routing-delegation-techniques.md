# Research: Agent Routing and Delegation Techniques for Multi-Agent AI Systems

**Research Date**: 2026-02-11
**Context**: CLI-based AI assistants like Claude Code with orchestrator-to-subagent delegation patterns
**Focus**: Practical, implementable solutions for reliable agent routing and the "agent forgot to delegate" problem

---

## Executive Summary

- **The "Forgot to Delegate" Problem**: This is a widespread challenge in multi-agent orchestration where the orchestrator LLM performs work itself instead of routing to specialized subagents. Solutions center around explicit routing triggers, semantic matching, tool-based handoffs, and forced delegation patterns.

- **Routing Techniques**: The field has converged on five main approaches: (1) Semantic routing using embeddings, (2) LLM-based classification, (3) Rule-based/pattern-matching, (4) Tool-based handoffs, and (5) Hybrid approaches combining multiple methods.

- **Framework Approaches**: Major frameworks handle routing differently:
  - **LangGraph**: Graph-based with conditional edges and explicit routing functions
  - **CrewAI**: Role-based with sequential/parallel task handoffs
  - **AutoGen**: Conversational routing with message passing
  - **OpenAI Swarm**: Lightweight handoffs via `transfer_to_XXX` functions
  - **Google ADK**: Hierarchical with LLM-driven AutoFlow delegation

- **Claude Code Specific**: The community has identified key patterns including mandatory delegation keywords ("MUST BE USED", "PROACTIVELY"), tool scoping for agents, explicit invocation protocols, and forcing the main agent into "plan mode" to prevent it from doing work directly.

- **Production Best Practices**: Successful implementations combine multiple techniques: clear agent descriptions, tool restriction, pre-action planning, monitoring/observability, and explicit delegation rules in system prompts.

---

## 1. The "Agent Forgot to Delegate" Problem

### Problem Definition

In orchestrator-based multi-agent systems, the orchestrator LLM is supposed to analyze requests and route them to specialized subagents. However, orchestrators frequently:
- Perform the work themselves instead of delegating
- Misroute to the wrong specialist
- Forget available subagents exist
- Implement functionality that already exists in subagents

### Root Causes

**Context Window Limitations**: As agent registries grow, agent descriptions get truncated or lost in long context windows.

**Ambiguous Task Boundaries**: When task classification isn't clear-cut, LLMs default to doing work themselves rather than risking incorrect delegation.

**Poor Agent Descriptions**: Vague or incomplete subagent descriptions lead to low confidence in delegation decisions.

**Lack of Forcing Mechanisms**: Most frameworks allow but don't enforce delegation, treating it as optional rather than mandatory.

**Token Optimization Bias**: LLMs may perceive direct execution as more efficient than the overhead of delegation (fewer tokens, fewer steps).

### Impact

- Orchestrator becomes a bottleneck handling all work
- Specialized agents sit idle
- Loss of domain expertise benefits
- Inconsistent behavior (sometimes delegates, sometimes doesn't)
- Degraded output quality when orchestrator lacks specialist knowledge

---

## 2. Routing and Indexing Techniques

### 2.1 Semantic Routing

**How It Works**:
- Pre-encode example utterances for each agent/route as vector embeddings
- When a new query arrives, embed it and find nearest neighbors in vector space
- Route to the agent with highest semantic similarity

**Key Advantages**:
- **Fast**: O(log n) similarity search vs. O(1) LLM call per routing decision
- **Cheap**: Single embedding + vector search << full LLM inference
- **Scalable**: Can handle 100s of routes without performance degradation
- **Deterministic**: Same query always routes to same agent

**Implementation Details**:
```python
# Pseudocode for semantic routing
agent_routes = {
    "data_engineer": ["write a dbt model", "optimize Snowflake query", "build Spark pipeline"],
    "frontend_dev": ["create React component", "style with Tailwind", "fix CSS bug"],
    "researcher": ["research latest AI techniques", "compare frameworks", "find documentation"]
}

# Pre-compute embeddings
route_embeddings = {}
for agent, examples in agent_routes.items():
    route_embeddings[agent] = [embed(ex) for ex in examples]

# At runtime
query = "I need to build an incremental dbt model"
query_embedding = embed(query)
best_agent = find_nearest_neighbor(query_embedding, route_embeddings)
```

**Current State (2026)**:
- **vLLM Semantic Router v0.1 (Iris)**: Signal-Decision Driven Plugin Chain Architecture with 6 signal types:
  - Domain Signals (MMLU-trained classification with LoRA extensibility)
  - Keyword Signals (regex-based pattern matching)
  - Embedding Signals (semantic similarity using neural embeddings)
  - Factual Signals (hallucination detection)
  - Feedback Signals (user satisfaction indicators)
  - Preference Signals (personalization)

**When to Use**:
- High-volume, low-latency routing needs
- Well-defined agent domains with clear example utterances
- Budget-constrained deployments (cheaper than LLM routing)

**When to Avoid**:
- Novel/edge case queries outside training examples
- Domains requiring nuanced understanding
- When routing logic changes frequently

### 2.2 LLM-Based Classification

**How It Works**:
- Present the LLM with query + list of available agents and their descriptions
- LLM classifies which agent should handle the query
- Execute handoff to selected agent

**Key Advantages**:
- **Flexible**: Handles novel queries and edge cases
- **Natural Language**: Can explain routing decisions
- **Adaptive**: No retraining needed when adding agents

**Disadvantages**:
- **Expensive**: Full LLM call per routing decision (higher token cost)
- **Slower**: Latency of LLM inference
- **Scalability Issues**: Accuracy degrades with 20+ routing options
- **Non-Deterministic**: May route differently on repeated identical queries

**Implementation Pattern**:
```
System Prompt:
"You are a routing coordinator. Given a user request and the following available agents,
select the SINGLE best agent to handle this request. Respond with only the agent name.

Available agents:
- data_engineer: Handles dbt, Spark, Airflow, Snowflake, data pipelines
- frontend_dev: Handles React, Vue, CSS, UI/UX, web components
- researcher: Handles web research, documentation lookup, technology comparisons

User request: {query}
Selected agent: "
```

**Production Optimization**:
- Use smaller/cheaper models for routing (GPT-4o-mini, Claude Haiku)
- Cache routing decisions for common queries
- Implement fallback to semantic routing if LLM routing fails

### 2.3 Rule-Based / Pattern Matching

**How It Works**:
- Define explicit keyword triggers or regex patterns for each agent
- Match query against patterns
- Route to first match or highest priority match

**Examples**:
```yaml
agents:
  dbt_expert:
    triggers:
      - "dbt"
      - "data model"
      - "dimensional model"
      - regex: "fact|dimension|staging"

  spark_expert:
    triggers:
      - "pyspark"
      - "spark"
      - "dataframe"
      - regex: "shuffle|partition|rdd"

  git_expert:
    triggers:
      - "commit"
      - "git"
      - "pull request"
      - regex: "conventional commit|atomic commit"
```

**Key Advantages**:
- **Fast**: O(1) pattern matching
- **Deterministic**: Predictable behavior
- **Transparent**: Easy to debug and audit
- **Free**: No LLM or embedding costs

**Disadvantages**:
- **Brittle**: Requires manual pattern maintenance
- **Limited Coverage**: Can't handle paraphrasing or synonyms
- **Maintenance Burden**: Grows linearly with number of agents

**When to Use**:
- Well-defined domains with consistent terminology
- Safety-critical routing (e.g., security agent must catch all "vulnerability" mentions)
- As a pre-filter before more expensive routing methods

### 2.4 Agent Registry with Metadata

**How It Works**:
- Central registry stores agent metadata (description, capabilities, tools, success metrics)
- Orchestrator queries registry to find best match
- Selection based on metadata matching, past performance, or availability

**Microsoft Multi-Agent Reference Architecture**:
> "The primary goal of an agent registry is to provide an information repository for the agents
> in the system to know how to communicate with one another. In most cases, in an Orchestrator-based
> multi-agent architecture, the registry enables the Orchestrator Agent to query which agents are
> best to carry out the immediate tasks at hand."

**Registry Schema Example**:
```json
{
  "agents": [
    {
      "id": "dbt-expert",
      "name": "dbt Expert",
      "description": "Specializes in dbt models, tests, documentation, and Snowflake SQL optimization",
      "capabilities": ["dbt", "sql", "snowflake", "data_modeling"],
      "tools": ["Read", "Write", "Bash", "Grep"],
      "success_rate": 0.94,
      "avg_latency_ms": 3200,
      "cost_per_task": 0.05,
      "last_updated": "2026-02-10"
    }
  ]
}
```

**Matching Strategies**:
- **Capability Matching**: Find agents with required capabilities
- **Performance-Based**: Select agent with highest success rate for this task type
- **Load Balancing**: Distribute to least busy agent with required skills
- **Cost Optimization**: Select cheapest agent meeting requirements

**When to Use**:
- Large-scale multi-agent systems (10+ agents)
- Production systems requiring observability
- When agents have different performance/cost characteristics

### 2.5 Hybrid Approaches

**How It Works**:
- Combine multiple routing methods in a cascade or voting system
- Example: Rule-based pre-filter → Semantic routing → LLM classification fallback

**AWS Prescriptive Guidance Pattern**:
```
1. Rule-Based Filter (fast rejection of obvious mismatches)
   ↓
2. Semantic Similarity (find top-3 candidate agents)
   ↓
3. LLM Classification (final selection from candidates with full context)
```

**Benefits**:
- **Accuracy**: Combines strengths of multiple methods
- **Efficiency**: Fast path for common cases, thorough analysis for ambiguous cases
- **Robustness**: Fallback mechanisms prevent routing failure

**Production Example**:
```python
def route_query(query: str, agents: List[Agent]) -> Agent:
    # Stage 1: Rule-based filter (10μs)
    keyword_matches = [a for a in agents if any(kw in query.lower() for kw in a.keywords)]
    if len(keyword_matches) == 1:
        return keyword_matches[0]  # Clear match, return immediately

    # Stage 2: Semantic routing (50ms)
    if len(keyword_matches) > 1:
        candidates = keyword_matches
    else:
        candidates = agents

    query_embedding = embed(query)
    top_3 = semantic_rank(query_embedding, candidates)[:3]

    if top_3[0].similarity > 0.9:
        return top_3[0].agent  # High confidence, no LLM needed

    # Stage 3: LLM classification (500ms)
    return llm_classify(query, top_3)
```

---

## 3. Framework-Specific Routing Patterns

### 3.1 LangGraph

**Architecture**: Graph-based state machine with nodes (agents/operations) and edges (control flow)

**Routing Mechanism**: Conditional edges with routing functions

**Key Patterns**:

#### Pattern 1: Supervisor Pattern
```python
from langgraph.graph import StateGraph, MessagesState
from langchain_core.tools import tool

# Supervisor agent routes to specialists
def supervisor_router(state: MessagesState) -> str:
    """Analyze query and return name of specialist agent to invoke"""
    # LLM analyzes state and returns agent name
    return "data_engineer"  # or "frontend_dev", "researcher", etc.

workflow = StateGraph(MessagesState)
workflow.add_node("supervisor", supervisor_agent)
workflow.add_node("data_engineer", data_engineer_agent)
workflow.add_node("frontend_dev", frontend_dev_agent)

# Conditional edge from supervisor to specialists
workflow.add_conditional_edges(
    "supervisor",
    supervisor_router,  # Routing function
    ["data_engineer", "frontend_dev", "researcher"]
)
```

#### Pattern 2: Tool-Based Handoffs
```python
@tool
def transfer_to_data_engineer(query: str) -> str:
    """Transfer to data engineer for dbt, Spark, Airflow, Snowflake tasks"""
    return Command(goto="data_engineer", state={"query": query})

# Agents can directly call handoff tools
workflow.add_conditional_edges(
    "current_agent",
    tools=[transfer_to_data_engineer],
    path=lambda output: output if isinstance(output, Agent) else "continue"
)
```

**When to Use**:
- Complex workflows with branching logic
- Need explicit control over state transitions
- Visual workflow design/debugging important

**When to Avoid**:
- Simple linear workflows
- Conversational/dialogue-heavy systems

### 3.2 CrewAI

**Architecture**: Role-based with Crews (teams) and Flows (orchestration)

**Routing Mechanism**: Sequential or parallel task assignment based on agent roles

**Key Patterns**:

```python
from crewai import Agent, Task, Crew

# Define agents with roles
data_engineer = Agent(
    role="Data Engineer",
    goal="Build data pipelines and models",
    backstory="Expert in dbt, Spark, Airflow, Snowflake"
)

researcher = Agent(
    role="Technical Researcher",
    goal="Find and synthesize technical information",
    backstory="Expert at web research and documentation"
)

# Define tasks with agent assignment
task1 = Task(
    description="Research best practices for incremental dbt models",
    agent=researcher  # Explicit assignment
)

task2 = Task(
    description="Implement the dbt model based on research",
    agent=data_engineer,
    context=[task1]  # Depends on task1 output
)

# Crew orchestrates execution
crew = Crew(
    agents=[researcher, data_engineer],
    tasks=[task1, task2],
    process="sequential"  # or "parallel"
)
```

**Routing Characteristics**:
- **Explicit**: Developer defines which agent handles which task
- **Structured**: Tasks have clear inputs/outputs and dependencies
- **Team-Oriented**: Agents collaborate through structured handoffs

**When to Use**:
- Team-like workflows with clear role divisions
- Task dependencies are known upfront
- Sequential or parallel execution patterns

**When to Avoid**:
- Dynamic routing needs (can't determine agent at design time)
- Conversational flows with unclear task boundaries

### 3.3 AutoGen

**Architecture**: Conversational agents with message passing

**Routing Mechanism**: Dialogue-driven with agents selecting next speaker

**Key Patterns**:

```python
from autogen import GroupChat, GroupChatManager

# Agents participate in group chat
user_proxy = UserProxyAgent("user")
data_engineer = AssistantAgent("data_engineer")
researcher = AssistantAgent("researcher")

# Group chat with manager routing messages
group_chat = GroupChat(
    agents=[user_proxy, data_engineer, researcher],
    messages=[],
    max_round=10,
    speaker_selection_method="auto"  # LLM decides next speaker
)

manager = GroupChatManager(group_chat)
```

**Routing Characteristics**:
- **Conversational**: Agents engage in dialogue
- **Dynamic**: Next speaker selected based on conversation context
- **Emergent**: Routing emerges from agent interactions

**When to Use**:
- Collaborative problem-solving requiring back-and-forth
- Unclear upfront which agents needed
- Research/exploration tasks

**When to Avoid**:
- Deterministic workflows
- Low-latency requirements (many LLM calls)

### 3.4 OpenAI Swarm / Agents SDK

**Architecture**: Lightweight handoffs with transfer functions

**Routing Mechanism**: Agents call `transfer_to_XXX()` functions to hand off

**Key Patterns**:

```python
from swarm import Agent

def transfer_to_data_engineer():
    """Transfer to data engineer for dbt, Spark, Airflow, Snowflake tasks"""
    return data_engineer_agent

def transfer_to_researcher():
    """Transfer to researcher for web research and documentation"""
    return researcher_agent

orchestrator = Agent(
    name="Orchestrator",
    instructions="You coordinate work. Delegate to specialists.",
    functions=[transfer_to_data_engineer, transfer_to_researcher]
)

data_engineer_agent = Agent(
    name="Data Engineer",
    instructions="You handle dbt, Spark, Airflow, Snowflake tasks."
)
```

**How Routing Works**:
- Orchestrator has transfer functions as tools
- When it calls `transfer_to_data_engineer()`, conversation ownership transfers
- System prompt switches to target agent's instructions
- Context (chat history) preserved across handoff

**Key Characteristics**:
- **Stateless**: No persistent state between API calls
- **Explicit Context Passing**: Must include all needed context in handoff
- **Simple**: Minimal abstraction over Chat Completions API

**When to Use**:
- Lightweight multi-agent systems
- Clear handoff boundaries
- Prototyping and experimentation

**When to Avoid**:
- Complex state management needs
- Production-grade systems (Swarm is educational only)

### 3.5 Google Agent Development Kit (ADK)

**Architecture**: Hierarchical with CoordinatorAgent and specialist sub-agents

**Routing Mechanism**: LLM-Driven AutoFlow or Explicit AgentTool invocation

**Key Patterns**:

#### Pattern 1: LLM-Driven Delegation (AutoFlow)
```python
from adk import CoordinatorAgent, Agent

# Coordinator automatically routes based on sub-agent descriptions
coordinator = CoordinatorAgent(
    name="MainAgent",
    sub_agents=[
        Agent(
            name="data_engineer",
            description="Handles dbt, Spark, Airflow, Snowflake tasks. Use for data modeling, ETL pipelines, SQL optimization."
        ),
        Agent(
            name="researcher",
            description="Handles web research, documentation lookup, technology comparisons. Use for gathering information."
        )
    ]
)
```

**How It Works**:
- Developer provides sub-agent descriptions
- ADK's AutoFlow transfers execution based on descriptions
- Coordinator LLM decides which sub-agent to invoke

#### Pattern 2: Explicit Invocation (AgentTool)
```python
@tool
def invoke_data_engineer(query: str) -> str:
    """Explicitly invoke data engineer for dbt, Spark, Airflow, Snowflake tasks"""
    return data_engineer.run(query)

coordinator = Agent(
    name="MainAgent",
    tools=[invoke_data_engineer]
)
```

**When to Use**:
- Hierarchical task delegation
- Specialist agents with clear domains
- Google Cloud ecosystem

---

## 4. System Prompt Techniques for Reliable Delegation

### 4.1 Explicit Delegation Rules

**Technique**: Define mandatory delegation rules directly in system prompt

**Example (from Claude Code community)**:
```markdown
## Agent Registry

Available agents and when to use them:

| Agent | Domain | Use When |
|-------|--------|----------|
| **researcher** | Research | Web search, documentation, state-of-the-art, technology comparisons |
| **coder** | Implementation | Code, tests, refactoring, debugging, multi-file changes |
| **dbt-expert** | dbt | dbt models, tests, documentation, SQL optimization for Snowflake |

## Delegation Rules

**MANDATORY**: You MUST delegate to specialized agents. Do NOT do the work yourself.

When the user asks for:
- Research, documentation, or comparisons → MUST delegate to @researcher
- Code implementation or refactoring → MUST delegate to @coder
- dbt models or SQL optimization → MUST delegate to @dbt-expert

Before answering directly, ALWAYS check if a specialized agent should handle this.
```

**Key Elements**:
- **Mandatory Language**: "MUST", "REQUIRED", "ALWAYS"
- **Clear Triggers**: Specific keywords/patterns that trigger delegation
- **Negative Rules**: "Do NOT do X yourself"

### 4.2 Pre-Action Checklist

**Technique**: Force LLM to run through delegation checklist before acting

**Example**:
```markdown
## Before Acting: Delegation Checklist

Before responding to ANY user request, you MUST complete this checklist:

[ ] Step 1: What is the user asking for? (Summarize in one sentence)
[ ] Step 2: Which domain does this fall under? (Research / Code / dbt / Spark / Airflow / etc.)
[ ] Step 3: Is there a specialized agent for this domain? (Check agent registry)
[ ] Step 4: DECISION:
    - IF specialized agent exists → Delegate to that agent
    - IF no specialized agent → Handle yourself

ONLY proceed with your own response if Step 4 says "Handle yourself".
```

**Why It Works**:
- **Chain-of-Thought**: Forces reasoning before action
- **Explicit Decision Point**: Makes delegation vs. direct work a conscious choice
- **Audit Trail**: Creates record of why delegation did/didn't happen

**Production Implementation**:
```markdown
# Marvin Operating System

## Phase 1: Understand & Plan (REQUIRED)

For EVERY request, you MUST:
1. Summarize the user's request in one sentence
2. Identify the primary domain(s): [Data Engineering / AI/ML / Research / Code / etc.]
3. Check agent registry for domain specialists
4. Decide: Delegate or Handle?

Output your Phase 1 analysis like this:
'''
PHASE 1 ANALYSIS:
- Request: [one sentence]
- Domain: [domain name]
- Specialist Available: [yes/no - name]
- Decision: [DELEGATE to @agent-name] OR [HANDLE DIRECTLY because...]
'''

## Phase 2: Execute

IF Phase 1 Decision = DELEGATE → Call the specialist agent
IF Phase 1 Decision = HANDLE DIRECTLY → Proceed with implementation
```

### 4.3 Trigger Keywords in Agent Descriptions

**Technique**: Include "MUST BE USED" or "use PROACTIVELY" in agent descriptions

**Claude Code Best Practice** (from community research):
```markdown
## Agent Registry

| Agent | Description |
|-------|-------------|
| researcher | **MUST BE USED** for: web search, documentation lookup, technology comparisons, state-of-the-art research. **Use PROACTIVELY** when user asks "how do I", "what's the best", "compare X and Y". |
| coder | **MUST BE USED** for: multi-file code changes, refactoring, test generation. **Use PROACTIVELY** for any task requiring editing 2+ files. |
| dbt-expert | **MUST BE USED** for: dbt models, dbt tests, dimensional modeling, Snowflake SQL optimization. **Use PROACTIVELY** when user mentions "dbt", "data model", "fact table", "dimension". |
```

**Key Phrases**:
- "MUST BE USED"
- "Use PROACTIVELY"
- "ALWAYS delegate"
- "REQUIRED for"
- "AUTOMATICALLY invoke"

**Why It Works**:
- Increases salience in LLM's attention
- Creates stronger association between trigger patterns and delegation
- Mirrors training data patterns for function calling

### 4.4 Forcing "Plan Mode"

**Technique**: Prevent orchestrator from direct execution by restricting it to planning-only mode

**GitHub Issue #6800** (Claude Code community request):
> "Feature Request: Main agent always in PLAN mode. It should be possible to force the main agent
> to always be in plan mode to ensure it always delegates work to appropriate subagents, as it's
> currently very easy for delegation to fail and for the main agent to start taking tasks it
> shouldn't be taking."

**Implementation**:
```markdown
# SYSTEM CONSTRAINT: Planning Mode

You are an orchestrator in PLANNING MODE ONLY. You CANNOT write code, read files, or execute tasks directly.

Your ONLY capabilities:
1. Understand user requests
2. Break down tasks into subtasks
3. Identify which specialist agent handles each subtask
4. Delegate to specialist agents
5. Synthesize results from specialists

You do NOT have access to:
- Read tool (cannot read files directly)
- Write tool (cannot write files directly)
- Bash tool (cannot execute commands directly)
- Edit tool (cannot edit code directly)

To accomplish anything, you MUST delegate to specialist agents.
```

**Tool Restriction Enforcement**:
```yaml
# Orchestrator agent configuration
orchestrator:
  tools:
    - AgentDelegate  # Can only delegate
    - PlanCreate     # Can create plans
    - PlanUpdate     # Can update plans
  restricted_tools:
    - Read
    - Write
    - Edit
    - Bash
    - Grep
    - Glob
```

### 4.5 Routing Tables with Pattern Matching

**Technique**: Embed explicit routing table in system prompt

**Example**:
```markdown
## Routing Table

Match the user's request against these patterns and delegate accordingly:

| Pattern (regex) | Agent | Example |
|----------------|-------|---------|
| `dbt\|dimensional model\|fact\|dim_` | @dbt-expert | "create a dbt incremental model" |
| `spark\|pyspark\|dataframe\|rdd` | @spark-expert | "optimize this PySpark job" |
| `airflow\|dag\|operator\|task` | @airflow-expert | "write an Airflow DAG" |
| `research\|compare\|find docs\|how do` | @researcher | "research best practices for..." |
| `implement\|refactor\|debug\|test` | @coder | "refactor this function" |

**Routing Algorithm**:
1. Check user request against each pattern
2. On first match, delegate to corresponding agent
3. If multiple matches, delegate to most specific match
4. If no matches, ask user to clarify
```

### 4.6 Role-Based Formatting

**Technique**: Use structured message formats to clarify roles and responsibilities

**Example**:
```markdown
# Message Format

Every message in a multi-agent conversation MUST use this format:

**Role**: [Orchestrator | Data Engineer | Researcher | etc.]
**Action**: [Planning | Delegating | Implementing | Researching | Reporting]
**Target**: [User | @agent-name | All]
**Content**: [The actual message]

Example:
**Role**: Orchestrator
**Action**: Delegating
**Target**: @researcher
**Content**: Please research best practices for dbt incremental models in Snowflake.
Focus on performance optimization and cost management.

---

This format ensures:
- Clear role identification (who is speaking)
- Clear action type (what they're doing)
- Clear target (who should act next)
- Structured handoffs between agents
```

---

## 5. Claude Code Specific Patterns

### 5.1 CLAUDE.md Agent Registry Pattern

**Location**: `.claude/registry/agents.md`

**Structure**:
```markdown
# Agent Registry

Available agents and when to use them:

| Agent | Domain | Use When |
|-------|--------|----------|
| **researcher** | Research | Web search, documentation, state-of-the-art, technology comparisons |
| **coder** | Implementation | Code, tests, refactoring, debugging, multi-file changes |
| **verifier** | Quality | Test execution, spec compliance, security checks, quality gates |
| **dbt-expert** | dbt | dbt models, tests, documentation, SQL optimization for Snowflake |
| **spark-expert** | Spark | PySpark jobs, performance tuning, shuffle optimization, ETL pipelines |
```

**Referenced in CLAUDE.md**:
```markdown
## Delegating (Subagents)
Read the agent registry to know who's available, then route:
@registry/agents.md

### When to Delegate vs. Do Directly
- Simple questions → answer directly
- Single-file edits → do directly
- Research tasks → researcher agent
- Multi-file changes → coder agent
- Domain-specific work → route to the matching domain agent
```

### 5.2 Explicit Tool Scoping

**Pattern**: Restrict tools per agent to enforce specialization

**Production Pattern** (from community research):
```markdown
# Tool Access Matrix

| Agent | Read | Write | Edit | Bash | Grep | Glob | WebSearch | WebFetch |
|-------|------|-------|------|------|------|------|-----------|----------|
| orchestrator | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| researcher | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| coder | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| reviewer | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| dbt-expert | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

**Why Tool Scoping Works**:
- Orchestrator has no tools → cannot do work directly → must delegate
- Read-only agents (reviewers, auditors) cannot accidentally modify code
- Specialists have only relevant tools → faster, safer execution
```

**Implementation in .claude/agents/AGENT.md**:
```markdown
# Orchestrator Agent

## Tools
- AgentDelegate (can delegate to other agents)

## Restricted Tools
The following tools are NOT AVAILABLE to this agent:
- Read (cannot read files directly - must delegate)
- Write (cannot write files directly - must delegate)
- Edit (cannot edit files directly - must delegate)
- Bash (cannot execute commands directly - must delegate)

To read files, write code, or execute commands, you MUST delegate to appropriate specialists.
```

### 5.3 Invocation Protocol Pattern

**Pattern**: Structured format for agent invocation with full context

**Community Best Practice**:
```markdown
## Professional Invocation Protocol

When delegating to a sub-agent, you MUST provide:
1. **Comprehensive Context**: Relevant background and previous decisions
2. **Explicit Instructions**: Clear, actionable task description
3. **Relevant File References**: Paths to files the agent needs
4. **Clear Success Criteria**: How to know when task is complete

**Template**:
'''
@agent-name

**Context**:
[Background information, previous decisions, why this task is needed]

**Task**:
[Clear, actionable description of what needs to be done]

**Files**:
- /path/to/relevant/file1.py
- /path/to/relevant/file2.sql

**Success Criteria**:
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

**Constraints**:
- Constraint 1
- Constraint 2
'''

**Example**:
'''
@dbt-expert

**Context**:
We're building a customer analytics data warehouse. We have raw order data in
`raw.orders` table and need to create a dimensional model.

**Task**:
Create a dbt incremental model for daily order facts. It should:
- Load only new orders since last run
- Calculate daily order metrics (count, total amount, avg amount)
- Partition by order_date
- Include appropriate tests

**Files**:
- models/staging/stg_orders.sql (source model)
- models/marts/schema.yml (where to add tests)

**Success Criteria**:
- [ ] Incremental model created in models/marts/fct_daily_orders.sql
- [ ] Model uses incremental materialization with proper unique_key
- [ ] Tests defined in schema.yml (unique, not_null, relationships)
- [ ] Documentation added to schema.yml

**Constraints**:
- Use Snowflake-specific optimizations (cluster_by if appropriate)
- Follow existing project naming conventions (fct_ prefix for facts)
- Include only 2024-2026 data (filter older records)
'''
```

### 5.4 Domain-Based Parallel Dispatch

**Pattern**: Dispatch parallel subagents when work spans independent domains

**Community Pattern**:
```markdown
## Dispatch Decision Tree

**Sequential Dispatch** (one agent at a time):
- Tasks have dependencies
- Shared files/state between tasks
- Unclear scope requiring exploration

**Parallel Dispatch** (multiple agents simultaneously):
- 3+ unrelated tasks
- No shared state between tasks
- Clear file boundaries with no overlap
- Independent domains (frontend + backend + database)

**Example Parallel Dispatch**:
When user says "build a full-stack feature":
- @frontend-dev: React component + styles
- @backend-dev: API endpoint + business logic
- @database-architect: Schema changes + migrations

Each agent works independently, results merged by orchestrator.
```

**Implementation**:
```markdown
## Parallel Dispatch Protocol

When dispatching parallel agents, you MUST:
1. Verify no file overlap between agents
2. Verify no shared state dependencies
3. Specify file ownership boundaries
4. Provide merge strategy for results

**Template**:
'''
PARALLEL DISPATCH

@frontend-dev (files: src/components/*, src/styles/*)
[Task for frontend]

@backend-dev (files: src/api/*, src/services/*)
[Task for backend]

@database-architect (files: migrations/*, models/*)
[Task for database]

**File Boundaries**:
- Frontend owns: src/components/, src/styles/
- Backend owns: src/api/, src/services/
- Database owns: migrations/, models/

**Merge Strategy**:
- Frontend and backend coordinate via API contract (specified below)
- Database schema must be deployed before backend can use it
- No direct dependencies between frontend and database

**API Contract**:
[Specify the API interface all agents must adhere to]
'''
```

### 5.5 Agent Description Optimization

**Pattern**: Write agent descriptions as if they're API documentation for the LLM

**Community Best Practice**:
> "The description field of your sub-agents is effectively your API documentation for the LLM.
> Be precise. Clear documentation leads to better usage."

**Poor Agent Description**:
```markdown
| Agent | Description |
|-------|-------------|
| researcher | Does research stuff |
| coder | Writes code |
```

**Optimized Agent Description**:
```markdown
| Agent | Description |
|-------|-------------|
| researcher | **MUST BE USED** for: (1) Web search and documentation lookup, (2) Technology comparisons and evaluations, (3) Finding best practices and design patterns, (4) Library/framework research. **Triggers**: "research", "compare", "find docs", "how do I", "what's the best", "which should I use". **Output**: Markdown research reports with cited sources. |
| coder | **MUST BE USED** for: (1) Multi-file code changes (2+ files), (2) Refactoring existing codebases, (3) Test generation and debugging, (4) Code review implementation. **Triggers**: "refactor", "implement", "write tests", "fix bug" + affects 2+ files. **Output**: Code changes with tests and documentation. |
```

**Key Elements**:
- **Mandatory Language**: "MUST BE USED"
- **Specific Capabilities**: Numbered list of what agent does
- **Trigger Keywords**: Explicit keywords that should invoke this agent
- **Output Format**: What the agent returns

---

## 6. Production Best Practices & Lessons Learned

### 6.1 Monitoring & Observability

**Key Metrics for Routing Reliability**:

| Metric | Target | Indicates |
|--------|--------|-----------|
| Delegation Rate | >80% | % of requests routed to specialists vs. handled by orchestrator |
| Routing Accuracy | >90% | % of delegations to correct specialist |
| Routing Latency | <500ms | Time to make routing decision |
| Agent Utilization | >60% | % of time specialists are active vs. idle |
| Task Completion Rate | >90% | % of delegated tasks successfully completed |

**Implementation** (from community patterns):
```markdown
## Agent Metrics (logged after each interaction)

Log the following for each user request:
- Request: [user's original request]
- Orchestrator Decision: [DELEGATE to @agent-name] or [HANDLE DIRECTLY]
- Reasoning: [why this decision was made]
- Agent Invoked: [agent name if delegated]
- Result: [SUCCESS | FAILURE | PARTIAL]
- Duration: [time to complete]
- Token Cost: [total tokens used]

Store logs in: .claude/logs/agent-metrics.jsonl
```

**Alerting Rules**:
```yaml
alerts:
  - name: Low Delegation Rate
    condition: delegation_rate < 0.8
    action: Review agent descriptions and routing rules

  - name: High Direct Handling
    condition: orchestrator_direct_work > 0.2
    action: Check for missing specialist agents or unclear boundaries

  - name: Routing Failures
    condition: routing_accuracy < 0.9
    action: Review failed routing decisions and update patterns
```

### 6.2 Testing Routing Reliability

**Test Types**:

#### Canary Tests (Explicit Routing)
```markdown
Test: "I need to build a dbt incremental model for customer orders"
Expected: Delegate to @dbt-expert
Actual: [record actual behavior]

Test: "Research best practices for PySpark optimization"
Expected: Delegate to @researcher
Actual: [record actual behavior]

Test: "Refactor the authentication module"
Expected: Delegate to @coder
Actual: [record actual behavior]
```

#### Edge Case Tests (Ambiguous Routing)
```markdown
Test: "Explain how incremental materialization works in dbt"
Expected: Could be @dbt-expert (implementation) or @researcher (explanation)
Acceptable: Either agent, but must delegate

Test: "I need a data pipeline that ingests from S3, transforms with Spark, loads to Snowflake"
Expected: Multi-agent coordination (@spark-expert + @snowflake-expert) or single @data-engineer
Acceptable: Any specialist, but orchestrator should not implement directly
```

#### Negative Tests (Should NOT Delegate)
```markdown
Test: "What is dbt?"
Expected: Handle directly (simple question, no implementation needed)
Actual: [record actual behavior]

Test: "Hello"
Expected: Handle directly (greeting, not a task)
Actual: [record actual behavior]
```

### 6.3 Iterative Improvement Process

**Feedback Loop**:
```
1. Deploy agents with initial descriptions
   ↓
2. Monitor delegation metrics
   ↓
3. Identify routing failures (wrong agent or no delegation)
   ↓
4. Update agent descriptions, add trigger keywords, adjust rules
   ↓
5. Re-test with failed cases
   ↓
6. Repeat until delegation rate >80% and accuracy >90%
```

**Real-World Example** (from community):
```markdown
## Iteration 1: Initial agent description
"researcher: Handles research tasks"
Delegation Rate: 45%
Problem: Too vague, orchestrator doesn't know when to delegate

## Iteration 2: Added capabilities
"researcher: Handles web search, documentation lookup, technology comparisons"
Delegation Rate: 62%
Problem: Better, but still misses many cases

## Iteration 3: Added trigger keywords
"researcher: **MUST BE USED** for web search, documentation lookup, technology comparisons.
Triggers: 'research', 'compare', 'find docs', 'how do I', 'what's the best'"
Delegation Rate: 78%
Problem: Close to target, but some edge cases missed

## Iteration 4: Added examples and output format
"researcher: **MUST BE USED** for: (1) Web search, (2) Documentation lookup, (3) Technology
comparisons. **Triggers**: 'research', 'compare', 'find docs', 'how do I', 'what's the best'.
**Examples**: 'research dbt best practices', 'compare Snowflake vs Redshift', 'find docs for
PySpark window functions'. **Output**: Markdown research report with cited sources."
Delegation Rate: 89%
Problem: Acceptable performance, continue monitoring

## Iteration 5: Added pre-action checklist to orchestrator
Added "Before Acting: Delegation Checklist" to orchestrator system prompt
Delegation Rate: 93%
Success: Target achieved ✓
```

### 6.4 Common Pitfalls & Solutions

#### Pitfall 1: Orchestrator Performs Simple Tasks Directly
**Problem**: Orchestrator writes small code snippets or answers questions instead of delegating

**Solution**: Force orchestrator into planning mode (restrict all implementation tools)
```markdown
# Orchestrator: Planning Mode ONLY
You CANNOT write code, read files, or execute tasks directly.
Your ONLY capabilities: understand requests, plan, delegate, synthesize results.
```

#### Pitfall 2: Vague Agent Boundaries
**Problem**: Overlap between agents (e.g., both "data-engineer" and "dbt-expert" can handle dbt tasks)

**Solution**: Explicit domain ownership
```markdown
## Domain Ownership

| Domain | Primary Owner | Secondary Owner | Rule |
|--------|--------------|----------------|------|
| dbt | @dbt-expert | None | @dbt-expert has exclusive ownership of all dbt tasks |
| Spark | @spark-expert | @data-engineer | @spark-expert for optimization/tuning, @data-engineer for basic Spark tasks |
| Research | @researcher | None | @researcher has exclusive ownership of all web research |
```

#### Pitfall 3: Missing Context in Handoffs
**Problem**: Subagent receives task but lacks context, produces irrelevant output

**Solution**: Mandatory invocation protocol (see 5.3 above)

#### Pitfall 4: Routing Thrashing
**Problem**: Agent A delegates to B, B delegates to C, C delegates back to A

**Solution**: Explicit delegation chains and loop prevention
```markdown
## Delegation Rules

**Allowed Chains**:
- orchestrator → specialist → orchestrator (for result synthesis)
- orchestrator → specialist1 → specialist2 (with explicit handoff protocol)

**Forbidden Chains**:
- specialist → orchestrator → specialist (no roundtrips)
- specialist → specialist → specialist (max 2 levels)
- Any cycle (A → B → A)

**Loop Prevention**:
Track delegation chain in state. If agent appears twice in chain, HALT and ask user for clarification.
```

#### Pitfall 5: Delegation Overhead
**Problem**: Simple tasks become slow due to delegation overhead (orchestrator → classify → delegate → execute)

**Solution**: Threshold-based delegation
```markdown
## When to Delegate vs. Handle Directly

**Handle Directly** (orchestrator):
- Questions about agent capabilities
- Greetings and social interactions
- Clarification questions
- Tasks taking <30 seconds

**Delegate** (specialist):
- Implementation tasks
- Research requiring web search
- Multi-step workflows
- Domain-specific expertise needed
- Tasks taking >30 seconds
```

---

## 7. Comparison Table: Routing Techniques

| Technique | Speed | Cost | Accuracy | Scalability | Flexibility | Maintenance |
|-----------|-------|------|----------|-------------|-------------|-------------|
| **Semantic Routing** | ⚡⚡⚡ Fast (50ms) | 💰 Cheap | ⭐⭐⭐ High (known queries) | ⭐⭐⭐ Excellent | ⭐⭐ Medium | ⭐⭐ Medium (retrain embeddings) |
| **LLM Classification** | ⚡ Slow (500ms) | 💰💰💰 Expensive | ⭐⭐⭐ High (all queries) | ⭐⭐ Good | ⭐⭐⭐ Excellent | ⭐⭐⭐ Low (just update prompts) |
| **Rule-Based** | ⚡⚡⚡ Fast (<10ms) | 💰 Free | ⭐⭐ Medium | ⭐⭐ Good | ⭐ Poor | ⭐ High (manual rules) |
| **Agent Registry** | ⚡⚡ Medium (100ms) | 💰 Cheap | ⭐⭐⭐ High | ⭐⭐⭐ Excellent | ⭐⭐ Medium | ⭐⭐ Medium |
| **Hybrid** | ⚡⚡ Medium (200ms) | 💰💰 Moderate | ⭐⭐⭐ Highest | ⭐⭐⭐ Excellent | ⭐⭐⭐ Excellent | ⭐⭐ Medium |

**Key**:
- Speed: ⚡ = slow (>500ms), ⚡⚡ = medium (100-500ms), ⚡⚡⚡ = fast (<100ms)
- Cost: 💰 = cheap, 💰💰 = moderate, 💰💰💰 = expensive
- Other metrics: ⭐ = low, ⭐⭐ = medium, ⭐⭐⭐ = high

---

## 8. Recommendations for Claude Code / CLI Assistants

### Recommended Architecture

**Tier 1: Rule-Based Pre-Filter** (handles obvious cases)
```markdown
# Stage 1: Keyword Pre-Filter (fast path)
IF query contains "dbt" → @dbt-expert
IF query contains "research" or "compare" → @researcher
IF query contains "commit" or "git" → @git-expert
IF query is simple question (<20 words, no action verbs) → handle directly
ELSE → proceed to Stage 2
```

**Tier 2: Semantic Routing** (handles most cases)
```markdown
# Stage 2: Semantic Similarity (medium path)
Embed query
Find top-3 most similar agents by description embedding
IF top match has similarity >0.85 → delegate to top match
ELSE → proceed to Stage 3
```

**Tier 3: LLM Classification with Pre-Action Checklist** (handles edge cases)
```markdown
# Stage 3: LLM Classification (slow path)
Present LLM with:
- Query
- Top-3 candidate agents from Stage 2
- Agent descriptions and capabilities
- Pre-action checklist

LLM must complete checklist and explicitly decide:
- DELEGATE to @agent-name (with reasoning)
- HANDLE DIRECTLY (only if truly no specialist applies)
```

### Recommended CLAUDE.md Structure

```markdown
# MARVIN — Data Engineering & AI Assistant

## Identity
[Define orchestrator identity and constraints]

## How You Work

### Thinking (Extended Thinking)
[When to use extended thinking]

### Planning (Mandatory First Step)
For EVERY request, you MUST:
1. Summarize request in one sentence
2. Identify domain(s)
3. Check agent registry for specialists
4. DECISION: Delegate or Handle?

### Delegating (Subagents)
Read agent registry: @registry/agents.md

#### When to Delegate vs. Do Directly
- Questions about capabilities → answer directly
- Simple clarifications → answer directly
- Implementation tasks → DELEGATE
- Research tasks → DELEGATE
- Domain-specific work → DELEGATE

## Agent Registry
@registry/agents.md

## Domain Knowledge
@rules/[domain-specific rules]
```

### Recommended Agent Description Template

```markdown
| Agent | Description |
|-------|-------------|
| {agent-name} | **MUST BE USED** for: (1) {capability 1}, (2) {capability 2}, (3) {capability 3}. **Triggers**: "{keyword1}", "{keyword2}", "{keyword3}". **Examples**: "{example1}", "{example2}". **Output**: {output format description}. **Tools**: {list of tools}. |
```

### Recommended Tool Scoping

```yaml
orchestrator:
  tools: []  # No implementation tools, can only delegate
  required_process:
    - Planning phase (analyze + decide)
    - Delegation phase (invoke specialist)
    - Synthesis phase (combine results)

specialist_agents:
  tools: [domain-specific tools]
  restrictions:
    - Cannot delegate further (leaf nodes only)
    - Must return structured results
```

---

## Sources

### Multi-Agent Systems & Routing Overview
- [Multi-agent systems - Agent Development Kit](https://google.github.io/adk-docs/agents/multi-agents/)
- [Developer's guide to multi-agent patterns in ADK - Google Developers Blog](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/)
- [Multi-Agent Multi-LLM Systems: The Future of AI Architecture (Complete Guide 2026)](https://dasroot.net/posts/2026/02/multi-agent-multi-llm-systems-future-ai-architecture-guide-2026/)
- [Multi-agent system: Frameworks & step-by-step tutorial – n8n Blog](https://blog.n8n.io/multi-agent-systems/)
- [Top 5 Open-Source Agentic AI Frameworks in 2026](https://aimultiple.com/agentic-frameworks)

### Framework-Specific Routing
- [LangGraph: Multi-Agent Workflows](https://blog.langchain.com/langgraph-multi-agent-workflows/)
- [Agent Orchestration 2026: LangGraph, CrewAI & AutoGen Guide | Iterathon](https://iterathon.tech/blog/ai-agent-orchestration-frameworks-2026)
- [CrewAI vs LangGraph vs AutoGen: Choosing the Right Multi-Agent AI Framework | DataCamp](https://www.datacamp.com/tutorial/crewai-vs-langgraph-vs-autogen)
- [Mastering AI Agent Orchestration- Comparing CrewAI, LangGraph, and OpenAI Swarm | by Arul | Medium](https://medium.com/@arulprasathpackirisamy/mastering-ai-agent-orchestration-comparing-crewai-langgraph-and-openai-swarm-8164739555ff)

### OpenAI Swarm & Handoffs
- [GitHub - openai/swarm: Educational framework exploring ergonomic, lightweight multi-agent orchestration](https://github.com/openai/swarm)
- [Orchestrating Agents: Routines and Handoffs | OpenAI Cookbook](https://cookbook.openai.com/examples/orchestrating_agents)
- [OpenAI Swarm Framework Guide for Reliable Multi-Agents | Galileo](https://galileo.ai/blog/openai-swarm-framework-multi-agents)
- [Deep Dive into OpenAI Swarm Agent Patterns](https://sparkco.ai/blog/deep-dive-into-openai-swarm-agent-patterns)

### Orchestrator Patterns
- [Orchestrating multiple agents - OpenAI Agents SDK](https://openai.github.io/openai-agents-python/multi_agent/)
- [LLM Agent Orchestration: A Step by Step Guide | IBM](https://www.ibm.com/think/tutorials/llm-agent-orchestration-with-langchain-and-granite)
- [Building a Multi-Agent Orchestrator: A Step-by-Step Guide](https://newsletter.adaptiveengineer.com/p/building-a-multi-agent-orchestrator)
- [Agent Orchestration Patterns in Multi-Agent Systems: Linear and Adaptive Approaches with Dynamiq](https://www.getdynamiq.ai/post/agent-orchestration-patterns-in-multi-agent-systems-linear-and-adaptive-approaches-with-dynamiq)
- [When to use multi-agent systems (and when not to) | Claude](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)

### Semantic Routing
- [Intent Recognition and Auto‑Routing in Multi-Agent Systems](https://gist.github.com/mkbctrl/a35764e99fe0c8e8c00b2358f55cd7fa)
- [vLLM Semantic Router v0.1 Iris: The First Major Release | vLLM Blog](https://blog.vllm.ai/2026/01/05/vllm-sr-iris.html)
- [AI Agent Routing: Tutorial & Best Practices](https://www.patronus.ai/ai-agent-development/ai-agent-routing)
- [Semantic Similarity as an Intent Router for LLM Apps](https://blog.getzep.com/building-an-intent-router-with-langchain-and-zep/)
- [The Semantic Router: AI's Pathway To Understanding User Input - ClearPeaks Blog](https://www.clearpeaks.com/the-semantic-router-ais-pathway-to-understanding-user-input/)
- [AI Agent Routers: Techniques, Practices & Tools for Routing Logic | Deepchecks](https://www.deepchecks.com/ai-agent-routers-techniques-best-practices-tools/)

### LLM Routing & Classification
- [Multi-LLM routing strategies for generative AI applications on AWS](https://aws.amazon.com/blogs/machine-learning/multi-llm-routing-strategies-for-generative-ai-applications-on-aws/)
- [LLM Semantic Router: Intelligent request routing for large language models | Red Hat Developer](https://developers.redhat.com/articles/2025/05/20/llm-semantic-router-intelligent-request-routing)
- [What is Semantic Router? Key Uses & How It Works | Deepchecks](https://www.deepchecks.com/glossary/semantic-router/)
- [Routing in RAG Driven Applications | Towards Data Science](https://towardsdatascience.com/routing-in-rag-driven-applications-a685460a7220/)

### Agent Registry & Pattern Matching
- [Agents registry - Multi-agent Reference Architecture](https://microsoft.github.io/multi-agent-reference-architecture/docs/agent-registry/Agent-Registry.html)
- [Workflow orchestration agents - AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/agentic-ai-patterns/workflow-orchestration-agents.html)
- [Routing dynamic dispatch patterns - AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/agentic-ai-patterns/routing-dynamic-dispatch-patterns.html)
- [The Routing Pattern: Build Smart Multi-Agent AI Workflows with LangGraph | by Huzaifaali | Medium](https://medium.com/@huzaifaali4013399/the-routing-pattern-build-smart-multi-agent-ai-workflows-with-langgraph-44f177aadf7a)

### System Prompt Techniques
- [LLM Agents | Prompt Engineering Guide](https://www.promptingguide.ai/research/llm-agents)
- [Agentic Prompt Engineering: A Deep Dive into LLM Roles and Role-Based Formatting](https://www.clarifai.com/blog/agentic-prompt-engineering)
- [Prompt Chaining | Prompt Engineering Guide](https://www.promptingguide.ai/techniques/prompt_chaining)
- [Everything You Need to Know About Prompt Engineering Frameworks](https://www.parloa.com/knowledge-hub/prompt-engineering-frameworks/)

### Pre-Action Planning
- [Pre-Act: Multi-Step Planning and Reasoning Improves Acting in LLM Agents](https://arxiv.org/html/2505.09970v2)
- [AI Agent Decision-Making: A Practical Explainer](https://skywork.ai/blog/ai-agent/ai-agent-decision-making)
- [Tackle Complex LLM Decision-Making with Language Agent Tree Search (LATS) & GPT-4o | Towards Data Science](https://towardsdatascience.com/tackle-complex-llm-decision-making-with-language-agent-tree-search-lats-gpt4-o-0bc648c46ea4/)
- [A practical guide to building agents](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf)

### Monitoring & Reliability
- [Multi-Agent System Reliability: Failure Patterns, Root Causes, and Production Validation Strategies](https://www.getmaxim.ai/articles/multi-agent-system-reliability-failure-patterns-root-causes-and-production-validation-strategies/)
- [A Practical Guide to Monitoring and Controlling Agentic Applications | Fiddler AI Blog](https://www.fiddler.ai/blog/monitoring-controlling-agentic-applications)
- [Mastering AI agent observability: A comprehensive guide | by Dave Davies | Online Inference | Medium](https://medium.com/online-inference/mastering-ai-agent-observability-a-comprehensive-guide-b142ed3604b1)
- [Observability in Multi‑Agent LLM Systems: Telemetry Strategies for Clarity and Reliability | by Kirill Petropavlov | Medium](https://medium.com/@kpetropavlov/observability-in-multi-agent-llm-systems-telemetry-strategies-for-clarity-and-reliability-fafe9ca3780c)
- [Why observability is essential for AI agents | IBM](https://www.ibm.com/think/insights/ai-agent-observability)
- [How to Build Your AI Agent Monitoring Stack | Galileo](https://galileo.ai/blog/how-to-build-ai-agent-monitoring-stack)
- [Top 5 Tools for Monitoring and Improving AI Agent Reliability (2026)](https://www.getmaxim.ai/articles/top-5-tools-for-monitoring-and-improving-ai-agent-reliability-2026/)

### Claude Code Specific
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Sub-Agent Delegation Setup.md · GitHub](https://gist.github.com/tomas-rampas/a79213bb4cf59722e45eab7aa45f155c)
- [ClaudeLog - What is Sub-Agent Delegation in Claude Code?](https://claudelog.com/faqs/what-is-sub-agent-delegation-in-claude-code/)
- [Claude Code Sub-Agents: Parallel vs Sequential Patterns](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)
- [Best practices for Claude Code subagents](https://www.pubnub.com/blog/best-practices-for-claude-code-sub-agents/)
- [awesome-claude-agents/docs/best-practices.md](https://github.com/vijaythecoder/awesome-claude-agents/blob/main/docs/best-practices.md)
- [Feature Request: Main agent always in PLAN mode · Issue #6800](https://github.com/anthropics/claude-code/issues/6800)
- [GitHub - VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [Claude Code Multi-Agent Orchestration System · GitHub](https://gist.github.com/kieranklaassen/d2b35569be2c7f1412c64861a219d51f)

### LangGraph Conditional Routing
- [Graph API overview - Docs by LangChain](https://docs.langchain.com/oss/python/langgraph/graph-api)
- [LangGraph Conditional Edges Example: Router Pattern Implementation Guide](https://langchain-tutorials.github.io/langgraph-conditional-edges-router-pattern-guide/)
- [Stateful routing with LangGraph. Routing like a call center | by Alexander Zalesov | Medium](https://medium.com/@zallesov/stateful-routing-with-langgraph-6dc8edc798bd)
- [LangGraph Tutorial: Implementing Advanced Conditional Routing - Unit 1.3 Exercise 4 - AIPE](https://aiproduct.engineer/tutorials/langgraph-tutorial-implementing-advanced-conditional-routing-unit-13-exercise-4)

### Tool Calling vs Agent Delegation
- [AI Agent Orchestration Patterns - Azure Architecture Center | Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
- [Delegating Work with Handoffs | CodeSignal](https://codesignal.com/learn/courses/mastering-agentic-patterns-with-claude/lessons/delegating-work-with-handoffs-1)
- [AI Agent Orchestration: How To Coordinate Multiple AI Agents](https://botpress.com/blog/ai-agent-orchestration)
- [Choosing the Right Multi-Agent Architecture](https://blog.langchain.com/choosing-the-right-multi-agent-architecture/)
- [AI Agent Orchestration Frameworks: Which One Works Best for You? – n8n Blog](https://blog.n8n.io/ai-agent-orchestration-frameworks/)
