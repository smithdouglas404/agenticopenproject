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

module Reminders
  class FormValidationService
    attr_reader :input_id

    def initialize(user:, model:, contract_class:, input_id: nil)
      @validation_service = Reminders::SetAttributesService.new(user:, model:, contract_class:)
      @input_id = input_id&.to_sym
    end

    def call(params)
      validation_result = @validation_service.call(params)

      if input_id_specified?
        (remind_at_inputs - [input_id]).each { validation_result.errors.delete(it) }
      end

      validation_result
    end

    private

    def input_id_specified?
      input_id.present? && remind_at_inputs.include?(input_id)
    end

    def remind_at_inputs = %i[remind_at_date remind_at_time]
  end
end
