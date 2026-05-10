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

module Backlogs
  class BulkMovesController < BaseController
    include OpTurbo::ComponentStream

    def move
      move_block_to(target_id: move_params[:target_id],
                    previous_item_id: move_params[:prev_id].presence)
    end

    def reorder
      previous_item_id = previous_item_id_for_reorder

      move_block_to(target_id: bulk_params[:source_id],
                    previous_item_id:)
    end

    def move_to_sprint_dialog
      respond_with_dialog Backlogs::MoveToSprintDialogComponent.new(
        work_package: ordered_work_packages.first,
        work_package_ids: ordered_work_package_ids,
        source_id: bulk_params[:source_id],
        project: @project,
        move_action: project_backlogs_bulk_move_work_packages_path(@project, helpers.all_backlogs_params)
      )
    end

    private

    def move_block_to(target_id:, previous_item_id:)
      move_attributes = move_attributes_from_target(target_id:)
      failure_message = perform_ordered_move(move_attributes:, previous_id: previous_item_id.presence || 0)

      return failure_response(failure_message) if failure_message

      refresh_source_target_components(target_id:)
      respond_with_turbo_streams
    end

    def ordered_work_packages
      @ordered_work_packages ||= begin
        work_packages_by_id = WorkPackage
          .visible
          .where(project: @project, id: ordered_work_package_ids)
          .index_by { |work_package| work_package.id.to_s }

        ordered_work_package_ids.map { |id| work_packages_by_id.fetch(id) }
      end
    end

    def ordered_work_package_ids
      @ordered_work_package_ids ||= bulk_params.fetch(:work_package_ids).compact_blank
    end

    def previous_item_id_for_reorder
      case params.expect(:direction)
      when "highest"
        0
      when "lowest"
        previous_id_for_lowest
      when "higher"
        previous_id_for_higher
      when "lower"
        previous_id_for_lower
      else
        raise ActionController::BadRequest, "direction must be one of: highest, higher, lower, lowest."
      end
    end

    def refresh_source_target_components(target_id:)
      [bulk_params[:source_id], target_id].compact_blank.uniq.each do |source_id|
        refresh_component_for(source_id)
      end
    end

    def perform_ordered_move(move_attributes:, previous_id:)
      failure_message = nil

      WorkPackage.transaction do
        ordered_work_packages.each do |work_package|
          call = Stories::UpdateService
            .new(user: current_user, story: work_package)
            .call(attributes: move_attributes, prev_id: previous_id)

          unless call.success?
            failure_message = call.message
            raise ActiveRecord::Rollback
          end

          previous_id = work_package.id
        end
      end

      failure_message
    end

    def selected_work_package_id_set
      @selected_work_package_id_set ||= ordered_work_package_ids.to_set(&:to_i)
    end

    def source_items
      @source_items ||= source_scope(bulk_params[:source_id]).to_a
    end

    def selected_indices
      @selected_indices ||= source_items.each_index.select do |index|
        selected_work_package_id_set.include?(source_items[index].id)
      end
    end

    def previous_id_for_lowest
      source_items.reverse.find { |work_package| selected_work_package_id_set.exclude?(work_package.id) }&.id || 0
    end

    def previous_id_for_higher
      return 0 if selected_indices.empty?

      previous_item = previous_unselected_item_before(selected_indices.first)
      return 0 unless previous_item

      previous_unselected_item_before(source_items.index(previous_item))&.id || 0
    end

    def previous_unselected_item_before(index)
      source_items[0...index].reverse.find do |work_package|
        selected_work_package_id_set.exclude?(work_package.id)
      end
    end

    def previous_id_for_lower
      return nil if selected_indices.empty?

      source_items[(selected_indices.last + 1)..]&.find do |work_package|
        selected_work_package_id_set.exclude?(work_package.id)
      end&.id
    end

    def refresh_component_for(source_id)
      target_type, target_id = source_id.split(":", 2)

      if target_type == "sprint"
        sprint = Sprint.for_project(@project).visible.find(target_id)
        replace_via_turbo_stream(component: Backlogs::SprintComponent.new(sprint:, project: @project), method: :morph)
      else
        replace_backlog_component_via_turbo_stream
      end
    end

    def replace_backlog_component_via_turbo_stream
      inbox_work_packages = WorkPackage.backlogs_inbox_for(project: @project)
      buckets = if OpenProject::FeatureDecisions.backlog_buckets_active?
                  BacklogBucket.for_project(@project)
                end

      replace_via_turbo_stream(
        component: Backlogs::BacklogComponent.new(inbox_work_packages:, buckets:, project: @project),
        method: :morph
      )
    end

    def source_scope(source_id)
      target_type, target_id = source_id.split(":", 2)
      scope = WorkPackage.visible.where(project: @project)

      case target_type
      when "sprint"
        scope.where(sprint_id: target_id).order_by_position
      when "backlog_bucket"
        scope.where(sprint_id: nil, backlog_bucket_id: target_id).order_by_position
      when "inbox"
        WorkPackage.backlogs_inbox_for(project: @project)
      else
        raise ActionController::BadRequest, "source_id must identify an inbox, backlog bucket, or sprint."
      end
    end

    def failure_response(reason)
      render_error_flash_message_via_turbo_stream(
        message: I18n.t(:notice_unsuccessful_update_with_reason, reason:)
      )
      respond_with_turbo_streams(status: :unprocessable_entity)
    end

    def move_attributes_from_target(target_id: move_params[:target_id])
      target_type, target_record_id = target_id.split(":", 2)

      case target_type
      when "sprint"
        { backlog_bucket_id: nil, sprint_id: target_record_id }
      when "backlog_bucket"
        { backlog_bucket_id: target_record_id, sprint_id: nil }
      when "inbox"
        { backlog_bucket_id: nil, sprint_id: nil }
      else
        raise ArgumentError, "target_type must be one of: backlog_bucket, sprint, inbox."
      end
    end

    def move_params
      params.require(%i[source_id target_id work_package_ids])
      params.permit(:source_id, :target_id, :prev_id, work_package_ids: [])
    end

    def bulk_params
      params.require(%i[source_id work_package_ids])
      params.permit(:source_id, work_package_ids: [])
    end
  end
end
