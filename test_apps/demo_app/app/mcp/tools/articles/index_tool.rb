# frozen_string_literal: true

module Tools
  module Articles
    # Lists all articles.
    class IndexTool < BaseTool
      tool_name "article_list"
      description "List all articles"

      input_schema(
        properties: {}
      )

      class << self
        def call(server_context: nil)
          records = Article.all
          MCP::Tool::Response.new([{
            type: "text",
            text: records.to_json
          }])
        end
      end
    end
  end
end
