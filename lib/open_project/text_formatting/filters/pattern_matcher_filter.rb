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
    class PatternMatcherFilter < HTMLPipeline::NodeFilter
      def self.matchers
        [
          OpenProject::TextFormatting::Matchers::ResourceLinksMatcher,
          OpenProject::TextFormatting::Matchers::WikiLinksMatcher,
          OpenProject::TextFormatting::Matchers::AttributeMacros
        ]
      end

      # Match text within all elements but skip pre and code blocks.
      SELECTOR = Selma::Selector.new(
        match_text_within: "*",
        ignore_text_within: %w[pre code]
      )

      def selector
        SELECTOR
      end

      def handle_text_chunk(text)
        self.class.matchers.each do |matcher|
          matcher.call(text, doc: nil, context:)
        end
      end
    end
  end
end
