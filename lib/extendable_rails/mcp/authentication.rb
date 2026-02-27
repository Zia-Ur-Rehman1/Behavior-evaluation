# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module ExtendableRails
  module Mcp
    # Rack middleware that authenticates incoming MCP requests.
    #
    # Supports three strategies configured via ExtendableRails.configuration:
    #   :none    — all requests pass through (default)
    #   :api_key — checks Authorization: Bearer <key> against configured key
    #   :oauth   — validates bearer token against a remote introspection endpoint
    class Authentication
      UNAUTHORIZED = [
        401,
        { "Content-Type" => "application/json" },
        ['{"error":"Unauthorized"}']
      ].freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        config = ExtendableRails.configuration

        case config.mcp_auth_strategy
        when :none
          @app.call(env)
        when :api_key
          authenticate_api_key(env, config)
        when :oauth
          authenticate_oauth(env, config)
        else
          @app.call(env)
        end
      end

      private

      def authenticate_api_key(env, config)
        token    = extract_bearer_token(env)
        expected = resolve_api_key(config)

        if expected && !expected.empty? && token == expected
          @app.call(env)
        else
          UNAUTHORIZED
        end
      end

      def authenticate_oauth(env, config)
        token = extract_bearer_token(env)
        return UNAUTHORIZED unless token

        if config.oauth_token_url
          validate_token_remote(token, config) ? @app.call(env) : UNAUTHORIZED
        else
          UNAUTHORIZED
        end
      end

      def extract_bearer_token(env)
        auth = env["HTTP_AUTHORIZATION"]
        return nil unless auth

        match = auth.match(/\ABearer\s+(.+)\z/i)
        match&.[](1)
      end

      def resolve_api_key(config)
        key = config.mcp_api_key
        key.respond_to?(:call) ? key.call : key
      end

      def validate_token_remote(token, config)
        uri  = URI.parse(config.oauth_token_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = (uri.scheme == "https")
        http.open_timeout  = 5
        http.read_timeout  = 5

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Accept"]       = "application/json"
        request.body = URI.encode_www_form(token: token)

        response = http.request(request)
        return false unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        body["active"] == true
      rescue StandardError
        false
      end
    end
  end
end
