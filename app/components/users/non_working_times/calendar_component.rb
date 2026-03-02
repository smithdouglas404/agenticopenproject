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

module Users
  module NonWorkingDays
    class CalendarComponent < ApplicationComponent
      include OpTurbo::Streamable
      include OpPrimer::ComponentHelpers

      options non_working_times: [],
              year: Date.current.year

      private

      def wrapper_data
        {
          "controller" => "users--non-working-days",
          "users--non-working-days-events-value" => events_json,
          "users--non-working-days-year-value" => year,
          "users--non-working-days-locale-value" => I18n.locale,
          "users--non-working-days-start-of-week-value" => first_day_of_week
        }
      end

      def events_json
        (global_events + user_events).to_json
      end

      def global_events
        non_working_times
          .grep(NonWorkingDay)
          .map do |day|
            { date: day.date.iso8601, title: day.name, type: "global" }
          end
      end

      def user_events
        user_days = non_working_times
          .grep(UserNonWorkingDay)
          .map(&:date)
          .sort

        consecutive_ranges(user_days).map do |range|
          days = range.count
          {
            start: range.first.iso8601,
            end: (range.last + 1.day).iso8601,
            title: I18n.t("label_x_days", count: days),
            type: "user"
          }
        end
      end

      # Maps Setting.start_of_week to FullCalendar's firstDay convention.
      # Setting: nil=locale default, 1=Monday, 6=Saturday, 7=Sunday
      # FullCalendar firstDay: 0=Sunday, 1=Monday, ..., 6=Saturday
      # Nil defaults to 1 (Monday) to match Rails/OpenProject convention.
      def first_day_of_week
        (Setting.start_of_week || 1) % 7
      end

      # Groups a sorted array of dates into consecutive ranges.
      def consecutive_ranges(dates)
        return [] if dates.empty?

        ranges = []
        current_range = [dates.first]

        dates.drop(1).each do |date|
          if date == current_range.last + 1.day
            current_range << date
          else
            ranges << current_range
            current_range = [date]
          end
        end

        ranges << current_range
        ranges
      end
    end
  end
end
