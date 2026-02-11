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

module Backlogs
  module Sprints
    class DatesForm < ApplicationForm
      form do |f|
        f.group(layout: :horizontal) do |dates|
          dates.single_date_picker(
            name: :start_date,
            label: attribute_name(:start_date),
            placeholder: attribute_name(:start_date),
            input_width: :small
          )
          dates.single_date_picker(
            name: :finish_date,
            label: attribute_name(:finish_date),
            placeholder: attribute_name(:finish_date),
            input_width: :small
          )
          dates.text_field(
            name: :duration,
            label: attribute_name(:duration),
            type: :number,
            input_width: :xsmall,
            inset: true,
            disabled: true,
            trailing_visual: {
              text: { text: I18n.t(:label_day_plural) }
            }
          )
        end
      end
    end
  end
end
