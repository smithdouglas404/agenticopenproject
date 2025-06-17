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
    form do |f|
      f.autocompleter(
        name: :id_or_email,
        label: TimeEntry.human_attribute_name(:user),
        required: true,
        autocomplete_options: {
          defaultData: true,
          component: "opce-user-autocompleter",
          url: ::API::V3::Utilities::PathHelper::ApiV3Path.principals,
          searchKey: "any_name_attribute",
          resource: "principals",
          focusDirectly: false,
          multiple: false,
          clearable: false,
          appendTo: "##{Users::Invitation::DialogComponent::DIALOG_ID}",
        }
      )

      f.select_list(
        name: "role_id",
        label: "Role",
        caption: "This is the role..",
        include_blank: true
      ) do |city_list|
        city_list.option(label: "Lopez Island", value: "lopez_island")
        city_list.option(label: "Bellevue", value: "bellevue")
        city_list.option(label: "Seattle", value: "seattle")
      end
    end
  end
end
