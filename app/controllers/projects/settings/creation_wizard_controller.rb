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

class Projects::Settings::CreationWizardController < Projects::SettingsController
  include OpTurbo::ComponentStream

  menu_item :settings_creation_wizard

  before_action :check_feature_flag

  def show; end

  def disable_dialog
    respond_with_dialog Projects::Settings::CreationWizard::DisableDialogComponent.new(
      project: @project
    )
  end

  def toggle
    @project.update(project_creation_wizard_enabled: !@project.project_creation_wizard_enabled)
    redirect_to project_settings_creation_wizard_path(@project, tab: params[:tab]), status: :see_other
  end

  private

  def check_feature_flag
    unless OpenProject::FeatureDecisions.project_initiation_active?
      render_404
    end
  end
end
