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

# Extends ActiveRecord finder methods to support semantic work package
# identifiers (e.g. "PROJ-42") in addition to numeric IDs.
#
# - find("PROJ-42") resolves transparently
# - find_by(id:)/find_by!(id:) raise ArgumentError for semantic strings
# - find_by_display_id("PROJ-42") is the explicit nil-on-miss resolver
# - exists?("PROJ-42") resolves transparently
#
# Included into WorkPackage class methods and extended into every
# ActiveRecord::Relation via WorkPackage::SemanticIdentifier.
module WorkPackage::SemanticIdentifier::FinderMethods
  def find(*args)
    ids = args.length == 1 && args.first.is_a?(Array) ? args.first : args

    if ids.length == 1 && semantic_id?(ids.first)
      return find_by_display_id!(ids.first)
    end

    if ids.any? { |id| semantic_id?(id) }
      raise ArgumentError,
            "Semantic identifiers in multi-argument find is not yet supported. " \
            "Resolve each identifier individually via find_by_display_id instead."
    end

    super
  end

  # Guard find_by against semantic identifiers passed via `id:` or `identifier:`.
  # Developers should use find("PROJ-42") or find_by_display_id("PROJ-42") instead.
  def find_by(*args)
    reject_semantic_id_in_find_by!(args)
    super
  end

  def find_by!(*args)
    reject_semantic_id_in_find_by!(args)
    super
  end

  def exists?(conditions = :none)
    return super unless semantic_id?(conditions)

    exists_by_semantic_identifier?(conditions)
  end

  # Resolves any display-facing identifier to a WorkPackage.
  #   - Numeric string ("12345")    → find by primary key
  #   - Semantic string ("PROJ-42") → lookup via identifier column and alias table
  #
  # Returns nil on miss.
  def find_by_display_id(identifier)
    return find_by(id: identifier) unless semantic_id?(identifier)

    find_by_semantic_identifier(identifier)
  end

  # Same as find_by_display_id but raises ActiveRecord::RecordNotFound on miss.
  def find_by_display_id!(identifier)
    find_by_display_id(identifier) ||
      raise(ActiveRecord::RecordNotFound.new(
              "Couldn't find WorkPackage with identifier=#{identifier}", "WorkPackage", "identifier", identifier
            ))
  end

  private

  def reject_semantic_id_in_find_by!(args)
    return unless args.length == 1 && args.first.is_a?(Hash)

    hash = args.first
    key, value = (hash.assoc(:id) || hash.assoc("id")) ||
                 (hash.assoc(:identifier) || hash.assoc("identifier"))
    return unless key && semantic_id?(value)

    raise ArgumentError,
          "Semantic identifier #{value.inspect} cannot be passed to find_by(#{key}:). " \
          "Use find(#{value.inspect}) or find_by_display_id(#{value.inspect}) instead."
  end

  # Returns true when value looks like a semantic work package identifier (e.g. "PROJ-42").
  # Non-string values (Integer, Hash, nil, Array) and numeric strings ("123", " 456 ")
  # return false — these fall through to standard ActiveRecord lookup.
  def semantic_id?(value)
    return false unless value.is_a?(String)

    stripped = value.strip
    stripped.to_i.to_s != stripped
  end

  # Resolves a semantic identifier (e.g. "PROJ-42") to a WorkPackage in
  # a single query. Matches against the current identifier column OR a
  # correlated EXISTS on the alias table for historical identifiers.
  # Returns nil on miss.
  #
  # Generates:
  #
  #   SELECT "work_packages".* FROM "work_packages"
  #   WHERE ("work_packages"."identifier" = 'PROJ-42'
  #      OR EXISTS (
  #        SELECT 1 FROM "work_package_semantic_aliases"
  #        WHERE "work_package_semantic_aliases"."work_package_id" = "work_packages"."id"
  #          AND "work_package_semantic_aliases"."identifier" = 'PROJ-42'
  #      ))
  #   ORDER BY "work_packages"."id" ASC LIMIT 1
  def find_by_semantic_identifier(identifier)
    where(identifier:).or(where(semantic_alias_exists(identifier))).first
  end

  def exists_by_semantic_identifier?(identifier)
    where(identifier:).or(where(semantic_alias_exists(identifier))).exists?
  end

  # Correlated EXISTS subquery that matches work packages having a
  # semantic alias row with the given identifier.
  def semantic_alias_exists(identifier)
    alias_table = WorkPackageSemanticAlias.arel_table

    WorkPackageSemanticAlias
      .where(alias_table[:work_package_id].eq(arel_table[:id]))
      .where(identifier:)
      .arel
      .exists
  end
end
