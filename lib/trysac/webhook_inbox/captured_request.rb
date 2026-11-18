# frozen_string_literal: true

require "base64"

module Trysac
  module WebhookInbox
    # Value object recording the result of a single forward attempt.
    class ForwardResult
      # @return [Integer, nil] the HTTP status code returned by the target, or nil on error
      attr_reader :status

      # @return [Symbol, nil] the error code if forwarding failed, or nil on success
      attr_reader :error_code

      # @return [String, nil] target URL for this forward attempt
      attr_reader :url

      # @return [Integer, nil] Unix epoch timestamp when the forward happened
      attr_reader :forwarded_at

      # Initializes a new ForwardResult.
      #
      # @param status [Integer, nil] HTTP response status code
      # @param error_code [Symbol, nil] error symbol on failure
      # @param url [String, nil] destination URL
      # @param forwarded_at [Integer, nil] epoch timestamp
      def initialize(status:, error_code: nil, url: nil, forwarded_at: nil)
        @status = status
        @error_code = error_code
        @url = url
        @forwarded_at = forwarded_at
        freeze
      end

      # Returns whether the forward attempt received an HTTP status without transport error.
      #
      # @return [Boolean]
      def success?
        !@status.nil? && @error_code.nil?
      end

      # Serializes this result to a JSON-compatible Hash.
      #
      # @return [Hash{String => Object}]
      def to_h
        {
          "status" => @status,
          "error_code" => @error_code&.to_s,
          "url" => @url,
          "forwarded_at" => @forwarded_at
        }
      end
    end

    # Represents a captured incoming webhook HTTP request.
    class CapturedRequest
      # @return [String] unique message identifier
      attr_reader :id

      # @return [String] inbox name
      attr_reader :inbox

      # @return [String] HTTP request method
      attr_reader :method

      # @return [String] request path
      attr_reader :path

      # @return [String] raw query string
      attr_reader :query

      # @return [Array<Array(String, String)>] request headers in arrival order
      attr_reader :headers

      # @return [String] raw binary request body (ASCII-8BIT)
      attr_reader :body

      # @return [Integer] Unix epoch timestamp when received
      attr_reader :received_at

      # Initializes a CapturedRequest.
      #
      # @param attributes [Hash] the captured request's fields
      # @option attributes [String] :id unique message ID
      # @option attributes [String] :inbox inbox name
      # @option attributes [String] :method HTTP verb
      # @option attributes [String] :path request path
      # @option attributes [String] :query query string
      # @option attributes [Array<Array(String, String)>] :headers pairs of `[name, value]`
      # @option attributes [String] :body binary body string
      # @option attributes [Integer] :received_at timestamp in seconds
      # @option attributes [Array<ForwardResult>] :forwards recorded forward attempts
      def initialize(**attributes)
        @id, @inbox, @method, @path, @query =
          attributes.values_at(:id, :inbox, :method, :path, :query).map { |value| frozen_text(value) }
        assign_payload(attributes)
        @forwards = Array(attributes[:forwards]).dup
        @mutex = Mutex.new
      end

      # Returns a snapshot copy of recorded forward attempts.
      #
      # @return [Array<ForwardResult>]
      def forwards
        @mutex.synchronize { @forwards.dup }
      end

      # Appends a forward result to this request in a thread-safe manner.
      #
      # @param result [ForwardResult] the forward attempt result
      # @return [ForwardResult]
      def record_forward(result)
        @mutex.synchronize { @forwards << result }
        result
      end

      # Returns the Base64-encoded representation of the raw body bytes.
      #
      # @return [String]
      def body_base64
        Base64.strict_encode64(@body)
      end

      # Returns the UTF-8 text of the body if valid UTF-8, or nil for non-UTF-8 binary data.
      #
      # @return [String, nil]
      def body_text
        utf8 = @body.dup.force_encoding(Encoding::UTF_8)
        utf8.valid_encoding? ? utf8 : nil
      end

      # Serializes this request into a JSON-ready Hash.
      #
      # @return [Hash{String => Object}]
      def to_h
        base_h.merge(
          "body_base64" => body_base64,
          "body_text" => body_text,
          "forwards" => forwards.map(&:to_h)
        )
      end

      private

      def assign_payload(attributes)
        @headers = freeze_headers(attributes[:headers])
        @body = attributes[:body].to_s.b.freeze
        @received_at = attributes[:received_at].to_i
      end

      def frozen_text(value)
        value.to_s.dup.freeze
      end

      def freeze_headers(headers)
        Array(headers).map { |name, value| [frozen_text(name), frozen_text(value)].freeze }.freeze
      end

      def base_h
        {
          "id" => @id, "inbox" => @inbox, "method" => @method,
          "path" => @path, "query" => @query, "headers" => @headers,
          "received_at" => @received_at
        }
      end
    end
  end
end
