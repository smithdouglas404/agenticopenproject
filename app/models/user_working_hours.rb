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

class UserWorkingHours < ApplicationRecord
  belongs_to :user, inverse_of: :working_hours

  validates :valid_from, presence: true
  validates :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 24 * 60 }
  validates :availability_factor,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :for_user, ->(user) { where(user:) }

  scope :past, -> { where(valid_from: ...Date.current).order(valid_from: :desc) }
  scope :upcoming, -> { where(valid_from: Date.current..).order(valid_from: :asc) }

  def self.valid_for_date(date)
    where(valid_from: ..date).order(valid_from: :desc).first
  end

  def self.current
    valid_for_date(Date.current)
  end

  scope :visible, ->(user = User.current) do
    if user.allowed_globally?(:manage_working_times)
      all
    else
      where(user:)
    end
  end

  %i[monday tuesday wednesday thursday friday saturday sunday].each do |day|
    define_method("#{day}_hours") do
      public_send(day) / 60.0
    end

    define_method("#{day}_hours=") do |hours|
      public_send("#{day}=", (hours.to_f * 60).round)
    end
  end
end
