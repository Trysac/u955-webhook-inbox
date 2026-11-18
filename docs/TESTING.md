# Testing

Specs live under `spec/trysac/webhook_inbox/` and run with RSpec and SimpleCov:

- `signer_spec.rb`: Verifies Standard Webhooks v1 test vectors, tolerance boundaries, multi-signature headers, and cross-checks signatures against the `standardwebhooks` 1.1 gem oracle.
- `forwarder_spec.rb`: Verifies byte-exact binary body (`"\x00\xff\r\n"`) and header order preservation over a local `TCPServer`, hop-by-hop header removal, and signature verification.
- `app_spec.rb`: Wraps `Trysac::WebhookInbox::App` in `Rack::Lint` from `rack` 3.2 and exercises every route, status code, error code, and security header.
- `store_spec.rb`: Tests ring-buffer eviction at 1,001 requests and inbox validation.
- `security_spec.rb`: Dedicated specs for each threat in `docs/SECURITY.md`.
- `cli_spec.rb`: Exercises `CLI.run` exit codes (`0`, `1`, `2`).
