# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe ExtendableRails::ErrorReporting::Notifiers::Logger do
  let(:output)   { StringIO.new }
  let(:logger)   { ::Logger.new(output) }
  let(:notifier) { described_class.new(logger: logger) }

  describe "inheritance" do
    it "inherits from Notifiers::Base" do
      expect(described_class.superclass)
        .to eq(ExtendableRails::ErrorReporting::Notifiers::Base)
    end
  end

  describe "LOG_METHODS mapping" do
    it "maps every severity level to a log method" do
      ExtendableRails::ErrorReporting::Severity::LEVELS.each do |level|
        expect(described_class::LOG_METHODS).to have_key(level)
      end
    end

    it "maps critical to fatal" do
      expect(described_class::LOG_METHODS[:critical]).to eq(:fatal)
    end

    it "maps normal to info" do
      expect(described_class::LOG_METHODS[:normal]).to eq(:info)
    end
  end

  describe "#initialize" do
    it "accepts an injected logger" do
      expect(notifier.instance_variable_get(:@logger)).to be(logger)
    end

    it "falls back to Rails.logger when available and not injected" do
      rails_logger = ::Logger.new(StringIO.new)
      allow(Rails).to receive(:logger).and_return(rails_logger)
      n = described_class.new
      expect(n.instance_variable_get(:@logger)).to be(rails_logger)
    end

    it "passes threshold to Base" do
      n = described_class.new(threshold: :warning)
      expect(n.threshold).to eq(:warning)
    end
  end

  describe "#deliver" do
    it "logs at the mapped level" do
      event = ExtendableRails::ErrorReporting::ErrorEvent.new(
        message: "payload too large", severity: :warning
      )
      notifier.deliver(event)
      expect(output.string).to include("WARN")
      expect(output.string).to include("[Warning] payload too large")
    end

    it "includes backtrace when present" do
      err = RuntimeError.new("x")
      err.set_backtrace(["app/foo.rb:7"])
      event = ExtendableRails::ErrorReporting::ErrorEvent.new(
        exception: err, severity: :high
      )
      notifier.deliver(event)
      expect(output.string).to include("app/foo.rb:7")
    end

    it "includes context when present" do
      event = ExtendableRails::ErrorReporting::ErrorEvent.new(
        message: "x", context: { key: "val" }
      )
      notifier.deliver(event)
      expect(output.string).to include("Context: {")
      expect(output.string).to include("key")
    end

    it "uses fatal for critical events" do
      event = ExtendableRails::ErrorReporting::ErrorEvent.new(
        message: "system down", severity: :critical
      )
      notifier.deliver(event)
      expect(output.string).to include("FATAL")
    end
  end
end
