# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::Notifiers::Slack do
  let(:webhook_url) { "https://hooks.slack.test/services/T000/B000/XXXX" }
  let(:notifier)    { described_class.new(webhook_url: webhook_url) }

  let(:exception) do
    err = RuntimeError.new("kaboom")
    err.set_backtrace(["app/a.rb:1", "app/b.rb:2"])
    err
  end

  let(:event) do
    ExtendableRails::ErrorReporting::ErrorEvent.new(
      exception: exception,
      severity:  :high,
      context:   { user_id: 42, request_id: "abc" },
      source:    "Foo#bar"
    )
  end

  describe "inheritance" do
    it "inherits from Notifiers::Base" do
      expect(described_class.superclass)
        .to eq(ExtendableRails::ErrorReporting::Notifiers::Base)
    end
  end

  describe "#initialize" do
    it "requires a webhook_url" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "accepts optional channel" do
      n = described_class.new(webhook_url: webhook_url, channel: "#ops")
      expect(n.instance_variable_get(:@channel)).to eq("#ops")
    end

    it "defaults username" do
      expect(notifier.instance_variable_get(:@username)).to eq("extendable-rails")
    end

    it "passes threshold to Base" do
      n = described_class.new(webhook_url: webhook_url, threshold: :critical)
      expect(n.threshold).to eq(:critical)
    end
  end

  describe "COLORS" do
    it "maps every severity level" do
      ExtendableRails::ErrorReporting::Severity::LEVELS.each do |level|
        expect(described_class::COLORS).to have_key(level)
      end
    end

    it "uses red for critical" do
      expect(described_class::COLORS[:critical]).to eq("#ff0000")
    end
  end

  describe "#build_payload (private)" do
    subject(:payload) { notifier.send(:build_payload, event) }

    it "includes username" do
      expect(payload[:username]).to eq("extendable-rails")
    end

    it "has exactly one attachment" do
      expect(payload[:attachments].length).to eq(1)
    end

    it "omits channel when not configured" do
      expect(payload).not_to have_key(:channel)
    end

    it "includes channel when configured" do
      n = described_class.new(webhook_url: webhook_url, channel: "#alerts")
      expect(n.send(:build_payload, event)[:channel]).to eq("#alerts")
    end

    describe "attachment" do
      let(:attachment) { payload[:attachments].first }

      it "uses the severity colour" do
        expect(attachment[:color]).to eq(described_class::COLORS[:high])
      end

      it "uses the event summary as title" do
        expect(attachment[:title]).to eq(event.summary)
      end

      it "includes the message text" do
        expect(attachment[:text]).to include("kaboom")
      end

      it "embeds the fingerprint in the footer" do
        expect(attachment[:footer]).to include(event.fingerprint)
      end

      it "has a unix timestamp" do
        expect(attachment[:ts]).to be_a(Integer)
      end
    end
  end

  describe "#build_fields (private)" do
    subject(:fields) { notifier.send(:build_fields, event) }

    it "includes severity" do
      expect(fields.map { |f| f[:title] }).to include("Severity")
    end

    it "includes exception class" do
      exc_field = fields.find { |f| f[:title] == "Exception" }
      expect(exc_field[:value]).to eq("RuntimeError")
    end

    it "shows dash for missing exception" do
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "plain")
      fields = notifier.send(:build_fields, e)
      exc_field = fields.find { |f| f[:title] == "Exception" }
      expect(exc_field[:value]).to eq("—")
    end

    it "includes source when present" do
      expect(fields.map { |f| f[:title] }).to include("Source")
    end

    it "includes context field with formatted key-values" do
      ctx_field = fields.find { |f| f[:title] == "Context" }
      expect(ctx_field[:value]).to include("*user_id*: 42")
      expect(ctx_field[:value]).to include("*request_id*:")
    end

    it "includes backtrace in a code block" do
      bt_field = fields.find { |f| f[:title] == "Backtrace" }
      expect(bt_field[:value]).to include("```")
      expect(bt_field[:value]).to include("app/a.rb:1")
    end

    it "omits context when empty" do
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x")
      fields = notifier.send(:build_fields, e)
      expect(fields.map { |f| f[:title] }).not_to include("Context")
    end

    it "omits backtrace when empty" do
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x")
      fields = notifier.send(:build_fields, e)
      expect(fields.map { |f| f[:title] }).not_to include("Backtrace")
    end
  end

  describe "#deliver" do
    it "POSTs JSON to the webhook" do
      http_double = instance_double(Net::HTTP)
      response    = instance_double(Net::HTTPResponse, body: "ok")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      expect(Net::HTTP).to receive(:new).with("hooks.slack.test", 443).and_return(http_double)
      expect(http_double).to receive(:use_ssl=).with(true)
      expect(http_double).to receive(:open_timeout=).with(5)
      expect(http_double).to receive(:read_timeout=).with(5)
      expect(http_double).to receive(:request) do |req|
        expect(req["Content-Type"]).to eq("application/json")
        body = JSON.parse(req.body)
        expect(body["username"]).to eq("extendable-rails")
        expect(body["attachments"]).to be_an(Array)
        response
      end

      notifier.deliver(event)
    end

    it "raises on non-success HTTP responses" do
      http_double = instance_double(Net::HTTP)
      response    = instance_double(Net::HTTPResponse, code: "500", body: "server error")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:request).and_return(response)

      expect { notifier.deliver(event) }.to raise_error(/HTTP 500/)
    end
  end

  describe "threshold integration via #notify" do
    it "skips delivery below threshold" do
      n = described_class.new(webhook_url: webhook_url, threshold: :critical)
      expect(n).not_to receive(:deliver)
      n.notify(event) # event is :high < :critical
    end
  end
end
