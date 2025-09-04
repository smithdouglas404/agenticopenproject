# frozen_string_literal: true

require "rails_helper"

RSpec.describe Meetings::IcalendarBuilder,
               with_settings: { mail_from: "openproject@example.org", app_title: "OpenProject Testing" } do
  let(:timezone) { ActiveSupport::TimeZone["Europe/Berlin"] }

  context "with a single meeting" do
    let(:meeting) { create(:meeting, :author_participates, start_time: Time.zone.parse("2025-08-30 10:00")) }

    context "when current user needs to take action" do
      subject(:builder) { described_class.new(timezone:, user: meeting.author) }

      let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

      it "sets PARTSTAT to NEEDS-ACTION and RSVP to TRUE for current user" do
        builder.add_single_meeting_event(meeting:)
        builder.update_calendar_status(cancelled: false)

        event = parsed_calendar.events.first
        expect(event.attendee).not_to be_empty

        # Find the current user's attendee entry
        current_user_attendee = event.attendee.find { |a| a.to_s.include?(meeting.author.mail) }
        expect(current_user_attendee).to be_present
        expect(current_user_attendee.ical_params["partstat"]).to eq(["NEEDS-ACTION"])
        expect(current_user_attendee.ical_params["rsvp"]).to eq(["TRUE"])
        expect(current_user_attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
        expect(current_user_attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
      end

      it "sets created and last_modified timestamps correctly" do
        builder.add_single_meeting_event(meeting:)
        builder.update_calendar_status(cancelled: false)

        event = parsed_calendar.events.first
        expect(event.created.to_time).to be_within(1.second).of(meeting.created_at.utc)
        expect(event.last_modified.to_time).to be_within(1.second).of(meeting.updated_at.utc)
      end
    end

    context "when current user has accepted all invitations" do
      subject(:builder) do
        described_class.new(timezone:, user: meeting.author).tap(&:treat_participations_from_user_as_accepted!)
      end

      let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

      it "sets PARTSTAT to ACCEPTED and RSVP to FALSE for all attendees" do
        builder.add_single_meeting_event(meeting:)
        builder.update_calendar_status(cancelled: false)

        event = parsed_calendar.events.first
        expect(event.attendee).not_to be_empty

        event.attendee.each do |attendee|
          expect(attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
          expect(attendee.ical_params["rsvp"]).to eq(["FALSE"])
          expect(attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
          expect(attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
        end
      end
    end

    context "when current user is not a participant" do
      let(:other_user) { create(:user) }
      let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

      subject(:builder) { described_class.new(timezone:, user: other_user) }

      it "sets PARTSTAT to ACCEPTED and RSVP to FALSE for all attendees" do
        builder.add_single_meeting_event(meeting:)
        builder.update_calendar_status(cancelled: false)

        event = parsed_calendar.events.first
        expect(event.attendee).not_to be_empty

        event.attendee.each do |attendee|
          expect(attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
          expect(attendee.ical_params["rsvp"]).to eq(["FALSE"])
          expect(attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
          expect(attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
        end
      end
    end

    context "with multiple participants" do
      let(:user1) { create(:user, firstname: "John", lastname: "Doe", mail: "john@example.com") }
      let(:user2) { create(:user, firstname: "Jane", lastname: "Smith", mail: "jane@example.com") }
      let(:meeting_with_participants) do
        meeting = create(:meeting, start_time: Time.zone.parse("2025-08-30 10:00"))
        create(:meeting_participant, meeting:, user: user1)
        create(:meeting_participant, meeting:, user: user2)
        meeting
      end

      context "when current user needs to take action" do
        subject(:builder) { described_class.new(timezone:, user: user1) }

        let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

        it "sets PARTSTAT to NEEDS-ACTION and RSVP to TRUE for current user, ACCEPTED and FALSE for others" do
          builder.add_single_meeting_event(meeting: meeting_with_participants)
          builder.update_calendar_status(cancelled: false)

          event = parsed_calendar.events.first
          expect(event.attendee.count).to eq(2)

          # Find attendees by email
          john_attendee = event.attendee.find { |a| a.to_s.include?("john@example.com") }
          jane_attendee = event.attendee.find { |a| a.to_s.include?("jane@example.com") }

          expect(john_attendee).to be_present
          expect(jane_attendee).to be_present

          # John is the current user, so he should have NEEDS-ACTION and RSVP=TRUE
          expect(john_attendee.ical_params["partstat"]).to eq(["NEEDS-ACTION"])
          expect(john_attendee.ical_params["rsvp"]).to eq(["TRUE"])
          expect(john_attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
          expect(john_attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])

          # Jane is not the current user, so she should have ACCEPTED and RSVP=FALSE
          expect(jane_attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
          expect(jane_attendee.ical_params["rsvp"]).to eq(["FALSE"])
          expect(jane_attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
          expect(jane_attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
        end
      end

      context "when current user has accepted all invitations" do
        subject(:builder) do
          described_class.new(timezone:, user: user1).tap(&:treat_participations_from_user_as_accepted!)
        end

        let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

        it "sets PARTSTAT to ACCEPTED and RSVP to FALSE for all multiple attendees" do
          builder.add_single_meeting_event(meeting: meeting_with_participants)
          builder.update_calendar_status(cancelled: false)

          event = parsed_calendar.events.first
          expect(event.attendee.count).to eq(2)

          # Find attendees by email
          john_attendee = event.attendee.find { |a| a.to_s.include?("john@example.com") }
          jane_attendee = event.attendee.find { |a| a.to_s.include?("jane@example.com") }

          expect(john_attendee).to be_present
          expect(jane_attendee).to be_present

          [john_attendee, jane_attendee].each do |attendee|
            expect(attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
            expect(attendee.ical_params["rsvp"]).to eq(["FALSE"])
            expect(attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
            expect(attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
          end
        end
      end
    end
  end

  context "with recurring meeting series" do
    let(:project) { create(:project) }
    let(:user1) { create(:user, firstname: "John", lastname: "Doe", member_with_permissions: { project => [:view_meetings] }) }
    let(:user2) { create(:user, firstname: "John", lastname: "Doe", member_with_permissions: { project => [:view_meetings] }) }

    let(:recurring_meeting) do
      create(:recurring_meeting,
             start_time: Time.zone.parse("2025-08-25 09:00"),
             iterations: 10,
             project: project,
             end_after: :iterations,
             time_zone: timezone.tzinfo.name).tap do |recurring_meeting|
        create(:meeting_participant, :invitee, meeting: recurring_meeting.template, user: user1)
        create(:meeting_participant, :invitee, meeting: recurring_meeting.template, user: user2)
      end
    end

    let!(:second_occurrence) do
      # Cancel second occurrence
      create(:scheduled_meeting,
             :cancelled,
             recurring_meeting:,
             start_time: recurring_meeting.start_time + 1.week)
    end

    let!(:third_occurence) do
      # Third occurrence instantiated and moved by +10 minutes
      base_start = recurring_meeting.start_time + 2.weeks
      create(:scheduled_meeting,
             recurring_meeting:,
             start_time: base_start)

      result = RecurringMeetings::InitOccurrenceService
          .new(user: User.system, recurring_meeting:)
          .call(start_time: base_start)

      meeting = result.result

      # Reschedule meeting to be 10 minutes later. It should still have the correct recurrence
      meeting.update(start_time: base_start + 10.minutes)

      meeting.scheduled_meeting
    end

    context "when current user needs to take action" do
      subject(:builder) { described_class.new(timezone:, user: user1) }

      let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

      it "sets PARTSTAT to NEEDS-ACTION and RSVP to TRUE for current user in recurring meeting series" do
        builder.add_series_event(recurring_meeting:)

        master = parsed_calendar.events.find { |e| e.rrule.present? && e.recurrence_id.blank? }
        overrides = parsed_calendar.events.select { |e| e.recurrence_id.present? }

        # Check master event attendees
        expect(master.attendee).not_to be_empty
        current_user_attendee = master.attendee.find { |a| a.to_s.include?(user1.mail) }
        other_user_attendee = master.attendee.find { |a| a.to_s.include?(user2.mail) }

        # Current user should have NEEDS-ACTION and RSVP=TRUE
        expect(current_user_attendee.ical_params["partstat"]).to eq(["NEEDS-ACTION"])
        expect(current_user_attendee.ical_params["rsvp"]).to eq(["TRUE"])
        expect(current_user_attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
        expect(current_user_attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])

        # Other user should have ACCEPTED and RSVP=FALSE
        expect(other_user_attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
        expect(other_user_attendee.ical_params["rsvp"]).to eq(["FALSE"])
        expect(other_user_attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
        expect(other_user_attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])

        # Check override event attendees
        overrides.each do |override_event|
          expect(override_event.attendee).not_to be_empty
          current_user_override = override_event.attendee.find { |a| a.to_s.include?(user1.mail) }
          other_user_override = override_event.attendee.find { |a| a.to_s.include?(user2.mail) }

          expect(current_user_override.ical_params["partstat"]).to eq(["NEEDS-ACTION"])
          expect(current_user_override.ical_params["rsvp"]).to eq(["TRUE"])
          expect(other_user_override.ical_params["partstat"]).to eq(["ACCEPTED"])
          expect(other_user_override.ical_params["rsvp"]).to eq(["FALSE"])
        end
      end

      it "sets created and last_modified timestamps correctly for recurring series" do
        builder.add_series_event(recurring_meeting:)

        master = parsed_calendar.events.find { |e| e.rrule.present? && e.recurrence_id.blank? }
        overrides = parsed_calendar.events.select { |e| e.recurrence_id.present? }

        # Check master event timestamps
        expect(master.created.to_time).to be_within(1.second).of(recurring_meeting.template.created_at.utc)
        expect(master.last_modified.to_time).to be_within(1.second).of(recurring_meeting.template.updated_at.utc)

        # Check override event timestamps
        overrides.each do |override_event|
          # Find the corresponding scheduled meeting for this override
          scheduled_meeting = [second_occurrence, third_occurence].find do |sm|
            sm.meeting && override_event.recurrence_id.to_time.utc.to_i == sm.start_time.utc.to_i
          end

          if scheduled_meeting&.meeting
            expect(override_event.created.to_time).to be_within(1.second).of(scheduled_meeting.meeting.created_at.utc)
            expect(override_event.last_modified.to_time).to be_within(1.second).of(scheduled_meeting.meeting.updated_at.utc)
          end
        end
      end
    end

    context "when current user has accepted all invitations" do
      subject(:builder) do
        described_class.new(timezone:, user: user1).tap(&:treat_participations_from_user_as_accepted!)
      end

      let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

      it "sets PARTSTAT to ACCEPTED and RSVP to FALSE for all attendees in recurring meeting series" do
        builder.add_series_event(recurring_meeting:)

        master = parsed_calendar.events.find { |e| e.rrule.present? && e.recurrence_id.blank? }
        overrides = parsed_calendar.events.select { |e| e.recurrence_id.present? }

        # Check master event attendees
        expect(master.attendee).not_to be_empty
        master.attendee.each do |attendee|
          expect(attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
          expect(attendee.ical_params["rsvp"]).to eq(["FALSE"])
          expect(attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
          expect(attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
        end

        # Check override event attendees
        overrides.each do |override_event|
          expect(override_event.attendee).not_to be_empty
          override_event.attendee.each do |attendee|
            expect(attendee.ical_params["partstat"]).to eq(["ACCEPTED"])
            expect(attendee.ical_params["rsvp"]).to eq(["FALSE"])
            expect(attendee.ical_params["cutype"]).to eq(["INDIVIDUAL"])
            expect(attendee.ical_params["role"]).to eq(["REQ-PARTICIPANT"])
          end
        end
      end

      it "sets created and last_modified timestamps correctly for recurring series when accepted" do
        builder.add_series_event(recurring_meeting:)

        master = parsed_calendar.events.find { |e| e.rrule.present? && e.recurrence_id.blank? }
        overrides = parsed_calendar.events.select { |e| e.recurrence_id.present? }

        # Check master event timestamps
        expect(master.created.to_time).to be_within(1.second).of(recurring_meeting.template.created_at.utc)
        expect(master.last_modified.to_time).to be_within(1.second).of(recurring_meeting.template.updated_at.utc)

        # Check override event timestamps
        overrides.each do |override_event|
          # Find the corresponding scheduled meeting for this override
          scheduled_meeting = [second_occurrence, third_occurence].find do |sm|
            sm.meeting && override_event.recurrence_id.to_time.utc.to_i == sm.start_time.utc.to_i
          end

          if scheduled_meeting&.meeting
            expect(override_event.created.to_time).to be_within(1.second).of(scheduled_meeting.meeting.created_at.utc)
            expect(override_event.last_modified.to_time).to be_within(1.second).of(scheduled_meeting.meeting.updated_at.utc)
          end
        end
      end
    end
  end

  context "for timezone component" do
    let(:meeting) { create(:meeting, start_time: Time.zone.parse("2025-10-01 10:00")) }
    let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

    subject(:builder) { described_class.new(timezone:) }

    it "includes a VTIMEZONE with TZID" do
      builder.add_single_meeting_event(meeting:)
      expect(parsed_calendar.timezones.size).to eq(1)
      tz = parsed_calendar.timezones.first
      expect(tz.tzid).to eq(timezone.tzinfo.canonical_identifier)
    end
  end

  context "for timezone transitions across multiple years" do
    subject(:builder) { described_class.new(timezone:) }

    let(:parsed_calendar) { Icalendar::Calendar.parse(builder.to_ical).first }

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
