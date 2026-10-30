# Security Policy

This policy covers every repository in the ALEX-LDT organisation that does not have its own.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Report them privately, in either of these ways:

- In a public repository, open its **Security** tab and choose **Report a vulnerability**.
- Email **tatu.erkinjuntti@forumvirium.fi** with the subject line `[SECURITY] <repository name>`.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Any suggested remediation

We will acknowledge your report and keep you informed while we investigate.

## Disclosure Policy

We follow coordinated disclosure. Please allow us reasonable time to investigate and fix the issue before disclosing it publicly. We will credit reporters unless anonymity is requested.

## Security Practices

- Credentials are never committed to repositories; they are kept in a secret manager or as GitHub Actions secrets
- All organisation members use two-factor authentication
- Public repositories have secret scanning with push protection, Dependabot alerts and private vulnerability reporting turned on
- Before a private repository is made public, its full Git history is scanned for secrets and checked for personal and confidential data
