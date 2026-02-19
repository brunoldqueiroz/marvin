#!/bin/bash
# validate-terraform.sh — Auto-format Terraform files on write/edit
# Hook: PostToolUse (matcher: Write|Edit) — used by terraform-expert agent

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.tf ]] || [[ "$FILE_PATH" == *.tfvars ]]; then
  if command -v terraform &> /dev/null; then
    terraform fmt "$FILE_PATH" 2>/dev/null
  elif command -v tofu &> /dev/null; then
    tofu fmt "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
