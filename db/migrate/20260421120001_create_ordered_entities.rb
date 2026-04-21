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

class CreateOrderedEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :ordered_entities do |t|
      t.references :persisted_query, null: false, foreign_key: true
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false
      t.integer :position
      t.timestamps
    end

    add_index :ordered_entities, %i[persisted_query_id entity_type entity_id], unique: true,
                                                                               name: :idx_ordered_entities_unique
    add_index :ordered_entities, %i[persisted_query_id entity_type position],
              name: :idx_ordered_entities_position
  end
end
