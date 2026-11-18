# frozen_string_literal: true

require "socket"
require "openssl"
require "timeout"

module Trysac
  module WebhookInbox
    # Low-level HTTP/1.1 client over TCPSocket (and OpenSSL::SSL::SSLSocket for https)
    # that writes the exact header sequence and binary body bytes without normalization.
    class RawHttpClient
      # Maximum number of response header lines read from the upstream server.
      MAX_RESPONSE_HEADERS = 128

      # Maximum bytes per response header line.
      MAX_LINE_LENGTH = 8_192

      # Sends an HTTP/1.1 request and reads only the status line and response headers.
      #
      # @param options [Hash{Symbol => Object}] request parameters: scheme, host, port, method,
      #   request_target, headers, body, timeout
      # @return [Integer] the HTTP response status code
      # @raise [Error] with `:forward_failed` on socket, TLS, timeout, or parse failure
      def request(**options)
        payload = build_wire_payload(options)
        Timeout.timeout(options.fetch(:timeout, 10)) do
          execute_wire_request(options[:host], options[:port], options[:scheme], payload)
        end
      rescue Error
        raise
      rescue Timeout::Error, StandardError => e
        raise Error.new(:forward_failed, "Forward failed: #{e.class}")
      end

      private

      def execute_wire_request(host, port, scheme, payload)
        sock = TCPSocket.new(host, port)
        begin
          io = scheme == "https" ? wrap_tls(sock, host) : sock
          io.write(payload)
          io.flush
          read_status_and_headers(io)
        ensure
          close_socket(io)
          close_socket(sock)
        end
      end

      def close_socket(io)
        io&.close unless io&.closed?
      rescue IOError, SystemCallError
        nil
      end

      def wrap_tls(tcp_socket, host)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
        ssl = OpenSSL::SSL::SSLSocket.new(tcp_socket, ctx)
        ssl.hostname = host if ssl.respond_to?(:hostname=)
        ssl.sync_close = true
        ssl.connect
        ssl
      end

      def build_wire_payload(opts)
        raw_body = opts[:body].b
        buf = request_head(opts)
        append_headers!(buf, opts[:headers])
        buf << "Content-Length: #{raw_body.bytesize}\r\nConnection: close\r\n\r\n".b << raw_body
      end

      def request_head(opts)
        target = sanitize_target(opts[:request_target])
        host_hdr = host_header(opts)
        parts = [sanitize_token(opts[:method]), " ", sanitize_line(target), " HTTP/1.1\r\nHost: ",
                 sanitize_line(host_hdr), "\r\n"]
        parts.map(&:b).join
      end

      def sanitize_target(request_target)
        request_target.nil? || request_target.empty? ? "/" : request_target
      end

      def host_header(opts)
        format_host(opts[:host], opts[:port], opts[:scheme])
      end

      def format_host(host, port, scheme)
        default_port?(scheme, port) ? host : "#{host}:#{port}"
      end

      def append_headers!(buf, headers)
        headers.each do |name, value|
          buf << sanitize_token(name) << ": ".b << sanitize_line(value) << "\r\n".b
        end
      end

      def default_port?(scheme, port)
        (scheme == "http" && port == 80) || (scheme == "https" && port == 443)
      end

      def sanitize_token(str)
        s = str.to_s.b
        raise Error.new(:forward_failed, "Invalid header token") if s.empty? || s.match?(/[\r\n:\0]/)

        s
      end

      def sanitize_line(str)
        s = str.to_s.b
        raise Error.new(:forward_failed, "Invalid CR/LF in header value") if s.match?(/[\r\n\0]/)

        s
      end

      def read_status_and_headers(io)
        status_line = io.gets("\n", MAX_LINE_LENGTH)
        raise Error.new(:forward_failed, "Empty response from target") if status_line.nil?

        match = %r{\AHTTP/\d+\.\d+\s+(\d{3})(?:\s|\r|\n)}.match(status_line)
        raise Error.new(:forward_failed, "Malformed HTTP status line") unless match

        drain_headers(io)
        match[1].to_i
      end

      def drain_headers(io)
        lines = 0
        while (line = io.gets("\n", MAX_LINE_LENGTH))
          lines += 1
          break if line.strip.empty? || lines >= MAX_RESPONSE_HEADERS
        end
      end
    end
  end
end
