# frozen_string_literal: true

require "securerandom"
require "time"

module ExtendableRails
  module ErrorReporting
    # Immutable value object that wraps an exception (or a plain message)
    # with severity, contextual metadata, and a fingerprint used for
    # deduplication downstream.
    #
    # Notifiers receive instances of this class and never raw exceptions.
    class ErrorEvent
      attr_reader :id, :severity, :exception, :message, :context,
                  :backtrace, :timestamp, :source

      # @param exception [Exception, nil] the raised exception (optional)
      # @param message   [String, nil]   human-readable message; falls back to exception.message
      # @param severity  [Symbol]        one of Severity::LEVELS
      # @param context   [Hash]          arbitrary metadata (user_id, request_id, params, …)
      # @param source    [String, nil]   logical origin (e.g. "ProviderManager#chat", "MCP::Auth")
      def initialize(exception: nil, message: nil, severity: :normal, context: {}, source: nil)
        @id        = SecureRandom.uuid
        @severity  = Severity.coerce(severity)
        @exception = exception
        @message   = (message || exception&.message || "(no message)").to_s
        @context   = context.freeze
        @backtrace = Array(exception&.backtrace)
        @timestamp = Time.now.utc
        @source    = source
      end

      def exception_class
        @exception&.class&.name
      end

      def severity_label
        Severity.label(@severity)
      end

      def severity_description
        Severity.description(@severity)
      end

      # Stable fingerprint for grouping identical errors.
      # Combines exception class, source, and the first backtrace frame.
      def fingerprint
        @fingerprint ||= begin
          parts = [exception_class, @source, @backtrace.first].compact
          parts.empty? ? @message.hash.to_s(16) : parts.join("|")
        end
      end

      # Serialisable hash for notifiers, loggers, and JSON APIs.
      def to_h
        {
          id:              @id,
          severity:        @severity,
          severity_label:  severity_label,
          message:         @message,
          exception_class: exception_class,
          source:          @source,
          context:         @context,
          backtrace:       @backtrace.first(50),
          timestamp:       @timestamp.iso8601,
          fingerprint:     fingerprint
        }
      end

      # Short one-line summary suitable for log lines and chat subjects.
      def summary
        prefix  = "[#{severity_label}]"
        klass   = exception_class ? " #{exception_class}:" : ""
        origin  = @source ? " (#{@source})" : ""
        "#{prefix}#{klass} #{@message}#{origin}"
      end
    end
  end
end
