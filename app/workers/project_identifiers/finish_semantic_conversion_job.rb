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
# * No projects remaining → enable semantic mode on the instance.
# * Projects still pending → synchronously kick off ConvertInstanceToSemanticIdsJob
#   again (which registers this job as its own on_success callback), then enable
#   semantic mode so the next callback pass can confirm the clean state.
class ProjectIdentifiers::FinishSemanticConversionJob < ApplicationJob
  MAX_ATTEMPTS = 3

  def perform(batch = nil, _event = nil)
    task_id = batch&.properties&.dig("task_id")
    attempt = batch&.properties&.dig("attempt") || 1
    remaining = ProjectIdentifiers::PendingProjectsFinder.new.project_ids

    if remaining.none?
      BackgroundTask.find(task_id).complete! if task_id.present?
      Setting::WorkPackageIdentifier.enable_semantic!
    elsif attempt >= MAX_ATTEMPTS
      Rails.logger.error(
        "#{self.class.name}: #{remaining.size} project(s) still pending after #{attempt} attempts " \
        "(#{remaining.to_a.join(', ')}) — aborting conversion"
      )
      BackgroundTask.find(task_id).fail! if task_id.present?
      ProjectIdentifiers::RevertInstanceToClassicIdsJob.perform_later
    else
      ProjectIdentifiers::ConvertInstanceToSemanticIdsJob.new.perform(task_id, attempt: attempt + 1)
    end
  end
end
