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

module Projects::Concerns
  module SetCalculatedCustomFieldValues
    private

    def set_attributes(params)
      super(params_except_calculated_fields(params)).tap do
        update_calculated_value_custom_fields
      end
    end

    def params_except_calculated_fields(params)
      custom_field_value_params = params[:custom_field_values]
      return params unless custom_field_value_params

      calculated_field_ids = model.all_available_custom_fields.field_format_calculated_value.pluck(:id)
      custom_field_value_params = custom_field_value_params.reject { |id, _| id.to_s.to_i.in?(calculated_field_ids) }

      params.merge(custom_field_values: custom_field_value_params)
    end

    def update_calculated_value_custom_fields
      changed_cf_ids = model.custom_values.select(&:changed?).map(&:custom_field_id)

      # Using unscope(where: :admin_only) to fix an issue when non admin user
      # edits a custom field which is used by an admin only calculated value
      # field. Without this unscoping, admin only value and all fields
      # referencing it (recursively) will not be recalculated and there will
      # even be no place for that recalculatin to be triggered unless an admin
      # edits same value again.
      #
      # This may need to be handled differently to make it work for other custom
      # field containers, like WorkPackage. User custom fields also has
      # admin_only check.
      affected_cfs = model.available_custom_fields.unscope(where: :admin_only).affected_calculated_fields(changed_cf_ids)

      model.change_by_system do
        model.calculate_custom_fields(affected_cfs)
      end
    end
  end
end
