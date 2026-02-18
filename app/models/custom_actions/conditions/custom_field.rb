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
          current_values = current.map { it.value.to_i }
          to_delete = current_values - condition.values
          current.where(value: to_delete).delete_all if to_delete.any?

          to_insert = condition.values - current_values
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

  def self.custom_action_scope_has_current(work_packages, _user)
    custom_field_id = Array(work_packages).map { it.custom_field_values.map(&:custom_field_id) }.uniq
    CustomAction
      .includes(:custom_field_conditions)
      .where(custom_actions_custom_fields: { custom_field_id: })
  end

  def self.custom_action_scope_has_no
    CustomAction
      .includes(:custom_field_conditions)
      .where(custom_actions_custom_fields: { custom_field_id: nil })
  end

  def human_name
    self.class.custom_field.name
  end

  def self.association_ids
    :custom_field_condition_ids
  end

  def fulfilled_by?(work_package, _user)
    values.empty? ||
      values.map(&:to_s).intersect?(work_package.custom_values_for_custom_field(self.class.custom_field).map(&:value))
  end
end
