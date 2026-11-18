# frozen_string_literal: true

require "securerandom"

module Trysac
  module WebhookInbox
    # Generates unique message identifiers prefixed with `msg_`.
    class IdGenerator
      # Creates a new random ID generator.
      def initialize
        @mutex = Mutex.new
      end

      # Generates the next random message ID (`"msg_" + SecureRandom.alphanumeric(24)`).
      #
      # @return [String] a unique message identifier
      def call
        "msg_#{SecureRandom.alphanumeric(24)}"
      end

      # Alias for {#call}.
      #
      # @return [String] a unique message identifier
      def next_id
        call
      end

      # Builds a deterministic sequential ID generator (`msg_000001`, `msg_000002`, ...).
      #
      # @param start [Integer] the first number in the sequence (default 1)
      # @return [Sequential] a thread-safe sequential ID generator
      def self.sequential(start = 1)
        Sequential.new(start)
      end

      # Deterministic sequential ID generator useful in tests and demos.
      class Sequential
        # @param start [Integer] starting counter value
        def initialize(start = 1)
          @counter = start - 1
          @mutex = Mutex.new
        end

        # Returns the next formatted message ID.
        #
        # @return [String] e.g. `"msg_000001"`
        def call
          val = @mutex.synchronize { @counter += 1 }
          format("msg_%06d", val)
        end

        # Alias for {#call}.
        #
        # @return [String]
        def next_id
          call
        end
      end
    end
  end
end
