# Coding Standards

## General
- Write clean, readable code over clever code
- Prefer editing existing files over creating new ones
- Follow existing patterns in the codebase
- No dead code, no commented-out blocks
- Keep functions small and focused (single responsibility)
- Meaningful names: variables describe what they hold, functions describe what they do

## Python
- Use type hints for function signatures
- Format with ruff (or black as fallback)
- snake_case for functions and variables, PascalCase for classes
- Docstrings for public APIs only (not every function)
- Prefer f-strings over .format() or %
- Use pathlib over os.path
- Use dataclasses or Pydantic for structured data

## SQL
- Lowercase keywords (select, from, where, join)
- snake_case for all identifiers
- CTEs over subqueries for readability
- Always qualify column names in JOINs
- Use explicit JOIN types (inner join, left join - never implicit)
- One column per line in SELECT for readability in diffs

## TypeScript/JavaScript
- Use TypeScript over JavaScript when possible
- Prefer const over let, never var
- Use async/await over .then() chains
- camelCase for variables/functions, PascalCase for classes/types

## Testing
- Tests are not optional for non-trivial changes
- Test behavior, not implementation details
- One assertion per test when practical
- Use descriptive test names that explain what and why
- Run tests after every significant change

## Git
- Commit messages: imperative mood, explain why not what
- Small, atomic commits (one logical change per commit)
- Never commit secrets, credentials, or .env files
