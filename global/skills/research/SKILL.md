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
> 1. **Search broadly first** — Use WebSearch for general discovery. Cast a wide net.
> 2. **Go deep on quality sources** — Use WebFetch to read promising results in full.
>    Prefer primary sources (official docs, papers, engineering blogs) over secondary.
> 3. **Find at least 5 quality sources** — Don't settle for the first results.
> 4. **Cross-reference findings** — Verify claims across multiple sources.
>    Note disagreements between sources.
> 5. **Check recency** — Prefer sources from the last 12 months for technology topics.
>    Always note publication dates.
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
