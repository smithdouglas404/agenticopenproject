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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Wikis
  module Adapters
    module Providers
      module XWiki
        # Represents a parsed XWiki stable page identifier in canonical document reference format:
        # "wikiName:Space1.Space2.PageName" — e.g. "xwiki:Main.WebHome"
        # Maps to the REST API path: /wikis/{wiki}/spaces/{s1}/spaces/{s2}/pages/{page}
        PageReference = Data.define(:wiki, :spaces, :page) do
          def self.parse(identifier)
            wiki, page_path = identifier.split(":", 2)
            return nil if page_path.blank?

            parts = page_path.split(".")
            page = parts.pop
            return nil if parts.empty?

            new(wiki:, spaces: parts, page:)
          end

          def rest_path
            spaces_path = spaces.map { "/spaces/#{CGI.escapeURIComponent(it)}" }.join
            "/wikis/#{CGI.escapeURIComponent(wiki)}#{spaces_path}/pages/#{CGI.escapeURIComponent(page)}"
          end
        end
      end
    end
  end
end
