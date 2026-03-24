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

module Admin
  module Groups
    class GroupDetailComponent < ApplicationComponent
      include ApplicationHelper
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      attr_reader :group, :ancestors, :child_groups

      def initialize(group:, ancestors: [], child_groups: [])
        super(nil)
        @group = group
        @ancestors = ancestors
        @child_groups = child_groups
      end

      def breadcrumb_items
        items = [{ label: organization_name, href: admin_departments_path }]

        ancestors.each do |ancestor|
          items << { label: ancestor.name, href: admin_department_path(ancestor) }
        end

        items << { label: group.name }
        items
      end

      def users
        @users ||= group.users
      end

      def render?
        group.present?
      end

      private

      def organization_name
        Setting.organization_name.presence || I18n.t("setting_organization_name")
      end
    end
  end
end
