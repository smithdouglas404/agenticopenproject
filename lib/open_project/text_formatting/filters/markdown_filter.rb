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
    class MarkdownFilter < HTMLPipeline::ConvertFilter
      # Commonmarker (with github_pre_lang: true) places the permalink anchor
      # BEFORE the heading text and puts the id on the anchor, e.g.:
      #   <h3><a href="#slug" aria-hidden="true" class="anchor" id="slug"></a>Heading</h3>
      #
      # We restructure each heading to match the expected format:
      #   <h3 id="slug">Heading\n<a href="#slug" aria-hidden="true" class="anchor"></a></h3>
      # (id moved to heading element, anchor moved to after text, id removed from anchor)
      HEADING_ANCHOR_RE = /
        (<h([1-6])>)                             # $1 heading opening, $2 level
        \s*
        (<a\s[^>]*\bid="([^"]+)"[^>]*><\/a>)    # $3 anchor element, $4 id value
        (.*?)                                    # $5 heading text
        (<\/h\2>)                                # $6 heading closing tag
      /xm

      # Convert Markdown to HTML using CommonMarker
      def call(text, context: @context)
        html = Commonmarker.to_html(text, options: commonmarker_options, plugins: commonmarker_plugins)
                           .tap(&:rstrip!)
        restructure_headings(html)
      end

      private

      def restructure_headings(html)
        html.gsub(HEADING_ANCHOR_RE) do
          level    = $2
          anchor   = $3
          id_value = $4
          text     = $5.strip

          # Remove id attribute from anchor (id moves to heading element)
          anchor_no_id = anchor.gsub(/\s*\bid="[^"]*"/, "")
          "<h#{level} id=\"#{id_value}\">#{text}\n#{anchor_no_id}</h#{level}>"
        end
      end

      ##
      # CommonMarker Options
      # https://github.com/gjtorikian/commonmarker#options
      def commonmarker_options
        {
          parse: { smart: false },
          extension: commonmark_extensions,
          render: {
            unsafe: true,
            escape: false,
            github_pre_lang: true,
            hardbreaks: context[:gfm] != false,
            escaped_char_spans: false
          }
        }
      end

      def commonmarker_plugins
        { syntax_highlighter: nil }
      end

      ##
      # Extensions to the default CommonMarker operation
      def commonmark_extensions
        # Disable all the extension enabled by default by commonmarker.
        %i[strikethrough tagfilter table autolink tasklist shortcodes]
          .index_with(false)
          # But enable those that the context has enabled explicitly
          .merge(context.fetch(:commonmarker_extensions, %i[table strikethrough tagfilter]).index_with(true))
      end
    end
  end
end
