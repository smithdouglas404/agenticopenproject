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

module API
  module V3
    module UserNonWorkingDays
      class NonWorkingDaysByUserAPI < ::API::OpenProjectAPI
        resource :non_working_days do
          after_validation do
            guard_feature_flag :user_working_times
          end

          params do
            optional :year, type: Integer, desc: "Filter by year. Defaults to the current year."
          end
          get do
            year = params[:year] || Date.current.year
            records = ::UserNonWorkingDay
                        .visible(current_user)
                        .for_user(@user)
                        .for_year(year)
                        .order(:date)

            UserNonWorkingDayCollectionRepresenter.new(
              records,
              self_link: api_v3_paths.user_non_working_days(@user.id),
              current_user:
            )
          end

          post &::API::V3::Utilities::Endpoints::Create.new(
            model: ::UserNonWorkingDay,
            params_modifier: ->(params) { params.merge(user: @user) }
          ).mount

          route_param :date, type: Date, desc: "UserNonWorkingDay date" do
            after_validation do
              @user_non_working_day = ::UserNonWorkingDay
                                        .visible(current_user)
                                        .for_user(@user)
                                        .find_by!(date: declared_params[:date])
            end

            delete &::API::V3::Utilities::Endpoints::Delete.new(model: ::UserNonWorkingDay).mount
          end
        end
      end
    end
  end
end
