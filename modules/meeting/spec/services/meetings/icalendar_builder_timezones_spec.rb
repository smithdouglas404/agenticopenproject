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

require "spec_helper"

RSpec.describe Meetings::IcalendarBuilder, "TimeZones",
               with_settings: { mail_from: "openproject@example.org", app_title: "OpenProject Testing" } do
  let(:tz_europe_berlin) { ActiveSupport::TimeZone["Europe/Berlin"] }
  let(:tz_utc) { ActiveSupport::TimeZone["Etc/UTC"] }

  let(:project) { create(:project) }
  let(:user) do
    create(:user, preferences: { time_zone: tz_europe_berlin.name },
                  member_with_permissions: { project => [:view_meetings] })
  end

  let(:builder) { described_class.new(user: user, timezone: tz_europe_berlin) }
  let(:parsed) { Icalendar::Calendar.parse(builder.to_ical).first }

  context "with a recurring meeting scheduled in UTC" do
    let!(:recurring_meeting) do
      create(:recurring_meeting,
             project: project,
             start_time: tz_utc.local(2025, 1, 16, 8, 0, 0),
             duration: 1.0,
             end_date: tz_utc.local(2026, 1, 16, 0, 0, 0),
             frequency: "weekly",
             end_after: "specific_date",
             uid: "OpenProject--meeting-series-31",
             time_zone: tz_utc.name)
    end

    before do
      builder.add_series_event(recurring_meeting: recurring_meeting)
    end

    it "generates all meeting occurences in UTC, starting at 8:00 UTC" do # rubocop:disable RSpec/ExampleLength
      event = parsed.events.first

      rrule_value = event.rrule.first.value_ical
      ics_schedule = IceCube::Schedule.new(event.dtstart.to_time)
      ics_schedule.add_recurrence_rule(IceCube::Rule.from_ical(rrule_value))

      actual_start_times = ics_schedule.all_occurrences.map(&:to_time)

      expected_start_times = [
        tz_utc.local(2025, 1, 16, 8, 0, 0),
        tz_utc.local(2025, 1, 23, 8, 0, 0),
        tz_utc.local(2025, 1, 30, 8, 0, 0),
        tz_utc.local(2025, 2, 6, 8, 0, 0),
        tz_utc.local(2025, 2, 13, 8, 0, 0),
        tz_utc.local(2025, 2, 20, 8, 0, 0),
        tz_utc.local(2025, 2, 27, 8, 0, 0),
        tz_utc.local(2025, 3, 6, 8, 0, 0),
        tz_utc.local(2025, 3, 13, 8, 0, 0),
        tz_utc.local(2025, 3, 20, 8, 0, 0),
        tz_utc.local(2025, 3, 27, 8, 0, 0),
        tz_utc.local(2025, 4, 3, 8, 0, 0), # from here on there's DST in Berlin
        tz_utc.local(2025, 4, 10, 8, 0, 0),
        tz_utc.local(2025, 4, 17, 8, 0, 0),
        tz_utc.local(2025, 4, 24, 8, 0, 0),
        tz_utc.local(2025, 5, 1, 8, 0, 0),
        tz_utc.local(2025, 5, 8, 8, 0, 0),
        tz_utc.local(2025, 5, 15, 8, 0, 0),
        tz_utc.local(2025, 5, 22, 8, 0, 0),
        tz_utc.local(2025, 5, 29, 8, 0, 0),
        tz_utc.local(2025, 6, 5, 8, 0, 0),
        tz_utc.local(2025, 6, 12, 8, 0, 0),
        tz_utc.local(2025, 6, 19, 8, 0, 0),
        tz_utc.local(2025, 6, 26, 8, 0, 0),
        tz_utc.local(2025, 7, 3, 8, 0, 0),
        tz_utc.local(2025, 7, 10, 8, 0, 0),
        tz_utc.local(2025, 7, 17, 8, 0, 0),
        tz_utc.local(2025, 7, 24, 8, 0, 0),
        tz_utc.local(2025, 7, 31, 8, 0, 0),
        tz_utc.local(2025, 8, 7, 8, 0, 0),
        tz_utc.local(2025, 8, 14, 8, 0, 0),
        tz_utc.local(2025, 8, 21, 8, 0, 0),
        tz_utc.local(2025, 8, 28, 8, 0, 0),
        tz_utc.local(2025, 9, 4, 8, 0, 0),
        tz_utc.local(2025, 9, 11, 8, 0, 0),
        tz_utc.local(2025, 9, 18, 8, 0, 0),
        tz_utc.local(2025, 9, 25, 8, 0, 0),
        tz_utc.local(2025, 10, 2, 8, 0, 0),
        tz_utc.local(2025, 10, 9, 8, 0, 0),
        tz_utc.local(2025, 10, 16, 8, 0, 0),
        tz_utc.local(2025, 10, 23, 8, 0, 0),
        tz_utc.local(2025, 10, 30, 8, 0, 0), # from here on there's no DST in Berlin
        tz_utc.local(2025, 11, 6, 8, 0, 0),
        tz_utc.local(2025, 11, 13, 8, 0, 0),
        tz_utc.local(2025, 11, 20, 8, 0, 0),
        tz_utc.local(2025, 11, 27, 8, 0, 0),
        tz_utc.local(2025, 12, 4, 8, 0, 0),
        tz_utc.local(2025, 12, 11, 8, 0, 0),
        tz_utc.local(2025, 12, 18, 8, 0, 0),
        tz_utc.local(2025, 12, 25, 8, 0, 0),
        tz_utc.local(2026, 1, 1, 8, 0, 0),
        tz_utc.local(2026, 1, 8, 8, 0, 0),
        tz_utc.local(2026, 1, 15, 8, 0, 0)
      ]

      expect(actual_start_times).to match_array(expected_start_times)
    end
  end

  context "with a recurring meeting scheduled in Europe/Berlin" do
    let!(:recurring_meeting) do
      create(:recurring_meeting,
             project: project,
             start_time: tz_europe_berlin.local(2025, 1, 16, 8, 0, 0),
             duration: 1.0,
             end_date: tz_europe_berlin.local(2026, 1, 16, 0, 0, 0),
             frequency: "weekly",
             end_after: "specific_date",
             uid: "OpenProject--meeting-series-31",
             time_zone: tz_europe_berlin.name)
    end

    before do
      builder.add_series_event(recurring_meeting: recurring_meeting)
    end

    it "generates all meeting occurences in Europe/Berlin, starting at 8:00 CET/CEST" do # rubocop:disable RSpec/ExampleLength
      event = parsed.events.first

      rrule_value = event.rrule.first.value_ical
      ics_schedule = IceCube::Schedule.new(event.dtstart.to_time)
      ics_schedule.add_recurrence_rule(IceCube::Rule.from_ical(rrule_value))

      actual_start_times = ics_schedule.all_occurrences.map(&:to_time)

      expected_start_times = [
        tz_europe_berlin.local(2025, 1, 16, 8, 0, 0),
        tz_europe_berlin.local(2025, 1, 23, 8, 0, 0),
        tz_europe_berlin.local(2025, 1, 30, 8, 0, 0),
        tz_europe_berlin.local(2025, 2, 6, 8, 0, 0),
        tz_europe_berlin.local(2025, 2, 13, 8, 0, 0),
        tz_europe_berlin.local(2025, 2, 20, 8, 0, 0),
        tz_europe_berlin.local(2025, 2, 27, 8, 0, 0),
        tz_europe_berlin.local(2025, 3, 6, 8, 0, 0),
        tz_europe_berlin.local(2025, 3, 13, 8, 0, 0),
        tz_europe_berlin.local(2025, 3, 20, 8, 0, 0),
        tz_europe_berlin.local(2025, 3, 27, 8, 0, 0),
        tz_europe_berlin.local(2025, 4, 3, 8, 0, 0), # from here on there's DST in Berlin
        tz_europe_berlin.local(2025, 4, 10, 8, 0, 0),
        tz_europe_berlin.local(2025, 4, 17, 8, 0, 0),
        tz_europe_berlin.local(2025, 4, 24, 8, 0, 0),
        tz_europe_berlin.local(2025, 5, 1, 8, 0, 0),
        tz_europe_berlin.local(2025, 5, 8, 8, 0, 0),
        tz_europe_berlin.local(2025, 5, 15, 8, 0, 0),
        tz_europe_berlin.local(2025, 5, 22, 8, 0, 0),
        tz_europe_berlin.local(2025, 5, 29, 8, 0, 0),
        tz_europe_berlin.local(2025, 6, 5, 8, 0, 0),
        tz_europe_berlin.local(2025, 6, 12, 8, 0, 0),
        tz_europe_berlin.local(2025, 6, 19, 8, 0, 0),
        tz_europe_berlin.local(2025, 6, 26, 8, 0, 0),
        tz_europe_berlin.local(2025, 7, 3, 8, 0, 0),
        tz_europe_berlin.local(2025, 7, 10, 8, 0, 0),
        tz_europe_berlin.local(2025, 7, 17, 8, 0, 0),
        tz_europe_berlin.local(2025, 7, 24, 8, 0, 0),
        tz_europe_berlin.local(2025, 7, 31, 8, 0, 0),
        tz_europe_berlin.local(2025, 8, 7, 8, 0, 0),
        tz_europe_berlin.local(2025, 8, 14, 8, 0, 0),
        tz_europe_berlin.local(2025, 8, 21, 8, 0, 0),
        tz_europe_berlin.local(2025, 8, 28, 8, 0, 0),
        tz_europe_berlin.local(2025, 9, 4, 8, 0, 0),
        tz_europe_berlin.local(2025, 9, 11, 8, 0, 0),
        tz_europe_berlin.local(2025, 9, 18, 8, 0, 0),
        tz_europe_berlin.local(2025, 9, 25, 8, 0, 0),
        tz_europe_berlin.local(2025, 10, 2, 8, 0, 0),
        tz_europe_berlin.local(2025, 10, 9, 8, 0, 0),
        tz_europe_berlin.local(2025, 10, 16, 8, 0, 0),
        tz_europe_berlin.local(2025, 10, 23, 8, 0, 0),
        tz_europe_berlin.local(2025, 10, 30, 8, 0, 0), # from here on there's no DST in Berlin
        tz_europe_berlin.local(2025, 11, 6, 8, 0, 0),
        tz_europe_berlin.local(2025, 11, 13, 8, 0, 0),
        tz_europe_berlin.local(2025, 11, 20, 8, 0, 0),
        tz_europe_berlin.local(2025, 11, 27, 8, 0, 0),
        tz_europe_berlin.local(2025, 12, 4, 8, 0, 0),
        tz_europe_berlin.local(2025, 12, 11, 8, 0, 0),
        tz_europe_berlin.local(2025, 12, 18, 8, 0, 0),
        tz_europe_berlin.local(2025, 12, 25, 8, 0, 0),
        tz_europe_berlin.local(2026, 1, 1, 8, 0, 0),
        tz_europe_berlin.local(2026, 1, 8, 8, 0, 0),
        tz_europe_berlin.local(2026, 1, 15, 8, 0, 0)
      ]

      expect(actual_start_times).to match_array(expected_start_times)
    end
  end
end
