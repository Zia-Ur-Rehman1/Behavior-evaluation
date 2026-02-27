# frozen_string_literal: true

require "rails"
require "rails/generators"
require "rails/generators/test_case"
require "generator_spec"

begin
  require "action_mailer"
rescue LoadError
  # action_mailer is optional; email notifier specs that need it will skip
end

# Load the gem under test
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "extendable_rails"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.order = :random
  config.warnings = false
end
