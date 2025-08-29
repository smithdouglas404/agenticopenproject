# frozen_string_literal: true

require "rails_helper"

RSpec.describe Meetings::IcalendarBuilder,
               with_settings: { mail_from: "openproject@example.org", app_title: "OpenProject Testing" } do
  subject(:builder) { described_class.new(timezone:) }

  let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

  let(:timezone) { ActiveSupport::TimeZone["Europe/Berlin"] }

  context "with a single meeting" do
    let(:meeting) { create(:meeting, :author_participates, start_time: Time.zone.parse("2025-08-30 10:00")) }

    it "adds basic event data" do
      builder.add_single_meeting_event(meeting:)
      builder.update_calendar_status(cancelled: false)

      event = parsed_calendar.events.first
      expect(event.summary).to include(meeting.title)
      expect(event.description).to include(I18n.t(:label_meeting))
      expect(event.uid).to eq(meeting.uid)
      # Organizer
      expect(event.organizer.to_s).to include("mailto:openproject@example.org")
      # Attendees (author participates)
      expect(event.attendee.first.to_s).to include("mailto:#{meeting.author.mail}")
      # Timezone parameter
      expect(event.dtstart.ical_params["tzid"]).to eq([timezone.tzinfo.canonical_identifier])
      # Method defaults to REQUEST when not cancelled
      expect(parsed_calendar.ip_method).to eq("REQUEST")
    end

    it "sets status CANCELLED when cancelled" do
      builder.add_single_meeting_event(meeting:, cancelled: true)
      builder.update_calendar_status(cancelled: true)
      event = parsed_calendar.events.first
      expect(event.status).to eq("CANCELLED")
      expect(parsed_calendar.ip_method).to eq("CANCEL")
    end
  end

  context "with recurring meeting series" do
    let(:recurring_meeting) do
      create(:recurring_meeting,
             start_time: Time.zone.parse("2025-08-25 09:00"),
             iterations: 10,
             end_after: :iterations,
             time_zone: timezone.tzinfo.name)
    end

    let!(:cancelled_schedule) do
      # Cancel second occurrence
      create(:scheduled_meeting,
             :cancelled,
             recurring_meeting:,
             start_time: recurring_meeting.start_time + 1.week)
    end

    let!(:instantiated_schedule) do
      # Third occurrence instantiated and moved by +10 minutes
      base_start = recurring_meeting.start_time + 2.weeks
      create(:scheduled_meeting,
             recurring_meeting:,
             start_time: base_start)

      # Create with meeting that has different start time
      scheduled = ScheduledMeeting.create!(
        recurring_meeting:,
        start_time: base_start,
        cancelled: false
      )

      meeting = create(:meeting,
                       recurring_meeting:,
                       start_time: base_start + 10.minutes,
                       project: recurring_meeting.project)

      scheduled.update!(meeting:)
      scheduled
    end

    it "adds master event with RRULE and EXDATE plus override events" do
      builder.add_series_event(recurring_meeting:)

      master = parsed_calendar.events.find { |e| e.rrule.present? && e.recurrence_id.blank? }
      overrides = parsed_calendar.events.select { |e| e.recurrence_id.present? }

      expect(master).to be_present
      expect(master.uid).to eq(recurring_meeting.uid)

      rrule = master.rrule.first
      expect(rrule.frequency).to eq("WEEKLY")
      expect(rrule.count).to eq(10)

      # EXDATE contains cancelled schedule start (original scheduled time, not moved time)
      exdates = Array(master.exdate).flat_map { |ex| Array(ex) }.map(&:value)
      expect(exdates).to include(cancelled_schedule.start_time.in_time_zone(timezone))
      # One override for instantiated schedule
      expect(overrides.size).to eq(1)
      ov = overrides.first
      expect(ov.recurrence_id.value).to eq(instantiated_schedule.start_time.in_time_zone(timezone))
      # Override start reflects moved meeting start time (+10m)
      expect(ov.dtstart.to_time.min).to eq(instantiated_schedule.meeting.start_time.min)
      expect(ov.dtstart.to_time.min).not_to eq(instantiated_schedule.start_time.min)
      expect(ov.sequence.to_i).to eq(instantiated_schedule.meeting.lock_version)
    end
  end

  context "for timezone component" do
    let(:meeting) { create(:meeting, start_time: Time.zone.parse("2025-10-01 10:00")) }

    it "includes a VTIMEZONE with TZID" do
      builder.add_single_meeting_event(meeting:)
      expect(parsed_calendar.timezones.size).to eq(1)
      tz = parsed_calendar.timezones.first
      expect(tz.tzid).to eq(timezone.tzinfo.canonical_identifier)
    end
  end

  context "for timezone transitions across multiple years" do
    # We pick dates spread over multiple DST changes
    let!(:meetings) do
      [
        Time.zone.parse("2025-03-30 10:00"), # Around spring DST change
        Time.zone.parse("2026-01-15 11:00"),
        Time.zone.parse("2026-07-15 09:30"), # Summer time
        Time.zone.parse("2027-02-10 14:00"),
        Time.zone.parse("2027-10-30 10:00")  # Around autumn DST change
      ].map do |ts|
        create(:meeting, :author_participates, start_time: ts, duration: 1.0)
      end
    end

    it "emits exactly one VTIMEZONE block" do
      meetings.each { |m| builder.add_single_meeting_event(meeting: m) }
      expect(parsed_calendar.timezones.size).to eq(1)
    end

    it "contains multiple STANDARD and/or DAYLIGHT components (DST transitions)" do
      meetings.each { |m| builder.add_single_meeting_event(meeting: m) }
      ics = builder.to_ical
      vtimezone_block = ics[/BEGIN:VTIMEZONE.*?END:VTIMEZONE/m]
      expect(vtimezone_block).to be_present
      standard_count = vtimezone_block.scan("BEGIN:STANDARD").size
      daylight_count = vtimezone_block.scan("BEGIN:DAYLIGHT").size
      expect(standard_count).to eq(4)
      expect(daylight_count).to eq(4)
    end
  end
end
