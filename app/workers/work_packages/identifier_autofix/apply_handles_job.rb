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

class WorkPackages::IdentifierAutofix::ApplyHandlesJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(perform_limit: 1)

  def perform
    detector = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new
    exclusion_set = detector.exclusion_set
    problematic_ids = detector.scope.ids.to_set

    Project.find_each do |project|
      fix_project_identifier(project, exclusion_set) if problematic_ids.include?(project.id)
      backfill_work_packages(project)
    end

    Setting.work_packages_identifier = Setting::WorkPackageIdentifier::ALPHANUMERIC
  end

  private

  def fix_project_identifier(project, exclusion_set)
    new_identifier = WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator
                       .suggest_identifier(project.name, exclude: exclusion_set)

    project.identifier = new_identifier
    project.save!(validate: false)
    exclusion_set << new_identifier
  end

  def backfill_work_packages(project)
    WorkPackage.where(project:, sequence_number: nil).order(:id).find_each do |wp|
      seq, sid = project.allocate_wp_semantic_identifier!
      wp.update_columns(sequence_number: seq, semantic_id: sid)
    end

    WorkPackage.where(project:).find_each do |wp|
      sid = "#{project.identifier}-#{wp.sequence_number}"
      wp.update_columns(semantic_id: sid) if wp.semantic_id != sid
    end
  end
end
