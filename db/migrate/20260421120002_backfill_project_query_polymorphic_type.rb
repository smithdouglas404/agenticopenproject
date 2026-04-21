# frozen_string_literal: true

class BackfillProjectQueryPolymorphicType < ActiveRecord::Migration[8.0]
  def up
    # STI base class is now PersistedQuery; Rails uses the base class name in
    # polymorphic columns. Backfill rows written before this migration.
    execute "UPDATE favorites SET favorited_type = 'PersistedQuery' WHERE favorited_type = 'ProjectQuery'"
    execute "UPDATE members SET entity_type = 'PersistedQuery' WHERE entity_type = 'ProjectQuery'"
  end

  def down
    execute <<~SQL.squish
      UPDATE favorites
      SET favorited_type = 'ProjectQuery'
      FROM persisted_queries
      WHERE favorites.favorited_type = 'PersistedQuery'
        AND favorites.favorited_id = persisted_queries.id
        AND persisted_queries.type = 'ProjectQuery'
    SQL

    execute <<~SQL.squish
      UPDATE members
      SET entity_type = 'ProjectQuery'
      FROM persisted_queries
      WHERE members.entity_type = 'PersistedQuery'
        AND members.entity_id = persisted_queries.id
        AND persisted_queries.type = 'ProjectQuery'
    SQL
  end
end
