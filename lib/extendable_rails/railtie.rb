# frozen_string_literal: true

module ExtendableRails
  class Railtie < ::Rails::Railtie
    generators do
      require_relative "../generators/extendable/scaffold/scaffold_generator"
    end

    # app/mcp is picked up automatically by Rails as an autoload root
    # (like app/models), so app/mcp/tools/foo.rb → Tools::Foo.
    #
    # However, the generator emits app/mcp/{helpers,llm,middleware}/*
    # files that define Mcp::* constants (not Helpers::*, Llm::*, etc.),
    # so Zeitwerk can't autoload them. Tell Zeitwerk to ignore those
    # directories and require them explicitly instead.
    initializer "extendable_rails.mcp_paths", before: :set_autoload_paths do |app|
      mcp_path = app.root.join("app", "mcp")
      next unless mcp_path.exist?

      %w[helpers llm middleware].each do |subdir|
        dir = mcp_path.join(subdir)
        Rails.autoloaders.main.ignore(dir) if dir.exist?
      end
    end

    # Eager-require the Mcp::* helper/llm/middleware files that Zeitwerk
    # was told to ignore. Runs after the app's initializers so that
    # ExtendableRails.configure has been called.
    initializer "extendable_rails.mcp_require", after: :load_config_initializers do |app|
      mcp_path = app.root.join("app", "mcp")
      next unless mcp_path.exist?

      %w[helpers llm middleware].each do |subdir|
        dir = mcp_path.join(subdir)
        next unless dir.exist?
        Dir.glob(dir.join("**", "*.rb")).sort.each { |f| require f }
      end
    end

    # Reset the LLM ProviderManager singleton on code reload in development
    config.to_prepare do
      ExtendableRails::Mcp::Llm::ProviderManager.reset!
    end
  end
end
