# Security Policy & Threat Model

## Threat Model

### Defended Threats

1. **Cross-Site Scripting (XSS) in HTML Views**: Webhook senders are untrusted and may send malicious HTML/JavaScript inside header names, header values, paths, or request bodies. Every dynamic value rendered in `Trysac::WebhookInbox::Views` passes through `ERB::Util.html_escape`, and every HTTP response carries `x-content-type-options: nosniff`.
2. **Server-Side Request Forgery (SSRF)**: The forwarder accepts only `http` and `https` URLs whose parsed `URI#host` matches an entry in `allowed_hosts` byte-for-byte. No DNS resolution or wildcard matching is performed during allow-list checks, and `RawHttpClient` reads only the response status and headers without following redirects.
3. **Memory Exhaustion (Denial of Service)**: Incoming webhook bodies are capped at `max_body_bytes` (default `1_048_576` bytes); requests exceeding the cap are rejected with `413` (`:payload_too_large`). The in-memory `Store` enforces `max_requests` (default `1_000`) and evicts the oldest entry when full.
4. **Signature Forgery and Replay Attacks**: `Signer.verify` validates Standard Webhooks v1 HMAC-SHA256 signatures using constant-time byte comparison (`OpenSSL.fixed_length_secure_compare`) and rejects timestamps outside the configured `tolerance` window (default 300 seconds) with `:timestamp_out_of_tolerance`.
5. **Sensitive Data Leakage in Telemetry**: `on_event` callbacks emit only metadata (`type`, `id`, `inbox`, `size`, `status`, `error_code`) and never include header values, secrets, or body payloads. Error messages are truncated to at most 200 characters.

### Out of Scope / Not Defended

- **UI and API Authentication**: The Rack application is designed to run on `localhost` during development or behind an authenticating reverse proxy in staging environments.
- **TLS Certificate Pinning**: HTTPS forwarding uses the system OpenSSL trust store (`OpenSSL::SSL::VERIFY_PEER`) without custom certificate pinning.
