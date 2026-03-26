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

# Compute-on-read identifier resolution for work packages.
#
# All historical resolution is structural — no slug history table is used
# for work packages. Instead, identifiers are parsed into prefix + sequence
# and resolved via Project's own FriendlyId history.
#
# Resolution chain:
#   1. Primary column match (via FriendlyId base)
#   2. Structural resolution: parse prefix + sequence, resolve prefix to
#      project (via Project FriendlyId history), find WP by sequence_number
#   3. Move resolution: check work_package_moves for WPs that left a project
module WorkPackages::Identifier::FinderMethods
  include FriendlyId::FinderMethods

  def exists_by_friendly_id?(id)
    super || resolve_identifier(id).present?
  end

  private

  def first_by_friendly_id(id)
    super || resolve_identifier(id)
  end

  def resolve_identifier(id)
    prefix, seq = id.to_s.match(/\A(.+)-(\d+)\z/)&.captures
    return unless prefix && seq

    seq = seq.to_i
    project = Project.friendly.find(prefix)

    find_by(project_id: project.id, sequence_number: seq) ||
      find_moved_work_package(project.id, seq)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # Finds a WP that was moved FROM the given project with the given sequence.
  def find_moved_work_package(source_project_id, sequence_number)
    move = WorkPackageMove.find_by(
      source_project_id:,
      sequence_number:
    )
    find_by(id: move.work_package_id) if move
  end
end
