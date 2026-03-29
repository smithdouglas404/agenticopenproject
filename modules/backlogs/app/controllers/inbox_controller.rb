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

class InboxController < RbApplicationController
  include OpTurbo::ComponentStream

  before_action :not_authorized_on_feature_flag_inactive
  before_action :load_work_package

  def move_to_sprint_dialog
    respond_with_dialog Backlogs::MoveToSprintDialogComponent.new(
      work_package: @work_package,
      project: @project
    )
  end

  def reorder
    call = Stories::UpdateService
      .new(user: current_user, story: @work_package)
      .call(attributes: { move_to: reorder_param })

    return failure_response(call.message) unless call.success?

    replace_inbox_component_via_turbo_stream
    respond_with_turbo_streams
  end

  # Move a work package from the Inbox to a Sprint, or reorder it within the Inbox.
  def move
    target_type, sprint_id = move_params[:target_id].split(":", 2)
    attributes = target_type == "sprint" ? { sprint_id: } : {}

    call = Stories::UpdateService
      .new(user: current_user, story: @work_package)
      .call(attributes:, **position_attributes)

    return failure_response(call.message) unless call.success?

    replace_inbox_component_via_turbo_stream
    replace_sprint_component_via_turbo_stream(sprint_id) if target_type == "sprint"
    respond_with_turbo_streams
  end

  private

  def load_work_package
    @work_package = WorkPackage.visible.find(params[:id])
  end

  def replace_inbox_component_via_turbo_stream
    inbox_work_packages = Backlog.inbox_for(project: @project)
    replace_via_turbo_stream(
      component: Backlogs::InboxComponent.new(work_packages: inbox_work_packages, project: @project),
      method: :morph
    )
  end

  def replace_sprint_component_via_turbo_stream(sprint_id)
    sprint = Agile::Sprint.for_project(@project).visible.find(sprint_id)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: I18n.t(:label_inbox), to: sprint.name)
    )
    replace_via_turbo_stream(
      component: Backlogs::SprintComponent.new(sprint: sprint, project: @project),
      method: :morph
    )
  end

  def failure_response(reason)
    render_error_flash_message_via_turbo_stream(
      message: I18n.t(:notice_unsuccessful_update_with_reason, reason:)
    )
    respond_with_turbo_streams(status: :unprocessable_entity)
  end

  def move_params
    params.require(%i[target_id])
    params.permit(:position, :target_id)
  end

  def position_attributes
    { position: move_params[:position]&.to_i }.compact
  end

  def reorder_param
    params.expect(:direction)
  end
end
