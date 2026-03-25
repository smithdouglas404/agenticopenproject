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

# Extends FriendlyId's history-aware finder with "ghost" identifier resolution.
#
# A ghost identifier is one that was never actually assigned to a work package
# but is intuitively valid — e.g. after renaming project "PROJ" to "BETTER",
# a new WP gets "BETTER-11", but users may still look up "PROJ-11".
#
# Resolution chain:
#   1. Primary column match (via FriendlyId base)
#   2. Slug history match (via FriendlyId::History)
#   3. Ghost resolution: parse prefix + sequence, resolve prefix to project
#      (via Project's own FriendlyId history), find WP by sequence_number
module WorkPackages::Identifier::FinderMethods
  include FriendlyId::History::FinderMethods

  def exists_by_friendly_id?(id)
    super || resolve_ghost_identifier(id).present?
  end

  private

  def first_by_friendly_id(id)
    super || resolve_ghost_identifier(id)
  end

  def resolve_ghost_identifier(id)
    prefix, seq = id.to_s.match(/\A(.+)-(\d+)\z/)&.captures
    return unless prefix && seq

    project = Project.friendly.find(prefix)
    find_by(project_id: project.id, sequence_number: seq.to_i)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
