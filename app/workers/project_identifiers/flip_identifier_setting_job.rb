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

class ProjectIdentifiers::FlipIdentifierSettingJob < ApplicationJob
  # Maximum number of re-processing passes before giving up and aborting the flip.
  # Prevents an infinite loop if work packages are created faster than they can be processed.
  MAX_ITERATIONS = 3

  # Called by GoodJob as an on_success batch callback with (batch, params).
  # Only fires when every job in the batch succeeded.
  def perform(_batch, params)
    remaining = remaining_project_ids
    iteration = params.to_h.fetch("iteration", 0).to_i

    return flip_setting! if remaining.empty?

    if iteration < MAX_ITERATIONS
      GoodJob::Batch.enqueue(
        on_success: self.class,
        on_success_params: { iteration: iteration + 1 }
      ) do
        remaining.each do |project_id|
          ProjectIdentifiers::BackfillProjectJob.perform_later(project_id)
        end
      end
    else
      Rails.logger.error(
        "FlipIdentifierSettingJob: reached max iterations (#{MAX_ITERATIONS}) with " \
        "#{remaining.size} project(s) still unprocessed — aborting flip, manual intervention required"
      )
      # Do NOT flip the setting; leave it for ops to investigate and re-trigger the migration.
    end
  end

  private

  def flip_setting!
    Setting.work_packages_identifier = Setting::WorkPackageIdentifier::SEMANTIC
  end

  def remaining_project_ids
    problematic_ids = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new.scope.ids.to_set
    needs_backfill = WorkPackage.where(sequence_number: nil).distinct.pluck(:project_id).to_set
    needs_backfill.merge(problematic_ids)
  end
end
