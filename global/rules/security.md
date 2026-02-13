# Security Rules

## Secrets
- Never hardcode secrets, API keys, tokens, or passwords in code
- Never commit .env files, credentials.json, or key files
- Never log or print secrets, even partially

## Code Safety
- Never pass unsanitized input to shell commands
- Quote all file paths in shell commands
- Use parameterized queries for SQL (never string concatenation)
- Sanitize file paths to prevent path traversal
