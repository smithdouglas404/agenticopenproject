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

  before_action :load_story, except: %i[bulk_move]

  # Move a story from a Sprint to another Sprint or an Agile::Sprint.
  def move_legacy # rubocop:disable Metrics/AbcSize
    # The update service reloads the story internally (via #move_after),
    # so we memoize the previous version_id before the call.
    version_id_was = @story.version_id
    target_id = move_params[:target_id]
    move_attributes = infer_attributes_from_target(@story, target_id)

    call = move_single_story(@story, move_attributes, position_attributes)
    unless call.success?
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    replace_typed_component_via_turbo_stream(sprint: @sprint)

    if target_sprint?(move_attributes)
      moved_to_sprint(target_id)
    elsif target_version?(move_attributes) && @story.version_id != version_id_was
      moved_to_version(target_id)
    end

    respond_with_turbo_streams
  end

  # Move a story from an Agile::Sprint to another Agile::Sprint, or the Inbox.
  def move # rubocop:disable Metrics/AbcSize
    # The update service reloads the story internally (via #move_after),
    # so we memoize the previous sprint_id before the call.
    sprint_id_was = @story.sprint_id
    target_id = move_params[:target_id]
    move_attributes = infer_attributes_from_target(@story, target_id)

    call = move_single_story(@story, move_attributes, position_attributes)
    unless call.success?
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
      )
      return respond_with_turbo_streams(status: :unprocessable_entity)
    end

    replace_typed_component_via_turbo_stream(sprint: @sprint)

    if target_inbox?(move_attributes)
      moved_to_inbox(target_id)
    elsif target_version?(move_attributes)
      moved_to_version(target_id)
    elsif target_sprint?(move_attributes) && @story.sprint_id != sprint_id_was
      moved_to_sprint(target_id)
    end

    respond_with_turbo_streams
  end

  # Bulk-move multiple stories (new Agile::Sprint route, uses prev_id positioning).
  def bulk_move
    stories = load_bulk_stories
    return respond_with_turbo_streams(status: :unprocessable_entity) if stories.empty?

    target_id = bulk_move_params[:target_id]
    source_sprints = source_sprints_for(stories)

    status =
      if bulk_move_in_transaction(stories, target_id)
        source_sprints.each { |sprint| replace_typed_component_via_turbo_stream(sprint:) }
        refresh_target_container(target_id)

        :ok
      else
        :unprocessable_entity
      end

    respond_with_turbo_streams(status:)
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

    replace_typed_component_via_turbo_stream(sprint: @sprint)

    respond_with_turbo_streams
  end

  private

  # Moves all stories inside a single transaction, chaining prev_id so they
  # end up in the correct order. Returns true on success, nil on rollback.
  def bulk_move_in_transaction(stories, target_id)
    prev_id = bulk_move_params[:prev_id].presence&.to_i

    ApplicationRecord.transaction do
      stories.each do |story|
        attributes = infer_attributes_from_target(story, target_id)
        call = move_single_story(story, attributes, prev_id:)

        unless call.success?
          render_error_flash_message_via_turbo_stream(
            message: I18n.t(:notice_unsuccessful_update_with_reason, reason: call.message)
          )
          raise ActiveRecord::Rollback
        end

        prev_id = call.result.id
      end

      true
    end
  end

  def load_bulk_stories
    ids = bulk_move_params[:story_ids]
    return [] if ids.blank?

    if OpenProject::FeatureDecisions.scrum_projects_active?
      WorkPackage.visible.where(id: ids).to_a
    else
      Story.visible.where(id: ids).to_a
    end
  end

  # In the scrum path stories belong to their container via sprint_id (Agile::Sprint).
  # In the legacy path they belong via version_id (Sprint < Version), so story.sprint
  # (the Agile::Sprint belongs_to) is nil and filter_map would produce an empty array.
  def source_sprints_for(stories)
    if OpenProject::FeatureDecisions.scrum_projects_active?
      stories.filter_map(&:sprint).uniq
    else
      version_ids = stories.filter_map(&:version_id).uniq
      Sprint.visible.apply_to(@project).where(id: version_ids).to_a
    end
  end

  def infer_attributes_from_target(story, target_id)
    target_type, id = target_id.split(":")

    case target_type
    when "version"
      { version_id: id, sprint_id: nil }
    when "sprint"
      # If the story is assigned to a version, we will only nullify the version
      # if it is used as a backlog. We will keep a "regular" version reference.
      # Otherwise, moving a story to a sprint would delete it from any version it is
      # assigned to.
      if story.version&.used_as_backlog?
        { version_id: nil, sprint_id: id }
      else
        { sprint_id: id }
      end
    when "inbox"
      { sprint_id: nil }
    else
      raise ArgumentError, "target_type must be one of: version, sprint, inbox."
    end
  end

  # Returns the ServiceResult. Does not perform any rendering.
  def move_single_story(story, attributes, position_attrs = {})
    Stories::UpdateService
      .new(user: current_user, story: story)
      .call(attributes:, **position_attrs)
  end

  def refresh_target_container(target_id)
    target_type, id = target_id.split(":")

    case target_type
    when "sprint"
      sprint = Agile::Sprint.for_project(@project).visible.find_by(id:)
      replace_typed_component_via_turbo_stream(sprint:) if sprint
    when "version"
      sprint = Sprint.visible.apply_to(@project).find_by(id:)
      replace_typed_component_via_turbo_stream(sprint:) if sprint
    when "inbox"
      inbox_work_packages = Backlog.inbox_for(project: @project)
      replace_via_turbo_stream(
        component: Backlogs::InboxComponent.new(work_packages: inbox_work_packages, project: @project),
        method: :morph
      )
    end
  end

  def bulk_move_params
    params.require(:target_id)
    params.require(:story_ids)
    params.permit(:target_id, :prev_id, story_ids: [])
  end

  def replace_typed_component_via_turbo_stream(sprint:)
    if sprint.is_a?(Agile::Sprint)
      replace_sprint_component_via_turbo_stream(sprint:)
    else
      replace_backlog_component_via_turbo_stream(sprint:)
    end
  end

  def moved_to_inbox(target_id)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: @sprint.name, to: I18n.t(:label_inbox))
    )
    refresh_target_container(target_id)
  end

  def moved_to_version(target_id)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: @sprint.name, to: @story.version.name)
    )
    refresh_target_container(target_id)
  end

  def moved_to_sprint(target_id)
    render_success_flash_message_via_turbo_stream(
      message: I18n.t(:notice_successful_move, from: @sprint.name, to: @story.sprint.name)
    )
    refresh_target_container(target_id)
  end

  def target_version?(move_attributes)
    move_attributes[:version_id].present?
  end

  def target_sprint?(move_attributes)
    move_attributes[:sprint_id].present?
  end

  def target_inbox?(move_attributes)
    move_attributes.key?(:sprint_id) && move_attributes[:sprint_id].nil? &&
      !move_attributes.key?(:version_id)
  end

  def replace_backlog_component_via_turbo_stream(sprint:)
    @backlog = Backlog.for(sprint:, project: @project)
    replace_via_turbo_stream(
      component: Backlogs::BacklogComponent.new(backlog: @backlog, project: @project),
      method: :morph
    )
  end

  def replace_sprint_component_via_turbo_stream(sprint:)
    replace_via_turbo_stream(component: Backlogs::SprintComponent.new(sprint: sprint, project: @project),
                             method: :morph)
  end

  def load_story
    @story = if OpenProject::FeatureDecisions.scrum_projects_active?
               WorkPackage.visible.find(params[:id])
             else
               Story.visible.find(params[:id])
             end
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
