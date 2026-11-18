# frozen_string_literal: true

require "erb"

module Trysac
  module WebhookInbox
    # Renders HTML views using standard library ERB with strict HTML escaping of every dynamic value.
    module Views
      # ERB template for the root index listing active inboxes and recent requests.
      INDEX_TEMPLATE = ERB.new(<<~HTML, trim_mode: "-")
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Webhook Inbox</title>
        </head>
        <body>
          <h1>Webhook Inbox</h1>
          <section id="inboxes">
            <h2>Inboxes</h2>
            <% if inboxes.empty? -%>
              <p>No requests captured yet.</p>
            <% else -%>
              <ul>
                <% inboxes.each do |name| -%>
                  <li><a href="/inboxes/<%= h(name) %>"><%= h(name) %></a></li>
                <% end -%>
              </ul>
            <% end -%>
          </section>
          <section id="requests">
            <h2>Recent Requests</h2>
            <%= render_request_list(requests) %>
          </section>
        </body>
        </html>
      HTML

      # ERB template for a single inbox view.
      INBOX_TEMPLATE = ERB.new(<<~HTML, trim_mode: "-")
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Inbox: <%= h(inbox) %></title>
        </head>
        <body>
          <h1>Inbox: <%= h(inbox) %></h1>
          <%= render_request_list(requests) %>
        </body>
        </html>
      HTML

      # ERB template for a table/list of captured requests.
      LIST_TEMPLATE = ERB.new(<<~HTML, trim_mode: "-")
        <% if requests.empty? -%>
          <p>No requests in this inbox.</p>
        <% else -%>
          <ul>
            <% requests.each do |req| -%>
              <li data-id="<%= h(req.id) %>">
                <strong><%= h(req.id) %></strong>
                <span><%= h(req.method) %></span>
                <span><%= h(req.path) %></span>
                <dl>
                  <% req.headers.each do |k, v| -%>
                    <dt><%= h(k) %></dt>
                    <dd><%= h(v) %></dd>
                  <% end -%>
                </dl>
                <pre><%= h(req.body_text || req.body_base64) %></pre>
              </li>
            <% end -%>
          </ul>
        <% end -%>
      HTML

      # Escapes a value for safe inclusion in HTML content or attributes.
      #
      # @param value [Object] value to escape
      # @return [String] HTML-escaped string
      def self.h(value)
        ERB::Util.html_escape(value.to_s)
      end

      # Renders the root HTML page.
      #
      # @param inboxes [Array<String>] list of active inbox names
      # @param requests [Array<CapturedRequest>] recent requests
      # @return [String] rendered HTML document
      def self.render_index(inboxes:, requests:)
        INDEX_TEMPLATE.result_with_hash(
          inboxes: inboxes,
          requests: requests,
          h: method(:h),
          render_request_list: method(:render_request_list)
        )
      rescue NameError
        bind_and_render(INDEX_TEMPLATE, inboxes: inboxes, requests: requests)
      end

      # Renders the HTML page for a specific inbox.
      #
      # @param inbox [String] inbox name
      # @param requests [Array<CapturedRequest>] requests in that inbox
      # @return [String] rendered HTML document
      def self.render_inbox(inbox:, requests:)
        bind_and_render(INBOX_TEMPLATE, inbox: inbox, requests: requests)
      end

      # Renders the HTML fragment listing captured requests.
      #
      # @param requests [Array<CapturedRequest>] requests to display
      # @return [String] rendered HTML fragment
      def self.render_request_list(requests)
        bind_and_render(LIST_TEMPLATE, requests: requests)
      end

      # Helper context object providing `h` and `render_request_list` to ERB templates.
      class RenderContext
        # @return [String, nil] inbox name
        attr_reader :inbox

        # @return [Array<String>] inbox names
        attr_reader :inboxes

        # @return [Array<CapturedRequest>] captured requests
        attr_reader :requests

        # @param inbox [String, nil]
        # @param inboxes [Array<String>]
        # @param requests [Array<CapturedRequest>]
        def initialize(inbox: nil, inboxes: [], requests: [])
          @inbox = inbox
          @inboxes = inboxes
          @requests = requests
        end

        # Escapes a string for HTML.
        #
        # @param val [Object]
        # @return [String]
        def h(val)
          ERB::Util.html_escape(val.to_s)
        end

        # Renders the nested request list.
        #
        # @param reqs [Array<CapturedRequest>]
        # @return [String]
        def render_request_list(reqs)
          Views.render_request_list(reqs)
        end

        # Exposes the kernel binding for ERB evaluation.
        #
        # @return [Binding]
        def context_binding
          binding
        end
      end

      def self.bind_and_render(template, **locals)
        ctx = RenderContext.new(**locals)
        template.result(ctx.context_binding)
      end

      private_class_method :bind_and_render
    end
  end
end
