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

module Members::Scopes
  module Visible
    extend ActiveSupport::Concern

    class_methods do
      # Find all members visible to the inquiring user
      def visible(user = User.current)
        if user.admin?
          visible_for_admins
        else
          visible_for_non_admins(user)
        end
      end

      private

      def visible_for_non_admins(user)
        # Use a subquery so later merges (e.g. joins + role filters on project.members) do not
        # mis-bind placeholders against the complex OR / work_package visibility SQL.
        visible_ids = visible_project_members(user).or(shared_work_package_members(user)).select(:id)

        where(id: visible_ids)
      end

      # Project-wide memberships in projects where the user may view or manage members.
      def visible_project_members(user)
        view_members = Project.allowed_to(user, :view_members)
        manage_members = Project.allowed_to(user, :manage_members)

        where(project_id: view_members.or(manage_members).select(:id), entity_type: nil)
      end

      # Work package shares the user may list, limited to entities they can view.
      def shared_work_package_members(user)
        where(project_id: Project.allowed_to(user, :view_shared_work_packages).select(:id),
              entity_type: WorkPackage.name,
              entity_id: WorkPackage.visible(user).select(:id))
      end

      def visible_for_admins
        all
      end
    end
  end
end
