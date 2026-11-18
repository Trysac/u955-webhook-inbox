# frozen_string_literal: true

require "base64"
require "openssl"

module Trysac
  module WebhookInbox
    # Implements the Standard Webhooks v1 HMAC-SHA256 signing and verification specification.
    module Signer
      # Prefix required on Standard Webhooks base64 secrets.
      SECRET_PREFIX = "whsec_"

      # Default timestamp tolerance in seconds (5 minutes).
      DEFAULT_TOLERANCE = 300

      # Maximum body size accepted by Signer operations (10 MiB).
      MAX_BODY_BYTES = 10 * 1_048_576

      # Signs a webhook payload according to Standard Webhooks v1.
      #
      # @param secret [String] secret starting with `whsec_` followed by strict base64
      # @param id [String] unique message identifier (`webhook-id`)
      # @param timestamp [Integer, String] Unix epoch seconds (`webhook-timestamp`)
      # @param body [String] raw payload bytes
      # @return [String] signature header value formatted as `"v1,<base64>"`
      # @raise [Error] with `:invalid_secret` if the secret is malformed
      def self.sign(secret:, id:, timestamp:, body:)
        key = decode_secret!(secret)
        validate_sign_params!(id, body)
        compute_signature(key, id, timestamp.to_s, body)
      end

      # Verifies Standard Webhooks headers (`webhook-id`, `webhook-timestamp`, `webhook-signature`)
      # against the raw payload and current time.
      #
      # @param secret [String] secret starting with `whsec_` followed by strict base64
      # @param headers [Hash, Array<Array(String, String)>] request headers (case-insensitive lookup)
      # @param body [String] raw request body bytes
      # @param now [Integer, Time] current timestamp for replay check
      # @param tolerance [Integer] maximum allowed age/skew in seconds (default 300)
      # @return [ true ] when verification succeeds
      # @raise [Error] with `:invalid_secret`, `:timestamp_out_of_tolerance`, or `:invalid_signature`
      def self.verify(secret:, headers:, body:, now: Time.now.to_i, tolerance: DEFAULT_TOLERANCE)
        decode_secret!(secret)
        validate_body_size!(body)
        id, ts, sig = extract_required_headers!(headers)
        ts_int = parse_timestamp!(ts)
        verify_tolerance!(ts_int, now.to_i, tolerance)
        verify_signatures(secret, id, ts_int, body, sig)
      end

      # Decodes a `whsec_` secret into raw key bytes.
      #
      # @param secret [String] the secret to decode
      # @return [String] raw decoded key bytes
      # @raise [Error] with `:invalid_secret` if invalid
      def self.decode_secret!(secret)
        unless secret.is_a?(String) && secret.start_with?(SECRET_PREFIX)
          raise Error.new(:invalid_secret, "Secret must start with whsec_")
        end

        encoded = secret.delete_prefix(SECRET_PREFIX)
        raise Error.new(:invalid_secret, "Secret key material must not be empty") if encoded.empty?

        decoded = Base64.strict_decode64(encoded)
        raise Error.new(:invalid_secret, "Secret key material must not be empty") if decoded.empty?

        decoded
      rescue ArgumentError
        raise Error.new(:invalid_secret, "Secret contains invalid base64")
      end

      # Extracts a header value case-insensitively from a Hash or pair Array.
      #
      # @param headers [Hash, Array<Array(String, String)>] headers collection
      # @param target [String] lower-case header name
      # @return [String, nil]
      def self.extract_header(headers, target)
        down = target.downcase
        return find_in_hash(headers, down) if headers.is_a?(Hash)
        return find_in_pairs(headers, down) if headers.respond_to?(:each)

        nil
      end

      # Parses an integer timestamp string.
      #
      # @param ts_str [String] timestamp header value
      # @return [Integer]
      # @raise [Error] with `:invalid_signature` when not a valid integer string
      def self.parse_timestamp!(ts_str)
        raise Error.new(:invalid_signature, "Invalid timestamp format") unless /\A-?\d+\z/.match?(ts_str.to_s)

        Integer(ts_str, 10)
      end

      def self.validate_sign_params!(id, body)
        raise Error.new(:invalid_signature, "id must be a non-empty String") if !id.is_a?(String) || id.empty?

        validate_body_size!(body)
      end

      def self.validate_body_size!(body)
        return if body.is_a?(String) && body.bytesize <= MAX_BODY_BYTES

        raise Error.new(:payload_too_large, "body exceeds limit")
      end

      def self.compute_signature(key, id, ts_str, body)
        to_sign = "".b << id.b << ".".b << ts_str.b << ".".b << body.b
        mac = OpenSSL::HMAC.digest("SHA256", key, to_sign)
        "v1,#{Base64.strict_encode64(mac)}"
      end

      def self.extract_required_headers!(headers)
        id = extract_header(headers, "webhook-id")
        ts = extract_header(headers, "webhook-timestamp")
        sig = extract_header(headers, "webhook-signature")
        if id.nil? || id.empty? || ts.nil? || ts.empty? || sig.nil? || sig.empty?
          raise Error.new(:invalid_signature, "Missing required webhook signature headers")
        end

        [id, ts, sig]
      end

      def self.verify_tolerance!(ts_int, now_int, tolerance)
        return if (now_int - ts_int).abs <= tolerance

        raise Error.new(:timestamp_out_of_tolerance, "Webhook timestamp is outside tolerance window")
      end

      def self.verify_signatures(secret, id, ts_int, body, sig_header)
        expected = sign(secret: secret, id: id, timestamp: ts_int, body: body)
        exp_bytes = Base64.strict_decode64(expected.delete_prefix("v1,"))

        sig_header.split.any? { |part| match_token?(part, exp_bytes) } ||
          raise(Error.new(:invalid_signature, "No matching v1 signature found"))
      end

      def self.match_token?(part, exp_bytes)
        ver, b64 = part.split(",", 2)
        return false unless ver == "v1" && b64 && !b64.empty?

        cand = decode_b64(b64)
        return false if cand.nil? || cand.bytesize != exp_bytes.bytesize

        OpenSSL.fixed_length_secure_compare(exp_bytes, cand)
      end

      def self.decode_b64(str)
        Base64.strict_decode64(str)
      rescue ArgumentError
        nil
      end

      def self.find_in_hash(hash, down)
        hash.each { |k, v| return v.to_s if k.to_s.downcase == down }
        nil
      end

      def self.find_in_pairs(pairs, down)
        pairs.each do |pair|
          next unless pair.is_a?(Array) && pair.length >= 2

          return pair[1].to_s if pair[0].to_s.downcase == down
        end
        nil
      end

      private_class_method :decode_secret!, :extract_header, :parse_timestamp!,
                           :validate_sign_params!, :validate_body_size!,
                           :compute_signature, :extract_required_headers!,
                           :verify_tolerance!, :verify_signatures,
                           :match_token?, :decode_b64, :find_in_hash, :find_in_pairs
    end
  end
end
