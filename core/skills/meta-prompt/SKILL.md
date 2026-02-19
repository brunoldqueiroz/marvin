---
name: meta-prompt
description: "Generate an optimized prompt for any task, agent, or skill using meta-prompting techniques. Use when crafting system prompts, agent instructions, or complex prompts."
disable-model-invocation: true
argument-hint: "[task description or goal for the prompt]"
---

# Meta Prompt Generator

Task: $ARGUMENTS

## What is Meta Prompting?

Meta prompting is using an LLM to generate, refine, and optimize prompts for
other LLM tasks. Instead of hand-crafting prompts, you describe what you need
and Marvin generates the optimal prompt structure.

## Process

### 1. Understand the Target Task

Analyze `$ARGUMENTS` to determine:
- **Who** is the target audience? (another LLM, a subagent, a skill)
- **What** should the prompt accomplish?
- **What format** should the output be in?
- **What constraints** exist? (length, style, tone, accuracy requirements)
- **What context** will be available when the prompt is used?

### 2. Select Prompting Technique

Based on the task complexity, choose the best technique(s):

| Technique | When to Use |
|-----------|-------------|
| **Zero-Shot** | Task is straightforward, model has strong prior knowledge |
| **Few-Shot** | Task needs pattern matching from examples |
| **Chain-of-Thought** | Task requires reasoning or multi-step logic |
| **Step-by-Step** | Task has a clear sequential process |
| **Role-Based** | Task benefits from a specific persona/expertise |
| **Structured Output** | Task needs specific output format (JSON, tables, etc.) |
| **Constrained** | Task has strict requirements (length, format, content) |

For complex tasks, combine multiple techniques.

### 3. Generate the Prompt

Build the prompt using this structure:

```markdown
## Role (if applicable)
You are a [specific role with relevant expertise].

## Context
[Background information the model needs to do the task well]

## Task
[Clear, specific instructions for what to do]
[Break into numbered steps if the task is multi-step]

## Format
[Expected output structure]
[Include a template if the format matters]

## Examples (if few-shot)
### Example 1
Input: [example input]
Output: [example output]

### Example 2
Input: [example input]
Output: [example output]

## Constraints
- [What to avoid]
- [Length limits]
- [Style requirements]

## Chain-of-Thought (if reasoning needed)
Think through this step by step:
1. First, consider [aspect 1]
2. Then, analyze [aspect 2]
3. Finally, synthesize [conclusion]
```

### 4. Evaluate the Prompt

Before delivering, check the prompt against these criteria:

- **Clarity** — Is every instruction unambiguous? Could it be misinterpreted?
- **Completeness** — Does it cover edge cases? Are all constraints stated?
- **Efficiency** — Is it using the minimum tokens for maximum effect?
- **Specificity** — Are instructions concrete, not vague? ("List 3 items" not "List some items")
- **Testability** — Can you verify if the output matches expectations?

### 5. Deliver

Present the generated prompt in a code block with:
- The technique(s) used and why
- The full prompt ready to copy/paste
- Suggestions for where to use it (AGENT.md, SKILL.md, direct use, etc.)
- Tips for iteration ("If results are too verbose, add a word limit constraint")

## Examples

**Input:** `/meta-prompt generate SQL queries from natural language descriptions`

**Output:** A few-shot prompt with role (SQL expert), examples of natural language → SQL pairs, constraints (use CTEs, lowercase keywords), and a chain-of-thought section for complex queries.

**Input:** `/meta-prompt classify support tickets into categories`

**Output:** A zero-shot prompt with role (support analyst), clear category definitions, structured output format (JSON with category + confidence), and edge case handling instructions.
