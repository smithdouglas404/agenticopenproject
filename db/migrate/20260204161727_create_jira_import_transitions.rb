# frozen_string_literal: true

class CreateJiraImportTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :jira_import_transitions do |t|
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.jsonb :metadata, default: {}
      t.integer :sort_key, null: false
      t.integer :jira_import_id, null: false
      t.boolean :most_recent, null: false

      # If you decide not to include an updated timestamp column in your transition
      # table, you'll need to configure the `updated_timestamp_column` setting in your
      # migration class.
      t.timestamps null: false
    end

    # Foreign keys are optional, but highly recommended
    add_foreign_key :jira_import_transitions, :jira_imports

    add_index(:jira_import_transitions,
              %i(jira_import_id sort_key),
              unique: true,
              name: "index_jira_import_transitions_parent_sort")
    add_index(:jira_import_transitions,
              %i(jira_import_id most_recent),
              unique: true,
              where: "most_recent",
              name: "index_jira_import_transitions_parent_most_recent")
  end
end
