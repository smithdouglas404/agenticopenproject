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

require Rails.root.join("db/migrate/migration_utils/squashed_migration").to_s
require_relative "tables/cost_entries"
require_relative "tables/cost_types"
require_relative "tables/rates"
require_relative "tables/time_entries"
require_relative "tables/time_entry_activities_projects"
require_relative "tables/time_entry_journals"

class AggregatedCostsMigrations < SquashedMigration
  squashed_migrations *%w[
    20180323133404_to_v710_aggregated_costs_migrations
    20200327074416_rename_fixed_version_in_cost_query
    20200807083952_rename_time_and_cost_module
    20210726065912_rename_cost_object_type
    20201001184404_rename_timestamp_on_time_and_cost_entry
    20220608213712_add_logged_by_id_to_time_entries
    20220707192304_backfill_time_entries_with_logged_by_id
    20220815072420_add_logged_by_to_time_entries_journals
    20221018160449_add_logged_by_to_cost_entries
    20230622074222_add_ongoing_to_time_entry
  ].freeze

  tables Tables::CostEntries,
         Tables::CostTypes,
         Tables::Rates,
         Tables::TimeEntries,
         Tables::TimeEntryActivitiesProjects,
         Tables::TimeEntryJournals
end
