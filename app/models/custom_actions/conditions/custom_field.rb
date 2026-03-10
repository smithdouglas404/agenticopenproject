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

class CustomActions::Conditions::CustomField < CustomActions::Conditions::Base
  class << self
    def key
      custom_field.attribute_name.to_sym
    end

    def type
      CustomField
    end

    def custom_field
      raise NotImplementedError
    end

    def all
      WorkPackageCustomField.usable_as_custom_action_condition.map { create_subclass(it) }
    end

    def create_subclass(custom_field)
      klass = Class.new(CustomActions::Conditions::CustomField)
      klass.define_singleton_method(:custom_field) { custom_field }
      klass.include(strategy(custom_field))
      klass
    end

    def setter(custom_action, condition)
      custom_action.custom_actions_custom_fields.transaction do
        current = custom_action.custom_actions_custom_fields.where(custom_field:)

        if condition.present?
          values = condition.values.map(&:to_s)
          current_values = current.map(&:value).uniq
          to_delete = current_values - values
          current.where(value: to_delete).delete_all if to_delete.any?

          to_insert = values - current_values
          if to_insert.any?
            custom_action.custom_actions_custom_fields.insert_all(
              to_insert.map { { custom_field_id: custom_field.id, value: it } }
            )
          end
        else
          current.delete_all
        end
      end
    end

    def getter(custom_action)
      values = custom_action.custom_actions_custom_fields.where(custom_field:)
      return if values.empty?

      new(values.map(&:value))
    end

    private

    def strategy(custom_field)
      case custom_field.field_format
      when "bool"
        CustomActions::Conditions::Strategies::Boolean
      when "list", "user"
        CustomActions::Conditions::Strategies::AssociatedCustomField
      end
    end
  end

  def self.custom_action_scope(_items, _user)
    raise "Mustn't use that. Something gone really bad."
  end

  def self.custom_fields_with(items)
    items = Array.wrap(items)
    return CustomAction.all if items.empty?

    cf_query = CustomValue
               .select(:custom_field_id, :value)
               .where(
                 customized_type: items.first.class.name,
                 customized_id: items.map(&:id)
               )

    CustomAction.where(<<~SQL.squish)
      NOT EXISTS (
        SELECT 1
        FROM (
          SELECT cacf.custom_field_id
          FROM custom_actions_custom_fields cacf
          WHERE cacf.custom_action_id = custom_actions.id
          GROUP BY cacf.custom_field_id
        ) action_cf

        WHERE NOT EXISTS (
          SELECT 1
          FROM custom_actions_custom_fields cacf2
          JOIN (#{cf_query.to_sql}) item_cf
            ON item_cf.custom_field_id = cacf2.custom_field_id
           AND item_cf.value = cacf2.value
          WHERE cacf2.custom_action_id = custom_actions.id
            AND cacf2.custom_field_id = action_cf.custom_field_id
        )
      )
    SQL
  end

  def self.custom_field_values(items)
    Array.wrap(items)
      .flat_map(&:custom_field_values)
      .filter_map { it.value.to_s if it.custom_field_id == custom_field.id }
      .uniq
  end

  def human_name
    self.class.custom_field.name
  end

  def self.association_ids
    :custom_field_condition_ids
  end

  def fulfilled_by?(work_package, _user)
    values.empty? ||
      values.map(&:to_s)
            .intersect?(work_package.custom_values_for_custom_field(id: self.class.custom_field.id).map(&:value))
  end
end
