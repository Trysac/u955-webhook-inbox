# frozen_string_literal: true

require "trysac/webhook_inbox"

# Matchers shared by the webhook inbox specs.
module WebhookInboxMatchers
  # Matches a raised {Trysac::WebhookInbox::Error} (or subclass) carrying the given code.
  def raise_webhook_error(code, message = nil)
    error = a_kind_of(Trysac::WebhookInbox::Error).and(having_attributes(code: code))
    message ? raise_error(error, message) : raise_error(error)
  end
end

RSpec::Matchers.define_negated_matcher :exclude, :include

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.include WebhookInboxMatchers
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
