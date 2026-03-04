# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class CreateProjectIdentifiers < ActiveRecord::Migration[8.0]
  def up
    create_table :project_identifiers do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :handle, null: false
      t.boolean :current, null: false, default: true

      t.timestamps
    end

    add_index :project_identifiers,
              :handle,
              unique: true

    add_index :project_identifiers,
              :project_id,
              unique: true,
              where: "current = TRUE",
              name: "index_project_identifiers_on_project_id_where_current_true"

    execute <<~SQL.squish
      INSERT INTO project_identifiers (project_id, handle, current, created_at, updated_at)
      SELECT id, identifier, true, NOW(), NOW()
      FROM projects
      WHERE identifier IS NOT NULL
    SQL

    remove_column :projects, :identifier
  end

  def down
    add_column :projects, :identifier, :string, null: true

    execute <<~SQL.squish
      UPDATE projects SET identifier = (SELECT handle
                                        FROM project_identifiers
                                        WHERE project_identifiers.project_id = projects.id
                                        AND project_identifiers.current = TRUE);
    SQL

    change_column_null :projects, :identifier, false
    drop_table :project_identifiers
  end
end
