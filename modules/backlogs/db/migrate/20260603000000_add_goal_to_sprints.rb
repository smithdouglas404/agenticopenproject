# frozen_string_literal: true

class AddGoalToSprints < ActiveRecord::Migration[8.1]
  def change
    add_column :sprints, :goal, :text
  end
end
