# frozen_string_literal: true

require "support/pages/page"

module Pages
  class NewBoard < Page
    include ::Components::Autocompleter::NgSelectAutocompleteHelpers

    def visit!
      visit new_work_package_board_path
      wait_for_reload if using_cuprite?
      wait_for_network_idle if using_cuprite?
    end

    def navigate_by_create_button(path: work_package_boards_path)
      visit path unless page.current_path == path
      wait_for_network_idle if using_cuprite?

      button = page.first(:test_id,
                          "add-board-button",
                          text: I18n.t("boards.label_board"),
                          exact_text: true,
                          visible: :visible) || page.find(:test_id, "add-board-button", visible: :visible)

      button.click
      wait_for_reload if using_cuprite?
    end

    def set_title(title)
      fill_in I18n.t(:label_title), with: title
    end

    def expect_project_dropdown
      find "[data-test-selector='project_id']"
    end

    def set_project(project)
      select_autocomplete(find('[data-test-selector="project_id"]'),
                          query: project,
                          results_selector: "body")
    end

    def set_board_type(board_type)
      choose board_type, match: :first
    end

    def click_on_submit
      click_on I18n.t(:button_create)
    end

    def click_on_cancel_button
      click_on "Cancel"
    end
  end
end
