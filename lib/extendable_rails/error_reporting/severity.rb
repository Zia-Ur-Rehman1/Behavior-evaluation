# frozen_string_literal: true

module ExtendableRails
  module ErrorReporting
    # Severity levels for error events, ordered from lowest to highest.
    #
    #   :normal   – informational; operators may want visibility but no action
    #   :warning  – something unexpected happened but the system recovered
    #   :high     – a significant failure that degraded user experience
    #   :critical – the system is broken; page someone
    #
    # Exposes helpers for validation, comparison, and human-readable labels.
    module Severity
      LEVELS = %i[normal warning high critical].freeze

      LABELS = {
        normal:   "Normal",
        warning:  "Warning",
        high:     "High",
        critical: "Critical"
      }.freeze

      DESCRIPTIONS = {
        normal:   "Informational event – no action required",
        warning:  "Unexpected condition – system recovered automatically",
        high:     "Significant failure – user experience degraded",
        critical: "Critical failure – immediate attention required"
      }.freeze

      module_function

      # Coerces a value into a valid severity symbol.
      # Raises ArgumentError for unknown values.
      def coerce(value)
        sym = value.to_sym
        return sym if LEVELS.include?(sym)

        raise ArgumentError,
              "Unknown severity #{value.inspect}. Expected one of: #{LEVELS.join(', ')}"
      end

      # Returns the numeric rank (0 = normal, 3 = critical).
      # Useful for threshold comparisons.
      def rank(level)
        LEVELS.index(coerce(level))
      end

      # True when +level+ is at least as severe as +threshold+.
      #
      #   Severity.meets?(:high, threshold: :warning)   # => true
      #   Severity.meets?(:normal, threshold: :warning) # => false
      def meets?(level, threshold:)
        rank(level) >= rank(threshold)
      end

      def label(level)
        LABELS.fetch(coerce(level))
      end

      def description(level)
        DESCRIPTIONS.fetch(coerce(level))
      end
    end
  end
end
