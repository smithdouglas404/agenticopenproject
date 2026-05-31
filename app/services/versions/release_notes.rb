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

module Versions
  # Generates release notes for a release from its completed (closed) work packages,
  # grouped by work package type, as a Markdown document.
  class ReleaseNotes
    def initialize(version)
      @version = version
    end

    # Completed work packages of the release, grouped by their type, ordered by type
    # position. Only work packages linked through the Release custom field are included.
    def grouped_work_packages
      @grouped_work_packages ||=
        @version.release_work_packages
          .merge(WorkPackage.with_status_closed)
          .includes(:type, :status)
          .order("#{::Type.table_name}.position, #{WorkPackage.table_name}.id")
          .group_by(&:type)
    end

    delegate :any?, to: :grouped_work_packages

    # Renders the release notes as Markdown.
    def to_markdown
      sections = ["# #{@version.name}"]
      sections << @version.description if @version.description.present?
      grouped_work_packages.each { |type, work_packages| sections << type_section(type, work_packages) }
      sections.join("\n\n")
    end

    private

    def type_section(type, work_packages)
      heading = "## #{type&.name || I18n.t(:label_none)}"
      items = work_packages.map { |wp| "- ##{wp.id} #{wp.subject}" }
      [heading, *items].join("\n")
    end
  end
end
