# frozen_string_literal: true

module ExtendableRails
  module Mcp
    # Tracks token usage reported by an LLM response and exposes helpers
    # for rendering a "context remaining" UI component.
    #
    # Usage in a Rails controller concern or helper:
    #
    #   include ExtendableRails::Mcp::ContextWindow
    #
    #   # After a Provider#chat call:
    #   record_usage(response)
    #
    #   # In a view or helper:
    #   context_remaining_percent   # => 72.4
    #   context_remaining_tokens    # => 144_800
    #   context_limit_tokens        # => 200_000
    #
    # The module is provider-aware: it reads `usage` from Anthropic, OpenAI,
    # Gemini, and DeepSeek response shapes automatically.
    module ContextWindow
      # Well-known context window sizes keyed by model prefix.
      # Override via ExtendableRails.configure { |c| c.context_limits = { ... } }
      DEFAULT_LIMITS = {
        # Anthropic
        "claude-opus-4"         => 200_000,
        "claude-sonnet-4"       => 200_000,
        "claude-haiku-4"        => 200_000,
        "claude-3-5-sonnet"     => 200_000,
        "claude-3-5-haiku"      => 200_000,
        "claude-3-opus"         => 200_000,
        # OpenAI
        "gpt-4o"                => 128_000,
        "gpt-4-turbo"           => 128_000,
        "gpt-4"                 => 8_192,
        "gpt-3.5-turbo"         => 16_385,
        "o1"                    => 200_000,
        "o3"                    => 200_000,
        # Google
        "gemini-2.0-flash"      => 1_048_576,
        "gemini-1.5-pro"        => 2_097_152,
        "gemini-1.5-flash"      => 1_048_576,
        # DeepSeek
        "deepseek-chat"         => 64_000,
        "deepseek-reasoner"     => 64_000,
      }.freeze

      # -----------------------------------------------------------------------
      # Public helpers
      # -----------------------------------------------------------------------

      # Parse a provider response hash and persist token counts in @_mcp_usage.
      #
      #   record_usage(response, model: "claude-sonnet-4-20250514")
      #
      def record_usage(response, model: nil)
        @_mcp_model = model if model
        @_mcp_usage = extract_usage(response)
      end

      # Tokens consumed so far (input + output combined).
      def context_used_tokens
        return 0 unless @_mcp_usage
        (@_mcp_usage[:input_tokens] || 0) + (@_mcp_usage[:output_tokens] || 0)
      end

      # Total context window for the current model (falls back to 128 000).
      def context_limit_tokens
        return @_context_limit if defined?(@_context_limit) && @_context_limit

        configured = ExtendableRails.configuration.context_limits rescue nil
        limits     = configured ? DEFAULT_LIMITS.merge(configured) : DEFAULT_LIMITS

        if @_mcp_model
          match = limits.keys.find { |prefix| @_mcp_model.to_s.start_with?(prefix) }
          @_context_limit = match ? limits[match] : 128_000
        else
          @_context_limit = 128_000
        end
      end

      # Tokens still available.
      def context_remaining_tokens
        [context_limit_tokens - context_used_tokens, 0].max
      end

      # Percentage of context still available (0–100, two decimal places).
      def context_remaining_percent
        return 100.0 if context_limit_tokens.zero?
        ((context_remaining_tokens.to_f / context_limit_tokens) * 100).round(2)
      end

      # Returns a symbol reflecting how full the context window is:
      #   :ok       — ≥ 30 % remaining
      #   :warning  — 10–29 % remaining
      #   :critical — < 10 % remaining
      def context_status
        pct = context_remaining_percent
        if pct >= 30
          :ok
        elsif pct >= 10
          :warning
        else
          :critical
        end
      end

      # Convenience summary hash (useful for JSON endpoints or view locals).
      def context_summary
        {
          used:      context_used_tokens,
          remaining: context_remaining_tokens,
          limit:     context_limit_tokens,
          percent:   context_remaining_percent,
          status:    context_status,
          model:     @_mcp_model
        }
      end

      private

      # Normalises provider-specific usage shapes into { input_tokens:, output_tokens: }.
      def extract_usage(response)
        return {} unless response.is_a?(Hash)

        # Anthropic: { "usage" => { "input_tokens" => N, "output_tokens" => N } }
        if (u = response["usage"] || response[:usage])
          input  = u["input_tokens"]  || u[:input_tokens]  || 0
          output = u["output_tokens"] || u[:output_tokens] || 0
          return { input_tokens: input.to_i, output_tokens: output.to_i }
        end

        # OpenAI / DeepSeek: { "usage" => { "prompt_tokens" => N, "completion_tokens" => N } }
        if (u = response["usage"] || response[:usage])
          input  = u["prompt_tokens"]     || u[:prompt_tokens]     || 0
          output = u["completion_tokens"] || u[:completion_tokens] || 0
          return { input_tokens: input.to_i, output_tokens: output.to_i }
        end

        # Gemini: { "usageMetadata" => { "promptTokenCount" => N, "candidatesTokenCount" => N } }
        if (u = response["usageMetadata"] || response[:usageMetadata])
          input  = u["promptTokenCount"]     || u[:promptTokenCount]     || 0
          output = u["candidatesTokenCount"] || u[:candidatesTokenCount] || 0
          return { input_tokens: input.to_i, output_tokens: output.to_i }
        end

        {}
      end
    end
  end
end
