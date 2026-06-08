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
  # Lists a work package's allocations: the allocation progress summary, one row
  # per allocation, and a footer to add another. Allocations whose principal is
  # not visible to the current user are still listed, but anonymised.
  class ListDialogComponent < ApplicationComponent
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers

    DIALOG_ID = "work-package-allocations-dialog"

    def initialize(project:, work_package:, allocations:, visible_principal_ids:)
      super

      @project = project
      @work_package = work_package
      @allocations = allocations
      @visible_principal_ids = visible_principal_ids
    end

    private

    attr_reader :project, :work_package, :allocations, :visible_principal_ids

    def title
      I18n.t("resource_management.work_package_allocations_dialog.title")
    end

    def visible_principal?(allocation)
      allocation.principal_id.nil? || visible_principal_ids.include?(allocation.principal_id)
    end

    def allocate_resource_path
      new_project_resource_allocation_path(project, work_package_id: work_package.id)
    end
  end
end
