# frozen_string_literal: true

class AddLifecycleStageToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :lifecycle_stage, :integer, default: nil
    add_index :projects, :lifecycle_stage

    create_table :lifecycle_stage_transitions do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :from_stage
      t.integer :to_stage, null: false
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :lifecycle_stage_transitions, %i[project_id created_at]
  end
end
