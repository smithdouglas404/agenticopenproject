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
    # HTML NodeFilter for auto-linking urls and email addresses in HTML text nodes.
    #
    # Runs post-conversion on the HTML output so that content inside
    # <pre>, <code>, <a>, and <kbd> blocks is not auto-linked.
    #
    # Context options:
    #
    #   autolink:
    #     classes: (string) Classes to add to auto linked urls and mails
    #     enabled: (boolean)
    #
    class AutolinkFilter < HTMLPipeline::NodeFilter
      SELECTOR = Selma::Selector.new(
        match_text_within: "*",
        ignore_text_within: %w[pre code a kbd]
      )

      def selector
        SELECTOR
      end

      def handle_text_chunk(text)
        autolink_context = default_autolink_options.merge context.fetch(:autolink, {})
        return if autolink_context[:enabled] == false

        content = text.to_s
        target  = context.fetch(:target, "_top")
        attrs   = "class=\"#{autolink_context[:classes]}\" rel=\"noopener noreferrer\" target=\"#{target}\""
        linked  = ::Rinku.auto_link(
          content,
          :all,
          attrs,
          nil,
          Rinku::AUTOLINK_SHORT_DOMAINS
        )
        text.replace(linked, as: :html) if linked != content
      end

      def default_autolink_options
        {
          enabled: true,
          # Having to specify the link class again here is unfortunate. But as rinku seems to run latest,
          # it cannot receive the link class like all the rest of the links.
          classes: "op-uc-link"
        }
      end
    end
  end
end
