# webhook-inbox

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/Trysac/u955-webhook-inbox/actions/workflows/ci.yml/badge.svg)](https://github.com/Trysac/u955-webhook-inbox/actions/workflows/ci.yml)

Rack webhook inbox that captures, inspects and forwards requests with byte-exact bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures

## Problem

Describe in two or three sentences the concrete problem this utility solves, who hits it, and what
they do today without it. Replace this paragraph when the first real feature lands.

## Install

```ruby
# Gemfile
gem "u955-webhook-inbox"
```

Until it is published on RubyGems, point the Gemfile at a release tag:
`gem "u955-webhook-inbox", git: "https://github.com/Trysac/u955-webhook-inbox", tag: "v0.1.0"`. Requires Ruby 4.0 or newer. No
dependencies outside the Ruby standard library.

## Usage

```ruby
require "trysac/webhook_inbox"

# normalize trims surrounding whitespace and lower-cases the text.
Trysac::WebhookInbox::Text.normalize("  Hello World ") # => "hello world"

# Blank input is rejected explicitly instead of returning an empty string.
Trysac::WebhookInbox::Text.normalize("   ") # raises Trysac::WebhookInbox::BlankInputError ("input is blank")
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) and [decisions](docs/decisions/)
- [Testing](docs/TESTING.md) and [security](docs/SECURITY.md)
- [Project record](docs/PROJECT.md) and [stack](docs/STACK.md)
- [Changelog](CHANGELOG.md) and [contributing guide](CONTRIBUTING.md)

## License

[MIT](LICENSE) (c) 2026 Miguel Gomez
