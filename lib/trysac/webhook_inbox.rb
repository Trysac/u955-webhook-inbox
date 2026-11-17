# frozen_string_literal: true

require_relative "webhook_inbox/version"
require_relative "webhook_inbox/blank_input_error"
require_relative "webhook_inbox/text"

# The namespace of the Trysac factory's Ruby libraries.
module Trysac
  # Rack webhook inbox that captures, inspects and forwards requests with byte-exact bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures
  module WebhookInbox
  end
end
