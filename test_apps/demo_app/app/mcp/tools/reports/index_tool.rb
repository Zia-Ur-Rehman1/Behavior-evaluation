# frozen_string_literal: true

module Tools
  module Reports
    # Lists all reports.
    class IndexTool < BaseTool
      tool_name "report_list"
      description "List all reports"

      input_schema(
        properties: {}
      )

      class << self
        def call(server_context: nil)
          records = Report.all
          MCP::Tool::Response.new([{
            type: "text",
            text: records.to_json
          }])
        end
      end
    end
  end
end
