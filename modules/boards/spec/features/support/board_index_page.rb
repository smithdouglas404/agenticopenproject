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

require "support/pages/page"
require_relative "board_list_page"
require_relative "board_new_page"

module Pages
  class BoardIndex < BoardListPage
    attr_reader :project

    def initialize(project = nil)
      @project = project
    end

    def visit!
      if project
        visit project_work_package_boards_path(project)
      else
        visit work_package_boards_path
      end
    end

    def expect_editable(editable)
      # Editable / draggable check
      expect(page).to have_conditional_selector(editable, ".buttons a.icon-delete")
      # Create button
      expect(page).to have_conditional_selector(editable, ".toolbar-item a", text: "Board")
    end

    def expect_board(name, present: true)
      expect(page).to have_conditional_selector(present, "td.name", text: name)
    end

    def create_board(action: "Basic", title: "#{action} Board", expect_empty: false, via_toolbar: true)
      new_board_page = NewBoard.new
      target_path = project ? project_work_package_boards_path(project) : work_package_boards_path

      visit target_path unless page.current_path == target_path
      wait_for_network_idle if using_cuprite?

      if via_toolbar
        new_board_page.navigate_by_create_button(path: target_path)
      else
        page.find_test_selector("boards--create-button").click
        wait_for_reload if using_cuprite?
      end

      expect(page).to have_field(I18n.t(:label_title), wait: 10)

      new_board_page.set_title title
      new_board_page.set_board_type action
      new_board_page.click_on_submit

      expect_and_dismiss_flash(message: I18n.t(:notice_successful_create))

      if expect_empty
        expect(page).to have_css(".boards-list--add-item-text", wait: 10)
        expect(page).to have_no_css(".boards-list--item")
      else
        expect(page).to have_css(".boards-list--item", wait: 10)
      end

      board_page = ::Pages::Board.new(::Boards::Grid.last)
      minimum_lists = board_page.board.contained_queries.exists? ? 1 : 0
      board_page.wait_for_lists_to_finish_loading(minimum_lists:)
      board_page
    end

    def open_board(board)
      target_path = if board.project
                      project_work_package_board_path(board.project, board)
                    else
                      work_package_board_path(board)
                    end

      page.find("td.name a", text: board.name).click
      expect(page).to have_current_path(target_path, wait: 10)
      board_page = ::Pages::Board.new(board)
      minimum_lists = board.contained_queries.exists? ? 1 : 0
      board_page.wait_for_lists_to_finish_loading(minimum_lists:)
      board_page
    end
  end
end
