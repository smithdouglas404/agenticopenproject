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
#
module OpPrimer
  # Truncates block content and exposes an expander to reveal the full text.
  #
  # Two truncation directions are supported:
  #
  # - `:horizontal` clips a single line with `Primer::Beta::Truncate`.
  # - `:vertical` clamps to `lines` rows with `OpPrimer::VerticalTruncateComponent`.
  #
  # The companion `expandable-text` Stimulus controller toggles the expanded state.
  # With `expansion: :inline` the expander reveals the text in place; with
  # `expansion: :external` the expander is left to a caller-provided action (for
  # example, a dialog) and only its visibility is managed.
  class ExpandableTextComponent < Primer::Component
    DIRECTION_OPTIONS = %i[horizontal vertical].freeze
    DIRECTION_DEFAULT = :horizontal

    EXPANSION_OPTIONS = %i[inline external].freeze
    EXPANSION_DEFAULT = :inline

    attr_reader :direction, :expansion

    # @param direction [Symbol] truncation direction. `:horizontal` clips a
    #   single line; `:vertical` clamps to `lines` rows.
    # @param lines [Integer] number of visible rows in `:vertical` mode, clamped to `1..6`.
    # @param expansion [Symbol] `:inline` reveals the text in place; `:external`
    #   leaves the expander's click to the caller (e.g. a dialog) and only manages
    #   its visibility.
    # @param expander_arguments [Hash] system arguments forwarded to the
    #   `Primer::Alpha::HiddenTextExpander`.
    # @param system_arguments [Hash] forwarded to the wrapping
    #   `Primer::BaseComponent`.
    # rubocop:disable Metrics/AbcSize
    def initialize(
      direction: DIRECTION_DEFAULT,
      lines: 3,
      expansion: EXPANSION_DEFAULT,
      expander_arguments: {},
      **system_arguments
    )
      super()

      @direction = ActiveSupport::StringInquirer.new(
        fetch_or_fallback(DIRECTION_OPTIONS, direction, DIRECTION_DEFAULT).to_s
      )
      @expansion = ActiveSupport::StringInquirer.new(
        fetch_or_fallback(EXPANSION_OPTIONS, expansion, EXPANSION_DEFAULT).to_s
      )

      @system_arguments = deny_tag_argument(**system_arguments)
      @system_arguments[:tag] = :div
      @system_arguments[:display] = :flex
      @system_arguments[:align_items] = @direction.vertical? ? :flex_end : :baseline
      @system_arguments[:data] = merge_data(
        @system_arguments,
        data: {
          controller: "expandable-text",
          expandable_text_mode_value: @direction,
          expandable_text_inline_value: @expansion.inline?
        }
      )
      @system_arguments[:classes] = class_names(
        @system_arguments[:classes],
        "gap-1 min-width-0"
      )

      truncate_arguments = { flex: 1, data: { expandable_text_target: "truncate" } }
      @truncate_component =
        if @direction.vertical?
          OpPrimer::VerticalTruncateComponent.new(lines:, **truncate_arguments)
        else
          Primer::Beta::Truncate.new(**truncate_arguments)
        end

      set_expander_arguments!(expander_arguments)
    end
    # rubocop:enable Metrics/AbcSize

    private

    def set_expander_arguments!(expander_arguments)
      @expander_arguments = expander_arguments.deep_dup
      @expander_arguments[:hidden] = true unless @expander_arguments.key?(:hidden)
      @expander_arguments[:mt] ||= 1
      @expander_arguments[:aria] = merge_aria(
        { aria: { label: I18n.t("js.label_expand_text") } },
        @expander_arguments
      )
      @expander_arguments[:data] = merge_data(
        { data: { expandable_text_target: "expander" } },
        @expander_arguments
      )
    end
  end
end
