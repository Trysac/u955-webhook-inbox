# Plain Rack 3 Application with Standard Library Runtime and Dev Oracles

Status: accepted (generated, pending human review)

## Context

Developers need a self-hosted webhook inbox that captures raw HTTP requests and replays them with byte-exact bodies, preserved header ordering, and Standard Webhooks v1 signatures without external runtime dependencies or HTTP client body re-encoding.

## Decision

Implement Trysac::WebhookInbox::App as a zero-runtime-dependency Rack 3 application using ERB for HTML escaping, OpenSSL::HMAC for Standard Webhooks v1 signing, and a TCPSocket/SSLSocket RawHttpClient for exact wire forwarding. Use rack (~> 3.2) for Rack::Lint and Rack::MockRequest and standardwebhooks (~> 1.1) as a verification oracle in development/test specs only.

## Consequences

The gem can be mounted in any Rack-compatible server or Sinatra application without dependency conflicts, guarantees byte-exact payload forwarding and header order, and is verified against Rack::Lint and the official Standard Webhooks reference implementation in CI.
