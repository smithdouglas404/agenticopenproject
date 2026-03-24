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

  prepend_before_action :load_project_sprint_and_story, only: %i[move reorder]

  # Move a story between version-backed sprint containers.
  def move
    # The update service reloads the story internally (via #move_after),
    # so we memoize the previous version_id before the call.
    version_id_was = @story.version_id

    move_attributes = infer_attributes_from_target
    unless move_story(move_attributes).success?
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    moved_to_version if target_version?(move_attributes) && @story.version_id != version_id_was

    respond_with_turbo_streams
  end

  def reorder
    call = Stories::UpdateService
      .new(user: current_user, story: @story)
      .call(attributes: { move_to: reorder_param })

    unless call.success?
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    replace_backlog_component_via_turbo_stream(sprint: @sprint)

    respond_with_turbo_streams
  end

  private

  def move_story(move_attributes)
    call = update_story_with_target_and_position(attributes: move_attributes)

    if call.success?
      # Update source component so that the moved story disappears
      replace_backlog_component_via_turbo_stream(sprint: @sprint)
    else
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
    end

    call
  end

  def update_story_with_target_and_position(attributes:)
    Stories::UpdateService
      .new(user: current_user, story: @story)
      .call(attributes:, **position_attributes)
  end

  def moved_to_version
    new_sprint = @story.version.becomes(Sprint)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: @sprint.name, to: new_sprint.name)
    )
    replace_backlog_component_via_turbo_stream(sprint: new_sprint)
  end

  def infer_attributes_from_target
    target_type, target_id = move_params[:target_id].split(":")

    case target_type
    when "version"
      { version_id: target_id, sprint_id: nil }
    when "sprint"
      # If the story is assigned to a version, we will only nullify the version
      # if it is used as a backlog. We will keep a "regular" version reference.
      # Otherwise, moving a story to a sprint would delete it from any version it is
      # assigned to.
      if @story.version&.used_as_backlog?
        { version_id: nil, sprint_id: target_id }
      else
        { sprint_id: target_id }
      end
    else
      raise ArgumentError, "target_type must include one of: version, sprint."
    end
  end

  def target_version?(move_attributes)
    move_attributes[:version_id].present?
  end

  def replace_backlog_component_via_turbo_stream(sprint:)
    @backlog = Backlog.for(sprint:, project: @project)
    replace_via_turbo_stream(
      component: Backlogs::BacklogComponent.new(backlog: @backlog, project: @project),
      method: :morph
    )
  end

  def load_story
    @story = Story.visible.find(params[:id])
  end

  def load_project_sprint_and_story
    load_project
    load_sprint
    load_story
  end

  def load_sprint
    @sprint = Sprint.visible.apply_to(@project).find(params[:sprint_id])
  end

  def move_params
    params.require(%i[target_id])
    params.permit(:position, :prev_id, :target_id)
  end

  def position_attributes
    if move_params.has_key?(:prev_id)
      { prev_id: move_params[:prev_id].to_i }
    elsif move_params.has_key?(:position)
      { position: move_params[:position].to_i }
    else
      {}
    end
  end

  def reorder_param
    params.expect(:direction)
  end
end
