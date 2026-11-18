# frozen_string_literal: true

require "spec_helper"
require "socket"
require "standardwebhooks"

RSpec.describe Trysac::WebhookInbox::Forwarder do
  let(:secret) { "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw" }
  let(:fixed_time) { 1_614_265_330 }

  def build_forwarder(timeout)
    described_class.new(
      http: Trysac::WebhookInbox::RawHttpClient.new, signer_secret: secret,
      allowed_hosts: ["127.0.0.1"], timeout: timeout, clock: -> { fixed_time }
    )
  end

  def build_request(id:, headers:, body:)
    Trysac::WebhookInbox::CapturedRequest.new(
      id: id, inbox: "stripe", method: "POST", path: "/hooks/stripe", query: "",
      headers: headers, body: body, received_at: fixed_time
    )
  end

  def read_headers(client)
    headers = []
    while (line = client.gets("\r\n"))
      stripped = line.chomp("\r\n")
      break if stripped.empty?

      headers << stripped.split(": ", 2)
    end
    headers
  end

  def serve_once(client, wire)
    request_line = client.gets("\r\n")
    headers = read_headers(client)
    length = headers.find { |name, _| name.casecmp("Content-Length").zero? }&.last.to_i
    wire << { request_line: request_line, headers: headers, body: client.read(length) }
    client.write("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
  ensure
    client.close
  end

  def forward_and_capture(request)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    wire = Queue.new
    thread = Thread.new { serve_once(server.accept, wire) }
    result = build_forwarder(5).forward(request, "http://127.0.0.1:#{port}/in")
    thread.join(5)
    server.close
    { result: result, wire: wire.pop(true), port: port }
  end

  describe 'forwarding binary body "\x00\xff\r\n" over a real TCPServer' do
    let(:stored_req) do
      build_request(
        id: "msg_000001", body: "\x00\xff\r\n".b,
        headers: [
          ["host", "original.example.com"], ["connection", "keep-alive"], ["keep-alive", "timeout=5"],
          ["transfer-encoding", "chunked"], ["content-length", "999"], ["x-first-header", "one"],
          ["content-type", "application/octet-stream"], ["x-second-header", "two"]
        ]
      )
    end
    let(:exchange) { forward_and_capture(stored_req) }
    let(:wire) { exchange[:wire] }

    def header_map
      wire[:headers].to_h { |name, value| [name.downcase, value] }
    end

    it "returns a successful result and records the attempt" do
      result = exchange[:result]
      expect([result.status, result.error_code, result.success?]).to eq([204, nil, true])
      expect(stored_req.forwards.length).to eq(1)
    end

    it "sends the request line and the exact binary body" do
      expect(wire[:request_line]).to eq("POST /in HTTP/1.1\r\n")
      expect([wire[:body], wire[:body].encoding]).to eq(["\x00\xff\r\n".b, Encoding::BINARY])
      expect(stored_req.body_text).to be_nil
    end

    it "rewrites framing headers and drops hop-by-hop headers" do
      expect(header_map.slice("host", "content-length")).to eq(
        "host" => "127.0.0.1:#{exchange[:port]}", "content-length" => "4"
      )
      expect(header_map.keys).not_to include("keep-alive", "transfer-encoding")
    end

    it "keeps application header order and appends the Standard Webhooks headers" do
      non_framing = wire[:headers].reject { |k, _| %w[host content-length connection].include?(k.downcase) }
      expect(non_framing.first(5)).to eq(
        [%w[x-first-header one], ["content-type", "application/octet-stream"], %w[x-second-header two],
         %w[webhook-id msg_000001], ["webhook-timestamp", fixed_time.to_s]]
      )
      expect(non_framing[5][0]).to eq("webhook-signature")
    end

    it "signs the forwarded request so Signer and the StandardWebhooks oracle both accept it" do
      verified = Trysac::WebhookInbox::Signer.verify(secret: secret, headers: wire[:headers], body: wire[:body],
                                                     now: fixed_time)
      expect(verified).to be(true)
      # The oracle's #verify JSON-parses the payload, which a binary body is not, so compare against its #sign.
      expect(header_map["webhook-signature"]).to eq(StandardWebhooks::Webhook.new(secret).sign("msg_000001", fixed_time,
                                                                                               wire[:body]))
    end
  end

  def garbage_server
    server = TCPServer.new("127.0.0.1", 0)
    Thread.new do
      client = server.accept
      client.write("NOT_HTTP_GARBAGE\r\n")
      client.close
    end
    server
  end

  it "records a failed attempt when RawHttpClient encounters a connection failure or malformed response" do
    server = garbage_server
    req = build_request(id: "msg_000002", headers: [], body: "{}")
    res = build_forwarder(2).forward(req, "http://127.0.0.1:#{server.addr[1]}/bad?x=1")
    server.close
    expect([res.status, res.error_code, res.success?]).to eq([nil, :forward_failed, false])
    expect(req.forwards.last.error_code).to eq(:forward_failed)
  end
end
