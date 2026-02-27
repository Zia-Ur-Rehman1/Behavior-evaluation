# frozen_string_literal: true

module Tools
  module Articles
    # Deletes a article.
    class DestroyTool < BaseTool
      tool_name "article_destroy"
      description "Delete a article"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the article to delete" }
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil)
          record = Article.find(id)
          record.destroy!
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ message: "Article #{id} was successfully deleted" })
          }])
        rescue ActiveRecord::RecordNotFound => e
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ error: e.message })
          }])
        end
      end
    end
  end
end
