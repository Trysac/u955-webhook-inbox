# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Trysac::WebhookInbox::CLI do
  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    code = described_class.run(argv, stdout: out, stderr: err)
    [code, out.string, err.string]
  end

  describe "sign and verify commands" do
    let(:secret) { "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw" }
    let(:msg_id) { "msg_p5jXN8AQM9LWM0D4loKWxJek" }
    let(:ts) { "1614265330" }
    let(:body) { '{"test": 2432232314}' }
    let(:sig) { "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=" }

    it "signs payloads with exit code 0" do
      code, out, err = run_cli("sign", "--secret", secret, "--id", msg_id, "--timestamp", ts, "--body", body)
      expect([code, err, out.strip]).to eq([0, "", sig])
    end

    it "verifies valid signatures with exit code 0" do
      args = ["verify", "--secret", secret, "--id", msg_id, "--timestamp", ts,
              "--signature", sig, "--body", body, "--now", ts]
      code, out, err = run_cli(*args)
      expect([code, err, out.strip]).to eq([0, "", "verified"])
    end

    it "returns exit code 1 on domain signature verification error" do
      args = ["verify", "--secret", secret, "--id", msg_id, "--timestamp", ts,
              "--signature", "v1,bad", "--body", body, "--now", ts]
      code, _, err = run_cli(*args)
      expect([code, err]).to match([1, a_string_including("invalid_signature")])
    end
  end

  describe "usage and option errors" do
    it "returns exit code 2 when required options are missing" do
      c1, = run_cli("sign", "--secret", "whsec_abc")
      c2, = run_cli("verify", "--secret", "whsec_abc")
      expect([c1, c2]).to eq([2, 2])
    end

    it "returns exit code 2 on unknown commands or unknown flags" do
      c1, = run_cli("unknown")
      c2, = run_cli("sign", "--unknown-flag")
      expect([c1, c2]).to eq([2, 2])
    end

    it "prints help and version information with exit code 0" do
      c_h, out_h, = run_cli("--help")
      c_v, out_v, = run_cli("--version")
      expect([c_h, out_h]).to match([0, a_string_including("Usage: webhook-inbox")])
      expect([c_v, out_v.strip]).to eq([0, Trysac::WebhookInbox::VERSION])
    end
  end
end
