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

# Tracks cross-project work package moves so that old identifiers
# (e.g. "SRC-5" after a WP moved to TGT and became "TGT-3") remain resolvable
# via compute-on-read finder methods.
class CreateWorkPackageMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :work_package_moves do |t|
      t.references :work_package, null: false, foreign_key: true, index: true
      t.bigint :source_project_id, null: false
      t.integer :sequence_number, null: false
      t.datetime :created_at, null: false
    end

    add_index :work_package_moves, %i[source_project_id sequence_number], unique: true
  end
end
