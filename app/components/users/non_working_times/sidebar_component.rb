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
    class SidebarComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers

      options non_working_times: [],
              year: Date.current.year

      private

      def user_ranges
        user_days = non_working_times
          .grep(UserNonWorkingDay)
          .map(&:date)
          .sort

        consecutive_ranges(user_days)
      end

      def global_day_count
        non_working_times.count { |d| d.is_a?(NonWorkingDay) }
      end

      def total_user_days
        user_ranges.sum(&:count)
      end

      def total_days
        total_user_days + global_day_count
      end

      def range_label(range)
        count = range.count
        "#{format_date_range(range.first, range.last)}: #{I18n.t('label_x_days', count:)}"
      end

      def format_date_range(first, last)
        if first.month == last.month && first.year == last.year
          "#{I18n.l(first, format: '%b %d')}-#{last.day}, #{first.year}"
        elsif first.year == last.year
          "#{I18n.l(first, format: '%b %d')} - #{I18n.l(last, format: '%b %d')}, #{first.year}"
        else
          "#{I18n.l(first, format: '%b %d, %Y')} - #{I18n.l(last, format: '%b %d, %Y')}"
        end
      end

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
