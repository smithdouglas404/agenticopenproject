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
    class FigureWrappedFilter < HTMLPipeline::NodeFilter
      # Wrap img and table elements:
      #
      # <figure>
      #   <div class="op-uc-figure--content">
      #     <img></img>  (or <table></table>)
      #   </div>
      # </figure>
      #
      # The figure and img/table elements later get CSS classes applied by BemCssFilter.
      SELECTOR = Selma::Selector.new(match_element: "img, table, figure > div")

      def selector
        SELECTOR
      end

      def handle_element(element)
        # For <div> that is a direct child of <figure>: ensure it carries the
        # op-uc-figure--content class (added when the <div> is user-authored
        # and lacks the class).
        if element.tag_name == "div"
          existing = element["class"]
          unless existing&.include?("op-uc-figure--content")
            element["class"] = [existing.presence, "op-uc-figure--content"].compact.join(" ")
          end
          return
        end

        ancestors = element.ancestors
        in_figure = ancestors.include?("figure")
        in_content_div = ancestors.include?("div")

        if in_figure
          # Already inside a user-written <figure>: only add the content <div> wrapper
          # unless one is already present (avoid double-wrapping).
          return if in_content_div

          element.before('<div class="op-uc-figure--content">', as: :html)
          element.after("</div>", as: :html)
        else
          # Not yet wrapped: insert full <figure><div> ... </div></figure> scaffold.
          element.before('<figure><div class="op-uc-figure--content">', as: :html)
          element.after("</div></figure>", as: :html)
        end
      end
    end
  end
end
