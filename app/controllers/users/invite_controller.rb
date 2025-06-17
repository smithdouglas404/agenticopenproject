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
class Users::InviteController < ApplicationController
  include OpTurbo::ComponentStream

  authorize_with_permission :manage_members, global: true
  before_action :create_form_model, only: %i[start_dialog step]

  def start_dialog
    respond_with_dialog(
      Users::Invitation::DialogComponent.new(@invitation)
    )
  end

  def step
    if @invitation.valid?
      respond_with_next_step
    else
      handle_errors_in_step
    end
  end

  private

  def handle_errors_in_step
    case params[:step]
    when "project"
      replace_via_turbo_stream(component: Users::Invitation::ProjectStep::FormComponent.new(@invitation))
      respond_with_turbo_streams
    when "principal"
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(@invitation))
      respond_with_turbo_streams
    else
      render_400 message: "Invalid step"
    end
  end

  def respond_with_next_step
    case params[:step]
    when "project"
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(@invitation))
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FooterComponent.new(@invitation))
      respond_with_turbo_streams
    when "principal"
      create_invitation
    else
      render_400 message: "Invalid step"
    end
  end

  def create_invitation
    # TODO, handle invite by mail
    call = Members::CreateService
      .new(user: current_user)
      .call(form_model_params)

    if call.success?
      close_dialog_via_turbo_stream("##{Users::Invitation::DialogComponent::DIALOG_ID}",
                                    additional: {})
    else
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(call.result))
    end

    respond_with_turbo_streams
  end

  def create_form_model
    @invitation = Users::Invitation::FormModel.new(form_model_params)
  end

  def form_model_params
    return {} unless params[:user_invitation]

    permitted_params.user_invitation
  end
end
