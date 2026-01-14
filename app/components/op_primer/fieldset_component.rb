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

module OpPrimer
  # A low-level component for building fieldsets with unopinionated styling.
  #
  # This component is not designed to be used directly, but rather a primitive for
  # authors of other components and form controls.
  class FieldsetComponent < Primer::Component
    attr_reader :legend_text

    renders_one :legend, ->(**system_arguments) {
      LegendComponent.new(visually_hide_legend: @visually_hide_legend, **system_arguments)
    }

    # @param legend_text [String] A legend should be short and concise. The String will also be read by assistive technology.
    # @param visually_hide_legend [Boolean] Controls if the legend is visible. If `true`, screen reader only text will be added.
    # @param system_arguments [Hash] <%= link_to_system_arguments_docs %>
    def initialize(legend_text: nil, visually_hide_legend: false, **system_arguments) # rubocop:disable Lint/MissingSuper
      @legend_text = legend_text
      @visually_hide_legend = visually_hide_legend
      @system_arguments = deny_tag_argument(**system_arguments)
      @system_arguments[:tag] = :fieldset

      deny_aria_key(
        :label,
        "instead of `aria-label`, include `legend_text` and set `visually_hide_legend` to `true` on the component initializer.",
        **@system_arguments
      )
    end

    def render?
      content? && (legend_text.present? || legend?)
    end

    class LegendComponent < Primer::Component
      attr_reader :text

      def initialize(text: nil, visually_hide_legend: false, **system_arguments) # rubocop:disable Lint/MissingSuper
        @text = text

        @system_arguments = deny_tag_argument(**system_arguments)
        @system_arguments[:tag] = :legend
        @system_arguments[:classes] = class_names(
          @system_arguments[:classes],
          { "sr-only" => visually_hide_legend }
        )
      end

      def call
        render(Primer::BaseComponent.new(**@system_arguments)) { legend_content }
      end

      private

      def legend_content
        @legend_content ||= content || text
      end
    end
  end
end
