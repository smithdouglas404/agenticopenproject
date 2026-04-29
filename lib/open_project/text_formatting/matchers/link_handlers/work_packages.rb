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

module OpenProject::TextFormatting::Matchers
  module LinkHandlers
    class WorkPackages < Base
      ##
      # Match work package links.
      # Condition: Separator is #|##|###
      # Condition: Prefix is nil
      def applicable?
        %w(# ## ###).include?(matcher.sep) && matcher.prefix.nil?
      end

      #
      # Examples:
      #
      # #1234, ##1234, ###1234
      def call
        wp_id = matcher.identifier.to_i

        # Ensure that the element was entered numeric,
        # prohibits links to things like #0123
        return if wp_id.to_s != matcher.identifier

        render_link(wp_id, matcher)
      end

      def render_link(wp_id, matcher)
        if ["##", "###"].include?(matcher.sep)
          render_work_package_macro(wp_id, detailed: (matcher.sep === "###"))
        else
          render_work_package_link(wp_id)
        end
      end

      private

      def render_work_package_macro(wp_id, detailed: false)
        ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                  "",
                                                  data: { id: wp_id, detailed: }
      end

      def render_work_package_link(wp_id)
        # Read from the per-render preload populated by
        # `ResourceLinksMatcher.preload_for_doc`. Nil means either no preload
        # ran (e.g. a code path that bypasses `PatternMatcherFilter`) or the
        # WP wasn't found — in both cases we fall back to the legacy `#N` shape
        # rather than running a per-link query inside the renderer.
        wp = OpenProject::TextFormatting::Matchers::ResourceLinksMatcher
               .work_packages_lookup
               &.[](wp_id)
        label = wp&.formatted_id || "##{wp_id}"
        # `display_id` is the semantic identifier (PROJ-7) in semantic mode and
        # the numeric id in classic mode — same field, mode-agnostic.
        href_id = wp&.display_id || wp_id

        link_to(label,
                work_package_path_or_url(id: href_id, only_path: context[:only_path]),
                class: "issue work_package",
                data: {
                  hover_card_trigger_target: "trigger",
                  hover_card_url: hover_card_work_package_path(wp_id)
                })
      end
    end
  end
end
