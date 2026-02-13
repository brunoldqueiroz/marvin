# Coding Standards

## SQL
- Lowercase keywords (select, from, where, join)
- snake_case for all identifiers
- CTEs over subqueries for readability
- Always qualify column names in JOINs
- Use explicit JOIN types (inner join, left join — never implicit)
- One column per line in SELECT for readability in diffs

## Testing
- Tests are not optional for non-trivial changes
- Test behavior, not implementation details
- Use descriptive test names that explain what and why
- Run tests after every significant change

## Git
- Commit messages: imperative mood, explain why not what
- Small, atomic commits (one logical change per commit)
- Never commit secrets, credentials, or .env files
