# frozen_string_literal: true

require_relative "error"

module Trysac
  module WebhookInbox
    # Raised when a required text input is empty or contains only whitespace.
    class BlankInputError < Error
      # Initializes a BlankInputError.
      #
      # @param message [String] error message
      def initialize(message = "input must not be blank")
        super(:blank_input, message)
      end
    end
  end
end
