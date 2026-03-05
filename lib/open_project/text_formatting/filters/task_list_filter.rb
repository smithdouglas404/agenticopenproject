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

module OpenProject::TextFormatting
  module Filters
    # Renders GFM task list items.
    #
    # When the Commonmarker `tasklist` extension is disabled (our default), list
    # items whose text begins with "[ ] " or "[x] " are rendered as plain text:
    #   <li>[ ] unchecked item</li>
    #   <li>[x] checked item</li>
    #
    # This filter detects those patterns in the first text chunk of each <li>
    # and replaces them with a disabled checkbox input.
    class TaskListFilter < HTMLPipeline::NodeFilter
      SELECTOR = Selma::Selector.new(
        match_element: "li",
        match_text_within: "li"
      )

      ITEM_PATTERN   = /\A\[([xX ])\] /
      CHECKED_VALUES = %w[x X].freeze

      def selector
        SELECTOR
      end

      def after_initialize
        @expect_first_chunk = false
      end

      def reset!
        after_initialize
      end

      def handle_element(element)
        return unless element.tag_name == "li"

        @expect_first_chunk = true
      end

      def handle_text_chunk(text)
        return unless @expect_first_chunk

        @expect_first_chunk = false
        content = text.to_s

        return unless (m = content.match(ITEM_PATTERN))

        checked   = CHECKED_VALUES.include?(m[1])
        remaining = content.sub(ITEM_PATTERN, "")
        checkbox  = render_checkbox(checked)

        text.replace("#{checkbox}#{remaining}", as: :html)
      end

      private

      def render_checkbox(checked)
        attrs = +%( type="checkbox" class="op-uc-list--task-checkbox" disabled="disabled")
        attrs << %( checked="checked") if checked
        "<input#{attrs}/>"
      end
    end
  end
end
