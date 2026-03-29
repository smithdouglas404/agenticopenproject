# frozen_string_literal: true

class AddSemanticIdToWorkPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :work_packages, :semantic_id, :string, if_not_exists: true

    remove_index :work_package_semantic_ids, name: :idx_wp_semantic_ids_current, if_exists: true
    remove_column :work_package_semantic_ids, :current, :boolean, if_exists: true
  end
end
