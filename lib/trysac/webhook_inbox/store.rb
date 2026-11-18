# frozen_string_literal: true

module Trysac
  module WebhookInbox
    # Thread-safe bounded ring-buffer store for captured webhook requests.
    class Store
      # Default maximum number of requests stored across all inboxes.
      DEFAULT_MAX_REQUESTS = 1_000

      # Regular expression that valid inbox names must match.
      INBOX_PATTERN = /\A[a-z0-9-]{1,64}\z/

      # @return [Integer] maximum capacity of the store
      attr_reader :max_requests

      # Validates an inbox name against {INBOX_PATTERN}.
      #
      # @param inbox [String] candidate inbox name
      # @return [String] the validated inbox name
      # @raise [Error] with `:invalid_inbox` when invalid
      def self.validate_inbox!(inbox)
        raise Error.new(:invalid_inbox, "Invalid inbox name") unless inbox.is_a?(String) && INBOX_PATTERN.match?(inbox)

        inbox
      end

      # Creates a new bounded Store.
      #
      # @param max_requests [Integer] maximum number of requests to retain (default 1,000)
      # @raise [Error] if max_requests is not a positive Integer
      def initialize(max_requests: DEFAULT_MAX_REQUESTS)
        unless max_requests.is_a?(Integer) && max_requests.positive?
          raise Error.new(:invalid_inbox, "max_requests must be a positive Integer")
        end

        @max_requests = max_requests
        @mutex = Mutex.new
        @order = []
        @by_id = {}
      end

      # Appends a captured request to the store, evicting the oldest request if full.
      #
      # @param request [CapturedRequest] the request to store
      # @return [CapturedRequest] the stored request
      def add(request)
        Store.validate_inbox!(request.inbox)
        @mutex.synchronize { record_entry(request) }
        request
      end

      # Finds a request by its ID.
      #
      # @param id [String] message identifier
      # @return [CapturedRequest, nil]
      def find(id)
        @mutex.synchronize { @by_id[id] }
      end

      # Lists requests for a given inbox, ordered newest first.
      #
      # @param inbox [String] inbox name
      # @return [Array<CapturedRequest>]
      # @raise [Error] with `:invalid_inbox` if the inbox name is invalid
      def by_inbox(inbox)
        Store.validate_inbox!(inbox)
        @mutex.synchronize do
          result = []
          @order.reverse_each do |id|
            req = @by_id[id]
            result << req if req && req.inbox == inbox
          end
          result
        end
      end

      # Returns all stored requests, newest first.
      #
      # @return [Array<CapturedRequest>]
      def all
        @mutex.synchronize do
          @order.reverse.filter_map { |id| @by_id[id] }
        end
      end

      # Returns distinct inbox names currently holding requests, in alphabetical order.
      #
      # @return [Array<String>]
      def inboxes
        @mutex.synchronize do
          @by_id.values.map(&:inbox).uniq.sort
        end
      end

      # Deletes all stored requests belonging to the given inbox.
      #
      # @param inbox [String] inbox name
      # @return [Integer] count of deleted requests
      # @raise [Error] with `:invalid_inbox` if the inbox name is invalid
      def delete_inbox(inbox)
        Store.validate_inbox!(inbox)
        @mutex.synchronize do
          to_remove = @by_id.values.select { |r| r.inbox == inbox }.map(&:id)
          to_remove.each do |id|
            @by_id.delete(id)
            @order.delete(id)
          end
          to_remove.length
        end
      end

      # Returns the total number of stored requests.
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @order.length }
      end

      private

      def record_entry(request)
        if @by_id.key?(request.id)
          @order.delete(request.id)
        elsif @order.length >= @max_requests
          evict_oldest
        end
        @order << request.id
        @by_id[request.id] = request
      end

      def evict_oldest
        oldest_id = @order.shift
        @by_id.delete(oldest_id) if oldest_id
      end
    end
  end
end
