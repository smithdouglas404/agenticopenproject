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
    project_ids = self.class.project_ids_needing_backfill

    return Setting::WorkPackageIdentifier.enable_semantic! if project_ids.empty?

    GoodJob::Batch.enqueue(on_success: ProjectIdentifiers::FlipIdentifierSettingJob) do
      project_ids.each do |project_id|
        ProjectIdentifiers::BackfillProjectJob.perform_later(project_id)
      end
    end
  end

  # Returns the set of project IDs that still need processing — either their identifier
  # violates the semantic format or they have work packages without a sequence number.
  # Shared with FlipIdentifierSettingJob for the post-batch validation pass.
  def self.project_ids_needing_backfill
    problematic_ids = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new.scope.ids.to_set
    needs_backfill  = WorkPackage.where(sequence_number: nil).distinct.pluck(:project_id).to_set
    needs_backfill | problematic_ids
  end
end
