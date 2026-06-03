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

module ResourceAllocations
  module Forms
    # The allocated duration, entered in chronic-duration syntax (e.g. "40h",
    # "1d 4h"). The `chronic-duration` Stimulus controller normalises the input
    # to a canonical hours string on blur.
    class HoursForm < ApplicationForm
      form do |f|
        f.text_field(
          name: :allocated_hours,
          label: ResourceAllocation.human_attribute_name(:allocated_hours),
          required: true,
          value: formatted_hours,
          invalid: allocated_time_error.present?,
          validation_message: allocated_time_error,
          data: { controller: "chronic-duration" }
        )
      end

      private

      # The duration is entered as `allocated_hours` but stored and validated as
      # `allocated_time`. Surface that attribute's errors on this field, each
      # formatted like Primer's own field errors ("Hours can't be blank.").
      def allocated_time_error
        label = ResourceAllocation.human_attribute_name(:allocated_hours)
        model.errors.messages_for(:allocated_time)
             .map { |message| "#{label} #{message}" }
             .join(" ")
             .presence
      end

      # Renders the stored duration as e.g. "40h", matching what the model's
      # `allocated_hours=` setter accepts back. Only relevant when re-rendering
      # the step after a validation error.
      def formatted_hours
        return if model.allocated_hours.nil?

        DurationConverter.output(model.allocated_hours)
      end
    end
  end
end
