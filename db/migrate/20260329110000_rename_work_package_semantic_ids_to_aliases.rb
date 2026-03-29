# frozen_string_literal: true

class RenameWorkPackageSemanticIdsToAliases < ActiveRecord::Migration[8.1]
  def change
    rename_table :work_package_semantic_ids, :work_package_semantic_aliases
  end
end
