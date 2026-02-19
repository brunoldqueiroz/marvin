# Handoff Protocol

## Verbosity Levels

- **Minimal** (commits, formatting): Objective, Acceptance Criteria, Constraints
- **Standard** (models, features, research): + Context, Return Protocol
- **Full** (debugging, retries, complex): + Error History, Detailed Background

## Template

```markdown
## Handoff: <Agent Name>

### Objective
<Single clear sentence>

### Acceptance Criteria
- [ ] <Criterion 1>
- [ ] <Criterion 2>

### Constraints
MUST: <Non-negotiable required behaviors>
MUST NOT: <Forbidden behaviors — violations fail the task>
PREFER: <Nice-to-have — follow when possible>

### Context (Standard+)
**Key Files:** <Paths + why>
**Prior Decisions:** <Relevant decisions>
**User Preferences:** <From memory>

### Return Protocol (Standard+)
Report: <What to include>
On failure: <How to report>
On ambiguity: <When to ask>

### Error History (Full only)
**Previous Attempt:** <What was tried, why it failed>

### Detailed Background (Full only)
<Architecture context, dependencies>
```
