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

  good_job_control_concurrency_with(perform_limit: 1)

  # Maximum number of re-processing passes before giving up and aborting the flip.
  # Prevents an infinite loop if work packages are created faster than they can be processed.
  MAX_ITERATIONS = 10

  # Called directly by the controller (no args) for the initial dispatch,
  # or by GoodJob as an on_success batch callback with (batch, params).
  def perform(_batch = nil, params = nil)
    iteration = params.to_h.with_indifferent_access.fetch(:iteration, 0).to_i
    remaining = project_ids_needing_backfill

    return switch_instance_to_semantic! if remaining.empty?

    convert_identifier_data(remaining, iteration)
  end

  private

  def switch_instance_to_semantic!
    Setting::WorkPackageIdentifier.enable_semantic!
  end

  def convert_identifier_data(remaining, iteration)
    if iteration < MAX_ITERATIONS
      enqueue_backfill_batch(remaining, next_iteration: iteration + 1)
    else
      abort_with_error(remaining.size)
    end
  end

  def enqueue_backfill_batch(project_ids, next_iteration:)
    GoodJob::Batch.enqueue(on_success: self.class, on_success_params: { iteration: next_iteration }) do
      project_ids.each { |project_id| ProjectIdentifiers::BackfillProjectJob.perform_later(project_id) }
    end
  end

  def abort_with_error(remaining_count)
    message =
      "#{self.class.name}: reached max iterations (#{MAX_ITERATIONS}) with " \
      "#{remaining_count} project(s) still unprocessed — aborting flip, manual intervention required"

    Rails.logger.error(message)
    raise message
  end

  def project_ids_needing_backfill
    problematic_ids = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new.scope.ids.to_set
    needs_backfill  = WorkPackage.where(sequence_number: nil).distinct.pluck(:project_id).to_set
    stale_ids       = WorkPackage
                        .joins(:project)
                        .where.not(sequence_number: nil)
                        .where("work_packages.identifier IS DISTINCT FROM " \
                               "projects.identifier || '-' || work_packages.sequence_number::text")
                        .distinct.pluck(:project_id).to_set
    needs_backfill | problematic_ids | stale_ids
  end
end
