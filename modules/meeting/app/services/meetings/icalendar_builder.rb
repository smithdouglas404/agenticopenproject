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
require "icalendar"
require "icalendar/tzinfo"

module Meetings
  class IcalendarBuilder
    attr_reader :timezone, :calendar, :all_times, :tzid, :calendar_generated_for_user

    def initialize(timezone:, user: User.current)
      @calendar_generated_for_user = user
      @timezone = timezone
      @tzid = timezone.tzinfo.canonical_identifier
      @calendar = build_icalendar
      @all_times = []
      @excluded_dates_cache = {}
      @instantiated_occurrences_cache = {}
      @series_cache_loaded = false
      @action_needed_from_user_as_attendee = true
    end

    def treat_participations_from_user_as_accepted!
      @action_needed_from_user_as_attendee = false
    end

    def add_single_meeting_event(meeting:, cancelled: false) # rubocop:disable Metrics/AbcSize
      calendar.event do |e|
        e.dtstart = ical_datetime(meeting.start_time)
        e.dtend = ical_datetime(meeting.end_time)

        e.created = meeting.created_at.utc
        e.last_modified = meeting.updated_at.utc
        e.sequence = meeting.lock_version

        e.url = url_helpers.meeting_url(meeting)
        e.summary = meeting.title
        e.description = meeting.title
        e.uid = meeting.uid
        e.organizer = ical_organizer
        e.location = meeting.location.presence
        e.status = if cancelled
                     "CANCELLED"
                   else
                     "CONFIRMED"
                   end

        add_attendees(event: e, meeting: meeting)
      end
    end

    def add_series_event(recurring_meeting:, cancelled: false) # rubocop:disable Metrics/AbcSize
      calendar.event do |e|
        e.uid = recurring_meeting.uid
        e.summary = recurring_meeting.title
        e.description = recurring_meeting.title
        e.organizer = ical_organizer

        e.created = recurring_meeting.template.created_at.utc
        e.last_modified = [recurring_meeting.template.updated_at, recurring_meeting.updated_at].max.utc
        e.sequence = recurring_meeting.template.lock_version

        e.rrule = recurring_meeting.schedule.rrules.first.to_ical # We currently only have one recurrence rule
        e.dtstart = ical_datetime(recurring_meeting.template.start_time)
        e.dtend = ical_datetime(recurring_meeting.template.end_time)
        e.url = url_helpers.project_recurring_meeting_url(recurring_meeting.project, recurring_meeting)
        e.location = recurring_meeting.template.location.presence
        e.status = if cancelled
                     "CANCELLED"
                   else
                     "CONFIRMED"
                   end

        add_attendees(event: e, meeting: recurring_meeting.template)

        # Add exceptions for all cancelled recurrences
        set_excluded_recurrence_dates(event: e, recurring_meeting: recurring_meeting)
      end

      # Add single events for all occurrences
      add_instantiated_occurrences(recurring_meeting: recurring_meeting)
    end

    def add_single_recurring_occurrence(scheduled_meeting:) # rubocop:disable Metrics/AbcSize
      recurring_meeting = scheduled_meeting.recurring_meeting
      meeting = scheduled_meeting.meeting

      calendar.event do |e|
        e.uid = recurring_meeting.uid
        e.summary = recurring_meeting.title
        e.description = recurring_meeting.title
        e.organizer = ical_organizer

        e.created = meeting.created_at.utc
        e.last_modified = meeting.updated_at.utc
        e.sequence = meeting.lock_version

        e.recurrence_id = ical_datetime(scheduled_meeting.start_time)
        e.dtstart = ical_datetime(meeting.start_time)
        e.dtend = ical_datetime(meeting.end_time)
        e.url = url_helpers.project_meeting_url(meeting.project, meeting)
        e.location = meeting.location.presence

        add_attendees(event: e, meeting: meeting)
        e.status = if scheduled_meeting.cancelled?
                     "CANCELLED"
                   else
                     "CONFIRMED"
                   end
      end
    end

    def update_calendar_status(cancelled:)
      if cancelled
        calendar.cancel
      else
        calendar.request
      end
    end

    def to_ical
      calendar.add_timezone(build_single_vtimezone)
      calendar.to_ical
    end

    def preload_for_recurring_meetings(recurring_meetings:)
      @excluded_dates_cache = ScheduledMeeting
        .where(recurring_meeting: recurring_meetings)
        .group(:recurring_meeting_id)
        .pluck(:recurring_meeting_id, "array_agg(start_time)")
        .to_h
        .transform_values { |dates| dates.map { |date| ical_datetime(date) } }

      @instantiated_occurrences_cache = ScheduledMeeting
        .where(recurring_meeting: recurring_meetings)
        .not_cancelled
        .instantiated
        .includes(meeting: [:project], recurring_meeting: [:project])
        .group_by(&:recurring_meeting_id)

      @series_cache_loaded = true
    end

    private

    def series_cache_loaded?
      @series_cache_loaded
    end

    def build_icalendar
      ::Icalendar::Calendar.new.tap do |calendar|
        calendar.prodid = "-//OpenProject GmbH//#{OpenProject::VERSION}//Meeting//EN"
      end
    end

    def add_attendees(event:, meeting:)
      meeting.participants.includes(:user).find_each do |participant|
        user = participant.user
        next unless user

        address = Icalendar::Values::CalAddress.new(
          "mailto:#{user.mail}",
          {
            "CN" => user.name,
            "EMAIL" => user.mail,
            "PARTSTAT" => attendee_participation_status(user),
            "RSVP" => attendee_rsvp_needed?(user) ? "TRUE" : "FALSE",
            "CUTYPE" => "INDIVIDUAL",
            "ROLE" => "REQ-PARTICIPANT"
          }
        )

        event.append_attendee(address)
      end
    end

    def attendee_participation_status(user)
      if calendar_generated_for_user == user && @action_needed_from_user_as_attendee
        "NEEDS-ACTION"
      else
        "ACCEPTED" # until we handle RSVPs properly, we assume participants have accepted
      end
    end

    def attendee_rsvp_needed?(user)
      calendar_generated_for_user == user && @action_needed_from_user_as_attendee
    end

    def ical_datetime(time)
      time_in_time_zone = time.in_time_zone(timezone)
      all_times << time_in_time_zone
      Icalendar::Values::DateTime.new time_in_time_zone, "tzid" => tzid
    end

    def format_ical_offset(offset_seconds)
      hours = offset_seconds / 3600
      minutes = (offset_seconds.abs / 60) % 60
      sprintf("%<hours>+03d%<minutes>02d", hours:, minutes:)
    end

    # Helper to build a VTZIMEZONE with all relevant transitions
    def build_single_vtimezone # rubocop:disable Metrics/AbcSize
      tz = Icalendar::Timezone.new
      tz.tzid = tzid

      # We are investigating how to properly build this ... for now let's
      # just include everything from min - 6 months to max + 6 months
      if all_times.present?
        transitions = timezone.tzinfo.transitions_up_to(all_times.max + 6.months, all_times.min - 6.months)

        transitions.each do |tr|
          comp = tr.offset.dst? ? Icalendar::Timezone::Daylight.new : Icalendar::Timezone::Standard.new
          comp.dtstart = tr.at.utc.strftime("%Y%m%dT%H%M%SZ")
          comp.tzoffsetfrom = format_ical_offset(tr.previous_offset.utc_total_offset)
          comp.tzoffsetto = format_ical_offset(tr.offset.utc_total_offset)
          comp.tzname = tr.offset.abbreviation.to_s
          tz.add_component(comp)
        end
      end

      tz
    end

    def ical_organizer
      Icalendar::Values::CalAddress.new("mailto:#{Setting.mail_from}", cn: Setting.app_title)
    end

    def url_helpers
      @url_helpers ||= OpenProject::StaticRouting::StaticUrlHelpers.new
    end

    # Methods for recurring meetings
    def add_instantiated_occurrences(recurring_meeting:)
      upcoming_instantiated_schedules(recurring_meeting).each do |scheduled_meeting|
        add_single_recurring_occurrence(scheduled_meeting:)
      end
    end

    def set_excluded_recurrence_dates(event:, recurring_meeting:)
      event.exdate = if series_cache_loaded?
                       @excluded_dates_cache[recurring_meeting.id] || []
                     else
                       recurring_meeting
                         .scheduled_meetings
                         .cancelled
                         .pluck(:start_time)
                         .map { ical_datetime(it) }
                     end
    end

    def upcoming_instantiated_schedules(recurring_meeting)
      if series_cache_loaded?
        @instantiated_occurrences_cache[recurring_meeting.id] || []
      else
        recurring_meeting
          .scheduled_meetings
          .not_cancelled
          .instantiated
          .includes(meeting: [:project], recurring_meeting: [:project])
      end
    end
  end
end
