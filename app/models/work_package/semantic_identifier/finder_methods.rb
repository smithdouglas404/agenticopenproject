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
    if args.length == 1 && !args.first.is_a?(Array)
      return semantic_id?(args.first) ? find_by_display_id!(args.first) : super
    end

    ids = args.first.is_a?(Array) ? args.first : args
    if ids.any? { |id| semantic_id?(id) }
      raise ArgumentError,
            "Semantic identifiers in multi-argument find are not supported. " \
            "Use primary keys for multi-argument lookup, or resolve each identifier " \
            "individually via find_by_display_id! (raises) or find_by_display_id (nil on miss)."
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
    if semantic_id?(identifier)
      find_by_semantic_identifier(identifier)
    else
      where(id: identifier).take # rubocop:disable Rails/FindBy -- avoid find_by, it would rerun semantic_id?
    end
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
    pair = (hash.assoc(:id) || hash.assoc("id")) ||
           (hash.assoc(:identifier) || hash.assoc("identifier"))
    return unless pair

    key, value = pair
    return unless semantic_id?(value)

    raise ArgumentError,
          "find_by(#{key}: #{value.inspect}) does not support semantic identifiers " \
          "because it cannot resolve aliases or match across identifier history. " \
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
