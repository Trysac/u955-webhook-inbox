# frozen_string_literal: true

require "uri"

module Trysac
  module WebhookInbox
    # Replays a {CapturedRequest} to an allow-listed HTTP/HTTPS target URL with
    # exact body bytes, preserved header order, stripped hop-by-hop headers, and
    # Standard Webhooks v1 signature headers.
    class Forwarder
      # Hop-by-hop and framing headers dropped before forwarding (RFC 9110 section 7.6.1),
      # plus existing Standard Webhooks signature headers to prevent spoofing.
      DROPPED_HEADERS = %w[
        connection
        keep-alive
        proxy-authenticate
        proxy-authorization
        te
        trailer
        transfer-encoding
        upgrade
        host
        content-length
        webhook-id
        webhook-timestamp
        webhook-signature
      ].freeze

      # Allowed URL schemes for forwarding.
      ALLOWED_SCHEMES = %w[http https].freeze

      # Maximum URL length accepted.
      MAX_URL_LENGTH = 2_048

      # @return [Array<String>] exact host names or IP literals permitted as forward targets
      attr_reader :allowed_hosts

      # @return [Numeric] request timeout in seconds
      attr_reader :timeout

      # Initializes a new Forwarder.
      #
      # @param http [#request] HTTP client (defaults to {RawHttpClient.new})
      # @param signer_secret [String] `whsec_` base64 signing secret
      # @param allowed_hosts [Array<String>] exact allow-list of target hostnames/IPs
      # @param timeout [Numeric] socket timeout in seconds (default 10)
      # @param clock [#call] callable returning Unix epoch seconds (default `-> { Time.now.to_i }`)
      def initialize(signer_secret:, allowed_hosts:, http: RawHttpClient.new, timeout: 10, clock: -> { Time.now.to_i })
        # Validate secret upfront
        Signer.sign(secret: signer_secret, id: "msg_init", timestamp: 0, body: "")
        @http = http
        @signer_secret = signer_secret
        @allowed_hosts = Array(allowed_hosts).map(&:to_s).freeze
        @timeout = timeout
        @clock = clock
      end

      # Validates and forwards a captured request to the given target URL.
      # Records the {ForwardResult} on the request when an HTTP attempt is made.
      #
      # @param request [CapturedRequest] the captured webhook request
      # @param url [String] target URL (`http://` or `https://`)
      # @return [ForwardResult] the outcome of the forward operation
      # @raise [Error] with `:invalid_url` or `:target_not_allowed` if URL validation fails
      def forward(request, url)
        uri = parse_and_validate_url!(url)
        ts = @clock.call.to_i
        params = forward_params(request, uri, build_signed_headers(request, ts))
        result = execute_forward(params, url, ts)
        request.record_forward(result)
        result
      end

      private

      def build_signed_headers(request, timestamp)
        sig = Signer.sign(
          secret: @signer_secret,
          id: request.id,
          timestamp: timestamp,
          body: request.body
        )
        build_forwarded_headers(request.headers, request.id, timestamp, sig)
      end

      def target_path_and_query(uri)
        path = uri.path.nil? || uri.path.empty? ? "/" : uri.path
        uri.query && !uri.query.empty? ? "#{path}?#{uri.query}" : path
      end

      def forward_params(request, uri, headers)
        {
          scheme: uri.scheme, host: uri.host, port: uri.port,
          method: request.method, request_target: target_path_and_query(uri),
          headers: headers, body: request.body, timeout: @timeout
        }
      end

      def execute_forward(params, url, timestamp)
        status = @http.request(**params)
        ForwardResult.new(status: status, error_code: nil, url: url, forwarded_at: timestamp)
      rescue Error => e
        ForwardResult.new(status: nil, error_code: e.code, url: url, forwarded_at: timestamp)
      rescue StandardError
        ForwardResult.new(status: nil, error_code: :forward_failed, url: url, forwarded_at: timestamp)
      end

      def parse_and_validate_url!(url)
        check_url_type_and_length!(url)
        uri = parse_uri!(url)
        check_uri_scheme_and_host!(uri)
        check_allowed_host!(uri.host)
        uri
      end

      def check_url_type_and_length!(url)
        return if url.is_a?(String) && !url.empty? && url.bytesize <= MAX_URL_LENGTH

        raise Error.new(:invalid_url, "URL must be a non-empty String within size limit")
      end

      def parse_uri!(url)
        URI.parse(url)
      rescue URI::InvalidURIError
        raise Error.new(:invalid_url, "Malformed target URL")
      end

      def check_uri_scheme_and_host!(uri)
        valid = uri.is_a?(URI::HTTP) && ALLOWED_SCHEMES.include?(uri.scheme) && uri.host && !uri.host.empty?
        raise Error.new(:invalid_url, "URL scheme must be http or https with a valid host") unless valid
      end

      def check_allowed_host!(host)
        raise Error.new(:target_not_allowed, "Target host is not in allowed_hosts") unless @allowed_hosts.include?(host)
      end

      def build_forwarded_headers(original_headers, id, timestamp, signature)
        kept = []
        original_headers.each do |name, value|
          next if DROPPED_HEADERS.include?(name.to_s.downcase)

          kept << [name, value]
        end
        kept << ["webhook-id", id]
        kept << ["webhook-timestamp", timestamp.to_s]
        kept << ["webhook-signature", signature]
        kept
      end
    end
  end
end
