# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Matches an HTTP method and path against an ordered route table and calls the first matching handler.
    class Router
      # Request context handed to every route handler: the upper-case HTTP method, the path and the Rack env.
      Request = Data.define(:http_method, :path, :env)

      # Builds a router over an ordered route table.
      #
      # @param routes [Array<Array(Array<String>, Regexp, #call)>] `[methods, pattern, handler]` entries; each
      #   pattern captures one path parameter and each handler receives `(param, request)`
      def initialize(routes)
        @routes = routes.freeze
      end

      # Calls the handler of the first route whose method list and path pattern match.
      #
      # @param http_method [String] upper-case HTTP method
      # @param path [String] request path
      # @param env [Hash] Rack environment hash
      # @return [Object, nil] the handler's result, or nil when no route matches
      def dispatch(http_method, path, env)
        request = Request.new(http_method: http_method, path: path, env: env)
        @routes.each do |methods, pattern, handler|
          next unless methods.include?(http_method)

          match = pattern.match(path)
          return handler.call(match[1], request) if match
        end
        nil
      end
    end
  end
end
