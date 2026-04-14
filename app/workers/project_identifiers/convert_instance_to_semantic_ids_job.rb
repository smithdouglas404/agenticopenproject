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

class ProjectIdentifiers::ConvertInstanceToSemanticIdsJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(total_limit: 1)

  # Maximum number of re-processing passes before giving up and aborting the flip.
  # Prevents an infinite loop if work packages are created faster than they can be processed.
  MAX_ITERATIONS = 10

  # Called by the controller as perform_later(nil, { task_id: }) for the initial dispatch,
  # or by GoodJob as an on_success batch callback with (batch, { task_id:, iteration: }).
  # The BackgroundTask is created by the controller in pending state; this job transitions
  # it to processing on the first iteration.
  def perform(_batch = nil, params = nil)
    p         = params.to_h.with_indifferent_access
    iteration = p.fetch(:iteration, 0).to_i
    task      = BackgroundTask.find(p[:task_id])
    task.start! if iteration.zero?
    remaining = project_ids_needing_backfill

    return switch_instance_to_semantic!(task) if remaining.empty?

    convert_identifier_data(remaining, iteration, task)
  end

  private

  def switch_instance_to_semantic!(task)
    task.complete!
    Setting::WorkPackageIdentifier.enable_semantic!
  end

  def convert_identifier_data(remaining, iteration, task)
    if iteration < MAX_ITERATIONS
      enqueue_backfill_batch(remaining, next_iteration: iteration + 1, task_id: task.id)
    else
      abort_with_error(remaining.size, task)
    end
  end

  def enqueue_backfill_batch(project_ids, next_iteration:, task_id:)
    GoodJob::Batch.enqueue(on_success: self.class, iteration: next_iteration, task_id:) do
      project_ids.each { |project_id| ProjectIdentifiers::ConvertProjectToSemanticIdsJob.perform_later(project_id) }
    end
  end

  def abort_with_error(remaining_count, task)
    message =
      "#{self.class.name}: reached max iterations (#{MAX_ITERATIONS}) with " \
      "#{remaining_count} project(s) still unprocessed — aborting flip, reverting data"

    Rails.logger.error(message)
    task.fail!(remaining_count:)
    # Do not raise: raising would cause GoodJob to retry this job, which would
    # race with the revert job. The error is surfaced via the log instead.
    revert_task = BackgroundTask.create!(task_type: BackgroundTask::SEMANTIC_ID_REVERSION)
    ProjectIdentifiers::RevertInstanceToClassicIdsJob.perform_later(revert_task.id)
  end

  def project_ids_needing_backfill
    ProjectIdentifiers::PendingProjectsFinder.new.project_ids
  end
end
