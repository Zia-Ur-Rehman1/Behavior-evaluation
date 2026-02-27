# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module ExtendableRails
  module Mcp
    module Llm
      class ProviderError < StandardError; end

      # A single LLM provider with built-in circuit breaker.
      #
      # Supports Anthropic, OpenAI, Gemini, DeepSeek, and any OpenAI-compatible API.
      # After `max_failures` consecutive failures the circuit opens and the provider
      # is skipped for `cooldown` seconds before retrying (half-open state).
      class Provider
        attr_reader :name, :model, :base_url

        DEFAULT_ENDPOINTS = {
          anthropic: "https://api.anthropic.com/v1/messages",
          openai:    "https://api.openai.com/v1/chat/completions",
          gemini:    "https://generativelanguage.googleapis.com/v1beta/models/%{model}:generateContent",
          deepseek:  "https://api.deepseek.com/v1/chat/completions"
        }.freeze

        def initialize(name:, api_key:, model:, base_url: nil, max_failures: 3, cooldown: 60)
          @name         = name.to_sym
          @api_key      = api_key
          @model        = model
          @base_url     = base_url
          @max_failures = max_failures
          @cooldown     = cooldown

          # Circuit breaker state
          @failure_count   = 0
          @last_failure_at = nil
          @mutex           = Mutex.new
        end

        # Returns true when the circuit has tripped and the cooldown hasn't
        # elapsed yet.
        def circuit_open?
          @mutex.synchronize do
            return false if @failure_count < @max_failures
            return false if @last_failure_at.nil?

            elapsed = Time.now - @last_failure_at
            if elapsed >= @cooldown
              # Cooldown expired — half-open: reset and allow a retry
              @failure_count   = 0
              @last_failure_at = nil
              false
            else
              true
            end
          end
        end

        # Makes a chat completion request.
        # Returns a Hash with the parsed response body.
        # Raises ProviderError on any failure.
        def chat(messages:, **options)
          raise ProviderError, "Circuit open for #{@name}" if circuit_open?

          response = send_request(messages, options)
          record_success
          response
        rescue ProviderError
          raise
        rescue StandardError => e
          record_failure
          raise ProviderError, "#{@name} failed: #{e.message}"
        end

        def reset_circuit!
          @mutex.synchronize do
            @failure_count   = 0
            @last_failure_at = nil
          end
        end

        private

        def record_success
          @mutex.synchronize do
            @failure_count   = 0
            @last_failure_at = nil
          end
        end

        def record_failure
          @mutex.synchronize do
            @failure_count  += 1
            @last_failure_at = Time.now
          end
        end

        def send_request(messages, options)
          case @name
          when :anthropic
            send_anthropic_request(messages, options)
          when :gemini
            send_gemini_request(messages, options)
          else
            # OpenAI-compatible: openai, deepseek, and any other provider
            send_openai_compatible_request(messages, options)
          end
        end

        # ----------------------------------------------------------------
        # Anthropic Messages API
        # ----------------------------------------------------------------
        def send_anthropic_request(messages, options)
          url = @base_url || DEFAULT_ENDPOINTS[:anthropic]
          uri = URI.parse(url)
          http = build_http(uri)

          body = {
            model:      @model,
            max_tokens: options.fetch(:max_tokens, 1024),
            messages:   messages
          }.merge(options.except(:max_tokens))

          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"]      = "application/json"
          request["x-api-key"]         = resolve_api_key
          request["anthropic-version"] = "2023-06-01"
          request.body = JSON.generate(body)

          execute_request(http, request)
        end

        # ----------------------------------------------------------------
        # OpenAI-compatible API (OpenAI, DeepSeek, etc.)
        # ----------------------------------------------------------------
        def send_openai_compatible_request(messages, options)
          url = @base_url || DEFAULT_ENDPOINTS.fetch(@name, DEFAULT_ENDPOINTS[:openai])
          uri = URI.parse(url)
          http = build_http(uri)

          body = { model: @model, messages: messages }.merge(options)

          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"]  = "application/json"
          request["Authorization"] = "Bearer #{resolve_api_key}"
          request.body = JSON.generate(body)

          execute_request(http, request)
        end

        # ----------------------------------------------------------------
        # Google Gemini API
        # ----------------------------------------------------------------
        def send_gemini_request(messages, options)
          url = @base_url || format(DEFAULT_ENDPOINTS[:gemini], model: @model)
          uri = URI.parse("#{url}?key=#{resolve_api_key}")
          http = build_http(uri)

          # Convert OpenAI-style messages to Gemini contents format
          contents = messages.map do |msg|
            role = msg[:role] == "assistant" ? "model" : "user"
            { role: role, parts: [{ text: msg[:content] }] }
          end

          body = { contents: contents }.merge(options)

          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)

          execute_request(http, request)
        end

        def build_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl      = (uri.scheme == "https")
          http.open_timeout  = 10
          http.read_timeout  = 30
          http
        end

        def execute_request(http, request)
          response = http.request(request)
          body = JSON.parse(response.body)

          unless response.is_a?(Net::HTTPSuccess)
            error_msg = body.dig("error", "message") || body.to_s
            raise StandardError, "HTTP #{response.code}: #{error_msg}"
          end

          body
        end

        def resolve_api_key
          @api_key.respond_to?(:call) ? @api_key.call : @api_key
        end
      end
    end
  end
end
