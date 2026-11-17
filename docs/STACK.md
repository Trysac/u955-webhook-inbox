# Stack

## Used

| Tool | Why |
|---|---|
| Ruby 4.0 | The current stable branch (normal maintenance); frozen string literals in every file. |
| Bundler | The standard dependency manager; `Gemfile.lock` committed, frozen installs, gem built from `library.gemspec`. |
| RuboCop + rubocop-rspec | Layout (format gate) and every other cop, Security and RSpec included (lint gate). |
| RSpec + SimpleCov | Specs, seeded property specs and line coverage of `lib/` (read by the gate). |
| YARD | The docs gate: every public module, class, constant and method documented (`yard stats --list-undoc`). |
| Semgrep CE + OSV-Scanner | The factory's own rules; OSV advisories over `Gemfile.lock`. |
| bundler-audit | The Ruby Advisory Database for every locked gem. |
| gitleaks | Secret scanning locally and in CI. |
| GitHub Actions + Dependabot | Thin CI wrapper over the local gates; weekly dependency updates. |

## Discarded

| Tool | Why not |
|---|---|
| Standard | RuboCop with an explicit configuration does the same and keeps every cop visible. |
| Steep/RBS, Sorbet | A second source of truth (signature files) for a small library; RuboCop and the specs cover it. |
| Minitest | RSpec is the template's standard; one test framework is enough. |
| rantly, prop_check | Generated inputs from a seeded `Random` give reproducible property specs without another gem. |
| Rake | The gates are one script (`scripts/check.rb`) that the factory, CI and contributors all run. |
| Shell scripts for gates | Not portable to Windows; the gates are a Ruby script. |
