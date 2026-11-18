# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `Trysac::WebhookInbox` Rack 3 application, bounded thread-safe `Store`, `Signer` (Standard Webhooks v1 HMAC-SHA256), `Forwarder` with `RawHttpClient` and `FakeHttpClient`, escaped ERB `Views`, and `CLI`.
- Initial project structure from the factory utility template.
