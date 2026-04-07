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

  def perform
    # Locate Projects with IDs that haven't yet been converted to the uppercase semantic format.
    problematic_ids = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new.scope.ids.to_set

    # Locate Projects that have some work packages that haven't yet gone through semantic ID sequencing.
    # This may include projects that have already had their identifier converted but the WPs haven't finished converting.
    # This enables idempotent re-runs.
    needs_backfill = WorkPackage.where(sequence_number: nil).distinct.pluck(:project_id).to_set

    needs_backfill.merge(problematic_ids)

    return Setting::WorkPackageIdentifier.enable_semantic! if needs_backfill.empty?

    GoodJob::Batch.enqueue(on_success: ProjectIdentifiers::FlipIdentifierSettingJob) do
      needs_backfill.each do |project_id|
        ProjectIdentifiers::BackfillProjectJob.perform_later(project_id)
      end
    end
  end
end
