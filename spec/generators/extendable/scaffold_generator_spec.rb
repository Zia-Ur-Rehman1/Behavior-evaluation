# frozen_string_literal: true

require "spec_helper"
require "support/rails_app_helpers"
require "generators/extendable/scaffold/scaffold_generator"

RSpec.describe Extendable::Generators::ScaffoldGenerator, type: :generator do
  destination RailsAppHelpers::DESTINATION_ROOT

  # Recreate the minimal routes.rb after prepare_destination wipes the tree.
  before do
    prepare_destination
    RailsAppHelpers.setup_routes!
  end

  # -----------------------------------------------------------------------
  # Helper: build a generator instance without running it (for unit tests)
  # -----------------------------------------------------------------------
  def build_generator(*args)
    generator(args)
  end

  # -----------------------------------------------------------------------
  # 1. No flags — standard Rails scaffold fallback
  # -----------------------------------------------------------------------
  describe "with no flags (standard scaffold fallback)" do
    it "delegates to invoke_standard_scaffold when no flags are given" do
      gen = build_generator("Post", "title:string", "body:text")
      expect(gen).to receive(:invoke_standard_scaffold)
      gen.generate_scaffold
    end

    it "does not create turbo stream view files" do
      # Stub the standard scaffold so we don't need a real Rails app/db
      allow_any_instance_of(described_class).to receive(:invoke_standard_scaffold)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string"]
      assert_no_file "app/views/posts/create.turbo_stream.erb"
      assert_no_file "app/views/posts/update.turbo_stream.erb"
      assert_no_file "app/views/posts/destroy.turbo_stream.erb"
    end

    it "does not create MCP tool files" do
      allow_any_instance_of(described_class).to receive(:invoke_standard_scaffold)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string"]
      assert_no_file "app/mcp/tools/posts/index_tool.rb"
      assert_no_file "app/mcp/tools/posts/create_tool.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 2. -t / --turbo flag (controller + views)
  # -----------------------------------------------------------------------
  describe "with --turbo flag (-t)" do
    before do
      # Stub the private helpers that call invoke/route to keep tests fast/isolated
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo"]
    end

    # --- Controller ---
    it "creates a turbo-aware controller" do
      assert_file "app/controllers/posts_controller.rb"
    end

    it "controller responds to turbo_stream format in create" do
      assert_file "app/controllers/posts_controller.rb" do |content|
        expect(content).to match(/respond_to do \|format\|/)
        expect(content).to match(/format\.turbo_stream/)
      end
    end

    it "controller has the correct class name" do
      assert_file "app/controllers/posts_controller.rb" do |content|
        expect(content).to match(/class PostsController < ApplicationController/)
      end
    end

    it "controller includes all CRUD actions" do
      assert_file "app/controllers/posts_controller.rb" do |content|
        %w[index show new edit create update destroy].each do |action|
          expect(content).to match(/def #{action}/)
        end
      end
    end

    # --- Turbo stream views ---
    it "creates create.turbo_stream.erb" do
      assert_file "app/views/posts/create.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.prepend/)
      end
    end

    it "creates update.turbo_stream.erb" do
      assert_file "app/views/posts/update.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.replace/)
      end
    end

    it "creates destroy.turbo_stream.erb" do
      assert_file "app/views/posts/destroy.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.remove/)
      end
    end

    it "creates new.turbo_stream.erb" do
      assert_file "app/views/posts/new.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.update/)
      end
    end

    it "creates edit.turbo_stream.erb" do
      assert_file "app/views/posts/edit.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.replace/)
      end
    end

    # --- HTML views ---
    it "creates index.html.erb with turbo target div" do
      assert_file "app/views/posts/index.html.erb" do |content|
        expect(content).to match(/id="posts"/)
      end
    end

    it "creates index.html.erb with a modal container" do
      assert_file "app/views/posts/index.html.erb" do |content|
        expect(content).to match(/id="modal"/)
      end
    end

    it "creates show.html.erb" do
      assert_file "app/views/posts/show.html.erb"
    end

    it "creates new.html.erb" do
      assert_file "app/views/posts/new.html.erb"
    end

    it "creates edit.html.erb" do
      assert_file "app/views/posts/edit.html.erb"
    end

    it "creates _form.html.erb" do
      assert_file "app/views/posts/_form.html.erb" do |content|
        expect(content).to match(/form_with/)
      end
    end

    it "creates named model partial _post.html.erb" do
      assert_file "app/views/posts/_post.html.erb"
    end

    it "model partial is wrapped in turbo_frame_tag" do
      assert_file "app/views/posts/_post.html.erb" do |content|
        expect(content).to match(/turbo_frame_tag/)
      end
    end

    it "model partial shows the title attribute" do
      assert_file "app/views/posts/_post.html.erb" do |content|
        expect(content).to match(/\.title/)
      end
    end

    # --- Does NOT create MCP files ---
    it "does not create MCP tool files" do
      assert_no_file "app/mcp/tools/posts/index_tool.rb"
      assert_no_file "app/mcp/tools/posts/create_tool.rb"
    end

    it "does not create an MCP initializer" do
      assert_no_file "config/initializers/mcp.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 3. --turbo-controller / -tc flag (controller only, no views)
  # -----------------------------------------------------------------------
  describe "with --turbo-controller flag (-tc)" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo-controller"]
    end

    it "creates the turbo-aware controller" do
      assert_file "app/controllers/posts_controller.rb" do |content|
        expect(content).to match(/format\.turbo_stream/)
      end
    end

    it "does NOT create turbo_stream views" do
      assert_no_file "app/views/posts/create.turbo_stream.erb"
      assert_no_file "app/views/posts/update.turbo_stream.erb"
      assert_no_file "app/views/posts/destroy.turbo_stream.erb"
      assert_no_file "app/views/posts/new.turbo_stream.erb"
      assert_no_file "app/views/posts/edit.turbo_stream.erb"
    end

    it "does NOT create HTML views" do
      assert_no_file "app/views/posts/index.html.erb"
      assert_no_file "app/views/posts/show.html.erb"
      assert_no_file "app/views/posts/_form.html.erb"
    end

    it "does not create MCP tool files" do
      assert_no_file "app/mcp/tools/posts/index_tool.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 4. --turbo-view / -tv flag (views only, no controller)
  # -----------------------------------------------------------------------
  describe "with --turbo-view flag (-tv)" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo-view"]
    end

    it "does NOT create the controller" do
      assert_no_file "app/controllers/posts_controller.rb"
    end

    it "creates create.turbo_stream.erb" do
      assert_file "app/views/posts/create.turbo_stream.erb" do |content|
        expect(content).to match(/turbo_stream\.prepend/)
      end
    end

    it "creates update.turbo_stream.erb" do
      assert_file "app/views/posts/update.turbo_stream.erb"
    end

    it "creates destroy.turbo_stream.erb" do
      assert_file "app/views/posts/destroy.turbo_stream.erb"
    end

    it "creates all HTML views" do
      %w[index show new edit _form].each do |view|
        assert_file "app/views/posts/#{view}.html.erb"
      end
    end

    it "creates the named model partial" do
      assert_file "app/views/posts/_post.html.erb"
    end

    it "does not create MCP tool files" do
      assert_no_file "app/mcp/tools/posts/index_tool.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 5. -m / --mcp flag
  # -----------------------------------------------------------------------
  describe "with --mcp flag (-m)" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--mcp"]
    end

    # --- MCP tool files ---
    it "creates base_tool.rb inheriting from ApplicationTool" do
      assert_file "app/mcp/tools/posts/base_tool.rb" do |content|
        expect(content).to match(/class BaseTool < Tools::ApplicationTool/)
      end
    end

    it "creates index_tool.rb" do
      assert_file "app/mcp/tools/posts/index_tool.rb" do |content|
        expect(content).to match(/Post\.all/)
        expect(content).to match(/tool_name.*post_list/)
      end
    end

    it "creates show_tool.rb" do
      assert_file "app/mcp/tools/posts/show_tool.rb" do |content|
        expect(content).to match(/Post\.find\(id\)/)
        expect(content).to match(/tool_name.*post_show/)
      end
    end

    it "creates create_tool.rb with correct attribute names" do
      assert_file "app/mcp/tools/posts/create_tool.rb" do |content|
        expect(content).to match(/title:/)
        expect(content).to match(/body:/)
      end
    end

    it "creates create_tool.rb with correct JSON Schema types" do
      assert_file "app/mcp/tools/posts/create_tool.rb" do |content|
        # string and text both map to "string"
        expect(content).to match(/type: "string"/)
      end
    end

    it "creates update_tool.rb" do
      assert_file "app/mcp/tools/posts/update_tool.rb" do |content|
        expect(content).to match(/Post\.find\(id\)/)
        expect(content).to match(/record\.update!/)
      end
    end

    it "creates destroy_tool.rb" do
      assert_file "app/mcp/tools/posts/destroy_tool.rb" do |content|
        expect(content).to match(/Post\.find\(id\)/)
        expect(content).to match(/record\.destroy!/)
      end
    end

    it "creates config/initializers/mcp.rb" do
      assert_file "config/initializers/mcp.rb" do |content|
        expect(content).to match(/MCP::Server\.new/)
      end
    end

    # --- Shared infrastructure files ---
    it "creates app/mcp/tools/application_tool.rb" do
      assert_file "app/mcp/tools/application_tool.rb" do |content|
        expect(content).to match(/class ApplicationTool < MCP::Tool/)
        expect(content).to match(/module Tools/)
      end
    end

    it "creates app/mcp/middleware/authentication.rb" do
      assert_file "app/mcp/middleware/authentication.rb" do |content|
        expect(content).to match(/class Authentication/)
        expect(content).to match(/module Mcp/)
      end
    end

    it "creates app/mcp/llm/provider.rb" do
      assert_file "app/mcp/llm/provider.rb" do |content|
        expect(content).to match(/class Provider/)
      end
    end

    it "creates app/mcp/llm/provider_manager.rb" do
      assert_file "app/mcp/llm/provider_manager.rb" do |content|
        expect(content).to match(/class ProviderManager/)
      end
    end

    it "initializer includes auto-discovery logic" do
      assert_file "config/initializers/mcp.rb" do |content|
        expect(content).to match(/after_initialize/)
        expect(content).to match(/Dir\.glob/)
        expect(content).to match(/mcp_server\.tools\s*=/)
      end
    end

    it "initializer includes ExtendableRails.configure block" do
      assert_file "config/initializers/mcp.rb" do |content|
        expect(content).to match(/ExtendableRails\.configure/)
        expect(content).to match(/mcp_auth_strategy/)
        expect(content).to match(/add_llm_provider/)
      end
    end

    # --- Context window UI ---
    it "creates the context window view partial" do
      assert_file "app/views/mcp/_context_window.html.erb" do |content|
        expect(content).to match(/mcp-context-window/)
        expect(content).to match(/remaining/)
      end
    end

    it "creates the context window helper" do
      assert_file "app/mcp/helpers/context_window_helper.rb" do |content|
        expect(content).to match(/ContextWindowHelper/)
        expect(content).to match(/ExtendableRails::Mcp::ContextWindow/)
      end
    end

    it "does not create turbo stream views" do
      assert_no_file "app/views/posts/create.turbo_stream.erb"
      assert_no_file "app/views/posts/destroy.turbo_stream.erb"
    end

    it "does not create a turbo controller" do
      # Without -t, no controller should be generated at all
      assert_no_file "app/controllers/posts_controller.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 6. Both --turbo and --mcp flags together
  # -----------------------------------------------------------------------
  describe "with both --turbo and --mcp flags" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo", "--mcp"]
    end

    it "creates the turbo-aware controller" do
      assert_file "app/controllers/posts_controller.rb" do |content|
        expect(content).to match(/format\.turbo_stream/)
      end
    end

    it "creates all turbo stream views" do
      %w[create update destroy new edit].each do |action|
        assert_file "app/views/posts/#{action}.turbo_stream.erb"
      end
    end

    it "creates all HTML views" do
      %w[index show new edit _form].each do |view|
        assert_file "app/views/posts/#{view}.html.erb"
      end
    end

    it "creates the named model partial" do
      assert_file "app/views/posts/_post.html.erb"
    end

    it "creates all MCP tool files" do
      %w[base index show create update destroy].each do |tool|
        assert_file "app/mcp/tools/posts/#{tool}_tool.rb"
      end
    end

    it "creates the MCP initializer" do
      assert_file "config/initializers/mcp.rb"
    end

    it "creates the context window partial" do
      assert_file "app/views/mcp/_context_window.html.erb"
    end
  end

  # -----------------------------------------------------------------------
  # 7. --turbo-controller combined with --mcp
  # -----------------------------------------------------------------------
  describe "with --turbo-controller and --mcp flags" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "--turbo-controller", "--mcp"]
    end

    it "creates the controller" do
      assert_file "app/controllers/posts_controller.rb"
    end

    it "does NOT create turbo_stream views" do
      assert_no_file "app/views/posts/create.turbo_stream.erb"
    end

    it "creates MCP tool files" do
      assert_file "app/mcp/tools/posts/index_tool.rb"
    end

    it "creates the context window partial" do
      assert_file "app/views/mcp/_context_window.html.erb"
    end
  end

  # -----------------------------------------------------------------------
  # 8. Multi-model: shared files are idempotent
  # -----------------------------------------------------------------------
  describe "multi-model scaffold with --mcp" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      # First scaffold
      run_generator ["Post", "title:string", "--mcp"]
      # Second scaffold
      run_generator ["Comment", "body:text", "--mcp"]
    end

    it "creates tools for both models" do
      assert_file "app/mcp/tools/posts/index_tool.rb"
      assert_file "app/mcp/tools/comments/index_tool.rb"
    end

    it "has only one application_tool.rb" do
      assert_file "app/mcp/tools/application_tool.rb"
    end

    it "has only one initializer" do
      assert_file "config/initializers/mcp.rb"
    end

    it "has only one authentication middleware" do
      assert_file "app/mcp/middleware/authentication.rb"
    end

    it "has only one provider_manager" do
      assert_file "app/mcp/llm/provider_manager.rb"
    end

    it "has only one context window partial" do
      assert_file "app/views/mcp/_context_window.html.erb"
    end

    it "has only one context window helper" do
      assert_file "app/mcp/helpers/context_window_helper.rb"
    end
  end

  # -----------------------------------------------------------------------
  # 9. mcp_type_for — unit tests for type mapping
  # -----------------------------------------------------------------------
  describe "#mcp_type_for" do
    # Instantiate directly so we don't share state with run_generator groups
    let(:gen) do
      described_class.new(["Post"], {}, destination_root: RailsAppHelpers::DESTINATION_ROOT)
    end

    def make_attr(type)
      instance_double("Rails::Generators::GeneratedAttribute", type: type)
    end

    it "maps :string to 'string'" do
      expect(gen.send(:mcp_type_for, make_attr(:string))).to eq("string")
    end

    it "maps :text to 'string'" do
      expect(gen.send(:mcp_type_for, make_attr(:text))).to eq("string")
    end

    it "maps :integer to 'integer'" do
      expect(gen.send(:mcp_type_for, make_attr(:integer))).to eq("integer")
    end

    it "maps :float to 'number'" do
      expect(gen.send(:mcp_type_for, make_attr(:float))).to eq("number")
    end

    it "maps :decimal to 'number'" do
      expect(gen.send(:mcp_type_for, make_attr(:decimal))).to eq("number")
    end

    it "maps :boolean to 'boolean'" do
      expect(gen.send(:mcp_type_for, make_attr(:boolean))).to eq("boolean")
    end

    it "maps :datetime to 'string'" do
      expect(gen.send(:mcp_type_for, make_attr(:datetime))).to eq("string")
    end

    it "maps :references to 'integer'" do
      expect(gen.send(:mcp_type_for, make_attr(:references))).to eq("integer")
    end

    it "maps unknown types to 'string'" do
      expect(gen.send(:mcp_type_for, make_attr(:jsonb))).to eq("string")
    end
  end

  # -----------------------------------------------------------------------
  # 10. mcp_attributes — excludes timestamps
  # -----------------------------------------------------------------------
  describe "#mcp_attributes" do
    it "excludes created_at and updated_at" do
      gen = described_class.new(
        ["Post", "title:string", "created_at:datetime", "updated_at:datetime"],
        {},
        destination_root: RailsAppHelpers::DESTINATION_ROOT
      )
      names = gen.send(:mcp_attributes).map(&:name)
      expect(names).to include("title")
      expect(names).not_to include("created_at")
      expect(names).not_to include("updated_at")
    end
  end

  # -----------------------------------------------------------------------
  # 11. turbo_any? / want_turbo_controller? / want_turbo_views? helpers
  # -----------------------------------------------------------------------
  describe "flag resolution helpers" do
    def gen_with_options(opts)
      described_class.new(
        ["Post"],
        opts,
        destination_root: RailsAppHelpers::DESTINATION_ROOT
      )
    end

    it "turbo_any? is false with no turbo flags" do
      g = gen_with_options(turbo: false, turbo_controller: false, turbo_view: false, mcp: false)
      expect(g.send(:turbo_any?)).to be false
    end

    it "turbo_any? is true with --turbo" do
      g = gen_with_options(turbo: true, turbo_controller: false, turbo_view: false, mcp: false)
      expect(g.send(:turbo_any?)).to be true
    end

    it "turbo_any? is true with --turbo-controller" do
      g = gen_with_options(turbo: false, turbo_controller: true, turbo_view: false, mcp: false)
      expect(g.send(:turbo_any?)).to be true
    end

    it "turbo_any? is true with --turbo-view" do
      g = gen_with_options(turbo: false, turbo_controller: false, turbo_view: true, mcp: false)
      expect(g.send(:turbo_any?)).to be true
    end

    it "want_turbo_controller? is false with only --turbo-view" do
      g = gen_with_options(turbo: false, turbo_controller: false, turbo_view: true, mcp: false)
      expect(g.send(:want_turbo_controller?)).to be false
    end

    it "want_turbo_controller? is true with --turbo" do
      g = gen_with_options(turbo: true, turbo_controller: false, turbo_view: false, mcp: false)
      expect(g.send(:want_turbo_controller?)).to be true
    end

    it "want_turbo_controller? is true with --turbo-controller" do
      g = gen_with_options(turbo: false, turbo_controller: true, turbo_view: false, mcp: false)
      expect(g.send(:want_turbo_controller?)).to be true
    end

    it "want_turbo_views? is false with only --turbo-controller" do
      g = gen_with_options(turbo: false, turbo_controller: true, turbo_view: false, mcp: false)
      expect(g.send(:want_turbo_views?)).to be false
    end

    it "want_turbo_views? is true with --turbo" do
      g = gen_with_options(turbo: true, turbo_controller: false, turbo_view: false, mcp: false)
      expect(g.send(:want_turbo_views?)).to be true
    end

    it "want_turbo_views? is true with --turbo-view" do
      g = gen_with_options(turbo: false, turbo_controller: false, turbo_view: true, mcp: false)
      expect(g.send(:want_turbo_views?)).to be true
    end
  end

  # -----------------------------------------------------------------------
  # 12. --template / -T flag — view_template helper
  # -----------------------------------------------------------------------
  describe "#view_template" do
    def gen_with_template(tpl)
      described_class.new(
        ["Post"],
        { template: tpl },
        destination_root: RailsAppHelpers::DESTINATION_ROOT
      )
    end

    it "returns 'default' when no template specified" do
      g = described_class.new(["Post"], {}, destination_root: RailsAppHelpers::DESTINATION_ROOT)
      expect(g.send(:view_template)).to eq("default")
    end

    it "returns 'default' for unknown template name" do
      expect(gen_with_template("foobar").send(:view_template)).to eq("default")
    end

    %w[default table card minimal].each do |tpl|
      it "returns '#{tpl}' for --template #{tpl}" do
        expect(gen_with_template(tpl).send(:view_template)).to eq(tpl)
      end
    end

    it "is case-insensitive" do
      expect(gen_with_template("TABLE").send(:view_template)).to eq("table")
    end
  end

  # -----------------------------------------------------------------------
  # 13. --template table — generates table views
  # -----------------------------------------------------------------------
  describe "with --turbo --template table" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo", "--template", "table"]
    end

    it "creates index.html.erb with a <table> element" do
      assert_file "app/views/posts/index.html.erb" do |content|
        expect(content).to match(/<table/)
        expect(content).to match(/<thead/)
        expect(content).to match(/<tbody/)
      end
    end

    it "creates _post.html.erb as a <tr> row inside turbo_frame_tag" do
      assert_file "app/views/posts/_post.html.erb" do |content|
        expect(content).to match(/turbo_frame_tag/)
        expect(content).to match(/<tr/)
        expect(content).to match(/<td/)
      end
    end

    it "creates the controller" do
      assert_file "app/controllers/posts_controller.rb"
    end

    it "creates turbo_stream views" do
      assert_file "app/views/posts/create.turbo_stream.erb"
    end
  end

  # -----------------------------------------------------------------------
  # 14. --template card — generates card views
  # -----------------------------------------------------------------------
  describe "with --turbo --template card" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "body:text", "--turbo", "--template", "card"]
    end

    it "creates index.html.erb with a CSS grid layout" do
      assert_file "app/views/posts/index.html.erb" do |content|
        expect(content).to match(/grid/)
      end
    end

    it "creates _post.html.erb as a card div" do
      assert_file "app/views/posts/_post.html.erb" do |content|
        expect(content).to match(/turbo_frame_tag/)
        expect(content).to match(/border/)
      end
    end
  end

  # -----------------------------------------------------------------------
  # 15. --template minimal — generates bare-bones views
  # -----------------------------------------------------------------------
  describe "with --turbo --template minimal" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "--turbo", "--template", "minimal"]
    end

    it "creates index.html.erb with a <ul> list" do
      assert_file "app/views/posts/index.html.erb" do |content|
        expect(content).to match(/<ul/)
      end
    end

    it "creates _post.html.erb as a <li> item" do
      assert_file "app/views/posts/_post.html.erb" do |content|
        expect(content).to match(/<li/)
      end
    end
  end

  # -----------------------------------------------------------------------
  # 16. --mcp generates the floating chat widget
  # -----------------------------------------------------------------------
  describe "with --mcp flag (chat widget)" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "--mcp"]
    end

    it "creates the McpChatsController" do
      assert_file "app/controllers/mcp_chats_controller.rb" do |content|
        expect(content).to match(/class McpChatsController/)
        expect(content).to match(/ContextWindowHelper/)
        expect(content).to match(/ProviderManager/)
      end
    end

    it "creates the chat turbo_stream views" do
      assert_file "app/views/mcp_chats/create.turbo_stream.erb" do |content|
        expect(content).to match(/mcp-chat-messages/)
      end
      assert_file "app/views/mcp_chats/error.turbo_stream.erb" do |content|
        expect(content).to match(/mcp-msg--error/)
      end
    end

    it "creates the floating chat widget partial" do
      assert_file "app/views/mcp/_chat_widget.html.erb" do |content|
        expect(content).to match(/mcp-fab/)
        expect(content).to match(/mcp-panel/)
        expect(content).to match(/AI Assistant/)
        expect(content).to match(/mcp_chats_path/)
      end
    end

    it "chat widget partial includes typing indicator" do
      assert_file "app/views/mcp/_chat_widget.html.erb" do |content|
        expect(content).to match(/mcp-typing/)
      end
    end
  end

  # -----------------------------------------------------------------------
  # 17. Multi-model: chat widget files are idempotent
  # -----------------------------------------------------------------------
  describe "multi-model --mcp: chat widget created only once" do
    before do
      allow_any_instance_of(described_class).to receive(:generate_model_and_migration)
      allow_any_instance_of(described_class).to receive(:generate_routes)
      run_generator ["Post", "title:string", "--mcp"]
      run_generator ["Comment", "body:text", "--mcp"]
    end

    it "has only one McpChatsController" do
      assert_file "app/controllers/mcp_chats_controller.rb"
    end

    it "has only one chat widget partial" do
      assert_file "app/views/mcp/_chat_widget.html.erb"
    end
  end
end
