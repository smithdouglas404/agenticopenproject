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

module CustomFields
  module Details
    class LengthForm < BaseForm
      supports_formats except: %i[list bool date user version link hierarchy calculated_value]

      form do |f|
        f.group(layout: :horizontal) do |g|
          g.text_field(
            name: :min_length,
            type: :number,
            label: attribute_name(:min_length),
            caption: I18n.t(:text_min_max_length_info),
            input_width: :xsmall
          )

          g.text_field(
            name: :max_length,
            type: :number,
            label: attribute_name(:max_length),
            caption: I18n.t(:text_min_max_length_info),
            input_width: :xsmall
          )
        end
      end
    end
  end
end
