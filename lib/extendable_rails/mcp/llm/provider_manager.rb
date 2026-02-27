# frozen_string_literal: true

require "logger"

module ExtendableRails
  module Mcp
    module Llm
      # Manages an ordered chain of LLM providers with automatic failover.
      #
      # Tries each provider in priority order (first configured = highest
      # priority). Skips providers whose circuit breaker has tripped. Falls
      # through to the next provider on any failure.
      #
      #   ExtendableRails::Mcp::Llm::ProviderManager.chat(
      #     messages: [{ role: "user", content: "Hello!" }]
      #   )
      class ProviderManager
        class AllProvidersFailedError < StandardError; end

        class << self
          # Convenience class method so callers can use the singleton directly.
          def chat(messages:, **options)
            instance.chat(messages: messages, **options)
          end

          def instance
            @instance ||= new(ExtendableRails.configuration.llm_providers)
          end

          # Reset the singleton (called on config reload / in tests).
          def reset!
            @instance = nil
          end
        end

        attr_reader :providers

        def initialize(provider_configs)
          @providers = Array(provider_configs).map { |cfg| Provider.new(**cfg) }
          @logger    = defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : Logger.new($stdout)
        end

        # Tries each provider in priority order. Returns the first successful
        # response hash. Raises AllProvidersFailedError if every provider fails.
        def chat(messages:, **options)
          errors = []

          @providers.each do |provider|
            if provider.circuit_open?
              @logger&.info("[ExtendableRails::LLM] Skipping #{provider.name} — circuit open")
              next
            end

            begin
              @logger&.debug("[ExtendableRails::LLM] Trying #{provider.name} (#{provider.model})")
              result = provider.chat(messages: messages, **options)
              @logger&.info("[ExtendableRails::LLM] Success with #{provider.name}")
              return result
            rescue ProviderError => e
              @logger&.warn("[ExtendableRails::LLM] #{provider.name} failed: #{e.message}")
              errors << { provider: provider.name, error: e.message }
              ExtendableRails.report_error(
                e,
                severity: :warning,
                source:   "Mcp::Llm::ProviderManager#chat",
                context:  { provider: provider.name, model: provider.model }
              )
            end
          end

          err = AllProvidersFailedError.new(
            "All LLM providers failed: #{errors.map { |e| "#{e[:provider]}: #{e[:error]}" }.join('; ')}"
          )
          ExtendableRails.report_error(
            err,
            severity: :critical,
            source:   "Mcp::Llm::ProviderManager#chat",
            context:  { attempted: errors.map { |e| e[:provider] } }
          )
          raise err
        end
      end
    end
  end
end
