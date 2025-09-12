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

class CalculatedValueError < ApplicationRecord
  belongs_to :project
  belongs_to :custom_field

  ERROR_TRANSLATIONS = {
    "ERROR_MATHEMATICAL" => "calculated_values.errors.mathematical",
    "ERROR_MISSING_VALUE" => "calculated_values.errors.missing_value"
  }.freeze

  VALID_ERROR_CODES = ERROR_TRANSLATIONS.keys.freeze

  validates :project_id, presence: true
  validates :custom_field_id, presence: true

  validates :error_code, inclusion: { in: VALID_ERROR_CODES }

  # It makes no sense to have the exact same error multiple times.
  validates :project_id, uniqueness: { scope: %i[custom_field_id error_code] }

  def error_message
    translation_key = ERROR_TRANSLATIONS.fetch(error_code, "calculated_values.errors.unknown")
    translation_options = {}

    if error_code == "ERROR_MISSING_VALUE"
      # To keep the error message short, we only show the first custom field with a missing value.
      cf = CustomField.find(missing_custom_field_ids.first)

      if cf
        translation_options[:custom_field_name] = cf.name
      else
        translation_key = "calculated_values.errors.unknown"
      end
    end

    I18n.t(translation_key, **translation_options)
  end
end
