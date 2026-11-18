# u955-webhook-inbox

Rack webhook inbox that captures, inspects and forwards requests with byte-exact bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures.

## Why

Developers integrating webhooks cannot see what a provider actually sent, and replaying a captured request through `curl` changes headers or re-encodes the body, so signatures stop matching. Hosted request bins are external and keep data outside the team. `Trysac::WebhookInbox` is a self-hosted, bounded Rack application that stores requests in memory, displays them safely with HTML escaping, and forwards them with their exact binary bytes, original header order, and a Standard Webhooks v1 signature to an allow-listed target.

## Usage

```ruby
require "trysac/webhook_inbox"

secret = ENV.fetch("WEBHOOK_SECRET") # a whsec_... value from your provider
sig = Trysac::WebhookInbox::Signer.sign(secret: secret, id: "msg_000001", timestamp: 1_614_265_330, body: '{"a":1}')
Trysac::WebhookInbox::Signer.verify(secret: secret, headers: { "webhook-id" => "msg_000001", "webhook-timestamp" => "1614265330", "webhook-signature" => sig }, body: '{"a":1}', now: 1_614_265_330)

store = Trysac::WebhookInbox::Store.new(max_requests: 1_000)
forwarder = Trysac::WebhookInbox::Forwarder.new(signer_secret: secret, allowed_hosts: ["127.0.0.1"])
app = Trysac::WebhookInbox::App.new(store: store, forwarder: forwarder)
```

## HTTP Routes

| Method & Path | Description |
|---|---|
| `POST\|PUT\|PATCH\|DELETE /hooks/:inbox` | Captures a webhook request into `:inbox` (`\A[a-z0-9-]{1,64}\z`) and returns `202` `{"id":"..."}`. |
| `GET /` | HTML overview of active inboxes and captured requests. |
| `GET /inboxes/:inbox` | HTML view of captured requests for `:inbox`. |
| `GET /api/inboxes/:inbox/requests` | JSON list of captured requests in `:inbox` (newest first). |
| `GET /api/requests/:id` | JSON representation of a captured request (`headers`, `body_base64`, `body_text`, `forwards`). |
| `POST /api/requests/:id/forward` | Forwards request `:id` to `{"url": "..."}` if the target host is allow-listed. |
| `DELETE /api/inboxes/:inbox` | Evicts all requests in `:inbox` and returns `204`. |

## Development

Run all quality gates:

```bash
ruby scripts/check.rb
```
