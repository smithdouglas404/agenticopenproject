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

module WorkPackage::Identifier
  extend ActiveSupport::Concern

  SEMANTIC_PATTERN = /\A([A-Za-z][A-Za-z0-9_]*)-(\d+)\z/

  included do
    has_many :semantic_ids,
             class_name: "WorkPackageSemanticId",
             foreign_key: :work_package_id,
             inverse_of: :work_package,
             dependent: :destroy

    has_one :current_semantic_id,
            -> { where(current: true) },
            class_name: "WorkPackageSemanticId",
            foreign_key: :work_package_id,
            inverse_of: :work_package

    after_create :register_semantic_id, if: -> { Setting::WorkPackageIdentifier.alphanumeric? }
  end

  class_methods do
    # Resolves any identifier form to a WorkPackage, applying visibility when user is given.
    #   - Numeric string ("12345")    → find by primary key
    #   - Semantic string ("PROJ-42") → registry lookup, then computed fallback
    #
    # Returns nil on miss.
    def find_by_identifier(param, user: nil)
      param = param.to_s.strip
      return identifier_scope(user).find_by(id: param) if param.match?(/\A\d+\z/)

      find_by_semantic_identifier(param, user:)
    end

    # Same as find_by_identifier but raises ActiveRecord::RecordNotFound on miss.
    def find_by_identifier!(param, user: nil)
      find_by_identifier(param, user:) ||
        raise(ActiveRecord::RecordNotFound, "WorkPackage not found: #{param}")
    end

    private

    def find_by_semantic_identifier(identifier, user:)
      # 1. Registry lookup — resolves current and historic identifiers
      wp_id = WorkPackageSemanticId.find_by(identifier:)&.work_package_id
      return identifier_scope(user).find_by(id: wp_id) if wp_id

      # 2. Computed fallback — handles registry misses (e.g. before backfill has run,
      #    or a WP accessed via an old project prefix not yet in the registry)
      prefix, seq = parse_semantic_identifier(identifier)
      return nil unless prefix && seq

      project = resolve_project_by_prefix(prefix)
      return nil unless project

      identifier_scope(user).find_by(project:, sequence_number: seq)
    end

    def parse_semantic_identifier(identifier)
      m = identifier.match(SEMANTIC_PATTERN)
      m ? [m[1], m[2].to_i] : nil
    end

    def resolve_project_by_prefix(prefix)
      Project.find_by(identifier: prefix) || Project.friendly.find(prefix)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def identifier_scope(user)
      user ? visible(user) : all
    end
  end

  private

  def register_semantic_id
    project = self.project
    seq = project.with_lock { project.increment!(:wp_sequence_counter).wp_sequence_counter }
    update_columns(sequence_number: seq)
    WorkPackageSemanticId.create!(identifier: "#{project.identifier}-#{seq}", work_package_id: id, current: true)
  end
end
