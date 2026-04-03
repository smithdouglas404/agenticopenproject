# frozen_string_literal: true

class Projects::Settings::ManagementController < Projects::SettingsController
  menu_item :settings_management

  def update
    call = Projects::UpdateService
      .new(model: @project, user: current_user)
      .call(permitted_params.project)

    @project = call.result

    if call.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_settings_management_path(@project)
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      render action: :show, status: :unprocessable_entity
    end
  end
end
