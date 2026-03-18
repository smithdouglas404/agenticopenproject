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

class Sprints::StartService < BaseServices::BaseCallable
  include Shared::ServiceContext

  attr_reader :user, :model

  def initialize(user:, model:)
    super()
    @user = user
    @model = model
  end

  def perform
    in_context(model, send_notifications: false) do
      start_sprint
    end
  end

  private

  def start_sprint
    return unsuccessful_start_result unless model.in_planning?

    result = ensure_task_board
    return result if result.failure?

    model.active!

    ServiceResult.success(result: model)
  rescue ActiveRecord::RecordInvalid
    unsuccessful_start_result
  rescue ActiveRecord::RecordNotUnique
    add_only_one_active_sprint_error
    unsuccessful_start_result
  end

  def unsuccessful_start_result
    ServiceResult.failure(result: model,
                          errors: model.errors,
                          message: unsuccessful_start_message)
  end

  def ensure_task_board
    return ServiceResult.success(result: model.task_board) if model.task_board?

    Boards::SprintTaskBoardCreateService
      .new(user:)
      .call(project: model.project, sprint: model, name: model.board_name)
  end

  def unsuccessful_start_message
    model.errors.full_messages.to_sentence if model.errors.any?
  end

  def add_only_one_active_sprint_error
    return if model.errors.added?(:status, :only_one_active_sprint_allowed)

    model.errors.add(:status, :only_one_active_sprint_allowed)
  end
end
