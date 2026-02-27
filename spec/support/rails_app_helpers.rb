# frozen_string_literal: true

# Helpers for setting up a minimal fake Rails application that serves as
# the destination_root for generator tests.
module RailsAppHelpers
  DESTINATION_ROOT = File.expand_path("../../tmp/rails_app", __dir__)

  # Recreates the minimal Rails app directory tree.
  # Called in before blocks AFTER prepare_destination has wiped the tree.
  def self.setup_routes!
    config_dir = File.join(DESTINATION_ROOT, "config")
    initializers_dir = File.join(DESTINATION_ROOT, "config/initializers")
    FileUtils.mkdir_p(config_dir)
    FileUtils.mkdir_p(initializers_dir)

    routes_path = File.join(config_dir, "routes.rb")
    File.write(routes_path, "Rails.application.routes.draw do\nend\n")
  end
end
