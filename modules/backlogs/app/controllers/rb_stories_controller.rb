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

  NEW_SPRINT_ACTIONS = %i[move].freeze

  skip_before_action :load_sprint_and_project, only: NEW_SPRINT_ACTIONS

  before_action :legacy_load_story, except: NEW_SPRINT_ACTIONS
  before_action :load_project, :load_sprint, :load_story, only: NEW_SPRINT_ACTIONS

  # Move a story from a Sprint to another Sprint or an Agile::Sprint.
  def move_legacy
    # The update service reloads the story internally (via #move_after),
    # so we memoize the previous version_id before the call.
    version_id_was = @story.version_id

    move_attributes = infer_attributes_from_target
    unless move_story(move_attributes)
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    if target_sprint?(move_attributes)
      moved_to_sprint
    elsif target_version?(move_attributes) && @story.version_id != version_id_was
      moved_to_version
    end

    respond_with_turbo_streams
  end

  # Move a story from an Agile::Sprint to another Agile::Sprint or a Sprint.
  def move
    # The update service reloads the story internally (via #move_after),
    # so we memoize the previous sprint_id before the call.
    sprint_id_was = @story.sprint_id

    move_attributes = infer_attributes_from_target
    unless move_story(move_attributes)
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    if target_version?(move_attributes)
      moved_to_version
    elsif target_sprint?(move_attributes) && @story.sprint_id != sprint_id_was
      moved_to_sprint
    end

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

    unless call.success?
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
      return false
    end

    # Update source component so that the moved story disappears
    replace_typed_component_via_turbo_stream(sprint: @sprint)
  end

  def update_story_with_target_and_position(attributes:)
    Stories::UpdateService
      .new(user: current_user, story: @story)
      .call(
        attributes:,
        position: move_params[:position].to_i
      )
  end

  def replace_typed_component_via_turbo_stream(sprint:)
    if sprint.is_a?(Agile::Sprint)
      replace_sprint_component_via_turbo_stream(sprint:)
    else
      replace_backlog_component_via_turbo_stream(sprint:)
    end
  end

  def moved_to_version
    moved_to(new_sprint: @story.version.becomes(Sprint))
  end

  def moved_to_sprint
    moved_to(new_sprint: @story.sprint.becomes(Agile::Sprint))
  end

  def moved_to(new_sprint:)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: @sprint.name, to: new_sprint.name)
    )

    # Update the target component so that the moved story shows up
    replace_typed_component_via_turbo_stream(sprint: new_sprint)
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

  def target_sprint?(move_attributes)
    move_attributes[:sprint_id].present?
  end

  def replace_backlog_component_via_turbo_stream(sprint:)
    @backlog = Backlog.for(sprint:, project: @project)
    replace_via_turbo_stream(
      component: Backlogs::BacklogComponent.new(backlog: @backlog, project: @project),
      method: :morph
    )
  end

  def replace_sprint_component_via_turbo_stream(sprint:)
    replace_via_turbo_stream(component: Backlogs::SprintComponent.new(sprint: sprint))
  end

  def legacy_load_story
    @story = Story.visible.find(params[:id])
  end

  def load_story
    @story = WorkPackage.visible.find(params[:story_id])
  end

  def load_sprint
    @sprint = Agile::Sprint.for_project(@project).visible.find(params[:sprint_id])
  end

  def move_params
    params.require(%i[position target_id])
    params.permit(:position, :target_id)
  end

  def reorder_param
    params.expect(:direction)
  end
end
