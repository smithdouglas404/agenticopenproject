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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class AddWorkPackageSemanticIdentifiers < ActiveRecord::Migration[8.1]
  def change
    # Counter cache for O(1) sequence allocation per project.
    # Monotonically increasing — never resets, even after WP deletion or move.
    add_column :projects, :wp_sequence_counter, :bigint, default: 0, null: false

    # Columns on work_packages for project-scoped semantic identifiers (e.g. "SC-111").
    # - sequence_number: project-scoped auto-incrementing integer
    # - identifier: the composed semantic identifier string, used as FriendlyId slug column
    change_table :work_packages, bulk: true do |t|
      t.bigint :sequence_number
      t.string :identifier

      t.index %i[project_id sequence_number],
              unique: true,
              where: "sequence_number IS NOT NULL",
              name: :index_work_packages_on_project_id_and_sequence_number
      t.index :identifier,
              unique: true,
              where: "identifier IS NOT NULL",
              name: :index_work_packages_on_identifier
    end
  end
end
