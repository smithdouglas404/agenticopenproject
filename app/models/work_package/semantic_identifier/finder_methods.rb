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

# Extends ActiveRecord finder methods (find, find_by, find_by!, exists?) to
# transparently resolve semantic work package identifiers (e.g. "PROJ-42")
# in addition to numeric IDs.
#
# Included into WorkPackage class methods and extended into every
# ActiveRecord::Relation via WorkPackage::SemanticIdentifier.
#
# Examples:
#   WorkPackage.find("PROJ-42")
#   WorkPackage.visible(user).find_by(id: "PROJ-42")
#   WorkPackage.exists?("PROJ-42")
module WorkPackage::SemanticIdentifier::FinderMethods
  def find(*args)
    return find_by_id_or_identifier!(args.first) if args.length == 1 && semantic_id?(args.first)

    super
  end

  # Override find_by to transparently resolve semantic identifiers when called
  # with `id:` as the sole keyword (e.g. `find_by(id: "PROJ-42")`).
  # All other find_by calls pass through to ActiveRecord unchanged.
  #
  # AR's find_by signature is find_by(arg, *args) — it doesn't use keyword splat,
  # so hash kwargs arrive as the positional `arg`. We match on that.
  def find_by(*args)
    if args.length == 1 && args.first.is_a?(Hash) && args.first.keys == [:id] && semantic_id?(args.first[:id])
      find_by_id_or_identifier(args.first[:id])
    else
      super
    end
  end

  # Mirror of find_by — Rails implements find_by! independently (not via find_by),
  # so we must override both to keep the pair consistent.
  def find_by!(*args)
    if args.length == 1 && args.first.is_a?(Hash) && args.first.keys == [:id] && semantic_id?(args.first[:id])
      find_by_id_or_identifier!(args.first[:id])
    else
      super
    end
  end

  def exists?(conditions = :none)
    return super unless semantic_id?(conditions)

    exists_by_semantic_identifier?(conditions)
  end

  private

  # Resolves any identifier form to a WorkPackage.
  #   - Numeric string ("12345")    → find by primary key
  #   - Semantic string ("PROJ-42") → lookup via work_packages table and alias table
  #
  # Returns nil on miss.
  def find_by_id_or_identifier(identifier)
    return find_by(id: identifier) unless semantic_id?(identifier)

    find_by_semantic_identifier(identifier)
  end

  # Same as find_by_id_or_identifier but raises ActiveRecord::RecordNotFound on miss.
  def find_by_id_or_identifier!(identifier)
    find_by_id_or_identifier(identifier) ||
      raise(ActiveRecord::RecordNotFound.new(
              "Couldn't find WorkPackage with identifier=#{identifier}", "WorkPackage", "identifier", identifier
            ))
  end

  # Returns true when value looks like a semantic work package identifier (e.g. "PROJ-42").
  # Non-string values (Integer, Hash, nil, Array) and numeric strings ("123", " 456 ")
  # return false — these fall through to standard ActiveRecord lookup.
  def semantic_id?(value)
    return false unless value.is_a?(String)

    stripped = value.strip
    stripped.to_i.to_s != stripped
  end

  # Looks up by current identifier column first, then falls back to
  # the alias table for historical identifiers. Two-step because AR's
  # .or() requires structurally compatible relations (joins breaks it).
  def find_by_semantic_identifier(identifier)
    find_by(identifier:) ||
      by_semantic_alias(identifier).first
  end

  def exists_by_semantic_identifier?(identifier)
    # Use where().exists? instead of exists?(identifier:) to keep the intent
    # clear — our exists? override intercepts string conditions, and while
    # hash conditions would pass through safely, the explicit form avoids
    # any ambiguity about recursion.
    where(identifier:).exists? || # rubocop:disable Rails/WhereExists
      by_semantic_alias(identifier).exists?
  end

  def by_semantic_alias(identifier)
    joins(:semantic_aliases).where(work_package_semantic_aliases: { identifier: })
  end
end
