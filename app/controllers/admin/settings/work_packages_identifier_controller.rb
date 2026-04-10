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

module Admin::Settings
  class WorkPackagesIdentifierController < ::Admin::SettingsController
    include OpTurbo::ComponentStream

    before_action :check_feature_flag

    current_menu_item :show do
      :work_packages_identifier
    end

    def show
      @form_state = WorkPackages::IdentifierAutofix.job_in_progress? ? :change_in_progress : :edit
    end

    def update
      return render_400 unless params[:settings]

      if autofix_requested?
        call = update_service.new(user: current_user).call(settings_params)
        call.on_success do
          WorkPackages::IdentifierAutofix::ApplyHandlesJob.perform_later
          redirect_to action: "show"
        end
        call.on_failure { failure_callback(call) }
      else
        super
      end
    end

    def confirm_dialog
      respond_with_dialog WorkPackages::Admin::Settings::ChangeIdentifiersDialogComponent.new
    end

    def status
      if WorkPackages::IdentifierAutofix.job_in_progress?
        head :no_content
      else
        replace_via_turbo_stream(
          component: WorkPackages::Admin::Settings::IdentifierSettingsFormComponent.new(state: :completed)
        )
        respond_with_turbo_streams
      end
    end

    private

    def check_feature_flag
      render_404 unless OpenProject::FeatureDecisions.semantic_work_package_ids_active?
    end

    def autofix_requested?
      ActiveRecord::Type::Boolean.new.cast(params[:confirm_dangerous_action])
    end
  end
end
