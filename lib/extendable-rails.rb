# frozen_string_literal: true
#
# Bundler auto-require shim.
# The gem is named "extendable-rails" (dash), but the real entry point is
# lib/extendable_rails.rb (underscore). Bundler tries `require "extendable-rails"`
# and then `require "extendable/rails"`, neither of which would find the
# underscore file, so this shim bridges the gap.

require_relative "extendable_rails"
