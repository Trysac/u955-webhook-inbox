# frozen_string_literal: true

require "spec_helper"
require "standardwebhooks"

RSpec.describe Trysac::WebhookInbox::Signer do
  let(:secret) { "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw" }
  let(:msg_id) { "msg_p5jXN8AQM9LWM0D4loKWxJek" }
  let(:timestamp) { 1_614_265_330 }
  let(:body) { '{"test": 2432232314}' }
  let(:expected_sig) { "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=" }

  def signed_headers(signature = expected_sig)
    { "webhook-id" => msg_id, "webhook-timestamp" => timestamp.to_s, "webhook-signature" => signature }
  end

  def verify_with(headers: signed_headers, payload: body, now: timestamp)
    described_class.verify(secret: secret, headers: headers, body: payload, now: now)
  end

  describe ".sign and StandardWebhooks oracle" do
    it "produces the exact Standard Webhooks v1 signature" do
      expect(described_class.sign(secret: secret, id: msg_id, timestamp: timestamp, body: body)).to eq(expected_sig)
    end

    it "passes the standardwebhooks 1.1 oracle" do
      sig = described_class.sign(secret: secret, id: msg_id, timestamp: timestamp, body: body)
      # StandardWebhooks::Webhook#verify compares against Time.now internally, so stub Time.now
      allow(Time).to receive(:now).and_return(Time.at(timestamp))
      expect(StandardWebhooks::Webhook.new(secret).verify(body, signed_headers(sig))).to eq({ "test" => 2_432_232_314 })
    end
  end

  describe ".verify" do
    it "accepts the signature at now 1614265630 (300 s later)" do
      expect(verify_with(now: 1_614_265_630)).to be(true)
    end

    it "raises :timestamp_out_of_tolerance at 1614265631" do
      expect { verify_with(now: 1_614_265_631) }.to raise_webhook_error(:timestamp_out_of_tolerance)
    end

    it "raises :invalid_signature when the body is changed" do
      expect { verify_with(payload: '{"test": 2432232315}') }.to raise_webhook_error(:invalid_signature)
    end

    it "passes when the header has two space-separated signatures of which one is valid" do
      multi_headers = signed_headers("v1,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= #{expected_sig}").to_a
      expect(verify_with(headers: multi_headers)).to be(true)
    end

    it "rejects invalid secrets" do
      ["invalid", "whsec_", "whsec_***not_base64***"].each do |bad|
        expect do
          described_class.sign(secret: bad, id: msg_id, timestamp: timestamp, body: body)
        end.to raise_webhook_error(:invalid_secret)
      end
    end

    it "rejects missing headers" do
      expect { verify_with(headers: {}) }.to raise_webhook_error(:invalid_signature)
    end

    it "rejects malformed timestamps" do
      bad_ts = signed_headers.merge("webhook-timestamp" => "not-a-number")
      expect { verify_with(headers: bad_ts) }.to raise_webhook_error(:invalid_signature)
    end

    it "rejects malformed signature tokens" do
      bad_sig = signed_headers("v2,abc v1,!!!bad_b64!!! v1,dG9vc2hvcnQ=")
      expect { verify_with(headers: bad_sig) }.to raise_webhook_error(:invalid_signature)
    end
  end
end
