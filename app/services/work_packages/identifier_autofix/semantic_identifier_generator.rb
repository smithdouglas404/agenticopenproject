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

module WorkPackages
  module IdentifierAutofix
    # Generates a unique semantic identifier for a new project by combining
    # the suggestion algorithm with a DB-backed exclusion set.
    #
    # The exclusion set covers:
    # * all current project identifiers (to satisfy the uniqueness constraint)
    # * historically reserved identifiers from FriendlyId slug history
    #   (to satisfy the identifier_not_historically_reserved validation)
    class SemanticIdentifierGenerator
      def self.generate(name)
        new.generate(name)
      end

      def generate(name)
        ProjectIdentifierSuggestionGenerator.suggest_identifier(name, exclude: exclusion_set)
      end

      private

      def exclusion_set
        Project.pluck(:identifier).to_set | ProblematicIdentifiers.new.reserved_identifiers
      end
    end
  end
end
