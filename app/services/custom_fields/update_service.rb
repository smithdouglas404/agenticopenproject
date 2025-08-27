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

module CustomFields
  class UpdateService < ::BaseServices::Update
    protected

    def after_perform(service_call)
      super.tap do
        recalculate_values
      end
    end

    private

    def recalculate_values
      return unless recalculate_values?

      model.class.customized_class.find_each do |customized|
        affected_cfs = customized.available_custom_fields.affected_calculated_fields([model.id])

        customized.calculate_custom_fields(affected_cfs)

        customized.save if customized.changed_for_autosave?
      end
    end

    def recalculate_values?
      model.field_format_calculated_value? && model.formula_previously_changed?
    end
  end
end
