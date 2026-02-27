# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module ExtendableRails
  module ErrorReporting
    module Notifiers
      # Posts error events to a Slack channel via an Incoming Webhook.
      #
      #   ExtendableRails.configure do |c|
      #     c.add_error_notifier(
      #       ExtendableRails::ErrorReporting::Notifiers::Slack.new(
      #         webhook_url: ENV["SLACK_WEBHOOK_URL"],
      #         channel:     "#alerts",
      #         username:    "extendable-rails",
      #         threshold:   :warning
      #       )
      #     )
      #   end
      class Slack < Base
        COLORS = {
          normal:   "#36a64f",   # green
          warning:  "#ffcc00",   # yellow
          high:     "#ff9900",   # orange
          critical: "#ff0000"    # red
        }.freeze

        def initialize(webhook_url:, channel: nil, username: "extendable-rails", **opts)
          super(**opts)
          @webhook_url = webhook_url
          @channel     = channel
          @username    = username
        end

        def deliver(event)
          payload = build_payload(event)
          post_json(@webhook_url, payload)
        end

        private

        def build_payload(event)
          attachment = {
            color:  COLORS.fetch(event.severity, "#cccccc"),
            title:  event.summary,
            text:   truncate(event.message, max: 1000),
            fields: build_fields(event),
            footer: "extendable-rails • #{event.fingerprint}",
            ts:     event.timestamp.to_i
          }

          payload = {
            username:    @username,
            attachments: [attachment]
          }
          payload[:channel] = @channel if @channel
          payload
        end

        def build_fields(event)
          fields = [
            { title: "Severity",  value: event.severity_label,        short: true },
            { title: "Exception", value: event.exception_class || "—", short: true }
          ]
          fields << { title: "Source", value: event.source, short: true } if event.source

          unless event.context.empty?
            ctx = event.context.map { |k, v| "*#{k}*: #{truncate(v.inspect, max: 80)}" }.join("\n")
            fields << { title: "Context", value: ctx, short: false }
          end

          unless event.backtrace.empty?
            fields << {
              title: "Backtrace",
              value: "```\n#{format_backtrace(event, lines: 8)}\n```",
              short: false
            }
          end

          fields
        end

        def post_json(url, body)
          uri  = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl      = (uri.scheme == "https")
          http.open_timeout  = 5
          http.read_timeout  = 5

          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)

          response = http.request(request)
          unless response.is_a?(Net::HTTPSuccess)
            raise "Slack webhook returned HTTP #{response.code}: #{response.body}"
          end

          response
        end
      end
    end
  end
end
