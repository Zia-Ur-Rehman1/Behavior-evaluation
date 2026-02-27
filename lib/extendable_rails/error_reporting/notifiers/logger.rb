# frozen_string_literal: true

require "logger"

module ExtendableRails
  module ErrorReporting
    module Notifiers
      # Writes error events to a standard Logger.
      #
      # Maps event severity to log levels:
      #   :normal   => info
      #   :warning  => warn
      #   :high     => error
      #   :critical => fatal
      #
      # This notifier is always safe to include (no network I/O) and is a
      # sensible default in every environment.
      class Logger < Base
        LOG_METHODS = {
          normal:   :info,
          warning:  :warn,
          high:     :error,
          critical: :fatal
        }.freeze

        def initialize(logger: nil, **opts)
          super(**opts)
          @logger = logger || default_logger
        end

        def deliver(event)
          method = LOG_METHODS.fetch(event.severity, :error)
          @logger.public_send(method) do
            msg = event.summary
            msg += "\n" + format_backtrace(event, lines: 20) unless event.backtrace.empty?
            msg += "\nContext: #{event.context.inspect}" unless event.context.empty?
            msg
          end
        end

        private

        def default_logger
          if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
            Rails.logger
          else
            ::Logger.new($stderr)
          end
        end
      end
    end
  end
end
