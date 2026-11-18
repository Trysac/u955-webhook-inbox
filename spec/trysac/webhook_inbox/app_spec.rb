# frozen_string_literal: true

require "spec_helper"
require "rack"
require "rack/lint"
require "rack/mock"
require "json"

RSpec.describe Trysac::WebhookInbox::App do
  let(:secret) { "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw" }
  let(:http) { Trysac::WebhookInbox::FakeHttpClient.new(default_status: 200) }
  let(:events) { [] }
  let(:raw) do
    clock = -> { 1_614_265_330 }
    forwarder = Trysac::WebhookInbox::Forwarder.new(
      http: http, signer_secret: secret, allowed_hosts: ["127.0.0.1", "hooks.internal"], timeout: 5, clock: clock
    )
    described_class.new(
      store: Trysac::WebhookInbox::Store.new(max_requests: 1_000), forwarder: forwarder,
      ids: Trysac::WebhookInbox::IdGenerator.sequential, clock: clock,
      max_body_bytes: 1_048_576, on_event: ->(ev) { events << ev }
    )
  end
  let(:client) { Rack::MockRequest.new(Rack::Lint.new(raw)) }

  def post_github_push
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_X_GITHUB_EVENT" => "push" }
    client.post("/hooks/github", **headers, input: '{"a":1}')
  end

  describe "POST /hooks/:inbox capture" do
    it "captures POST with arrival headers and emits metadata-only event" do
      res = client.post("/hooks/github", "CONTENT_TYPE" => "application/json",
                                         "HTTP_X_GITHUB_EVENT" => "push", input: '{"a":1}')
      expect([res.status, res.headers["x-content-type-options"], JSON.parse(res.body)]).to eq(
        [202, "nosniff", { "id" => "msg_000001" }]
      )
      expect(events).to eq([{ type: :received, id: "msg_000001", inbox: "github", size: 7 }])
      expect(events.first.keys).not_to include(:body, :headers)
    end

    it "returns stored request details via GET /api/requests/:id" do
      post_github_push
      res = client.get("/api/requests/msg_000001")
      data = JSON.parse(res.body)
      expect([res.status, res.headers["x-content-type-options"]]).to eq([200, "nosniff"])
      expect([data["id"], data["method"], data["body_base64"], data["body_text"]]).to eq(
        ["msg_000001", "POST", "eyJhIjoxfQ==", '{"a":1}']
      )
      expect(data["headers"]).to eq([%w[content-length 7], %w[content-type application/json], %w[x-github-event push]])
    end
  end

  describe "HTML inspection and inbox management" do
    it "lists requests newest first and renders escaped HTML in index and inbox views" do
      client.post("/hooks/github", "HTTP_X_XSS" => "<script>", input: "first")
      client.put("/hooks/github", "HTTP_X_SECOND" => "2", input: "second")
      ids = JSON.parse(client.get("/api/inboxes/github/requests").body)["requests"].map { |r| r["id"] }
      root_body = client.get("/").body
      inbox_body = client.get("/inboxes/github").body
      expect(ids).to eq(%w[msg_000002 msg_000001])
      expect(root_body).to include("&lt;script&gt;").and(exclude("<script>"))
      expect(inbox_body).to include("&lt;script&gt;")
    end

    it "deletes inbox requests with 204" do
      client.post("/hooks/github", input: "data")
      del_res = client.delete("/api/inboxes/github")
      after = JSON.parse(client.get("/api/inboxes/github/requests").body)["requests"]
      expect([del_res.status, del_res.headers["x-content-type-options"], del_res.body]).to eq(
        [204, "nosniff", ""]
      )
      expect(after).to be_empty
    end
  end

  describe "size limits and inbox name validation" do
    it "returns 413 payload_too_large when body exceeds max_body_bytes" do
      res = client.post("/hooks/github", input: "a" * 1_048_577)
      expect([res.status, res.headers["x-content-type-options"]]).to eq([413, "nosniff"])
      expect(JSON.parse(res.body)["code"]).to eq("payload_too_large")
    end

    it "returns 400 invalid_inbox when inbox name contains spaces" do
      env = Rack::MockRequest.env_for("/hooks/Bad%20Name", method: "POST", input: "{}")
      env["PATH_INFO"] = "/hooks/Bad Name"
      status, headers, body_enum = raw.call(env)
      body_str = body_enum.join
      expect([status, headers["x-content-type-options"]]).to eq([400, "nosniff"])
      expect(JSON.parse(body_str)["code"]).to eq("invalid_inbox")
    end
  end

  describe "forwarding API" do
    it "forwards to allowed targets and records the attempt" do
      client.post("/hooks/github", input: '{"hello":"world"}')
      res = client.post(
        "/api/requests/msg_000001/forward",
        "CONTENT_TYPE" => "application/json",
        input: JSON.generate({ "url" => "http://127.0.0.1:8080/webhook" })
      )
      expect([res.status, JSON.parse(res.body)["status"]]).to eq([200, 200])
      expect(http.calls.length).to eq(1)
    end

    it "rejects non-allowlisted targets with 403 target_not_allowed" do
      client.post("/hooks/github", input: "{}")
      res = client.post(
        "/api/requests/msg_000001/forward",
        "CONTENT_TYPE" => "application/json",
        input: JSON.generate({ "url" => "http://169.254.169.254/latest" })
      )
      expect([res.status, JSON.parse(res.body)["code"]]).to eq([403, "target_not_allowed"])
    end

    it "rejects invalid schemes and malformed JSON with 400 invalid_url" do
      client.post("/hooks/github", input: "{}")
      file_res = client.post("/api/requests/msg_000001/forward",
                             "CONTENT_TYPE" => "application/json", input: '{"url":"file:///etc/passwd"}')
      bad_json = client.post("/api/requests/msg_000001/forward",
                             "CONTENT_TYPE" => "application/json", input: "{not_json")
      expect([file_res.status, JSON.parse(file_res.body)["code"]]).to eq([400, "invalid_url"])
      expect([bad_json.status, JSON.parse(bad_json.body)["code"]]).to eq([400, "invalid_url"])
    end

    it "returns 502 forward_failed and records failure on transport error" do
      client.post("/hooks/github", input: "{}")
      http.respond_with(error: Timeout::Error.new("timed out"))
      res = client.post("/api/requests/msg_000001/forward",
                        "CONTENT_TYPE" => "application/json",
                        input: '{"url":"http://127.0.0.1:8080/webhook"}')
      expect([res.status, JSON.parse(res.body)["code"]]).to eq([502, "forward_failed"])
      stored = raw.store.find("msg_000001")
      expect([stored.forwards.length, stored.forwards.last.error_code]).to eq([1, :forward_failed])
    end
  end

  describe "404 handling" do
    it "returns 404 for unknown routes and missing request IDs" do
      r1 = client.get("/unknown/route")
      r2 = client.get("/api/requests/msg_999999")
      r3 = client.post("/api/requests/msg_999999/forward", input: '{"url":"http://127.0.0.1/x"}')
      expect([r1.status, JSON.parse(r1.body)["code"]]).to eq([404, "not_found"])
      expect([r2.status, JSON.parse(r2.body)["code"]]).to eq([404, "not_found"])
      expect([r3.status, JSON.parse(r3.body)["code"]]).to eq([404, "not_found"])
    end
  end
end
