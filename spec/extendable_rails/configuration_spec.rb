# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "defaults auth strategy to :none" do
      expect(config.mcp_auth_strategy).to eq(:none)
    end

    it "defaults mcp_api_key to nil" do
      expect(config.mcp_api_key).to be_nil
    end

    it "defaults oauth_token_url to nil" do
      expect(config.oauth_token_url).to be_nil
    end

    it "defaults llm_providers to empty array" do
      expect(config.llm_providers).to eq([])
    end

    it "defaults context_limits to empty hash" do
      expect(config.context_limits).to eq({})
    end
  end

  describe "#add_llm_provider" do
    it "adds a provider config hash to the list" do
      config.add_llm_provider(name: :anthropic, api_key: "sk-test", model: "claude-sonnet-4-20250514")
      expect(config.llm_providers.length).to eq(1)
      expect(config.llm_providers.first[:name]).to eq(:anthropic)
      expect(config.llm_providers.first[:model]).to eq("claude-sonnet-4-20250514")
    end

    it "preserves insertion order for fallback chain" do
      config.add_llm_provider(name: :anthropic, api_key: "sk-1", model: "claude")
      config.add_llm_provider(name: :openai, api_key: "sk-2", model: "gpt-4o")
      config.add_llm_provider(name: :deepseek, api_key: "sk-3", model: "deepseek-chat")

      expect(config.llm_providers.map { |p| p[:name] }).to eq(%i[anthropic openai deepseek])
    end

    it "converts name to symbol" do
      config.add_llm_provider(name: "gemini", api_key: "key", model: "gemini-pro")
      expect(config.llm_providers.first[:name]).to eq(:gemini)
    end

    it "includes default max_failures and cooldown" do
      config.add_llm_provider(name: :anthropic, api_key: "key", model: "claude")
      provider = config.llm_providers.first
      expect(provider[:max_failures]).to eq(3)
      expect(provider[:cooldown]).to eq(60)
    end

    it "allows overriding max_failures and cooldown" do
      config.add_llm_provider(name: :anthropic, api_key: "key", model: "claude",
                              max_failures: 5, cooldown: 120)
      provider = config.llm_providers.first
      expect(provider[:max_failures]).to eq(5)
      expect(provider[:cooldown]).to eq(120)
    end
  end

  describe "ExtendableRails.configure" do
    after { ExtendableRails.reset_configuration! }

    it "yields the configuration object" do
      ExtendableRails.configure do |c|
        c.mcp_auth_strategy = :api_key
        c.mcp_api_key = "test-key"
      end

      expect(ExtendableRails.configuration.mcp_auth_strategy).to eq(:api_key)
      expect(ExtendableRails.configuration.mcp_api_key).to eq("test-key")
    end
  end

  describe "ExtendableRails.reset_configuration!" do
    it "resets to a fresh configuration" do
      ExtendableRails.configure { |c| c.mcp_auth_strategy = :oauth }
      ExtendableRails.reset_configuration!
      expect(ExtendableRails.configuration.mcp_auth_strategy).to eq(:none)
    end
  end
end
