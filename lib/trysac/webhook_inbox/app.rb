# frozen_string_literal: true

require "json"

module Trysac
  module WebhookInbox
    # Rack 3 application that captures incoming webhooks, serves an HTML inspection UI
    # and JSON API, and forwards stored requests with Standard Webhooks signatures.
    class App
      # Default maximum request body size in bytes (1 MiB).
      DEFAULT_MAX_BODY_BYTES = 1_048_576

      # HTTP methods accepted on `/hooks/:inbox`.
      CAPTURE_METHODS = %w[POST PUT PATCH DELETE].freeze

      # @return [Store] request store
      attr_reader :store

      # @return [Forwarder] webhook forwarder
      attr_reader :forwarder

      # @return [Integer] maximum allowed body size in bytes
      attr_reader :max_body_bytes

      # Initializes a new Rack App instance.
      #
      # @param store [Store] bounded request store
      # @param forwarder [Forwarder] request forwarder
      # @param ids [#call] ID generator callable (defaults to {IdGenerator.new})
      # @param options [Hash] optional tuning knobs
      # @option options [#call] :clock clock callable returning epoch seconds (defaults to `-> { Time.now.to_i }`)
      # @option options [Integer] :max_body_bytes maximum request body size in bytes (default 1,048,576)
      # @option options [#call, nil] :on_event optional instrumentation callback receiving metadata-only hashes
      def initialize(store: Store.new, forwarder: nil, ids: IdGenerator.new, **options)
        @store = store
        @forwarder = forwarder
        @ids = ids
        @clock = options[:clock] || -> { Time.now.to_i }
        @max_body_bytes = options[:max_body_bytes] || DEFAULT_MAX_BODY_BYTES
        @on_event = options[:on_event]
        @router = Router.new(inbox_routes + request_routes)
      end

      # Rack 3 entry point (`call(env) -> [status, headers, body]`).
      #
      # @param env [Hash] Rack environment hash
      # @return [Array(Integer, Hash{String => String}, Array<String>)] Rack response triplet
      def call(env)
        method = env["REQUEST_METHOD"].to_s.upcase
        path = env["PATH_INFO"].to_s
        path = "/" if path.empty?

        @router.dispatch(method, path, env) ||
          Responses.json(404, { "code" => "not_found", "error" => "Route not found" })
      rescue Error => e
        Responses.error(e)
      end

      private

      def inbox_routes
        [
          [%w[GET], %r{\A/\z}, ->(_param, _req) { handle_root }],
          [CAPTURE_METHODS, %r{\A/*hooks/([^/]*)\z}, ->(inbox, req) { handle_capture(inbox, req) }],
          [%w[GET], %r{\A/*inboxes/([^/]*)\z}, ->(inbox, _req) { handle_html_inbox(inbox) }],
          [%w[GET], %r{\A/*api/inboxes/([^/]*)/requests\z}, ->(inbox, _req) { handle_api_inbox_requests(inbox) }],
          [%w[DELETE], %r{\A/*api/inboxes/([^/]*)\z}, ->(inbox, _req) { handle_api_delete_inbox(inbox) }]
        ]
      end

      def request_routes
        [
          [%w[GET], %r{\A/*api/requests/([^/]*)\z}, ->(id, _req) { handle_api_get_request(id) }],
          [%w[POST], %r{\A/*api/requests/([^/]*)/forward\z}, ->(id, req) { handle_api_forward_request(id, req.env) }]
        ]
      end

      def handle_root
        Responses.html(200, Views.render_index(inboxes: @store.inboxes, requests: @store.all))
      end

      def handle_html_inbox(inbox)
        Store.validate_inbox!(inbox)
        Responses.html(200, Views.render_inbox(inbox: inbox, requests: @store.by_inbox(inbox)))
      end

      def handle_capture(inbox, request)
        Store.validate_inbox!(inbox)
        captured = capture(inbox, request)
        @store.add(captured)
        emit_event(type: :received, id: captured.id, inbox: inbox, size: captured.body.bytesize)
        Responses.json(202, { "id" => captured.id })
      end

      def capture(inbox, request)
        env = request.env
        body = RackInput.read_bounded_body!(env, @max_body_bytes)
        CapturedRequest.new(
          id: @ids.call, inbox: inbox, method: request.http_method, path: request.path,
          query: env["QUERY_STRING"].to_s, headers: RackInput.headers_in_order(env),
          body: body, received_at: @clock.call.to_i
        )
      end

      def handle_api_inbox_requests(inbox)
        Responses.json(200, { "requests" => @store.by_inbox(inbox).map(&:to_h) })
      end

      def handle_api_delete_inbox(inbox)
        deleted = @store.delete_inbox(inbox)
        emit_event(type: :inbox_cleared, inbox: inbox, count: deleted)
        Responses.empty(204)
      end

      def handle_api_get_request(id)
        Responses.json(200, find_request!(id).to_h)
      end

      def handle_api_forward_request(id, env)
        req = find_request!(id)
        raise Error.new(:forward_failed, "No forwarder configured") if @forwarder.nil?

        result = @forwarder.forward(req, forward_target!(env))
        emit_forwarded(req, result)
        return Responses.json(200, result.to_h) unless result.error_code

        Responses.json(502, { "code" => result.error_code.to_s, "forward" => result.to_h })
      end

      def find_request!(id)
        @store.find(id) || raise(Error.new(:not_found, "Request not found"))
      end

      def forward_target!(env)
        payload = RackInput.read_json!(env, @max_body_bytes)
        return payload["url"] if payload.is_a?(Hash) && payload["url"].is_a?(String)

        raise Error.new(:invalid_url, "JSON body must contain a string 'url' field")
      end

      def emit_forwarded(req, result)
        emit_event(type: :forwarded, id: req.id, inbox: req.inbox, status: result.status, error_code: result.error_code)
      end

      def emit_event(payload)
        @on_event&.call(payload)
      end
    end
  end
end
