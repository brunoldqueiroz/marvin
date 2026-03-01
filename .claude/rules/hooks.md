---
paths:
  - ".claude/hooks/**/*.sh"
---

# Hook Authoring Rules

## File Structure

Every hook MUST follow this skeleton:

```bash
#!/bin/bash
# <hook-name>.sh — <one-line description>
# Hook: <PreToolUse|PostToolUse|...> (matcher: <tool-name|"">)
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
```

## Exit Codes

- `exit 0` — allow / pass (default behavior)
- `exit 2` — block with user-facing error message on stderr
- Other codes — fail-open (logged but does not block)
- MUST NOT use `exit 1` for gates — that signals tool failure, not a block.

## _lib.sh Utilities

- MUST use `json_val '.path.to.field'` for JSON extraction — never raw
  jq calls (breaks on systems without jq).
- MUST use `log_metric '{...}'` for JSONL metrics — handles rotation.

## Safety Patterns

- MUST wrap metrics logging in `{ ... } 2>/dev/null` — a metrics failure
  must never crash the hook or block the user.
- MUST sanitize strings before embedding in JSON — escape newlines,
  quotes, and backslashes (see `_lib.sh` patterns).
- MUST source `_lib.sh` via `"$(dirname "$0")/_lib.sh"` — never use
  relative paths like `../_lib.sh` or `source _lib.sh`.

## Lifecycle

1. Start new hooks as **warning** (`exit 0` + logged message)
2. Promote to **hard gate** (`exit 2`) only after validating accuracy
   via metrics (confirm low false-positive rate)
