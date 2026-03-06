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
    class LinkAttributeFilter < HTMLPipeline::NodeFilter
      SELECTOR = Selma::Selector.new(match_element: "a")

      def selector
        SELECTOR
      end

      def handle_element(element)
        href = element["href"]

        # Strip style attribute to prevent hidden/malicious links (e.g. display:none)
        element.remove_attribute("style")

        # TOC nav contains fragment links to same-page headings; they need neither
        # target nor rel.  Other fragment links (e.g. heading permalink anchors)
        # are not inside <nav> and do receive rel but not target.
        in_nav = element.ancestors.include?("nav")
        return if element["target"] || (href&.start_with?("#") && in_nav)

        # Add rel to all links that are not same-page TOC links
        existing_rel = element["rel"]
        element["rel"] = "noopener noreferrer" if existing_rel.blank?

        # Skip target for fragment links (permalink anchors stay in place)
        return if href&.start_with?("#")

        element["target"] = context.fetch(:target, "_top")
      end
    end
  end
end
