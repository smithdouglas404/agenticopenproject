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

module Projects::IdentifierFinder
  def enhanced_find(*args, allow_nil: false)
    id = args.first
    return find(*args) if args.count != 1 || !semantic_id?(id)

    result = find_by(identifier: id)
    return result if result.present?

    former_id_project = Project::FormerIdentifier.find_by(identifier: id)&.project
    if former_id_project && exists?(id: former_id_project.id)
      return former_id_project
    end

    return nil if allow_nil

    raise ActiveRecord::RecordNotFound, "Couldn't find Project with identifier #{id.inspect}"
  end

  private

  def semantic_id?(id)
    return false if !id.is_a?(String) # e.g. Array
    return false if id.to_i.to_s == id.to_s # database ID as String

    true
  end
end
