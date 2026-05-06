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
      # #1234, ##1234, ###1234, #PROJ-7, ##PROJ-7, ###PROJ-7
      def call
        identifier = matcher.identifier

        if WorkPackage::SemanticIdentifier.semantic_id?(identifier)
          # Semantic shape is only valid when the instance is in semantic
          # mode. Classic instances render the literal text fallback.
          return nil unless Setting::WorkPackageIdentifier.semantic_mode_active?

          render_for_semantic(identifier, matcher)
        else
          # Numeric branch: reject leading-zero shapes ("#0123") that round-
          # trip back to a different integer.
          return nil if identifier != identifier.to_i.to_s

          render_for_numeric(identifier.to_i, matcher)
        end
      end

      private

      def render_for_semantic(display_id, matcher)
        if ["##", "###"].include?(matcher.sep)
          # Quickinfo: the frontend Angular component does its own APIv3
          # lookup and handles missing WPs. data-id carries the user-facing
          # display_id straight through.
          render_work_package_macro(display_id, detailed: matcher.sep == "###")
        else
          # Plain `#PROJ-N` link: needs the WP record for the formatted_id
          # label and hover-card URL. Cache miss → literal text fallback
          # rather than a broken `/work_packages/PROJ-N` URL.
          wp = OpenProject::TextFormatting::Matchers::ResourceLinksMatcher.work_package_for(display_id)
          return nil unless wp

          render_work_package_link(wp, fallback_id: display_id)
        end
      end

      def render_for_numeric(wp_id, matcher)
        wp = OpenProject::TextFormatting::Matchers::ResourceLinksMatcher.work_package_for(wp_id)

        if ["##", "###"].include?(matcher.sep)
          # Prefer the resolved WP's display_id so `##1234` rendered in
          # semantic mode also shows the user-facing identifier in the
          # editor model. Cache miss (classic mode or unknown WP) keeps the
          # numeric data-id, matching the pre-PR behaviour.
          data_id = wp&.display_id || wp_id
          render_work_package_macro(data_id, detailed: matcher.sep == "###")
        else
          render_work_package_link(wp, fallback_id: wp_id)
        end
      end

      # `data-id` carries the user-facing display id (semantic in semantic
      # mode, numeric in classic) end-to-end. The frontend Angular component
      # passes it straight to APIv3, which resolves either shape via
      # `find_by_display_id`.
      def render_work_package_macro(data_id, detailed: false)
        ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                  "",
                                                  data: { id: data_id, detailed: }
      end

      def render_work_package_link(work_package, fallback_id:)
        # Nil `work_package` means no preload ran (classic mode, no
        # references in the doc, or a render path that bypasses
        # `PatternMatcherFilter`) OR the WP wasn't found. We fall back to
        # the legacy `#N` shape rather than running a per-link query inside
        # the renderer.
        label = work_package&.formatted_id || "##{fallback_id}"
        # `display_id` is the semantic identifier (PROJ-7) in semantic mode
        # and the numeric id in classic mode — same field, mode-agnostic.
        href_id = work_package&.display_id || fallback_id

        link_to(label,
                work_package_path_or_url(id: href_id, only_path: context[:only_path]),
                class: "issue work_package",
                data: {
                  hover_card_trigger_target: "trigger",
                  # The hover-card route accepts both numeric and semantic
                  # ids (HoverCardComponent calls find_by_display_id). Pass
                  # display_id so the URL matches the user-facing identifier.
                  hover_card_url: hover_card_work_package_path(href_id)
                })
      end
    end
  end
end
