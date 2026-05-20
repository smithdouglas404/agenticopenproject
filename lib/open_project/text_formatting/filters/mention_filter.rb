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

      MENTION_TYPES = {
        "user" => User,
        "group" => Group,
        "work_package" => WorkPackage
      }.freeze

      def call
        cache = preload_mentioned_records
        doc.search("mention").each do |mention|
          anchor = mention_anchor(mention, cache)
          mention.replace(anchor) if anchor
        end

        doc
      end

      private

      # Resolves all mentioned records in one SELECT per class. Ids stay as
      # strings so the lookup matches raw `data-id` values without coercion.
      def preload_mentioned_records
        mention_ids_by_class.to_h do |klass, ids|
          [klass, klass.visible.where(id: ids).index_by { |record| record.id.to_s }]
        end
      end

      def mention_ids_by_class
        doc.search("mention").each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |mention, acc|
          id = mention_id(mention) or next
          acc[mention_class(mention)] << id
        end
      end

      def mention_anchor(mention, cache)
        record = resolve_mention(mention, cache)

        case record
        when Group
          group_mention(record)
        when User
          user_mention(record)
        when WorkPackage
          work_package_mention(record, mention)
        else
          record
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
        # Render the mention with the same label and URL convention used for
        # `#N` text references elsewhere in the markdown pipeline.
        display_id = work_package.display_id

        case mention.text.count("#")
        when 3
          ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                    "",
                                                    data: { id: work_package.id, display_id:, detailed: true }
        when 2
          ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                    "",
                                                    data: { id: work_package.id, display_id:, detailed: false }
        else
          link_to(work_package.formatted_id,
                  work_package_path_or_url(id: display_id, only_path: context[:only_path]),
                  class: "issue work_package",
                  data: {
                    hover_card_trigger_target: "trigger",
                    hover_card_url: hover_card_work_package_path(display_id)
                  })
        end
      end

      def resolve_mention(mention, cache)
        klass = mention_class(mention)
        id = mention_id(mention)
        cache.dig(klass, id) || fallback_text(mention)
      end

      def mention_class(mention)
        MENTION_TYPES.fetch(mention["data-type"]) { raise ArgumentError }
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
        value = mention["data-id"]
        # Reject semantic-shaped data-ids: `PROJ-42` must not silently
        # resolve to WP id 42 via embedded-digit extraction.
        value if value&.match?(/\A\d+\z/)
      end
    end
  end
end
