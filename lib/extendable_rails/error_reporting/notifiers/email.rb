# frozen_string_literal: true

module ExtendableRails
  module ErrorReporting
    module Notifiers
      # Sends error events as plain-text emails.
      #
      # Uses the +mail+ gem directly (the same gem ActionMailer depends on) so
      # the host app's SMTP/delivery settings are honoured without pulling in
      # ActionView. If no mail transport is configured, falls back to a
      # stderr dump so events are never silently dropped.
      #
      #   ExtendableRails.configure do |c|
      #     c.add_error_notifier(
      #       ExtendableRails::ErrorReporting::Notifiers::Email.new(
      #         to:        %w[ops@example.com cto@example.com],
      #         from:      "alerts@example.com",
      #         threshold: :high
      #       )
      #     )
      #   end
      class Email < Base
        def initialize(to:, from: "no-reply@localhost", subject_prefix: "[ExtendableRails]", **opts)
          super(**opts)
          @to      = Array(to)
          @from    = from
          @prefix  = subject_prefix
        end

        def deliver(event)
          subject = build_subject(event)
          body    = build_body(event)

          if mail_available?
            deliver_via_mail(subject, body)
          else
            warn "[ExtendableRails::ErrorReporting::Email] No mail transport available.\n" \
                 "Subject: #{subject}\n#{body}"
          end
        end

        private

        def build_subject(event)
          "#{@prefix} [#{event.severity_label}] #{truncate(event.message, max: 120)}"
        end

        def build_body(event)
          lines = []
          lines << "An error was captured by extendable-rails."
          lines << ""
          lines << "Severity:  #{event.severity_label} – #{event.severity_description}"
          lines << "Timestamp: #{event.timestamp.iso8601}"
          lines << "Event ID:  #{event.id}"
          lines << "Fingerprint: #{event.fingerprint}"
          lines << ""
          lines << "Message:"
          lines << "  #{event.message}"
          lines << ""
          if event.exception_class
            lines << "Exception: #{event.exception_class}"
            lines << ""
          end
          if event.source
            lines << "Source: #{event.source}"
            lines << ""
          end
          unless event.context.empty?
            lines << "Context:"
            event.context.each { |k, v| lines << "  #{k}: #{v.inspect}" }
            lines << ""
          end
          unless event.backtrace.empty?
            lines << "Backtrace (first 30 lines):"
            event.backtrace.first(30).each { |frame| lines << "  #{frame}" }
            lines << ""
          end
          lines << "--"
          lines << "extendable-rails error reporting"
          lines.join("\n")
        end

        def mail_available?
          return true if defined?(::Mail)

          begin
            require "mail"
            true
          rescue LoadError
            false
          end
        end

        def deliver_via_mail(subject, body)
          mail = ::Mail.new
          mail.to      = @to
          mail.from    = @from
          mail.subject = subject
          mail.body    = body
          mail.charset = "UTF-8"

          # If ActionMailer is loaded, reuse its configured delivery method so
          # SMTP / :test / :letter_opener settings from the host Rails app apply.
          if defined?(ActionMailer::Base)
            mail.delivery_method(
              ActionMailer::Base.delivery_method,
              ActionMailer::Base.send("#{ActionMailer::Base.delivery_method}_settings") || {}
            )
          end

          mail.deliver
        end
      end
    end
  end
end
