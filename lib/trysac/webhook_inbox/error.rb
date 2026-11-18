# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Base error class for Trysac::WebhookInbox with a machine-readable code.
    class Error < ArgumentError
      # Maximum number of characters allowed in an error message.
      MAX_MESSAGE_LENGTH = 200

      # @return [Symbol] the machine-readable error code
      attr_reader :code

      # Initializes a new Error.
      #
      # @param code [Symbol] machine-readable error code
      # @param message [String, nil] human-readable description (truncated to 200 chars)
      def initialize(code, message = nil)
        @code = code.to_sym
        msg = (message || code.to_s).to_s
        msg = msg[0, MAX_MESSAGE_LENGTH] if msg.length > MAX_MESSAGE_LENGTH
        super(msg)
      end
    end
  end
end
