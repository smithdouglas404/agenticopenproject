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

module OpenProject::TextFormatting::Formats::Markdown
  class Formatter < OpenProject::TextFormatting::Formats::BaseFormatter
    def to_html(text)
      result = pipeline.call(text, context:)
      result[:output].html_safe
    end

    def text_filters
      [
        OpenProject::TextFormatting::Filters::SettingMacrosFilter.new
      ]
    end

    def convert_filter
      OpenProject::TextFormatting::Filters::MarkdownFilter.new
    end

    def node_filters
      [
        OpenProject::TextFormatting::Filters::SanitizationFilter::FragmentIdPrefixFilter.new,
        OpenProject::TextFormatting::Filters::TaskListFilter.new,
        OpenProject::TextFormatting::Filters::TableOfContentsFilter.new,
        OpenProject::TextFormatting::Filters::MacroFilter.new,
        OpenProject::TextFormatting::Filters::MentionFilter.new,
        OpenProject::TextFormatting::Filters::PatternMatcherFilter.new,
        OpenProject::TextFormatting::Filters::SyntaxHighlightFilter.new,
        OpenProject::TextFormatting::Filters::AttachmentFilter.new,
        OpenProject::TextFormatting::Filters::AutolinkFilter.new,
        OpenProject::TextFormatting::Filters::AutolinkCustomProtocolsFilter.new,
        OpenProject::TextFormatting::Filters::RelativeLinkFilter.new,
        OpenProject::TextFormatting::Filters::LinkAttributeFilter.new,
        OpenProject::TextFormatting::Filters::ExternalLinkCaptureFilter.new,
        OpenProject::TextFormatting::Filters::FigureWrappedFilter.new,
        OpenProject::TextFormatting::Filters::BemCssFilter.new
      ]
    end

    def sanitization_config
      OpenProject::TextFormatting::Filters::SanitizationFilter.config
    end

    def self.format
      :markdown
    end
  end
end
