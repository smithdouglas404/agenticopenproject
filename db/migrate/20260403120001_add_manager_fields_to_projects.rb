# frozen_string_literal: true

class AddManagerFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :portfolio_manager, foreign_key: { to_table: :users }, null: true
    add_reference :projects, :project_manager, foreign_key: { to_table: :users }, null: true
  end
end
