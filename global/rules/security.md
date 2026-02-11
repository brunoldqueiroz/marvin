# Security Rules

## Secrets Management
- Never hardcode secrets, API keys, tokens, or passwords in code
- Use environment variables or secret managers
- Never commit .env files, credentials.json, or key files
- Never log or print secrets, even partially
- Never include secrets in error messages or stack traces

## Input Validation
- Validate all external input (user input, API responses, file content)
- Use parameterized queries for SQL (never string concatenation)
- Sanitize file paths to prevent path traversal
- Validate URLs before fetching

## Command Execution
- Never pass unsanitized input to shell commands
- Avoid shell=True in subprocess calls when possible
- Use allowlists over denylists for command validation
- Quote all file paths in shell commands

## Dependencies
- Pin dependency versions
- Review new dependencies before adding (check maintenance, popularity, license)
- Prefer well-known packages over obscure alternatives
- Keep dependencies up to date

## Data Handling
- Never expose internal errors to end users
- Sanitize data before rendering in HTML/templates
- Use HTTPS for all external API calls
- Encrypt sensitive data at rest when possible

## Access Control
- Follow principle of least privilege
- Never run with root/admin unless strictly necessary
- Use read-only access when write access isn't needed
