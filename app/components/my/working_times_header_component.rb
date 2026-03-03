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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module My
  class WorkingTimesHeaderComponent < ApplicationComponent
    def call # rubocop:disable Metrics/AbcSize
      render(Primer::OpenProject::PageHeader.new) do |header|
        header.with_title { t(:label_schedule_and_availability) }
        header.with_breadcrumbs(
          [{ href: my_account_path, text: t(:label_my_account) },
           t(:label_schedule_and_availability)]
        )
        header.with_tab_nav(label: "label") do |nav|
          nav.with_tab(selected: params[:action] == "working_hours",
                       href: my_working_hours_path) do |tab|
            tab.with_text { t(:label_working_hours) }
          end

          nav.with_tab(selected: params[:action] == "non_working_days",
                       href: my_non_working_times_path(year: Date.current.year)) do |tab|
            tab.with_text { t(:label_non_working_days) }
          end
        end
      end
    end
  end
end
