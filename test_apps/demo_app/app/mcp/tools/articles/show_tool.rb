# frozen_string_literal: true

module Tools
  module Articles
    # Retrieves a single article by ID.
    class ShowTool < BaseTool
      tool_name "article_show"
      description "Get a single article by ID"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the article" }
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil)
          record = Article.find(id)
          MCP::Tool::Response.new([{
            type: "text",
            text: record.to_json
          }])
        rescue ActiveRecord::RecordNotFound
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ error: "Article with id=#{id} was not found" })
          }])
        end
      end
    end
  end
end
