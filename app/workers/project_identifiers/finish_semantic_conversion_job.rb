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

# GoodJob on_success callback invoked after a ConvertInstanceToSemanticIdsJob
# batch completes. Performs a sanity check for any projects that were created
# or missed during the batch run:
#
# * Projects still pending → synchronously kick off ConvertInstanceToSemanticIdsJob
#   again (which registers this job as its own on_success callback).
# * Always completes the BackgroundTask and enables semantic mode.
class ProjectIdentifiers::FinishSemanticConversionJob < ApplicationJob
  def perform(_batch = nil, params = nil)
    task_id   = params.to_h.with_indifferent_access[:task_id]
    remaining = ProjectIdentifiers::PendingProjectsFinder.new.project_ids

    ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.new.perform(task_id) if remaining.any?

    BackgroundTask.find(task_id).complete!
    Setting::WorkPackageIdentifier.enable_semantic!
  end
end
