# frozen_string_literal: true

require "json"

module Trysac
  module WebhookInbox
    # Reads the request body and headers out of a Rack environment without losing bytes or order.
    module RackInput
      # Rack environment keys excluded when reconstructing HTTP headers.
      EXCLUDED_HTTP_ENV_KEYS = %w[HTTP_HOST HTTP_VERSION].freeze

      # Rack environment keys that carry headers without the `HTTP_` prefix.
      PLAIN_HEADER_KEYS = { "CONTENT_TYPE" => "content-type", "CONTENT_LENGTH" => "content-length" }.freeze

      module_function

      # Reads at most `max_bytes` from `rack.input` as binary data.
      #
      # @param env [Hash] Rack environment hash
      # @param max_bytes [Integer] maximum accepted body size in bytes
      # @return [String] binary (ASCII-8BIT) body, empty when there is no input
      # @raise [Error] with `:payload_too_large` when the body is larger than `max_bytes`
      def read_bounded_body!(env, max_bytes)
        chunk = env["rack.input"]&.read(max_bytes + 1)
        data = chunk.nil? ? String.new(encoding: Encoding::BINARY) : chunk.b
        raise Error.new(:payload_too_large, "Request body exceeds #{max_bytes} bytes") if data.bytesize > max_bytes

        data
      end

      # Reads the bounded request body and parses it as JSON.
      #
      # @param env [Hash] Rack environment hash
      # @param max_bytes [Integer] maximum accepted body size in bytes
      # @return [Object] the parsed JSON value
      # @raise [Error] with `:payload_too_large` for an oversized body or `:invalid_url` for invalid JSON
      def read_json!(env, max_bytes)
        JSON.parse(read_bounded_body!(env, max_bytes))
      rescue JSON::ParserError
        raise Error.new(:invalid_url, "Forward request body must be valid JSON")
      end

      # Rebuilds the request headers in the order the Rack environment lists them.
      #
      # @param env [Hash] Rack environment hash
      # @return [Array<Array(String, String)>] lower-case `[name, value]` pairs
      def headers_in_order(env)
        env.filter_map do |key, val|
          name = header_name(key.to_s)
          [name, val.to_s] if name && !val.nil?
        end
      end

      # Maps a Rack environment key to its lower-case HTTP header name.
      #
      # @param key [String] Rack environment key
      # @return [String, nil] the header name, or nil when the key is not a header
      def header_name(key)
        return PLAIN_HEADER_KEYS[key] if PLAIN_HEADER_KEYS.key?(key)
        return nil unless key.start_with?("HTTP_") && !EXCLUDED_HTTP_ENV_KEYS.include?(key)

        key.delete_prefix("HTTP_").tr("_", "-").downcase(:ascii)
      end
    end
  end
end
