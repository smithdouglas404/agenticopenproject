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
  module OutsideDatesStep
    # Confirmation step shown when the allocation dates fall outside the work
    # package's schedule. Replaces the dialog body; the carried form values are
    # re-submitted by the footer so "Allocate" recreates the same allocation and
    # "Back" returns to the editable step.
    class FormComponent < ApplicationComponent
      include ApplicationHelper
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      def initialize(allocation:, project:, allocation_kind:, form_values:, filters: nil)
        super
        @allocation = allocation
        @project = project
        @allocation_kind = allocation_kind
        @form_values = form_values
        @filters = filters
      end

      def wrapper_key
        ResourceAllocations::NewDialogComponent::BODY_ID
      end

      private

      def heading
        I18n.t("resource_management.allocate_resource_dialog.outside_dates.title")
      end

      def description
        I18n.t(
          "resource_management.allocate_resource_dialog.outside_dates.description",
          resource_dates: date_range(@allocation.start_date, @allocation.end_date),
          work_package_dates: date_range(@allocation.entity_start_date, @allocation.entity_due_date)
        )
      end

      def confirmation
        I18n.t("resource_management.allocate_resource_dialog.outside_dates.confirm_#{@allocation.schedule_violation}")
      end

      def date_range(from_date, to_date)
        "#{format_or_dash(from_date)} - #{format_or_dash(to_date)}"
      end

      def format_or_dash(date)
        date.present? ? helpers.format_date(date) : "—"
      end
    end
  end
end
