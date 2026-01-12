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

# This is a component designed to layout individual parts of a page to ensure that everything behaves as desired.
# The page is expected to consist of the following parts:
#   * Header
#   * Left side
#   * Right side, consisting of 1 to n tabs
#
# This is the expected layout
# |-------------------------------------------------
# |                           | Tab1 | Tab 2 | ... |
# |       PageHeader          |                    |
# |                           |                    |
# |---------------------------|                    |
# |                           |   some             |
# |       some info           |   more             |
# |        about the          |   details          |
# |        object             |                    |
# |                           |                    |
# |------------------------------------------------|
#
# The header can be configured to go full width, in which case the page looks like this:
# |-------------------------------------------------
# |                                                |
# |                    PageHeader                  |
# |                                                |
# |---------------------------| Tab1 | Tab 2 | ... |
# |                           |                    |
# |                           |                    |
# |                           |   some             |
# |       some info           |   more             |
# |        about the          |   details          |
# |        object             |                    |
# |                           |                    |
# |                           |                    |
# |------------------------------------------------|
#
# There are some special things to consider for mobile,
# where the left side becomes an additional tab as part of the tab navigation:
# |-----------------------|
# |                       |
# |    PageHeader         |
# |                       |
# | Tab 0 | Tab1 | Tab 2 | ... |
# |                       |
# |                       |
# |  Tab 0 is the         |
# |  previously left part |
# |                       |
# |                       |
# |-----------------------|
module OpPrimer
  class FullViewPageLayoutComponent < ViewComponent::Base
    include OpPrimer::ComponentHelpers

    class Tab < ViewComponent::Base
      attr_reader :name, :href, :active, :counter

      def initialize(name:, href:, active: false, counter: 0)
        @name = name.to_s
        @href   = href
        @active = active
        @counter = counter
      end

      def call
        content
      end
    end

    renders_one :header, lambda { |full_width: false, **system_arguments|
      system_arguments[:tag] ||= :div
      @system_arguments[:classes] = class_names(
        @system_arguments[:classes],
        "full-view-page-layout--full-width-header" => full_width
      )
      Primer::BaseComponent.new(**system_arguments)
    }

    renders_one  :left_tab, OpPrimer::FullViewPageLayoutComponent::Tab
    renders_many :tabs, OpPrimer::FullViewPageLayoutComponent::Tab

    def initialize(nav_arguments: {}, **system_arguments)
      super()
      @nav_arguments = nav_arguments
      @nav_arguments[:label] ||= I18n.t(:label_work_package_tabs)

      @system_arguments = system_arguments
      @system_arguments[:tag] = :div
    end

    def rendered_tabs
      return tabs unless mobile? && left_tab

      [left_tab, *tabs]
    end

    def active_tab
      rendered_tabs.find(&:active) || left_tab || tabs.first
    end

    def right_tab
      return active_tab if mobile?

      # Special case when the left side is marked as active tab
      if active_tab == left_tab
        tabs.first
      else
        active_tab
      end
    end

    def mobile?
      helpers.browser.device.mobile?
    end

    def render_tab(nav, tab)
      nav.with_tab(
        selected: tab == right_tab,
        href: tab.href
      ) do |c|
        c.with_text { tab.name }
        c.with_counter(
          count: tab.counter,
          hide_if_zero: true,
          id: "full-view-#{tab.name}-tab-counter",
          test_selector: "full-view--#{tab.name}-tab-counter"
        )
      end
    end

    def before_render
      raise ArgumentError, "Left tab must be defined" unless left_tab

      active_tabs = rendered_tabs.select(&:active)
      raise ArgumentError, "Only one tab can be active" if active_tabs.size > 1
    end
  end
end
