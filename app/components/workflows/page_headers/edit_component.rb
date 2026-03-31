# frozen_string_literal: true

# -- copyright
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
# ++

module Workflows::PageHeaders
  class EditComponent < BaseComponent
    options :tabs, :role

    def type = model

    def page_breadcrumb
      { href: workflows_path, text: t(:label_workflow_plural) }
    end

    def title
      type.name
    end

    def add_action_buttons(header) # rubocop:disable Metrics/AbcSize
      header.with_action_button(
        data: { controller: "async-dialog" },
        tag: :a,
        mobile_icon: :copy,
        mobile_label: t(:label_copy_workflow_from_type),
        size: :medium,
        href: new_workflow_copy_from_type_path(type),
        aria: { label: helpers.t(:label_copy_workflow_from_type) },
        title: helpers.t(:label_copy_workflow_from_type)
      ) do |button|
        button.with_leading_visual_icon(icon: :copy)
        t(:label_copy_workflow_from_type)
      end

      header.with_action_button(
        data: { controller: "async-dialog" },
        tag: :a,
        mobile_icon: :copy,
        mobile_label: t(:label_copy_workflow_from_role),
        size: :medium,
        href: new_workflow_copy_from_role_path(type, source_role_id: role&.id),
        aria: { label: helpers.t(:label_copy_workflow_from_role) },
        title: helpers.t(:label_copy_workflow_from_role)
      ) do |button|
        button.with_leading_visual_icon(icon: :copy)
        t(:label_copy_workflow_from_role)
      end
    end

    def add_tabs(header)
      helpers.render_tab_header_nav(header, tabs)
    end
  end
end
