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

class MeetingTemplatesController < ApplicationController
  before_action :load_and_authorize_in_optional_project

  include Layout
  include OpTurbo::ComponentStream
  include OpTurbo::FlashStreamHelper

  menu_item :meetings

  def index
    @templates = Meeting.standalone_templates
                        .visible
                        .order(:title)

    @templates = @templates.where(project_id: @project.id) if @project

    render "meeting_templates/index",
           locals: { menu_name: project_or_global_menu }
  end

  def new_dialog
    @template = Meeting.new(
      project: @project,
      author: User.current,
      template: true,
      recurring_meeting_id: nil
    )

    respond_with_dialog Meetings::Index::DialogComponent.new(
      meeting: @template,
      project: @project,
      template: true
    )
  end

  def create
    call = ::Meetings::CreateService
      .new(user: current_user)
      .call(template_params)

    @template = call.result

    if call.success?
      flash[:notice] = I18n.t(:notice_meeting_template_created)
      redirect_to controller: "/meetings", action: "show", id: @template, status: :see_other
    else
      update_via_turbo_stream(
        component: Meetings::Index::FormComponent.new(
          meeting: @template,
          project: @template.project,
          template: true
        ),
        status: :bad_request
      )

      respond_with_turbo_streams
    end
  end

  # TODO
  # def show
  # end
  #
  # def edit
  # end
  #
  # def update
  # end
  #
  # def update_title
  # end
  #
  # def delete_dialog
  # end
  #
  # def destroy
  # end

  private

  def require_project
    render_404 unless @project
  end

  def template_params
    permitted = params.expect(meeting: %i[title project_id])

    permitted.merge(
      template: true,
      recurring_meeting_id: nil
    ).tap do |p|
      p[:project_id] = @project.id if @project.present?
    end
  end
end
