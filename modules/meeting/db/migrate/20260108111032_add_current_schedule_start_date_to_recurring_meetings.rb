# frozen_string_literal: true

class AddCurrentScheduleStartDateToRecurringMeetings < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_meetings, :current_schedule_start_date, :date

    execute <<~SQL.squish
      UPDATE recurring_meetings SET current_schedule_start_date = (start_time AT TIME ZONE time_zone)::date;
    SQL

    change_column_null :recurring_meetings, :current_schedule_start_date, false
  end
end
