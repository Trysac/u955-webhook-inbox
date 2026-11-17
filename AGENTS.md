# AGENTS.md

Instructions for coding agents (and humans) working on the gem `u955-webhook-inbox` (module
`Trysac::WebhookInbox`, required as `trysac/webhook_inbox`).

## Commands

| Task | Command |
|---|---|
| Install dependencies | `bundle install` |
| Run every gate (must pass before a PR) | `ruby scripts/check.rb` |
| Tests only | `bundle exec rspec` |
| Format | `bundle exec rubocop --autocorrect --only Layout` |
| Lint | `bundle exec rubocop` |
| Coverage | `ruby scripts/check.rb tests` |

The gate sequence is: format (RuboCop's Layout cops), lint (`gem build --strict` of
`library.gemspec`, then RuboCop with every other cop; any offense fails), Semgrep (the factory's
rules in `.semgrep/`), RSpec under SimpleCov with line coverage >= 80 % of `lib/`, documentation
(`docs-manifest.json` plus YARD: every public module, class, constant and method of `lib/`
documented), gitleaks, bundler-audit over `Gemfile.lock`, and OSV-Scanner over `Gemfile.lock`.
It stops at the first failure.

## Folder map

| Path | Content |
|---|---|
| `lib/trysac/webhook_inbox.rb` | The entry point (`require "trysac/webhook_inbox"`); it requires the rest of `lib/`. |
| `lib/trysac/webhook_inbox/` | The library, module `Trysac::WebhookInbox`, one constant per file; its public methods are the public API. |
| `spec/` | RSpec specs (`*_spec.rb`, mirroring `lib/`), including property specs. |
| `spec/fixtures/` | Optional fixtures and golden files used by specs. |
| `scripts/` | The single definition of the quality gates (`check.rb`) and the factory's dependency tool. |
| `docs/` | Architecture, decisions (ADRs), testing, security, project record, stack. |
| `fabrica.json` | Install and check commands used by the factory and CI. |
| `docs-manifest.json` | Documentation files the docs gate requires. |
| `.github/` | CI wrapper and Dependabot configuration. |

## Conventions

- Ruby 4.0 or newer, `# frozen_string_literal: true` at the top of every file, double-quoted
  strings, clean under RuboCop.
- Standard library only unless an ADR in `docs/decisions/` justifies a dependency.
- Every public module, class, constant and method has a YARD comment; invalid input raises a
  documented `ArgumentError` subclass of the library, never returns nil or a sentinel.
- Write the failing spec first; specs use every literal of the acceptance items verbatim, and
  property specs (generated inputs from a fixed `Random` seed) cover invariants.
- CI-only conformance specs (external tools or downloads) carry the `:conformance` tag; only CI
  runs them.
- Every behavior change updates `README.md` usage, `CHANGELOG.md` (Unreleased) and, if it is a
  design choice, a new ADR.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`).

## Limits

- Never push to `main`; work on a branch and open a pull request.
- Do NOT edit `.github/`, `fabrica.json`, `docs-manifest.json`, `scripts/`, `Gemfile`,
  `Gemfile.lock`, `library.gemspec`, `lib/trysac/webhook_inbox/version.rb`, `.rubocop.yml`,
  `.editorconfig` or any tool configuration. They are the quality contract; changes to them are
  made by a human.
- Never lower the coverage threshold, add `# rubocop:disable`, `# :nocov:` or a `.rubocop_todo.yml`
  to silence a finding, or skip a spec to make a gate pass.
- Never commit secrets, tokens, credentials or `.env` files; gitleaks blocks them.
