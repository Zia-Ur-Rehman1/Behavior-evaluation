# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"
require "rails/generators/resource_helpers"

module Extendable
  module Generators
    class ScaffoldGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("templates", __dir__)

      # Accept field:type pairs exactly like `rails generate scaffold`
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      # ----------------------------------------------------------------
      # Turbo flags
      # ----------------------------------------------------------------

      # -t / --turbo: generate BOTH Turbo Stream views AND a turbo-aware controller
      class_option :turbo, type: :boolean, aliases: "-t", default: false,
                           desc: "Generate Turbo Stream views and a turbo-aware controller (controller + views)"

      # --turbo-controller / -tc: generate ONLY the turbo-aware controller (no views)
      class_option :turbo_controller, type: :boolean, aliases: "-tc", default: false,
                                      desc: "Generate only the turbo-aware controller (no Turbo Stream views)"

      # --turbo-view / -tv: generate ONLY the Turbo Stream views + HTML views (no controller)
      class_option :turbo_view, type: :boolean, aliases: "-tv", default: false,
                                desc: "Generate only Turbo Stream views and HTML views (no controller)"

      # --template / -T: choose the view template style
      #   default  — the classic extendable-rails views (matching the original style)
      #   table    — tabular layout with a <table> on the index page
      #   card     — grid of cards on the index page
      #   minimal  — bare-bones HTML, no styling
      class_option :template, type: :string, aliases: "-T", default: "default",
                              desc: "View template style: default, table, card, minimal"

      # ----------------------------------------------------------------
      # MCP flag
      # ----------------------------------------------------------------

      # -m / --mcp: generate MCP tool files for this resource
      class_option :mcp, type: :boolean, aliases: "-m", default: false,
                         desc: "Generate MCP (Model Context Protocol) tool files"

      # ----------------------------------------------------------------
      # Entry point
      # ----------------------------------------------------------------
      def generate_scaffold
        if !turbo_any? && !options[:mcp]
          invoke_standard_scaffold
        else
          generate_model_and_migration
          generate_routes
          generate_turbo_controller if want_turbo_controller?
          generate_turbo_views      if want_turbo_views?
          generate_html_files       if want_turbo_views?
          generate_mcp_files        if options[:mcp]
          generate_mcp_initializer  if options[:mcp]
        end
      end

      private

      # ----------------------------------------------------------------
      # Flag resolution helpers
      # ----------------------------------------------------------------

      VALID_TEMPLATES = %w[default table card minimal].freeze

      def turbo_any?
        options[:turbo] || options[:turbo_controller] || options[:turbo_view]
      end

      def want_turbo_controller?
        options[:turbo] || options[:turbo_controller]
      end

      def want_turbo_views?
        options[:turbo] || options[:turbo_view]
      end

      # Resolved template style — falls back to "default" for unknown values.
      def view_template
        t = options[:template].to_s.downcase
        VALID_TEMPLATES.include?(t) ? t : "default"
      end

      # ----------------------------------------------------------------
      # Standard fallback
      # ----------------------------------------------------------------
      def invoke_standard_scaffold
        invoke "rails:scaffold", [name] + raw_attributes_args, {}
      end

      def raw_attributes_args
        attributes.map { |a| "#{a.name}:#{a.type}" }
      end

      # ----------------------------------------------------------------
      # Model + migration
      # ----------------------------------------------------------------
      def generate_model_and_migration
        invoke "rails:model", [name] + raw_attributes_args
      end

      # ----------------------------------------------------------------
      # Routes (guard against duplicates on re-run)
      # ----------------------------------------------------------------
      def generate_routes
        routes_file = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes_file) &&
           File.read(routes_file).include?("resources :#{plural_table_name}")
          say_status :skip, "route already exists for #{plural_table_name}", :yellow
          return
        end
        route "resources :#{plural_table_name}"
      end

      # ----------------------------------------------------------------
      # Turbo: controller only
      # ----------------------------------------------------------------
      def generate_turbo_controller
        template "turbo/controller.rb.tt",
                 "app/controllers/#{controller_file_path}_controller.rb"
      end

      # ----------------------------------------------------------------
      # Turbo: turbo_stream views (shared across all template styles)
      # ----------------------------------------------------------------
      def generate_turbo_views
        %w[create update destroy new edit].each do |action|
          template "turbo/views/#{action}.turbo_stream.erb.tt",
                   "app/views/#{controller_file_path}/#{action}.turbo_stream.erb"
        end
      end

      # ----------------------------------------------------------------
      # Turbo: HTML views — routed through selected template style
      # ----------------------------------------------------------------
      def generate_html_files
        tpl = view_template
        dir = "app/views/#{controller_file_path}"
        empty_directory dir

        %w[index show new edit _form].each do |view|
          src = if tpl == "default"
                  "turbo/views/#{view}.html.erb.tt"
                else
                  "turbo/views/#{tpl}/#{view}.html.erb.tt"
                end
          template src, "#{dir}/#{view}.html.erb"
        end

        # Named model partial (_post.html.erb)
        partial_src = if tpl == "default"
                        "turbo/views/_singular.html.erb.tt"
                      else
                        "turbo/views/#{tpl}/_singular.html.erb.tt"
                      end
        template partial_src, "#{dir}/_#{singular_table_name}.html.erb"
      end

      # ----------------------------------------------------------------
      # MCP: tool files + shared infrastructure (idempotent)
      # ----------------------------------------------------------------
      def generate_mcp_files
        generate_application_tool
        generate_mcp_auth_middleware
        generate_mcp_llm_files
        generate_mcp_context_window
        generate_mcp_chat_widget

        mcp_dir = "app/mcp/tools/#{plural_table_name}"
        empty_directory mcp_dir

        %w[base index show create update destroy].each do |tool|
          template "mcp/#{tool}_tool.rb.tt", "#{mcp_dir}/#{tool}_tool.rb"
        end
      end

      def generate_mcp_initializer
        initializer_path = "config/initializers/mcp.rb"
        unless File.exist?(File.join(destination_root, initializer_path))
          template "mcp/initializer.rb.tt", initializer_path
        end
      end

      # Shared ApplicationTool base class (created once)
      def generate_application_tool
        app_tool_path = "app/mcp/tools/application_tool.rb"
        unless File.exist?(File.join(destination_root, app_tool_path))
          template "mcp/application_tool.rb.tt", app_tool_path
        end
      end

      # Auth middleware skeleton (created once)
      def generate_mcp_auth_middleware
        auth_dir  = "app/mcp/middleware"
        auth_path = "#{auth_dir}/authentication.rb"
        unless File.exist?(File.join(destination_root, auth_path))
          empty_directory auth_dir
          template "mcp/authentication.rb.tt", auth_path
        end
      end

      # LLM provider files (created once each)
      def generate_mcp_llm_files
        llm_dir = "app/mcp/llm"
        %w[provider provider_manager].each do |file|
          path = "#{llm_dir}/#{file}.rb"
          unless File.exist?(File.join(destination_root, path))
            empty_directory llm_dir
            template "mcp/#{file}.rb.tt", path
          end
        end
      end

      # Context window partial + helper (created once)
      def generate_mcp_context_window
        partial_path = "app/views/mcp/_context_window.html.erb"
        unless File.exist?(File.join(destination_root, partial_path))
          empty_directory "app/views/mcp"
          template "mcp/_context_window.html.erb.tt", partial_path
        end

        helper_path = "app/mcp/helpers/context_window_helper.rb"
        unless File.exist?(File.join(destination_root, helper_path))
          empty_directory "app/mcp/helpers"
          template "mcp/context_window_helper.rb.tt", helper_path
        end
      end

      # Floating chat widget controller + views + partial (created once)
      def generate_mcp_chat_widget
        controller_path = "app/controllers/mcp_chats_controller.rb"
        unless File.exist?(File.join(destination_root, controller_path))
          template "mcp/chat_controller.rb.tt", controller_path
        end

        chat_views_dir = "app/views/mcp_chats"
        empty_directory chat_views_dir

        %w[create error].each do |action|
          view_path = "#{chat_views_dir}/#{action}.turbo_stream.erb"
          unless File.exist?(File.join(destination_root, view_path))
            template "mcp/chat/#{action}.turbo_stream.erb.tt", view_path
          end
        end

        widget_path = "app/views/mcp/_chat_widget.html.erb"
        unless File.exist?(File.join(destination_root, widget_path))
          template "mcp/_chat_widget.html.erb.tt", widget_path
        end

        # Inject chat routes (idempotent)
        routes_file = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes_file) &&
           !File.read(routes_file).include?("mcp_chats")
          route <<~ROUTE.strip
            resources :mcp_chats, only: [:create] do
                collection { delete :clear }
              end
          ROUTE
        end
      end

      # ----------------------------------------------------------------
      # Template helpers (available inside .tt files via ERB)
      # ----------------------------------------------------------------

      # Maps Rails column types to JSON Schema types for MCP tool definitions
      def mcp_type_for(attribute)
        mapping = {
          "string"     => "string",
          "text"       => "string",
          "integer"    => "integer",
          "float"      => "number",
          "decimal"    => "number",
          "boolean"    => "boolean",
          "date"       => "string",
          "datetime"   => "string",
          "time"       => "string",
          "references" => "integer",
          "belongs_to" => "integer",
        }
        mapping.fetch(attribute.type.to_s, "string")
      end

      # Attributes excluding auto-managed timestamps
      def mcp_attributes
        attributes.reject { |a| %w[created_at updated_at].include?(a.name) }
      end

      # Generates a human-readable bullet list of MCP tools for the chat
      # widget's default system prompt (used inside chat_controller.rb.tt)
      def mcp_tool_descriptions
        tools_root = File.join(destination_root, "app", "mcp", "tools")
        return "various resources" unless File.directory?(tools_root)

        resource_dirs = Dir.glob(File.join(tools_root, "*")).select { |f| File.directory?(f) }
        return "various resources" if resource_dirs.empty?

        resource_dirs.map do |dir|
          name = File.basename(dir).humanize
          "- #{name}: list, show, create, update, destroy"
        end.join("\n")
      end
    end
  end
end
