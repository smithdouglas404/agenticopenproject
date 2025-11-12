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

require "support/pages/page"

module Pages
  module Portfolios
    class Index < ::Pages::Page
      include ::Components::Common::Filters
      include ::Components::Autocompleter::NgSelectAutocompleteHelpers

      def path(*)
        "/portfolios"
      end

      def expect_portfolios_listed(*portfolios)
        within_portfolio_list do
          portfolios.each do |portfolio|
            expect(page).to have_text(portfolio.name)
            expect(page).to have_text(portfolio.description)
          end
        end
      end

      def expect_portfolios_not_listed(*portfolios)
        within_portfolio_list do
          portfolios.each do |portfolio|
            case portfolio
            when Project
              expect(page).to have_no_text(portfolio.name)
            when String
              expect(page).to have_no_text(portfolio)
            else
              raise ArgumentError, "#{portfolio.inspect} is not a Portfolio or a String"
            end
          end
        end
      end

      def expect_portfolio_at_place(portfolio, place)
        within_portfolio_list do
          expect(page)
            .to have_css(".portfolio:nth-of-type(#{place}) .portfolio-name", text: portfolio.name)
        end
      end

      def expect_portfolios_in_order(*portfolios)
        portfolios.each_with_index do |portfolio, index|
          expect_portfolio_at_place(portfolio, index + 1)
        end
      end

      def expect_title(name)
        expect(page).to have_css('[data-test-selector="portfolio-query-name"]', text: name)
      end

      def expect_filter_available(filter_name)
        expect(page).to have_select("add_filter_select", with_options: [filter_name])
      end

      def expect_filter_not_available(filter_name)
        expect(page).to have_no_select("add_filter_select", with_options: [filter_name])
      end

      def filter_by_active(value)
        set_filter("active", "Active", "is", [value])
        wait_for_reload
      end

      def filter_by_public(value)
        set_filter("public", "Public", "is", [value])
        wait_for_reload
      end

      def filter_by_favorited(value)
        set_filter("favorited", "Favorite", "is", [value])
        wait_for_reload
      end

      def filter_by_membership(value)
        set_filter("member_of", "I am member", "is", [value])
        wait_for_reload
      end

      def filter_by_name_and_identifier(value, send_keys: false)
        set_name_and_identifier_filter([value], send_keys:)
        wait_for_reload
      end

      def set_advanced_filter(name, human_name, human_operator = nil, values = [], send_keys: false)
        selected_filter = select_filter(name, human_name)

        within(selected_filter) do
          apply_operator(name, human_operator)

          return unless values.any?

          if boolean_filter?(name)
            set_toggle_filter(values)
          elsif autocomplete_filter?(selected_filter)
            select(human_operator, from: "operator")
            set_autocomplete_filter(values)
          elsif date_filter?(selected_filter) || date_time_filter?(selected_filter)
            select(human_operator, from: "operator")
            wait_for_network_idle
            set_created_at_filter(human_operator, values, send_keys:)
          end
        end
      end

      def click_more_menu_item(item)
        wait_for_network_idle
        page.find('[data-test-selector="portfolio-more-dropdown-menu"]').click
        page.find(".ActionListItem", text: item, exact_text: true).click
        wait_for_network_idle
      end

      def create_new_portfolio
        page.find('[data-test-selector="portfolio-new-button"]').click
      end

      def sidebar_menu_items
        page.find_by_id("menu-sidebar").all(".op-submenu--item-title").map(&:text)
      end

      def within_portfolio_list(&)
        within "#portfolios-index-container", &
      end

      def within_row(portfolio)
        row = page.find(".portfolio[data-test-selector='op-portfolios--portfolio-#{portfolio.id}']")
        row.hover
        within row do
          yield row
        end
      end

      private

      def boolean_filter?(filter)
        %w[active member_of favorited public templated].include?(filter.to_s)
      end
    end
  end
end
