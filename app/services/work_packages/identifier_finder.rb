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
  # Single entry point for resolving a work package from any identifier form:
  #   - Numeric string ("12345")     → find by primary key
  #   - Semantic string ("PROJ-42")  → registry lookup, then computed fallback
  #
  # Always applies visibility scope when a user is provided.
  class IdentifierFinder
    SEMANTIC_PATTERN = /\A([A-Za-z][A-Za-z0-9_]*)-(\d+)\z/

    # @param param [String, Integer] the raw identifier param
    # @param user [User, nil] used to scope results to visible work packages
    # @return [WorkPackage, nil]
    def self.find(param, user: nil)
      param = param.to_s.strip
      return find_by_pk(param, user:) if param.match?(/\A\d+\z/)

      find_by_semantic(param, user:)
    end

    # Same as find but raises ActiveRecord::RecordNotFound on miss.
    def self.find!(param, user: nil)
      find(param, user:) || raise(ActiveRecord::RecordNotFound, "WorkPackage not found: #{param}")
    end

    class << self
      private

      def find_by_pk(id, user:)
        scope(user).find_by(id:)
      end

      def find_by_semantic(identifier, user:)
        # 1. Registry lookup — handles current and historic identifiers
        wp_id = WorkPackageSemanticId.find_by(identifier:)&.work_package_id
        return scope(user).find_by(id: wp_id) if wp_id

        # 2. Computed fallback — handles registry misses and new WPs accessed
        #    via an old project prefix before the registry has been populated
        prefix, seq = parse(identifier)
        return nil unless prefix && seq

        project = resolve_project(prefix)
        return nil unless project

        scope(user).find_by(project:, sequence_number: seq)
      end

      def parse(identifier)
        m = identifier.match(SEMANTIC_PATTERN)
        m ? [m[1], m[2].to_i] : nil
      end

      def resolve_project(prefix)
        Project.find_by(identifier: prefix) || Project.friendly.find(prefix)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def scope(user)
        user ? WorkPackage.visible(user) : WorkPackage.all
      end
    end
  end
end
