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

  STATE_INITIAL = "initial"
  STATE_FETCHING = "fetching"
  STATE_FETCH_ERROR = "fetch-error"
  STATE_FETCHED = "fetched"
  STATE_CONFIGURING = "configuring"
  STATE_IMPORTING = "importing"
  STATE_IMPORT_ERROR = "import-error"
  STATE_IMPORTED = "imported"
  STATE_REVERTING = "reverting"
  STATE_REVERT_ERROR = "revert-error"
  STATE_REVERTED = "reverted"

  STATES = [
    STATE_INITIAL,
    STATE_FETCHING,
    STATE_FETCH_ERROR,
    STATE_FETCHED,
    STATE_CONFIGURING,
    STATE_IMPORTING,
    STATE_IMPORT_ERROR,
    STATE_IMPORTED,
    STATE_REVERTING,
    STATE_REVERT_ERROR,
    STATE_REVERTED
  ].freeze

  def status_equal_or_after?(check_status)
    STATES.index(status) >= STATES.index(check_status)
  end

  def status_before?(check_status)
    STATES.index(status) < STATES.index(check_status)
  end

  def status_running?
    [
      STATE_FETCHING,
      STATE_IMPORTING,
      STATE_REVERTING
    ].include?(status)
  end
end
