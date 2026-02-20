---
name: worktree
description: Manage git worktrees for parallel isolated development
disable-model-invocation: true
argument-hint: "<create|list|remove|cleanup|status> [name]"
---

# Worktree Management

Command: `$ARGUMENTS`

## Process

### 1. Parse Arguments

Parse `$ARGUMENTS` to determine the subcommand:

| Command | Action |
|---------|--------|
| `create <name>` | Create a new worktree |
| `list` | List active worktrees with status |
| `remove <name>` | Remove a worktree (with safety check) |
| `cleanup` | Remove all merged worktrees + prune |
| `status` | Overview of all worktrees |

If `$ARGUMENTS` is empty or unrecognized, show usage help with examples.

### 2. Execute

#### `create <name>`

1. **Determine paths:**
   - Get the project name from the root directory basename
   - Worktree path: `../<project-name>-<name>` (sibling directory)
   - Branch name: `worktree/<name>`

2. **Validate:**
   - Check that `<name>` is provided and contains only alphanumeric chars, hyphens, underscores
   - Check that the worktree path doesn't already exist
   - Check that the branch `worktree/<name>` doesn't already exist

3. **Create the worktree:**
   ```bash
   git worktree add -b "worktree/<name>" "../<project>-<name>"
   ```

4. **Post-setup:**
   - Copy `.env*` files to the new worktree (if any exist): `cp .env* "../<project>-<name>/"` — skip if none found
   - Detect dependency files and install:
     - `package.json` → `cd <worktree> && npm install`
     - `requirements.txt` → `cd <worktree> && pip install -r requirements.txt`
     - `pyproject.toml` → `cd <worktree> && pip install -e .`
     - `go.mod` → `cd <worktree> && go mod download`
   - Report the worktree path and branch to the user

5. **Report:**
   ```
   Worktree created:
     Path:   ../<project>-<name>
     Branch: worktree/<name>

   To start working in it, open a new Claude Code session in that directory.
   ```

#### `list`

Run `git worktree list` and display results in a table with:
- Path
- Branch
- HEAD commit (short hash)

#### `remove <name>`

1. **Determine the worktree path:** `../<project-name>-<name>`
2. **Safety check:** Run `git -C "<worktree-path>" status --porcelain` to detect uncommitted changes
3. **If dirty:** Show the uncommitted files and ask the user for confirmation before proceeding. NEVER use `--force` without explicit user approval.
4. **If clean (or user confirmed):**
   ```bash
   git worktree remove "../<project>-<name>"
   ```
5. **Ask about branch:** Offer to delete the `worktree/<name>` branch if it has been merged. If not merged, warn the user and require explicit confirmation.

#### `cleanup`

1. List all worktrees with `git worktree list --porcelain`
2. For each linked worktree (not the main one):
   - Check if its branch has been merged into the current branch
   - If merged and clean → remove it
   - If merged but dirty → report and skip
   - If not merged → report and skip
3. Run `git worktree prune` to clean up stale references
4. Report what was removed and what was skipped

#### `status`

For each worktree, display:
- Path
- Branch name
- Ahead/behind relative to main branch (`git rev-list --left-right --count main...<branch>`)
- Dirty file count (`git -C <path> status --porcelain | wc -l`)

Present as a formatted table.

### 3. Delegation

For complex git operations (merge conflicts, branch cleanup, interactive rebase), delegate to the **git-expert** agent with a structured handoff including:
- The worktree path and branch
- The specific operation needed
- Constraint: preserve worktree isolation

### 4. Conventions

- **Directory pattern:** `../<project-name>-<worktree-name>` (sibling to main project)
- **Branch namespace:** `worktree/<name>` prefix for easy identification
- **Safety first:** Never `--force` remove without user confirmation
- **Environment parity:** Always copy `.env*` files on create
- **Dependency install:** Auto-detect and install on create
