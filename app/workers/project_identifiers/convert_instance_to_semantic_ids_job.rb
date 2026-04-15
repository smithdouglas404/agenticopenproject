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

  def perform(task_id = nil, attempt: 1)
    if task_id.present?
      task = LongRunningTask.find(task_id)
      task.start! if task.pending?
    end

    GoodJob::Batch.enqueue(on_success: ProjectIdentifiers::FinishSemanticConversionJob,
                           task_id:, attempt:) do
      ProjectIdentifiers::PendingProjectsFinder.new.project_ids.each do |project_id|
        ProjectIdentifiers::ConvertProjectToSemanticIdsJob.perform_later(project_id)
      end
    end
  end

  def enqueue_backfill_batch(project_ids, next_iteration:)
    GoodJob::Batch.enqueue(on_success: self.class, on_success_params: { iteration: next_iteration }) do
      project_ids.each { |project_id| ProjectIdentifiers::ConvertProjectToSemanticIdsJob.perform_later(project_id) }
    end
  end

  def abort_with_error(remaining_count)
    message =
      "#{self.class.name}: reached max iterations (#{MAX_ITERATIONS}) with " \
      "#{remaining_count} project(s) still unprocessed — aborting flip, reverting data"

    Rails.logger.error(message)
    # Do not raise: raising would cause GoodJob to retry this job, which would
    # race with the revert job. The error is surfaced via the log instead.
    ProjectIdentifiers::RevertInstanceToClassicIdsJob.perform_later
  end

  def project_ids_needing_backfill
    ProjectIdentifiers::PendingProjectsFinder.new.project_ids
  end
end
