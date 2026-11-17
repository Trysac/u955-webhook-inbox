# frozen_string_literal: true

require "spec_helper"

RSpec.describe Trysac::WebhookInbox::Text do
  describe ".normalize" do
    it "trims surrounding whitespace and lower-cases the text" do
      expect(described_class.normalize("  Hello World ")).to eq("hello world")
    end

    it "keeps inner whitespace" do
      expect(described_class.normalize("\tA  B\n")).to eq("a  b")
    end

    it "lower-cases only ASCII letters" do
      expect(described_class.normalize("ÉCOLE")).to eq("École")
    end

    it "raises BlankInputError on blank input" do
      expect { described_class.normalize("   ") }
        .to raise_error(Trysac::WebhookInbox::BlankInputError, "input is blank")
    end

    it "raises BlankInputError on empty input" do
      expect { described_class.normalize("") }.to raise_error(ArgumentError, "input is blank")
    end
  end

  it "exposes a semantic version" do
    expect(Trysac::WebhookInbox::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
