# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::Mcp::Llm::Provider do
  subject(:provider) do
    described_class.new(
      name:         :openai,
      api_key:      "sk-test",
      model:        "gpt-4o",
      max_failures: 3,
      cooldown:     2  # short cooldown for testing
    )
  end

  describe "#circuit_open?" do
    it "is false initially" do
      expect(provider.circuit_open?).to be false
    end

    it "is false after fewer than max_failures failures" do
      2.times { provider.send(:record_failure) }
      expect(provider.circuit_open?).to be false
    end

    it "is true after max_failures consecutive failures" do
      3.times { provider.send(:record_failure) }
      expect(provider.circuit_open?).to be true
    end

    it "resets after cooldown period" do
      3.times { provider.send(:record_failure) }
      expect(provider.circuit_open?).to be true

      # Simulate time passing beyond cooldown
      provider.instance_variable_set(:@last_failure_at, Time.now - 3)
      expect(provider.circuit_open?).to be false
    end

    it "resets failure count on success" do
      2.times { provider.send(:record_failure) }
      provider.send(:record_success)
      expect(provider.circuit_open?).to be false

      # Even after recording more failures, counter started from 0
      2.times { provider.send(:record_failure) }
      expect(provider.circuit_open?).to be false
    end
  end

  describe "#reset_circuit!" do
    it "clears failure count and last failure time" do
      3.times { provider.send(:record_failure) }
      expect(provider.circuit_open?).to be true

      provider.reset_circuit!
      expect(provider.circuit_open?).to be false
    end
  end

  describe "#chat" do
    it "raises ProviderError when circuit is open" do
      3.times { provider.send(:record_failure) }

      expect { provider.chat(messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(ExtendableRails::Mcp::Llm::ProviderError, /Circuit open/)
    end
  end

  describe "#name and #model" do
    it "exposes the provider name as a symbol" do
      expect(provider.name).to eq(:openai)
    end

    it "exposes the model name" do
      expect(provider.model).to eq("gpt-4o")
    end
  end

  describe "DEFAULT_ENDPOINTS" do
    it "has endpoints for anthropic, openai, gemini, and deepseek" do
      endpoints = described_class::DEFAULT_ENDPOINTS
      expect(endpoints.keys).to contain_exactly(:anthropic, :openai, :gemini, :deepseek)
    end
  end

  describe "Proc-based api_key" do
    it "resolves the key at call time" do
      counter = 0
      p = described_class.new(
        name: :openai,
        api_key: -> { counter += 1; "key-#{counter}" },
        model: "gpt-4o"
      )
      expect(p.send(:resolve_api_key)).to eq("key-1")
      expect(p.send(:resolve_api_key)).to eq("key-2")
    end
  end
end
