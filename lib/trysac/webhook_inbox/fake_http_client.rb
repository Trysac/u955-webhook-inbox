# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # In-memory HTTP client double for deterministic testing without network sockets.
    class FakeHttpClient
      # @return [Array<Hash{Symbol => Object}>] list of captured request invocations
      attr_reader :calls

      # Initializes a new FakeHttpClient.
      #
      # @param default_status [Integer] default HTTP status returned when no handler fails
      # @param error [Exception, Symbol, nil] optional error to raise on every request
      def initialize(default_status: 200, error: nil)
        @default_status = default_status
        @error = error
        @calls = []
        @mutex = Mutex.new
      end

      # Configures the fake client to fail with the given error or return a status.
      #
      # @param status [Integer] status code to return
      # @param error [Exception, Symbol, nil] error to raise
      # @return [void]
      def respond_with(status: 200, error: nil)
        @mutex.synchronize do
          @default_status = status
          @error = error
        end
      end

      # Records the outgoing request parameters and returns the configured status or raises.
      #
      # @param options [Hash{Symbol => Object}] request parameters
      # @return [Integer] configured HTTP status code
      # @raise [Error] with `:forward_failed` when configured to fail
      def request(**options)
        err, status = record_and_fetch(options)
        raise_if_error!(err)
        status
      end

      private

      def record_and_fetch(opts)
        @mutex.synchronize do
          @calls << {
            scheme: opts[:scheme], host: opts[:host], port: opts[:port], method: opts[:method],
            request_target: opts[:request_target],
            headers: opts[:headers].map { |k, v| [k.dup, v.dup] },
            body: opts[:body].dup.force_encoding(Encoding::BINARY),
            timeout: opts.fetch(:timeout, 10)
          }
          [@error, @default_status]
        end
      end

      def raise_if_error!(err)
        return unless err

        msg = err.is_a?(Exception) ? err.message : err.to_s
        raise Error.new(:forward_failed, msg)
      end
    end
  end
end
