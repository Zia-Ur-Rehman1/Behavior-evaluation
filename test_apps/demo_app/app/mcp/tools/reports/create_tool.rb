# frozen_string_literal: true

module Tools
  module Reports
    # Creates a new report.
    class CreateTool < BaseTool
      tool_name "report_create"
      description "Create a new report"

      input_schema(
        properties: {
          title: { type: "string", description: "Title" },
          category: { type: "string", description: "Category" },
          status: { type: "string", description: "Status" },
          notes: { type: "string", description: "Notes" },
        },
        required: ["title", "category", "status", "notes"]
      )

      class << self
        def call(title:, category:, status:, notes:, server_context: nil)
          record = Report.create!(
            title: title,
            category: category,
            status: status,
            notes: notes,
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
