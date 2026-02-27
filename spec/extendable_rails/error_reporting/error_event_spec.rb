# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::ErrorEvent do
  let(:exception) do
    err = RuntimeError.new("boom")
    err.set_backtrace(["app/models/foo.rb:42:in `bar'", "app/jobs/sync.rb:10"])
    err
  end

  describe "#initialize" do
    it "generates a unique id" do
      a = described_class.new(message: "x")
      b = described_class.new(message: "x")
      expect(a.id).not_to eq(b.id)
    end

    it "generates a UUID-formatted id" do
      event = described_class.new(message: "x")
      expect(event.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "coerces severity via Severity.coerce" do
      event = described_class.new(message: "x", severity: "high")
      expect(event.severity).to eq(:high)
    end

    it "raises on invalid severity" do
      expect { described_class.new(message: "x", severity: :bogus) }
        .to raise_error(ArgumentError)
    end

    it "defaults severity to :normal" do
      event = described_class.new(message: "x")
      expect(event.severity).to eq(:normal)
    end

    it "extracts message from exception when none given" do
      event = described_class.new(exception: exception)
      expect(event.message).to eq("boom")
    end

    it "prefers explicit message over exception.message" do
      event = described_class.new(exception: exception, message: "custom")
      expect(event.message).to eq("custom")
    end

    it "falls back to placeholder when no message or exception" do
      event = described_class.new
      expect(event.message).to eq("(no message)")
    end

    it "freezes the context hash" do
      event = described_class.new(message: "x", context: { a: 1 })
      expect(event.context).to be_frozen
    end

    it "captures the backtrace from the exception" do
      event = described_class.new(exception: exception)
      expect(event.backtrace.first).to include("foo.rb:42")
    end

    it "has empty backtrace when no exception" do
      event = described_class.new(message: "x")
      expect(event.backtrace).to eq([])
    end

    it "records a UTC timestamp" do
      event = described_class.new(message: "x")
      expect(event.timestamp.utc?).to be true
    end

    it "stores the source" do
      event = described_class.new(message: "x", source: "MyService#call")
      expect(event.source).to eq("MyService#call")
    end
  end

  describe "#exception_class" do
    it "returns the exception class name" do
      event = described_class.new(exception: exception)
      expect(event.exception_class).to eq("RuntimeError")
    end

    it "is nil when there is no exception" do
      event = described_class.new(message: "x")
      expect(event.exception_class).to be_nil
    end
  end

  describe "#severity_label and #severity_description" do
    let(:event) { described_class.new(message: "x", severity: :critical) }

    it "returns the human label" do
      expect(event.severity_label).to eq("Critical")
    end

    it "returns the description" do
      expect(event.severity_description).to match(/immediate attention/i)
    end
  end

  describe "#fingerprint" do
    it "is stable across calls" do
      event = described_class.new(exception: exception, source: "Foo")
      expect(event.fingerprint).to eq(event.fingerprint)
    end

    it "differs for different exception classes" do
      a = described_class.new(exception: RuntimeError.new("x"))
      b = described_class.new(exception: ArgumentError.new("x"))
      expect(a.fingerprint).not_to eq(b.fingerprint)
    end

    it "incorporates source" do
      a = described_class.new(exception: exception, source: "A")
      b = described_class.new(exception: exception, source: "B")
      expect(a.fingerprint).not_to eq(b.fingerprint)
    end

    it "incorporates first backtrace frame" do
      e1 = RuntimeError.new("x")
      e1.set_backtrace(["a.rb:1"])
      e2 = RuntimeError.new("x")
      e2.set_backtrace(["b.rb:1"])
      expect(described_class.new(exception: e1).fingerprint)
        .not_to eq(described_class.new(exception: e2).fingerprint)
    end

    it "falls back to message hash when no exception or source" do
      event = described_class.new(message: "plain string event")
      expect(event.fingerprint).to be_a(String)
      expect(event.fingerprint).not_to be_empty
    end
  end

  describe "#to_h" do
    let(:event) do
      described_class.new(
        exception: exception,
        severity:  :high,
        context:   { user_id: 99 },
        source:    "Foo#bar"
      )
    end

    subject(:h) { event.to_h }

    it "includes all core keys" do
      expect(h.keys).to include(
        :id, :severity, :severity_label, :message, :exception_class,
        :source, :context, :backtrace, :timestamp, :fingerprint
      )
    end

    it "serialises timestamp as ISO 8601" do
      expect(h[:timestamp]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "caps backtrace at 50 frames" do
      big = RuntimeError.new("x")
      big.set_backtrace(Array.new(200) { |i| "frame#{i}" })
      event = described_class.new(exception: big)
      expect(event.to_h[:backtrace].length).to eq(50)
    end

    it "round-trips context" do
      expect(h[:context]).to eq(user_id: 99)
    end
  end

  describe "#summary" do
    it "includes severity, exception class, message, and source" do
      event = described_class.new(
        exception: exception,
        severity:  :critical,
        source:    "Jobs::Sync"
      )
      expect(event.summary).to eq("[Critical] RuntimeError: boom (Jobs::Sync)")
    end

    it "omits exception class when none" do
      event = described_class.new(message: "hello", severity: :warning)
      expect(event.summary).to eq("[Warning] hello")
    end

    it "omits source when none" do
      event = described_class.new(exception: exception, severity: :normal)
      expect(event.summary).to eq("[Normal] RuntimeError: boom")
    end
  end
end
