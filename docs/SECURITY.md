# Security notes

## Threat model

The gem `u955-webhook-inbox` is a pure library without I/O. The main risks are:

- **Supply chain**: a compromised gem or CI action. Mitigation: standard library only, every gem
  pinned by the committed `Gemfile.lock` (frozen installs), bundler-audit (the Ruby Advisory
  Database) and OSV-Scanner over `Gemfile.lock` in the gates, Dependabot weekly updates, actions
  pinned by commit SHA, minimal workflow permissions, MFA required to publish
  (`rubygems_mfa_required`).
- **Leaked secrets**: tokens committed by mistake. Mitigation: `gitleaks` runs in the local gates
  and in CI; `.env` files and RubyGems credentials are never committed.
- **Insecure code**: code evaluation, command injection, object injection through `Marshal.load`
  or unsafe YAML, method dispatch chosen by input (`send`), disabled TLS verification.
  Mitigation: RuboCop's Security and Lint cops and the factory's Semgrep rules
  (`.semgrep/factory-rules.yml`, `nosemgrep` ignored); fix the code instead of silencing it.
- **Untrusted input**: callers may pass hostile strings. Mitigation: validate input and raise
  explicit, documented errors; never deserialize untrusted data with `Marshal`; never build a
  shell command line from data.

## Publishing

Releases are git tags; publishing on RubyGems needs an account with MFA, whose credentials are
never stored in the repository.

To report a vulnerability, see [SECURITY.md](../SECURITY.md).
