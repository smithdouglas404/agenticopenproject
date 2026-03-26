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
# Overrides find and exists? to support semantic identifiers ("SC-123").
# Numeric IDs pass through to ActiveRecord. Identifiers are resolved
# structurally: parse prefix + sequence → resolve project (via Project's
# FriendlyId history) → find WP by (project_id, sequence_number).
#
# Uses FriendlyId's Object#friendly_id? for dispatch (already available
# globally via FriendlyId::ObjectUtils, loaded for Project).
#
# Resolution chain:
#   1. Structural: parse "PREFIX-SEQ", resolve prefix to project, find WP
#   2. Move fallback: check work_package_moves for WPs that left a project
#   3. Numeric fallback: delegate to ActiveRecord (primary key lookup)
module WorkPackages::Identifier::FinderMethods
  def find(*args)
    return super if args.length != 1

    id = args.first
    return super unless id.friendly_id?

    resolve_identifier(id) || super
  end

  def exists?(*args)
    return super unless args.length == 1 && args.first.friendly_id?

    resolve_identifier(args.first).present? || super
  end

  private

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
    move = WorkPackageMove.find_by(source_project_id:, sequence_number:)
    find_by(id: move.work_package_id) if move
  end
end
