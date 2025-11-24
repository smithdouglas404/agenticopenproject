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

class Projects::Settings::SubitemsController < Projects::SettingsController
  menu_item :settings_subitems

  def show; end

  def update
    workspace_type = params[:workspace_type]
    template_id = params[:template_id]

    assignment = @project.subproject_template_assignments.find_or_initialize_by(workspace_type:)

    if template_id.blank?
      if assignment.persisted?
        assignment.destroy
        flash[:notice] = I18n.t(:notice_successful_update)
      end
    else
      assignment.template_id = template_id
      if assignment.save
        flash[:notice] = I18n.t(:notice_successful_update)
      else
        flash[:error] = assignment.errors.full_messages.join(", ")
      end
    end

    redirect_to project_settings_subitems_path(@project)
  end

end
