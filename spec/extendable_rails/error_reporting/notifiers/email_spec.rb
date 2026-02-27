# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::Notifiers::Email do
  let(:notifier) { described_class.new(to: "ops@example.com", from: "alerts@example.com") }

  let(:exception) do
    err = ArgumentError.new("bad argument: nil")
    err.set_backtrace(["lib/foo.rb:10:in `parse'", "lib/bar.rb:5"])
    err
  end

  let(:event) do
    ExtendableRails::ErrorReporting::ErrorEvent.new(
      exception: exception,
      severity:  :critical,
      context:   { job: "NightlySync", attempt: 3 },
      source:    "SyncWorker#perform"
    )
  end

  describe "inheritance" do
    it "inherits from Notifiers::Base" do
      expect(described_class.superclass)
        .to eq(ExtendableRails::ErrorReporting::Notifiers::Base)
    end
  end

  describe "#initialize" do
    it "requires :to" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "wraps :to in an array" do
      n = described_class.new(to: "single@example.com")
      expect(n.instance_variable_get(:@to)).to eq(["single@example.com"])
    end

    it "accepts an array of recipients" do
      n = described_class.new(to: %w[a@x.com b@x.com])
      expect(n.instance_variable_get(:@to)).to eq(%w[a@x.com b@x.com])
    end

    it "defaults from address" do
      n = described_class.new(to: "x@y.com")
      expect(n.instance_variable_get(:@from)).to eq("no-reply@localhost")
    end

    it "has a default subject prefix" do
      expect(notifier.instance_variable_get(:@prefix)).to eq("[ExtendableRails]")
    end

    it "passes threshold to Base" do
      n = described_class.new(to: "x@y.com", threshold: :high)
      expect(n.threshold).to eq(:high)
    end
  end

  describe "#build_subject (private)" do
    it "includes prefix, severity, and message" do
      subj = notifier.send(:build_subject, event)
      expect(subj).to include("[ExtendableRails]")
      expect(subj).to include("[Critical]")
      expect(subj).to include("bad argument")
    end

    it "truncates very long messages" do
      long_event = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "x" * 500)
      subj = notifier.send(:build_subject, long_event)
      expect(subj.length).to be < 200
    end
  end

  describe "#build_body (private)" do
    subject(:body) { notifier.send(:build_body, event) }

    it "states the severity and its description" do
      expect(body).to include("Severity:  Critical")
      expect(body).to include("immediate attention")
    end

    it "includes the event id" do
      expect(body).to include("Event ID:  #{event.id}")
    end

    it "includes the fingerprint" do
      expect(body).to include("Fingerprint: #{event.fingerprint}")
    end

    it "includes the message" do
      expect(body).to include("bad argument: nil")
    end

    it "includes the exception class" do
      expect(body).to include("Exception: ArgumentError")
    end

    it "includes the source" do
      expect(body).to include("Source: SyncWorker#perform")
    end

    it "lists context key-value pairs" do
      expect(body).to include("job: \"NightlySync\"")
      expect(body).to include("attempt: 3")
    end

    it "includes the backtrace" do
      expect(body).to include("lib/foo.rb:10")
    end

    it "caps backtrace at 30 lines" do
      big = RuntimeError.new("x")
      big.set_backtrace(Array.new(100) { |i| "frame#{i}" })
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(exception: big)
      body = notifier.send(:build_body, e)
      expect(body).to include("frame29")
      expect(body).not_to include("frame30")
    end

    it "omits exception section when no exception" do
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "plain")
      body = notifier.send(:build_body, e)
      expect(body).not_to include("Exception:")
    end

    it "omits context section when empty" do
      e = ExtendableRails::ErrorReporting::ErrorEvent.new(message: "plain")
      body = notifier.send(:build_body, e)
      expect(body).not_to include("Context:")
    end
  end

  describe "#deliver" do
    context "when the Mail gem is available" do
      before do
        require "mail"
        Mail.defaults { delivery_method :test }
        Mail::TestMailer.deliveries.clear
        # Hide ActionMailer so the plain Mail path is taken (avoids Ruby 3.3.0
        # + ActionView anonymous-parameter syntax bug in the test environment).
        hide_const("ActionMailer") if defined?(ActionMailer)
      end

      after { Mail::TestMailer.deliveries.clear }

      it "delivers a mail with the correct recipients" do
        notifier.deliver(event)

        expect(Mail::TestMailer.deliveries.length).to eq(1)
        delivered = Mail::TestMailer.deliveries.first
        expect(delivered.to).to eq(["ops@example.com"])
        expect(delivered.from).to eq(["alerts@example.com"])
      end

      it "includes severity and message in the subject" do
        notifier.deliver(event)
        delivered = Mail::TestMailer.deliveries.first
        expect(delivered.subject).to include("[Critical]")
        expect(delivered.subject).to include("bad argument")
      end

      it "includes full error details in the body" do
        notifier.deliver(event)
        body = Mail::TestMailer.deliveries.first.body.to_s
        expect(body).to include("Severity:  Critical")
        expect(body).to include("bad argument: nil")
        expect(body).to include("ArgumentError")
        expect(body).to include("lib/foo.rb:10")
      end

      it "supports multiple recipients" do
        n = described_class.new(to: %w[a@x.com b@x.com], from: "alerts@x.com")
        n.deliver(event)
        expect(Mail::TestMailer.deliveries.first.to).to eq(%w[a@x.com b@x.com])
      end
    end

    context "when no mail transport is available" do
      it "warns to stderr" do
        hide_const("ActionMailer") if defined?(ActionMailer)
        hide_const("Mail")         if defined?(Mail)
        # Prevent require "mail" from succeeding inside #mail_available?
        allow(notifier).to receive(:mail_available?).and_return(false)

        expect { notifier.deliver(event) }
          .to output(/No mail transport available/).to_stderr
      end
    end
  end
end
