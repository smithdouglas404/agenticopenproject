# frozen_string_literal: true
module RecurringMeetings
  class ScheduleController < ApplicationController
    include OpTurbo::ComponentStream

    around_action :with_user_time_zone
    before_action :require_login, :build_meeting
    no_authorization_required! :humanize_schedule

    def humanize_schedule
      component = RecurringMeetings::HumanScheduleComponent.new(recurring_meeting: @recurring_meeting)
      update_via_turbo_stream(component:)

      respond_with_turbo_streams do |format|
        format.html { render plain: @recurring_meeting.human_frequency_schedule }
      end
    end

    private

    def with_user_time_zone(&)
      User.execute_as(User.current, &)
    end

    def build_meeting
      @recurring_meeting = RecurringMeeting.new(schedule_params.compact_blank)
    end

    def schedule_params
      params.expect(meeting: %i[start_date start_time_hour frequency interval time_zone])
    end
  end
end
