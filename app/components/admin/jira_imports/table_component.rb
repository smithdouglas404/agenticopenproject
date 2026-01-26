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

module Admin::JiraImports
  class TableComponent < OpPrimer::BorderBoxTableComponent
    columns :id, :status, :projects, :author

    def initialize(jira:, **)
      @jira = jira
      super
    end

    def mobile_title
      JiraImport.model_name.human(count: 2)
    end

    def row_class
      RowComponent
    end

    def has_actions?
      true
    end

    def headers
      [
        [:id, { caption: JiraImport.human_attribute_name(:id) }],
        [:status, { caption: JiraImport.human_attribute_name(:status) }],
        [:projects, { caption: JiraImport.human_attribute_name(:projects) }],
        [:author, { caption: JiraImport.human_attribute_name(:author_id) }],
      ]
    end

    def blank_title
      "No import runs set up yet"
    end

    def blank_description
      render(Primer::OpenProject::FlexLayout.new) do |flex|
        flex.with_row do
          render(Primer::Beta::Text.new(color: :muted)) do
            "Create an import run to start importing information from this Jira instance"
          end
        end
        flex.with_row(p: 3) do
          render(Primer::Beta::Button.new(
                   scheme: :primary,
                   size: :medium,
                   tag: :a,
                   href: new_admin_import_jira_run_path(jira_id: @jira.id)
                 )) do |button|
            button.with_leading_visual_icon(icon: :plus)
            "Import run"
          end
        end
      end
    end

    def blank_icon
      :"arrow-down"
    end
  end
end
