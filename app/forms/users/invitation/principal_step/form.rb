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

module Users::Invitation::PrincipalStep
  class Form < ApplicationForm
    include OpenProject::StaticRouting::UrlHelpers
    include Redmine::I18n

    form do |f|
      f.hidden name: :project_id
      f.hidden name: :principal_type

      f.autocompleter(
        name: :id_or_email,
        label: TimeEntry.human_attribute_name(:user),
        required: true,
        autocomplete_options: {
          defaultData: true,
          component: "opce-members-autocompleter",
          url: autocomplete_for_member_project_members_path(model.project_id) + ".json",
          focusDirectly: false,
          multiple: false,
          clearable: false,
          appendTo: "##{Users::Invitation::DialogComponent::DIALOG_ID}"
        }
      )

      f.select_list(
        name: "role_id",
        label: "Role",
        caption: link_translate("users.invite_user_modal.role.description",
                                links: { docs_link: %i[sysadmin_docs roles_and_permissions] }),
        include_blank: false,
        required: true
      ) do |role_list|
        ProjectRole
          .givable
          .ordered_by_builtin_and_position
          .find_each do |role|
          role_list.option(label: role.name, value: role.id)
        end
      end
    end
  end
end
