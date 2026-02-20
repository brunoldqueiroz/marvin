# Marvin — Data Engineering & AI Assistant
# Usage: make help

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Project path (override: make install PROJECT=~/Projects/my-app)
PROJECT ?=

# ─── Installation ───────────────────────────────────────────────

.PHONY: install
install: _require-project ## Install Marvin to a project
	python3 scripts/install.py --force "$(PROJECT)"

.PHONY: install-dev
install-dev: _require-project ## Install in dev mode (symlinks)
	python3 scripts/install.py --dev --force "$(PROJECT)"

.PHONY: dry-run
dry-run: _require-project ## Preview installation without changes
	python3 scripts/install.py --dry-run "$(PROJECT)"

.PHONY: uninstall
uninstall: _require-project ## Remove Marvin from a project
	@echo "Removing $(PROJECT)/.claude/ ..."
	@rm -rf "$(PROJECT)/.claude"
	@echo "Done."

# ─── Validation ─────────────────────────────────────────────────

.PHONY: lint
lint: lint-json lint-bash ## Run all linters

.PHONY: lint-json
lint-json: ## Validate settings.json and .mcp.json
	@echo "Validating JSON..."
	@python3 -c "import json; json.load(open('core/settings.json')); print('  core/settings.json: ok')"
	@python3 -c "import json; json.load(open('core/.mcp.json')); print('  core/.mcp.json: ok')"

.PHONY: lint-bash
lint-bash: ## Lint hook scripts with shellcheck (if available)
	@echo "Linting hooks..."
	@if command -v shellcheck &> /dev/null; then \
		shellcheck core/hooks/*.sh && echo "  shellcheck: all passed"; \
	else \
		echo "  shellcheck not installed, checking syntax only..."; \
		for f in core/hooks/*.sh; do \
			bash -n "$$f" && echo "  $$f: ok"; \
		done; \
	fi

.PHONY: test
test: lint test-hooks ## Run all checks

.PHONY: test-hooks
test-hooks: ## Test hook scripts produce valid output
	@echo "Testing hooks..."
	@export CLAUDE_PROJECT_DIR="$$(pwd)"; \
	echo '{}' | ./core/hooks/session-context.sh | \
		python3 -c "import json,sys; json.load(sys.stdin); print('  session-context.sh: ok')"
	@export CLAUDE_PROJECT_DIR="$$(pwd)"; \
	echo '{}' | ./core/hooks/compact-reinject.sh | \
		python3 -c "import json,sys; json.load(sys.stdin); print('  compact-reinject.sh: ok')"
	@export CLAUDE_PROJECT_DIR="$$(pwd)"; \
	./core/hooks/status-line.sh > /dev/null && echo "  status-line.sh: ok"
	@echo '{"tool_name":"Bash","error":"command not found"}' | \
		CLAUDE_PROJECT_DIR="$$(pwd)" ./core/hooks/tool-failure-context.sh | \
		python3 -c "import json,sys; json.load(sys.stdin); print('  tool-failure-context.sh: ok')"
	@echo '{"trigger":"manual"}' | \
		CLAUDE_PROJECT_DIR="$$(pwd)" ./core/hooks/pre-compact-save.sh && \
		echo "  pre-compact-save.sh: ok" && \
		rm -f .claude/.pre-compact-state.json

# ─── Development ────────────────────────────────────────────────

.PHONY: hooks-chmod
hooks-chmod: ## Ensure all hooks are executable
	@chmod +x core/hooks/*.sh
	@echo "All hooks marked executable."

.PHONY: list-hooks
list-hooks: ## List all hook scripts
	@echo "Hook scripts:"
	@ls -1 core/hooks/*.sh | sed 's|core/hooks/|  |'

.PHONY: list-agents
list-agents: ## List all specialist agents
	@echo "Agents:"
	@ls -1d core/agents/*/ 2>/dev/null | sed 's|core/agents/||;s|/||' | sed 's/^/  /'

# ─── Helpers ────────────────────────────────────────────────────

.PHONY: _require-project
_require-project:
ifndef PROJECT
	$(error PROJECT is required. Usage: make install PROJECT=~/Projects/my-app)
endif

.PHONY: help
help: ## Show this help
	@echo "Marvin — Data Engineering & AI Assistant"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make install PROJECT=~/Projects/my-app"
	@echo "  make install-dev PROJECT=~/Projects/my-app"
	@echo "  make test"
