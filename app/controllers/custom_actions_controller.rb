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

class CustomActionsController < ApplicationController
  before_action :require_admin

  guard_enterprise_feature(:custom_actions,
                          only: %i[new create edit update action_section condition_section
                                   remove_action_section remove_condition_section]) do
    redirect_to action: :index
  end

  before_action :find_custom_action, only: %i[edit update destroy]
  before_action :find_custom_action_for_section, only: %i[action_section condition_section]
  before_action :pad_params, only: %i[create update]

  layout "admin"

  def index
    @custom_actions = CustomAction.order_by_position
  end

  def new
    @custom_action = CustomAction.new
  end

  def edit; end

  def create
    CustomActions::CreateService
      .new(user: current_user)
      .call(attributes: permitted_params.custom_action.to_h,
            &index_or_render(:new))
  end

  def update
    CustomActions::UpdateService
      .new(action: @custom_action, user: current_user)
      .call(attributes: permitted_params.custom_action.to_h,
            &index_or_render(:edit))
  end

  def destroy
    @custom_action.destroy

    redirect_to custom_actions_path, status: :see_other
  end

  def action_section
    key = params[:key].to_s.delete_prefix("action_")
    action = @custom_action.all_actions.find { it.key.to_s == key }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("custom-actions-form--active-actions",
                             partial: "custom_actions/action_section",
                             locals: { action: })
        ], status: :ok
      end
    end
  end

  def condition_section
    key = params[:key].to_s.delete_prefix("condition_")
    condition = @custom_action.all_conditions.find { it.key.to_s == key }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("custom-actions-form--active-conditions",
                             partial: "custom_actions/condition_section",
                             locals: { condition: })
        ], status: :ok
      end
    end
  end

  def remove_action_section
    key = params[:key].to_s.delete_prefix("action_")
    section_id = "action_section_#{key}"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(section_id)
        ], status: :ok
      end
    end
  end

  def remove_condition_section
    key = params[:key].to_s.delete_prefix("condition_")
    section_id = "condition_section_#{key}"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(section_id)
        ], status: :ok
      end
    end
  end

  private

  def find_custom_action
    @custom_action = CustomAction.find(params[:id])
  end

  def find_custom_action_for_section
    @custom_action = params[:id].present? ? CustomAction.find_by(id: params[:id]) : new
  end

  def index_or_render(render_action)
    ->(call) {
      call.on_success do
        redirect_to custom_actions_path, status: :see_other
      end

      call.on_failure do
        @custom_action = call.result
        render action: render_action, status: :unprocessable_entity
      end
    }
  end

  # If no action/condition is set in the view, the
  # actions/conditions already existing on a custom action should be removed.
  # But because it is not feasible to have an empty and hidden hash object in a form
  # we have to pad the params here.
  def pad_params
    return if !params[:custom_action] || params[:custom_action][:move_to]

    params[:custom_action][:conditions] ||= {}
    params[:custom_action][:actions] ||= {}
  end
end
