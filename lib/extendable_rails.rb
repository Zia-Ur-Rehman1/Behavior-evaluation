# frozen_string_literal: true

require "rails"
require_relative "extendable_rails/version"
require_relative "extendable_rails/error_reporting/severity"
require_relative "extendable_rails/error_reporting/error_event"
require_relative "extendable_rails/error_reporting/notifiers/base"
require_relative "extendable_rails/error_reporting/notifiers/logger"
require_relative "extendable_rails/error_reporting/notifiers/slack"
require_relative "extendable_rails/error_reporting/notifiers/email"
require_relative "extendable_rails/error_reporting/reporter"
require_relative "extendable_rails/configuration"
require_relative "extendable_rails/mcp/authentication"
require_relative "extendable_rails/mcp/context_window"
require_relative "extendable_rails/mcp/llm/provider"
require_relative "extendable_rails/mcp/llm/provider_manager"
require_relative "extendable_rails/railtie"

module ExtendableRails
end
