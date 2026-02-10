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

class JiraImport < ApplicationRecord
  belongs_to :jira
  belongs_to :author, class_name: "User"

  has_many :transitions, class_name: "JiraImportTransition", autosave: false

  def state_machine
    @state_machine ||= JiraImportStateMachine.new(
      self,
      transition_class: JiraImportTransition,
      association_name: :transitions
    )
  end

  delegate :can_transition_to?,
           :current_state,
           :history,
           :last_transition,
           :last_transition_to,
           :transition_to!,
           :transition_to,
           :in_state?,
           :status_running?,
           :status_equal_or_after?,
           :status_equal_or_before?,
           :status_after?,
           :status_before?,
           :deletable?,
           to: :state_machine

  def project_ids
    (projects || []).pluck("id")
  end
end
