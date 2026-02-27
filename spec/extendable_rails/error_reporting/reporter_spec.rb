# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::Reporter do
  subject(:reporter) { described_class.new }

  # Simple spy notifier
  let(:spy_class) do
    Class.new(ExtendableRails::ErrorReporting::Notifiers::Base) do
      attr_reader :received
      def initialize(**opts); super; @received = []; end
      def deliver(event); @received << event; end
    end
  end

  describe "notifier registry" do
    it "starts empty" do
      expect(reporter.notifiers).to be_empty
    end

    it "registers notifiers" do
      n = spy_class.new
      reporter.add(n)
      expect(reporter.notifiers).to include(n)
    end

    it "returns self for chaining" do
      expect(reporter.add(spy_class.new)).to be(reporter)
    end

    it "rejects objects that don't respond to #notify" do
      expect { reporter.add(Object.new) }
        .to raise_error(ArgumentError, /must respond to #notify/)
    end

    it "clears notifiers" do
      reporter.add(spy_class.new)
      reporter.clear!
      expect(reporter.notifiers).to be_empty
    end

    it "returns a copy so external mutation is safe" do
      reporter.add(spy_class.new)
      copy = reporter.notifiers
      copy.clear
      expect(reporter.notifiers).not_to be_empty
    end
  end

  describe "#report" do
    let(:spy_a) { spy_class.new }
    let(:spy_b) { spy_class.new }

    before do
      reporter.add(spy_a)
      reporter.add(spy_b)
    end

    context "with an Exception" do
      let(:err) do
        e = RuntimeError.new("boom")
        e.set_backtrace(["x.rb:1"])
        e
      end

      it "dispatches to every notifier" do
        reporter.report(err)
        expect(spy_a.received.length).to eq(1)
        expect(spy_b.received.length).to eq(1)
      end

      it "wraps the exception in an ErrorEvent" do
        event = reporter.report(err)
        expect(event).to be_a(ExtendableRails::ErrorReporting::ErrorEvent)
        expect(event.exception).to be(err)
        expect(event.exception_class).to eq("RuntimeError")
      end

      it "defaults severity to :normal" do
        event = reporter.report(err)
        expect(event.severity).to eq(:normal)
      end

      it "accepts severity override" do
        event = reporter.report(err, severity: :critical)
        expect(event.severity).to eq(:critical)
      end

      it "passes context through" do
        event = reporter.report(err, context: { a: 1 })
        expect(event.context).to eq(a: 1)
      end

      it "passes source through" do
        event = reporter.report(err, source: "Foo#bar")
        expect(event.source).to eq("Foo#bar")
      end

      it "allows message override" do
        event = reporter.report(err, message: "custom")
        expect(event.message).to eq("custom")
      end
    end

    context "with a String" do
      it "creates an event with no exception" do
        event = reporter.report("something happened", severity: :warning)
        expect(event.exception).to be_nil
        expect(event.message).to eq("something happened")
        expect(event.severity).to eq(:warning)
      end
    end

    it "still dispatches if one notifier raises" do
      bad = Class.new(ExtendableRails::ErrorReporting::Notifiers::Base) do
        def deliver(_e); raise "network"; end
      end.new
      good = spy_class.new
      reporter.clear!
      reporter.add(bad).add(good)

      expect { reporter.report("x") }.not_to raise_error
      expect(good.received.length).to eq(1)
    end
  end

  describe "#capture" do
    let(:spy) { spy_class.new }
    before    { reporter.add(spy) }

    it "yields the block and returns its value on success" do
      result = reporter.capture { 42 }
      expect(result).to eq(42)
    end

    it "does not report when the block succeeds" do
      reporter.capture { :ok }
      expect(spy.received).to be_empty
    end

    it "reports and re-raises by default" do
      expect { reporter.capture { raise "boom" } }
        .to raise_error(RuntimeError, "boom")
      expect(spy.received.length).to eq(1)
    end

    it "uses :high as the default severity" do
      reporter.capture { raise "boom" } rescue nil
      expect(spy.received.first.severity).to eq(:high)
    end

    it "accepts a custom severity" do
      reporter.capture(severity: :critical) { raise "boom" } rescue nil
      expect(spy.received.first.severity).to eq(:critical)
    end

    it "suppresses the exception when reraise: false" do
      result = reporter.capture(reraise: false) { raise "boom" }
      expect(result).to be_nil
      expect(spy.received.length).to eq(1)
    end

    it "swallows listed exception classes without re-raising" do
      result = reporter.capture(swallow: [ArgumentError]) { raise ArgumentError, "x" }
      expect(result).to be_nil
      expect(spy.received.first.exception_class).to eq("ArgumentError")
    end

    it "still re-raises unlisted exceptions when swallow is given" do
      expect do
        reporter.capture(swallow: [ArgumentError]) { raise RuntimeError, "x" }
      end.to raise_error(RuntimeError)
    end

    it "attaches context and source" do
      reporter.capture(context: { k: "v" }, source: "Foo") { raise "boom" } rescue nil
      event = spy.received.first
      expect(event.context).to eq(k: "v")
      expect(event.source).to eq("Foo")
    end
  end

  describe "severity convenience helpers" do
    let(:spy) { spy_class.new }
    before    { reporter.add(spy) }

    %i[normal warning high critical].each do |level|
      it "##{level} reports with severity :#{level}" do
        event = reporter.public_send(level, "msg")
        expect(event.severity).to eq(level)
        expect(spy.received.first.severity).to eq(level)
      end
    end

    it "passes additional options" do
      event = reporter.warning("msg", context: { a: 1 }, source: "Foo")
      expect(event.context).to eq(a: 1)
      expect(event.source).to eq("Foo")
    end
  end

  describe "threshold behaviour (integration)" do
    it "respects notifier thresholds" do
      low  = spy_class.new(threshold: :normal)
      high = spy_class.new(threshold: :critical)
      reporter.add(low).add(high)

      reporter.report("minor glitch", severity: :warning)

      expect(low.received.length).to eq(1)
      expect(high.received).to be_empty
    end
  end

  describe "thread safety" do
    it "handles concurrent reports without error" do
      spy = spy_class.new
      reporter.add(spy)

      threads = Array.new(20) do
        Thread.new { reporter.report("concurrent") }
      end
      threads.each(&:join)

      expect(spy.received.length).to eq(20)
    end
  end
end
