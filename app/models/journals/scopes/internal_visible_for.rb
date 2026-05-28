# frozen_string_literal: true

# -- copyright
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
# ++

module Journals::Scopes
  # Restricts journals to those the given user is allowed to see in the given
  # project. Internal journals are hidden unless the project has internal
  # comments enabled, the Enterprise add-on is active, and the user holds
  # `view_internal_comments`.
  #
  # This is a class scope (rather than a `has_many` extension) so it composes
  # inside a subquery — for example, the journals leg of a UNION.
  #
  # The `user:` default of `User.current` assumes request context. Pass `user:`
  # explicitly from background jobs where `User.current` is not set.
  module InternalVisibleFor
    extend ActiveSupport::Concern

    class_methods do
      def internal_visible_for(project:, user: User.current)
        if EnterpriseToken.allows_to?(:internal_comments) &&
            project.enabled_internal_comments &&
            user.allowed_in_project?(:view_internal_comments, project)
          all
        else
          where(internal: false)
        end
      end
    end
  end
end
