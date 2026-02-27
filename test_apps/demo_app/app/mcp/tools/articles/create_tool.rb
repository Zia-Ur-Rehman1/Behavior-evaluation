# frozen_string_literal: true

module Tools
  module Articles
    # Creates a new article.
    class CreateTool < BaseTool
      tool_name "article_create"
      description "Create a new article"

      input_schema(
        properties: {
          title: { type: "string", description: "Title" },
          body: { type: "string", description: "Body" },
          published: { type: "boolean", description: "Published" },
        },
        required: ["title", "body", "published"]
      )

      class << self
        def call(title:, body:, published:, server_context: nil)
          record = Article.create!(
            title: title,
            body: body,
            published: published,
          )
          MCP::Tool::Response.new([{
            type: "text",
            text: record.to_json
          }])
        rescue ActiveRecord::RecordInvalid => e
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ error: e.message })
          }])
        end
      end
    end
  end
end
