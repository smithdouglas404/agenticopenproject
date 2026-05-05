# frozen_string_literal: true

class RepositionWorkPackages < ActiveRecord::Migration[8.1]
  def change
    reversible do |direction|
      direction.up do
        # Copied 1:1 from modules/backlogs/app/services/work_packages/rebuild_positions_service.rb.
        # The service could also have been called. But this way, there is no dependency between the two.
        execute <<~SQL.squish
          UPDATE work_packages
          SET position = mapping.new_position
          FROM (
            SELECT
              id,
              ROW_NUMBER() OVER (
                PARTITION BY project_id, sprint_id
                ORDER BY position, created_at
              ) AS new_position
            FROM work_packages
          ) AS mapping
          WHERE work_packages.id = mapping.id
        SQL
      end
    end
  end
end
