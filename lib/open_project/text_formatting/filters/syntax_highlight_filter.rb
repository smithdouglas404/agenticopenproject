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
    # Applies Rouge syntax highlighting to fenced code blocks.
    #
    # Commonmarker with `github_pre_lang: true` (our default) emits:
    #   <pre lang="ruby"><code>def foobar\n  ...\nend\n</code></pre>
    #
    # This filter:
    #   1. Detects <pre lang="…"> elements and adds highlight classes.
    #   2. Unwraps the inner <code> element (remove_and_keep_content).
    #   3. Replaces the text content with Rouge-highlighted HTML.
    class SyntaxHighlightFilter < HTMLPipeline::NodeFilter
      # Match all pre elements and code elements that are direct children of pre.
      # Text is only needed for pre[lang] > code (where we apply Rouge).
      SELECTOR = Selma::Selector.new(
        match_element:     "pre, pre > code",
        match_text_within: "pre[lang] > code"
      )

      def selector
        SELECTOR
      end

      def after_initialize
        @current_lang      = nil
        @formatter         = nil
        @in_highlight_code = false
      end

      def reset!
        after_initialize
      end

      def handle_element(element)
        case element.tag_name
        when "pre"
          # Reset lang for every pre block (nil for plain blocks).
          lang = element["lang"].to_s.strip.presence
          @current_lang = lang
          if lang
            existing = element["class"].to_s
            element["class"] = [existing, "highlight", "highlight-#{lang}"].reject(&:empty?).join(" ")
          end
        when "code"
          # Only matched inside <pre> (due to "pre > code" selector).
          # Always unwrap the <code> element — keep content, remove the tag itself.
          element.remove_and_keep_content
          @in_highlight_code = @current_lang.present?
        end
      end

      def handle_text_chunk(text)
        return unless @in_highlight_code

        @in_highlight_code = false
        lang    = @current_lang
        content = text.to_s

        highlighted = highlight(lang, content)
        text.replace(highlighted, as: :html)
      end

      private

      def highlight(lang, code)
        lexer     = Rouge::Lexer.find_fancy(lang, code) || Rouge::Lexers::PlainText
        formatter = build_formatter
        formatter.format(lexer.lex(code))
      rescue StandardError
        CGI.escapeHTML(code)
      end

      def build_formatter
        @formatter ||= highlighter_class(context)
      end

      ##
      # Get highlighter class for the current context
      def highlighter_class(ctx = context)
        # Get syntax highlighting options. If we're in a CSS-constrained environment (i.e., mail),
        # inline syntax highlighting.
        if ctx[:inline_css]
          Rouge::Formatters::HTMLInline.new Rouge::Themes::Github
        else
          Rouge::Formatters::HTML.new
        end
      end
    end
  end
end
