# frozen_string_literal: true

class AddCursorColumnToJiraImports < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_imports, :cursor, :jsonb
  end
end
