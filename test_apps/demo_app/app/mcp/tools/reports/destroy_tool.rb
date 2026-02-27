# frozen_string_literal: true

module Tools
  module Reports
    # Deletes a report.
    class DestroyTool < BaseTool
      tool_name "report_destroy"
      description "Delete a report"

      input_schema(
        properties: {
          id: { type: "integer", description: "The ID of the report to delete" }
        },
        required: ["id"]
      )

      class << self
        def call(id:, server_context: nil)
          record = Report.find(id)
          record.destroy!
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.generate({ message: "Report #{id} was successfully deleted" })
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
