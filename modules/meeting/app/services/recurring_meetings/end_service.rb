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

module RecurringMeetings
  class EndService < ::BaseServices::BaseCallable
    attr_reader :recurring_meeting, :current_user

    def initialize(recurring_meeting, current_user:)
      super()

      @recurring_meeting = recurring_meeting
      @current_user = current_user
    end

    def call
      # When we want the meeting to have ended today,
      # yesterday remains the last possible occurrence, so we set end_date = yesterday.
      # We do not want any occurrences today to remain.
      result = ::RecurringMeetings::UpdateService
        .new(model: recurring_meeting, user: current_user, contract_class: RecurringMeetings::EndSeriesContract)
        .call(end_after: "specific_date", end_date: Time.zone.yesterday)

      result.on_success do
        remove_scheduled_meetings
        remove_future_occurrences
      end

      result
    end

    private

    ##
    # Remove any upcoming scheduled meetings (e.g., those that are instantiated or cancelled)
    def remove_scheduled_meetings
      recurring_meeting.scheduled_meetings.upcoming.destroy_all
    end

    ##
    # Remove all actual future occurrences of the meeting that remained.
    # We do not use the DeleteService as that would send out notifications
    def remove_future_occurrences
      recurring_meeting.scheduled_instances.destroy_all
    end
  end
end
