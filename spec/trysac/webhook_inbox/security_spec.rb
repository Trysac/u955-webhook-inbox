# frozen_string_literal: true

require "spec_helper"
require "rack/lint"
require "rack/mock"

RSpec.describe "Threat model defenses (docs/SECURITY.md)" do
  let(:secret) { "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw" }
  let(:store) { Trysac::WebhookInbox::Store.new(max_requests: 3) }
  let(:fake_http) { Trysac::WebhookInbox::FakeHttpClient.new(default_status: 200) }
  let(:app) do
    forwarder = Trysac::WebhookInbox::Forwarder.new(
      http: fake_http, signer_secret: secret, allowed_hosts: ["127.0.0.1"], clock: -> { 1_614_265_330 }
    )
    Rack::Lint.new(
      Trysac::WebhookInbox::App.new(
        store: store, forwarder: forwarder, ids: Trysac::WebhookInbox::IdGenerator.sequential,
        clock: -> { 1_614_265_330 }, max_body_bytes: 64
      )
    )
  end
  let(:client) { Rack::MockRequest.new(app) }

  it "defends against XSS in the HTML view by escaping header names, header values, and bodies" do
    client.post("/hooks/sec", "HTTP_X_PAYLOAD" => "<script>alert(1)</script>", input: "<img src=x onerror=alert(2)>")
    html = client.get("/inboxes/sec").body
    expect(html).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    expect(html).to include("&lt;img src=x onerror=alert(2)&gt;")
    expect(html).not_to include("<script>")
  end

  it "defends against SSRF to non-allow-listed hosts and non-HTTP schemes without DNS resolution" do
    client.post("/hooks/sec", input: "{}")
    res = client.post("/api/requests/msg_000001/forward", input: '{"url":"http://169.254.169.254/latest"}')
    expect(res.status).to eq(403)
    expect(fake_http.calls).to be_empty
  end

  it "defends against memory exhaustion via the request body cap" do
    too_big = client.post("/hooks/sec", input: "x" * 65)
    expect(too_big.status).to eq(413)
    expect(store.size).to eq(0)
  end

  it "defends against memory exhaustion via ring-buffer eviction" do
    4.times { |i| client.post("/hooks/sec", input: "msg-#{i}") }
    expect(store.size).to eq(3)
    expect(store.find("msg_000001")).to be_nil
  end

  describe "signature forgery and replay" do
    def headers
      sig = Trysac::WebhookInbox::Signer.sign(secret: secret, id: "msg_1", timestamp: 1_000_000, body: '{"amount":100}')
      { "webhook-id" => "msg_1", "webhook-timestamp" => "1000000", "webhook-signature" => sig }
    end

    it "defends against signature forgery" do
      expect do
        Trysac::WebhookInbox::Signer.verify(secret: secret, headers: headers, body: '{"amount":999}', now: 1_000_000)
      end.to raise_webhook_error(:invalid_signature)
    end

    it "defends against replay outside tolerance" do
      expect do
        Trysac::WebhookInbox::Signer.verify(secret: secret, headers: headers, body: '{"amount":100}', now: 1_000_301)
      end.to raise_webhook_error(:timestamp_out_of_tolerance)
    end
  end
end
