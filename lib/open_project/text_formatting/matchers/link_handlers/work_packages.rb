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
      # CKEditor `#`-based mention triggers for WP references: `#N` plain link,
      # `##N` compact quickinfo, `###N` detailed quickinfo. Distinct from the
      # matcher's generic `sep` vocabulary (where `#` *separates* prefix from
      # id in `version#3`); here it's a sigil that triggers mention recognition.
      # Shared with the PDF-export subclass in `app/models/work_package/exports/macros/links.rb`.
      HASH_TRIGGERS = %w[# ## ###].freeze

      def applicable?
        hash_trigger? && matcher.prefix.nil?
      end

      # Examples: #1234, ##1234, ###1234, #PROJ-7, ##PROJ-7, ###PROJ-7
      def call
        identifier = matcher.identifier

        if WorkPackage::SemanticIdentifier.semantic_id?(identifier)
          # Semantic shapes are only meaningful in semantic mode; classic
          # instances render the literal text fallback.
          return nil unless Setting::WorkPackageIdentifier.semantic_mode_active?

          render_for_semantic(identifier)
        else
          # Reject leading-zero shapes like `#0123` that aren't canonical id strings.
          return nil unless WorkPackage::SemanticIdentifier.numeric_id?(identifier)

          render_for_numeric(identifier.to_i)
        end
      end

      private

      def hash_trigger?
        HASH_TRIGGERS.include?(matcher.sep)
      end

      def quickinfo?
        matcher.sep.length > 1
      end

      def detailed?
        matcher.sep == "###"
      end

      def render_for_semantic(display_id)
        # Both quickinfo and plain link need the WP record so the rendered
        # HTML can carry the record id in `data-id`. Unresolved WP →
        # literal text rather than a broken reference.
        wp = OpenProject::TextFormatting::Matchers::ResourceLinksMatcher.work_package_for(display_id)
        return nil unless wp

        if quickinfo?
          render_work_package_macro(id: wp.id, display_id: wp.display_id, detailed: detailed?)
        else
          render_work_package_link(wp, fallback_id: display_id)
        end
      end

      def render_for_numeric(wp_id)
        wp = OpenProject::TextFormatting::Matchers::ResourceLinksMatcher.work_package_for(wp_id)

        if quickinfo?
          # Prefer the resolved WP's identifiers; fall back to the matched
          # id when no preload is available (classic mode).
          record_id = wp&.id || wp_id
          display_id = wp&.display_id || wp_id
          render_work_package_macro(id: record_id, display_id:, detailed: detailed?)
        else
          render_work_package_link(wp, fallback_id: wp_id)
        end
      end

      def render_work_package_macro(id:, display_id:, detailed: false)
        ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                  "",
                                                  data: { id:, display_id:, detailed: }
      end

      def render_work_package_link(work_package, fallback_id:)
        # Fall back to the bare `#N` shape when no WP is provided (classic mode,
        # render path bypassing `PatternMatcherFilter`) rather than running a
        # per-link query inside the renderer.
        label = work_package&.formatted_id || "##{fallback_id}"
        href_id = work_package&.display_id || fallback_id

        link_to(label,
                work_package_path_or_url(id: href_id, only_path: context[:only_path]),
                class: "issue work_package",
                data: {
                  hover_card_trigger_target: "trigger",
                  hover_card_url: hover_card_work_package_path(href_id)
                })
      end
    end
  end
end
