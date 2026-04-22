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

class Workflows::TabsController < ApplicationController
  include OpTurbo::ComponentStream

  layout false

  before_action :require_admin

  before_action :set_type
  before_action :set_tab
  before_action :set_eligible_roles
  before_action :set_role

  def edit
    unless turbo_frame_request?
      redirect_to edit_workflow_path(@type, role_id: params[:role_id], tab: @tab)
      return
    end

    statuses_for_form

    if @type && @role && @statuses.any?
      workflows_for_form
    end
  end

  def update
    call = Workflows::BulkUpdateService
           .new(role: @role, type: @type, tab: @tab)
           .call(permitted_status_params)

    if call.success?
      render_flash_message_via_turbo_stream(
        message: I18n.t(:notice_successful_update),
        scheme: :success
      )
      statuses = statuses_for_form
      if statuses.empty?
        # Need to replace with the blankslate.
        update_via_turbo_stream(
          component: Workflows::StatusMatrixFormComponent.new(
            tab: @tab,
            role: @role,
            type: @type,
            available_roles: @eligible_roles,
            statuses:,
            has_status_changes: @has_status_changes
          )
        )
      end
    else
      render_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update),
        scheme: :danger
      )
      @turbo_status = :unprocessable_entity
    end

    respond_with_turbo_streams
  end

  def status_dialog
    all_statuses = Status.order(:position)
    current_statuses = if params[:status_ids].present?
                         Status.where(id: params[:status_ids].map(&:to_i)).order(:position)
                       elsif @type && @role
                         statuses_for_role_and_type
                       else
                         Status.none
                       end

    respond_with_dialog Workflows::StatusDialogComponent.new(
      all_statuses:,
      current_statuses:,
      role: @role,
      type: @type,
      tab: @tab
    )
  end

  def confirm_statuses # rubocop:disable Metrics/AbcSize
    current_status_ids = Array(params[:status_ids]).flatten.map(&:to_i)
    original_ids = Array(params[:original_status_ids]).flatten.map(&:to_i)
    removed_count = (original_ids - current_status_ids).size

    if removed_count > 0
      respond_with_dialog Workflows::StatusRemovalDangerDialogComponent.new(
        role: @role,
        type: @type,
        tab: @tab,
        status_ids: current_status_ids,
        removed_count: removed_count
      )
    else
      statuses = statuses_for_form.tap { workflows_for_form }
      update_via_turbo_stream(
        component: Workflows::StatusMatrixFormComponent.new(
          tab: @tab,
          role: @role,
          type: @type,
          available_roles: @eligible_roles,
          statuses:,
          has_status_changes: @has_status_changes
        )
      )
      respond_with_turbo_streams
    end
  end

  private

  def set_type
    @type = ::Type.find(params[:workflow_type_id])
  end

  def set_tab
    @tab = params[:tab]
  end

  def set_eligible_roles
    @eligible_roles = Workflow.eligible_roles.order(:builtin, :position)
  end

  def set_role
    @role = @eligible_roles.find(params[:role_id])
  end

  def statuses_for_form
    @added_status_ids = []
    @has_status_changes = false
    @statuses = if @type && params[:status_ids].present?
                  statuses_from_params
                elsif @type && @role
                  statuses_for_role_and_type
                elsif @type
                  @type.statuses
                else
                  Status.all
                end
  end

  def statuses_from_params
    status_ids = params[:status_ids].map(&:to_i)
    saved_ids = statuses_for_role_and_type.pluck(:id)
    @added_status_ids = status_ids - saved_ids
    @has_status_changes = @added_status_ids.any? || (saved_ids - status_ids).any?
    Status.where(id: status_ids).order(:position)
  end

  def statuses_for_role_and_type
    @type.statuses(role: @role, tab: @tab)
  end

  def workflows_for_form
    workflows = Workflow.where(role_id: @role.id, type_id: @type.id)
    @workflows = {}
    @workflows["always"] = workflows.select { |w| !w.author && !w.assignee }
    @workflows["author"] = workflows.select(&:author)
    @workflows["assignee"] = workflows.select(&:assignee)
  end

  def permitted_status_params
    return {} if params["status"].blank?

    params["status"]
      .to_unsafe_h
      .select { |key, value| /\A\d+\z/.match?(key) && value.keys.all? { /\A\d+\z/.match?(it) } }
  end
end
