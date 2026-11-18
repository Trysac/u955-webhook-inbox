# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Text helpers of this library.
    module Text
      # Maximum text length accepted by normalize.
      MAX_INPUT_LENGTH = 65_536

      # Trims surrounding whitespace and lower-cases the ASCII letters of the text.
      #
      # @param input [String] the text to normalize
      # @return [String] the trimmed, lower-cased text
      # @raise [BlankInputError] when nothing is left after trimming
      # @raise [Error] when input is not a String or exceeds MAX_INPUT_LENGTH
      def self.normalize(input)
        raise Error.new(:invalid_inbox, "input must be a String") unless input.is_a?(String)
        raise Error.new(:payload_too_large, "input exceeds max length") if input.bytesize > MAX_INPUT_LENGTH

        trimmed = input.strip
        raise BlankInputError if trimmed.empty?

        trimmed.downcase(:ascii)
      end
    end
  end
end
