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

# Write a JSONL line to metrics.jsonl with rotation (keep 500 when >1000).
# Usage: log_metric '{"ts":"...","event":"..."}'
log_metric() {
  local metrics_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/dev"
  local metrics_file="$metrics_dir/metrics.jsonl"
  mkdir -p "$metrics_dir" 2>/dev/null
  echo "$1" >> "$metrics_file"
  local count
  count=$(wc -l < "$metrics_file" 2>/dev/null || echo "0")
  if [ "$count" -gt 1000 ]; then
    tail -500 "$metrics_file" > "$metrics_file.tmp" && mv "$metrics_file.tmp" "$metrics_file"
  fi
}
