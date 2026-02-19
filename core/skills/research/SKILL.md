---
name: research
description: Deep research on any topic using web search, Exa, and Context7
disable-model-invocation: true
argument-hint: "[topic to research]"
---

# Deep Research

Research topic: $ARGUMENTS

## Process

### 1. Clarify the Question

Before searching, decompose the topic into specific sub-questions:
- What exactly needs to be understood?
- What are the key dimensions to explore? (e.g. options, trade-offs, best practices)
- What would make this research actionable?

### 2. Delegate to Researcher Agent

Spawn the **researcher** subagent with these instructions:

> Research the following topic thoroughly: $ARGUMENTS
>
> Requirements:
>
> **Tool Priority (FOLLOW THIS ORDER):**
> 1. **Context7 FIRST for library/framework docs** — Use ToolSearch to load Context7 tools
>    (`mcp__upstash-context7-mcp__resolve-library-id` then `mcp__upstash-context7-mcp__query-docs`).
>    Use Context7 whenever the topic involves a specific library, framework, SDK, or tool
>    (e.g. dbt, Airflow, Spark, React, Terraform, etc.). This gives you up-to-date,
>    accurate documentation directly from the source.
> 2. **Exa for high-quality web search** — Use ToolSearch to load Exa tools
>    (`mcp__exa__web_search_exa`, `mcp__exa__company_research_exa`, `mcp__exa__get_code_context_exa`).
>    Exa returns higher quality, more relevant results than generic web search.
>    Use it for technical articles, blog posts, comparisons, and best practices.
> 3. **WebSearch as fallback only** — Use WebSearch only when Exa and Context7 don't
>    cover the topic (e.g. very recent news, niche topics, non-technical queries).
> 4. **WebFetch to go deep** — Use WebFetch to read promising URLs in full.
>    Prefer primary sources (official docs, papers, engineering blogs) over secondary.
>
> **Research Quality:**
> 1. **Find at least 5 quality sources** — Don't settle for the first results.
> 2. **Cross-reference findings** — Verify claims across multiple sources.
>    Note disagreements between sources.
> 3. **Check recency** — Prefer sources from the last 12 months for technology topics.
>    Always note publication dates.
>
> **IMPORTANT:** You MUST use ToolSearch to load Exa and Context7 MCP tools before
> attempting to call them. They are deferred tools and won't work unless loaded first.
>
> Write the full research report to a file.

### 3. Output Format

The researcher agent should write to `research/<topic-slug>.md` with:

```markdown
# Research: <Topic>

**Date:** <today's date>
**Researcher:** Marvin (researcher agent)

## Executive Summary
- 3-5 bullet points with the most important findings
- Lead with actionable insights, not background

## Detailed Findings

### <Sub-topic 1>
[Findings with inline source citations]

### <Sub-topic 2>
[Findings with inline source citations]

## Comparison Table (when applicable)
| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|

## Recommendations
- What to do, with trade-offs explained
- Clear reasoning for each recommendation
- Distinguish "strong recommendation" from "consider this"

## Open Questions
- What couldn't be determined from available sources
- What needs further investigation

## Sources
1. [Title](URL) — brief description of what this source covers
2. [Title](URL) — ...
```

### 4. Review and Summarize

After the researcher agent completes:
- Read the generated report
- Provide a brief summary to the user
- Highlight the top 3 actionable takeaways
- Ask if the user wants to go deeper on any sub-topic
