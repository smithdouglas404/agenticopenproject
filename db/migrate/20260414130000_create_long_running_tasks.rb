# frozen_string_literal: true

class CreateLongRunningTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :long_running_tasks do |t|
      t.integer :task_type, null: false
      t.integer :status,    null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.datetime :aborted_at
      t.string :description
      t.references :created_by, foreign_key: { to_table: :users }
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end

    add_index :long_running_tasks, %i[task_type status]
  end
end
