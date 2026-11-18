# frozen_string_literal: true

require "json"

module Trysac
  module WebhookInbox
    # Builds the Rack response triplets returned by {App}.
    module Responses
      # HTTP status for each {Error} code that does not map to 400 Bad Request.
      STATUS_BY_CODE = {
        payload_too_large: 413,
        target_not_allowed: 403,
        not_found: 404,
        forward_failed: 502
      }.freeze

      # Security header sent on every response.
      NOSNIFF = { "x-content-type-options" => "nosniff" }.freeze

      module_function

      # Builds a JSON response.
      #
      # @param status [Integer] HTTP status code
      # @param data [Hash] JSON-serializable payload
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def json(status, data)
        typed(status, "application/json; charset=utf-8", JSON.generate(data))
      end

      # Builds an HTML response.
      #
      # @param status [Integer] HTTP status code
      # @param html [String] rendered HTML document
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def html(status, html)
        typed(status, "text/html; charset=utf-8", html)
      end

      # Builds a response without a body, such as 204 No Content.
      #
      # @param status [Integer] HTTP status code
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def empty(status)
        [status, NOSNIFF.dup, []]
      end

      # Builds the JSON error response for an {Error}, mapping its code to an HTTP status.
      #
      # @param err [Error] the error raised while handling the request
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def error(err)
        json(STATUS_BY_CODE.fetch(err.code, 400), { "code" => err.code.to_s, "error" => err.message })
      end

      # Builds a response with a typed body and its exact byte length.
      #
      # @param status [Integer] HTTP status code
      # @param content_type [String] value of the `content-type` header
      # @param body [String] response body
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def typed(status, content_type, body)
        headers = { "content-type" => content_type, "content-length" => body.bytesize.to_s }.merge(NOSNIFF)
        [status, headers, [body]]
      end
    end
  end
end
