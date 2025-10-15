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

module PerformanceData
  class UsersSeeder < Seeder
    TARGET_USER_COUNT = 1000

    def seed_data!
      print_status "Seeding performance users ..."
      user_names.each do |login|
        user = new_user(login)
        ActiveRecord::Base.transaction do
          user.save!(validate: false)
        end
      end
    end

    def applicable?
      !seed_users_disabled? && User.count < TARGET_USER_COUNT
    end

    def seed_users_disabled?
      off_values = %w[off false no 0]

      off_values.include? ENV.fetch("OP_DEV_USER_SEEDER_ENABLED", nil)
    end

    def user_names
      ((User.count + 1)..TARGET_USER_COUNT).map { |i| "mass-user-#{i}" }
    end

    def not_applicable_message
      msg = "Not seeding development users."
      msg = "#{msg} seed users disabled through ENV" if seed_users_disabled?

      msg
    end

    def new_user(login)
      User.new.tap do |user|
        user.login = login
        user.password = login
        user.firstname = login.humanize
        user.lastname = "Performance user"
        user.mail = "#{login}@example.net"
        user.status = chance?(90) ? User.statuses[:active] : User.statuses[:locked]
        user.language = chance?(50) ? "de" : "en"
        user.force_password_change = false
        user.notification_settings.build(assignee: true, responsible: true, mentioned: true, watched: true)
      end
    end

    def chance?(percent)
      rand < percent / 100.0
    end
  end
end
