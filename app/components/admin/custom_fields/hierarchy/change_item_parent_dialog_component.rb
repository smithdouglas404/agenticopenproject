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

module Admin
  module CustomFields
    module Hierarchy
      class ChangeItemParentDialogComponent < ApplicationComponent
        include OpTurbo::Streamable

        TEST_SELECTOR = "op-custom-fields--change-item-parent-dialog"

        def initialize(custom_field:, hierarchy_item:)
          super
          @custom_field = custom_field
          @hierarchy_item = hierarchy_item
        end

        def dialog_id = "custom-fields--change-item-parent-dialog"

        def form_id = "custom-fields--change-item-parent-form"

        def form_arguments
          {
            id: form_id,
            url: change_parent_custom_field_item_path(custom_field_id: @custom_field.id, id: @hierarchy_item.id),
            model: form_model,
            method: :post
          }
        end

        def hierarchy_items
          hashed_hierarchy = @custom_field.hierarchy_root.hash_tree
          hashed_hierarchy.keys.first.label = @custom_field.name

          hashed_hierarchy
        end

        def add_sub_tree(tree, hierarchy_hash)
          hierarchy_hash.each do |item, child_hash|
            if child_hash.empty?
              tree.with_leaf(**item_options(item))
            else
              expanded = current?(item) || child_hash.any? { |child, _| current?(child) }

              tree.with_sub_tree(expanded:, **item_options(item)) do |sub_tree|
                add_sub_tree(sub_tree, child_hash)
              end
            end
          end
        end

        private

        def form_model
          CustomField::Hierarchy::Forms::NewParentFormModel.new(new_parent: [])
        end

        def item_options(item)
          {
            label: item.label,
            current: current?(item),
            value: item.id,
            select_variant: :single,
            disabled: disabled?(item)
          }
        end

        def current?(item)
          item.id == @hierarchy_item.id
        end

        def disabled?(item)
          item.id == @hierarchy_item.id || item.id == @hierarchy_item.parent.id
        end
      end
    end
  end
end
