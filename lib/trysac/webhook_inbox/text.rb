# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Text helpers of this library.
    module Text
      # Trims surrounding whitespace and lower-cases the ASCII letters of the text.
      #
      # @param input [String] the text to normalize
      # @return [String] the trimmed, lower-cased text
      # @raise [BlankInputError] when nothing is left after trimming, instead of returning an empty string
      def self.normalize(input)
        trimmed = input.strip
        raise BlankInputError if trimmed.empty?

        trimmed.downcase(:ascii)
      end
    end
  end
end
