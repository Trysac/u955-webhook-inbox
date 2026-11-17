# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Raised when the input is empty or only whitespace, instead of returning an empty string.
    class BlankInputError < ArgumentError
      # Creates the error with the message "input is blank".
      def initialize
        super("input is blank")
      end
    end
  end
end
