# frozen_string_literal: true

require_relative "webhook_inbox/version"
require_relative "webhook_inbox/error"
require_relative "webhook_inbox/blank_input_error"
require_relative "webhook_inbox/text"
require_relative "webhook_inbox/id_generator"
require_relative "webhook_inbox/captured_request"
require_relative "webhook_inbox/store"
require_relative "webhook_inbox/signer"
require_relative "webhook_inbox/raw_http_client"
require_relative "webhook_inbox/fake_http_client"
require_relative "webhook_inbox/forwarder"
require_relative "webhook_inbox/views"
require_relative "webhook_inbox/responses"
require_relative "webhook_inbox/rack_input"
require_relative "webhook_inbox/router"
require_relative "webhook_inbox/app"
require_relative "webhook_inbox/cli"

# The namespace of the Trysac factory's Ruby libraries.
module Trysac
  # Rack webhook inbox that captures, inspects and forwards requests with byte-exact
  # bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures.
  module WebhookInbox
  end
end
