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

module Components
  module Admin
    class TypeConfigurationForm
      include Capybara::DSL
      include Capybara::RSpecMatchers
      include RSpec::Matchers
      include Rails.application.routes.url_helpers

      def add_button_dropdown
        page.find_test_selector("type-form-configuration-add-button")
      end

      def reset_button
        page.find_test_selector("type-form-configuration-reset-button")
      end

      def inactive_group
        page.find_test_selector("type-form-configuration-inactive-container")
      end

      def inactive_drop
        inactive_group.find(".Box ul")
      end

      def expect_empty
        expect(page).to have_no_css('[data-group-key]')
      end

      def find_group(name)
        title = page.find(".Box-header span.text-bold", text: /\A#{Regexp.escape(name)}\z/, match: :first)
        title.find(:xpath, "./ancestor::*[@data-group-key][1]")
      end

      def attribute_selector(attribute)
        %[li[data-attr-key="#{attribute}"]]
      end

      def find_group_handle(label)
        group_key = find_group(label)["data-group-key"]
        page.find_test_selector("type-form-configuration-section-handle-#{group_key}", visible: :all)
      end

      def find_attribute_handle(attribute)
        page.find_test_selector("type-form-configuration-attribute-handle-#{attribute}", visible: :all)
      end

      def expect_attribute(key:, translation: nil)
        attribute = page.find(attribute_selector(key))
        expect(attribute).to have_text(translation) if translation
      end

      def move_to(attribute, group_label)
        drag_and_drop(find_attribute_handle(attribute), find_group(group_label))
        expect_group(group_label, group_label, key: attribute)
      end

      def remove_attribute(attribute)
        row = page.find(attribute_selector(attribute))

        within row do
          page.find_test_selector("type-form-configuration-attribute-actions-#{attribute}").click
        end

        page.find_test_selector("type-form-configuration-delete-attribute-#{attribute}", visible: :all).click

        page.within_test_selector("type-form-configuration-sections-container") do
          expect(page).to have_no_css(attribute_selector(attribute))
        end
      end

      def drag_and_drop(handle, target)
        target_container = target.find(".Box ul")

        scroll_to_element(target_container)

        page.driver.browser.action
            .move_to(handle.native)
            .click_and_hold(handle.native)
            .perform

        scroll_to_element(target_container)

        page.driver.browser.action
            .move_to(target_container.native)
            .release
            .perform
      end

      def add_query_group(name, relation_filter, expect: true)
        SeleniumHubWaiter.wait unless using_cuprite?

        add_button_dropdown.click
        click_on I18n.t("types.edit.form_configuration.add_query_group")

        modal = ::Components::WorkPackages::TableConfigurationModal.new

        within ".relation-filter-selector" do
          page.find_test_selector("wp-table-configuration-relation-filter").select(I18n.t("js.relation_labels.#{relation_filter}"))

          option_labels = %w[
            children
            precedes
            follows
            relates
            duplicates
            duplicated
            blocks
            blocked
            partof
            includes
            requires
            required
          ].map { |filter_name| I18n.t("js.relation_labels.#{filter_name}") }

          option_labels.each do |label|
            expect(page).to have_text(label)
          end
        end

        yield modal if block_given?
        modal.save if modal.open?

        fill_section_name(name)
        save_section

        expect_group(name, name) if expect
      end

      def edit_query_group(name)
        wait_for_turbo

        group_key = find_group(name)["data-group-key"]
        page.find_test_selector("type-form-configuration-query-actions-#{group_key}").click
        page.find_test_selector("type-form-configuration-edit-query-#{group_key}", visible: :all).click
        expect(page).to have_css(".wp-table--configuration-modal")
      end

      def add_attribute_group(name, expect: true)
        add_button_dropdown.click
        click_on I18n.t("types.edit.form_configuration.add_attribute_group")

        fill_section_name(name)
        save_section

        expect_group(name, name) if expect
      end

      def save_changes
        wait_for_turbo
      end

      def rename_group(from, to)
        menu_id = open_group_menu(from)
        within "##{menu_id}" do
          first("a.ActionListContent", minimum: 1, visible: :all).click
        end

        fill_section_name(to)
        save_section

        expect_group(to, to)
      end

      def remove_group(name)
        menu_id = open_group_menu(name)
        within "##{menu_id}" do
          click_link I18n.t("button_delete")
        end

        expect(page).to have_no_css('[data-group-key]', text: /\b#{Regexp.escape(name)}\b/)
      end

      def expect_no_attribute(attribute, group)
        expect(find_group(group)).to have_no_css(attribute_selector(attribute))
      end

      def expect_group(_label, translation, *attributes)
        group = find_group(translation)
        expect(group).to have_text(translation)

        within group do
          attributes.each do |attribute|
            expect_attribute(**attribute)
          end
        end
      end

      def expect_inactive(attribute)
        expect(inactive_drop).to have_css(attribute_selector(attribute))
      end

      private

      def fill_section_name(name)
        input = page.find_test_selector("type-form-configuration-section-name-input", wait: 10)
        input.set(name)
      end

      def open_group_menu(name)
        menu_button = menu_button_for(name)
        menu_id = menu_button[:'aria-controls']
        menu_button.click
        menu_id
      end

      def menu_button_for(name)
        group_key = find_group(name)["data-group-key"]
        page.find_test_selector("type-form-configuration-section-actions-#{group_key}")
      end

      def save_section
        page.find_test_selector("type-form-configuration-section-save", wait: 10).click
        expect(page).to have_no_selector(page.test_selector("type-form-configuration-section-name-input"))
      end

      def wait_for_turbo
        if using_cuprite?
          wait_for_reload
        else
          SeleniumHubWaiter.wait
        end
      end
    end
  end
end
