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

class JiraImport < ApplicationRecord
  belongs_to :jira

  INITIAL = "initial"
  INSTANCE_META_FETCHING = "instance-meta-fetching"
  INSTANCE_META_ERROR = "instance-meta-error"
  INSTANCE_META_DONE = "instance-meta-done"
  CONFIGURING = "configuring"
  PROJECTS_META_FETCHING = "projects-meta-fetching"
  PROJECTS_META_ERROR = "projects-meta-error"
  PROJECTS_META_DONE = "projects-meta-done"
  IMPORTING = "importing"
  IMPORT_ERROR = "import-error"
  IMPORTED = "imported"
  REVERTING = "reverting"
  REVERT_ERROR = "revert-error"
  REVERTED = "reverted"

  STATUSES = [
    INITIAL,
    INSTANCE_META_FETCHING,
    INSTANCE_META_ERROR,
    INSTANCE_META_DONE,
    CONFIGURING,
    PROJECTS_META_FETCHING,
    PROJECTS_META_ERROR,
    PROJECTS_META_DONE,
    IMPORTING,
    IMPORT_ERROR,
    IMPORTED,
    REVERTING,
    REVERT_ERROR,
    REVERTED
  ].freeze

  def status_equal_or_after?(check_status)
    STATUSES.index(status) >= STATUSES.index(check_status)
  end

  def status_before?(check_status)
    STATUSES.index(status) < STATUSES.index(check_status)
  end

  def status_after?(check_status)
    STATUSES.index(status) > STATUSES.index(check_status)
  end

  def status_between?(check_from_including, check_to_including)
    STATUSES.index(status) >= STATUSES.index(check_from_including) && STATUSES.index(status) <= STATUSES.index(check_to_including)
  end

  def status?(*check_statuses)
    check_statuses.include?(status)
  end

  def status_running?
    [
      INSTANCE_META_FETCHING,
      PROJECTS_META_FETCHING,
      IMPORTING,
      REVERTING
    ].include?(status)
  end
end
