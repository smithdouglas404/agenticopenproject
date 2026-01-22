# frozen_string_literal: true

class FixUniquenessOnEnumerations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Get rid of old index
    remove_index :enumerations, name: "index_enumerations_on_type_project_id_and_LOWER_name", algorithm: :concurrently

    # As we did not really validate uniqueness before, we need to fix existing duplicates
    execute <<~SQL.squish
      UPDATE enumerations SET name = enumerations.name || ' ' || counter.rn
      FROM (SELECT id, row_number() OVER (PARTITION BY type, COALESCE(project_id, -1), LOWER(name) ORDER BY id) AS rn FROM enumerations) AS counter
      WHERE enumerations.id = counter.id AND counter.rn > 1;
    SQL

    # Add the index again
    add_index :enumerations,
              "type, project_id, LOWER(name)",
              unique: true,
              algorithm: :concurrently,
              nulls_not_distinct: true,
              name: "index_enumerations_on_type_project_id_and_LOWER_name"
  end

  def down
    # roll back to the old version of the index
    remove_index :enumerations, name: "index_enumerations_on_type_project_id_and_LOWER_name", algorithm: :concurrently
    add_index :enumerations, "type, project_id, LOWER(name)", unique: true, algorithm: :concurrently,
                                                              name: "index_enumerations_on_type_project_id_and_LOWER_name"
  end
end
