# frozen_string_literal: true

module ExtendableRails
  module ErrorReporting
    module Notifiers
      # Abstract base class for all error notifiers.
      #
      # Subclasses implement #deliver(event) and receive an ErrorEvent.
      # The base class provides:
      #   * threshold filtering   – skip events below a configured severity
      #   * safe dispatch         – a notifier that raises must never crash the app
      #   * shared helpers        – truncation, formatted backtrace, etc.
      #
      # To build a custom notifier for any third-party service, subclass this
      # class and implement +deliver+:
      #
      #   class PagerDutyNotifier < ExtendableRails::ErrorReporting::Notifiers::Base
      #     def initialize(routing_key:, **opts)
      #       super(**opts)
      #       @routing_key = routing_key
      #     end
      #
      #     def deliver(event)
      #       # POST event.to_h to PagerDuty Events API v2
      #     end
      #   end
      #
      # Then register it:
      #
      #   ExtendableRails.configure do |c|
      #     c.add_error_notifier PagerDutyNotifier.new(routing_key: ENV["PD_KEY"],
      #                                                 threshold: :high)
      #   end
      class Base
        attr_reader :threshold

        # @param threshold [Symbol] minimum severity this notifier handles
        def initialize(threshold: :normal)
          @threshold = Severity.coerce(threshold)
        end

        # Entry point called by the Reporter. Handles threshold filtering and
        # exception swallowing so a misbehaving notifier can't break the host
        # application. Subclasses should override #deliver, not #notify.
        def notify(event)
          return false unless handle?(event)

          deliver(event)
          true
        rescue StandardError => e
          warn "[ExtendableRails::ErrorReporting] #{self.class.name} failed to deliver: " \
               "#{e.class}: #{e.message}"
          false
        end

        # Override in subclasses. Receives an ErrorEvent.
        def deliver(_event)
          raise NotImplementedError, "#{self.class.name} must implement #deliver(event)"
        end

        # True when the event severity meets or exceeds this notifier's
        # threshold. Subclasses may extend this (e.g. rate-limit checks)
        # but should call +super+ first.
        def handle?(event)
          Severity.meets?(event.severity, threshold: @threshold)
        end

        protected

        # Truncate a string for chat-friendly payloads.
        def truncate(str, max: 500)
          s = str.to_s
          s.length > max ? "#{s[0, max - 1]}…" : s
        end

        # Returns the first +lines+ frames of the event backtrace joined by
        # newlines.
        def format_backtrace(event, lines: 10)
          event.backtrace.first(lines).join("\n")
        end
      end
    end
  end
end
