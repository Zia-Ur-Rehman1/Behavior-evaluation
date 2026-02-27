# frozen_string_literal: true

module ExtendableRails
  module ErrorReporting
    # Central reporter that fans out an ErrorEvent to all registered notifiers.
    #
    # One instance lives on the global configuration and is exposed via
    # +ExtendableRails.error_reporter+. Thread-safe for concurrent reports.
    #
    # Typical usage:
    #
    #   # Register notifiers once (e.g. in an initializer)
    #   ExtendableRails.configure do |c|
    #     c.add_error_notifier Notifiers::Logger.new
    #     c.add_error_notifier Notifiers::Slack.new(webhook_url: ENV["SLACK_URL"],
    #                                               threshold: :high)
    #   end
    #
    #   # Report an exception
    #   begin
    #     risky_operation!
    #   rescue => e
    #     ExtendableRails.report_error(e, severity: :high,
    #                                      context: { user_id: current_user.id })
    #   end
    #
    #   # Or wrap a block – re-raises by default so control flow is preserved
    #   ExtendableRails.capture(severity: :warning, source: "Jobs::Nightly") do
    #     do_work
    #   end
    class Reporter
      def initialize
        @notifiers = []
        @mutex     = Mutex.new
      end

      # ------------------------------------------------------------------
      # Notifier registry
      # ------------------------------------------------------------------

      # @param notifier [Notifiers::Base] anything responding to #notify(event)
      def add(notifier)
        unless notifier.respond_to?(:notify)
          raise ArgumentError, "notifier must respond to #notify(event)"
        end

        @mutex.synchronize { @notifiers << notifier }
        self
      end

      def notifiers
        @mutex.synchronize { @notifiers.dup }
      end

      def clear!
        @mutex.synchronize { @notifiers.clear }
      end

      # ------------------------------------------------------------------
      # Reporting API
      # ------------------------------------------------------------------

      # Report an error (exception or string). Returns the ErrorEvent.
      #
      # @param error    [Exception, String] what went wrong
      # @param severity [Symbol]            Severity level (default :normal)
      # @param context  [Hash]              extra metadata
      # @param source   [String, nil]       logical origin
      # @param message  [String, nil]       explicit message (overrides error.message)
      def report(error, severity: :normal, context: {}, source: nil, message: nil)
        event =
          if error.is_a?(Exception)
            ErrorEvent.new(exception: error, message: message, severity: severity,
                           context: context, source: source)
          else
            ErrorEvent.new(message: error.to_s, severity: severity,
                           context: context, source: source)
          end

        dispatch(event)
        event
      end

      # Run a block, capture any exception, and report it.
      #
      # @param severity [Symbol]   severity to assign if an error is raised
      # @param context  [Hash]     metadata attached to the event
      # @param source   [String]   logical origin label
      # @param reraise  [Boolean]  re-raise the captured exception (default true)
      # @param swallow  [Array<Class>] exception classes to suppress instead of re-raising
      # @return whatever the block returns on success; nil if swallowed
      def capture(severity: :high, context: {}, source: nil, reraise: true, swallow: [])
        yield
      rescue *Array(swallow) => e
        report(e, severity: severity, context: context, source: source)
        nil
      rescue StandardError => e
        report(e, severity: severity, context: context, source: source)
        raise if reraise
        nil
      end

      # ------------------------------------------------------------------
      # Convenience helpers for each severity level
      # ------------------------------------------------------------------

      def normal(error, **opts)
        report(error, severity: :normal, **opts)
      end

      def warning(error, **opts)
        report(error, severity: :warning, **opts)
      end

      def high(error, **opts)
        report(error, severity: :high, **opts)
      end

      def critical(error, **opts)
        report(error, severity: :critical, **opts)
      end

      private

      def dispatch(event)
        # Snapshot to avoid holding the mutex while delivering.
        notifiers.each { |n| n.notify(event) }
      end
    end
  end
end
