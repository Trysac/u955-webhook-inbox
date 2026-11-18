# frozen_string_literal: true

require "spec_helper"

RSpec.describe Trysac::WebhookInbox::Text do
  let(:samples) do
    rng = Random.new(42)
    Array.new(50) { Array.new(rng.rand(1..30)) { rng.rand(65..90).chr }.join }
  end

  it "is idempotent across generated padded inputs" do
    samples.each do |sample|
      once = described_class.normalize("  #{sample}  ")
      expect(described_class.normalize(once)).to eq(once)
    end
  end

  it "trims and lower-cases every generated padded input" do
    samples.each { |sample| expect(described_class.normalize("  #{sample}  ")).to eq(sample.downcase(:ascii)) }
  end

  it "truncates Error messages to at most 200 characters" do
    err = Trysac::WebhookInbox::Error.new(:invalid_inbox, "x" * 500)
    expect([err.message.length, err.code]).to eq([200, :invalid_inbox])
  end
end
