# Architecture

## Overview

`Trysac::WebhookInbox` is structured as a modular Rack 3 application using only the Ruby 4.0 standard library at runtime:

1. **`Trysac::WebhookInbox::App`**: Plain Rack 3 callable (`call(env) -> [status, headers, body]`) with lower-case response header names and `x-content-type-options: nosniff` on every response. Reconstructs incoming request headers in Rack `env` iteration order from `CONTENT_TYPE`, `CONTENT_LENGTH`, and `HTTP_*`.
2. **`Trysac::WebhookInbox::Store`**: Mutex-guarded bounded ring buffer (`max_requests: 1_000` by default) that evicts the oldest request when capacity is reached.
3. **`Trysac::WebhookInbox::CapturedRequest` & `ForwardResult`**: Value objects holding the binary body (`Encoding::BINARY`), ordered `[[name, value]]` header pairs, Base64 encoding, optional UTF-8 text projection, and thread-safe list of forward attempts.
4. **`Trysac::WebhookInbox::Signer`**: Implements Standard Webhooks v1 signing (`HMAC-SHA256` over `"#{id}.#{timestamp}.#{body}"` with `whsec_` base64 secrets) and constant-time verification (`OpenSSL.fixed_length_secure_compare`) with timestamp tolerance.
5. **`Trysac::WebhookInbox::Forwarder` & `RawHttpClient`**: Validates target URLs against an exact hostname/IP allow-list (`http` and `https` only, no redirects followed), strips RFC 9110 section 7.6.1 hop-by-hop headers plus original `Host` and `Content-Length`, appends `webhook-id`, `webhook-timestamp`, and `webhook-signature`, and writes raw HTTP/1.1 bytes over `TCPSocket` / `OpenSSL::SSL::SSLSocket`.
6. **`Trysac::WebhookInbox::Views`**: Standard-library `ERB` templates that escape every rendered value via `ERB::Util.html_escape`.
7. **`Trysac::WebhookInbox::CLI`**: Command-line entry point (`CLI.run(argv, stdout:, stderr:)`) for signing and verifying payloads.
