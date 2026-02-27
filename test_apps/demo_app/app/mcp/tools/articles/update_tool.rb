# frozen_string_literal: true

module Tools
  module Articles
    # Updates an existing article.
    class UpdateTool < BaseTool
      tool_name "article_update"
      description "Update an existing article"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the article to update" },
          title: { type: "string", description: "Title" },
          body: { type: "string", description: "Body" },
          published: { type: "boolean", description: "Published" },
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil, **attrs)
          record = Article.find(id)
          permitted = attrs.slice(:title, :body, :published)
          record.update!(permitted)
          MCP::Tool::Response.new([{
            type: "text",
            text: record.to_json
          }])
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ error: e.message })
          }])
        end
      end
    end
  end
end
