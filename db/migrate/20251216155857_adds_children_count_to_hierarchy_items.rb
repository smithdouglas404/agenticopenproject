# frozen_string_literal: true

class AddsChildrenCountToHierarchyItems < ActiveRecord::Migration[8.0]
  def change
    add_column :hierarchical_items, :children_count, :integer, default: 0
  end
end
