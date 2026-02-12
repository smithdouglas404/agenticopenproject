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

module Meetings
  class CreateContract < BaseContract
    include OpenProject::ActionAuthorizer::Registrable

    attribute :recurring_meeting_id
    attribute :uid

    validate :user_allowed_to_add
    validate :recurring_meeting_visible

    class << self
      def create_allowed?(user:, scope:)
        return false if scope.nil?

        user.allowed_in_project?(:create_meetings, scope)
      end

      def new_allowed?(user:, scope:)
        if scope.nil?
          user.allowed_in_any_project?(:create_meetings)
        else
          user.allowed_in_project?(:create_meetings, scope)
        end
      end

      def copy_allowed?(user:, scope:)
        create_allowed?(user:, scope: scope.project)
      end
    end

    register_action_authorization :new, method: :new_allowed?
    register_action_authorization :create, method: :create_allowed?
    register_action_authorization :copy, method: :copy_allowed?

    private

    def user_allowed_to_add
      return if model.project.nil?

      unless self.class.create_allowed?(user: user, scope: model.project)
        errors.add :base, :error_unauthorized
      end
    end

    def recurring_meeting_visible
      return if model.recurring_meeting.nil?

      unless user.allowed_in_project?(:view_meetings, model.recurring_meeting.project)
        errors.add :base, :error_unauthorized
      end
    end
  end
end
