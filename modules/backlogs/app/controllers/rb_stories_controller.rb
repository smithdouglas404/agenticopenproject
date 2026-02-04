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

class RbStoriesController < RbApplicationController
  include OpTurbo::ComponentStream

  # This is a constant here because we will recruit it elsewhere to whitelist
  # attributes. This is necessary for now as we still directly use `attributes=`
  # in non-controller code.
  PERMITTED_PARAMS = %i[id status_id version_id
                        story_points type_id subject author_id
                        sprint_id].freeze

  def create
    call = Stories::CreateService
           .new(user: current_user)
           .call(attributes: story_params,
                 prev: params[:prev])

    respond_with_story(call)
  end

  def update
    story = Story.find(params[:id])

    call = Stories::UpdateService
           .new(user: current_user, story:)
           .call(attributes: story_params,
                 prev: params[:prev])

    unless call.success?
      # reload the story to be able to display it correctly
      call.result.reload
    end

    respond_with_story(call)
  end

  def move
    story = Story.find(params[:id])

    call = Stories::UpdateService
            .new(user: current_user, story:)
            .call(attributes: {
                    version_id: move_params[:target_id],
                    position: move_params[:position]
                  })

    unless call.success?
      render_error_flash_message_via_turbo_stream(message: I18n.t(:notice_unsuccessful_update)) # TODO: display reason
    end

    backlog = Backlog.for(sprint: @sprint, project: @project)
    replace_via_turbo_stream(component: Backlogs::BacklogComponent.new(backlog:, project: @project))

    if story.saved_change_to_version_id?
      new_sprint  = story.version.becomes(Sprint)
      new_backlog = Backlog.for(sprint: new_sprint, project: @project)

      render_success_flash_message_via_turbo_stream(
        message: I18n.t(:notice_successful_move, from: @sprint.name, to: new_sprint.name)
      )
      replace_via_turbo_stream(component: Backlogs::BacklogComponent.new(backlog: new_backlog, project: @project))
    end

    respond_with_turbo_streams
  end

  def reorder
    story = Story.find(params[:id])

    call = Stories::UpdateService
        .new(user: current_user, story:)
        .call(attributes: { move_to: reorder_param })

    unless call.success?
      render_error_flash_message_via_turbo_stream(message: I18n.t(:notice_unsuccessful_update)) # TODO: display reason
    end

    backlog = Backlog.for(sprint: @sprint, project: @project)

    replace_via_turbo_stream(component: Backlogs::BacklogComponent.new(backlog:, project: @project))

    respond_with_turbo_streams
  end

  private

  def respond_with_story(call)
    status = call.success? ? 200 : 400
    story = call.result

    respond_with_turbo_streams
  end

  def move_params
    params.require(%i[position target_id])
    params.permit(:position, :target_id)
  end

  def reorder_param
    params.expect(:direction)
  end

  def story_params
    params.permit(PERMITTED_PARAMS).merge(project: @project).to_h
  end
end
