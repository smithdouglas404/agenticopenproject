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

module OpenProject::Backlogs::Patches::WorkPackagesFilterHelperPatch
  def self.included(base)
    base.send(:prepend, DoneStatusOverrides)
  end

  # When a project has Backlogs "Done statuses" configured, the roadmap
  # overview counts those work packages alongside closed ones (see
  # VersionPatch::ProgressOverrides). The drill-down links must filter to the
  # same set, otherwise clicking "X closed work packages" shows fewer than
  # the displayed count. The generic status_id `c`/`o` meta-filters only
  # consider statuses.is_closed, so we emit an explicit status_id list that
  # unions (or excludes) the project's done statuses.
  module DoneStatusOverrides
    def project_work_packages_closed_version_path(version, options = {})
      done_status_ids = version.project.done_statuses.pluck(:id)
      return super if done_status_ids.empty?

      status_ids = (Status.where(is_closed: true).pluck(:id) + done_status_ids).uniq
      project_work_packages_with_query_path(
        version.project,
        version_status_query(version, status_ids),
        options
      )
    end

    def project_work_packages_open_version_path(version, options = {})
      done_status_ids = version.project.done_statuses.pluck(:id)
      return super if done_status_ids.empty?

      status_ids = Status.where(is_closed: false).pluck(:id) - done_status_ids
      project_work_packages_with_query_path(
        version.project,
        version_status_query(version, status_ids),
        options
      )
    end

    private

    def version_status_query(version, status_ids)
      {
        f: [
          filter_object("status_id", "=", status_ids.map(&:to_s)),
          filter_object("version_id", "=", version.id)
        ]
      }
    end
  end
end
