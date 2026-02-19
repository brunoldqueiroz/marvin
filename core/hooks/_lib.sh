#!/bin/bash
# _lib.sh — Shared utilities for Marvin hooks
# Source this from hooks: source "$(dirname "$0")/_lib.sh"

# Extract a JSON field. Supports jq-style dot paths.
# Usage: echo '{"a":{"b":"val"}}' | json_val '.a.b'
json_val() {
  if command -v jq &> /dev/null; then
    jq -r "$1 // empty"
  else
    local py_path="$1"
    python3 -c "
import json, sys
d = json.load(sys.stdin)
for key in '''${py_path}'''.strip('.').split('.'):
    d = d.get(key, '') if isinstance(d, dict) else ''
print(d if d else '')
" 2>/dev/null
  fi
}
