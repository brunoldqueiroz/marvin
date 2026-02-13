# Security Rules

## Secrets Management
- Never hardcode secrets, API keys, tokens, or passwords in code
- Use environment variables or secret managers
- Never commit .env files, credentials.json, or key files
- Never log or print secrets, even partially
- Never include secrets in error messages or stack traces

## Command Execution
- Never pass unsanitized input to shell commands
- Avoid shell=True in subprocess calls when possible
- Use allowlists over denylists for command validation
- Quote all file paths in shell commands

## Critical Constraints
- Use parameterized queries for SQL (never string concatenation)
- Sanitize file paths to prevent path traversal
- Use HTTPS for all external API calls
- Pin dependency versions; prefer well-known packages
