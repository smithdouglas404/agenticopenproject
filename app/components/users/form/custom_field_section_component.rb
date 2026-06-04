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

module Users
  module Form
    class CustomFieldSectionComponent < ApplicationComponent
      def initialize(section:, form:, contract:, user:)
        super()
        @section = section
        @form = form
        @contract = contract
        @user = user
        @visible_cfs_by_key = visible_cfs_by_key(section)
      end

      def title
        @section.name.presence || I18n.t("settings.user_attributes.label_untitled_section")
      end

      def built_in?(key)
        UserCustomFieldSection::BUILT_IN_ATTRIBUTES.include?(key)
      end

      def visible_custom_field(key)
        @visible_cfs_by_key[key]
      end

      private

      def visible_cfs_by_key(section)
        section.custom_fields.visible(User.current).index_by(&:column_name)
      end
    end
  end
end
