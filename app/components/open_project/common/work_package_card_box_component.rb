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
    class WorkPackageCardBoxComponent < ApplicationComponent
      include Primer::AttributesHelper
      include OpPrimer::ComponentHelpers

      # Renders a `Header` above the card list with the title, count badge, and
      # consumer-provided actions/menu/description.
      #
      # @param title [String] heading text rendered inside the collapsible header.
      # @param count [Integer, NilClass] optional count badge displayed alongside
      #   the title; hidden when zero or nil.
      renders_one :header, ->(title:, count: nil) {
        Header.new(title:, count:, container:, list_id:, collapsed: folded?)
      }

      # Renders a `Primer::Beta::Blankslate` when no items are produced — that
      # is, when `items.empty?` after slot resolution and automatic item builds.
      # The slot is required unless the caller provides manual items, and is
      # silently ignored whenever `items` is non-empty.
      #
      # @param title [String] blankslate heading.
      # @param description [String, NilClass] optional secondary text.
      # @param icon [Symbol, NilClass] optional Octicon name.
      # @param system_arguments [Hash] forwarded to `Primer::Beta::Blankslate`.
      renders_one :empty_state, ->(title:, description: nil, icon: nil, **system_arguments) {
        system_arguments[:role] = "status"
        system_arguments[:aria] = merge_aria(
          system_arguments,
          aria: { live: "polite" }
        )

        blankslate = Primer::Beta::Blankslate.new(**system_arguments)
        blankslate.with_heading(tag: :h4).with_content(title)
        blankslate.with_description_content(description) if description
        blankslate.with_visual_icon(icon:) if icon
        blankslate
      }

      # When set, the box truncates `work_packages` to the first `truncate_middle`
      # rows plus a derived tail (`max(truncate_middle / 5, 1)`) and inserts a
      # show-more affordance between them. Truncation only triggers when
      # `work_packages.size > truncate_middle + 2 * tail_size`.
      #
      # @param truncate_middle [Integer] first-page size.
      # @param text [String, NilClass] copy override for the show-more label.
      #   Supports a `%{count}` placeholder. Defaults to the
      #   `work_package_card_box_component.show_more` translation key.
      renders_one :show_more, ->(truncate_middle:, text: nil) {
        ShowMore.new(truncate_middle:, text:)
      }

      # @!parse
      #   # Adds a work package item row to the box. When at least one item is
      #   # added manually, the box does not build rows from `work_packages:`.
      #   #
      #   # @param work_package [WorkPackage] the work package rendered in the row.
      #   # @param component_klass [Class] row bridge class used instead of the
      #   #   box's configured `item_component_klass`. It must accept the
      #   #   arguments documented on
      #   #   `#build_item`, expose `#row_args` with valid
      #   #   `Primer::Beta::BorderBox#with_row` keyword arguments, and expose
      #   #   `#card` returning a renderable object.
      #   # @param system_arguments [Hash] forwarded to the item class.
      #   def with_work_package_item(
      #     work_package:,
      #     component_klass: item_component_klass,
      #     **system_arguments,
      #     &block
      #   )
      #   end

      # @!parse
      #   # Adds a custom empty item row to the box. This can be used instead of
      #   # the `empty_state` slot when the caller owns item iteration. It cannot
      #   # be combined with `work_packages:`, `with_work_package_item`, or
      #   # `with_show_more`.
      #   #
      #   # @param system_arguments [Hash] forwarded to
      #   #   `Primer::Beta::BorderBox#with_row`.
      #   def with_empty_item(**system_arguments, &block)
      #   end
      renders_many :items, types: {
        work_package_item: {
          renders: lambda { |work_package:, **system_arguments, &block|
            build_item(work_package:, **system_arguments).tap do |item|
              capture(item, &block) if block
            end
          },
          as: :work_package_item
        },
        empty_item: {
          renders: lambda { |**system_arguments, &block|
            EmptyItem.new(**system_arguments).tap do |empty_item|
              empty_item.with_content(capture(&block)) if block
            end
          },
          as: :empty_item
        }
      }

      # Renders a free-form footer row below the card list.
      renders_one :footer

      attr_reader :work_packages,
                  :project,
                  :container,
                  :drag_and_drop,
                  :item_component_klass,
                  :params,
                  :current_user

      # @param project [Project] the project this card box is rendered in. May
      #   differ from individual `work_package.project` values when sprints or
      #   buckets are shared across projects.
      # @param container [Symbol, String, Class, ApplicationRecord] drives the box
      #   DOM id and related ids via `dom_target`.
      # @param work_packages [Enumerable<WorkPackage>] the work packages to render
      #   as cards. Truncated when the `:show_more` slot is set and the count
      #   exceeds the derived threshold.
      # @param drag_and_drop [Hash, NilClass] optional generic drag-and-drop
      #   target data. Requires `:target_id` and `:allowed_drag_type` when set.
      # @param item_component_klass [Class] item class used for automatically
      #   built work package items.
      # @param params [Hash] optional URL params passed to work package items
      #   when deriving row arguments.
      # @param current_user [User] passed through to each item for permission
      #   checks; defaults to `User.current`.
      # @param system_arguments [Hash] forwarded to the underlying
      #   `Primer::Beta::BorderBox`.
      def initialize(
        project:,
        container:,
        work_packages: [],
        drag_and_drop: nil,
        item_component_klass: Item,
        params: {},
        current_user: User.current,
        **system_arguments
      )
        super()

        @work_packages = work_packages
        @project = project
        @container = container
        @drag_and_drop = drag_and_drop
        @item_component_klass = item_component_klass
        @params = params
        @current_user = current_user
        @automatic_items = false

        @system_arguments = system_arguments
        @system_arguments[:id] = container_id
        @system_arguments[:list_id] = list_id
        @system_arguments[:padding] = :condensed
        merge_drag_and_drop_data! if drag_and_drop
      end

      def before_render
        # Content must be loaded before mode validation and automatic item builds
        # so slot calls have already populated `items`.
        content
        validate_item_mode!
        build_automatic_items if build_automatic_items?
        validate_empty_state!
        validate_show_more!
      end

      def truncated?
        automatic_items? && show_more? && work_packages.size > truncate_threshold
      end

      # Builds a new work package item without adding it to the box. Use this
      # instead of the `#with_work_package_item` slot when rendering additional
      # items outside this box, such as in a separately-loaded page.
      #
      # @param work_package [WorkPackage] the work package rendered in the row.
      # @param component_klass [Class] item class used instead of the configured
      #   default item class. It must accept `work_package:`, `project:`,
      #   `container:`, `params:`, `current_user:`, and `**system_arguments`.
      # @param system_arguments [Hash] forwarded to the item class.
      def build_item(
        work_package:,
        component_klass: item_component_klass,
        **system_arguments
      )
        component_klass.new(
          work_package:,
          project:,
          container:,
          params:,
          current_user:,
          **system_arguments
        )
      end

      private

      def folded?
        current_user.pref[:backlogs_versions_default_fold_state] == "closed"
      end

      def build_automatic_items?
        work_package_items.empty? && work_packages.any?
      end

      def build_automatic_items
        @automatic_items = true

        visible_work_packages.each do |work_package|
          with_work_package_item(work_package:)
        end
      end

      def automatic_items?
        @automatic_items
      end

      def validate_item_mode!
        return unless empty_items.any?

        if work_packages.any?
          raise ArgumentError, "empty_item cannot be combined with work_packages"
        end

        if work_package_items.any?
          raise ArgumentError, "empty_item cannot be combined with work_package_item"
        end

        if show_more?
          raise ArgumentError, "empty_item cannot be combined with show_more"
        end
      end

      def validate_empty_state!
        return unless items.empty? && !empty_state?

        raise ArgumentError, "empty_state slot is required when no work package items are rendered"
      end

      def validate_show_more!
        return if !show_more? || show_more.truncate_middle.is_a?(Integer)

        raise ArgumentError, "show_more requires truncate_middle: as an Integer"
      end

      def container_id
        dom_target(container)
      end

      def list_id
        dom_target(container, :list)
      end

      def header_id
        dom_target(container, :header)
      end

      def empty_items
        items.select { |item| item.respond_to?(:empty_item?) && item.empty_item? }
      end

      def work_package_items
        items - empty_items
      end

      def merge_drag_and_drop_data!
        @system_arguments[:data] = merge_data(
          {
            data: drag_and_drop_data
          },
          @system_arguments
        )
      end

      def drag_and_drop_data
        {
          # Sprint historically used "container" alone. The shared box keeps the
          # first mirror container on the page for now until parent-specific DnD
          # handling is extracted in follow-up work.
          generic_drag_and_drop_target: "container mirrorContainer",
          target_container_accessor: ":scope > ul",
          target_id: drag_and_drop.fetch(:target_id),
          target_allowed_drag_type: drag_and_drop.fetch(:allowed_drag_type)
        }
      end

      def visible_work_packages
        return work_packages unless truncated?

        work_packages.first(show_more.truncate_middle) + work_packages.last(tail_size)
      end

      def tail_size
        return 0 unless show_more?

        [show_more.truncate_middle / 5, 1].max
      end

      def truncate_threshold
        show_more.truncate_middle + (tail_size * 2)
      end

      def omitted_count
        work_packages.size - show_more.truncate_middle - tail_size
      end

      def last_omitted_id
        if work_packages.respond_to?(:reverse_order)
          work_packages.reverse_order.offset(tail_size).limit(1).pick(:id)
        else
          work_packages[-(tail_size + 1)]&.id
        end
      end

      def show_more_id
        dom_target(container, :show_more)
      end

      def show_more_label
        if show_more.text
          format(show_more.text, count: omitted_count)
        else
          t(".show_more", count: omitted_count)
        end
      end
    end
  end
end
