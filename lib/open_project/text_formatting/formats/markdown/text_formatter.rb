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

module OpenProject::TextFormatting::Formats
  module Markdown
    # Text-output sibling of `Markdown::Formatter`. Shares the matcher and
    # mention pipeline with the rich renderer so identifier resolution
    # stays consistent across channels, then collapses the final DOM to
    # text via `PlainTextOutputFilter`. Intended for plain/text mailers
    # and other channels where HTML would be a foreign body.
    class TextFormatter < OpenProject::TextFormatting::Formats::BaseFormatter
      def initialize(context)
        super(context.merge(plain_text: true))
      end

      def to_html(text)
        pipeline.call(text, context)[:output].to_s
      end

      def filters
        [
          OpenProject::TextFormatting::Filters::SettingMacrosFilter,
          OpenProject::TextFormatting::Filters::MarkdownFilter,
          OpenProject::TextFormatting::Filters::SanitizationFilter,
          OpenProject::TextFormatting::Filters::MentionFilter,
          OpenProject::TextFormatting::Filters::PatternMatcherFilter,
          OpenProject::TextFormatting::Filters::PlainTextOutputFilter
        ]
      end

      def self.format
        :markdown_as_text
      end
    end
  end
end
