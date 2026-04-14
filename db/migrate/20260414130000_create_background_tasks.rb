# frozen_string_literal: true

class CreateBackgroundTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :background_tasks do |t|
      t.string :task_type, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :background_tasks, %i[task_type status]
  end
end
