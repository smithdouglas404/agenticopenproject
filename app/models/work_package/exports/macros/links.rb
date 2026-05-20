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

module WorkPackage::Exports
  module Macros
    class WorkPackagesLinkHandler < OpenProject::TextFormatting::Matchers::LinkHandlers::WorkPackages
      # PDF export only handles canonical numeric `#N` references. Semantic and
      # leading-zero shapes fall through to literal text to avoid emitting a
      # `<mention data-id="0">` (since `"PROJ-1".to_i == 0`). Semantic-id
      # support in PDF export is tracked in https://community.openproject.org/wp/74766.
      def applicable?
        hash_trigger? &&
          matcher.prefix.blank? &&
          WorkPackage::SemanticIdentifier.numeric_id?(matcher.identifier)
      end

      # PDF rendering walks Markly nodes directly and bypasses the
      # `PatternMatcherFilter` preload pipeline, so the parent's cache-driven
      # `call` would miss every reference.
      def call
        render_link(matcher.identifier.to_i, matcher)
      end

      def render_link(wp_id, matcher)
        link = "#{matcher.sep}#{wp_id}"
        "<mention class=\"mention\" data-id=\"#{wp_id}\" data-type=\"work_package\" data-text=\"#{link}\">#{
          link
        }</mention>"
      end
    end

    class Links < OpenProject::TextFormatting::Matchers::ResourceLinksMatcher
      def self.link_handlers
        [WorkPackagesLinkHandler]
      end

      # Faster inclusion check before the full regex is being applied
      def self.applicable?(content)
        /#\d/.match(content)
      end
    end
  end
end
