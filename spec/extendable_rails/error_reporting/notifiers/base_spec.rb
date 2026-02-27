# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::Notifiers::Base do
  # Concrete subclass for testing abstract behaviour.
  let(:test_class) do
    Class.new(described_class) do
      attr_reader :delivered

      def initialize(**opts)
        super
        @delivered = []
      end

      def deliver(event)
        @delivered << event
      end
    end
  end

  let(:failing_class) do
    Class.new(described_class) do
      def deliver(_event)
        raise "network down"
      end
    end
  end

  let(:event_normal) do
    ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x", severity: :normal)
  end

  let(:event_high) do
    ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x", severity: :high)
  end

  let(:event_critical) do
    ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x", severity: :critical)
  end

  describe "#initialize" do
    it "defaults threshold to :normal" do
      expect(test_class.new.threshold).to eq(:normal)
    end

    it "coerces threshold" do
      expect(test_class.new(threshold: "warning").threshold).to eq(:warning)
    end

    it "raises on invalid threshold" do
      expect { test_class.new(threshold: :xxx) }.to raise_error(ArgumentError)
    end
  end

  describe "#deliver" do
    it "raises NotImplementedError on the base class" do
      expect { described_class.new.deliver(event_normal) }
        .to raise_error(NotImplementedError, /must implement #deliver/)
    end
  end

  describe "#notify" do
    context "threshold filtering" do
      let(:notifier) { test_class.new(threshold: :high) }

      it "delivers events at the threshold" do
        notifier.notify(event_high)
        expect(notifier.delivered).to include(event_high)
      end

      it "delivers events above the threshold" do
        notifier.notify(event_critical)
        expect(notifier.delivered).to include(event_critical)
      end

      it "skips events below the threshold" do
        notifier.notify(event_normal)
        expect(notifier.delivered).to be_empty
      end

      it "returns true when delivered" do
        expect(notifier.notify(event_high)).to be true
      end

      it "returns false when skipped" do
        expect(notifier.notify(event_normal)).to be false
      end
    end

    context "safety" do
      let(:notifier) { failing_class.new }

      it "swallows delivery exceptions" do
        expect { notifier.notify(event_critical) }.not_to raise_error
      end

      it "returns false on delivery failure" do
        expect(notifier.notify(event_critical)).to be false
      end

      it "prints a warning" do
        expect { notifier.notify(event_critical) }
          .to output(/failed to deliver.*network down/).to_stderr
      end
    end
  end

  describe "#handle?" do
    let(:notifier) { test_class.new(threshold: :warning) }

    it "is true at or above threshold" do
      expect(notifier.handle?(event_high)).to be true
    end

    it "is false below threshold" do
      expect(notifier.handle?(event_normal)).to be false
    end
  end

  describe "protected helpers" do
    let(:notifier) { test_class.new }

    describe "#truncate" do
      it "returns short strings unchanged" do
        expect(notifier.send(:truncate, "abc", max: 10)).to eq("abc")
      end

      it "truncates long strings with an ellipsis" do
        result = notifier.send(:truncate, "a" * 600, max: 10)
        expect(result.length).to eq(10)
        expect(result).to end_with("…")
      end
    end

    describe "#format_backtrace" do
      it "joins the first N frames" do
        err = RuntimeError.new("x")
        err.set_backtrace((1..20).map { |i| "frame#{i}" })
        event = ExtendableRails::ErrorReporting::ErrorEvent.new(exception: err)
        result = notifier.send(:format_backtrace, event, lines: 3)
        expect(result).to eq("frame1\nframe2\nframe3")
      end
    end
  end
end
