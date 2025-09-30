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
require Rails.root.join("db/migrate/tables/base").to_s
Dir[File.join(__dir__, "tables/*.rb")].each { |file| require file }

class AggregatedMeetingMigrations < SquashedMigration
  squashed_migrations *%w[
    20180323135408_to_v710_aggregated_meeting_migrations
    20230816141222_create_meeting_agenda_items
    20230823113310_add_work_package_to_meeting_agenda_items
    20230829122717_add_state_to_meetings
    20230911102918_add_type_to_meeting
    20230918135247_change_meeting_agenda_item_description_to_notes
    20231003151656_create_meeting_agenda_item_journals
    20231012124745_add_item_type_to_meeting_agenda_items
    20231013114720_add_item_type_to_meeting_agenda_item_journal
    20231020154219_add_trgm_index_to_meeting_agenda_item_notes
    20231025144701_migrate_agenda_item_permissions
    20231119192222_add_locking_to_meeting
    20240313102951_add_presenter_to_meeting
    20240405131352_create_meeting_sections
    20240408161233_add_state_to_meeting_journal
    20240418110249_set_author_as_presenter
    20240516102219_fix_untitled_meetings
  ].freeze

  tables Tables::MeetingContents,
         Tables::MeetingParticipants,
         Tables::Meetings,
         Tables::MeetingJournals,
         Tables::MeetingContentJournals,
         Tables::MeetingSections,
         Tables::MeetingAgendaItems,
         Tables::MeetingAgendaItemJournals
end
