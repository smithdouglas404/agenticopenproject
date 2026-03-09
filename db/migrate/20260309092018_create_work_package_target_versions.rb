# frozen_string_literal: true

class CreateWorkPackageTargetVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :work_package_target_versions, id: false do |t|
      t.references :work_package, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :version,      null: false, foreign_key: { on_delete: :cascade }, index: false
      t.timestamps
    end

    add_index :work_package_target_versions, %i[work_package_id version_id],
              unique: true,
              name: "idx_wp_target_versions_on_wp_and_version"
    add_index :work_package_target_versions, :version_id,
              name: "idx_wp_target_versions_on_version"
  end
end
