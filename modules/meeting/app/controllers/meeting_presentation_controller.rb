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

class MeetingPresentationController < ApplicationController
  include OpTurbo::ComponentStream
  include Meetings::AgendaComponentStreams

  before_action :check_feature_flag

  before_action :find_meeting
  before_action :find_agenda_item, only: [:check_for_updates]

  load_and_authorize_with_permission_in_optional_project :view_meetings

  layout "meetings/presentation"

  def show; end

  def check_for_updates
    if params[:reference] == @meeting_agenda_item.updated_at.iso8601
      head :no_content
      return
    end

    turbo_streams << turbo_stream.set_dataset_attribute(
      "#op-meeting-presentation-content",
      "reference-value",
      @meeting_agenda_item.updated_at.iso8601
    )
    update_item_via_turbo_stream(current_occurrence: @meeting, presentation_mode: true)

    respond_with_turbo_streams
  end

  private

  def find_meeting
    @meeting = Meeting.find(params[:meeting_id])
    @project = @meeting.project
  end

  def find_agenda_item
    @meeting_agenda_item = @meeting.agenda_items.find(params[:meeting_agenda_item_id])
  end

  def check_feature_flag
    unless OpenProject::FeatureDecisions.meetings_presentation_mode_active?
      render_404
    end
  end
end
