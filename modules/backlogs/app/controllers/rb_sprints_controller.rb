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

class RbSprintsController < RbApplicationController
  include OpTurbo::ComponentStream

  NEW_SPRINT_ACTIONS = %i[new_dialog
                          edit_dialog
                          create
                          refresh_form
                          update_agile_sprint].freeze
  SPRINT_STATE_ACTIONS = %i[start finish].freeze

  skip_before_action :load_sprint_and_project, only: NEW_SPRINT_ACTIONS
  skip_before_action :authorize, only: SPRINT_STATE_ACTIONS

  before_action :load_project, only: NEW_SPRINT_ACTIONS
  before_action :authorize_start!, only: :start
  before_action :authorize_finish!, only: :finish

  def new_dialog
    call = Sprints::SetAttributesService.new(
      user: current_user,
      model: Agile::Sprint.new,
      contract_class: EmptyContract
    ).call(attributes: converted_agile_sprint_params)

    respond_with_dialog Backlogs::NewSprintDialogComponent.new(sprint: call.result)
  end

  def edit_dialog
    @sprint = Agile::Sprint.for_project(@project).visible.find(params[:id])

    respond_with_dialog Backlogs::NewSprintDialogComponent.new(sprint: @sprint, state: :edit)
  end

  def refresh_form
    id = edit_agile_sprint_params.dig(:sprint, :id)
    sprint = id.present? ? Agile::Sprint.for_project(@project).visible.find(id) : Agile::Sprint.new

    call = Sprints::SetAttributesService.new(
      user: current_user,
      model: sprint,
      contract_class: EmptyContract
    ).call(attributes: converted_agile_sprint_params)

    update_via_turbo_stream(component: Backlogs::NewSprintFormComponent.new(sprint: call.result))

    respond_with_turbo_streams
  end

  def create
    call = Sprints::CreateService
             .new(user: current_user)
             .call(attributes: converted_agile_sprint_params)

    if call.success?
      render_success_flash_message_via_turbo_stream(message: I18n.t(:notice_successful_create))
      close_dialog_via_turbo_stream("##{Backlogs::NewSprintDialogComponent::DIALOG_ID}")
      insert_sprint_into_list_via_turbo_stream(sprint: call.result)
    else
      update_new_sprint_form_component_via_turbo_stream(sprint: call.result, base_errors: call.errors[:base])
    end

    respond_with_turbo_streams
  end

  # Called like this due to `update` being taken by legacy sprints.
  def update_agile_sprint # rubocop:disable Metrics/AbcSize
    @sprint = Agile::Sprint.for_project(@project).visible.find(params[:id])

    call = Sprints::UpdateService
             .new(user: current_user, model: @sprint)
             .call(attributes: agile_sprint_params[:sprint])

    if call.success?
      render_success_flash_message_via_turbo_stream(message: I18n.t(:notice_successful_update))
      update_sprint_header_component_via_turbo_stream(sprint: call.result)
    else
      update_new_sprint_form_component_via_turbo_stream(sprint: call.result, base_errors: call.errors[:base])
    end

    respond_with_turbo_streams
  end

  def start
    result = start_sprint

    if result.success?
      @sprint = result.result
      redirect_to project_work_package_board_path(@project, @sprint.task_board_for(@project)),
                  notice: I18n.t(:notice_successful_start)
    else
      respond_with_start_finish_failure(message: start_finish_failure_message(:start, result.message))
    end
  end

  def finish # rubocop:disable Metrics/AbcSize
    result = finish_sprint

    if result.success?
      render_success_flash_message_via_turbo_stream(message: I18n.t(:notice_successful_finish))
      close_dialog_via_turbo_stream("##{Backlogs::FinishSprintDialogComponent::DIALOG_ID}")
      remove_finished_sprint_from_list_via_turbo_stream

      if moved_to_backlog?
        update_inbox_component_via_turbo_stream
      elsif params[:move_to_sprint_id].present?
        update_target_sprint_component_via_turbo_stream
      end

      respond_with_turbo_streams
    elsif result.includes_error?(:base, :unfinished_work_packages)
      show_finish_sprint_dialog
    else
      respond_with_start_finish_failure(message: start_finish_failure_message(:finish, result.message))
    end
  end

  def edit_name
    update_header_component_via_turbo_stream(state: :edit)
    respond_with_turbo_streams
  end

  def show_name
    update_header_component_via_turbo_stream(state: :show)
    respond_with_turbo_streams
  end

  def update
    call = Versions::UpdateService
      .new(user: current_user, model: @sprint)
      .call(attributes: sprint_params)

    if call.success?
      status = 200
      state = :show
      @sprint = call.result
      render_success_flash_message_via_turbo_stream(message: I18n.t(:notice_successful_update))
    else
      status = 422
      state = :edit
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
    end

    update_header_component_via_turbo_stream(state:)
    respond_with_turbo_streams(status:)
  end

  private

  def update_header_component_via_turbo_stream(state: :show)
    @backlog = Backlog.for(sprint: @sprint, project: @project)

    update_via_turbo_stream(
      component: Backlogs::BacklogHeaderComponent.new(
        backlog: @backlog,
        project: @project,
        state:
      ),
      method: :morph
    )
  end

  def update_sprint_header_component_via_turbo_stream(sprint:)
    update_via_turbo_stream(
      component: Backlogs::SprintHeaderComponent.new(sprint:, project: @project),
      method: :morph
    )
  end

  def update_new_sprint_form_component_via_turbo_stream(sprint:, base_errors: nil)
    update_via_turbo_stream(
      component: Backlogs::NewSprintFormComponent.new(
        sprint:,
        base_errors:
      ),
      status: :bad_request
    )
  end

  def insert_sprint_into_list_via_turbo_stream(sprint:) # rubocop:disable Metrics/AbcSize
    component = Backlogs::SprintComponent.new(sprint:, project: @project)

    # Find the correct position by comparing dates with existing sprints
    sprints = Agile::Sprint.displayable_in_project(@project)
    sprint_index = sprints.index(sprint)

    action, target = if sprint_index.nil? || sprint_index == sprints.length - 1
                       # Sprint is last or not found in ordered list, append to end
                       [:append, "sprint_planning_sprint_content"]
                     elsif sprint_index.zero?
                       # Sprint is first, prepend to beginning
                       [:prepend, "sprint_planning_sprint_content"]
                     else
                       # Sprint is in the middle, insert before the next sprint
                       next_sprint = sprints[sprint_index + 1]
                       [:before, "backlogs-sprint-component-#{next_sprint.id}"]
                     end

    turbo_streams << turbo_stream.public_send(action, target, component.render_in(view_context))
  end

  def remove_finished_sprint_from_list_via_turbo_stream
    remove_via_turbo_stream(
      component: Backlogs::SprintComponent.new(sprint: @sprint, project: @project)
    )
  end

  def update_target_sprint_component_via_turbo_stream
    target_sprint = Agile::Sprint.for_project(@project).visible.find(params[:move_to_sprint_id])
    replace_via_turbo_stream(
      component: Backlogs::SprintComponent.new(sprint: target_sprint, project: @project),
      method: :morph
    )
  end

  def update_inbox_component_via_turbo_stream
    inbox_work_packages = Backlog.inbox_for(project: @project)
    replace_via_turbo_stream(
      component: Backlogs::InboxComponent.new(work_packages: inbox_work_packages, project: @project),
      method: :morph
    )
  end

  def moved_to_backlog?
    params[:unfinished_action].in?(%w[move_to_top_of_backlog move_to_bottom_of_backlog])
  end

  def show_finish_sprint_dialog
    respond_with_dialog(
      Backlogs::FinishSprintDialogComponent.new(
        sprint: @sprint,
        project: @project,
        available_sprints: Agile::Sprint.native_to_sprint_source(@project).in_planning.where.not(id: @sprint.id).order_by_date
      )
    )
  end

  # Overrides load_sprint_and_project to load the sprint from :id instead of :sprint_id
  def load_sprint_and_project
    load_project

    @sprint = if (NEW_SPRINT_ACTIONS + SPRINT_STATE_ACTIONS).include?(action_name.to_sym)
                Agile::Sprint.for_project(@project).visible.find(params[:id])
              else
                Sprint.visible.find(params[:id])
              end
  end

  def sprint_params
    params.expect(sprint: %i[name start_date effective_date])
  end

  def agile_sprint_params
    params.permit(sprint: %i[name start_date finish_date])
  end

  def edit_agile_sprint_params
    params.permit(sprint: %i[id name start_date finish_date])
  end

  def converted_agile_sprint_params
    # Do some preprocessing to make the params easier to use
    converted_sprint_params = agile_sprint_params[:sprint].to_h
    converted_sprint_params[:project] = @project

    converted_sprint_params
  end

  def start_sprint
    Sprints::StartService
      .new(user: current_user, model: @sprint)
      .call(send_notifications: false)
  end

  def finish_sprint
    Sprints::FinishService
      .new(user: current_user, model: @sprint)
      .call(
        unfinished_action: params[:unfinished_action],
        move_to_sprint_id: params[:move_to_sprint_id],
        send_notifications: false
      )
  end

  def respond_with_start_finish_failure(message:)
    render_error_flash_message_via_turbo_stream(message:)

    respond_with_turbo_streams(status: :unprocessable_entity) do |format|
      fallback_responses_for(format, alert: message)
    end
  end

  def fallback_responses_for(format, **)
    format.html { redirect_back_or_to(backlogs_project_backlogs_path(@project), **) }
  end

  def start_finish_failure_message(action, reason)
    if reason.present?
      I18n.t(:"notice_unsuccessful_#{action}_with_reason", reason:)
    else
      I18n.t(:"notice_unsuccessful_#{action}")
    end
  end

  def authorize_start!
    deny_access unless current_user.allowed_in_project?(:view_sprints, @project) &&
      Sprints::StartContract.can_start?(user: current_user, sprint: @sprint, project: @project)
  end

  def authorize_finish!
    deny_access unless current_user.allowed_in_project?(:view_sprints, @project) &&
      Sprints::StartContract.can_start_or_complete?(user: current_user, sprint: @sprint)
  end
end
