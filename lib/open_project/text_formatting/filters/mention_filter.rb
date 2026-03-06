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
    class MentionFilter < HTMLPipeline::NodeFilter
      include ERB::Util
      include ActionView::Helpers::UrlHelper
      include OpenProject::ObjectLinking
      include OpenProject::StaticRouting::UrlHelpers

      # Also match <br> inside <mention> so we can remove hardbreak artifacts:
      # Commonmarker with hardbreaks:true converts every newline to <br />, including
      # newlines inside <mention> inner content. Those <br> elements are stripped
      # when the mention falls back to remove_and_keep_content.
      SELECTOR = Selma::Selector.new(
        match_element: "mention, mention br"
      )

      def selector
        SELECTOR
      end

      def after_initialize
        @in_fallback_mention = false
      end

      def reset!
        after_initialize
      end

      def handle_element(element)
        if element.tag_name == "br"
          element.remove if @in_fallback_mention
          return
        end

        anchor_html = mention_anchor_html(element)
        if anchor_html
          @in_fallback_mention = false
          element.before(anchor_html, as: :html)
          element.remove
        else
          # No entity found: keep inner content (e.g. display text) as fallback.
          # Set flag so nested <br> elements (hardbreak artifacts) are stripped.
          @in_fallback_mention = true
          element.remove_and_keep_content
        end
      end

      # For link_to
      def controller; end

      private

      def mention_anchor_html(element)
        mention_instance = class_from_mention(element)

        case mention_instance
        when Group
          group_mention(mention_instance)
        when User
          user_mention(mention_instance)
        when WorkPackage
          work_package_mention(mention_instance, element)
        else
          # fallback: nil signals handle_element to use remove_and_keep_content
          nil
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

      def work_package_mention(work_package, element)
        text_content = element["data-text"] || ""
        hash_count   = text_content.count("#")

        case hash_count
        when 3
          ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                    "",
                                                    data: { id: work_package.id, detailed: true }
        when 2
          ApplicationController.helpers.content_tag "opce-macro-wp-quickinfo",
                                                    "",
                                                    data: { id: work_package.id, detailed: false }
        else
          link_to("##{work_package.id}",
                  work_package_path_or_url(id: work_package.id, only_path: context[:only_path]),
                  class: "issue work_package",
                  data: {
                    hover_card_trigger_target: "trigger",
                    hover_card_url: hover_card_work_package_path(work_package.id)
                  })
        end
      end

      def class_from_mention(element)
        mention_class = case element["data-type"]
                        when "user"
                          User
                        when "group"
                          Group
                        when "work_package"
                          WorkPackage
                        else
                          raise ArgumentError
                        end

        mention_class
          .visible
          .find_by(id: mention_id(element)) || fallback_text(element)
      end

      def fallback_text(_element)
        nil
      end

      def mention_id(element)
        attribute_value = element["data-id"]
        id_match = attribute_value&.match(/\d+/)
        id_match ? id_match[0] : nil
      end
    end
  end
end
