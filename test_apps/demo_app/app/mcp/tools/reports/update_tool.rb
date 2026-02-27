# frozen_string_literal: true

module Tools
  module Reports
    # Updates an existing report.
    class UpdateTool < BaseTool
      tool_name "report_update"
      description "Update an existing report"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the report to update" },
          title: { type: "string", description: "Title" },
          category: { type: "string", description: "Category" },
          status: { type: "string", description: "Status" },
          notes: { type: "string", description: "Notes" },
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil, **attrs)
          record = Report.find(id)
          permitted = attrs.slice(:title, :category, :status, :notes)
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
