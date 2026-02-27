# frozen_string_literal: true

module Tools
  module Reports
    # Retrieves a single report by ID.
    class ShowTool < BaseTool
      tool_name "report_show"
      description "Get a single report by ID"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the report" }
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil)
          record = Report.find(id)
          MCP::Tool::Response.new([{
            type: "text",
            text: record.to_json
          }])
        rescue ActiveRecord::RecordNotFound
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ error: "Report with id=#{id} was not found" })
          }])
        end
      end
    end
  end
end
