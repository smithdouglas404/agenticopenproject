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
    class MentionFilter < HTML::Pipeline::Filter
      include ERB::Util
      include ActionView::Helpers::UrlHelper
      include OpenProject::ObjectLinking
      include OpenProject::StaticRouting::UrlHelpers

      def call
        preload_work_package_mentions

        doc.search("mention").each do |mention|
          anchor = mention_anchor(mention)
          mention.replace(anchor) if anchor
        end

        doc
      end

      private

      # Bounded two-SELECT preload for WP mentions: an unscoped fetch (label
      # resolution regardless of viewer) plus a visibility-scoped id pluck
      # (gate anchor vs plain-text render). Mirrors the pattern
      # `ResourceLinksMatcher` uses for `#N` text references so mentions
      # and references resolve to the same shape for the same recipient,
      # and avoids the per-mention query the old `.visible.find_by` did.
      def preload_work_package_mentions
        ids = mention_work_package_ids
        if ids.empty?
          @mentioned_work_packages = {}
          @visible_mentioned_ids = Set.new
          return
        end

        scope = WorkPackage.where(id: ids)
        # Static-HTML channels need `type` and `status` to render
        # quickinfo envelopes as anchors instead of `<opce-*>` widgets.
        scope = scope.includes(:type, :status) if context[:as_static_html]
        @mentioned_work_packages = scope.index_by(&:id)
        @visible_mentioned_ids = WorkPackage.visible.where(id: ids).pluck(:id).to_set
      end

      def mention_work_package_ids
        doc.css('mention[data-type="work_package"]').filter_map { |m| mention_id(m)&.to_i }.uniq
      end

      def mention_anchor(mention)
        mention_instance = class_from_mention(mention)

        case mention_instance
        when Group
          group_mention(mention_instance)
        when User
          user_mention(mention_instance)
        when WorkPackage
          work_package_mention(mention_instance, mention)
        else
          mention_instance
        end
      end

      def user_mention(user)
        link_to_user(user,
                     only_path: context[:only_path],
                     class: "user-mention")
      end

      def group_mention(group)
        link_to_group(group,
                      only_path: context[:only_path],
                      class: "user-mention")
      end

      def work_package_mention(work_package, mention)
        return Nokogiri::XML::Text.new(work_package.formatted_id, mention.document) if text_only?(work_package)

        # Match the label and URL convention used for `#N` text references
        # elsewhere in the markdown pipeline.
        case mention.text.count("#")
        when 3 then work_package_quickinfo(work_package, detailed: true)
        when 2 then work_package_quickinfo(work_package, detailed: false)
        else        work_package_link(work_package)
        end
      end

      # Plain-text channels and inaccessible WPs both render the
      # `formatted_id` without an anchor or quickinfo widget — the
      # latter would resolve to a hover-card endpoint the recipient
      # can't reach.
      def text_only?(work_package)
        context[:as_text] || @visible_mentioned_ids.exclude?(work_package.id)
      end

      def work_package_quickinfo(work_package, detailed:)
        return work_package_static_macro(work_package, detailed:) if context[:as_static_html]

        ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                  "",
                                                  data: { id: work_package.id,
                                                          display_id: work_package.display_id,
                                                          detailed: }
      end

      # Static fallback shared with the PatternMatcherFilter's `##`/`###`
      # path so envelope-driven and text-driven references render the same
      # shape in channels that cannot hydrate the custom element. Always
      # uses the WP's current `formatted_id`, normalising any historical
      # alias the envelope may have been authored with.
      def work_package_static_macro(work_package, detailed:)
        label = OpenProject::TextFormatting::Matchers::LinkHandlers::WorkPackages
                  .compose_static_macro_label(work_package, label: work_package.formatted_id, detailed:)

        link_to(label,
                work_package_path_or_url(id: work_package.display_id, only_path: context[:only_path]),
                class: "issue work_package")
      end

      def work_package_link(work_package)
        display_id = work_package.display_id
        link_to(work_package.formatted_id,
                work_package_path_or_url(id: display_id, only_path: context[:only_path]),
                class: "issue work_package",
                data: {
                  hover_card_trigger_target: "trigger",
                  hover_card_url: hover_card_work_package_path(display_id)
                })
      end

      # WP label resolution is unscoped (preloaded above); visibility is
      # gated separately in `text_only?` so an inaccessible WP renders
      # its current formatted_id rather than the envelope text the
      # author originally typed. User/group mentions stay visibility-gated
      # at the find — there's no equivalent text-only render path for
      # principals.
      def class_from_mention(mention)
        case mention.attributes["data-type"].value
        when "user"         then User.visible.find_by(id: mention_id(mention))
        when "group"        then Group.visible.find_by(id: mention_id(mention))
        when "work_package" then @mentioned_work_packages[mention_id(mention)&.to_i]
        else raise ArgumentError
        end || fallback_text(mention)
      end

      ##
      # Pass the content of the mention back to Nokogiri
      # without unescaping any sanitization taken place already.
      def fallback_text(mention)
        Nokogiri::XML::Text.new(mention.text, doc)
      end

      # For link_to
      def controller; end

      def mention_id(mention)
        value = mention.attributes["data-id"]&.value
        # Reject semantic-shaped data-ids: `PROJ-42` must not silently
        # resolve to WP id 42 via embedded-digit extraction.
        value if value&.match?(/\A\d+\z/)
      end
    end
  end
end
