# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::Mcp::Llm::ProviderManager do
  let(:provider_configs) do
    [
      { name: :primary,   api_key: "pk", model: "model-a", max_failures: 2, cooldown: 1 },
      { name: :secondary, api_key: "sk", model: "model-b", max_failures: 2, cooldown: 1 }
    ]
  end

  subject(:manager) { described_class.new(provider_configs) }

  before { ExtendableRails.reset_configuration! }
  after  { ExtendableRails.reset_configuration! }

  describe "#chat" do
    it "returns the first provider's result on success" do
      primary = manager.providers.first
      allow(primary).to receive(:chat).and_return({ "result" => "from primary" })

      result = manager.chat(messages: [{ role: "user", content: "hello" }])
      expect(result["result"]).to eq("from primary")
    end

    it "falls back to the second provider when the first fails" do
      primary   = manager.providers[0]
      secondary = manager.providers[1]

      allow(primary).to receive(:chat)
        .and_raise(ExtendableRails::Mcp::Llm::ProviderError, "rate limited")
      allow(secondary).to receive(:chat)
        .and_return({ "result" => "from secondary" })

      result = manager.chat(messages: [{ role: "user", content: "hello" }])
      expect(result["result"]).to eq("from secondary")
    end

    it "raises AllProvidersFailedError when all providers fail" do
      manager.providers.each do |p|
        allow(p).to receive(:chat)
          .and_raise(ExtendableRails::Mcp::Llm::ProviderError, "down")
      end

      expect { manager.chat(messages: [{ role: "user", content: "hello" }]) }
        .to raise_error(described_class::AllProvidersFailedError, /All LLM providers failed/)
    end

    it "skips providers with open circuits" do
      primary   = manager.providers[0]
      secondary = manager.providers[1]

      # Trip the primary's circuit breaker
      2.times { primary.send(:record_failure) }
      expect(primary.circuit_open?).to be true

      allow(secondary).to receive(:chat)
        .and_return({ "result" => "from secondary" })

      result = manager.chat(messages: [{ role: "user", content: "hello" }])
      expect(result["result"]).to eq("from secondary")
    end

    it "includes all provider errors in the AllProvidersFailedError message" do
      manager.providers.each_with_index do |p, i|
        allow(p).to receive(:chat)
          .and_raise(ExtendableRails::Mcp::Llm::ProviderError, "error #{i}")
      end

      begin
        manager.chat(messages: [{ role: "user", content: "hello" }])
      rescue described_class::AllProvidersFailedError => e
        expect(e.message).to include("primary")
        expect(e.message).to include("secondary")
        expect(e.message).to include("error 0")
        expect(e.message).to include("error 1")
      end
    end
  end

  describe "#providers" do
    it "exposes the provider list" do
      expect(manager.providers.length).to eq(2)
      expect(manager.providers.first.name).to eq(:primary)
      expect(manager.providers.last.name).to eq(:secondary)
    end
  end

  describe ".instance (singleton)" do
    after do
      described_class.reset!
      ExtendableRails.reset_configuration!
    end

    it "creates an instance from global configuration" do
      ExtendableRails.configure do |c|
        c.add_llm_provider(name: :openai, api_key: "key", model: "gpt-4o")
      end

      instance = described_class.instance
      expect(instance.providers.length).to eq(1)
      expect(instance.providers.first.name).to eq(:openai)
    end

    it "can be reset" do
      described_class.instance  # creates one
      described_class.reset!

      ExtendableRails.configure do |c|
        c.add_llm_provider(name: :anthropic, api_key: "key", model: "claude")
        c.add_llm_provider(name: :deepseek, api_key: "key2", model: "ds")
      end

      instance = described_class.instance
      expect(instance.providers.length).to eq(2)
    end
  end

  describe "with empty provider list" do
    subject(:manager) { described_class.new([]) }

    it "raises AllProvidersFailedError immediately" do
      expect { manager.chat(messages: [{ role: "user", content: "hello" }]) }
        .to raise_error(described_class::AllProvidersFailedError)
    end
  end

  describe "error reporting integration" do
    let(:spy) do
      Class.new(ExtendableRails::ErrorReporting::Notifiers::Base) do
        attr_reader :received
        def initialize(**opts); super; @received = []; end
        def deliver(event); @received << event; end
      end.new
    end

    before do
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }
    end

    it "reports a :warning when a single provider fails but failover succeeds" do
      primary   = manager.providers[0]
      secondary = manager.providers[1]

      allow(primary).to receive(:chat)
        .and_raise(ExtendableRails::Mcp::Llm::ProviderError, "rate limited")
      allow(secondary).to receive(:chat).and_return({ "result" => "ok" })

      manager.chat(messages: [{ role: "user", content: "hi" }])

      warnings = spy.received.select { |e| e.severity == :warning }
      expect(warnings.length).to eq(1)
      expect(warnings.first.source).to eq("Mcp::Llm::ProviderManager#chat")
      expect(warnings.first.context[:provider]).to eq(:primary)
    end

    it "reports a :critical when all providers fail" do
      manager.providers.each do |p|
        allow(p).to receive(:chat)
          .and_raise(ExtendableRails::Mcp::Llm::ProviderError, "down")
      end

      expect { manager.chat(messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(described_class::AllProvidersFailedError)

      criticals = spy.received.select { |e| e.severity == :critical }
      expect(criticals.length).to eq(1)
      expect(criticals.first.context[:attempted]).to eq(%i[primary secondary])
    end

    it "does not report anything on a successful first-try chat" do
      primary = manager.providers.first
      allow(primary).to receive(:chat).and_return({ "result" => "ok" })

      manager.chat(messages: [{ role: "user", content: "hi" }])

      expect(spy.received).to be_empty
    end
  end
end
