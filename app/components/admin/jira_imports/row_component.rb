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
  class RowComponent < OpPrimer::BorderBoxRowComponent
    def id
      render(Primer::Beta::Link.new(href: admin_jira_jira_import_path(jira_id: model.jira.id, id: model.id), font_weight: :bold)) { "Import ##{model.id}" }
    end

    def author
      User.find(model.author_id)
    end

    def button_links
      [
        edit_button
      ]
    end

    def edit_button
      render(
        Primer::Beta::IconButton.new(
          icon: :pencil,
          tag: :a,
          href: admin_jira_jira_import_path(jira_id: model.jira.id, id: model.id),
          "aria-label": "Edit"
        )
      )
    end

    def status
      render(
        Primer::Beta::Text.new(
          font_weight: :bold,
          pl: 2
        )
      ) { model.status.to_s }
    end

    def projects
      render(
        Primer::Beta::Text.new(
          font_weight: :bold,
          pl: 2
        )
      ) { model.projects.join(" ") }
    end
  end
end
