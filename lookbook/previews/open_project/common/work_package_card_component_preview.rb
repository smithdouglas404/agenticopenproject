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

module OpenProject
  module Common
    # @logical_path OpenProject/Common
    class WorkPackageCardComponentPreview < ViewComponent::Preview
      def default
        work_package = WorkPackage.first
        project = work_package&.project
        return preview_message("No work packages in the database.") unless work_package && project

        sprint = Sprint.where(project_id: project.id).first
        render OpenProject::Common::WorkPackageCardComponent.new(
          work_package:,
          project:,
          container: sprint
        )
      end

      def inbox_context
        work_package = WorkPackage.first
        project = work_package&.project
        return preview_message("No work packages in the database.") unless work_package && project

        render OpenProject::Common::WorkPackageCardComponent.new(
          work_package:,
          project:,
          container: nil
        )
      end

      private

      def preview_message(text)
        render(Primer::Beta::Blankslate.new) do |b|
          b.with_heading(tag: :h4).with_content(text)
        end
      end
    end
  end
end
