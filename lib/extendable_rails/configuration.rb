# frozen_string_literal: true

module ExtendableRails
  class Configuration
    attr_accessor :mcp_auth_strategy    # :none, :api_key, :oauth
    attr_accessor :mcp_api_key          # String or Proc
    attr_accessor :oauth_token_url      # URL for OAuth token introspection
    attr_accessor :oauth_public_key     # For local JWT verification (optional)
    attr_accessor :llm_providers        # Array of provider config hashes
    attr_accessor :context_limits       # Hash of model-prefix => token limit overrides
    attr_reader   :error_reporter       # ErrorReporting::Reporter instance

    def initialize
      @mcp_auth_strategy = :none
      @mcp_api_key       = nil
      @oauth_token_url   = nil
      @oauth_public_key  = nil
      @llm_providers     = []
      @context_limits    = {}
      @error_reporter    = ErrorReporting::Reporter.new
    end

    # DSL method for adding LLM providers in priority order.
    #
    #   config.add_llm_provider(
    #     name:     :anthropic,
    #     api_key:  ENV["ANTHROPIC_API_KEY"],
    #     model:    "claude-sonnet-4-20250514",
    #     base_url: "https://api.anthropic.com/v1/messages"   # optional
    #   )
    def add_llm_provider(name:, api_key:, model:, base_url: nil, max_failures: 3, cooldown: 60)
      @llm_providers << {
        name:         name.to_sym,
        api_key:      api_key,
        model:        model,
        base_url:     base_url,
        max_failures: max_failures,
        cooldown:     cooldown
      }
    end

    # Register an error notifier.
    #
    # Pass an instance of +ErrorReporting::Notifiers::Base+ (or any object
    # that responds to #notify), or pass a symbol shortcut:
    #
    #   config.add_error_notifier :slack, webhook_url: ENV["SLACK_URL"], threshold: :warning
    #   config.add_error_notifier :email, to: "ops@example.com", threshold: :high
    #   config.add_error_notifier :logger
    #   config.add_error_notifier MyCustomNotifier.new(...)
    def add_error_notifier(notifier_or_type, **opts)
      notifier =
        case notifier_or_type
        when :slack
          ErrorReporting::Notifiers::Slack.new(**opts)
        when :email
          ErrorReporting::Notifiers::Email.new(**opts)
        when :logger
          ErrorReporting::Notifiers::Logger.new(**opts)
        else
          notifier_or_type
        end

      @error_reporter.add(notifier)
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # ------------------------------------------------------------------
    # Error reporting convenience delegates
    # ------------------------------------------------------------------

    def error_reporter
      configuration.error_reporter
    end

    # Report an error. Accepts an Exception or a String.
    #
    #   ExtendableRails.report_error(e, severity: :critical,
    #                                   context: { job: "NightlySync" })
    def report_error(error, **opts)
      error_reporter.report(error, **opts)
    end

    # Wrap a block; captured exceptions are reported and (by default) re-raised.
    #
    #   ExtendableRails.capture(severity: :high, source: "Payments#charge") do
    #     gateway.charge!(...)
    #   end
    def capture(**opts, &block)
      error_reporter.capture(**opts, &block)
    end
  end
end
