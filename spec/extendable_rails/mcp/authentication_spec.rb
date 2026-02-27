# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::Mcp::Authentication do
  let(:inner_app) { ->(env) { [200, { "Content-Type" => "text/plain" }, ["OK"]] } }
  let(:middleware) { described_class.new(inner_app) }

  after { ExtendableRails.reset_configuration! }

  def env_with_auth(token)
    { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
  end

  describe "strategy :none" do
    before { ExtendableRails.configure { |c| c.mcp_auth_strategy = :none } }

    it "passes all requests through" do
      status, = middleware.call({})
      expect(status).to eq(200)
    end
  end

  describe "strategy :api_key" do
    before do
      ExtendableRails.configure do |c|
        c.mcp_auth_strategy = :api_key
        c.mcp_api_key = "secret-key-123"
      end
    end

    it "accepts requests with correct API key" do
      status, = middleware.call(env_with_auth("secret-key-123"))
      expect(status).to eq(200)
    end

    it "rejects requests with wrong API key" do
      status, = middleware.call(env_with_auth("wrong-key"))
      expect(status).to eq(401)
    end

    it "rejects requests with no Authorization header" do
      status, = middleware.call({})
      expect(status).to eq(401)
    end

    it "rejects requests with empty bearer token" do
      status, = middleware.call("HTTP_AUTHORIZATION" => "Bearer ")
      expect(status).to eq(401)
    end

    it "supports Proc-based API keys" do
      ExtendableRails.configure do |c|
        c.mcp_auth_strategy = :api_key
        c.mcp_api_key = -> { "dynamic-key" }
      end

      status, = middleware.call(env_with_auth("dynamic-key"))
      expect(status).to eq(200)
    end
  end

  describe "strategy :oauth" do
    before do
      ExtendableRails.configure do |c|
        c.mcp_auth_strategy = :oauth
      end
    end

    it "rejects when no oauth_token_url is configured" do
      status, = middleware.call(env_with_auth("some-token"))
      expect(status).to eq(401)
    end

    it "rejects when no token is provided" do
      ExtendableRails.configure { |c| c.oauth_token_url = "https://auth.example.com/introspect" }
      status, = middleware.call({})
      expect(status).to eq(401)
    end
  end
end
