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

module Backlogs
  class InboxComponent < ApplicationComponent
    include Primer::AttributesHelper
    include OpTurbo::Streamable
    include Backlogs::CommonHelper

    PAGINATION_THRESHOLD = 70
    FIRST_PAGE_SIZE = 50
    LAST_PAGE_SIZE = 10

    attr_reader :work_packages, :project, :current_user

    def initialize(work_packages:, project:, current_user: User.current, **system_arguments)
      super()

      @work_packages = work_packages
      @project = project
      @current_user = current_user

      @system_arguments = system_arguments
      @system_arguments[:id] = inbox_dom_id
      @system_arguments[:padding] = :condensed
      @system_arguments[:test_selector] = test_selector
      @system_arguments[:data] = merge_data(
        @system_arguments,
        { data: drop_target_config }
      )
    end

    def wrapper_uniq_by
      project
    end

    private

    def total
      @total ||= work_packages.count
    end

    def test_selector
      "backlog-inbox"
    end

    def inbox_dom_id
      "inbox_#{project.id}"
    end

    def paginate?
      !show_all_backlog && total > PAGINATION_THRESHOLD
    end

    def first_page
      work_packages.limit(FIRST_PAGE_SIZE)
    end

    def last_page
      work_packages.last(LAST_PAGE_SIZE)
    end

    def id_of_last_omitted_in_middle
      work_packages.reverse_order.offset(LAST_PAGE_SIZE).limit(1).pick(:id)
    end

    def middle_count
      total - FIRST_PAGE_SIZE - LAST_PAGE_SIZE
    end

    def drop_target_config
      {
        generic_drag_and_drop_target: "container mirrorContainer",
        target_container_accessor: ":scope > ul",
        target_id: "inbox",
        target_allowed_drag_type: "story"
      }
    end
  end
end
