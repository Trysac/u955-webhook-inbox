# frozen_string_literal: true

require "spec_helper"

# Property specs: invariants checked on inputs generated from a fixed seed, so every run checks the same cases.
RSpec.describe "Text.normalize properties" do
  let(:text) { Trysac::WebhookInbox::Text }
  let(:inputs) do
    alphabet = [*"a".."z", *"A".."Z", *"0".."9", " ", "\t", "\n", "-", "_", "é", "Ä"]
    Array.new(200) do |index|
      random = Random.new(index)
      core = Array.new(random.rand(1..12)) { alphabet[random.rand(alphabet.size)] }.join
      "#{" " * random.rand(3)}x#{core}#{"\t" * random.rand(3)}"
    end
  end

  it "is idempotent" do
    inputs.each do |input|
      once = text.normalize(input)
      expect(text.normalize(once)).to eq(once)
    end
  end

  it "leaves no surrounding whitespace" do
    inputs.each do |input|
      result = text.normalize(input)
      expect(result).to eq(result.strip)
    end
  end

  it "has no ASCII upper-case letters" do
    inputs.each do |input|
      expect(text.normalize(input)).not_to match(/[A-Z]/)
    end
  end
end
