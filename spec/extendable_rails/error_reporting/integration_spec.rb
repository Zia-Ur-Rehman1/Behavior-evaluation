# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Error reporting integration" do
  before { ExtendableRails.reset_configuration! }
  after  { ExtendableRails.reset_configuration! }

  let(:spy_class) do
    Class.new(ExtendableRails::ErrorReporting::Notifiers::Base) do
      attr_reader :received
      def initialize(**opts); super; @received = []; end
      def deliver(event); @received << event; end
    end
  end

  describe "Configuration#error_reporter" do
    it "exposes a Reporter instance" do
      expect(ExtendableRails.configuration.error_reporter)
        .to be_a(ExtendableRails::ErrorReporting::Reporter)
    end

    it "is replaced on reset_configuration!" do
      original = ExtendableRails.configuration.error_reporter
      ExtendableRails.reset_configuration!
      expect(ExtendableRails.configuration.error_reporter).not_to be(original)
    end
  end

  describe "Configuration#add_error_notifier" do
    it "registers a custom notifier instance" do
      spy = spy_class.new
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }
      expect(ExtendableRails.error_reporter.notifiers).to include(spy)
    end

    it "creates a Slack notifier from :slack symbol" do
      ExtendableRails.configure do |c|
        c.add_error_notifier :slack, webhook_url: "https://hooks.slack.test/x"
      end
      expect(ExtendableRails.error_reporter.notifiers.first)
        .to be_a(ExtendableRails::ErrorReporting::Notifiers::Slack)
    end

    it "creates an Email notifier from :email symbol" do
      ExtendableRails.configure do |c|
        c.add_error_notifier :email, to: "ops@example.com"
      end
      expect(ExtendableRails.error_reporter.notifiers.first)
        .to be_a(ExtendableRails::ErrorReporting::Notifiers::Email)
    end

    it "creates a Logger notifier from :logger symbol" do
      ExtendableRails.configure do |c|
        c.add_error_notifier :logger
      end
      expect(ExtendableRails.error_reporter.notifiers.first)
        .to be_a(ExtendableRails::ErrorReporting::Notifiers::Logger)
    end

    it "passes threshold option through to built-in notifiers" do
      ExtendableRails.configure do |c|
        c.add_error_notifier :slack, webhook_url: "https://x.test", threshold: :critical
      end
      expect(ExtendableRails.error_reporter.notifiers.first.threshold).to eq(:critical)
    end
  end

  describe "ExtendableRails.error_reporter" do
    it "delegates to configuration.error_reporter" do
      expect(ExtendableRails.error_reporter)
        .to be(ExtendableRails.configuration.error_reporter)
    end
  end

  describe "ExtendableRails.report_error" do
    it "reports through the configured reporter" do
      spy = spy_class.new
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }

      event = ExtendableRails.report_error(RuntimeError.new("boom"),
                                            severity: :high,
                                            context:  { key: 1 })

      expect(event).to be_a(ExtendableRails::ErrorReporting::ErrorEvent)
      expect(spy.received.first.message).to eq("boom")
      expect(spy.received.first.severity).to eq(:high)
      expect(spy.received.first.context).to eq(key: 1)
    end

    it "accepts a plain string" do
      spy = spy_class.new
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }

      ExtendableRails.report_error("something happened", severity: :warning)
      expect(spy.received.first.message).to eq("something happened")
    end
  end

  describe "ExtendableRails.capture" do
    it "captures, reports, and re-raises" do
      spy = spy_class.new
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }

      expect do
        ExtendableRails.capture(source: "Test") { raise "oops" }
      end.to raise_error("oops")

      expect(spy.received.first.message).to eq("oops")
      expect(spy.received.first.source).to eq("Test")
    end

    it "swallows when reraise: false" do
      spy = spy_class.new
      ExtendableRails.configure { |c| c.add_error_notifier(spy) }

      result = ExtendableRails.capture(reraise: false) { raise "oops" }
      expect(result).to be_nil
      expect(spy.received.length).to eq(1)
    end
  end

  describe "custom third-party notifier" do
    it "can subclass Base and receive events" do
      sentry_class = Class.new(ExtendableRails::ErrorReporting::Notifiers::Base) do
        attr_reader :events
        def initialize(**opts); super; @events = []; end

        def deliver(event)
          # A real integration would POST event.to_h to Sentry here
          @events << event.to_h
        end
      end

      sentry = sentry_class.new(threshold: :warning)
      ExtendableRails.configure { |c| c.add_error_notifier(sentry) }

      ExtendableRails.report_error("test", severity: :high)

      expect(sentry.events.length).to eq(1)
      expect(sentry.events.first[:severity]).to eq(:high)
      expect(sentry.events.first[:message]).to eq("test")
    end

    it "third-party notifier below threshold does not fire" do
      custom = spy_class.new(threshold: :critical)
      ExtendableRails.configure { |c| c.add_error_notifier(custom) }

      ExtendableRails.report_error("minor", severity: :warning)
      expect(custom.received).to be_empty
    end
  end

  describe "multiple notifiers (fan-out)" do
    it "dispatches one event to all registered notifiers" do
      a = spy_class.new
      b = spy_class.new
      c = spy_class.new(threshold: :critical)
      ExtendableRails.configure do |cfg|
        cfg.add_error_notifier(a)
        cfg.add_error_notifier(b)
        cfg.add_error_notifier(c)
      end

      ExtendableRails.report_error("boom", severity: :high)

      expect(a.received.length).to eq(1)
      expect(b.received.length).to eq(1)
      expect(c.received).to be_empty
    end
  end
end
