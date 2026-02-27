# extendable-rails v2 — Integration & Extension Guide

A step-by-step guide to installing the gem, generating your first scaffold,
understanding every generated file, and extending the gem for your own use case.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Quick start — your first scaffold](#2-quick-start)
3. [Generator flags reference](#3-generator-flags-reference)
4. [Turbo integration walkthrough](#4-turbo-integration-walkthrough)
5. [View template styles](#5-view-template-styles)
6. [Adding your own custom templates](#6-adding-your-own-custom-templates)
7. [MCP integration walkthrough](#7-mcp-integration-walkthrough)
8. [MCP Context Window UI](#8-mcp-context-window-ui)
9. [MCP Floating Chat Widget](#9-mcp-floating-chat-widget)
10. [LLM provider configuration](#10-llm-provider-configuration)
11. [Authentication strategies](#11-authentication-strategies)
12. [Extending generated code](#12-extending-generated-code)
13. [Testing](#13-testing)

---

## 1. Installation

### Gemfile

```ruby
gem "extendable-rails", "~> 2.0"
```

Run:

```
bundle install
```

**That's it.** `turbo-rails` and `mcp` are declared as runtime dependencies
and are pulled in automatically. You do **not** need to add them separately.

### Minimum requirements

| Dependency  | Version  |
|-------------|----------|
| Ruby        | >= 2.7   |
| Rails       | >= 5.2   |
| mcp gem     | >= 0.7   |
| turbo-rails | >= 1.0   |

### Rails 5/6 note

Rails 5.2 / 6.x do not ship `turbo-rails`. The gem is added as a dependency so
`bundle install` installs it. Run the Turbo install task once after bundling:

```
bundle exec rails turbo:install
```

---

## 2. Quick start

### 2a. Standard Rails scaffold (unchanged behaviour)

No flags → delegates to Rails' own scaffold unchanged:

```
rails generate extendable:scaffold Post title:string body:text
```

### 2b. Turbo scaffold — all defaults

```
rails generate extendable:scaffold Post title:string body:text --turbo
# short alias
rails generate extendable:scaffold Post title:string body:text -t
```

### 2c. Turbo scaffold with table layout

```
rails generate extendable:scaffold Post title:string body:text --turbo --template table
# short aliases
rails generate extendable:scaffold Post title:string body:text -t -T table
```

### 2d. MCP scaffold

```
rails generate extendable:scaffold Post title:string body:text --mcp
rails generate extendable:scaffold Post title:string body:text -m
```

### 2e. Everything — Turbo (card layout) + MCP + chat widget

```
rails generate extendable:scaffold Post title:string body:text --turbo --template card --mcp
```

---

## 3. Generator flags reference

| Flag | Alias | Description |
|------|-------|-------------|
| _(none)_ | | Standard Rails scaffold |
| `--turbo` | `-t` | Turbo controller **+** all view files |
| `--turbo-controller` | `-tc` | Turbo controller **only** (no views) |
| `--turbo-view` | `-tv` | Views **only** (no controller) |
| `--template STYLE` | `-T STYLE` | View template style (see Section 5) |
| `--mcp` | `-m` | MCP tool files + chat widget |

### Flag combination matrix

| Flags | Controller | Turbo Stream views | HTML views | MCP tools | Chat widget |
|-------|:---:|:---:|:---:|:---:|:---:|
| _(none)_ | standard | standard | standard | — | — |
| `-t` | ✓ | ✓ | ✓ | — | — |
| `-tc` | ✓ | — | — | — | — |
| `-tv` | — | ✓ | ✓ | — | — |
| `-m` | — | — | — | ✓ | ✓ |
| `-t -m` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `-tc -m` | ✓ | — | — | ✓ | ✓ |

---

## 4. Turbo integration walkthrough

### Step 1 — Add to Gemfile and bundle

```ruby
gem "extendable-rails", "~> 2.0"
```

```
bundle install
```

### Step 2 — Generate

```
rails generate extendable:scaffold Post title:string published:boolean --turbo
rails db:migrate
```

### Step 3 — Verify routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :posts
  root "posts#index"
end
```

### Step 4 — Start server

```
rails server
```

Open `http://localhost:3000/posts`. Creating, editing, and deleting records
updates the page without a full reload.

### Step 5 — Controller-only mode

When you already have views and only want the Turbo-aware controller:

```
rails generate extendable:scaffold Comment body:text --turbo-controller
```

### Step 6 — Views-only mode

When you already have a controller and want Turbo Stream views added:

```
rails generate extendable:scaffold Comment body:text --turbo-view
```

---

## 5. View template styles

The `--template` (or `-T`) flag selects which HTML layout extendable-rails
uses for the generated views. The Turbo Stream views (`.turbo_stream.erb`)
are **identical across all styles** — only the HTML views differ.

### `default` (no flag needed)

The classic extendable-rails layout:

- `index`: `<div id="resources">` containing rendered partials
- `_partial`: `turbo_frame_tag` around a simple `<div>` with `<p>` fields
- Best for: quick prototypes, minimal customisation needed

```
rails generate extendable:scaffold Post title:string -t
# same as:
rails generate extendable:scaffold Post title:string -t -T default
```

### `table`

A data-dense tabular layout:

- `index`: `<table>` with `<thead>` column headers and `<tbody id="resources">`
- `_partial`: `<tr>` row inside `turbo_frame_tag` — rows update in place
- `show`: two-column `<table>` with label/value pairs
- Form fields have consistent spacing and focus styles
- Best for: admin panels, dashboards, data-heavy resources

```
rails generate extendable:scaffold Post title:string body:text -t -T table
```

### `card`

A responsive card grid layout:

- `index`: CSS grid (`display:grid; grid-template-columns: repeat(auto-fill, minmax(280px,1fr))`)
- `_partial`: card with header (id + first attribute), body (remaining attributes), footer link
- `show`: full-width card with coloured header bar
- Best for: content collections, image galleries, product listings

```
rails generate extendable:scaffold Post title:string body:text -t -T card
```

### `minimal`

Bare-bones HTML, zero inline CSS:

- `index`: `<ul id="resources">` list
- `_partial`: `<li>` with plain text and `[show] [edit] [del]` links
- Form uses standard `<br>` line breaks
- Best for: APIs where you control all styling, prototyping with your own CSS framework

```
rails generate extendable:scaffold Post title:string -t -T minimal
```

---

## 6. Adding your own custom templates

You can create additional template styles without modifying the gem.

### Step 1 — Create your template directory

```
mkdir -p lib/templates/extendable/scaffold/turbo/views/mytemplate
```

### Step 2 — Create the required files

You need six HTML files:

```
lib/templates/extendable/scaffold/turbo/views/mytemplate/
  index.html.erb.tt
  show.html.erb.tt
  new.html.erb.tt
  edit.html.erb.tt
  _form.html.erb.tt
  _singular.html.erb.tt     ← named partial (e.g. _post.html.erb)
```

Template files use ERB with `<%= %>` for generator-time interpolation.
Inside `.tt` files, `<%%=` becomes `<%= ` in the output (escaped ERB).

The following generator helpers are available inside every `.tt` file:

| Helper | Returns | Example |
|--------|---------|---------|
| `singular_table_name` | `"post"` | `@post` |
| `plural_table_name` | `"posts"` | `@posts` |
| `class_name` | `"Post"` | `Post.find(id)` |
| `human_name` | `"Post"` | labels |
| `controller_file_path` | `"posts"` | view directory |
| `index_helper` | `"posts"` | `posts_path` |
| `attributes` | Array of attribute objects | field loop |
| `attributes_names` | Array of string names | `permit(...)` |

### Step 3 — Tell the generator to find your templates

In `config/application.rb`:

```ruby
config.generators do |g|
  g.source_root File.expand_path("lib/templates", Rails.root)
end
```

Or add a `config/initializers/extendable_rails.rb`:

```ruby
Extendable::Generators::ScaffoldGenerator.source_paths.unshift(
  Rails.root.join("lib", "templates", "extendable", "scaffold")
)
```

### Step 4 — Use your template

The generator resolution order is: **your app templates first**, then gem templates.
Simply pass your folder name as the `--template` value:

```
rails generate extendable:scaffold Post title:string --turbo --template mytemplate
```

Because `VALID_TEMPLATES` in the generator only validates against the built-in
list and falls back to `"default"` for unknown values, you need to override
`view_template` in an initializer to allow custom names:

```ruby
# config/initializers/extendable_rails.rb
module Extendable
  module Generators
    class ScaffoldGenerator
      VALID_TEMPLATES = (superclass::VALID_TEMPLATES + %w[mytemplate]).freeze
    end
  end
end
```

Or simply keep your template name in sync with `VALID_TEMPLATES` by reopening
the constant once in a generator config file.

### Step 5 — Example index.html.erb.tt with Tailwind CSS

```erb
<p style="color:green"><%%= notice %></p>

<div class="flex items-center justify-between mb-6">
  <h1 class="text-2xl font-bold"><%= human_name.pluralize %></h1>
  <%%= link_to "New <%= human_name %>",
        new_<%= singular_table_name %>_path,
        class: "btn btn-primary" %>
</div>

<div id="modal"></div>

<div id="<%= plural_table_name %>" class="space-y-4">
  <%%= render @<%= plural_table_name %> %>
</div>
```

---

## 7. MCP integration walkthrough

### Step 1 — Bundle

```ruby
gem "extendable-rails", "~> 2.0"
```

```
bundle install
```

### Step 2 — Generate

```
rails generate extendable:scaffold Product name:string price:decimal --mcp
rails db:migrate
```

Generated files (first run also creates shared infrastructure):

```
app/
  controllers/
    mcp_chats_controller.rb             # chat widget backend
  mcp/
    tools/
      application_tool.rb
      products/
        base_tool.rb
        index_tool.rb   (tool_name "product_list")
        show_tool.rb    (tool_name "product_show")
        create_tool.rb  (tool_name "product_create")
        update_tool.rb  (tool_name "product_update")
        destroy_tool.rb (tool_name "product_destroy")
    middleware/
      authentication.rb
    llm/
      provider.rb
      provider_manager.rb
    helpers/
      context_window_helper.rb
  views/
    mcp/
      _context_window.html.erb
      _chat_widget.html.erb
    mcp_chats/
      create.turbo_stream.erb
      error.turbo_stream.erb
config/
  initializers/mcp.rb
```

### Step 3 — Configure the initializer

```ruby
# config/initializers/mcp.rb
ExtendableRails.configure do |config|
  config.mcp_auth_strategy = :api_key
  config.mcp_api_key = ENV["MCP_API_KEY"]

  config.add_llm_provider(
    name:    :anthropic,
    api_key: ENV["ANTHROPIC_API_KEY"],
    model:   "claude-opus-4-20250514"   # maximum context: 200 000 tokens
  )
end
```

### Step 4 — Mount the MCP server

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :products

  # MCP tools endpoint
  mount Rails.application.config.mcp_server, at: "/mcp"

  # Chat widget routes (injected automatically by the generator)
  resources :mcp_chats, only: [:create] do
    collection { delete :clear }
  end
end
```

### Step 5 — Add the chat widget to your layout

```erb
<%# app/views/layouts/application.html.erb — just before </body> %>
  <%= render "mcp/chat_widget" %>
</body>
```

### Step 6 — Start the server and test

```
rails server
```

Open any page. A blue chat bubble appears in the bottom-right corner.
Click it to open the AI chat panel.

---

## 8. MCP Context Window UI

The context window shows how many tokens have been used vs the model's limit.

### Step 1 — Include the helper in your controller

```ruby
class ChatController < ApplicationController
  include Mcp::ContextWindowHelper

  def ask
    response = ExtendableRails::Mcp::Llm::ProviderManager.chat(
      messages: [{ role: "user", content: params[:q] }]
    )
    record_usage(response, model: "claude-opus-4-20250514")
    @answer = response.dig("content", 0, "text")
  end
end
```

### Step 2 — Render the partial

```erb
<%= render "mcp/context_window", **context_summary %>
```

Colour coding:

| Remaining | Colour | Status |
|-----------|--------|--------|
| >= 30 %   | Green  | ok |
| 10–29 %   | Amber  | warning |
| < 10 %    | Red    | critical |

### Step 3 — Override context limits

```ruby
ExtendableRails.configure do |config|
  config.context_limits = {
    "my-finetuned-model" => 32_000,
    "gpt-4o"             => 200_000
  }
end
```

### Step 4 — Maximum context: use claude-opus-4

To maximise available context (200 000 tokens):

```ruby
config.add_llm_provider(
  name:    :anthropic,
  api_key: ENV["ANTHROPIC_API_KEY"],
  model:   "claude-opus-4-20250514"
)
```

The context window UI will automatically display 200 000 as the limit for
any model prefixed with `"claude-opus-4"`.

---

## 9. MCP Floating Chat Widget

The chat widget is a floating panel generated when you use `--mcp`. It lets
users interact with the LLM directly from any page in your Rails app.

### What it looks like

```
┌─────────────────────────────────────┐
│ AI  AI Assistant           [Clear] ✕│
├─────────────────────────────────────┤
│  AI  Hi! I'm your AI assistant.     │
│      I can help you manage records…│
│                                     │
│              How many posts?  [you] │
│  AI  There are 42 posts.            │
│                                     │
│ ████████████░░░░░░░  72% remaining  │◄── context bar
├─────────────────────────────────────┤
│ [Ask anything…              ] [➤]  │
└─────────────────────────────────────┘
                            [💬]  ◄── FAB
```

### Step 1 — Add the widget to your layout

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>…</head>
  <body>
    <%= yield %>
    <%= render "mcp/chat_widget" %>   <%# add this line %>
  </body>
</html>
```

### Step 2 — Configure the default greeting

The greeting shown on first open can be customised:

**Option A — environment variable:**
```
MCP_CHAT_GREETING="Hi! I can help you manage products, orders, and customers."
```

**Option B — Rails config:**
```ruby
# config/initializers/mcp.rb (or any initializer)
Rails.application.config.mcp_chat_greeting =
  "Welcome! Ask me to list products, create an order, or find a customer."
```

### Step 3 — Customise the system prompt

The AI's behaviour is controlled by a system prompt. Override it:

**Option A — environment variable:**
```
MCP_CHAT_SYSTEM_PROMPT="You are a shop assistant. Only help with product and order queries."
```

**Option B — Rails config:**
```ruby
Rails.application.config.mcp_chat_system_prompt = <<~PROMPT
  You are a helpful assistant for Acme Shop.
  Available operations:
  - Products: list, show, create, update, destroy
  - Orders: list, show, create
  Always be concise. Never make up data.
PROMPT
```

### Step 4 — Restrict chat to authenticated users

Add a `before_action` to `McpChatsController`:

```ruby
# app/controllers/mcp_chats_controller.rb
class McpChatsController < ApplicationController
  before_action :authenticate_user!   # Devise
  # or
  before_action :require_login        # your own auth
  include Mcp::ContextWindowHelper
  # … rest of generated code …
end
```

### Step 5 — Conversation history

The widget stores conversation history in `session[:mcp_messages]`. This is
per-browser-session and is cleared when the user clicks "Clear".

For persistent history across sessions, override `build_messages` in the controller:

```ruby
def build_messages
  current_user.chat_messages.last(20).map do |m|
    { role: m.role, content: m.content }
  end
end
```

### Step 6 — Style the widget with Tailwind (or any framework)

The widget uses only inline styles so it works without any CSS framework.
To switch to Tailwind, edit `app/views/mcp/_chat_widget.html.erb` and
replace the `<style>` block + inline styles with Tailwind classes.

The key CSS class hooks are:

| Class | Element |
|-------|---------|
| `.mcp-fab` | Floating action button |
| `.mcp-panel` | Chat panel container |
| `.mcp-panel.mcp-open` | Panel when visible |
| `.mcp-panel__header` | Panel header bar |
| `.mcp-panel__body` | Scrollable message list |
| `.mcp-msg--user` | User message row |
| `.mcp-msg--assistant` | AI message row |
| `.mcp-msg--error` | Error message row |
| `.mcp-msg__bubble` | Message bubble |
| `.mcp-panel__footer` | Input area |

---

## 10. LLM provider configuration

Providers are tried in priority order. On repeated failure the circuit
breaker opens and the next provider is used automatically.

```ruby
ExtendableRails.configure do |config|
  # Primary — maximum context (200k tokens)
  config.add_llm_provider(
    name:         :anthropic,
    api_key:      ENV["ANTHROPIC_API_KEY"],
    model:        "claude-opus-4-20250514",
    max_failures: 3,
    cooldown:     60
  )

  # Fallback 1
  config.add_llm_provider(
    name:    :openai,
    api_key: ENV["OPENAI_API_KEY"],
    model:   "gpt-4o"
  )

  # Fallback 2
  config.add_llm_provider(
    name:    :gemini,
    api_key: ENV["GEMINI_API_KEY"],
    model:   "gemini-2.0-flash"
  )

  # Fallback 3
  config.add_llm_provider(
    name:    :deepseek,
    api_key: ENV["DEEPSEEK_API_KEY"],
    model:   "deepseek-chat"
  )
end
```

### Proc-based API keys (multi-tenant / rotated keys)

```ruby
config.add_llm_provider(
  name:    :anthropic,
  api_key: -> { Rails.application.credentials.anthropic_api_key },
  model:   "claude-opus-4-20250514"
)
```

---

## 11. Authentication strategies

### No auth (development default)

```ruby
config.mcp_auth_strategy = :none
```

### API key

```ruby
config.mcp_auth_strategy = :api_key
config.mcp_api_key        = ENV["MCP_API_KEY"]
```

Clients send: `Authorization: Bearer <your-api-key>`

### OAuth token introspection

```ruby
config.mcp_auth_strategy = :oauth
config.oauth_token_url    = "https://your-auth-server.com/oauth/introspect"
```

### Applying the middleware

```ruby
# config/routes.rb
authenticated_mcp = Rack::Builder.new do
  use ExtendableRails::Mcp::Authentication
  run Rails.application.config.mcp_server
end
mount authenticated_mcp, at: "/mcp"
```

---

## 12. Extending generated code

### 12a. Add logging to all tools

```ruby
# app/mcp/tools/application_tool.rb
module Tools
  class ApplicationTool < MCP::Tool
    def self.call(**args)
      Rails.logger.info("[MCP] #{name} called with #{args.inspect}")
      super
    end
  end
end
```

### 12b. Scope a resource's tools

```ruby
# app/mcp/tools/posts/base_tool.rb
module Tools
  module Posts
    class BaseTool < Tools::ApplicationTool
      def self.scope = Post.published
    end
  end
end
```

### 12c. Create a custom tool

```ruby
# app/mcp/tools/posts/search_tool.rb
module Tools
  module Posts
    class SearchTool < BaseTool
      tool_name "post_search"
      description "Full-text search across post title and body"

      input_schema(
        properties: { query: { type: "string" } },
        required:   ["query"]
      )

      class << self
        def call(query:, server_context: nil)
          results = Post.where("title ILIKE :q OR body ILIKE :q", q: "%#{query}%")
          MCP::Tool::Response.new([{ type: "text", text: results.to_json }])
        end
      end
    end
  end
end
```

Auto-discovery picks it up without any registration step.

### 12d. Persist chat history across sessions

```ruby
# app/controllers/mcp_chats_controller.rb
private

def build_messages
  current_user.mcp_conversations
              .order(:created_at)
              .last(20)
              .map { |m| { role: m.role, content: m.content } }
end
```

### 12e. Add context limits for custom models

```ruby
ExtendableRails.configure do |config|
  config.context_limits = { "my-finetuned-v2" => 16_000 }
end
```

---

## 13. Testing

```
bundle exec rspec
```

### Testing a custom tool

```ruby
RSpec.describe Tools::Posts::SearchTool do
  it "returns matching posts" do
    post = create(:post, title: "Hello World")
    response = described_class.call(query: "Hello")
    json = JSON.parse(response.content.first[:text])
    expect(json.first["id"]).to eq(post.id)
  end
end
```

### Testing context window helpers

```ruby
RSpec.describe ExtendableRails::Mcp::ContextWindow do
  let(:obj) { Class.new { include ExtendableRails::Mcp::ContextWindow }.new }

  it "parses Anthropic usage" do
    obj.record_usage(
      { "usage" => { "input_tokens" => 1000, "output_tokens" => 500 } },
      model: "claude-opus-4-20250514"
    )
    expect(obj.context_used_tokens).to eq(1500)
    expect(obj.context_limit_tokens).to eq(200_000)
    expect(obj.context_status).to eq(:ok)
  end
end
```

### Testing the chat widget controller

```ruby
RSpec.describe McpChatsController, type: :controller do
  before do
    allow(ExtendableRails::Mcp::Llm::ProviderManager).to receive(:chat).and_return(
      { "content" => [{ "type" => "text", "text" => "There are 5 posts." }],
        "usage"   => { "input_tokens" => 100, "output_tokens" => 20 } }
    )
  end

  it "returns a turbo_stream response" do
    post :create, params: { message: "How many posts?" }, format: :turbo_stream
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
  end

  it "accumulates messages in session" do
    post :create, params: { message: "Hello" }, format: :turbo_stream
    expect(session[:mcp_messages].length).to eq(2)   # user + assistant
  end
end
```

---

## 11. Error Reporting & Notifications

extendable-rails ships with a pluggable error-reporting system. Any exception
raised by the LLM provider chain, the MCP middleware, or your own code can be
captured, tagged with a **severity level**, and fanned out to one or more
**notifiers** — Slack, Email, a logger, or any custom third-party integration.

### 11.1. Severity Levels

Four ordered levels are available. Each has a descriptive message you can
surface in alerts:

| Level     | Rank | Description                                      |
|-----------|------|--------------------------------------------------|
| `normal`  | 0    | Informational event – no action required         |
| `warning` | 1    | Unexpected condition – system recovered automatically |
| `high`    | 2    | Significant failure – user experience degraded   |
| `critical`| 3    | Critical failure – immediate attention required  |

```ruby
ExtendableRails::ErrorReporting::Severity.label(:critical)       # => "Critical"
ExtendableRails::ErrorReporting::Severity.description(:warning)
# => "Unexpected condition – system recovered automatically"
ExtendableRails::ErrorReporting::Severity.meets?(:high, threshold: :warning) # => true
```

### 11.2. Registering Notifiers

Add notifiers in `config/initializers/extendable_rails.rb`:

```ruby
ExtendableRails.configure do |config|
  # Always log locally
  config.add_error_notifier :logger

  # Slack alerts for warnings and above
  config.add_error_notifier :slack,
    webhook_url: ENV["SLACK_WEBHOOK_URL"],
    channel:     "#alerts",
    threshold:   :warning

  # Email the on-call team for high/critical
  config.add_error_notifier :email,
    to:        %w[ops@example.com cto@example.com],
    from:      "alerts@example.com",
    threshold: :high
end
```

Each notifier can have its own **threshold** — only events at or above that
severity are dispatched to it.

### 11.3. Reporting Errors

**Report an exception directly:**

```ruby
begin
  risky_operation!
rescue => e
  ExtendableRails.report_error(e,
    severity: :high,
    context:  { user_id: current_user.id, request_id: request.uuid },
    source:   "CheckoutController#create")
  raise
end
```

**Report a plain string (no exception):**

```ruby
ExtendableRails.report_error("Payment gateway returned empty body",
  severity: :warning,
  context:  { gateway: :stripe, order_id: order.id })
```

**Wrap a block** — captures, reports, and re-raises by default:

```ruby
ExtendableRails.capture(severity: :critical, source: "Jobs::NightlySync") do
  SyncService.new.perform!
end
```

Pass `reraise: false` to suppress, or `swallow: [SomeError]` to selectively
swallow specific error classes:

```ruby
ExtendableRails.capture(swallow: [Net::TimeoutError], severity: :warning) do
  external_api.ping
end
```

**Severity shortcuts:**

```ruby
ExtendableRails.error_reporter.warning("cache miss",  context: { key: "user:42" })
ExtendableRails.error_reporter.critical(e,            source: "Billing#charge")
```

### 11.4. Built-in Notifiers

#### Logger

Maps severities to standard log levels (`normal→info`, `warning→warn`,
`high→error`, `critical→fatal`). Writes to `Rails.logger` when available.

```ruby
config.add_error_notifier :logger, threshold: :normal
```

#### Slack

Posts rich attachments via Incoming Webhooks. Colour-codes by severity and
includes exception class, source, context, and the first 8 backtrace lines.

```ruby
config.add_error_notifier :slack,
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  channel:     "#backend-alerts",
  username:    "extendable-rails",
  threshold:   :warning
```

#### Email

Sends a plain-text email via the `mail` gem, reusing your Rails app's SMTP
delivery configuration when ActionMailer is loaded.

```ruby
config.add_error_notifier :email,
  to:             %w[ops@example.com],
  from:           "alerts@example.com",
  subject_prefix: "[PRODUCTION]",
  threshold:      :high
```

### 11.5. Custom Third-Party Notifiers

All notifiers inherit from a common base class. To ship errors to **any**
third-party service, subclass `ExtendableRails::ErrorReporting::Notifiers::Base`
and implement `#deliver(event)`:

```ruby
# lib/notifiers/pager_duty_notifier.rb
class PagerDutyNotifier < ExtendableRails::ErrorReporting::Notifiers::Base
  SEVERITY_MAP = { normal: "info", warning: "warning",
                   high: "error",  critical: "critical" }.freeze

  def initialize(routing_key:, **opts)
    super(**opts)                 # <- passes :threshold to Base
    @routing_key = routing_key
  end

  def deliver(event)
    payload = {
      routing_key: @routing_key,
      event_action: "trigger",
      dedup_key:    event.fingerprint,
      payload: {
        summary:        event.summary,
        severity:       SEVERITY_MAP[event.severity],
        source:         event.source || "extendable-rails",
        timestamp:      event.timestamp.iso8601,
        custom_details: event.to_h
      }
    }
    post_json("https://events.pagerduty.com/v2/enqueue", payload)
  end

  private

  def post_json(url, body)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port).tap { |h| h.use_ssl = true }
    req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    req.body = JSON.generate(body)
    http.request(req)
  end
end

# config/initializers/extendable_rails.rb
ExtendableRails.configure do |c|
  c.add_error_notifier PagerDutyNotifier.new(
    routing_key: ENV["PAGERDUTY_ROUTING_KEY"],
    threshold:   :high
  )
end
```

The base class gives you for free:

* **Threshold filtering** — `#notify` skips events below `threshold`
* **Exception swallowing** — a crashing notifier never brings down the app
* **Helpers** — `#truncate(str, max:)` and `#format_backtrace(event, lines:)`

### 11.6. The ErrorEvent Object

Every notifier receives an `ErrorEvent` with these readers:

| Method                 | Returns                                      |
|------------------------|----------------------------------------------|
| `id`                   | UUID for this specific event                 |
| `severity`             | `:normal`, `:warning`, `:high`, `:critical`  |
| `severity_label`       | `"Critical"` etc.                            |
| `severity_description` | Human-readable description of the level      |
| `message`              | Error message                                |
| `exception`            | The raised `Exception` (or `nil`)            |
| `exception_class`      | `"RuntimeError"` etc. (or `nil`)             |
| `context`              | `Hash` of arbitrary metadata (frozen)        |
| `source`               | Logical origin string (e.g. `"Foo#bar"`)     |
| `backtrace`            | `Array<String>` (empty when no exception)    |
| `timestamp`            | UTC `Time`                                   |
| `fingerprint`          | Stable ID for grouping identical errors      |
| `summary`              | One-line formatted summary                   |
| `to_h`                 | `Hash` suitable for JSON serialisation       |

### 11.7. Automatic Reporting from LLM Failover

The `ProviderManager` already reports automatically:

* Each individual provider failure → `:warning`
* All-providers-exhausted → `:critical`

So once you register a notifier, LLM failures show up immediately with no
extra code.
