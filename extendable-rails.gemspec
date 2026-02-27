# frozen_string_literal: true

require_relative "lib/extendable_rails/version"

Gem::Specification.new do |spec|
  spec.name          = "extendable-rails"
  spec.version       = ExtendableRails::VERSION
  spec.authors       = ["extendable-rails contributors"]
  spec.email         = ["hello@example.com"]

  spec.summary = "Extends Rails scaffold with Turbo Stream views, MCP tools, and a floating AI chat widget"
  spec.description = <<~DESC
    extendable-rails v2 wraps the standard Rails scaffold generator and adds:
    - -t / --turbo: Hotwire Turbo Stream controller + multiple view templates
      (default, table, card, minimal) with -tc / -tv for controller- or view-only generation
    - -m / --mcp: Model Context Protocol tool files, LLM provider failover,
      context-window UI, and a floating AI chat widget
    - Pluggable error reporting with severity levels (normal/warning/high/critical)
      and built-in Slack, Email, and Logger notifiers + a base class for custom
      third-party integrations
    All peer dependencies (turbo-rails, mcp) are declared as runtime dependencies
    and installed automatically. Compatible with Rails 6.0 through 8.x.
  DESC
  spec.homepage      = "https://github.com/yourorg/extendable-rails"
  spec.license       = "MIT"

  # Ruby 2.7+ covers Rails 6.0–8 range
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = spec.homepage
  spec.metadata["changelog_uri"]     = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "extendable-rails.gemspec", "README.md", "LICENSE", "GUIDE.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]

  # -------------------------------------------------------------------------
  # Runtime dependencies — installed automatically when the gem is added
  # -------------------------------------------------------------------------

  # Rails 6.0 through 8.x (turbo-rails transitively requires railties >= 6.0)
  spec.add_dependency "railties", ">= 6.0"

  # MCP gem — Model Context Protocol server support
  spec.add_dependency "mcp", ">= 0.7"

  # Hotwire Turbo — required for --turbo / -t / -tc / -tv flags
  # Listed as a runtime dependency so `bundle install` pulls it automatically.
  # Applications that only use --mcp can set `turbo_rails` as optional in their
  # own Gemfile, but having it here prevents "uninitialized constant" errors.
  spec.add_dependency "turbo-rails", ">= 1.0"

  # -------------------------------------------------------------------------
  # Development / test dependencies
  # -------------------------------------------------------------------------
  spec.add_development_dependency "rails",          ">= 6.0"
  spec.add_development_dependency "sqlite3",        ">= 1.4"
  spec.add_development_dependency "rspec",          ">= 3.12"
  spec.add_development_dependency "generator_spec", ">= 0.10"
end
