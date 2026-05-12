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

module OpenProject
  module Common
    class WorkPackageCardComponent < ApplicationComponent
      include Primer::ClassNameHelper
      include OpPrimer::ComponentHelpers

      renders_one :metric, Primer::Content
      renders_one :menu, ->(src: nil, button_aria_label: nil, **system_arguments) {
        Menu.new(
          work_package:,
          src:,
          button_aria_label:,
          **system_arguments
        )
      }
      renders_one :bottom_line, Primer::Content

      attr_reader :work_package, :menu_src, :show_drag_handle, :show_assignee, :show_priority,
                  :show_parent_link, :status_scheme

      # @param work_package [WorkPackage] the work package this card represents.
      # @param menu_src [String, NilClass] optional lazy menu source. Prefer the
      #   `with_menu(src:)` slot for new call sites.
      # @param show_drag_handle [Boolean] whether to show a drag handle icon.
      # @param show_assignee [Boolean] whether to show the assignee (icon + name when space allows).
      # @param show_priority [Boolean] whether to show the priority badge.
      # @param show_parent_link [Boolean] whether to show a link to the parent work package in row 3.
      #   Only rendered when the work package actually has a parent.
      # @param status_scheme [Symbol] status label scheme for the info line. One of :default or :secondary.
      def initialize(work_package:, menu_src: nil, show_drag_handle: false,
                     show_assignee: false, show_priority: false, show_parent_link: false,
                     status_scheme: :default)
        super()

        @work_package = work_package
        @menu_src = menu_src
        @show_drag_handle = show_drag_handle
        @show_assignee = show_assignee
        @show_priority = show_priority
        @show_parent_link = show_parent_link
        @status_scheme = status_scheme
      end

      private

      def show_footer?
        bottom_line? || (show_parent_link && work_package.parent.present?)
      end
    end
  end
end
