---
name: review
description: Code review with focus on quality, security, and best practices
disable-model-invocation: true
argument-hint: "[file path, directory, or git ref to review]"
---

# Code Review

Review target: $ARGUMENTS

## Process

### 1. Determine Review Scope

Based on `$ARGUMENTS`:
- **File path** (e.g. `src/pipeline.py`) → review that specific file
- **Directory** (e.g. `src/`) → review all files in that directory
- **Git ref** (e.g. `HEAD`, `main..feature`) → review the diff
- **Empty** → review all uncommitted changes (`git diff` + `git diff --staged`)

### 2. Gather Context

Before reviewing:
- Read the files to be reviewed
- Check for related tests
- Look at recent git history for these files (understand the change intent)
- Check if there are specs in `specs/` or `changes/specs/` related to this code

### 3. Review Checklist

Go through each item systematically:

**Correctness**
- Does the code do what it's supposed to do?
- Are edge cases handled?
- Are there off-by-one errors, null checks, or boundary issues?
- Do error paths work correctly?

**Security**
- Any hardcoded secrets, API keys, or credentials?
- SQL injection risks (string concatenation in queries)?
- Command injection risks (unsanitized input in shell commands)?
- Path traversal vulnerabilities?
- Proper input validation at system boundaries?

**Quality**
- Are functions focused (single responsibility)?
- Are names descriptive and consistent?
- Is there dead code, commented-out blocks, or debug statements?
- Are there unnecessary abstractions or over-engineering?

**Testing**
- Are there tests for the new/changed behavior?
- Do tests cover edge cases?
- Are tests testing behavior or implementation details?

**Performance** (when relevant)
- N+1 queries?
- Missing indexes for frequent queries?
- Unnecessary loops or redundant operations?
- Large data loaded into memory when streaming would work?

**Conventions**
- Does the code follow the project's existing patterns?
- Are naming conventions consistent?
- Does formatting match the project style?

### 4. Output Format

Present the review as:

```markdown
# Code Review: <target>

## Summary
[1-2 sentence overall assessment]

## Issues Found

### Critical (Must Fix)
1. **[file:line]** — [Description of issue]
   - Why: [Why this is a problem]
   - Fix: [Suggested fix]

### Important (Should Fix)
1. **[file:line]** — [Description]
   - Why: [Reason]
   - Fix: [Suggestion]

### Minor (Consider)
1. **[file:line]** — [Description]

## What's Good
- [Positive observations — acknowledge good code]

## Recommendation
- [ ] Ship as-is
- [ ] Fix critical issues, then ship
- [ ] Needs significant rework
```

### 5. Offer to Fix

After presenting the review, ask the user:
- "Want me to fix the critical/important issues?"
- If yes, delegate to the **python-expert** agent with the specific fixes needed
- Then run the **verifier** agent to confirm the fixes
