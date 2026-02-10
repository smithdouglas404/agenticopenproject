# frozen_string_literal: true

class RemoveJiraImportStatus < ActiveRecord::Migration[8.0]
  def change
    remove_column :jira_imports, :status, :string
  end
end
