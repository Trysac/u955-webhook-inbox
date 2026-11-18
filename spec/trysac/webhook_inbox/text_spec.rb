# frozen_string_literal: true

require "spec_helper"

RSpec.describe Trysac::WebhookInbox::Text do
  describe ".normalize" do
    it "trims surrounding whitespace and lower-cases ASCII letters" do
      expect(described_class.normalize("  GitHub-Hooks \n")).to eq("github-hooks")
    end

    it "raises BlankInputError when input is empty or whitespace" do
      expect { described_class.normalize("   \t\n ") }.to raise_error(
        an_instance_of(Trysac::WebhookInbox::BlankInputError).and(having_attributes(code: :blank_input)),
        /blank/
      )
    end

    it "raises Error when input is not a String" do
      expect { described_class.normalize(123) }.to raise_webhook_error(:invalid_inbox)
    end

    it "raises Error when input exceeds max size" do
      huge = "a" * (described_class::MAX_INPUT_LENGTH + 1)
      expect { described_class.normalize(huge) }.to raise_webhook_error(:payload_too_large)
    end
  end
end
